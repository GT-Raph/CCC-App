import 'package:ccc_app/models/admin_drafts.dart';
import 'package:ccc_app/screens/admin/admin_lists.dart';
import 'package:ccc_app/screens/admin/editors.dart';
import 'package:ccc_app/screens/main_screen.dart';
import 'package:ccc_app/screens/news_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

const botweStaff = StaffRole(branchId: 'b-botwe');
const churchAdmin = StaffRole();

/// Pumps [home] for a signed-in member whose staff role is [role].
Future<Harness> pumpAs(
  WidgetTester tester,
  StaffRole? role,
  Widget home, {
  FakeAdmin? admin,
}) async {
  final harness = Harness(admin: (admin ?? FakeAdmin())..role = role);
  await harness.state.staff.useMember(ama);
  // Tall enough that the whole form is built at once.
  await harness.pump(tester, home, size: const Size(430, 2800));
  return harness;
}

/// Scrolls the form until [text] is built, then taps it.
Future<void> tapInForm(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Map<String, dynamic> newsRow({
  String id = 'n1',
  String title = 'Harvest Thanksgiving',
  String? branchId = 'b-botwe',
  DateTime? publishedAt,
}) => {
  'id': id,
  'branch_id': branchId,
  'title': title,
  'subtitle': '',
  'summary': 'A day of thanks.',
  'body': 'The full story.',
  'image_paths': ['2026/10/choir.jpg'],
  'published_at': (publishedAt ?? DateTime.now()).toUtc().toIso8601String(),
  'branches': branchId == null ? null : {'name': 'CCC Botwe'},
};

Map<String, dynamic> sermonRow() => {
  'id': 's1',
  'branch_id': 'b-botwe',
  'title': 'Walking in Faith',
  'preacher': 'Rev. Kofi Mensah',
  'preached_on': '2026-10-12',
  'description': '',
  'audio_path': '2026/10/faith.mp3',
  'duration_seconds': 2880,
};

void main() {
  test('branch staff manage only their own branch', () {
    expect(botweStaff.canManage('b-botwe'), isTrue);
    expect(botweStaff.canManage('b-westland'), isFalse);
    expect(botweStaff.canManage(null), isFalse, reason: 'church-wide content');
    expect(churchAdmin.canManage(null), isTrue);
    expect(churchAdmin.canManage('b-westland'), isTrue);
  });

  test('drafts save times in UTC and dates without a time zone', () {
    final news = NewsDraft(
      title: '  Harvest  ',
      publishedAt: DateTime.utc(2026, 10, 19, 9),
    ).toRow();
    expect(news['title'], 'Harvest');
    expect(news['published_at'], '2026-10-19T09:00:00.000Z');
    final sermon = SermonDraft(
      preachedOn: DateTime(2026, 3, 4),
      durationMinutes: 48,
    ).toRow();
    expect(sermon['preached_on'], '2026-03-04');
    expect(sermon['duration_seconds'], 48 * 60);
  });

  testWidgets('members never see staff buttons', (tester) async {
    await pumpAs(tester, null, const MainScreen(member: ama));
    expect(find.textContaining('New story'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Manage church content'), findsNothing);
  });

  testWidgets('branch staff post news for their own branch', (tester) async {
    final harness = await pumpAs(
      tester,
      botweStaff,
      const MainScreen(member: ama),
    );
    final newsLoads = harness.news.requests.length;

    await tester.tap(find.text('New story'));
    await tester.pumpAndSettle();
    expect(find.text('New story'), findsOneWidget);
    // The branch is fixed to their own.
    expect(find.text('CCC Botwe'), findsOneWidget);
    expect(
      find.text('Branch staff post for their own branch.'),
      findsOneWidget,
    );

    await tapInForm(tester, 'Publish');
    expect(find.text('Give the story a title.'), findsOneWidget);
    expect(harness.admin!.saved, isEmpty);

    await tester.enterText(find.byType(TextField).first, 'Youth Day');
    await tester.enterText(find.byType(TextField).at(2), 'Games and worship.');
    await tapInForm(tester, 'Publish');

    final saved = harness.admin!.saved.single;
    expect(saved.kind, ContentKind.news);
    expect(saved.id, isNull);
    expect(saved.values['title'], 'Youth Day');
    expect(saved.values['summary'], 'Games and worship.');
    expect(saved.values['branch_id'], 'b-botwe');
    expect(find.text('Published.'), findsOneWidget);
    // Back on Home, which reloaded the news.
    expect(find.text('News by church'), findsOneWidget);
    expect(harness.news.requests.length, greaterThan(newsLoads));
  });

  testWidgets('church-wide admins post news for every branch', (tester) async {
    final harness = await pumpAs(tester, churchAdmin, const NewsEditor());
    expect(find.text('All branches'), findsOneWidget);
    expect(find.text('Branch staff post for their own branch.'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Harvest');
    await tapInForm(tester, 'Publish');
    expect(harness.admin!.saved.single.values['branch_id'], isNull);
  });

  testWidgets('only church-wide admins can show an event to every branch', (
    tester,
  ) async {
    await pumpAs(tester, botweStaff, const EventEditor());
    expect(find.text('Show to every branch'), findsNothing);
  });

  testWidgets('admins see the every-branch switch on events', (tester) async {
    await pumpAs(tester, churchAdmin, const EventEditor());
    await tester.scrollUntilVisible(
      find.text('Show to every branch'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Show to every branch'), findsOneWidget);
  });

  testWidgets('branch staff keep sermons to their own branch', (tester) async {
    await pumpAs(
      tester,
      botweStaff,
      const SermonEditor(id: 's1'),
      admin: FakeAdmin(
        rows: {
          ContentKind.sermons: [sermonRow()],
        },
      ),
    );
    expect(find.text('CCC Botwe'), findsOneWidget);
    expect(
      find.text('Branch staff post for their own branch.'),
      findsOneWidget,
    );
    expect(find.text('All branches'), findsNothing);
  });

  testWidgets('HQ admins post a sermon for every branch', (tester) async {
    final admin = FakeAdmin(
      rows: {
        ContentKind.sermons: [sermonRow()],
      },
    );
    await pumpAs(
      tester,
      churchAdmin,
      const SermonEditor(id: 's1'),
      admin: admin,
    );
    await tapInForm(tester, 'CCC Botwe');
    await tester.tap(find.text('All branches'));
    await tester.pumpAndSettle();
    await tapInForm(tester, 'Save changes');
    expect(admin.saved.single.id, 's1');
    expect(admin.saved.single.values['branch_id'], isNull);
    expect(admin.saved.single.values['audio_path'], '2026/10/faith.mp3');
  });

  testWidgets('staff edit and delete existing news from the list', (
    tester,
  ) async {
    final admin = FakeAdmin(
      rows: {
        ContentKind.news: [
          newsRow(),
          newsRow(
            id: 'n2',
            title: 'Next week',
            publishedAt: DateTime.now().add(const Duration(days: 7)),
          ),
          // Another branch's story isn't listed for Botwe staff.
          newsRow(id: 'n3', title: 'Westland only', branchId: 'b-westland'),
        ],
      },
    );
    await pumpAs(
      tester,
      botweStaff,
      const AdminListScreen(kind: ContentKind.news),
      admin: admin,
    );
    expect(find.text('Harvest Thanksgiving'), findsOneWidget);
    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.text('Westland only'), findsNothing);

    await tester.tap(find.text('Harvest Thanksgiving'));
    await tester.pumpAndSettle();
    expect(find.text('Edit story'), findsOneWidget);
    expect(find.text('Harvest Thanksgiving'), findsOneWidget);
    expect(find.text('Cover'), findsOneWidget, reason: 'the saved photo');

    await tester.enterText(find.byType(TextField).first, 'Harvest 2026');
    await tapInForm(tester, 'Save changes');
    expect(admin.saved.single.id, 'n1');
    expect(admin.saved.single.values['title'], 'Harvest 2026');
    expect(admin.saved.single.values['image_paths'], ['2026/10/choir.jpg']);

    await tester.tap(find.text('Next week'));
    await tester.pumpAndSettle();
    await tapInForm(tester, 'Delete story');
    expect(find.text('Delete this story?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(admin.deleted.single.id, 'n2');
    expect(admin.removed, ['2026/10/choir.jpg']);
  });

  testWidgets('leaving with unsaved changes asks first', (tester) async {
    final harness = await pumpAs(tester, botweStaff, const AdminHomeScreen());
    await tester.tap(find.text('News'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New story'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Draft');
    await tester.pump();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Draft'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Draft'), findsNothing);
    expect(harness.admin!.saved, isEmpty);
  });

  testWidgets('only church-wide admins manage staff', (tester) async {
    await pumpAs(tester, botweStaff, const AdminHomeScreen());
    expect(find.text('Staff'), findsNothing);
  });

  testWidgets('church-wide admins add staff by email', (tester) async {
    final admin = FakeAdmin()
      ..staffList.add(const StaffMember(email: 'ama@example.com'));
    await pumpAs(tester, churchAdmin, const AdminHomeScreen(), admin: admin);
    await tester.tap(find.text('Staff'));
    await tester.pumpAndSettle();

    // Their own row can't be removed.
    expect(find.text('You'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Media@Botwe.org');
    await tester.tap(find.text('Every branch (HQ admin)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CCC Botwe').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add staff'));
    await tester.pumpAndSettle();

    expect(admin.added.single.email, 'media@botwe.org');
    expect(admin.added.single.branchId, 'b-botwe');
    expect(find.text('CCC Botwe staff'), findsNothing);
    expect(find.text('media@botwe.org'), findsOneWidget);
  });

  testWidgets('details show Edit only for content the staff member manages', (
    tester,
  ) async {
    final item = newsItem('n1', 'Botwe Youth Day', church: 'CCC Botwe');
    await pumpAs(tester, botweStaff, NewsDetailsScreen(item: item));
    // Church-wide news: Botwe staff can't edit it.
    expect(find.text('Edit story'), findsNothing);
  });

  testWidgets('ministry staff see who has joined', (tester) async {
    final admin =
        FakeAdmin(
            rows: {
              ContentKind.ministries: [
                {
                  'id': 'm1',
                  'branch_id': 'b-botwe',
                  'name': 'Botwe Choir',
                  'focus': '',
                  'meets': '',
                  'venue': '',
                  'members_label': '',
                  'about': '',
                  'image_paths': <String>[],
                  'sort_order': 0,
                },
              ],
            },
          )
          ..signupList = [
            Signup(
              member: 'Ama Owusu',
              branch: 'CCC Botwe',
              joinedAt: DateTime(2026, 10, 12),
            ),
          ];
    await pumpAs(
      tester,
      botweStaff,
      const MinistryEditor(id: 'm1'),
      admin: admin,
    );
    await tester.tap(find.text('See who has joined'));
    await tester.pumpAndSettle();
    expect(find.text('1 member'), findsOneWidget);
    expect(find.text('Ama Owusu'), findsOneWidget);
  });
}
