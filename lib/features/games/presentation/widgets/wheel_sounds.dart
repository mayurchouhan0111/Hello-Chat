import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Coalesce rapid segment changes while the platform player is busy. A queued
/// tick must never play after a reveal, a background transition, or disposal.
class WheelSounds {
  WheelSounds() : this.withPlayers(AudioPlayer(), AudioPlayer());

  @visibleForTesting
  WheelSounds.withPlayers(this._tick, this._chime);

  final AudioPlayer _tick;
  final AudioPlayer _chime;
  int _revision = 0;
  String? _revealedRound;
  bool _disposed = false;
  static bool globalSoundEnabled = true;
  bool get isEnabled => globalSoundEnabled;
  Future<void> _pending = Future.value();

  void setEnabled(bool enabled) {
    globalSoundEnabled = enabled;
    if (!enabled) silence();
  }

  void prepare() {
    _pending = Future.wait([
      _load(_tick, 'games/wheel_tick.wav'),
      _load(_chime, 'games/wheel_result.wav'),
    ]).then<void>((_) {}).catchError(_log);
  }

  Future<void> _load(AudioPlayer player, String path) async {
    await player.setAudioContext(const AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: false,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
        options: [AVAudioSessionOptions.mixWithOthers],
      ),
    ));
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setSourceAsset(path);
  }

  void tick() {
    if (!isEnabled) return;
    _play(_tick);
  }

  void reveal(String round) {
    if (!isEnabled) return;
    if (round == _revealedRound) return;
    _revealedRound = round;
    _play(_chime);
  }

  void _play(AudioPlayer player) {
    final revision = ++_revision;
    _pending = _pending.then<void>((_) async {
      if (_disposed || revision != _revision) return;
      if (player == _chime) await _tick.stop();
      await player.stop();
      if (!_disposed && revision == _revision) await player.resume();
    }).catchError(_log);
  }

  void silence() {
    ++_revision;
    _pending = _pending.then<void>((_) async {
      await Future.wait([_tick.stop(), _chime.stop()]);
    }).catchError(_log);
  }

  void dispose() {
    _disposed = true;
    _pending = _pending.then<void>((_) async {
      await Future.wait([_tick.dispose(), _chime.dispose()]);
    }).catchError(_log);
  }

  static void _log(Object error) => debugPrint('Wheel audio: $error');
}
