import '../models/member_details.dart';
import '../models/ministry.dart';
import '../services/auth_service.dart';
import '../services/content_service.dart';
import 'branch_feed.dart';

/// Published ministries and the current member's saved memberships.
class MinistryDirectory extends BranchFeed<Ministry> {
  MinistryDirectory({this.source, required super.listener})
    : super(load: source == null ? null : (id) => source.list(branchId: id));

  final MinistrySource? source;
  Set<String> _joined = {};
  Member? _member;
  int _memberGeneration = 0;
  bool _disposed = false;
  bool _membershipsLoaded = false;
  Future<void>? _membershipsLoading;
  final _pending = <String, Future<MembershipChange>>{};

  /// The member's details once [detailsAsked] has loaded them.
  MemberDetails? details;

  /// Requests to join ministries that approve their members.
  Map<String, RequestState> _requests = {};

  bool hasJoined(String id) => _joined.contains(id);

  MinistryStanding standing(String id) {
    if (_joined.contains(id)) return MinistryStanding.joined;
    return switch (_requests[id]) {
      RequestState.pending => MinistryStanding.asked,
      RequestState.declined => MinistryStanding.declined,
      null => MinistryStanding.out,
    };
  }

  Future<void> useMember(Member? member) {
    _member = member;
    final generation = ++_memberGeneration;
    details = null;
    _joined = {};
    _requests = {};
    _pending.clear();
    _membershipsLoaded = member == null;
    notifyListeners();
    return _membershipsLoading = _loadMemberships(generation);
  }

  Future<void> _loadMemberships(int generation) async {
    if (source == null || _member == null) return;
    try {
      final joined = await source!.joined();
      Map<String, RequestState> requests;
      try {
        requests = await source!.requests();
      } catch (_) {
        // Before ministry_approval.sql has been run there are none.
        requests = {};
      }
      if (_disposed || generation != _memberGeneration) return;
      _joined = joined;
      _requests = requests;
      _membershipsLoaded = true;
      notifyListeners();
    } catch (_) {
      // Retry before a write; a failed read must not turn Leave into Join.
    }
  }

  /// Whether the signed-in member has been asked for their details (and
  /// loads them); null when that isn't known, for a guest or offline.
  Future<bool?> detailsAsked() async {
    final source = this.source;
    if (source == null || _member == null) return null;
    final generation = _memberGeneration;
    try {
      final found = await source.myDetails();
      if (_disposed || generation != _memberGeneration) return null;
      details = found;
      return found != null;
    } catch (_) {
      return null;
    }
  }

  /// Saves the member's details, then brings their automatic ministries up
  /// to date. Returns the names of the ministries just joined.
  Future<List<String>> saveDetails(MemberDetails value) async {
    final source = this.source;
    if (source == null || _member == null) {
      throw StateError('Sign in to save your details.');
    }
    await source.saveDetails(value);
    details = value;
    try {
      return await matchAutomatic();
    } catch (_) {
      // The details are saved; matching runs again when the app next opens.
      return const [];
    }
  }

  /// Joins the ministries the member qualifies for and leaves automatic ones
  /// they no longer do, then reloads their memberships. Returns the names of
  /// the ministries just joined.
  Future<List<String>> matchAutomatic() async {
    final source = this.source;
    if (source == null || _member == null) return const [];
    final generation = _memberGeneration;
    final added = await source.matchMinistries();
    if (!_disposed && generation == _memberGeneration) {
      await _loadMemberships(generation);
    }
    return added;
  }

  /// Joins or leaves [ministry]; for one that approves its members, asks to
  /// join or withdraws the request instead of joining.
  Future<MembershipChange> toggle(Ministry ministry) =>
      _pending[ministry.id] ??= _toggle(ministry);

  Future<MembershipChange> _toggle(Ministry ministry) async {
    final generation = _memberGeneration;
    final id = ministry.id;
    try {
      await Future<void>.value();
      if (source == null || _member == null) {
        throw StateError('Sign in to join a ministry.');
      }
      await _membershipsLoading;
      if (!_membershipsLoaded) await _loadMemberships(generation);
      if (_disposed || generation != _memberGeneration || !_membershipsLoaded) {
        throw StateError('Memberships could not be loaded. Try again.');
      }
      final MembershipChange change;
      if (_joined.contains(id)) {
        await source!.leave(id);
        change = MembershipChange.left;
      } else if (!ministry.needsApproval) {
        await source!.join(id);
        change = MembershipChange.joined;
      } else if (_requests[id] == RequestState.pending) {
        await source!.withdrawRequest(id);
        change = MembershipChange.withdrew;
      } else {
        await source!.requestToJoin(id);
        change = MembershipChange.asked;
      }
      if (_disposed || generation != _memberGeneration) {
        throw StateError('The signed-in member changed.');
      }
      _joined = {..._joined};
      _requests = {..._requests};
      switch (change) {
        case MembershipChange.joined:
          _joined.add(id);
        case MembershipChange.left:
          _joined.remove(id);
        case MembershipChange.asked:
          _requests[id] = RequestState.pending;
        case MembershipChange.withdrew:
          _requests.remove(id);
      }
      notifyListeners();
      return change;
    } finally {
      if (generation == _memberGeneration) _pending.remove(id);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _memberGeneration++;
    super.dispose();
  }
}
