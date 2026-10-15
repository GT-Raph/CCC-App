import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/event.dart';
import '../models/live_stream.dart';
import '../services/external_actions.dart';
import '../widgets/cards.dart';
import '../widgets/ccc_widgets.dart';
import '../widgets/details_scaffold.dart';
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
    final shareText =
        '${event?.title ?? widget.stream.title ?? 'Live now'}'
        '\n${widget.branchName}\n${widget.stream.watchUrl}';
    return Scaffold(
      bottomNavigationBar: BottomActionBar(
        children: [
          // Live chat, quality settings, or a phone where the in-app player
          // won't play.
          Expanded(
            child: CccButton(
              label: 'Open in YouTube',
              variant: CccButtonVariant.outlined,
              icon: const Icon(Icons.open_in_new),
              onPressed: () =>
                  ExternalActions.website(context, widget.stream.watchUrl),
            ),
          ),
          const SizedBox(width: 10),
          Builder(
            builder: (buttonContext) => ShareButton(
              onPressed: () => ExternalActions.share(buttonContext, shareText),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const DetailsHeader(title: 'Live'),
          YoutubePlayer(controller: controller, backgroundColor: Colors.black),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const LiveBadge(),
                      const SizedBox(width: 10),
                      Expanded(child: DetailsEyebrow(widget.branchName)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DetailsTitle(
                    event?.title ?? widget.stream.title ?? 'Live stream',
                  ),
                  if (event != null) ...[
                    const SizedBox(height: 20),
                    EventFacts(event: event),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
