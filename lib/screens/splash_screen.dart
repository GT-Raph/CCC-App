import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../navigation.dart';
import '../services/auth_service.dart';
import '../theme/ccc_theme.dart';
import '../widgets/ccc_widgets.dart';

/// The church's mark and name on the welcome screen's night, before moving
/// on to the welcome screen (or straight home if signed in).
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
      value: cccSystemBars(Brightness.dark),
      child: Scaffold(
        backgroundColor: CccNight.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: logoIn,
                child: ScaleTransition(
                  scale: Tween(begin: 0.94, end: 1.0).animate(logoIn),
                  child: const ChurchLogo(width: 128),
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: wordmarkIn,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.2),
                    end: Offset.zero,
                  ).animate(wordmarkIn),
                  child: Semantics(
                    label: 'Calvary Charismatic Centre. Welcome home.',
                    excludeSemantics: true,
                    child: const Column(
                      children: [
                        Text(
                          'Calvary Charismatic Centre',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                            height: 1.2,
                            letterSpacing: -0.4,
                            color: CccNight.text,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Welcome home',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.3,
                            color: CccNight.muted,
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
