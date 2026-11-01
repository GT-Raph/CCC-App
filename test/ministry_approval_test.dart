import 'package:ccc_app/models/admin_drafts.dart';
import 'package:ccc_app/models/ministry.dart';
import 'package:ccc_app/screens/admin/editors.dart';
import 'package:ccc_app/screens/main_screen.dart';
import 'package:ccc_app/widgets/admin_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

const ministriesTab = 3;

const choir = Ministry(
  id: 'choir',
  name: 'Choir',
  focus: 'Singers and musicians',
  meets: '',
  venue: '',
  members: '',
  about: '',
  needsApproval: true,
);

/// Opens the app for Ama, a member of CCC Botwe.
Future<Harness> openApp(
  WidgetTester tester, {
  FakeMinistries? ministries,
  FakeAdmin? admin,
  int tab = 0,
}) async {
  final harness = Harness(ministries: ministries, admin: admin);
  await harness.pump(
    tester,
    MainScreen(member: ama, initialTab: tab),
    size: const Size(430, 932),
  );
  await tester.pumpAndSettle();
  return harness;
}

FakeMinistries choirOnly() => FakeMinistries(results: (_) => const [choir]);

/// The text field under the label [label] on a staff form.
Finder field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(LabeledField)),
  matching: find.byType(TextField),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('members ask to join a ministry that approves its members', (
    tester,
  ) async {
    final ministries = choirOnly();
    await openApp(tester, ministries: ministries, tab: ministriesTab);

    await tester.tap(find.text('Ask to join'));
    await tester.pumpAndSettle();
    expect(
      find.text('Request sent. A leader of Choir will answer it.'),
      findsOneWidget,
    );
    expect(find.text('Requested'), findsOneWidget);
    expect(ministries.requestStates, {'choir': RequestState.pending});
    expect(ministries.joinedIds, isEmpty);

    // Withdrawing asks first.
    await tester.tap(find.text('Requested'));
    await tester.pumpAndSettle();
    expect(find.text('Withdraw your request?'), findsOneWidget);
    await tester.tap(find.text('Withdraw'));
    await tester.pumpAndSettle();
    expect(find.text('Your request to join Choir is withdrawn.'), findsOneWidget);
    expect(find.text('Ask to join'), findsOneWidget);
    expect(ministries.requestStates, isEmpty);
  });

  testWidgets('a declined request shows on the ministry, and can be asked again', (
    tester,
  ) async {
    final ministries = choirOnly()
      ..requestStates['choir'] = RequestState.declined;
    await openApp(tester, ministries: ministries, tab: ministriesTab);
    expect(find.text('Ask to join'), findsOneWidget);

    await tester.tap(find.text('Choir'));
    await tester.pumpAndSettle();
    expect(
      find.text("Your last request wasn't approved. You can ask again."),
      findsOneWidget,
    );
    expect(find.text('A leader approves new members.'), findsOneWidget);
    await tester.tap(find.text('Ask to join'));
    await tester.pumpAndSettle();
    expect(find.text('Requested'), findsOneWidget);
    expect(ministries.requestStates, {'choir': RequestState.pending});
  });

  testWidgets('leaving a ministry that approves its members asks first', (
    tester,
  ) async {
    final ministries = FakeMinistries(
      results: (_) => const [choir],
      joinedIds: {'choir'},
    );
    await openApp(tester, ministries: ministries, tab: ministriesTab);

    await tester.tap(find.text('Joined'));
    await tester.pumpAndSettle();
    expect(find.text('Leave Choir?'), findsOneWidget);
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('You left Choir.'), findsOneWidget);
    expect(ministries.joinedIds, isEmpty);
  });

  testWidgets('leaders are told about requests and answer them', (
    tester,
  ) async {
    final admin = FakeAdmin()
      ..approvals = [
        const ApprovalMinistry(id: 'choir', name: 'Choir', waiting: 0),
      ]
      ..requestsByMinistry['choir'] = [
        JoinRequest(
          memberId: 'kofi',
          member: 'Kofi Mensah',
          branch: 'CCC Botwe',
          requestedAt: DateTime(2026, 10, 28),
        ),
        JoinRequest(
          memberId: 'efua',
          member: 'Efua Boateng',
          requestedAt: DateTime(2026, 10, 29),
        ),
      ];
    await openApp(tester, admin: admin);

    expect(
      find.text('2 requests to join are waiting for your answer.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('Join requests'), findsOneWidget);
    expect(find.text('Kofi Mensah'), findsOneWidget);
    expect(find.text('CCC Botwe · Asked 28 Oct'), findsOneWidget);
    expect(find.text('Asked 29 Oct'), findsOneWidget);

    await tester.tap(find.text('Approve').first);
    await tester.pumpAndSettle();
    expect(admin.answered.single, (
      ministryId: 'choir',
      memberId: 'kofi',
      approve: true,
    ));
    expect(find.text('Kofi Mensah is now in Choir.'), findsOneWidget);
    expect(find.text('Kofi Mensah'), findsNothing);

    // Declining asks first.
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(find.text("Decline Efua Boateng's request?"), findsOneWidget);
    await tester.tap(find.text('Decline').last);
    await tester.pumpAndSettle();
    expect(admin.answered.last, (
      ministryId: 'choir',
      memberId: 'efua',
      approve: false,
    ));
    expect(
      find.text(
        'No one is waiting. New requests to join your ministries appear '
        'here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('only those who answer requests see Join requests', (
    tester,
  ) async {
    await openApp(tester, admin: FakeAdmin());
    await tester.tap(find.bySemanticsLabel('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Join requests'), findsNothing);
  });

  testWidgets('leaders find Join requests in their account', (tester) async {
    final admin = FakeAdmin()
      ..approvals = [
        const ApprovalMinistry(id: 'choir', name: 'Choir', waiting: 0),
      ];
    await openApp(tester, admin: admin);
    await tester.tap(find.bySemanticsLabel('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Join requests'), findsOneWidget);
    expect(find.text('None waiting'), findsOneWidget);
  });

  testWidgets('staff choose leaders and whether a ministry approves members', (
    tester,
  ) async {
    final admin = FakeAdmin(
      rows: {
        ContentKind.ministries: [
          {
            'id': 'm1',
            'branch_id': null,
            'name': 'Choir',
            'image_paths': <String>[],
            'sort_order': 0,
            'needs_approval': false,
          },
        ],
      },
    )..role = const StaffRole();
    admin.leadersByMinistry['m1'] = ['alto@example.org'];
    final harness = Harness(admin: admin);
    await harness.state.staff.useMember(ama);
    await harness.pump(
      tester,
      const MinistryEditor(id: 'm1'),
      size: const Size(430, 3600),
    );
    await tester.pumpAndSettle();

    // Approving and adding automatically exclude each other.
    await tester.tap(find.text('Add members who qualify'));
    await tester.pumpAndSettle();
    expect(find.text('From age'), findsOneWidget);
    await tester.tap(find.text('Leader approves new members'));
    await tester.pumpAndSettle();
    expect(find.text('From age'), findsNothing);
    expect(find.text('alto@example.org'), findsOneWidget);

    await tester.enterText(field("Leader's sign-in email"), 'Bass@Example.org');
    await tester.tap(find.text('Add leader'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove alto@example.org'));
    await tester.pumpAndSettle();
    expect(admin.leadersByMinistry['m1'], ['bass@example.org']);
    expect(find.text('bass@example.org'), findsOneWidget);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    final values = admin.saved.single.values;
    expect(values['needs_approval'], isTrue);
    expect(values['auto_assign'], isFalse);
  });
}
