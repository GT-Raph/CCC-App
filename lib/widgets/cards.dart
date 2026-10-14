import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/branch.dart';
import '../models/event.dart';
import '../models/live_stream.dart';
import '../models/ministry.dart';
import '../models/news.dart';
import '../models/sermon.dart';
import '../theme/ccc_theme.dart';
import 'ccc_widgets.dart';
import 'media.dart';

const _cardRadius = BorderRadius.all(Radius.circular(20));
const _eventCardRadius = BorderRadius.all(Radius.circular(10));

/// "News by church" card on the Home tab.
class NewsCard extends StatelessWidget {
  const NewsCard({
    required this.item,
    required this.onDetails,
    required this.onShare,
    super.key,
  });

  final NewsItem item;
  final VoidCallback onDetails;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CccColors.paper,
      borderRadius: _cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onDetails,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 15, top: 5, right: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: CccColors.navy,
                        ),
                      ),
                    ),
                  ),
                  ShareIconButton(onPressed: onShare, size: 24),
                ],
              ),
            ),
            if (item.subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              _padded(
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: CccColors.body,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            _padded(
              IconTextRow(
                icon: Icons.church,
                iconSize: 16,
                iconTop: 1,
                gutter: 22,
                text: item.church,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 18 / 14,
                  color: CccColors.body,
                ),
              ),
            ),
            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: 12),
              _padded(
                Text(
                  item.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    color: CccColors.body,
                  ),
                ),
              ),
            ],
            if (item.images.isNotEmpty) ...[
              const SizedBox(height: 15),
              ImageStrip(images: item.images),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DetailsLink(onTap: onDetails),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _padded(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 15),
    child: child,
  );
}

/// "Details →": navy text with the brand-yellow arrow, 44px tall to tap.
class DetailsLink extends StatelessWidget {
  const DetailsLink({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: const SizedBox(
        height: 44,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: CccColors.navy,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.arrow_forward, size: 20, color: CccColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Share icon with a full 44px touch target around it.
class ShareIconButton extends StatelessWidget {
  const ShareIconButton({required this.onPressed, this.size = 30, super.key});

  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Share',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size > 44 ? size : 44,
        child: InkResponse(
          onTap: onPressed,
          radius: 24,
          child: Center(
            child: Icon(Icons.share, size: size, color: CccColors.ink),
          ),
        ),
      ),
    );
  }
}

/// Title, church, date, host, address and description rows shared by the
/// event card and the event details screen.
class EventInfo extends StatelessWidget {
  const EventInfo({required this.event, this.compact = false, super.key});

  final Event event;

  /// On a card: the address and description are cut short; the details
  /// screen shows them in full.
  final bool compact;

  static const _rowStyle = TextStyle(
    fontSize: 16,
    height: 21 / 16,
    color: CccColors.body,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1,
            color: CccColors.navy,
          ),
        ),
        const SizedBox(height: 20),
        IconTextRow(
          icon: Icons.church,
          iconSize: 18,
          text: event.churchLabel,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1,
            color: CccColors.body,
          ),
        ),
        const SizedBox(height: 15),
        IconTextRow(
          glyph: const CustomPaint(
            size: Size(14, 16),
            painter: _CalendarGlyph(),
          ),
          iconLeft: 3,
          iconTop: 2,
          text: event.dateLabel,
          style: _rowStyle,
        ),
        const SizedBox(height: 15),
        IconTextRow(
          icon: Icons.person,
          iconSize: 22,
          iconLeft: -2,
          iconTop: -1,
          text: event.host,
          style: _rowStyle,
        ),
        const SizedBox(height: 15),
        IconTextRow(
          icon: Icons.location_on,
          iconSize: 19,
          iconLeft: -1,
          iconTop: 1,
          text: event.address,
          style: _rowStyle,
          maxLines: compact ? 2 : null,
        ),
        const SizedBox(height: 15),
        IconTextRow(
          glyph: const CustomPaint(size: Size(15, 15), painter: _ChatGlyph()),
          iconLeft: 3,
          iconTop: 2,
          text: event.description,
          style: _rowStyle,
          maxLines: compact ? 3 : null,
        ),
      ],
    );
  }
}

