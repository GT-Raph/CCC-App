import 'package:ccc_app/main.dart';
import 'package:ccc_app/screens/main_screen.dart';
import 'package:ccc_app/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(430 * 3, 932 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> openWelcome(WidgetTester tester) async {
  final harness = Harness();
  addTearDown(harness.events.streams.close);
  await tester.pumpWidget(CccApp(state: harness.state));
  await tester.pump(const Duration(milliseconds: 2700));
  await tester.pumpAndSettle();
}

/// Taps Guest and waits for the delayed "Login after Home" sheet.
Future<void> enterAsGuest(WidgetTester tester) async {
  await tester.tap(find.text('Guest'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// Scrolls the main list until [finder] is built and on screen.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find.byType(CustomScrollView),
    const Offset(0, -250),
  );
  await tester.pumpAndSettle();
}

/// Scrolls the details screen until the text is on screen.
Future<void> scrollToText(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

Future<Harness> pumpMember(
  WidgetTester tester, {
  int tab = 0,
  Member? member = ama,
}) async {
  final harness = Harness();
  await harness.pump(
    tester,
    MainScreen(member: member, initialTab: tab),
    size: tester.view.physicalSize / tester.view.devicePixelRatio,
  );
  return harness;
}

const ministriesTab = 3;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.socialProviders = [];
  });

  testWidgets('splash leads to the welcome screen', (tester) async {
    usePhoneScreen(tester);
    await openWelcome(tester);

    expect(find.text('Calvary Charismatic Centre'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Or login with...'), findsNothing);
  });

  testWidgets('guest is invited to log in and can skip', (tester) async {
    usePhoneScreen(tester);
    await openWelcome(tester);

    await enterAsGuest(tester);

    expect(find.text('CREATE AN ACCOUNT'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('CREATE AN ACCOUNT'), findsNothing);
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('News by church'), findsOneWidget);
    expect(find.text('Harvest Thanksgiving'), findsOneWidget);
  });

  testWidgets('guest member-only actions open the login prompt', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await openWelcome(tester);
    await enterAsGuest(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Remind Me').first);
    await tester.tap(find.text('Remind Me').first);
    await tester.pumpAndSettle();

    expect(find.text('CREATE AN ACCOUNT'), findsOneWidget);
    await tester.tap(find.text('CREATE AN ACCOUNT'));
    await tester.pumpAndSettle();
    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets('tabs switch between news, events, branches and ministries', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await pumpMember(tester);

    expect(find.text('Ama'), findsOneWidget);
    expect(find.text('News by church'), findsOneWidget);

    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    expect(find.text('Events near me'), findsOneWidget);
    expect(find.text('Intercessory Prayers'), findsWidgets);

    await tester.tap(find.text('Church'));
    await tester.pumpAndSettle();
    expect(find.text('Branches'), findsOneWidget);
    // No Google Maps key in tests, so the tab explains branches are off.
    expect(
      find.text('Branch locations are not available yet.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Ministries'));
    await tester.pumpAndSettle();
    // The tab label and the section title.
    expect(find.text('Ministries'), findsNWidgets(2));
    expect(find.text('Kharis Ladies'), findsOneWidget);
    expect(find.text("Women's fellowship"), findsOneWidget);
    expect(find.text('50+ members'), findsOneWidget);
  });

  testWidgets('all five tabs fit a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpMember(tester, tab: ministriesTab);

    for (final label in ['Home', 'Events', 'Church', 'Sermons']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Kharis Ladies'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('members join and leave ministries', (tester) async {
    usePhoneScreen(tester);
    await pumpMember(tester, tab: ministriesTab);

    await tester.tap(find.bySemanticsLabel('Join Kharis Ladies'));
    await tester.pumpAndSettle();
    expect(find.text('You joined Kharis Ladies.'), findsOneWidget);
    expect(find.text('Joined'), findsOneWidget);

    await tester.tap(find.text('Kharis Ladies'));
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsOneWidget);
    expect(find.textContaining('A fellowship for the women'), findsOneWidget);
    expect(find.text('Saturdays, 4:00 PM'), findsOneWidget);

    await scrollToText(tester, 'Joined');
    await tester.tap(find.text('Joined'));
    await tester.pumpAndSettle();
    expect(find.text('You left Kharis Ladies.'), findsOneWidget);
    expect(find.text('Join Ministry'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Joined'), findsNothing);
    expect(find.bySemanticsLabel('Join Kharis Ladies'), findsOneWidget);
  });

  testWidgets('guests are asked to log in before joining a ministry', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await pumpMember(tester, tab: ministriesTab, member: null);

    await tester.tap(find.bySemanticsLabel('Join Kharis Ladies'));
    await tester.pumpAndSettle();
    expect(find.text('CREATE AN ACCOUNT'), findsOneWidget);
    expect(find.text('Joined'), findsNothing);
  });

  testWidgets('search finds ministries by name, focus and venue', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await pumpMember(tester, tab: ministriesTab);

    await tester.enterText(find.byType(TextField), 'ages 18');
    await tester.pump();
    expect(find.text('Youth Ministry'), findsOneWidget);
    expect(find.text('Kharis Ladies'), findsNothing);

    await tester.enterText(find.byType(TextField), 'prayer room');
    await tester.pump();
    expect(find.text('Prayer Ministry'), findsOneWidget);
    expect(find.text('Youth Ministry'), findsNothing);
  });

  testWidgets('search filters the current tab', (tester) async {
    usePhoneScreen(tester);
    await pumpMember(tester, tab: 1);

    await tester.enterText(find.byType(TextField), 'Intercessory');
    await tester.pump();
    expect(find.text('Intercessory Prayers'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'nothing like this');
    await tester.pump();
    expect(find.text('Intercessory Prayers'), findsNothing);
    expect(find.textContaining('Nothing matches'), findsOneWidget);
  });

  testWidgets('members can set and see event reminders', (tester) async {
    usePhoneScreen(tester);
    final harness = await pumpMember(tester, tab: 1);

    await scrollTo(tester, find.text('Remind Me').first);
    await tester.tap(find.text('Remind Me').first);
    await tester.pumpAndSettle();
    expect(find.text('Reminded'), findsOneWidget);
    expect(harness.scheduler.scheduled, hasLength(1));
    expect(harness.reminderStore.saved, {'prayers'});
  });

  testWidgets('event details show contact information', (tester) async {
    usePhoneScreen(tester);
    await pumpMember(tester, tab: 1);

    await tester.tap(find.text('Intercessory Prayers').first);
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('+233 20 000 0000'), findsOneWidget);
    expect(find.text('events@example.org'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    await scrollToText(tester, 'Remind Me');
    expect(find.text('Remind Me'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Events near me'), findsOneWidget);
  });

  testWidgets('login and sign up validate before contacting Supabase', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await openWelcome(tester);

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(
      find.text(
        'Enter a valid email and a password with at least 6 characters.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.textContaining('Sign Up'));
    await tester.pumpAndSettle();
    expect(find.text('Create Account'), findsOneWidget);
    // Let the login error snackbar time out so it no longer covers the form.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Jessica');
    await tester.enterText(find.byType(TextField).at(1), 'Doe');
    await tester.enterText(find.byType(TextField).at(2), 'jessica@example.com');
    await tester.enterText(find.byType(TextField).at(3), 'secret1');
    await tester.enterText(find.byType(TextField).at(4), 'secret2');
    await tester.tap(find.text('Sign up'));
    await tester.pump();
    expect(find.text('The passwords do not match.'), findsOneWidget);
  });
}
