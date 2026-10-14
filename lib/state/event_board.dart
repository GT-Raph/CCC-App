import 'dart:async';

import '../models/event.dart';
import '../models/live_stream.dart';
import '../services/event_service.dart';
import 'branch_feed.dart';

/// The listener's events (their branch's and the all-branch ones) and which
/// branches are streaming live.
class EventBoard extends BranchFeed<Event> {
  EventBoard({
    this.source,
    required super.listener,
    this.onLoaded,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(
         load: source == null
             ? null
             : (branchId) => source.upcoming(branchId: branchId),
       );

  final EventSource? source;

  /// Told about each freshly loaded list (reminders follow time changes).
  final void Function(List<Event> events)? onLoaded;
  final DateTime Function() _clock;

  Map<String, LiveStream> _live = const {};
  StreamSubscription<List<LiveStream>>? _liveUpdates;

  DateTime get now => _clock();

  /// Current and upcoming events, soonest first.
  List<Event> get events {
    final now = this.now;
    return [
      for (final event in items)
        if (!event.hasEndedAt(now)) event,
    ];
  }

  @override
  Future<void> ensureLoaded() {
    _watchLive();
    return super.ensureLoaded();
  }

  @override
  void loaded(List<Event> items) => onLoaded?.call(items);

  /// The branch's stream when [event] is on and its host branch is live.
  LiveStream? liveFor(Event event) {
    final branchId = event.branchId;
    if (branchId == null) return null;
    final stream = _live[branchId];
    final now = this.now;
    return stream != null && stream.isLiveAt(now) && event.isOnAt(now)
        ? stream
        : null;
  }

  /// The listener's branch stream when it is live outside any listed event,
  /// so it still shows at the top of the Events tab.
  LiveStream? get branchLiveNow {
    final branchId = listener.branch?.id;
    if (branchId == null) return null;
    final stream = _live[branchId];
    final now = this.now;
    if (stream == null || !stream.isLiveAt(now)) return null;
    final covered = events.any((e) => e.branchId == branchId && e.isOnAt(now));
    return covered ? null : stream;
  }

  void _watchLive() {
    final source = this.source;
    if (source == null || _liveUpdates != null) return;
    _liveUpdates = source.liveStreams().listen(
      (streams) {
        _live = {for (final stream in streams) stream.branchId: stream};
        notifyListeners();
      },
      // Without live updates the tab still works, just without LIVE badges.
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    _liveUpdates?.cancel();
    super.dispose();
  }
}
