import 'package:flutter/material.dart';

import '../theme/ccc_theme.dart';
import 'ccc_widgets.dart';

/// Horizontally scrolling row of 100 × 100 photos that runs off the card
/// edge. Photos can be bundled assets or uploaded (https) ones.
class ImageStrip extends StatelessWidget {
  const ImageStrip({required this.images, this.leftPadding = 15, super.key});

  final List<String> images;
  final double leftPadding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(left: leftPadding, right: leftPadding),
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox.square(
            dimension: 100,
            child: CccPhoto(images[index]),
          ),
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
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: photos.isEmpty ? 1 : photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox.square(
            dimension: 100,
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
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const ColoredBox(color: CccColors.background),
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
                color: CccColors.paper,
                shadows: [Shadow(blurRadius: 3)],
              ),
            ),
          ),
      ],
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: CccColors.background,
      child: Icon(Icons.church, color: CccColors.inactive, size: 36),
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
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const _PhotoPlaceholder(),
      errorBuilder: (_, _, _) => const _NoPhotos(),
    );
  }
}

/// Stands in for an event that has no photos: the app's misty header photo
/// with the church logo, so the card still reads as a card.
class _NoPhotos extends StatelessWidget {
  const _NoPhotos();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(CccAssets.headerBackground, fit: BoxFit.cover),
        const ColoredBox(color: Color(0x80FFFFFF)),
        const Center(child: ChurchLogo(width: 64, color: CccColors.navy)),
      ],
    );
  }
}

/// Swipeable event photos with page dots and an optional LIVE badge. With no
/// photos it shows a plain placeholder.
class ImageCarousel extends StatefulWidget {
  const ImageCarousel({
    required this.images,
    required this.height,
    this.isLive = false,
    this.badgeWidth = 40,
    this.badgeInset = 10,
    this.dotsBottom = 15,
    super.key,
  });

  final List<String> images;
  final double height;
  final bool isLive;
  final double badgeWidth;
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
            const _NoPhotos()
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
              right: widget.badgeInset,
              child: LiveBadge(width: widget.badgeWidth),
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
          if (i > 0) const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == index ? CccColors.paper : Colors.transparent,
              border: Border.all(color: CccColors.paper, width: 1.2),
            ),
          ),
        ],
      ],
    );
  }
}

class LiveBadge extends StatelessWidget {
  const LiveBadge({this.width = 40, super.key});

  final double width;

  @override
  Widget build(BuildContext context) {
    final inset = width * 2.22 / 40;
    return Container(
      width: width,
      height: width * 18.89 / 40,
      padding: EdgeInsets.all(inset),
      decoration: BoxDecoration(
        color: CccColors.paper,
        borderRadius: BorderRadius.circular(width / 40),
      ),
      child: Image.asset(
        CccAssets.liveBadge,
        fit: BoxFit.fill,
        semanticLabel: 'Live',
      ),
    );
  }
}
