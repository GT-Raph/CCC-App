import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../navigation.dart';
import '../theme/ccc_theme.dart';

const darkStatusBar = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
);

enum CccButtonVariant { filled, white, outlined }

/// The rounded call-to-action used across the design (radius 8, soft shadow).
class CccButton extends StatelessWidget {
  const CccButton({
    required this.label,
    required this.onPressed,
    this.variant = CccButtonVariant.filled,
    this.height = 60,
    this.width,
    this.fontSize = 20,
    this.icon,
    this.iconGap = 10,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final CccButtonVariant variant;
  final double height;
  final double? width;
  final double fontSize;
  final Widget? icon;
  final double iconGap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // Black text throughout: white on the brand yellow is only 1.9:1.
    final (background, border) = switch (variant) {
      CccButtonVariant.filled => (CccColors.primary, null),
      CccButtonVariant.white => (CccColors.paper, null),
      CccButtonVariant.outlined => (
        CccColors.primaryTint,
        const BorderSide(color: CccColors.primary, width: 1.2),
      ),
    };
    const foreground = CccColors.ink;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: border ?? BorderSide.none,
    );

    return PressScale(
      enabled: onPressed != null && !isLoading,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: CccShadows.raised,
        ),
        child: Material(
          color: background,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            child: Center(
              child: isLoading
                  ? SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: foreground,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          IconTheme.merge(
                            data: IconThemeData(color: foreground),
                            child: icon!,
                          ),
                          SizedBox(width: iconGap),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shrinks its child slightly while a finger is down, so buttons feel like
/// they respond to the press. Listens to raw pointer events, so it never
/// competes with the child's own tap handling.
class PressScale extends StatefulWidget {
  const PressScale({
    required this.child,
    this.enabled = true,
    this.scale = 0.97,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool pressed = false;
  Offset? downAt;

  void _press(bool value) {
    if (pressed != value && mounted) setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final still = !widget.enabled || MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (event) {
        downAt = event.position;
        _press(true);
      },
      // A finger that starts a scroll isn't pressing the button.
      onPointerMove: (event) {
        final start = downAt;
        if (start != null && (event.position - start).distance > kTouchSlop) {
          _press(false);
        }
      },
      onPointerUp: (_) => _press(false),
      onPointerCancel: (_) => _press(false),
      child: AnimatedScale(
        scale: pressed && !still ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// The misty mountain photo behind the welcome, login and sign up screens,
/// washed out with an 80% white layer as in the design.
class PhotoBackground extends StatelessWidget {
  const PhotoBackground({required this.child, this.photoTop = 0, super.key});

  final Widget child;

  /// Where the photo starts, as a fraction of the screen height. The sign up
  /// screen lifts it (Figma: y = -167 of 932).
  final double photoTop;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final photo = Image.asset(CccAssets.welcomeBackground, fit: BoxFit.cover);
    return ColoredBox(
      color: CccColors.paper,
      child: Stack(
        children: [
          Positioned(
            top: height * photoTop,
            left: 0,
            right: 0,
            height: height,
            child: photoTop < 0 ? _FadeOut(child: photo) : photo,
          ),
          const Positioned.fill(child: ColoredBox(color: Color(0xCCFFFFFF))),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// Fades a lifted photo out at the bottom, so it has no hard edge behind the
/// lower fields.
class _FadeOut extends StatelessWidget {
  const _FadeOut({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.75, 1],
        colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
      ).createShader(bounds),
      child: child,
    );
  }
}

/// Lays out a full-screen design with fixed gaps and flexible [Spacer]s, and
/// scrolls when the keyboard or a short screen leaves too little room.
class FullScreenColumn extends StatelessWidget {
  const FullScreenColumn({
    required this.children,
    this.bottomGap = 0,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    super.key,
  });

  final List<Widget> children;

  /// Space between the last child and the home indicator area.
  final double bottomGap;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: media.size.height),
        child: IntrinsicHeight(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              media.padding.top,
              20,
              media.padding.bottom + bottomGap,
            ),
            child: Column(
              crossAxisAlignment: crossAxisAlignment,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class ChurchLogo extends StatelessWidget {
  const ChurchLogo({
    this.width = 173,
    this.color = CccColors.primary,
    super.key,
  });

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      CccAssets.logo,
      width: width,
      height: width * 149.997 / 173,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

class AuthTitle extends StatelessWidget {
  const AuthTitle({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: CccFonts.playfair,
            fontWeight: FontWeight.w900,
            fontSize: 36,
            height: 1,
            color: CccColors.ink,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            height: 21 / 15,
            color: CccColors.ink,
          ),
        ),
      ],
    );
  }
}

/// A translucent 60px input with a leading icon, as on the login and sign up
/// screens. Password fields get the eye toggle.
class AuthField extends StatefulWidget {
  const AuthField({
    required this.icon,
    required this.hint,
    required this.controller,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
    super.key,
  });

  final Widget icon;
  final String hint;
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;

  /// Translucent box shared with the other fields on the auth screens.
  static const decoration = BoxDecoration(
    color: Color(0x4DFFFFFF),
    borderRadius: BorderRadius.all(Radius.circular(8)),
    border: Border.fromBorderSide(BorderSide(color: Color(0x66DCDCDC))),
    // Figma keeps the drop shadow out from under the translucent fill.
    boxShadow: [
      BoxShadow(
        color: Color(0x33545454),
        offset: Offset(2, 2),
        blurRadius: 10,
        blurStyle: BlurStyle.outer,
      ),
    ],
  );

  static const hintColor = Color(0xFF5E5E5E);

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool obscured = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: AuthField.decoration,
      child: Row(
        children: [
          SizedBox(width: 58, child: Center(child: widget.icon)),
          Expanded(
            child: TextField(
              controller: widget.controller,
              obscureText: obscured,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              autofillHints: widget.autofillHints,
              textCapitalization: widget.textCapitalization,
              onSubmitted: widget.onSubmitted,
              autocorrect: !widget.isPassword,
              enableSuggestions: !widget.isPassword,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CccColors.ink,
              ),
              decoration: InputDecoration.collapsed(
                hintText: widget.hint,
                hintStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AuthField.hintColor,
                ),
              ),
            ),
          ),
          if (widget.isPassword)
            IconButton(
              onPressed: () => setState(() => obscured = !obscured),
              tooltip: obscured ? 'Show password' : 'Hide password',
              icon: Icon(
                obscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 24,
                color: CccColors.ink,
              ),
            ),
          if (widget.isPassword) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class FieldIcons {
  static const email = Icon(
    Icons.alternate_email,
    size: 26,
    color: CccColors.ink,
  );
  static const person = Icon(
    Icons.account_box_outlined,
    size: 28,
    color: CccColors.ink,
  );
  static final key = Transform.rotate(
    angle: -math.pi / 4,
    child: const Icon(Icons.key_outlined, size: 25, color: CccColors.ink),
  );
}

/// "Don't have an account? Sign Up" style footer link.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    required this.prompt,
    required this.action,
    required this.onTap,
    super.key,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text.rich(
          TextSpan(
            text: '$prompt ',
            children: [
              TextSpan(
                text: action,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: CccColors.navy,
                  decoration: TextDecoration.underline,
                  decorationColor: CccColors.primary,
                  decorationThickness: 2,
                ),
              ),
            ],
          ),
          style: const TextStyle(fontSize: 16, color: CccColors.ink),
        ),
      ),
    );
  }
}

/// Photo header with the avatar, notification bell, settings and greeting.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    required this.greeting,
    required this.name,
    required this.onAvatarTap,
    required this.onSettingsTap,
    super.key,
  });

  final String greeting;
  final String name;
  final VoidCallback onAvatarTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: top + 190,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(CccAssets.headerBackground, fit: BoxFit.cover),
          const ColoredBox(color: Color(0x99FFFFFF)),
          Positioned(
            left: 20,
            top: top + 20,
            child: Semantics(
              button: true,
              label: 'Account',
              child: GestureDetector(
                onTap: onAvatarTap,
                child: const _AvatarPlaceholder(),
              ),
            ),
          ),
          Positioned(
            right: 11,
            top: top + 21.5,
            // The design's notification bell returns once the app has real
            // notifications to show.
            child: Row(
              children: [
                IconButton(
                  onPressed: onSettingsTap,
                  tooltip: 'Settings',
                  icon: const Icon(
                    Icons.settings,
                    size: 31,
                    color: CccColors.ink,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: top + 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    fontFamily: CccFonts.montserrat,
                    fontSize: 20,
                    height: 1,
                    color: CccColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: CccFonts.montserrat,
                    fontWeight: FontWeight.w700,
                    fontSize: 38,
                    height: 40 / 38,
                    color: CccColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        color: CccColors.primary,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: CccColors.paper, size: 40),
    );
  }
}

/// Home / Events / Church / Ministries / Sermons along the bottom of the
/// screen. The yellow pill from the design's switcher slides behind the
/// selected section's icon.
class CccNavigationBar extends StatelessWidget {
  const CccNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;

  /// Also called for the selected section, which scrolls back to the top.
  final ValueChanged<int> onSelected;

  static const labels = ['Home', 'Events', 'Church', 'Ministries', 'Sermons'];

  /// (unselected, selected): one Material family, outlined until chosen.
  static const icons = [
    (Icons.home_outlined, Icons.home),
    (Icons.calendar_month_outlined, Icons.calendar_month),
    (Icons.church_outlined, Icons.church),
    (Icons.people_outline, Icons.people),
    (Icons.headphones_outlined, Icons.headphones),
  ];
  static const _pill = Size(56, 32);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final animate = !MediaQuery.disableAnimationsOf(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: CccColors.paper,
        border: Border(top: BorderSide(color: CccColors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: 66,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / labels.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: animate
                        ? const Duration(milliseconds: 260)
                        : Duration.zero,
                    curve: Curves.easeOutCubic,
                    left:
                        itemWidth * selectedIndex +
                        (itemWidth - _pill.width) / 2,
                    top: 8,
                    width: _pill.width,
                    height: _pill.height,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: CccColors.primary,
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        Expanded(
                          child: _NavItem(
                            icons: icons[i],
                            label: labels[i],
                            selected: i == selectedIndex,
                            onTap: () => onSelected(i),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icons,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final (IconData, IconData) icons;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      selected: selected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        highlightShape: BoxShape.rectangle,
        child: TweenAnimationBuilder<Color?>(
          duration: const Duration(milliseconds: 200),
          tween: ColorTween(end: selected ? CccColors.ink : CccColors.muted),
          builder: (context, color, _) => Column(
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: Center(
                  // Crossfades between the outlined and filled glyphs.
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      selected ? icons.$2 : icons.$1,
                      key: ValueKey(selected),
                      size: 24,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Shrinks rather than wrapping with very large text sizes.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    height: 1,
                    color: color,
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

class CccSearchField extends StatelessWidget {
  const CccSearchField({
    required this.controller,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: CccColors.primaryTint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CccColors.primary, width: 1.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 18.5),
          const CustomPaint(size: Size(26, 26), painter: _SearchGlyph()),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: CccColors.ink,
              ),
              decoration: const InputDecoration.collapsed(
                hintText: 'Search',
                hintStyle: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: CccColors.ink,
                ),
              ),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox(width: 12)
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: const Icon(Icons.close, color: CccColors.body),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Photo app bar with a back chevron and centred title ("Event details").
class DetailsHeader extends StatelessWidget {
  const DetailsHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: top + 64,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(CccAssets.headerBackground, fit: BoxFit.cover),
          const ColoredBox(color: Color(0x99FFFFFF)),
          Positioned(
            top: top,
            left: 0,
            right: 0,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    color: CccColors.ink,
                  ),
                ),
                Positioned(
                  left: 4,
                  child: IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    tooltip: 'Back',
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 30,
                      color: CccColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The design's magnifier: a heavy ring with a short handle.
class _SearchGlyph extends CustomPainter {
  const _SearchGlyph();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CccColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.115
      ..strokeCap = StrokeCap.round;
    final radius = size.width * 0.37;
    final center = Offset(
      radius + paint.strokeWidth / 2,
      radius + paint.strokeWidth / 2,
    );
    canvas.drawCircle(center, radius, paint);
    final handleStart = center + Offset.fromDirection(math.pi / 4, radius + 1);
    canvas.drawLine(
      handleStart,
      Offset(
        size.width - paint.strokeWidth / 2,
        size.height - paint.strokeWidth / 2,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, height: 1, color: CccColors.ink),
    );
  }
}

/// Grey stand-ins shaped like the cards that are loading, so the screen
/// doesn't jump when they arrive. They pulse gently, and hold still when the
/// system asks for reduced motion.
class SkeletonList extends StatefulWidget {
  const SkeletonList({
    required this.label,
    this.count = 3,
    this.photo = false,
    super.key,
  });

  /// What's loading, for screen readers ("Loading sermons").
  final String label;
  final int count;

  /// Cards that start with a photo (branches, events).
  final bool photo;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final opacity = Tween(
    begin: 1.0,
    end: 0.45,
  ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.stop();
    } else if (!controller.isAnimating) {
      controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget bone(double widthFactor, double height) => FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE4E4E4),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );

    return Semantics(
      label: widget.label,
      excludeSemantics: true,
      child: FadeTransition(
        opacity: opacity,
        child: Column(
          children: [
            for (var i = 0; i < widget.count; i++) ...[
              if (i > 0) const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CccColors.paper,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.photo) ...[
                      bone(1, 120),
                      const SizedBox(height: 16),
                    ],
                    bone(0.62, 18),
                    const SizedBox(height: 12),
                    bone(0.4, 13),
                    const SizedBox(height: 10),
                    bone(0.82, 13),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Grab bar at the top of the app's bottom sheets.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: CccColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Bottom sheet that invites a guest to log in ("Login after Home" frame).
Future<void> showLoginPrompt(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    barrierColor: CccColors.scrim,
    backgroundColor: CccColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            Align(
              alignment: Alignment.centerRight,
              child: _SheetLink(
                label: 'Skip',
                padding: const EdgeInsets.fromLTRB(16, 10, 0, 10),
                style: const TextStyle(fontSize: 20, height: 1),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ),
            const SizedBox(height: 14),
            CccButton(
              label: 'Login',
              onPressed: () {
                Navigator.pop(sheetContext);
                CccNavigation.openLogin(context);
              },
            ),
            const SizedBox(height: 20),
            Center(
              child: _SheetLink(
                label: 'CREATE AN ACCOUNT',
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  CccNavigation.openSignUp(context);
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Plain text action whose padding enlarges the tap area without moving the
/// label off its design position.
class _SheetLink extends StatelessWidget {
  const _SheetLink({
    required this.label,
    required this.padding,
    required this.style,
    required this.onTap,
  });

  final String label;
  final EdgeInsets padding;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: padding,
          child: Text(label, style: style.copyWith(color: CccColors.ink)),
        ),
      ),
    );
  }
}

void showCccMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
