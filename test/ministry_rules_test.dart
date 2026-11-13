import 'package:ccc_app/models/admin_drafts.dart';
import 'package:ccc_app/models/member_details.dart';
import 'package:ccc_app/models/ministry.dart';
import 'package:ccc_app/screens/admin/admin_lists.dart';
import 'package:ccc_app/screens/admin/editors.dart';
import 'package:ccc_app/screens/main_screen.dart';
import 'package:ccc_app/screens/ministry_details_screen.dart';
import 'package:ccc_app/services/church_query.dart';
import 'package:ccc_app/widgets/admin_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

Map<String, dynamic> ministryRow() => {
  'id': 'youth',
  'name': 'Youth Ministry',
  'branch_id': 'b-botwe',
  'about': 'Existing ministry description',
  'auto_assign': true,
  'min_age': 18,
  'max_age': 35,
  'for_gender': 'female',
  'for_marital_statuses': ['single'],
  'for_students': null,
  'needs_approval': false,
};

FakeAdmin leader() => FakeAdmin(
  rows: {
    ContentKind.ministries: [ministryRow()],
  },
)..ruleMinistries = [ministryRow()];

Finder field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(LabeledField)),
  matching: find.byType(TextField),
);

class FailingRulesAdmin extends FakeAdmin {
  FailingRulesAdmin()
    : super(
        rows: {
          ContentKind.ministries: [ministryRow()],
        },
      ) {
    ruleMinistries = [ministryRow()];
  }

  bool fail = true;

