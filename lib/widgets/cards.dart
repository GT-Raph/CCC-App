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

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// A small muted icon followed by text, for when and where something is.
class MetaRow extends StatelessWidget {
  const MetaRow({
    required this.icon,
    required this.text,
    this.maxLines,
    super.key,
  });

  final IconData icon;
  final String text;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: p.textMuted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, height: 1.4, color: p.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Which branch something belongs to, above its title.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Icon(Icons.church_outlined, size: 14, color: p.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: p.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

TextStyle _cardTitle(CccPalette p, [double size = 18]) => TextStyle(
  fontSize: size,
  fontWeight: FontWeight.w700,
  height: 1.3,
  letterSpacing: -0.2,
  color: p.text,
);

/// A news story on the Home tab.
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
    final p = context.palette;
    return CccCard(
      onTap: onDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.images.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CccPhoto(item.images.first),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Eyebrow(item.church),
                        const SizedBox(height: 8),
                        Text(item.title, style: _cardTitle(p)),
                        if (item.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                ShareIconButton(onPressed: onShare),
              ],
            ),
          ),
          if (item.summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                item.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: p.textSecondary,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: DetailsLink(label: 'Read story', onTap: onDetails),
            ),
          ),
        ],
      ),
    );
  }
}

/// A gold text link with an arrow, 44px tall to tap.
class DetailsLink extends StatelessWidget {
  const DetailsLink({required this.onTap, this.label = 'Details', super.key});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: p.accentText,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward, size: 16, color: p.accentText),
            ],
          ),
        ),
      ),
    );
  }
}

