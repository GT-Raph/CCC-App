import 'dart:async';
import 'dart:convert';

import 'package:ccc_app/models/event.dart';
import 'package:ccc_app/screens/main_screen.dart';
import 'package:ccc_app/services/content_service.dart';
import 'package:ccc_app/services/event_service.dart';
import 'package:ccc_app/services/sermon_service.dart';
import 'package:ccc_app/state/branch_feed.dart';
import 'package:ccc_app/state/event_reminders.dart';
import 'package:ccc_app/state/ministry_directory.dart';
import 'package:ccc_app/state/sermon_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fakes.dart';

class ControlledMinistries extends FakeMinistries {
  Completer<void>? writeGate;
  bool failRead = false;
  int joins = 0;
  @override
  Future<Set<String>> joined() async {
    if (failRead) throw StateError('Offline');
    return super.joined();
  }

  @override
  Future<void> join(String id) async {
    joins++;
    await writeGate?.future;
    await super.join(id);
  }
}

class FailingScheduler extends FakeScheduler {
  bool failSchedule = false;
  bool failCancel = false;
  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    if (failSchedule) throw StateError('Scheduler unavailable');
    await super.schedule(id: id, at: at, title: title, body: body);
  }

  @override
  Future<void> cancel(int id) async {
    if (failCancel) throw StateError('Cancellation failed');
    await super.cancel(id);
  }
}

class FailingReminderStore extends MemoryReminderStore {
  @override
  Future<void> write(Set<String> ids) async => throw StateError('Disk full');
}

