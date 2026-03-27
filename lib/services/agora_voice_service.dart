import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants/agora_config.dart';
import 'voice_service.dart';

class AgoraVoiceService implements VoiceService {
  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isMuted = false;
  final _speakingController = StreamController<bool>.broadcast();

  @override
  bool get isMuted => _isMuted;

  @override
  Stream<bool> get isSpeakingStream => _speakingController.stream;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Handle permissions
    await [Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(const RtcEngineContext(
      appId: AgoraConfig.appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print("Joined channel: ${connection.channelId}");
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print("Remote user $remoteUid joined");
        },
        onAudioVolumeIndication: (RtcConnection connection, List<AudioVolumeInfo> speakers, int speakerNumber, int totalVolume) {
          // Detect if local user is speaking
          bool speaking = speakers.any((s) => s.uid == 0 && (s.volume ?? 0) > 10);
          _speakingController.add(speaking);
        },
      ),
    );

    await _engine!.enableAudioVolumeIndication(interval: 250, smooth: 3, reportVad: true);
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine!.enableAudio();
    
    _isInitialized = true;
  }

  @override
  Future<void> joinRoom(String roomId, String userId) async {
    if (!_isInitialized) await initialize();
    
    await _engine!.joinChannel(
      token: AgoraConfig.tempToken,
      channelId: roomId,
      uid: 0, // Using 0 for automatic UID
      options: const ChannelMediaOptions(
        autoSubscribeAudio: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  @override
  Future<void> leaveRoom() async {
    if (_engine != null) {
      await _engine!.leaveChannel();
    }
  }

  @override
  Future<void> muteLocalAudio(bool mute) async {
    if (_engine != null) {
      await _engine!.muteLocalAudioStream(mute);
      _isMuted = mute;
    }
  }

  @override
  void dispose() {
    if (_engine != null) {
      _engine!.release();
      _engine = null;
    }
    _speakingController.close();
  }
}
