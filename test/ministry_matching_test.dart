import 'package:ccc_app/models/admin_drafts.dart';
import 'package:ccc_app/models/member_details.dart';
import 'package:ccc_app/models/ministry.dart';
import 'package:ccc_app/screens/admin/editors.dart';
import 'package:ccc_app/screens/main_screen.dart';
import 'package:ccc_app/widgets/admin_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

/// Opens Home for Ama, a member of CCC Botwe, with [ministries].
Future<Harness> openHome(
  WidgetTester tester,
  FakeMinistries ministries, {
  int tab = 0,
}) async {
  final harness = Harness(ministries: ministries);
  await harness.pump(
    tester,
    MainScreen(member: ama, initialTab: tab),
    size: const Size(430, 932),
  );
  await tester.pumpAndSettle();
  return harness;
}

/// Scrolls the screen on top until [text] is built, then taps it.
Future<void> tapBelow(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// The text field under the label [label] on a staff form.
Finder field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(LabeledField)),
  matching: find.byType(TextField),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('details save the date of birth as a day, without a time zone', () {
    final details = MemberDetails(
      birthDate: DateTime(1994, 3, 7),
      gender: Gender.female,
      maritalStatus: MaritalStatus.married,
      student: false,
    );
    expect(details.toRow(), {
      'birth_date': '1994-03-07',
      'gender': 'female',
      'marital_status': 'married',
      'student': false,
    });
    final back = MemberDetails.fromRow(details.toRow());
    expect(back.birthDate, DateTime(1994, 3, 7));
    expect(back.gender, Gender.female);
    expect(back.maritalStatus, MaritalStatus.married);
    expect(back.student, isFalse);
    expect(MemberDetails.skipped.isEmpty, isTrue);
    expect(MemberDetails.skipped.toRow().values, everyElement(isNull));
  });

  test('members are told which ministries they were added to', () {
    expect(addedToMinistriesMessage(['Youth']), "You've been added to Youth.");
    expect(
      addedToMinistriesMessage(['Choir', 'Youth']),
      "You've been added to Choir and Youth.",
    );
    expect(
      addedToMinistriesMessage(['Choir', 'Ushers', 'Youth']),
      "You've been added to Choir, Ushers and Youth.",
    );
  });

  test('ministry rules save and load', () {
    final draft = MinistryDraft(
      name: 'Youth',
      addsMembers: true,
      minAge: 18,
      maxAge: 35,
      forMaritalStatuses: {MaritalStatus.widowed, MaritalStatus.single},
    );
    final row = draft.toRow();
    expect(row['auto_assign'], isTrue);
    expect(row['min_age'], 18);
    expect(row['max_age'], 35);
    expect(row['for_gender'], isNull);
    expect(row['for_marital_statuses'], ['single', 'widowed']);
    expect(row['for_students'], isNull);
    final back = MinistryDraft.fromRow({...row, 'id': 'm1'});
    expect(back.addsMembers, isTrue);
    expect(back.minAge, 18);
    expect(back.forMaritalStatuses, {
      MaritalStatus.single,
      MaritalStatus.widowed,
    });
    expect(back.hasRule, isTrue);
    expect(MinistryDraft().hasRule, isFalse);
  });

  testWidgets('a new member is asked about themselves and added to ministries', (
    tester,
  ) async {
    final ministries = FakeMinistries(
      details: null,
      matches: ['Youth Ministry', 'Kharis Ladies'],
    );
    await openHome(tester, ministries);
    expect(find.text('About you'), findsOneWidget);

    await tester.tap(find.text('Female'));
    await tester.tap(find.text('Single'));
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    await tapBelow(tester, 'Save');

    final saved = ministries.savedDetails.single;
    expect(saved.gender, Gender.female);
    expect(saved.maritalStatus, MaritalStatus.single);
    expect(saved.student, isTrue);
    expect(saved.birthDate, isNull);
    expect(find.text('About you'), findsNothing);
    expect(
      find.text("You've been added to Youth Ministry and Kharis Ladies."),
      findsOneWidget,
    );
  });

  testWidgets('members can skip, and are not asked again', (tester) async {
    final ministries = FakeMinistries(details: null);
    await openHome(tester, ministries);
    await tapBelow(tester, 'Skip for now');

    expect(find.text('About you'), findsNothing);
    expect(ministries.savedDetails.single.isEmpty, isTrue);
    expect(ministries.details, isNotNull);
  });

  testWidgets('members already asked are matched again when the app opens', (
    tester,
  ) async {
    final ministries = FakeMinistries(matches: ['Youth Ministry']);
    await openHome(tester, ministries);

    expect(find.text('About you'), findsNothing);
    expect(ministries.matchCalls, 1);
    expect(find.text("You've been added to Youth Ministry."), findsOneWidget);
  });

  testWidgets('members change their details from their account', (
    tester,
  ) async {
    final ministries = FakeMinistries(
      details: const MemberDetails(gender: Gender.male),
    );
    await openHome(tester, ministries);
    await tester.tap(find.bySemanticsLabel('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('About you'), findsOneWidget);
    expect(find.text('Skip for now'), findsNothing);
    // Tapping the picked answer again clears it.
    await tester.tap(find.text('Male'));
    await tester.tap(find.text('Married'));
    await tester.pumpAndSettle();
    await tapBelow(tester, 'Save');

    final saved = ministries.savedDetails.single;
    expect(saved.gender, isNull);
    expect(saved.maritalStatus, MaritalStatus.married);
    expect(find.text('Your details are saved.'), findsOneWidget);
  });

  testWidgets("leaving a ministry that adds members says it won't add them "
      'again', (tester) async {
    final ministries = FakeMinistries(
      results: (_) => const [
        Ministry(
          id: 'youth',
          name: 'Youth Ministry',
          focus: 'Ages 18 to 35',
          meets: '',
          venue: '',
          members: '',
          about: '',
          addsMembers: true,
        ),
      ],
      joinedIds: {'youth'},
    );
    await openHome(tester, ministries, tab: 3);
    await tester.tap(find.text('Joined'));
    await tester.pumpAndSettle();

    expect(
      find.text("You left Youth Ministry. You won't be added to it again."),
      findsOneWidget,
    );
  });

  testWidgets('staff set who a ministry is for', (tester) async {
    final admin = FakeAdmin()..role = const StaffRole();
    final harness = Harness(admin: admin);
    await harness.state.staff.useMember(ama);
    await harness.pump(
      tester,
      const MinistryEditor(),
      size: const Size(430, 3600),
    );
    await tester.enterText(find.byType(TextField).first, 'Youth Ministry');
    await tester.tap(find.text('Add members who qualify'));
    await tester.pumpAndSettle();

    // Switched on with no rules.
    await tester.tap(find.text('Add ministry'));
    await tester.pumpAndSettle();
    expect(
      find.text('Set at least one rule, or switch this off.'),
      findsOneWidget,
    );

    // Ages the wrong way round.
    await tester.enterText(field('From age'), '35');
    await tester.enterText(field('To age'), '18');
    await tester.tap(find.text('Add ministry'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter whole numbers from 0 to 120, youngest first.'),
      findsOneWidget,
    );
    expect(admin.saved, isEmpty);

    await tester.enterText(field('From age'), '18');
    await tester.enterText(field('To age'), '35');
    await tester.tap(find.text('Women'));
    await tester.tap(find.text('Single'));
    await tester.pump();
    await tester.tap(find.text('Widowed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add ministry'));
    await tester.pumpAndSettle();

    final values = admin.saved.single.values;
    expect(values['auto_assign'], isTrue);
    expect(values['min_age'], 18);
    expect(values['max_age'], 35);
    expect(values['for_gender'], 'female');
    expect(values['for_marital_statuses'], ['single', 'widowed']);
    expect(values['for_students'], isNull);
  });
}