/// A yellow icon in a 27px gutter followed by text, as in the event rows.
class IconTextRow extends StatelessWidget {
  const IconTextRow({
    required this.text,
    required this.style,
    this.icon,
    this.glyph,
    this.iconSize = 18,
    this.iconLeft = 0,
    this.iconTop = 0,
    this.gutter = 27,
    this.maxLines,
    super.key,
  });

  final IconData? icon;

  /// A drawn icon used instead of [icon] where Material has no match.
  final Widget? glyph;
  final String text;
  final TextStyle style;
  final double iconSize;
  final double iconLeft;
  final double iconTop;
  final double gutter;

  /// Cuts the text short with an ellipsis.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: gutter,
          height: 1,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 0,
            minHeight: 0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: Transform.translate(
              offset: Offset(iconLeft, iconTop),
              child:
                  glyph ?? Icon(icon, size: iconSize, color: CccColors.primary),
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: style,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// "Events near me" card.
class EventCard extends StatelessWidget {
  const EventCard({
    required this.event,
    required this.reminded,
    required this.onOpen,
    required this.onAction,
    required this.onShare,
    this.live,
    super.key,
  });

  final Event event;
  final bool reminded;
  final VoidCallback onOpen;

  /// Join Now, Remind Me / Reminded, or Watch Live while [live].
  final VoidCallback onAction;
  final VoidCallback onShare;

  /// The host branch's stream while the event is on and it is live.
  final LiveStream? live;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CccColors.paper,
      borderRadius: _eventCardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ImageCarousel(
              images: event.images,
              height: 164,
              isLive: live != null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: EventInfo(event: event, compact: true),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Spacer(flex: 53),
                SizedBox.square(
                  dimension: 44,
                  child: InkResponse(
                    onTap: onOpen,
                    radius: 24,
                    child: const Center(
                      child: Icon(
                        Icons.info_outline,
                        size: 31,
                        color: CccColors.ink,
                        semanticLabel: 'Event details',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 21.5),
                EventActionButton(
                  event: event,
                  reminded: reminded,
                  live: live != null,
                  onPressed: onAction,
                  width: 188,
                  height: 44,
                  fontSize: 14,
                ),
                const SizedBox(width: 21),
                ShareIconButton(onPressed: onShare),
                const Spacer(flex: 37),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Watch Live while the event is streaming, otherwise Join Now / Remind Me /
/// Reminded, depending on the event and the member's reminder.
class EventActionButton extends StatelessWidget {
  const EventActionButton({
    required this.event,
    required this.reminded,
    required this.onPressed,
    this.live = false,
    this.width,
    this.height = 60,
    this.fontSize = 20,
    this.joinVariant = CccButtonVariant.outlined,
    super.key,
  });

  final Event event;
  final bool reminded;
  final VoidCallback onPressed;
  final double? width;
  final double height;
  final double fontSize;
  final CccButtonVariant joinVariant;
  final bool live;

  @override
  Widget build(BuildContext context) {
    if (live) {
      return CccButton(
        label: 'Watch Live',
        onPressed: onPressed,
        width: width,
        height: height,
        fontSize: fontSize,
        iconGap: 6,
        icon: Icon(Icons.play_arrow_rounded, size: fontSize + 8),
      );
    }
    if (event.joinable) {
      return CccButton(
        label: 'Join Now',
        onPressed: onPressed,
        variant: joinVariant,
        width: width,
        height: height,
        fontSize: fontSize,
      );
    }
    return CccButton(
      label: reminded ? 'Reminded' : 'Remind Me',
      onPressed: onPressed,
      variant: reminded ? CccButtonVariant.filled : CccButtonVariant.outlined,
      width: width,
      height: height,
      fontSize: fontSize,
      iconGap: 8,
      icon: Transform.rotate(
        angle: -math.pi / 9,
        child: Icon(Icons.notifications, size: fontSize + 4),
      ),
    );
  }
}

/// A church branch from Google Maps on the Church tab ("Our Savior's
/// Church" card in the design).
class BranchCard extends StatelessWidget {
  const BranchCard({
    required this.branch,
    required this.photoUrl,
    required this.onOpen,
    required this.onDirections,
    super.key,
  });

  final Branch branch;
  final String Function(String photoName) photoUrl;
  final VoidCallback onOpen;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    // Google listing names can run to two lines, so give them some leading.
    const nameStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: CccColors.ink,
    );
    const addressStyle = TextStyle(
      fontSize: 14,
      height: 18 / 14,
      color: CccColors.ink,
    );
    const metaStyle = TextStyle(
      fontSize: 14,
      height: 16 / 14,
      color: CccColors.ink,
    );
    final distance = branch.distanceLabel;

    return Material(
      color: CccColors.paper,
      borderRadius: _eventCardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NetworkPhotoStrip(
                    photos: [
                      for (final photo in branch.photos)
                        (url: photoUrl(photo.name), credit: photo.author),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 13, right: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconTextRow(
                          icon: Icons.church,
                          iconSize: 18,
                          gutter: 24,
                          text: branch.name,
                          style: nameStyle,
                        ),
                        const SizedBox(height: 20),
                        IconTextRow(
                          icon: Icons.location_on,
                          iconSize: 19,
                          iconLeft: -1,
                          iconTop: 1,
                          gutter: 24,
                          text: branch.address,
                          style: addressStyle,
                        ),
                        const SizedBox(height: 20),
                        if (distance != null)
                          IconTextRow(
                            icon: Icons.pin_drop_outlined,
                            iconSize: 18,
                            iconLeft: -1,
                            gutter: 24,
                            text: distance,
                            style: metaStyle,
                          )
                        else
                          const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: DirectionsButton(onTap: onDirections),
            ),
          ],
        ),
      ),
    );
  }
}

/// A branch streaming live outside any listed event, at the top of the
/// Events tab.
class LiveNowCard extends StatelessWidget {
  const LiveNowCard({
    required this.stream,
    required this.branchName,
    required this.onWatch,
    super.key,
  });

  final LiveStream stream;
  final String branchName;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CccColors.paper,
      borderRadius: _eventCardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onWatch,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CccPhoto(
                    'https://i.ytimg.com/vi/${stream.videoId}/hqdefault.jpg',
                  ),
                  const Positioned(
                    top: 10,
                    right: 10,
                    child: LiveBadge(width: 48),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$branchName is live now',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CccColors.body,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stream.title ?? 'Live stream',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: CccColors.navy,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: CccButton(
                      label: 'Watch Live',
                      onPressed: onWatch,
                      width: 188,
                      height: 44,
                      fontSize: 14,
                      iconGap: 6,
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A ministry on the Ministries tab, laid out like the design's "Kharis
/// Ladies" card: photos, name, when and where it meets, members and Join.
class MinistryCard extends StatelessWidget {
  const MinistryCard({
    required this.ministry,
    required this.joined,
    required this.onOpen,
    required this.onJoin,
    super.key,
  });

  final Ministry ministry;
  final bool joined;
  final VoidCallback onOpen;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    const nameStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: CccColors.ink,
    );
    const focusStyle = TextStyle(
      fontSize: 14,
      height: 18 / 14,
      color: CccColors.body,
    );
    const metaStyle = TextStyle(
      fontSize: 14,
      height: 18 / 14,
      color: CccColors.ink,
    );

    return Material(
      color: CccColors.paper,
      borderRadius: _eventCardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ministry.images.isNotEmpty) ...[
                ImageStrip(images: ministry.images),
                const SizedBox(height: 20),
              ],
              Padding(
                padding: const EdgeInsets.only(left: 13, right: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconTextRow(
                      icon: Icons.church,
                      iconSize: 18,
                      iconTop: 1,
                      gutter: 24,
                      text: ministry.name,
                      style: nameStyle,
                    ),
                    if (ministry.focus.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: Text(ministry.focus, style: focusStyle),
                      ),
                    ],
                    if (ministry.meets.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      IconTextRow(
                        glyph: const CustomPaint(
                          size: Size(13, 15),
                          painter: _CalendarGlyph(),
                        ),
                        iconLeft: 2,
                        iconTop: 1,
                        gutter: 24,
                        text: ministry.meets,
                        style: metaStyle,
                      ),
                    ],
                    if (ministry.venue.isNotEmpty) ...[
                      SizedBox(height: ministry.meets.isEmpty ? 16 : 12),
                      IconTextRow(
                        icon: Icons.location_on,
                        iconSize: 18,
                        iconLeft: -1,
                        gutter: 24,
                        text: ministry.venue,
                        style: metaStyle,
                      ),
                    ],
                    // The row is as tall as the Join tag's tap area, which
                    // already spaces it from the venue.
                    Row(
                      children: [
                        if (ministry.members.isNotEmpty) ...[
                          SizedBox(
                            width: 24,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Transform.translate(
                                offset: const Offset(-1, 0),
                                child: const Icon(
                                  Icons.groups_outlined,
                                  size: 19,
                                  color: CccColors.primary,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${ministry.members} members',
                              style: metaStyle,
                            ),
                          ),
                        ] else
                          const Spacer(),
                        JoinChip(
                          joined: joined,
                          ministryName: ministry.name,
                          onTap: onJoin,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The design's small yellow "Join" tag. Once joined it turns into a pale
/// "Joined" tag with a check; tapping it again leaves the ministry.
class JoinChip extends StatefulWidget {
  const JoinChip({
    required this.joined,
    required this.ministryName,
    required this.onTap,
    super.key,
  });

  final bool joined;
  final String ministryName;
  final VoidCallback onTap;

  @override
  State<JoinChip> createState() => _JoinChipState();
}

class _JoinChipState extends State<JoinChip> {
  bool pressed = false;

  void _press(bool value) {
    if (pressed != value) setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final joined = widget.joined;
    // Its own node, so screen readers can reach it apart from the card.
    return Semantics(
      container: true,
      button: true,
      label: joined
          ? 'Joined ${widget.ministryName}'
          : 'Join ${widget.ministryName}',
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: widget.onTap,
        // 44px tall so the 28px tag is still easy to hit.
        child: SizedBox(
          height: 44,
          child: Center(
            child: AnimatedScale(
              scale: pressed ? 0.95 : 1,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 88,
                height: 28,
                decoration: BoxDecoration(
                  color: joined ? CccColors.primaryTint : CccColors.primary,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: CccColors.primary, width: 1.2),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.85, end: 1.0).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Padding(
                    key: ValueKey(joined),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    // Shrinks rather than overflowing with large text sizes.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: joined
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: CccColors.primary,
                                ),
                                SizedBox(width: 4),
                                Text('Joined', style: _chipStyle),
                              ],
                            )
                          : const Text('Join', style: _chipStyle),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _chipStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1,
    color: CccColors.ink,
  );
}

/// Name, focus, meeting time, venue, members and description on the ministry
/// details screen, in the style of [EventInfo].
class MinistryInfo extends StatelessWidget {
  const MinistryInfo({required this.ministry, super.key});

  final Ministry ministry;

  static const _rowStyle = TextStyle(
    fontSize: 16,
    height: 21 / 16,
    color: CccColors.body,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ministry.name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: CccColors.navy,
          ),
        ),
        if (ministry.focus.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            ministry.focus,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: CccColors.body,
            ),
          ),
        ],
        for (final row in [
          if (ministry.meets.isNotEmpty)
            IconTextRow(
              glyph: const CustomPaint(
                size: Size(14, 16),
                painter: _CalendarGlyph(),
              ),
              iconLeft: 3,
              iconTop: 2,
              text: ministry.meets,
              style: _rowStyle,
            ),
          if (ministry.venue.isNotEmpty)
            IconTextRow(
              icon: Icons.location_on,
              iconSize: 19,
              iconLeft: -1,
              iconTop: 1,
              text: ministry.venue,
              style: _rowStyle,
            ),
          if (ministry.members.isNotEmpty)
            IconTextRow(
              icon: Icons.groups_outlined,
              iconSize: 22,
              iconLeft: -1,
              iconTop: -1,
              text: '${ministry.members} members',
              style: _rowStyle,
            ),
          if (ministry.about.isNotEmpty)
            IconTextRow(
              glyph: const CustomPaint(
                size: Size(15, 15),
                painter: _ChatGlyph(),
              ),
              iconLeft: 3,
              iconTop: 3,
              text: ministry.about,
              style: _rowStyle,
            ),
        ]) ...[const SizedBox(height: 15), row],
      ],
    );
  }
}

enum SermonPlayback { none, loading, playing, paused }

/// A sermon on the Sermons tab. Tapping it plays it, or pauses it when it is
/// the one playing.
class SermonCard extends StatelessWidget {
  const SermonCard({
    required this.sermon,
    required this.playback,
    required this.onTap,
    this.position,
    this.length = Duration.zero,
    super.key,
  });

  final Sermon sermon;
  final SermonPlayback playback;
  final VoidCallback onTap;

  /// Playback position, for the progress line under the sermon that is
  /// loaded in the player.
  final ValueListenable<Duration>? position;
  final Duration length;

  @override
  Widget build(BuildContext context) {
    const metaStyle = TextStyle(fontSize: 13, height: 1, color: CccColors.body);
    final durationLabel = sermon.durationLabel;
    final position = this.position;

    return Material(
      color: CccColors.paper,
      borderRadius: _eventCardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PlayBadge(playback: playback, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sermon.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: CccColors.ink,
                          ),
                        ),
                        if (sermon.preacher.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            sermon.preacher,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 18 / 14,
                              color: CccColors.body,
                            ),
                          ),
                        ],
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 16,
                          runSpacing: 6,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CustomPaint(
                                  size: Size(11, 13),
                                  painter: _CalendarGlyph(),
                                ),
                                const SizedBox(width: 6),
                                Text(sermon.dateLabel, style: metaStyle),
                              ],
                            ),
                            if (durationLabel != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.schedule,
                                    size: 14,
                                    color: CccColors.primary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(durationLabel, style: metaStyle),
                                ],
                              ),
                            if (sermon.forAllBranches)
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.public,
                                    size: 14,
                                    color: CccColors.primary,
                                  ),
                                  SizedBox(width: 5),
                                  Text('All branches', style: metaStyle),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (position != null)
              ValueListenableBuilder(
                valueListenable: position,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: length > Duration.zero
                      ? (value.inMilliseconds / length.inMilliseconds).clamp(
                          0.0,
                          1.0,
                        )
                      : 0,
                  minHeight: 3,
                  color: CccColors.primary,
                  backgroundColor: CccColors.primaryTint,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Yellow play / pause button face. Black icons keep it readable; white on
/// the brand yellow is too faint for an icon this important.
class PlayBadge extends StatelessWidget {
  const PlayBadge({
    required this.playback,
    required this.size,
    this.circle = false,
    super.key,
  });

  final SermonPlayback playback;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 0.62;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: CccColors.primary,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size / 4),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.8, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: switch (playback) {
          SermonPlayback.loading => SizedBox.square(
            key: const ValueKey('loading'),
            dimension: size * 0.4,
            child: const CircularProgressIndicator(
              strokeWidth: 2.4,
              color: CccColors.ink,
            ),
          ),
          SermonPlayback.playing => Icon(
            Icons.pause_rounded,
            key: const ValueKey('pause'),
            size: iconSize,
            color: CccColors.ink,
            semanticLabel: 'Pause',
          ),
          _ => Icon(
            Icons.play_arrow_rounded,
            key: const ValueKey('play'),
            size: iconSize,
            color: CccColors.ink,
            semanticLabel: 'Play',
          ),
        },
      ),
    );
  }
}

