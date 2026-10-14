import 'package:flutter/material.dart';

import 'models/event.dart';
import 'models/live_stream.dart';
import 'models/ministry.dart';
import 'models/news.dart';
import 'screens/event_details_screen.dart';
import 'screens/live_stream_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/ministry_details_screen.dart';
import 'screens/news_details_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/auth_service.dart';

class CccNavigation {
  static void openWelcome(BuildContext context) {
    Navigator.of(
      context,
    ).pushAndRemoveUntil(_fade(const WelcomeScreen()), (_) => false);
  }

  /// Opens the Home / Events / Church / Ministries screen as the only route. A guest
  /// ([member] is null) is invited to log in once the screen has appeared.
  static void openMain(BuildContext context, {Member? member}) {
    Navigator.of(context).pushAndRemoveUntil(
      _fade(MainScreen(member: member, promptGuestLogin: member == null)),
      (_) => false,
    );
  }

  static void openLogin(BuildContext context, {bool replace = false}) =>
      _open(context, const LoginScreen(), replace);

  static void openSignUp(BuildContext context, {bool replace = false}) =>
      _open(context, const SignUpScreen(), replace);

  static void openEvent(BuildContext context, Event event, {Member? member}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventDetailsScreen(event: event, member: member),
      ),
    );
  }

  static void openMinistry(
    BuildContext context,
    Ministry ministry, {
    Member? member,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MinistryDetailsScreen(ministry: ministry, member: member),
      ),
    );
  }

  static void openLiveStream(
    BuildContext context,
    LiveStream stream, {
    required String branchName,
    Event? event,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveStreamScreen(
          stream: stream,
          branchName: branchName,
          event: event,
        ),
      ),
    );
  }

  static void openNews(BuildContext context, NewsItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NewsDetailsScreen(item: item)),
    );
  }

  static void _open(BuildContext context, Widget screen, bool replace) {
    final route = MaterialPageRoute<void>(builder: (_) => screen);
    replace
        ? Navigator.of(context).pushReplacement(route)
        : Navigator.of(context).push(route);
  }

  static PageRoute<void> _fade(Widget screen) => PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (_, _, _) => screen,
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
