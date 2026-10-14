import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/church_branch.dart';
import '../models/sermon.dart';
import '../services/auth_service.dart';
import '../services/sermon_service.dart';

enum SermonStatus { notConfigured, noBranch, loading, ready, failed }

enum BranchListStatus { idle, loading, ready, failed }

/// The listener's branch and its sermons. A member's branch is saved on their
/// account; a guest's choice is remembered on the device.
class SermonLibrary extends ChangeNotifier {
  SermonLibrary({
    this.source,
    this.guestStore = const GuestBranchStore(),
    Future<void> Function(ChurchBranch branch)? saveMemberBranch,
  }) : _saveMemberBranch = saveMemberBranch ?? AuthService.updateBranch;

  final SermonSource? source;
  final GuestBranchStore guestStore;
  final Future<void> Function(ChurchBranch branch) _saveMemberBranch;

  ChurchBranch? branch;
  bool _isMember = false;

  List<Sermon> sermons = const [];
  String? error;
  bool setupMissing = false;
  bool _loading = false;
  String? _loadedFor;

  /// Bumped for each load, so a slow load for a previous branch is ignored.
  int _generation = 0;

  /// The Sermons tab has been opened, so load as soon as there is a branch.
  bool _wanted = false;

  List<ChurchBranch> branchList = const [];
  BranchListStatus branchListStatus = BranchListStatus.idle;
  String? branchListError;

  bool get isConfigured => source != null;

  SermonStatus get status {
    if (source == null) return SermonStatus.notConfigured;
    if (branch == null) return SermonStatus.noBranch;
    if (_loading) return SermonStatus.loading;
    if (error != null) return SermonStatus.failed;
    return _loadedFor == branch!.id ? SermonStatus.ready : SermonStatus.loading;
  }

  /// Starts from the member's branch, or the guest's saved choice.
  Future<void> useListener(Member? member) async {
    _isMember = member != null;
    final next = member != null ? member.branch : await guestStore.read();
    if (next == branch) return;
    branch = next;
    _clearSermons();
    notifyListeners();
    if (_wanted) await ensureLoaded();
  }

  /// Loads the branch's sermons the first time the Sermons tab is shown.
  Future<void> ensureLoaded() async {
    _wanted = true;
    final branch = this.branch;
    if (source == null || branch == null || _loading) return;
    if (_loadedFor == branch.id && error == null) return;
    await refresh();
  }

  Future<void> refresh() async {
    final source = this.source;
    final branch = this.branch;
    if (source == null || branch == null) return;
    final generation = ++_generation;
    _loading = true;
    error = null;
    notifyListeners();
    try {
      final found = await source.sermons(branch.id);
      if (generation != _generation) return;
      sermons = found;
      _loadedFor = branch.id;
      setupMissing = false;
    } on ChurchDataException catch (e) {
      if (generation != _generation) return;
      error = e.message;
      setupMissing = e.setupMissing;
    }
    _loading = false;
    notifyListeners();
  }

  /// Makes [next] the listener's branch and loads its sermons. Throws when a
  /// member's choice can't be saved to their account.
  Future<void> chooseBranch(ChurchBranch next) async {
    if (_isMember) {
      await _saveMemberBranch(next);
    } else {
      await guestStore.write(next);
    }
    if (next == branch) return;
    branch = next;
    _clearSermons();
    notifyListeners();
    await refresh();
  }

  /// Loads the branches for the branch picker.
  Future<void> loadBranches({bool force = false}) async {
    final source = this.source;
    if (source == null) return;
    if (branchListStatus == BranchListStatus.loading) return;
    if (branchListStatus == BranchListStatus.ready && !force) return;
    branchListStatus = BranchListStatus.loading;
    branchListError = null;
    notifyListeners();
    try {
      branchList = await source.branches();
      branchListStatus = BranchListStatus.ready;
    } on ChurchDataException catch (e) {
      branchListError = e.setupMissing
          ? 'Branches are not set up yet.'
          : "Branches couldn't load. Check your internet connection and "
                'try again.';
      setupMissing = setupMissing || e.setupMissing;
      branchListStatus = BranchListStatus.failed;
    }
    notifyListeners();
  }

  void _clearSermons() {
    _generation++;
    _loading = false;
    sermons = const [];
    error = null;
    _loadedFor = null;
  }
}

/// Remembers which branch a guest chose to listen to.
class GuestBranchStore {
  const GuestBranchStore();

  static const _key = 'guest_branch_v1';

  Future<ChurchBranch?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == null) return null;
      return ChurchBranch.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(ChurchBranch branch) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(branch.toJson()));
    } catch (_) {
      // Not remembering a guest's choice is fine; they can pick again.
    }
  }
}