void main() {
  group('published content', () {
    test(
      'news, ministries, events and sermons query only the requested audience',
      () async {
        final requests = <Uri>[];
        final client = SupabaseClient(
          'https://church.example',
          'test-key',
          httpClient: MockClient((request) async {
            requests.add(request.url);
            // Real responses carry their request; the client reads it.
            return http.Response(
              '[]',
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        final service = ContentService(client);
        final events = EventService(client);
        final sermons = SermonService(client);
        expect(await service.latest(), isEmpty);
        expect(requests.last.queryParameters['branch_id'], 'is.null');
        expect(
          requests.last.queryParameters['published_at'],
          startsWith('lte.'),
        );
        expect(await service.latest(branchId: botwe.id), isEmpty);
        expect(
          requests.last.queryParameters['or'],
          '(branch_id.is.null,branch_id.eq.${botwe.id})',
        );
        expect(await service.list(branchId: botwe.id), isEmpty);
        expect(
          requests.last.queryParameters['or'],
          '(branch_id.is.null,branch_id.eq.${botwe.id})',
        );
        expect(await events.upcoming(), isEmpty);
        expect(requests.last.queryParameters['for_all_branches'], 'eq.true');
        expect(await events.upcoming(branchId: botwe.id), isEmpty);
        expect(
          requests.last.queryParameters['or'],
          '(for_all_branches.eq.true,branch_id.eq.${botwe.id})',
        );
        expect(await sermons.sermons(botwe.id), isEmpty);
        expect(
          requests.last.queryParameters['or'],
          '(branch_id.is.null,branch_id.eq.${botwe.id})',
        );
      },
    );

    test(
      'missing tables produce setup errors, never a demo fallback',
      () async {
        final client = SupabaseClient(
          'https://church.example',
          'test-key',
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode({
                'code': 'PGRST205',
                'message': 'Table does not exist',
              }),
              404,
              headers: {'content-type': 'application/json'},
              request: request,
            ),
          ),
        );
        addTearDown(client.dispose);
        final source = ContentService(client);
        await Future.wait(
          [source.latest(), source.list(), EventService(client).upcoming()].map(
            (request) => expectLater(
              request,
              throwsA(
                isA<ChurchDataException>().having(
                  (e) => e.setupMissing,
                  'setupMissing',
                  true,
                ),
              ),
            ),
          ),
        );
      },
    );

    testWidgets('empty feeds show honest empty states', (tester) async {
      final harness = Harness(
        news: FakeNews((_) => []),
        events: FakeEvents((_) => []),
        ministries: FakeMinistries(results: (_) => []),
      );
      await harness.pump(tester, const MainScreen(member: ama));
      expect(find.text('No news yet.'), findsOneWidget);
      expect(find.text('Harvest Thanksgiving'), findsNothing);
      await tester.tap(find.text('Events'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No upcoming events'), findsOneWidget);
      await tester.tap(find.text('Ministries'));
      await tester.pumpAndSettle();
      expect(find.text('No ministries yet.'), findsOneWidget);
      expect(find.text('Kharis Ladies'), findsNothing);
    });

    test(
      'late responses cannot replace the new branch or notify after disposal',
      () async {
        final listener = SermonLibrary(
          source: FakeSermons(),
          saveMemberBranch: (_) async {},
        );
        await listener.useListener(ama);
        final oldLoad = Completer<List<String>>();
        final nextLoad = Completer<List<String>>();
        final feed = BranchFeed<String>(
          listener: listener,
          load: (id) => id == botwe.id ? oldLoad.future : nextLoad.future,
        );
        final first = feed.ensureLoaded();
        await listener.chooseBranch(westland);
        nextLoad.complete(['Westland']);
        await Future<void>.delayed(Duration.zero);
        oldLoad.complete(['Botwe']);
        await first;
        expect(feed.items, ['Westland']);
        final pending = feed.refresh();
        feed.dispose();
        await pending;
        listener.dispose();
      },
    );

    test('unexpected data errors end loading and can be retried', () async {
      final listener = SermonLibrary();
      var fail = true;
      final feed = BranchFeed<String>(
        listener: listener,
        load: (_) async {
          if (fail) throw const FormatException('Malformed record');
          return [];
        },
      );
      await feed.ensureLoaded();
      expect(feed.status, FeedStatus.failed);
      expect(feed.items, isEmpty);
      fail = false;
      await feed.refresh();
      expect(feed.status, FeedStatus.ready);
      feed.dispose();
      listener.dispose();
    });
  });

  group('saved memberships', () {
    late ControlledMinistries source;
    late MinistryDirectory directory;
    late SermonLibrary listener;
    setUp(() async {
      source = ControlledMinistries();
      listener = SermonLibrary();
      directory = MinistryDirectory(source: source, listener: listener);
      await directory.useMember(ama);
    });
    tearDown(() {
      directory.dispose();
      listener.dispose();
    });

    test(
      'joins persist across reload and leave removes the saved membership',
      () async {
        final item = ministry('women', 'Women');
        expect(await directory.toggle(item), true);
        expect(source.joinedIds, {'women'});
        await directory.useMember(ama);
        expect(directory.hasJoined('women'), true);
        expect(await directory.toggle(item), false);
        expect(source.joinedIds, isEmpty);
      },
    );

    test('failed writes never show a successful join', () async {
      source.failWrites = true;
      await expectLater(
        directory.toggle(ministry('women', 'Women')),
        throwsA(isA<Exception>()),
      );
      expect(directory.hasJoined('women'), false);
    });

    test(
      'repeated taps share one write and wait for server confirmation',
      () async {
        source.writeGate = Completer<void>();
        final first = directory.toggle(ministry('women', 'Women'));
        final second = directory.toggle(ministry('women', 'Women'));
        await Future<void>.delayed(Duration.zero);
        expect(source.joins, 1);
        expect(directory.hasJoined('women'), false);
        source.writeGate!.complete();
        expect(await first, true);
        expect(await second, true);
      },
    );

    test('a pending write cannot leak into a guest session', () async {
      source.writeGate = Completer<void>();
      final pending = directory.toggle(ministry('women', 'Women'));
      final result = expectLater(pending, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      await directory.useMember(null);
      source.writeGate!.complete();
      await result;
      expect(directory.hasJoined('women'), false);
    });

    test(
      'failed membership reads block writes until membership is known',
      () async {
        source.failRead = true;
        await directory.useMember(ama);
        await expectLater(
          directory.toggle(ministry('women', 'Women')),
          throwsStateError,
        );
        expect(source.joins, 0);
      },
    );
  });

  group('phone reminders', () {
    final clock = DateTime.utc(2026, 10, 14, 8);
    Event upcoming(String id, {int minutes = 180}) => event(
      id,
      'Service $id',
      branch: botwe,
      start: clock.add(Duration(minutes: minutes)),
    );
    late FailingScheduler scheduler;
    late MemoryReminderStore store;
    late EventReminders reminders;
    setUp(() {
      scheduler = FailingScheduler();
      store = MemoryReminderStore();
      reminders = EventReminders(
        scheduler: scheduler,
        store: store,
        clock: () => clock,
      );
    });
    tearDown(() => reminders.dispose());

    test('schedules one hour before and restores the saved state', () async {
      final item = upcoming('a');
      expect(await reminders.toggle(item), ReminderOutcome.hourBefore);
      expect(
        scheduler.scheduled.values.single.at,
        item.startsAt!.subtract(const Duration(hours: 1)),
      );
      final restored = EventReminders(
        scheduler: scheduler,
        store: store,
        clock: () => clock,
      );
      await restored.restore();
      expect(restored.isSet('a'), true);
      expect(await restored.toggle(item), ReminderOutcome.removed);
      expect(scheduler.scheduled, isEmpty);
      expect(store.saved, isEmpty);
      restored.dispose();
    });

    test(
      'near events remind at start and past events cannot be scheduled',
      () async {
        expect(
          await reminders.toggle(upcoming('near', minutes: 30)),
          ReminderOutcome.atStart,
        );
        expect(
          scheduler.scheduled.values.single.at,
          clock.add(const Duration(minutes: 30)),
        );
        expect(
          await reminders.toggle(upcoming('past', minutes: -1)),
          ReminderOutcome.started,
        );
        expect(store.saved, {'near'});
      },
    );

    test('denied permission never claims a reminder was set', () async {
      scheduler.granted = false;
      expect(await reminders.toggle(upcoming('a')), ReminderOutcome.denied);
      expect(reminders.isSet('a'), false);
      expect(scheduler.scheduled, isEmpty);
    });

    test(
      'rapid same and different event taps neither cancel nor lose reminders',
      () async {
        await Future.wait([
          reminders.toggle(upcoming('a')),
          reminders.toggle(upcoming('a')),
          reminders.toggle(upcoming('b')),
        ]);
        expect(store.saved, {'a', 'b'});
        expect(scheduler.scheduled, hasLength(2));
      },
    );

    test('schedule and cancel failures preserve honest state', () async {
      scheduler.failSchedule = true;
      await expectLater(reminders.toggle(upcoming('a')), throwsStateError);
      expect(reminders.isSet('a'), false);
      scheduler.failSchedule = false;
      await reminders.toggle(upcoming('a'));
      scheduler.failCancel = true;
      await expectLater(reminders.toggle(upcoming('a')), throwsStateError);
      expect(reminders.isSet('a'), true);
    });

    test('storage failure cancels the untracked notification', () async {
      final broken = EventReminders(
        scheduler: scheduler,
        store: FailingReminderStore(),
        clock: () => clock,
      );
      await expectLater(broken.toggle(upcoming('a')), throwsStateError);
      expect(broken.isSet('a'), false);
      expect(scheduler.scheduled, isEmpty);
      broken.dispose();
    });

    test(
      'complete lookup moves reminders and cancels removed events',
      () async {
        await reminders.toggle(upcoming('a'));
        await reminders.toggle(upcoming('b'));
        await reminders.resync(
          [],
          lookup: (ids) async {
            expect(ids, {'a', 'b'});
            return [upcoming('a', minutes: 240)];
          },
        );
        expect(store.saved, {'a'});
        expect(
          scheduler.scheduled.values.single.at,
          clock.add(const Duration(hours: 3)),
        );
        expect(
          scheduler.cancelled,
          contains(EventReminders.notificationId('b')),
        );
      },
    );

    test(
      'partial feed and failed lookup preserve another branch reminders',
      () async {
        await reminders.toggle(upcoming('a'));
        await reminders.resync([]);
        await reminders.resync(
          [],
          lookup: (_) async => throw StateError('Offline'),
        );
        expect(store.saved, {'a'});
        expect(scheduler.scheduled, hasLength(1));
      },
    );

    test(
      'resync cancels notifications for events that already started',
      () async {
        await reminders.toggle(upcoming('a'));
        await reminders.resync([upcoming('a', minutes: -1)]);
        expect(store.saved, isEmpty);
        expect(scheduler.scheduled, isEmpty);
      },
    );
  });
}
