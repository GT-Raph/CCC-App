import 'package:ccc_app/models/sermon.dart';
import 'package:ccc_app/screens/main_screen.dart';
import 'package:ccc_app/screens/sign_up_screen.dart';
import 'package:ccc_app/services/auth_service.dart';
import 'package:ccc_app/services/sermon_service.dart';
import 'package:ccc_app/state/sermon_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'support/fakes.dart';

const sermonsTab = 4;

void main() {
  test('sermon labels', () {
    expect(botweSermons.first.dateLabel, '12 Oct 2026');
    expect(lengthLabel(const Duration(minutes: 48)), '48 min');
    expect(lengthLabel(const Duration(minutes: 65)), '1 h 5 min');
    expect(lengthLabel(const Duration(minutes: 120)), '2 h');
    expect(clockLabel(const Duration(minutes: 4, seconds: 5)), '4:05');
    expect(
      clockLabel(const Duration(hours: 1, minutes: 2, seconds: 9)),
      '1:02:09',
    );
    expect(botweSermons.last.matches('owusu'), isTrue);
    expect(botweSermons.last.matches('faith'), isFalse);
  });

  test("a member's branch comes from their account details", () {
    User user(Map<String, dynamic> metadata) => User(
      id: 'u1',
      appMetadata: const {},
      userMetadata: metadata,
      aud: 'authenticated',
      createdAt: '2026-10-14T00:00:00Z',
      email: 'ama@example.com',
    );

    final member = Member.fromUser(
      user({
        'first_name': 'Ama',
        'branch_id': 'b-botwe',
        'branch_name': 'CCC Botwe',
      }),
    );
    expect(member.branch, botwe);
    expect(member.branch!.name, 'CCC Botwe');
    expect(Member.fromUser(user({'first_name': 'Ama'})).branch, isNull);
  });

  test('a branch change during a load ignores the older results', () async {
    final library = SermonLibrary(
      source: FakeSermons(),
      guestStore: MemoryGuestStore(botwe),
    );
    await library.useListener(null);
    final first = library.refresh();
    await library.chooseBranch(westland);
    await first;

    expect(library.branch, westland);
    expect(library.sermons.single.title, 'Grace Abounds');
    expect(library.status, SermonStatus.ready);
  });

  testWidgets("members hear their branch's sermons, newest first", (
    tester,
  ) async {
    final harness = Harness();
    await harness.pump(
      tester,
      const MainScreen(member: ama, initialTab: sermonsTab),
    );

    expect(find.text('Sermons'), findsNWidgets(2));
    expect(find.text('CCC Botwe'), findsOneWidget);
    expect(harness.source.requested, [botwe.id]);
    final newest = find.text('Walking in Faith');
    final older = find.text('The Good Shepherd');
    expect(tester.getTopLeft(newest).dy, lessThan(tester.getTopLeft(older).dy));
    expect(find.text('12 Oct 2026'), findsOneWidget);
    expect(find.text('1 h 5 min'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'owusu');
    await tester.pump();
    expect(newest, findsNothing);
    expect(older, findsOneWidget);
  });

  testWidgets('sermons for every branch are labelled and credit the church', (
    tester,
  ) async {
    final harness = Harness(
      source: FakeSermons(
        forEveryBranch: [
          sermon('h1', null, 'One Church, One Voice', DateTime(2026, 10, 13)),
        ],
      ),
    );
    await harness.pump(
      tester,
      const MainScreen(member: ama, initialTab: sermonsTab),
    );

    expect(find.text('One Church, One Voice'), findsOneWidget);
    expect(find.text('Walking in Faith'), findsOneWidget);
    // Only the church-wide sermon carries the label.
    expect(find.text('All branches'), findsOneWidget);

    await tester.tap(find.text('One Church, One Voice'));
    await tester.pump();
    expect(harness.player.branchName, 'Calvary Charismatic Centre');
  });

  testWidgets('playing a sermon opens the mini player and full player', (
    tester,
  ) async {
    final harness = Harness();
    await harness.pump(
      tester,
      const MainScreen(member: ama, initialTab: sermonsTab),
    );

    await tester.tap(find.text('Walking in Faith'));
    await tester.pumpAndSettle();
    expect(harness.player.calls, ['play s2']);
    // The card and the mini player.
    expect(find.text('Walking in Faith'), findsNWidgets(2));
    expect(find.byTooltip('Close player'), findsOneWidget);

    // Tapping the playing sermon pauses it.
    await tester.tap(find.text('Walking in Faith').first);
    await tester.pumpAndSettle();
    expect(harness.player.calls.last, 'pause');

    await tester.tap(find.text('Walking in Faith').last);
    await tester.pumpAndSettle();
    expect(find.text('Notes for Walking in Faith.'), findsOneWidget);
    expect(find.text('Rev. Kofi Mensah'), findsWidgets);

    await tester.tap(find.bySemanticsLabel('Forward 30 seconds'));
    await tester.pump();
    expect(harness.player.calls.last, 'seek 30');
    await tester.tap(find.bySemanticsLabel('Playback speed 1×'));
    await tester.pump();
    expect(harness.player.speed, 1.25);
    expect(find.text('1.25×'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20)); // Close the sheet.
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close player'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close player'), findsNothing);
    expect(find.text('Walking in Faith'), findsOneWidget);
  });

  testWidgets('members without a branch are asked to choose one', (
    tester,
  ) async {
    final harness = Harness();
    await harness.pump(
      tester,
      const MainScreen(
        member: Member(firstName: 'Kwame', email: 'kwame@example.com'),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Choose your branch'), findsOneWidget);
    await tester.tap(find.text('CCC Westland'));
    await tester.pumpAndSettle();

    expect(harness.savedForMember, [westland]);
    expect(find.text('Your branch is now CCC Westland.'), findsOneWidget);
    await tester.tap(find.text('Sermons'));
    await tester.pumpAndSettle();
    expect(find.text('Grace Abounds'), findsOneWidget);
  });

  testWidgets('guests choose a branch to listen to, kept on the device', (
    tester,
  ) async {
    final harness = Harness();
    await harness.pump(tester, const MainScreen(initialTab: sermonsTab));

    expect(
      find.text('Choose your branch to hear its sermons.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Choose branch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CCC Botwe'));
    await tester.pumpAndSettle();

    expect(harness.guestStore.saved, botwe);
    expect(harness.savedForMember, isEmpty);
    expect(find.text('Walking in Faith'), findsOneWidget);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('the tab explains when sermons are not set up in Supabase', (
    tester,
  ) async {
    final harness = Harness(
      source: FakeSermons(
        failure: const ChurchDataException(
          'Sermons are not set up yet.',
          setupMissing: true,
        ),
      ),
    );
    await harness.pump(
      tester,
      const MainScreen(member: ama, initialTab: sermonsTab),
    );

    expect(find.text('Sermons are not set up yet.'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('sign up asks for a branch', (tester) async {
    final harness = Harness();
    await harness.pump(tester, const SignUpScreen());

    await tester.enterText(find.byType(TextField).at(0), 'Ama');
    await tester.enterText(find.byType(TextField).at(1), 'Owusu');
    await tester.enterText(find.byType(TextField).at(2), 'ama@example.com');
    await tester.enterText(find.byType(TextField).at(3), 'secret1');
    await tester.enterText(find.byType(TextField).at(4), 'secret1');
    await tester.tap(find.text('Sign up'));
    await tester.pump();
    expect(find.text('Choose your branch.'), findsOneWidget);

    await tester.tap(find.text('Your Branch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CCC Botwe'));
    await tester.pumpAndSettle();
    expect(find.text('Your Branch'), findsNothing);
    expect(find.text('CCC Botwe'), findsOneWidget);
  });
}
