import 'package:flutter/material.dart';

import '../theme/ccc_theme.dart';
import 'ccc_widgets.dart';
import 'media.dart';

/// The layout shared by the news, event and ministry screens: a back button,
/// the photos in a rounded frame, the content, and the main actions pinned
/// along the bottom.
class DetailsScaffold extends StatelessWidget {
  const DetailsScaffold({
    required this.children,
    this.images = const [],
    this.isLive = false,
    this.actions = const [],
    super.key,
  });

  final List<String> images;
  final bool isLive;
  final List<Widget> children;

  /// The bottom bar's buttons; none hides the bar.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final photoHeight = ((media.size.width - 40) * 0.62).clamp(160.0, 360.0);
    return Scaffold(
      bottomNavigationBar: actions.isEmpty
          ? null
          : BottomActionBar(children: actions),
      body: Column(
        children: [
          const DetailsHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                28 + (actions.isEmpty ? media.padding.bottom : 0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (images.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ImageCarousel(
                        images: images,
                        height: photoHeight,
                        isLive: isLive,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  ...children,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The gold label above a details title: which branch, or what kind.
class DetailsEyebrow extends StatelessWidget {
  const DetailsEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: context.palette.accentText,
      ),
    );
  }
}

/// The large title of a details screen.
class DetailsTitle extends StatelessWidget {
  const DetailsTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w800,
          height: 1.18,
          letterSpacing: -0.6,
          color: context.palette.text,
        ),
      ),
    );
  }
}

/// A section of running text under a small heading ("About").
class DetailsSection extends StatelessWidget {
  const DetailsSection({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [SectionTitle(title), const SizedBox(height: 10), child],
      ),
    );
  }
}

/// Long-form text on a details screen.
class DetailsBody extends StatelessWidget {
  const DetailsBody(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        height: 1.65,
        color: context.palette.textSecondary,
      ),
    );
  }
}

/// "Share" in a details screen's bottom bar.
class ShareButton extends StatelessWidget {
  const ShareButton({required this.onPressed, this.expand = false, super.key});

  final VoidCallback onPressed;

  /// Takes the bar's full width when it's the only action.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return CccButton(
      label: 'Share',
      variant: CccButtonVariant.outlined,
      width: expand ? null : 116,
      iconGap: 8,
      icon: const Icon(Icons.share_outlined),
      onPressed: onPressed,
    );
  }
}
