import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;

import '../navigation.dart';
import '../services/auth_service.dart';
import '../theme/ccc_theme.dart';
import '../widgets/ccc_widgets.dart';

const _nightStatusBar = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: CccNight.background,
  systemNavigationBarIconBrightness: Brightness.light,
);

/// A strong ease-out: quick to respond, soft to land.
const _easeOut = Cubic(0.23, 1, 0.32, 1);

/// The first screen: the church's mark with its own construction lines drawn
/// out across the page, then Create account, Log in and Continue as guest.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<Member>? signIns;

  /// One opening sequence: the lines draw out, the mark settles, then the
  /// words and buttons rise 56ms apart. Buttons work throughout.
  late final intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final lines = _phase(0, 0.75);
  late final mark = _phase(0.08, 0.55);
  late final rise = [
    for (var i = 0; i < 5; i++) _phase(0.26 + i * 0.04, 0.66 + i * 0.04),
  ];
  var started = false;

  Animation<double> _phase(double begin, double end) => CurvedAnimation(
    parent: intro,
    curve: Interval(begin, end, curve: _easeOut),
  );

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    // Plays once; with reduced motion the screen opens already settled.
    if (MediaQuery.disableAnimationsOf(context)) {
      intro.value = 1;
    } else {
      intro.forward();
    }
  }

  @override
  void dispose() {
    signIns?.cancel();
    intro.dispose();
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
    final bottom = MediaQuery.paddingOf(context).bottom;
    final social = AuthService.socialProviders;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _nightStatusBar,
      child: Scaffold(
        backgroundColor: CccNight.background,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            const Positioned.fill(child: _MistBackdrop()),
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _LogoStage(lines: lines, mark: mark),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(24, 0, 24, bottom + 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Rise(animation: rise[0], child: const _Name()),
                              const SizedBox(height: 12),
                              _Rise(
                                animation: rise[1],
                                child: const Text(
                                  'Sermons, events and news from your '
                                  'branch, all in one place.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                    color: CccNight.muted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),
                              _Rise(
                                animation: rise[2],
                                child: CccButton(
                                  label: 'Create account',
                                  height: 54,
                                  fontSize: 17,
                                  onPressed: () =>
                                      CccNavigation.openSignUp(context),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _Rise(
                                animation: rise[3],
                                child: CccButton(
                                  label: 'Log in',
                                  variant: CccButtonVariant.onDark,
                                  height: 54,
                                  fontSize: 17,
                                  onPressed: () =>
                                      CccNavigation.openLogin(context),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _Rise(
                                animation: rise[4],
                                child: _GuestLink(
                                  onPressed: () =>
                                      CccNavigation.openMain(context),
                                ),
                              ),
                              // Only providers switched on in Supabase
                              // (SOCIAL_SIGN_IN).
                              if (social.isNotEmpty)
                                _Rise(
                                  animation: rise[4],
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 20),
                                    child: Column(
                                      children: [
                                        const Text(
                                          'Or continue with',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: CccNight.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: _SocialButtons(
                                            providers: social,
                                            onSelected: _socialSignIn,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The misty mountain photo of the light screens, dimmed to a night sky and
/// faded out before the words.
class _MistBackdrop extends StatelessWidget {
  const _MistBackdrop();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: FractionallySizedBox(
        heightFactor: 0.68,
        widthFactor: 1,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.25, 1],
            colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          ).createShader(bounds),
          child: Image.asset(
            CccAssets.welcomeBackground,
            fit: BoxFit.cover,
            opacity: const AlwaysStoppedAnimation(0.14),
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

/// The church's mark, with the construction lines that run past its corners
/// continued to the edges of the screen.
class _LogoStage extends StatelessWidget {
  const _LogoStage({required this.lines, required this.mark});

  final Animation<double> lines;
  final Animation<double> mark;

  static const logoWidth = 136.0;

  /// Below the middle, nearer the words it introduces.
  static const alignment = Alignment(0, 0.3);

  @override
  Widget build(BuildContext context) {
    final logoSize = _ConstructionLines.logoSizeFor(logoWidth);
    return ExcludeSemantics(
      child: ConstrainedBox(
        // On short screens the page scrolls instead of crushing the mark.
        constraints: const BoxConstraints(minHeight: 240),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ConstructionLines(
                  progress: lines,
                  logoSize: logoSize,
                  alignment: alignment,
                ),
              ),
            ),
            Align(
              alignment: alignment,
              child: FadeTransition(
                opacity: mark,
                child: ScaleTransition(
                  scale: Tween(begin: 0.94, end: 1.0).animate(mark),
                  child: SvgPicture.asset(
                    CccAssets.logo,
                    width: logoSize.width,
                    height: logoSize.height,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a soft gold glow behind the mark and draws its construction lines
/// outward from where they leave the mark, fading as they go.
class _ConstructionLines extends CustomPainter {
  _ConstructionLines({
    required this.progress,
    required this.logoSize,
    required this.alignment,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Size logoSize;
  final Alignment alignment;

  // Positions are measured on the logo rendered at 10× its SVG size.
  static const _artWidth = 1730.0;
  static const _artHeight = 1500.0;

  /// The floor line, whose short stubs stand out past both walls.
  static const _floorY = 1187.5;
  static const _floorStubEnds = (20.0, 1665.0);

  /// The two posts that rise past the roof and drop past the floor.
  static const _postsX = (401.0, 1334.0);
  static const _postsTop = 92.0;

  /// The roof lines leave the artwork at its sides, falling 0.54 per unit.
  static const _roofSideY = 676.0;
  static const _roofSlope = 0.54;

  static Size logoSizeFor(double width) =>
      Size(width, width * _artHeight / _artWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t == 0) return;
    final logo = alignment.inscribe(logoSize, Offset.zero & size);
    Offset at(double x, double y) => Offset(
      logo.left + x / _artWidth * logo.width,
      logo.top + y / _artHeight * logo.height,
    );

    final glowRadius = logo.width * 1.7;
    canvas.drawCircle(
      logo.center,
      glowRadius,
      Paint()
        ..shader = ui.Gradient.radial(logo.center, glowRadius, [
          CccNight.glow.withValues(alpha: CccNight.glow.a * t),
          CccNight.glow.withValues(alpha: 0),
        ]),
    );

    final floorY = at(0, _floorY).dy;
    final postsTop = at(0, _postsTop).dy;
    final leftPost = at(_postsX.$1, 0).dx;
    final rightPost = at(_postsX.$2, 0).dx;
    final roofLeft = at(0, _roofSideY);
    final roofRight = at(_artWidth, _roofSideY);
    final toRightEdge = size.width - roofRight.dx;
    final segments = [
      (at(_floorStubEnds.$1, _floorY), Offset(0, floorY)),
      (at(_floorStubEnds.$2, _floorY), Offset(size.width, floorY)),
      (Offset(leftPost, postsTop), Offset(leftPost, 0)),
      (Offset(rightPost, postsTop), Offset(rightPost, 0)),
      (Offset(leftPost, logo.bottom), Offset(leftPost, size.height)),
      (Offset(rightPost, logo.bottom), Offset(rightPost, size.height)),
      (roofLeft, roofLeft + Offset(-roofLeft.dx, roofLeft.dx * _roofSlope)),
      (roofRight, roofRight + Offset(toRightEdge, toRightEdge * _roofSlope)),
    ];
    for (final (start, end) in segments) {
      if ((end - start).distance < 1) continue;
      canvas.drawLine(
        start,
        Offset.lerp(start, end, t)!,
        Paint()
          ..strokeWidth = 1
          ..shader = ui.Gradient.linear(start, end, [
            CccNight.line,
            CccNight.line.withValues(alpha: 0),
          ]),
      );
    }
  }

  @override
  bool shouldRepaint(_ConstructionLines old) =>
      old.logoSize != logoSize || old.alignment != alignment;
}

/// The church's name, lit from above.
class _Name extends StatelessWidget {
  const _Name();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [CccNight.text, Color(0xFFD8CDB8)],
        ).createShader(bounds),
        child: const Text(
          'Calvary Charismatic Centre',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.12,
            letterSpacing: -0.6,
            color: CccNight.text,
          ),
        ),
      ),
    );
  }
}

/// Browsing without an account: the quietest of the three choices.
class _GuestLink extends StatelessWidget {
  const _GuestLink({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: CccNight.muted,
        overlayColor: CccNight.text,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        // A button's text style replaces the theme's, font included.
        textStyle: const TextStyle(
          fontFamily: CccFonts.openSans,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: const Text('Continue as guest'),
    );
  }
}

/// Fades and lifts [child] into place as [animation] runs.
class _Rise extends StatelessWidget {
  const _Rise({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 12 * (1 - animation.value)),
          child: child,
        ),
        child: child,
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
