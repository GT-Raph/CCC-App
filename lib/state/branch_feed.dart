import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/church_query.dart';
import 'sermon_library.dart';

enum FeedStatus { notConfigured, loading, ready, failed }

/// A list from Supabase for the listener's branch (its own items plus the
/// ones for every branch) that reloads when the listener changes branch.
/// [SermonLibrary] holds that branch, whether it's a member's or a guest's.
class BranchFeed<T> extends ChangeNotifier {
  BranchFeed({required this.load, required this.listener}) {
    _branchKey = _currentBranchKey;
    listener.addListener(_listenerChanged);
  }

  /// Fetches the items for a branch (null: no branch chosen). Null when
  /// Supabase isn't set up.
  final Future<List<T>> Function(String? branchId)? load;
  final SermonLibrary listener;

  List<T> _items = const [];
  String? error;
  bool setupMissing = false;
  bool _loading = false;
  String? _loadedFor;
  late String _branchKey;

  /// The list has been shown, so load (and reload on a branch change).
  bool _wanted = false;
  int _generation = 0;
  bool _disposed = false;

  String get _currentBranchKey => listener.branch?.id ?? '';

  FeedStatus get status {
    if (load == null) return FeedStatus.notConfigured;
    if (_loading) return FeedStatus.loading;
    if (error != null) return FeedStatus.failed;
    return _loadedFor == _branchKey ? FeedStatus.ready : FeedStatus.loading;
  }

  List<T> get items => _items;

  Future<void> ensureLoaded() async {
    _wanted = true;
    if (load == null || _loading) return;
    if (_loadedFor == _branchKey && error == null) return;
    await refresh();
  }

  Future<void> refresh() async {
    final load = this.load;
    if (load == null) return;
    final branchKey = _branchKey;
    final generation = ++_generation;
    _loading = true;
    error = null;
    notifyListeners();
    try {
      final found = await load(branchKey.isEmpty ? null : branchKey);
      if (_disposed || generation != _generation) return;
      _items = found;
      _loadedFor = branchKey;
      setupMissing = false;
      loaded(found);
    } on ChurchDataException catch (e) {
      if (_disposed || generation != _generation) return;
      error = e.message;
      setupMissing = e.setupMissing;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      error = "Content couldn't load. Please try again.";
      setupMissing = false;
    }
    _loading = false;
    notifyListeners();
  }

  /// Called with each freshly loaded list.
  @protected
  void loaded(List<T> items) {}

  void _listenerChanged() {
    final branchKey = _currentBranchKey;
    if (branchKey == _branchKey) return;
    _branchKey = branchKey;
    _generation++;
    _loading = false;
    _items = const [];
    _loadedFor = null;
    error = null;
    notifyListeners();
    if (_wanted) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    listener.removeListener(_listenerChanged);
    super.dispose();
  }
}
