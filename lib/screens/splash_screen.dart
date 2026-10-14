import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../navigation.dart';
import '../services/auth_service.dart';
import '../theme/ccc_theme.dart';
import '../widgets/ccc_widgets.dart';

/// Splash Screens 1–3: a blank screen, then the logo, then the church's
/// name,
/// before moving on to the welcome screen (or straight home if signed in).
class SplashScreen extends StatefulWidget {
  const SplashScreen({this.member, super.key});

  final Member? member;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late final logoIn = CurvedAnimation(
    parent: controller,
    curve: const Interval(0.12, 0.38, curve: Curves.easeOutCubic),
  );
  late final wordmarkIn = CurvedAnimation(
    parent: controller,
    curve: const Interval(0.46, 0.70, curve: Curves.easeOutCubic),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (controller.isAnimating || controller.isCompleted) return;
    if (MediaQuery.of(context).disableAnimations) {
      controller.value = 1;
      Future<void>.delayed(const Duration(milliseconds: 800), _finish);
    } else {
      controller.forward().whenComplete(_finish);
    }
  }

  void _finish() {
    if (!mounted) return;
    final member = widget.member;
    member == null
        ? CccNavigation.openWelcome(context)
        : CccNavigation.openMain(context, member: member);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkStatusBar,
      child: Scaffold(
        backgroundColor: CccColors.paper,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: logoIn,
                child: ScaleTransition(
                  scale: Tween(begin: 0.9, end: 1.0).animate(logoIn),
                  child: const ChurchLogo(),
                ),
              ),
              const SizedBox(height: 20),
              FadeTransition(
                opacity: wordmarkIn,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(wordmarkIn),
                  // The church's name set like the design's CHURCH wordmark.
                  child: Semantics(
                    label: 'Calvary Charismatic Centre. Welcome home.',
                    excludeSemantics: true,
                    child: const Column(
                      children: [
                        Text(
                          'CALVARY CHARISMATIC',
                          style: TextStyle(
                            fontFamily: CccFonts.montserrat,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            height: 1,
                            letterSpacing: 3.4,
                            color: CccColors.primary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'CENTRE',
                          style: TextStyle(
                            fontFamily: CccFonts.montserrat,
                            fontWeight: FontWeight.w700,
                            fontSize: 40,
                            height: 1,
                            letterSpacing: 8,
                            color: CccColors.primary,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Welcome home',
                          style: TextStyle(
                            fontFamily: CccFonts.script,
                            fontSize: 20,
                            height: 1,
                            color: CccColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
