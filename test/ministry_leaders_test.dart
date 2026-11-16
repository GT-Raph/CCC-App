import 'dart:convert';

import 'package:ccc_app/models/admin_drafts.dart';
import 'package:ccc_app/screens/admin/admin_lists.dart';
import 'package:ccc_app/screens/admin/editors.dart';
import 'package:ccc_app/services/admin_service.dart';
import 'package:ccc_app/services/church_query.dart';
import 'package:ccc_app/widgets/admin_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fakes.dart';

Map<String, dynamic> ministry(String id, String name, String? branch) => {
  'id': id,
  'name': name,
  'branch_id': branch,
  'branches': branch == null ? null : {'name': branch},
};

class LeaderAdmin extends FakeAdmin {
  LeaderAdmin({super.role})
    : super(
        rows: {
          ContentKind.ministries: [
            ministry('choir', 'Choir', 'b-botwe'),
            ministry('youth', 'Youth', 'b-westland'),
            ministry('prayer', 'Prayer', null),
          ],
        },
      );
  bool failAdd = false;
  bool failRead = false;

  @override
  Future<void> addLeader(String ministryId, String email) async {
    if (failAdd) throw const ChurchDataException('Leader could not be added.');
    await super.addLeader(ministryId, email);
  }

  @override
  Future<List<String>> leaders(String ministryId) async {
    if (failRead) throw const ChurchDataException('Leaders could not load.');
    return super.leaders(ministryId);
  }
}

Finder emailField() => find.descendant(
  of: find.ancestor(
    of: find.text("Leader's sign-in email"),
    matching: find.byType(LabeledField),
  ),
  matching: find.byType(TextField),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'a refused removal is reported instead of appearing successful',
    () async {
      final client = SupabaseClient(
        'https://church.example',
        'test-key',
        httpClient: MockClient(
          (request) async => http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        AdminService(client).removeLeader('choir', 'leader@church.org'),
        throwsA(isA<ChurchDataException>()),
      );
    },
  );

  for (final target in [('youth', 'Youth'), ('prayer', 'Prayer')]) {
    testWidgets(
      'super admin appoints a ${target.$2} leader from the admin hub',
      (tester) async {
        final admin = LeaderAdmin(role: const StaffRole(superAdmin: true));
        final harness = Harness(admin: admin);
        await harness.state.staff.useMember(ama);
        await harness.pump(tester, const AdminHomeScreen());
        await tester.ensureVisible(find.text('Ministry leaders'));
        await tester.tap(find.text('Ministry leaders'));
        await tester.pumpAndSettle();
        expect(find.text('Choir'), findsOneWidget);
        expect(find.text('Youth'), findsOneWidget);
        expect(find.text('Prayer'), findsOneWidget);
        await tester.tap(find.text(target.$2));
        await tester.pumpAndSettle();
        expect(find.text('Save changes'), findsNothing);
        expect(find.text('Name'), findsNothing);
        await tester.enterText(emailField(), ' Leader@Church.org ');
        await tester.tap(find.text('Add leader'));
        await tester.pumpAndSettle();
        expect(admin.leadersByMinistry[target.$1], ['leader@church.org']);
        expect(find.text('leader@church.org'), findsOneWidget);
        expect(
          admin.saved,
          isEmpty,
          reason: 'Appointments never rewrite ministry content.',
        );
        await tester.enterText(emailField(), 'leader@church.org');
        await tester.tap(find.text('Add leader'));
        await tester.pumpAndSettle();
        expect(find.text('This person is already a leader.'), findsOneWidget);
        expect(admin.leadersByMinistry[target.$1], hasLength(1));
      },
    );
  }

  testWidgets(
    'branch staff see only their ministries and cannot use another ministry route',
    (tester) async {
      final admin = LeaderAdmin(role: const StaffRole(branchId: 'b-botwe'));
      final harness = Harness(admin: admin);
      await harness.state.staff.useMember(ama);
      await harness.pump(
        tester,
        const AdminListScreen(kind: ContentKind.ministries, leadersOnly: true),
      );
      expect(find.text('Choir'), findsOneWidget);
      expect(find.text('Youth'), findsNothing);
      expect(find.text('Prayer'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await harness.pump(
        tester,
        const MinistryEditor(id: 'youth', leadersOnly: true),
      );
      expect(
        find.text(
          "You don't have permission to appoint leaders for this ministry.",
        ),
        findsOneWidget,
      );
      expect(find.text('Add leader'), findsNothing);
    },
  );

  testWidgets('ministry leaders cannot appoint other leaders', (tester) async {
    final admin = LeaderAdmin()
      ..ruleMinistries = [ministry('choir', 'Choir', 'b-botwe')];
    final harness = Harness(admin: admin);
    await harness.state.staff.useMember(ama);
    await harness.pump(
      tester,
      const MinistryEditor(id: 'choir', leadersOnly: true),
    );
    expect(find.text('Add leader'), findsNothing);
    expect(
      find.text(
        "You don't have permission to appoint leaders for this ministry.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('a failed appointment preserves the email for retry', (
    tester,
  ) async {
    final admin = LeaderAdmin(role: const StaffRole(superAdmin: true))
      ..failAdd = true;
    final harness = Harness(admin: admin);
    await harness.state.staff.useMember(ama);
    await harness.pump(
      tester,
      const MinistryEditor(id: 'choir', leadersOnly: true),
    );
    await tester.enterText(emailField(), 'leader@church.org');
    await tester.tap(find.text('Add leader'));
    await tester.pumpAndSettle();
    expect(find.text('Leader could not be added.'), findsOneWidget);
    expect(
      tester.widget<TextField>(emailField()).controller!.text,
      'leader@church.org',
    );
    expect(admin.leadersByMinistry, isEmpty);
    admin.failAdd = false;
    await tester.tap(find.text('Add leader'));
    await tester.pumpAndSettle();
    expect(admin.leadersByMinistry['choir'], ['leader@church.org']);
  });

  testWidgets('failed leader reads offer retry', (tester) async {
    final admin = LeaderAdmin(role: const StaffRole(superAdmin: true))
      ..failRead = true;
    admin.leadersByMinistry['choir'] = ['existing@church.org'];
    final harness = Harness(admin: admin);
    await harness.state.staff.useMember(ama);
    await harness.pump(
      tester,
      const MinistryEditor(id: 'choir', leadersOnly: true),
    );
    expect(find.text('Retry loading leaders'), findsOneWidget);
    admin.failRead = false;
    await tester.tap(find.text('Retry loading leaders'));
    await tester.pumpAndSettle();
    expect(find.text('existing@church.org'), findsOneWidget);
  });

  test(
    'adding a leader uses insert permissions and ignores duplicate assignments',
    () async {
      late http.Request sent;
      final client = SupabaseClient(
        'https://church.example',
        'test-key',
        httpClient: MockClient((request) async {
          sent = request;
          return http.Response('', 201, request: request);
        }),
      );
      addTearDown(client.dispose);
      await AdminService(client).addLeader('choir', ' Leader@Church.org ');
      expect(sent.method, 'POST');
      expect(sent.url.path, '/rest/v1/ministry_leaders');
      expect(sent.url.queryParameters['on_conflict'], 'ministry_id,email');
      expect(sent.headers['Prefer'], contains('resolution=ignore-duplicates'));
      expect(jsonDecode(sent.body), {
        'ministry_id': 'choir',
        'email': 'leader@church.org',
      });
    },
  );
}