/// Yellow diamond that opens turn-by-turn directions.
class DirectionsButton extends StatelessWidget {
  const DirectionsButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Directions',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox.square(
          dimension: 56.57,
          child: Center(
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CccColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Transform.rotate(
                  angle: -math.pi / 4,
                  child: const Icon(
                    Icons.turn_right,
                    size: 20,
                    color: CccColors.paper,
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

/// Solid calendar with binder tabs (event date row).
class _CalendarGlyph extends CustomPainter {
  const _CalendarGlyph();

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = CccColors.primary;
    canvas.drawRRect(
      RRect.fromLTRBR(
        0,
        2,
        size.width,
        size.height,
        const Radius.circular(1.5),
      ),
      fill,
    );
    final tab = size.width * 0.13;
    for (final x in [size.width * 0.22, size.width * 0.78 - tab]) {
      canvas.drawRRect(
        RRect.fromLTRBR(x, 0, x + tab, 4, const Radius.circular(1)),
        fill,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 5.5, size.width, 1),
      Paint()..color = CccColors.paper,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Round speech bubble with two lines (event description row).
class _ChatGlyph extends CustomPainter {
  const _ChatGlyph();

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = CccColors.primary;
    final radius = size.width / 2;
    canvas.drawCircle(Offset(radius, radius), radius, fill);
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width * 0.12, size.height * 0.55)
        ..lineTo(size.width * 0.45, size.height * 0.88)
        ..close(),
      fill,
    );
    final line = Paint()
      ..color = CccColors.paper
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.4),
      Offset(size.width * 0.7, size.height * 0.4),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.62),
      Offset(size.width * 0.58, size.height * 0.62),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