/// Share icon with a full 44px touch target around it.
class ShareIconButton extends StatelessWidget {
  const ShareIconButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Share',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 44,
        child: InkResponse(
          onTap: onPressed,
          radius: 22,
          child: Center(
            child: Icon(
              Icons.share_outlined,
              size: 20,
              color: context.palette.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Month and day in a gold-washed tile, so dates can be scanned down a list.
class DateTile extends StatelessWidget {
  const DateTile({required this.date, super.key});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ExcludeSemantics(
      child: Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: p.accentTint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              _months[date.month - 1],
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: p.accentText,
              ),
            ),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: p.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An event on the Events tab: its photo (if any), date, title, branch and
/// the one thing to do about it.
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

  /// Join now, Remind me / Reminded, or Watch live while [live].
  final VoidCallback onAction;
  final VoidCallback onShare;

  /// The host branch's stream while the event is on and it is live.
  final LiveStream? live;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final start = event.startsAt;
    return CccCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (event.images.isNotEmpty)
            ImageCarousel(
              images: event.images,
              height: 176,
              isLive: live != null,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (start != null) ...[
                  DateTile(date: start),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (live != null && event.images.isEmpty) ...[
                        const LiveBadge(),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _cardTitle(p, 17),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.dateLabel,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: p.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event.churchLabel,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: p.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (event.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                event.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: p.textSecondary,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
            child: Row(
              children: [
                Expanded(
                  child: EventActionButton(
                    event: event,
                    reminded: reminded,
                    live: live != null,
                    onPressed: onAction,
                    height: 44,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 4),
                ShareIconButton(onPressed: onShare),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Watch live while the event is streaming, otherwise Join now / Remind me /
/// Reminded, depending on the event and the member's reminder. [prominent]
/// makes Remind me the gold main action, as on the details screen.
class EventActionButton extends StatelessWidget {
  const EventActionButton({
    required this.event,
    required this.reminded,
    required this.onPressed,
    this.live = false,
    this.prominent = false,
    this.width,
    this.height = 52,
    this.fontSize = 16,
    super.key,
  });

  final Event event;
  final bool reminded;
  final VoidCallback onPressed;
  final bool prominent;
  final double? width;
  final double height;
  final double fontSize;
  final bool live;

  @override
  Widget build(BuildContext context) {
    if (live) {
      return CccButton(
        label: 'Watch live',
        onPressed: onPressed,
        width: width,
        height: height,
        fontSize: fontSize,
        iconGap: 6,
        icon: const Icon(Icons.play_arrow_rounded),
      );
    }
    if (event.joinable) {
      return CccButton(
        label: 'Join now',
        onPressed: onPressed,
        variant: prominent
            ? CccButtonVariant.filled
            : CccButtonVariant.outlined,
        width: width,
        height: height,
        fontSize: fontSize,
        iconGap: 6,
        icon: const Icon(Icons.open_in_new),
      );
    }
    return CccButton(
      label: reminded ? 'Reminded' : 'Remind me',
      onPressed: onPressed,
      variant: reminded
          ? CccButtonVariant.tonal
          : prominent
          ? CccButtonVariant.filled
          : CccButtonVariant.outlined,
      width: width,
      height: height,
      fontSize: fontSize,
      iconGap: 8,
      icon: Icon(
        reminded
            ? Icons.notifications_active
            : Icons.notifications_none_outlined,
      ),
    );
  }
}

/// A list of facts with hairlines between them, as on the details screens.
class InfoGroup extends StatelessWidget {
  const InfoGroup({required this.rows, super.key});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return CccCard(
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0) const Divider(height: 1, indent: 50),
            row,
          ],
        ],
      ),
    );
  }
}

/// One fact in an [InfoGroup]; with [onTap] it opens something (call,
/// email, map).
class InfoRow extends StatelessWidget {
  const InfoRow({
    required this.icon,
    required this.text,
    this.label,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String text;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 20, color: p.textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null) ...[
                  Text(
                    label!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: p.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  text,
                  style: TextStyle(fontSize: 15.5, height: 1.4, color: p.text),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 1),
              child: Icon(Icons.chevron_right, size: 20, color: p.textMuted),
            ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

/// When, where and who for an event, on its details and live screens. The
/// branch is in the eyebrow above the title.
class EventFacts extends StatelessWidget {
  const EventFacts({required this.event, this.onAddress, super.key});

  final Event event;
  final VoidCallback? onAddress;

  @override
  Widget build(BuildContext context) {
    return InfoGroup(
      rows: [
        InfoRow(icon: Icons.event_outlined, text: event.dateLabel),
        if (event.host.isNotEmpty)
          InfoRow(icon: Icons.person_outline, label: 'Host', text: event.host),
        if (event.address.isNotEmpty)
          InfoRow(
            icon: Icons.location_on_outlined,
            text: event.address,
            onTap: onAddress,
          ),
      ],
    );
  }
}

/// A church branch from Google Maps on the Church tab.
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
    final p = context.palette;
    final distance = branch.distanceLabel;
    return CccCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          NetworkPhotoStrip(
            photos: [
              for (final photo in branch.photos)
                (url: photoUrl(photo.name), credit: photo.author),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Google listing names can run to two lines.
                Text(branch.name, style: _cardTitle(p, 16.5)),
                const SizedBox(height: 6),
                MetaRow(icon: Icons.location_on_outlined, text: branch.address),
                if (distance != null) ...[
                  const SizedBox(height: 4),
                  MetaRow(icon: Icons.near_me_outlined, text: distance),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: DirectionsButton(onTap: onDirections),
          ),
        ],
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
    final p = context.palette;
    return CccCard(
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
                const Positioned(top: 12, left: 12, child: LiveBadge()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$branchName is live now',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(stream.title ?? 'Live stream', style: _cardTitle(p, 17)),
                const SizedBox(height: 14),
                CccButton(
                  label: 'Watch live',
                  onPressed: onWatch,
                  height: 44,
                  fontSize: 15,
                  iconGap: 6,
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A ministry on the Ministries tab: photos, name, when and where it meets,
/// members and Join.
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
    final p = context.palette;
    return CccCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ministry.images.isNotEmpty) ...[
            const SizedBox(height: 16),
            ImageStrip(images: ministry.images),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ministry.name, style: _cardTitle(p, 17)),
                if (ministry.focus.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    ministry.focus,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: p.textSecondary,
                    ),
                  ),
                ],
                if (ministry.meets.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  MetaRow(icon: Icons.schedule, text: ministry.meets),
                ],
                if (ministry.venue.isNotEmpty) ...[
                  SizedBox(height: ministry.meets.isEmpty ? 10 : 4),
                  MetaRow(
                    icon: Icons.location_on_outlined,
                    text: ministry.venue,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 12, 8),
            child: Row(
              children: [
                if (ministry.members.isNotEmpty) ...[
                  Icon(Icons.groups_outlined, size: 17, color: p.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${ministry.members} members',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: p.textMuted,
                      ),
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
          ),
        ],
      ),
    );
  }
}

/// A small gold "Join" button. Once joined it turns into a quiet "Joined"
/// with a check; tapping it again leaves the ministry.
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
    final p = context.palette;
    final joined = widget.joined;
    final style = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1,
      color: joined ? p.text : CccColors.onPrimary,
    );
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
        // 48px tall so the 34px button is still easy to hit.
        child: SizedBox(
          height: 48,
          child: Center(
            child: AnimatedScale(
              scale: pressed ? 0.95 : 1,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                constraints: const BoxConstraints(minWidth: 84),
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: joined ? p.surface : CccColors.primary,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: joined ? p.lineStrong : CccColors.primary,
                  ),
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
                  child: Center(
                    key: ValueKey(joined),
                    widthFactor: 1,
                    // Shrinks rather than overflowing with large text sizes.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: joined
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: p.accentText,
                                ),
                                const SizedBox(width: 4),
                                Text('Joined', style: style),
                              ],
                            )
                          : Text('Join', style: style),
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
    final p = context.palette;
    final metaStyle = TextStyle(fontSize: 13, height: 1, color: p.textMuted);
    final durationLabel = sermon.durationLabel;
    final position = this.position;

    Widget meta(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: p.textMuted),
        const SizedBox(width: 5),
        Text(text, style: metaStyle),
      ],
    );

    return CccCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                        style: _cardTitle(p, 16),
                      ),
                      if (sermon.preacher.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          sermon.preacher,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: p.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          meta(Icons.event_outlined, sermon.dateLabel),
                          if (durationLabel != null)
                            meta(Icons.schedule, durationLabel),
                          if (sermon.forAllBranches)
                            meta(Icons.public, 'All branches'),
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
                backgroundColor: p.accentTint,
              ),
            ),
        ],
      ),
    );
  }
}

/// Gold play / pause button face. Black icons keep it readable; white on
/// the gold is too faint for an icon this important.
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
    final iconSize = size * 0.6;
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
              color: CccColors.onPrimary,
            ),
          ),
          SermonPlayback.playing => Icon(
            Icons.pause_rounded,
            key: const ValueKey('pause'),
            size: iconSize,
            color: CccColors.onPrimary,
            semanticLabel: 'Pause',
          ),
          _ => Icon(
            Icons.play_arrow_rounded,
            key: const ValueKey('play'),
            size: iconSize,
            color: CccColors.onPrimary,
            semanticLabel: 'Play',
          ),
        },
      ),
    );
  }
}

/// Opens turn-by-turn directions to a branch.
class DirectionsButton extends StatelessWidget {
  const DirectionsButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CccButton(
      label: 'Directions',
      variant: CccButtonVariant.outlined,
      height: 44,
      fontSize: 15,
      iconGap: 6,
      icon: const Icon(Icons.directions_outlined),
      onPressed: onTap,
    );
  }
}
