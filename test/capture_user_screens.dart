// Exports actual Flutter widgets, with test-only sample data and bundled fonts.
// Run: flutter test --no-pub test/capture_user_screens.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ccc_app/models/admin_drafts.dart';
import 'package:ccc_app/models/branch.dart';
import 'package:ccc_app/screens/admin/editors.dart';
import 'package:ccc_app/screens/event_details_screen.dart';
import 'package:ccc_app/screens/join_requests_screen.dart';
import 'package:ccc_app/screens/login_screen.dart';
import 'package:ccc_app/screens/main_screen.dart';
import 'package:ccc_app/screens/member_details_screen.dart';
import 'package:ccc_app/screens/ministry_details_screen.dart';
import 'package:ccc_app/screens/sign_up_screen.dart';
import 'package:ccc_app/screens/welcome_screen.dart';
import 'package:ccc_app/services/places_service.dart';
import 'package:ccc_app/state/branch_directory.dart';
import 'package:ccc_app/state/ccc_state.dart';
import 'package:ccc_app/state/event_reminders.dart';
import 'package:ccc_app/state/sermon_library.dart';
import 'package:ccc_app/theme/ccc_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

const outputDirectory = 'artifacts/user-screens';
const phoneSize = Size(430, 932);

class PreviewBranches extends BranchDirectory {
  PreviewBranches()
    : super(places: PlacesService(apiKey: 'unused-preview-key')) {
    status = BranchStatus.ready;
    branches = const [
      Branch(
        id: 'b-botwe',
        name: 'CCC Botwe',
        address: 'Ashaley Botwe, Accra',
        latitude: 5.70,
        longitude: -0.15,
        mapsUri: 'https://maps.google.com/',
      ),
      Branch(
        id: 'b-westland',
        name: 'CCC Westland',
        address: 'Westland, Accra',
        latitude: 5.67,
        longitude: -0.20,
        mapsUri: 'https://maps.google.com/',
      ),
    ];
  }

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> refresh() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final textFonts = FontLoader('OpenSans');
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      textFonts.addFont(rootBundle.load('assets/fonts/OpenSans-$weight.ttf'));
    }
    await textFonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await Directory(outputDirectory).create(recursive: true);
  });

  testWidgets('export the member screens and ministry leader screens', (
    tester,
  ) async {
    tester.view.physicalSize = phoneSize * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final events = FakeEvents();
    final admin = FakeAdmin();
    final state = CccState(
      branches: PreviewBranches(),
      sermons: SermonLibrary(
        source: FakeSermons(),
        guestStore: MemoryGuestStore(botwe),
        saveMemberBranch: (_) async {},
      ),
      player: FakePlayer(),
      eventSource: events,
      newsSource: FakeNews(),
      ministrySource: FakeMinistries(joinedIds: {'youth'}),
      reminders: EventReminders(
        scheduler: FakeScheduler(),
        store: MemoryReminderStore(),
      ),
      adminSource: admin,
    );
    addTearDown(events.streams.close);
    addTearDown(state.dispose);
    var captureKey = GlobalKey();

    Future<void> screen(Widget home) async {
      captureKey = GlobalKey();
      await tester.pumpWidget(
        CccScope(
          state: state,
          child: RepaintBoundary(
            key: captureKey,
            child: MaterialApp(
              key: UniqueKey(),
              debugShowCheckedModeBanner: false,
              theme: buildCccTheme(),
              home: home,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final context = tester.element(find.byType(Scaffold).first);
        await precacheImage(
          const AssetImage('assets/images/church_logo.png'),
          context,
        );
        if (!context.mounted) return;
        await precacheImage(
          const AssetImage('assets/images/church_logo_light.png'),
          context,
        );
        if (!context.mounted) return;
        await precacheImage(
          const AssetImage('assets/images/welcome_background.jpg'),
          context,
        );
      });
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final rendered = await boundary.toImage(pixelRatio: 2);
        final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$outputDirectory/$name.png',
        ).writeAsBytes(png!.buffer.asUint8List());
        rendered.dispose();
      });
      expect(tester.takeException(), isNull, reason: name);
    }

    await screen(const WelcomeScreen());
    await capture('01-welcome');
    await screen(const LoginScreen());
    await capture('02-login');
    await screen(const SignUpScreen());
    await capture('03-create-account');
    await screen(const MainScreen(member: ama));
    await capture('04-home');
    await tester.tap(find.bySemanticsLabel('Account'));
    await tester.pumpAndSettle();
    await capture('10-account');
    await screen(const MainScreen(member: ama, initialTab: 1));
    await capture('05-events');
    await screen(
      EventDetailsScreen(event: testEvents(botwe.id).first, member: ama),
    );
    await capture('11-event-details');
    await screen(const MainScreen(member: ama, initialTab: 2));
    await capture('06-church');
    await screen(const MainScreen(member: ama, initialTab: 3));
    await capture('07-ministries');
    await screen(
      MinistryDetailsScreen(
        ministry: testMinistries(botwe.id).first,
        member: ama,
      ),
    );
    await capture('12-ministry-details');
    await screen(const MainScreen(member: ama, initialTab: 4));
    await capture('08-sermons');
    await tester.tap(find.text('Walking in Faith'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Walking in Faith').last);
    await tester.pumpAndSettle();
    await capture('09-sermon-player');
    await screen(const MemberDetailsScreen());
    await capture('13-about-you');

    final rules = <String, dynamic>{
      'id': 'youth',
      'name': 'Youth Ministry',
      'branch_id': botwe.id,
      'auto_assign': true,
      'min_age': 18,
      'max_age': 35,
      'for_marital_statuses': <String>[],
      'needs_approval': false,
    };
    admin.rowsByKind[ContentKind.ministries] = [rules];
    admin.ruleMinistries = [rules];
    await state.staff.useMember(ama);
    await screen(const MinistryEditor(id: 'youth', rulesOnly: true));
    await capture('14-leader-requirements');
    admin.approvals = [
      const ApprovalMinistry(id: 'choir', name: 'Choir', waiting: 2),
    ];
    admin.requestsByMinistry['choir'] = [
      JoinRequest(
        memberId: 'sample-1',
        member: 'Kofi Mensah',
        branch: 'CCC Botwe',
        requestedAt: DateTime(2026, 11, 12),
      ),
      JoinRequest(
        memberId: 'sample-2',
        member: 'Efua Boateng',
        branch: 'CCC Botwe',
        requestedAt: DateTime(2026, 11, 13),
      ),
    ];
    await screen(const JoinRequestsScreen());
    await capture('15-leader-join-requests');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('export a labeled overview of the main member screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1386, 2150);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const mainScreens = [
      ('04-home', 'Home / News'),
      ('05-events', 'Events'),
      ('06-church', 'Church / Branches'),
      ('07-ministries', 'Ministries'),
      ('08-sermons', 'Sermons'),
      ('10-account', 'Account'),
    ];
    final previews = (await tester.runAsync(
      () async => [
        for (final (name, label) in mainScreens)
          (
            label,
            MemoryImage(await File('$outputDirectory/$name.png').readAsBytes()),
          ),
      ],
    ))!;
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildCccTheme(),
          home: Scaffold(
            backgroundColor: const Color(0xffe9e8e2),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CCC · Member screens',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Current Flutter UI · Sample content · 430 × 932 phone viewport',
                    style: TextStyle(fontSize: 18, color: Color(0xff625f55)),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: [
                      for (final (label, preview) in previews)
                        SizedBox(
                          width: 430,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image(
                                  image: preview,
                                  width: 430,
                                  height: 932,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(Scaffold));
      for (final (_, preview) in previews) {
        if (!context.mounted) return;
        await precacheImage(preview, context);
      }
    });
    await tester.pumpAndSettle();
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final rendered = await boundary.toImage();
      final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$outputDirectory/overview-main.png',
      ).writeAsBytes(png!.buffer.asUint8List());
      rendered.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
