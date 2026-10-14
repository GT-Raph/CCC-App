import 'package:ccc_app/models/event.dart';
import 'package:ccc_app/screens/main_screen.dart';
import 'package:ccc_app/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

Future<FakeEvents> pumpEvents(
  WidgetTester tester, {
  required List<Event> Function(String? branchId) results,
  Member? member = ama,
}) async {
  final source = FakeEvents(results);
  await Harness(events: source).pump(
    tester,
    MainScreen(member: member, initialTab: 1),
    size: const Size(430, 1600),
  );
  return source;
}

void main() {
  test('event dates read like the design', () {
    expect(
      eventDateLabel(DateTime(2026, 10, 19, 9)),
      '19th October 2026, 09:00 AM',
    );
    expect(eventDateLabel(DateTime(2026, 10, 1, 12, 30)), contains('1st'));
    expect(eventDateLabel(DateTime(2026, 10, 1, 12, 30)), endsWith('12:30 PM'));
    expect(eventDateLabel(DateTime(2026, 10, 22, 18)), startsWith('22nd'));
    expect(eventDateLabel(DateTime(2026, 10, 23, 18)), startsWith('23rd'));
    expect(eventDateLabel(DateTime(2026, 10, 12, 18)), startsWith('12th'));
  });

  test('event rows from Supabase', () {
    final parsed = Event.fromRow({
      'id': 'e1',
      'branch_id': botwe.id,
      'for_all_branches': true,
      'title': 'Harvest',
      'starts_at': '2026-10-19T09:00:00Z',
      'ends_at': null,
      'host': 'Rev. Kofi Mensah',
      'address': 'Ashaley Botwe',
      'description': 'Thanksgiving.',
      'image_paths': ['botwe/harvest.jpg'],
      'phone': '',
      'email': '',
      'website': '',
      'branches': {'name': 'CCC Botwe'},
    }, imageUrl: (path) => 'https://cdn.example/$path');

    expect(parsed.churchLabel, 'CCC Botwe, for all branches');
    expect(parsed.images, ['https://cdn.example/botwe/harvest.jpg']);
    expect(
      parsed.endsOrAssumed!.difference(parsed.startsAt!),
      const Duration(hours: 3),
    );
    final during = parsed.startsAt!.add(const Duration(hours: 1));
    expect(parsed.isOnAt(during), isTrue);
    expect(
      parsed.isOnAt(parsed.startsAt!.add(const Duration(hours: 4))),
      isFalse,
    );
  });

  testWidgets("members see their branch's events and all-branch events", (
    tester,
  ) async {
    final source = await pumpEvents(
      tester,
      results: (_) => [
        event(
          'ended',
          'Dawn Prayer',
          branch: botwe,
          start: now.subtract(const Duration(hours: 6)),
        ),
        event(
          'sunday',
          'Botwe Sunday Service',
          branch: botwe,
          start: now.add(const Duration(days: 1)),
        ),
        event(
          'convention',
          'Youth Convention',
          branch: westland,
          forAll: true,
          start: now.add(const Duration(days: 2)),
        ),
      ],
    );

    expect(source.requests, [botwe.id]);
    // The branch bar and the Sunday service's church row.
    expect(find.text('CCC Botwe'), findsNWidgets(2));
    expect(find.text('Botwe Sunday Service'), findsOneWidget);
    expect(find.text('Youth Convention'), findsOneWidget);
    expect(find.text('CCC Westland, for all branches'), findsOneWidget);
    expect(find.text('Dawn Prayer'), findsNothing);
    expect(find.text('Watch Live'), findsNothing);
  });

  testWidgets("a live branch stream turns its event into Watch Live", (
    tester,
  ) async {
    final source = await pumpEvents(
      tester,
      results: (_) => [
        event(
          'sunday',
          'Botwe Sunday Service',
          branch: botwe,
          start: now.subtract(const Duration(minutes: 10)),
        ),
      ],
    );
    expect(find.text('Remind Me'), findsOneWidget);

    source.streams.add([live(botwe)]);
    await tester.pumpAndSettle();
    expect(find.text('Watch Live'), findsOneWidget);
    expect(find.bySemanticsLabel('Live'), findsOneWidget);
    // Matched to the event, so no separate "is live now" card.
    expect(find.text('CCC Botwe is live now'), findsNothing);

    // A reading the checker hasn't refreshed in 30 minutes is not trusted.
    source.streams.add([
      live(
        botwe,
        checkedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Watch Live'), findsNothing);
    expect(find.text('Remind Me'), findsOneWidget);
  });

  testWidgets('a branch live outside any event shows at the top', (
    tester,
  ) async {
    final source = await pumpEvents(
      tester,
      results: (_) => [
        event(
          'next-week',
          'Botwe Sunday Service',
          branch: botwe,
          start: now.add(const Duration(days: 7)),
        ),
      ],
    );

    // Another branch being live doesn't concern a Botwe member.
    source.streams.add([live(westland)]);
    await tester.pumpAndSettle();
    expect(find.textContaining('is live now'), findsNothing);

    source.streams.add([live(westland), live(botwe)]);
    await tester.pumpAndSettle();
    expect(find.text('CCC Botwe is live now'), findsOneWidget);
    expect(find.text('CCC Botwe Sunday Service'), findsOneWidget);
    expect(find.text('Watch Live'), findsOneWidget);
  });

  testWidgets('guests see all-branch events until they choose a branch', (
    tester,
  ) async {
    final source = await pumpEvents(
      tester,
      member: null,
      results: (branchId) => [
        if (branchId == botwe.id)
          event(
            'sunday',
            'Botwe Sunday Service',
            branch: botwe,
            start: now.add(const Duration(days: 1)),
          ),
        event(
          'convention',
          'Youth Convention',
          branch: westland,
          forAll: true,
          start: now.add(const Duration(days: 2)),
        ),
      ],
    );

    expect(source.requests, [null]);
    expect(find.text('All branches'), findsOneWidget);
    expect(find.text('Youth Convention'), findsOneWidget);
    expect(find.text('Botwe Sunday Service'), findsNothing);

    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CCC Botwe'));
    await tester.pumpAndSettle();

    expect(source.requests, [null, botwe.id]);
    expect(find.text('Botwe Sunday Service'), findsOneWidget);
    expect(find.text('Youth Convention'), findsOneWidget);
  });
}
