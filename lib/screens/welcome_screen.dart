import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;

import '../navigation.dart';
import '../services/auth_service.dart';
import '../theme/ccc_theme.dart';
import '../widgets/ccc_widgets.dart';

/// "Splash Screen 4": Login, Register, Guest and social sign-in.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  StreamSubscription<Member>? signIns;

  @override
  void initState() {
    super.initState();
    // Social sign-in finishes in the browser and returns through a deep link.
    // Email sign-in on a screen above this one navigates by itself.
    if (AuthService.isConfigured) {
      signIns = AuthService.signIns.listen((member) {
        if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
        CccNavigation.openMain(context, member: member);
      });
    }
  }

  @override
  void dispose() {
    signIns?.cancel();
    super.dispose();
  }

  Future<void> _socialSignIn(OAuthProvider provider) async {
    try {
      await AuthService.signInWithProvider(provider);
    } catch (error) {
      if (mounted) {
        showCccMessage(
          context,
          'This sign-in option is not available yet. Please use email.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkStatusBar,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: PhotoBackground(
          child: FullScreenColumn(
            bottomGap: 34,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              SvgPicture.asset(
                CccAssets.churchIcon,
                width: 67.31,
                height: 73.85,
                semanticsLabel: 'Church',
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome to',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: CccColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Calvary Charismatic Centre',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  color: CccColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sermons, events and news from your branch, all in one place.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 22 / 16,
                  color: CccColors.ink,
                ),
              ),
              const SizedBox(height: 56),
              Row(
                children: [
                  Expanded(
                    child: CccButton(
                      label: 'Login',
                      onPressed: () => CccNavigation.openLogin(context),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: CccButton(
                      label: 'Register',
                      variant: CccButtonVariant.white,
                      onPressed: () => CccNavigation.openSignUp(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 41),
              Center(
                child: CccButton(
                  label: 'Guest',
                  width: 188,
                  onPressed: () => CccNavigation.openMain(context),
                ),
              ),
              // Only providers switched on in Supabase (SOCIAL_SIGN_IN).
              if (AuthService.socialProviders.isNotEmpty) ...[
                const SizedBox(height: 53),
                const Center(
                  child: Text(
                    'Or login with...',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1,
                      color: CccColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _SocialButtons(
                      providers: AuthService.socialProviders,
                      onSelected: _socialSignIn,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The Facebook / Google / Apple pills, each cut out of the design's SVG,
/// for the providers that are switched on.
class _SocialButtons extends StatelessWidget {
  const _SocialButtons({required this.providers, required this.onSelected});

  final List<OAuthProvider> providers;
  final ValueChanged<OAuthProvider> onSelected;

  /// Order of the pills in the SVG, and their labels.
  static const _pills = [
    (OAuthProvider.facebook, 'Continue with Facebook'),
    (OAuthProvider.google, 'Continue with Google'),
    (OAuthProvider.apple, 'Continue with Apple'),
  ];

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final (index, (provider, label)) in _pills.indexed)
        if (providers.contains(provider)) (index, provider, label),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (position, (index, provider, label)) in shown.indexed) ...[
          if (position > 0) const SizedBox(width: 16),
          _ProviderPill(
            index: index,
            label: label,
            onTap: () => onSelected(provider),
          ),
        ],
      ],
    );
  }
}

class _ProviderPill extends StatelessWidget {
  const _ProviderPill({
    required this.index,
    required this.label,
    required this.onTap,
  });

  /// Which pill of the SVG: 0 Facebook, 1 Google, 2 Apple.
  final int index;
  final String label;
  final VoidCallback onTap;

  // In the SVG each pill is 106 × 52, 122 apart, with 8px of shadow room.
  static const _pitch = 122.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: 106,
        height: 52,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -8,
              top: -8,
              width: _pitch,
              height: 72,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: 370,
                  maxWidth: 370,
                  minHeight: 72,
                  maxHeight: 72,
                  child: Transform.translate(
                    offset: Offset(-index * _pitch, 0),
                    child: SvgPicture.asset(
                      CccAssets.socialButtons,
                      width: 370,
                      height: 72,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                customBorder: const StadiumBorder(),
                child: const SizedBox(width: 106, height: 52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
