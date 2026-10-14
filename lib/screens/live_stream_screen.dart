import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/event.dart';
import '../models/live_stream.dart';
import '../services/external_actions.dart';
import '../theme/ccc_theme.dart';
import '../widgets/cards.dart';
import '../widgets/ccc_widgets.dart';
import '../widgets/media.dart';

/// Plays a branch's YouTube live stream inside the app.
class LiveStreamScreen extends StatefulWidget {
  const LiveStreamScreen({
    required this.stream,
    required this.branchName,
    this.event,
    super.key,
  });

  final LiveStream stream;
  final String branchName;

  /// The event being streamed, when there is one.
  final Event? event;

  /// YouTube now refuses to play in apps that don't say who they are; the
  /// app's id, as an https origin, does that.
  static const playerOrigin = 'https://com.ccc.church.ccc_app';

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  late final controller = YoutubePlayerController.fromVideoId(
    videoId: widget.stream.videoId!,
    autoPlay: true,
    params: const YoutubePlayerParams(
      origin: LiveStreamScreen.playerOrigin,
      showFullscreenButton: true,
    ),
  );

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkStatusBar,
      child: Scaffold(
        backgroundColor: CccColors.background,
        body: Column(
          children: [
            const DetailsHeader(title: 'Live'),
            YoutubePlayer(
              controller: controller,
              backgroundColor: Colors.black,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 14 + bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const LiveBadge(width: 44),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.branchName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: CccColors.body,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (event != null)
                      EventInfo(event: event)
                    else
                      Text(
                        widget.stream.title ?? 'Live stream',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: CccColors.navy,
                        ),
                      ),
                    const SizedBox(height: 28),
                    // Live chat, quality settings, or a phone where the
                    // in-app player won't play.
                    CccButton(
                      label: 'Open in YouTube',
                      variant: CccButtonVariant.outlined,
                      iconGap: 12,
                      icon: const Icon(Icons.open_in_new, size: 26),
                      onPressed: () => ExternalActions.website(
                        context,
                        widget.stream.watchUrl,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (buttonContext) => CccButton(
                        label: 'Share',
                        variant: CccButtonVariant.white,
                        iconGap: 12,
                        icon: const Icon(Icons.share, size: 26),
                        onPressed: () => ExternalActions.share(
                          buttonContext,
                          '${event?.title ?? widget.stream.title ?? 'Live now'}'
                          '\n${widget.branchName}\n${widget.stream.watchUrl}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
