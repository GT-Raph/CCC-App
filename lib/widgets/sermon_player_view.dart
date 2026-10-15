import 'package:flutter/material.dart';

import '../models/sermon.dart';
import '../services/external_actions.dart';
import '../state/ccc_state.dart';
import '../state/sermon_player.dart';
import '../theme/ccc_theme.dart';
import 'cards.dart';
import 'ccc_widgets.dart';

/// How [sermon] shows in the list given what the player is doing.
SermonPlayback playbackOf(SermonPlayer player, Sermon sermon) {
  if (player.sermon?.id != sermon.id) return SermonPlayback.none;
  if (player.buffering) return SermonPlayback.loading;
  return player.playing ? SermonPlayback.playing : SermonPlayback.paused;
}

/// Bar above the navigation bar while a sermon is loaded. Tapping it opens
/// the full player.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = CccScope.of(context).player;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final sermon = player.sermon;
        if (sermon == null) return const SizedBox.shrink();
        final error = player.error;
        final p = context.palette;
        return _SlideUp(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(top: BorderSide(color: p.line)),
            ),
            // Sits on the navigation bar, which keeps clear of the home
            // indicator, so it needs no bottom inset of its own.
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProgressLine(player: player),
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () => showSermonPlayer(context),
                      child: SizedBox(
                        height: 64,
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            _RoundButton(
                              label: player.playing ? 'Pause' : 'Play',
                              onTap: player.toggle,
                              child: PlayBadge(
                                playback: playbackOf(player, sermon),
                                size: 44,
                                circle: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sermon.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                      color: p.text,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    error ?? player.branchName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.2,
                                      color: error == null
                                          ? p.textMuted
                                          : p.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: player.close,
                              tooltip: 'Close player',
                              icon: Icon(Icons.close, color: p.textMuted),
                            ),
                            const SizedBox(width: 6),
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
      },
    );
  }
}

/// Slides the mini player up from below the screen edge when it appears.
class _SlideUp extends StatelessWidget {
  const _SlideUp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) => FractionalTranslation(
        translation: Offset(0, 1 - t),
        child: Opacity(opacity: t, child: child),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.player});

  final SermonPlayer player;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: player.position,
      builder: (context, position, _) {
        final total = player.duration.inMilliseconds;
        return LinearProgressIndicator(
          value: total > 0
              ? (position.inMilliseconds / total).clamp(0.0, 1.0)
              : 0,
          minHeight: 2,
          color: CccColors.primary,
          backgroundColor: context.palette.line,
        );
      },
    );
  }
}

/// Full player: title, seek bar, skip buttons, speed, share and the sermon
/// notes.
Future<void> showSermonPlayer(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _PlayerSheet(),
  );
}

class _PlayerSheet extends StatelessWidget {
  const _PlayerSheet();

  @override
  Widget build(BuildContext context) {
    final player = CccScope.of(context).player;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final sermon = player.sermon;
        if (sermon == null) return const SizedBox(height: 120);
        final error = player.error;
        final p = context.palette;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 22),
                  Text(
                    player.branchName,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: p.accentText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sermon.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 25,
                      height: 1.2,
                      letterSpacing: -0.5,
                      color: p.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (sermon.preacher.isNotEmpty)
                    Text(
                      sermon.preacher,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: p.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    sermon.dateLabel,
                    style: TextStyle(fontSize: 14, color: p.textMuted),
                  ),
                  const SizedBox(height: 22),
                  _SeekBar(player: player),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoundButton(
                        label: 'Back 10 seconds',
                        onTap: () => player.skip(const Duration(seconds: -10)),
                        child: const _SkipIcon(Icons.replay_10),
                      ),
                      const SizedBox(width: 28),
                      _RoundButton(
                        label: player.playing ? 'Pause' : 'Play',
                        onTap: player.toggle,
                        child: PlayBadge(
                          playback: playbackOf(player, sermon),
                          size: 72,
                          circle: true,
                        ),
                      ),
                      const SizedBox(width: 28),
                      _RoundButton(
                        label: 'Forward 30 seconds',
                        onTap: () => player.skip(const Duration(seconds: 30)),
                        child: const _SkipIcon(Icons.forward_30),
                      ),
                    ],
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: p.error),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _SpeedButton(player: player),
                      const Spacer(),
                      Builder(
                        builder: (buttonContext) => TextButton.icon(
                          onPressed: () => ExternalActions.share(
                            buttonContext,
                            sermon.shareText(player.branchName),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: p.text,
                            minimumSize: const Size(48, 44),
                          ),
                          icon: const Icon(Icons.share_outlined, size: 20),
                          label: const Text(
                            'Share',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (sermon.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Text(
                      sermon.description,
                      style: TextStyle(
                        fontSize: 15.5,
                        height: 1.6,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.player});

  final SermonPlayer player;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  /// Where the thumb is while it is being dragged.
  double? dragging;

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final p = context.palette;
    final timeStyle = TextStyle(
      fontSize: 13,
      color: p.textMuted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ValueListenableBuilder(
      valueListenable: player.position,
      builder: (context, position, _) {
        final total = player.duration.inMilliseconds.toDouble();
        final value = (dragging ?? position.inMilliseconds.toDouble()).clamp(
          0.0,
          total > 0 ? total : 1.0,
        );
        final shown = Duration(milliseconds: value.round());
        final left = Duration(milliseconds: (total - value).round());
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: CccColors.primary,
                inactiveTrackColor: p.line,
                thumbColor: CccColors.primary,
                overlayColor: CccColors.primary.withValues(alpha: 0.15),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                // Lines the track up with the text above and the times below.
                padding: const EdgeInsets.symmetric(vertical: 14),
                value: value,
                max: total > 0 ? total : 1,
                semanticFormatterCallback: (value) =>
                    clockLabel(Duration(milliseconds: value.round())),
                onChanged: total > 0
                    ? (value) => setState(() => dragging = value)
                    : null,
                onChangeEnd: (value) async {
                  await player.seek(Duration(milliseconds: value.round()));
                  if (mounted) setState(() => dragging = null);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Text(clockLabel(shown), style: timeStyle),
                  const Spacer(),
                  Text(
                    total > 0 ? '-${clockLabel(left)}' : '',
                    style: timeStyle,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SkipIcon extends StatelessWidget {
  const _SkipIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 52,
      child: Icon(icon, size: 32, color: context.palette.text),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.player});

  final SermonPlayer player;

  static String _label(double speed) =>
      '${speed.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')}×';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final speeds = SermonPlayer.speeds;
    final next = speeds[(speeds.indexOf(player.speed) + 1) % speeds.length];
    return Semantics(
      button: true,
      label: 'Playback speed ${_label(player.speed)}',
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: () => player.setSpeed(next),
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          backgroundColor: p.surfaceAlt,
          side: BorderSide.none,
          minimumSize: const Size(64, 44),
          shape: const StadiumBorder(),
        ),
        child: Text(
          _label(player.speed),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// A button that shrinks slightly while pressed.
class _RoundButton extends StatefulWidget {
  const _RoundButton({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<_RoundButton> {
  bool pressed = false;

  void _press(bool value) {
    if (pressed != value) setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: pressed ? 0.94 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
