import 'package:flutter/material.dart';

import '../theme/ccc_theme.dart';
import 'ccc_widgets.dart';

/// Horizontally scrolling row of square photos that runs off the card edge.
/// Photos can be bundled assets or uploaded (https) ones.
class ImageStrip extends StatelessWidget {
  const ImageStrip({required this.images, this.leftPadding = 16, super.key});

  final List<String> images;
  final double leftPadding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: leftPadding),
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox.square(dimension: 96, child: CccPhoto(images[index])),
        ),
      ),
    );
  }
}

typedef WebPhoto = ({String url, String? credit});

/// [ImageStrip] for photos loaded from the web (Google Maps branch photos),
/// with the photographer credit Google asks apps to show.
class NetworkPhotoStrip extends StatelessWidget {
  const NetworkPhotoStrip({required this.photos, super.key});

  final List<WebPhoto> photos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: photos.isEmpty ? 1 : photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox.square(
            dimension: 96,
            child: photos.isEmpty
                ? const _PhotoPlaceholder()
                : _WebPhotoTile(photo: photos[index]),
          ),
        ),
      ),
    );
  }
}

class _WebPhotoTile extends StatelessWidget {
  const _WebPhotoTile({required this.photo});

  final WebPhoto photo;

  @override
  Widget build(BuildContext context) {
    final credit = photo.credit;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          photo.url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : const _PhotoPlaceholder(),
          errorBuilder: (_, _, _) => const _PhotoPlaceholder(),
        ),
        if (credit != null)
          Positioned(
            left: 4,
            right: 4,
            bottom: 3,
            child: Text(
              credit,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 8,
                height: 1,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 3)],
              ),
            ),
          ),
      ],
    );
  }
}

/// While a photo loads, or when a branch has none.
class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ColoredBox(
      color: p.surfaceAlt,
      child: Icon(
        Icons.church_outlined,
        color: p.textMuted.withValues(alpha: 0.6),
        size: 30,
      ),
    );
  }
}

/// A bundled photo, or one uploaded to Supabase (an https link).
class CccPhoto extends StatelessWidget {
  const CccPhoto(this.path, {this.fit = BoxFit.cover, super.key});

  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (!path.startsWith('http')) return Image.asset(path, fit: fit);
    return Image.network(
      path,
      fit: fit,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : ColoredBox(color: context.palette.surfaceAlt),
      errorBuilder: (_, _, _) => const _NoPhoto(),
    );
  }
}

/// Stands in for a photo that couldn't load: the church's mark, faint.
class _NoPhoto extends StatelessWidget {
  const _NoPhoto();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ColoredBox(
      color: p.surfaceAlt,
      child: Center(
        child: ChurchLogo(
          width: 56,
          color: p.textMuted.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

/// Swipeable photos with page dots and an optional Live badge.
class ImageCarousel extends StatefulWidget {
  const ImageCarousel({
    required this.images,
    required this.height,
    this.isLive = false,
    this.badgeInset = 12,
    this.dotsBottom = 14,
    super.key,
  });

  final List<String> images;
  final double height;
  final bool isLive;
  final double badgeInset;
  final double dotsBottom;

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  final controller = PageController();
  int page = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.images.isEmpty)
            const _NoPhoto()
          else
            PageView.builder(
              controller: controller,
              itemCount: widget.images.length,
              onPageChanged: (value) => setState(() => page = value),
              itemBuilder: (context, index) => CccPhoto(widget.images[index]),
            ),
          if (widget.isLive)
            Positioned(
              top: widget.badgeInset,
              left: widget.badgeInset,
              child: const LiveBadge(),
            ),
          if (widget.images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: widget.dotsBottom,
              child: PageDots(count: widget.images.length, index: page),
            ),
        ],
      ),
    );
  }
}

class PageDots extends StatelessWidget {
  const PageDots({required this.count, required this.index, super.key});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: i == index ? Colors.white : const Color(0x99FFFFFF),
              boxShadow: const [
                BoxShadow(color: Color(0x40000000), blurRadius: 4),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Red "Live" pill for streams that are on now.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});

  /// White on this red is 4.9:1.
  static const red = Color(0xFFD92D20);

  @override
  Widget build(BuildContext context) {
    // Its own node, so screen readers announce it apart from the title.
    return Semantics(
      container: true,
      label: 'Live',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        decoration: BoxDecoration(
          color: red,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(dimension: 6),
            ),
            SizedBox(width: 6),
            Text(
              'Live',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1.1,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
