import 'package:flutter/widgets.dart';

import '../models/news.dart';
import '../services/admin_service.dart';
import '../services/content_service.dart';
import '../services/event_service.dart';
import '../services/sermon_service.dart';
import 'branch_directory.dart';
import 'branch_feed.dart';
import 'event_board.dart';
import 'event_reminders.dart';
import 'ministry_directory.dart';
import 'sermon_library.dart';
import 'sermon_player.dart';
import 'staff_access.dart';

/// App-wide state: the listener's branch with its news, events, live streams,
/// ministries and sermons; the sermon player; event reminders; and the
/// church branches on the map.
class CccState extends ChangeNotifier {
  CccState({
    BranchDirectory? branches,
    SermonLibrary? sermons,
    SermonPlayer? player,
    EventSource? eventSource,
    NewsSource? newsSource,
    MinistrySource? ministrySource,
    EventReminders? reminders,
    AdminSource? adminSource,
  }) : branches = branches ?? BranchDirectory(),
       sermons = sermons ?? SermonLibrary(source: SermonService.configured()),
       player = player ?? JustAudioSermonPlayer(),
       reminders = reminders ?? EventReminders(),
       staff = StaffAccess(source: adminSource ?? AdminService.configured()) {
    final content = (newsSource == null || ministrySource == null)
        ? ContentService.configured()
        : null;
    news = BranchFeed<NewsItem>(
      load: switch (newsSource ?? content) {
        final NewsSource source => (branchId) => source.latest(
          branchId: branchId,
        ),
        null => null,
      },
      listener: this.sermons,
    );
    final eventData = eventSource ?? EventService.configured();
    events = EventBoard(
      source: eventData,
      listener: this.sermons,
      onLoaded: (items) => this.reminders.resync(
        items,
        lookup: eventData is ReminderEventSource
            ? (eventData as ReminderEventSource).reminderEvents
            : null,
      ),
    );
    ministries = MinistryDirectory(
      source: ministrySource ?? content,
      listener: this.sermons,
    );
    // Cards show Reminded / Joined, so their changes rebuild the screens.
    this.reminders.addListener(notifyListeners);
    ministries.addListener(notifyListeners);
    // Staff buttons appear once the member's role is known.
    staff.addListener(notifyListeners);
  }

  final BranchDirectory branches;

  /// Also holds the listener's branch, which news, events and ministries
  /// follow.
  final SermonLibrary sermons;
  final SermonPlayer player;
  final EventReminders reminders;

  /// The signed-in member's staff role, for the staff buttons.
  final StaffAccess staff;
  late final BranchFeed<NewsItem> news;
  late final EventBoard events;
  late final MinistryDirectory ministries;

  @override
  void dispose() {
    reminders.removeListener(notifyListeners);
    ministries.removeListener(notifyListeners);
    staff.removeListener(notifyListeners);
    staff.dispose();
    branches.dispose();
    news.dispose();
    events.dispose();
    ministries.dispose();
    reminders.dispose();
    sermons.dispose();
    player.dispose();
    super.dispose();
  }
}

class CccScope extends InheritedNotifier<CccState> {
  const CccScope({required CccState state, required super.child, super.key})
    : super(notifier: state);

  static CccState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CccScope>()!.notifier!;
}
