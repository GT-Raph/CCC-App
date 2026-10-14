import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'services/auth_service.dart';
import 'widgets/ccc_widgets.dart';

export 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(darkStatusBar);
  await _startBackgroundAudio();
  await dotenv.load(fileName: '.env');
  AuthService.socialProviders = AuthService.parseProviders(
    dotenv.maybeGet('SOCIAL_SIGN_IN'),
  );
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
  );
  runApp(
    CccApp(
      initialMember: AuthService.currentMember,
      googleMapsApiKey: dotenv.maybeGet('GOOGLE_MAPS_API_KEY'),
    ),
  );
}

/// Lets sermons keep playing with the screen off, with lock-screen controls
/// that match the player's skip buttons. If that can't start (for example a
/// hot restart after the native plugins changed, which needs a full rebuild),
/// the app still opens and sermons play while it is in the foreground.
Future<void> _startBackgroundAudio() async {
  // JustAudioBackground swaps in its own player before starting the audio
  // service, and leaves it in place if the service fails.
  final standardPlayer = JustAudioPlatform.instance;
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.ccc.church.ccc_app.sermons',
      androidNotificationChannelName: 'Sermon playback',
      androidNotificationOngoing: true,
      rewindInterval: const Duration(seconds: 10),
      fastForwardInterval: const Duration(seconds: 30),
    );
  } catch (error) {
    JustAudioPlatform.instance = standardPlayer;
    debugPrint('Background sermon playback is off: $error');
  }
}
