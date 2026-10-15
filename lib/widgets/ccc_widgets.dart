import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../navigation.dart';
import '../theme/ccc_theme.dart';

/// filled: gold, the one main action on a screen. outlined: a quiet
/// secondary action. tonal: a filled grey for tertiary actions. onDark: the
/// welcome screen's outlined button.
enum CccButtonVariant { filled, outlined, tonal, onDark }

/// The app's button: 10px corners, no shadow, a slight shrink when pressed.
class CccButton extends StatelessWidget {
  const CccButton({
    required this.label,
    required this.onPressed,
    this.variant = CccButtonVariant.filled,
    this.height = 52,
    this.width,
    this.fontSize = 16,
    this.icon,
    this.iconGap = 8,
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
    final p = context.palette;
    final (background, border, foreground) = switch (variant) {
      CccButtonVariant.filled => (
        CccColors.primary,
        BorderSide.none,
        CccColors.onPrimary,
      ),
      CccButtonVariant.outlined => (
        p.surface,
        BorderSide(color: p.lineStrong),
        p.text,
      ),
      CccButtonVariant.tonal => (p.surfaceAlt, BorderSide.none, p.text),
      CccButtonVariant.onDark => (
        CccNight.buttonFill,
        const BorderSide(color: CccNight.buttonEdge),
        CccNight.text,
      ),
    };
    final enabled = onPressed != null;

    return PressScale(
      enabled: enabled && !isLoading,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: SizedBox(
          width: width,
          height: height,
          child: Material(
            color: background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: border,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: isLoading ? null : onPressed,
              child: Center(
                child: isLoading
                    ? SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: foreground,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              IconTheme.merge(
                                data: IconThemeData(
                                  color: foreground,
                                  size: fontSize + 4,
                                ),
                                child: icon!,
                              ),
                              SizedBox(width: iconGap),
                            ],
                            Flexible(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                  color: foreground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

/// A rounded surface with a hairline edge: the app's card.
class CccCard extends StatelessWidget {
  const CccCard({required this.child, this.onTap, this.padding, super.key});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final content = padding == null
        ? child
        : Padding(padding: padding!, child: child);
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Lays out a full-screen form with fixed gaps and flexible [Spacer]s, and
/// scrolls when the keyboard or a short screen leaves too little room.
class FullScreenColumn extends StatelessWidget {
  const FullScreenColumn({
    required this.children,
    this.bottomGap = 0,
    this.topGap = 0,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    super.key,
  });

  final List<Widget> children;

  /// Space between the last child and the home indicator area.
  final double bottomGap;

  /// Space below the status bar.
  final double topGap;
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
              24,
              media.padding.top + topGap,
              24,
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

/// A large left-aligned screen title with a line of explanation.
class AuthTitle extends StatelessWidget {
  const AuthTitle({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 30,
              height: 1.12,
              letterSpacing: -0.6,
              color: p.text,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: TextStyle(fontSize: 15.5, height: 1.5, color: p.textSecondary),
        ),
      ],
    );
  }
}

/// A field's label, with "(required)" where it applies.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {this.required = false, super.key});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Text.rich(
      TextSpan(
        text: label,
        children: [
          if (required)
            TextSpan(
              text: ' (required)',
              style: TextStyle(fontWeight: FontWeight.w400, color: p.textMuted),
            ),
        ],
      ),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
    );
  }
}

/// The look shared by every text field: a surface with a firm edge that
/// turns gold while typing.
InputDecoration cccFieldDecoration(
  BuildContext context, {
  String? hint,
  String? helper,
  String? error,
  Widget? suffixIcon,
}) {
  final p = context.palette;
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: p.textMuted),
    helperText: helper,
    helperMaxLines: 3,
    helperStyle: TextStyle(fontSize: 13, color: p.textMuted),
    errorText: error,
    errorStyle: TextStyle(fontSize: 13, color: p.error),
    filled: true,
    fillColor: p.surface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    suffixIcon: suffixIcon,
    enabledBorder: border(p.lineStrong),
    focusedBorder: border(CccColors.primary, 1.5),
    errorBorder: border(p.error),
    focusedErrorBorder: border(p.error, 1.5),
  );
}

/// A labelled text field for the log in and sign up screens. Password
/// fields get a show/hide toggle.
class AuthField extends StatefulWidget {
  const AuthField({
    required this.label,
    required this.controller,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool obscured = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(widget.label),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          obscureText: obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          textCapitalization: widget.textCapitalization,
          onSubmitted: widget.onSubmitted,
          autocorrect: !widget.isPassword,
          enableSuggestions: !widget.isPassword,
          style: TextStyle(fontSize: 16, color: p.text),
          decoration: cccFieldDecoration(
            context,
            suffixIcon: widget.isPassword
                ? IconButton(
                    onPressed: () => setState(() => obscured = !obscured),
                    tooltip: obscured ? 'Show password' : 'Hide password',
                    icon: Icon(
                      obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 22,
                      color: p.textMuted,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// "New here? Create account" style footer link.
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
    final p = context.palette;
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Text.rich(
              TextSpan(
                text: '$prompt ',
                children: [
                  TextSpan(
                    text: action,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: p.accentText,
                    ),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 15, color: p.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round icon button: on a surface with a hairline, or dark and
/// translucent where it sits on a photo.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.overPhoto = false,
    this.iconSize = 20,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool overPhoto;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: overPhoto ? const Color(0x73000000) : p.surface,
        foregroundColor: overPhoto ? Colors.white : p.text,
        side: overPhoto ? null : BorderSide(color: p.line),
        fixedSize: const Size.square(40),
        minimumSize: const Size.square(40),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      icon: Icon(icon, size: iconSize),
    );
  }
}

/// Back to the welcome screen from log in and sign up.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.translate(
        // Lines the circle's edge up with the fields below.
        offset: const Offset(-4, 0),
        child: CircleIconButton(
          icon: Icons.arrow_back_ios_new,
          tooltip: 'Back',
          iconSize: 18,
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
    );
  }
}

/// The back button and title along the top of a pushed screen.
class DetailsHeader extends StatelessWidget {
  const DetailsHeader({this.title, this.actions = const [], super.key});

  final String? title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            const SizedBox(width: 8),
            CircleIconButton(
              icon: Icons.arrow_back_ios_new,
              tooltip: 'Back',
              iconSize: 18,
              onPressed: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: title == null
                  ? const SizedBox.shrink()
                  : Semantics(
                      header: true,
                      child: Text(
                        title!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: p.text,
                        ),
                      ),
                    ),
            ),
            if (actions.isEmpty) const SizedBox(width: 56) else ...actions,
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// The main actions of a details screen, pinned above the home indicator.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
        child: Row(children: children),
      ),
    );
  }
}

/// Home / Events / Church / Ministries / Sermons along the bottom of the
/// screen. The gold pill slides behind the selected section's icon.
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
    final p = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final animate = !MediaQuery.disableAnimationsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / labels.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: animate
                        ? const Duration(milliseconds: 260)
                        : Duration.zero,
                    curve: const Cubic(0.23, 1, 0.32, 1),
                    left:
                        itemWidth * selectedIndex +
                        (itemWidth - _pill.width) / 2,
                    top: 7,
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
    final p = context.palette;
    return Semantics(
      container: true,
      selected: selected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        highlightShape: BoxShape.rectangle,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 200),
          tween: Tween(end: selected ? 1 : 0),
          builder: (context, t, _) => Column(
            children: [
              const SizedBox(height: 7),
              SizedBox(
                height: 32,
                child: Center(
                  // Crossfades between the outlined and filled glyphs.
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      selected ? icons.$2 : icons.$1,
                      key: ValueKey(selected),
                      size: 22,
                      color: Color.lerp(p.textMuted, CccColors.onPrimary, t),
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
                    color: Color.lerp(p.textMuted, p.text, t),
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

/// A quiet filled search box.
class CccSearchField extends StatelessWidget {
  const CccSearchField({
    required this.controller,
    required this.onChanged,
    this.hint = 'Search',
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search, size: 20, color: p.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
                color: p.text,
              ),
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                  color: p.textMuted,
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
                    icon: Icon(Icons.close, size: 18, color: p.textMuted),
                  ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.3,
          color: context.palette.text,
        ),
      ),
    );
  }
}

/// Stand-ins shaped like the cards that are loading, so the screen doesn't
/// jump when they arrive. They pulse gently, and hold still when the system
/// asks for reduced motion.
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
    end: 0.5,
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
    final p = context.palette;
    Widget bone(double widthFactor, double height) => FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: p.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
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
              if (i > 0) const SizedBox(height: 14),
              CccCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.photo) ...[
                      bone(1, 140),
                      const SizedBox(height: 16),
                    ],
                    bone(0.35, 12),
                    const SizedBox(height: 12),
                    bone(0.7, 18),
                    const SizedBox(height: 12),
                    bone(0.9, 13),
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
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: context.palette.lineStrong,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Bottom sheet that invites a guest to log in before a member-only action.
Future<void> showLoginPrompt(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    barrierColor: CccColors.scrim,
    builder: (sheetContext) {
      final p = sheetContext.palette;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              const SizedBox(height: 22),
              Text(
                'Log in to continue',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: p.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Members can join ministries, get event reminders and keep '
                'their branch on every phone.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: p.textSecondary,
                ),
              ),
              const SizedBox(height: 22),
              CccButton(
                label: 'Log in',
                onPressed: () {
                  Navigator.pop(sheetContext);
                  CccNavigation.openLogin(context);
                },
              ),
              const SizedBox(height: 10),
              CccButton(
                label: 'Create account',
                variant: CccButtonVariant.outlined,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  CccNavigation.openSignUp(context);
                },
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                style: TextButton.styleFrom(
                  foregroundColor: p.textSecondary,
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(
                    fontFamily: CccFonts.openSans,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void showCccMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
