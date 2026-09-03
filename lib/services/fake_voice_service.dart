import 'dart:async';
import 'dart:math';
import 'voice_service.dart';

class FakeVoiceService implements VoiceService {
  final _speakingController = StreamController<bool>.broadcast();
  Timer? _simulationTimer;
  bool _isMuted = false;
  final _random = Random();

  @override
  bool get isMuted => _isMuted;

  @override
  bool get isBroadcaster => !_isMuted;

  @override
  Stream<bool> get isSpeakingStream => _speakingController.stream;

  @override
  Stream<List<int>> get speakingUidsStream => const Stream.empty();

  @override
  Future<void> initialize() async {
    print("Fake voice initialized");
  }

  @override
  Future<void> joinRoom(String roomId, String userId) async {
    print("Simulating joining channel for room: $roomId for user: $userId");
    _startSpeakingSimulation();
  }

  @override
  Future<void> leaveRoom() async {
    print("Simulating leaving channel");
    _stopSpeakingSimulation();
  }

  @override
  Future<void> muteLocalAudio(bool mute) async {
    _isMuted = mute;
    print("Fake voice muted: $_isMuted");
    if (_isMuted) {
      _stopSpeakingSimulation();
      _speakingController.add(false);
    } else {
      _startSpeakingSimulation();
    }
  }

  @override
  Future<void> muteRoomAudio(bool mute) async {
    print("Fake voice room mute toggled: $mute");
  }

  @override
  Future<void> setBroadcasterRole() async {
    print("Fake voice: set broadcaster role");
  }

  @override
  Future<void> setAudienceRole() async {
    print("Fake voice: set audience role");
  }

  @override
  Future<void> toggleSpeakerphone(bool enable) async {
    print("Fake voice speakerphone toggled: $enable");
  }

  @override
  Future<void> onAppPaused() async {
    print("Fake voice: app paused");
  }

  @override
  Future<void> onAppResumed() async {
    print("Fake voice: app resumed");
  }

  void _startSpeakingSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(Duration(seconds: _random.nextInt(3) + 2), (timer) {
      if (!_isMuted) {
        _speakingController.add(_random.nextBool());
      }
    });
  }

  void _stopSpeakingSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  @override
  void dispose() {
    _stopSpeakingSimulation();
    _speakingController.close();
  }
}
