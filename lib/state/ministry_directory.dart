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
  final _pending = <String, Future<bool>>{};

  bool hasJoined(String id) => _joined.contains(id);

  Future<void> useMember(Member? member) {
    _member = member;
    final generation = ++_memberGeneration;
    _joined = {};
    _pending.clear();
    _membershipsLoaded = member == null;
    notifyListeners();
    return _membershipsLoading = _loadMemberships(generation);
  }

  Future<void> _loadMemberships(int generation) async {
    if (source == null || _member == null) return;
    try {
      final joined = await source!.joined();
      if (_disposed || generation != _memberGeneration) return;
      _joined = joined;
      _membershipsLoaded = true;
      notifyListeners();
    } catch (_) {
      // Retry before a write; a failed read must not turn Leave into Join.
    }
  }

  Future<bool> toggle(Ministry ministry) =>
      _pending[ministry.id] ??= _toggle(ministry);

  Future<bool> _toggle(Ministry ministry) async {
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
      final joining = !_joined.contains(id);
      if (joining) {
        await source!.join(id);
      } else {
        await source!.leave(id);
      }
      if (_disposed || generation != _memberGeneration) {
        throw StateError('The signed-in member changed.');
      }
      _joined = {..._joined};
      joining ? _joined.add(id) : _joined.remove(id);
      notifyListeners();
      return joining;
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
