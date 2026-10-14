import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/sermon.dart';

/// The sermon that is playing, shared by the mini player, the player sheet
/// and the sermon list.
abstract class SermonPlayer extends ChangeNotifier {
  Sermon? get sermon;

  /// Branch the [sermon] belongs to, shown under its title.
  String get branchName;

  bool get playing;

  /// Loading or waiting for the network.
  bool get buffering;

  /// The last playback problem, cleared when something plays again.
  String? get error;

  /// The audio's real length once loaded, else the length from the upload.
  Duration get duration;

  /// Updates several times a second; listen to it only where the time shows.
  ValueListenable<Duration> get position;

  double get speed;

  static const speeds = [1.0, 1.25, 1.5, 2.0, 0.75];

  /// Plays [sermon] from the start, or resumes it if it is already loaded.
  Future<void> play(Sermon sermon, {required String branchName});

  Future<void> pause();

  Future<void> toggle() =>
      playing ? pause() : play(sermon!, branchName: branchName);

  Future<void> seek(Duration to);

  Future<void> skip(Duration by) {
    final target = position.value + by;
    final end = duration;
    return seek(
      target < Duration.zero
          ? Duration.zero
          : (end > Duration.zero && target > end ? end : target),
    );
  }

  Future<void> setSpeed(double speed);

  /// Stops playback and hides the mini player.
  Future<void> close();
}

/// [SermonPlayer] on just_audio, with lock-screen and notification controls
/// from just_audio_background (set up in `main`).
class JustAudioSermonPlayer extends SermonPlayer {
  AudioPlayer? _audio;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  Sermon? _sermon;

  /// The sermon whose audio is in the player; null after a failed load, so
  /// pressing play again retries it.
  String? _loadedId;
  String _branchName = '';
  bool _playing = false;
  bool _buffering = false;
  bool _completed = false;
  String? _error;
  Duration? _loadedDuration;
  double _speed = 1;
  final _position = ValueNotifier(Duration.zero);

  @override
  Sermon? get sermon => _sermon;
  @override
  String get branchName => _branchName;
  @override
  bool get playing => _playing;
  @override
  bool get buffering => _buffering;
  @override
  String? get error => _error;
  @override
  Duration get duration =>
      _loadedDuration ?? _sermon?.duration ?? Duration.zero;
  @override
  ValueListenable<Duration> get position => _position;
  @override
  double get speed => _speed;

  /// Created on first use, so screens and tests that never play a sermon
  /// don't start the audio plugin.
  AudioPlayer get _player => _audio ??= _create();

  AudioPlayer _create() {
    final player = AudioPlayer();
    _subscriptions
      ..add(
        player.playerStateStream.listen((state) {
          final processing = state.processingState;
          _playing = state.playing && processing != ProcessingState.completed;
          _buffering =
              processing == ProcessingState.loading ||
              processing == ProcessingState.buffering;
          _completed = processing == ProcessingState.completed;
          notifyListeners();
        }),
      )
      ..add(player.positionStream.listen((value) => _position.value = value))
      ..add(
        player.durationStream.listen((value) {
          _loadedDuration = value;
          notifyListeners();
        }),
      )
      ..add(
        player.playbackEventStream.listen(
          (_) {},
          onError: (Object _, StackTrace _) => _fail(),
        ),
      );
    return player;
  }

  @override
  Future<void> play(Sermon sermon, {required String branchName}) async {
    final player = _player;
    _error = null;
    if (_loadedId != sermon.id) {
      _sermon = sermon;
      _loadedId = sermon.id;
      _branchName = branchName;
      _loadedDuration = null;
      _position.value = Duration.zero;
      _buffering = true;
      notifyListeners();
      try {
        await player.setAudioSource(
          AudioSource.uri(
            Uri.parse(sermon.audioUrl),
            tag: MediaItem(
              id: sermon.id,
              title: sermon.title,
              artist: sermon.preacher.isEmpty ? null : sermon.preacher,
              album: branchName,
              duration: sermon.duration,
            ),
          ),
        );
      } on PlayerInterruptedException {
        return; // Another sermon was chosen while this one loaded.
      } catch (_) {
        _fail();
        return;
      }
    } else if (_completed) {
      await player.seek(Duration.zero);
    }
    // Completes only when playback pauses or ends, so don't wait for it.
    unawaited(player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration to) => _player.seek(to);

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    notifyListeners();
    await _player.setSpeed(speed);
  }

  @override
  Future<void> close() async {
    _sermon = null;
    _loadedId = null;
    _playing = false;
    _buffering = false;
    _error = null;
    _position.value = Duration.zero;
    notifyListeners();
    await _audio?.stop();
  }

  void _fail() {
    _loadedId = null;
    _error = "This sermon couldn't play. Check your connection and try again.";
    _playing = false;
    _buffering = false;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _audio?.dispose();
    _position.dispose();
    super.dispose();
  }
}
