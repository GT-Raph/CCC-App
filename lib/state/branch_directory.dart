import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/church_branches.dart';
import '../models/branch.dart';
import '../models/church_branch.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';

enum BranchStatus { notConfigured, idle, loading, ready, failed }

/// The church's branches with their Google Maps details, nearest first when
/// the member shares their location.
class BranchDirectory extends ChangeNotifier {
  BranchDirectory({
    this.places,
    this.listedBranches,
    this.location = const LocationService(),
    this.cache = const BranchCache(),
  }) : status = places == null ? BranchStatus.notConfigured : BranchStatus.idle;

  final PlacesService? places;

  /// The branches the church lists in Supabase. Those with a Google Maps
  /// listing are shown under the church's name for them; until the list is
  /// set up, the directory searches Google Maps instead.
  final Future<List<ChurchBranch>> Function()? listedBranches;
  final LocationService location;
  final BranchCache cache;

  BranchStatus status;
  List<Branch> branches = const [];
  LocationAccess? locationAccess;
  String? error;
  Future<void>? _loading;

  /// How many of the nearest branches get a driving distance and time.
  static const routedBranches = 10;

  /// Loads the branches the first time the Church tab is shown.
  Future<void> ensureLoaded() => _loading ??= _load(useCache: true);

  /// Fetches fresh results from Google Maps (pull to refresh, Try again).
  Future<void> refresh() => _loading = _load(useCache: false);

  /// Asks for location again, or opens settings when the system won't ask
  /// (distances refresh when the member comes back to the app).
  Future<void> enableLocation() async {
    final access = locationAccess;
    if (access == LocationAccess.deniedForever ||
        access == LocationAccess.serviceOff) {
      await location.openSettings(access!);
      return;
    }
    await refreshDistances();
  }

  Future<void> refreshDistances() async {
    final places = this.places;
    if (places == null || status != BranchStatus.ready) return;
    final fix = await location.current();
    _applyLocation(fix);
    notifyListeners();
    await _addDrivingTimes(places, fix.position);
  }

  Future<void> _load({required bool useCache}) async {
    final places = this.places;
    if (places == null) return;
    status = BranchStatus.loading;
    error = null;
    notifyListeners();

    final fix = location.current();
    try {
      var found = useCache ? await cache.read() : null;
      if (found == null) {
        found = await _find(places);
        await cache.write(found);
      }
      branches = found;
      _applyLocation(await fix);
      status = BranchStatus.ready;
      notifyListeners();
      await _addDrivingTimes(places, (await fix).position);
    } on PlacesException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Could not load branches. Check your connection and try again.');
    }
  }

  Future<List<Branch>> _find(PlacesService places) async {
    final listed = await _listed();
    if (listed.isEmpty) {
      // Search misses some branches (listings named only "CCC <town>", and
      // most outside Accra), so it is only the fallback.
      return places.searchBranches(
        queries: branchSearchQueries,
        keep: isChurchBranch,
      );
    }
    Object? failure;
    final found = await Future.wait([
      for (final branch in listed)
        places
            .branchById(branch.googlePlaceId!)
            .then(
              (place) => place?.withName(branch.name),
              onError: (Object error) {
                failure ??= error;
                return null;
              },
            ),
    ]);
    final branches = found.nonNulls.toList();
    if (branches.isEmpty && failure != null) throw failure!;
    return branches;
  }

  Future<List<ChurchBranch>> _listed() async {
    final load = listedBranches;
    if (load == null) return const [];
    try {
      return [
        for (final branch in await load())
          if (branch.googlePlaceId != null) branch,
      ];
    } catch (_) {
      return const []; // Not set up in Supabase yet.
    }
  }

  void _fail(String message) {
    error = message;
    status = BranchStatus.failed;
    _loading = null;
    notifyListeners();
  }

  void _applyLocation(LocationFix fix) {
    locationAccess = fix.access;
    final origin = fix.position;
    if (origin == null) {
      branches = [for (final b in branches) b.withDistance()];
      return;
    }
    branches = [
      for (final b in branches)
        b.withDistance(
          straightMeters: location.distanceMeters(
            origin,
            b.latitude,
            b.longitude,
          ),
        ),
    ]..sort((a, b) => a.straightMeters!.compareTo(b.straightMeters!));
  }

  Future<void> _addDrivingTimes(PlacesService places, LatLng? origin) async {
    if (origin == null || branches.isEmpty) return;
    try {
      final nearest = branches.take(routedBranches).toList();
      final times = await places.drivingTimes(origin, nearest);
      if (times.isEmpty) return;
      branches = [
        for (final b in branches)
          if (times[b.id] case final time?)
            b.withRoute(meters: time.meters, seconds: time.seconds)
          else
            b,
      ];
      notifyListeners();
    } catch (_) {
      // Driving times are a bonus (they need the Routes API); keep the
      // straight-line distances when they are unavailable.
    }
  }
}

/// Keeps the branch list for a day so each phone asks Google Maps for it at
/// most once a day.
class BranchCache {
  const BranchCache();

  // v2: the list follows Supabase's branches table rather than a search.
  static const _key = 'church_branches_v2';
  static const maxAge = Duration(hours: 24);

  Future<List<Branch>?> read() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.parse(json['savedAt'] as String);
      if (DateTime.now().difference(savedAt) > maxAge) return null;
      return [
        for (final branch
            in (json['branches'] as List).cast<Map<String, dynamic>>())
          Branch.fromJson(branch),
      ];
    } catch (_) {
      return null;
    }
  }

  Future<void> write(List<Branch> branches) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode({
          'savedAt': DateTime.now().toIso8601String(),
          'branches': [for (final branch in branches) branch.toJson()],
        }),
      );
    } catch (_) {}
  }
}