  @override
  Future<void> saveMinistryRules(String ministryId, MinistryDraft rules) async {
    if (fail) throw const ChurchDataException('Requirements could not save.');
    await super.saveMinistryRules(ministryId, rules);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('leaders add a requirement while retaining the existing rules', (
    tester,
  ) async {
    final admin = leader();
    final harness = Harness(admin: admin);
    await harness.state.staff.useMember(ama);
    await harness.pump(
      tester,
      const MinistryEditor(id: 'youth', rulesOnly: true),
      size: const Size(430, 1800),
    );

    expect(tester.widget<TextField>(field('From age')).controller!.text, '18');
    expect(tester.widget<TextField>(field('To age')).controller!.text, '35');
    expect(find.text('Delete ministry'), findsNothing);
    expect(find.text('See who has joined'), findsNothing);
    expect(find.text('Photos'), findsNothing);
    expect(find.text("Leader's sign-in email"), findsNothing);
    expect(find.text('Name'), findsNothing);
    await tester.tap(find.text('Students only'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(admin.saved, isEmpty, reason: 'Leaders use the limited rules API.');
    final saved = admin.savedRules.single;
    expect(saved.id, 'youth');
    expect(saved.rules.addsMembers, isTrue);
    expect(saved.rules.needsApproval, isFalse);
    expect(saved.rules.minAge, 18);
    expect(saved.rules.maxAge, 35);
    expect(saved.rules.forGender, Gender.female);
    expect(saved.rules.forMaritalStatuses, {MaritalStatus.single});
    expect(saved.rules.forStudents, isTrue);
    expect(admin.uploads, isEmpty);
    expect(admin.removed, isEmpty);
  });

  testWidgets('leaders cannot open another ministry requirements form', (
    tester,
  ) async {
    final admin = leader()..ruleMinistries = [];
    final harness = Harness(admin: admin);
    await harness.state.staff.useMember(ama);
    await harness.pump(
      tester,
      const MinistryEditor(id: 'youth', rulesOnly: true),
    );
    expect(
      find.text("You don't have permission to change these requirements."),
      findsOneWidget,
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(admin.savedRules, isEmpty);
    expect(find.text('From age'), findsNothing);
  });

  testWidgets('a failed save keeps the entered requirements for retry', (
    tester,
  ) async {
    final admin = FailingRulesAdmin();
    final harness = Harness(admin: admin);
    await harness.state.staff.useMember(ama);
    await harness.pump(
      tester,
      const MinistryEditor(id: 'youth', rulesOnly: true),
      size: const Size(430, 1800),
    );
    await tester.enterText(field('From age'), '21');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Requirements could not save.'), findsOneWidget);
    expect(tester.widget<TextField>(field('From age')).controller!.text, '21');
    expect(admin.savedRules, isEmpty);
    admin.fail = false;
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(admin.savedRules.single.rules.minAge, 21);
  });

  testWidgets(
    'leaders find requirements in Account without an approval queue',
    (tester) async {
      final harness = Harness(admin: leader());
      await harness.pump(
        tester,
        const MainScreen(member: ama),
        size: const Size(430, 1100),
      );
      await tester.tap(find.bySemanticsLabel('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Join requests'), findsNothing);
      expect(find.text('Manage church content'), findsNothing);
      expect(find.text('Membership requirements'), findsOneWidget);
      await tester.tap(find.text('Edit').last);
      await tester.pumpAndSettle();
      expect(find.byType(AdminListScreen), findsOneWidget);
      expect(find.text('New ministry'), findsNothing);
      await tester.tap(find.text('Youth Ministry'));
      await tester.pumpAndSettle();
      expect(find.byType(MinistryEditor), findsOneWidget);
      expect(find.text('From age'), findsOneWidget);
    },
  );

  testWidgets('assigned leaders see requirements on ministry details', (
    tester,
  ) async {
    final harness = Harness(admin: leader());
    await harness.state.staff.useMember(ama);
    final ministry = Ministry.fromRow(ministryRow(), imageUrl: (path) => path);
    await harness.pump(
      tester,
      MinistryDetailsScreen(ministry: ministry, member: ama),
    );
    expect(find.text('Membership requirements'), findsOneWidget);
    expect(find.text('Edit ministry'), findsNothing);
    await harness.state.staff.useMember(null);
    await tester.pumpAndSettle();
    expect(find.text('Membership requirements'), findsNothing);
    expect(harness.state.staff.ruleMinistryIds, isEmpty);
  });

  testWidgets('a freshly assigned ministry opens after the list refreshes', (
    tester,
  ) async {
    final admin = leader()..ruleMinistries = [];
    final harness = Harness(admin: admin);
    await harness.state.staff.useMember(ama);
    admin.ruleMinistries = [ministryRow()];
    await harness.pump(
      tester,
      const AdminListScreen(kind: ContentKind.ministries, rulesOnly: true),
    );
    await tester.tap(find.text('Youth Ministry'));
    await tester.pumpAndSettle();
    expect(find.text('From age'), findsOneWidget);
    expect(harness.state.staff.ruleMinistryIds, {'youth'});
  });

  testWidgets(
    'the account sheet scrolls when staff have all ministry actions',
    (tester) async {
      final admin = leader()
        ..role = const StaffRole()
        ..approvals = [
          const ApprovalMinistry(
            id: 'youth',
            name: 'Youth Ministry',
            waiting: 0,
          ),
        ];
      final harness = Harness(admin: admin);
      await harness.pump(
        tester,
        const MainScreen(member: ama),
        size: const Size(390, 700),
      );
      await tester.tap(find.bySemanticsLabel('Account'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('staff can assign leaders to an automatic ministry', (
    tester,
  ) async {
    final admin = leader()..role = const StaffRole();
    final harness = Harness(admin: admin);
    await harness.state.staff.useMember(ama);
    await harness.pump(
      tester,
      const MinistryEditor(id: 'youth'),
      size: const Size(430, 3800),
    );
    await tester.enterText(
      field("Leader's sign-in email"),
      'Leader@Example.org',
    );
    await tester.tap(find.text('Add leader'));
    await tester.pumpAndSettle();
    expect(admin.leadersByMinistry['youth'], ['leader@example.org']);
    expect(find.text('From age'), findsOneWidget);
  });
}
