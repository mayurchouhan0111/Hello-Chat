import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../core/constants/agora_config.dart';
import 'voice_service.dart';
import '../core/services/base_firebase_service.dart';

class AgoraVoiceService with BaseFirebaseService implements VoiceService {
  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isSpeakerPhone = true;
  bool _isVideoEnabled = false;
  
  final _speakingController = StreamController<bool>.broadcast();
  final _remoteUsersController = StreamController<List<int>>.broadcast();
  final List<int> _remoteUids = [];
  String? _currentRoomId;
  bool _isRetrying = false;

  @override
  bool get isMuted => _isMuted;

  @override
  Stream<bool> get isSpeakingStream => _speakingController.stream;

  Stream<List<int>> get remoteUsersStream => _remoteUsersController.stream;

  Completer<void>? _initCompleter;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    try {
      // Handle permissions
      await [Permission.microphone, Permission.camera].request();

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        audioScenario: AudioScenarioType.audioScenarioChorus,
      ));

      // Set audio profile for professional music/singing quality
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileMusicHighQualityStereo,
      );

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            try {
              debugPrint("✅ Joined Agora channel: ${connection.channelId}");
            } catch (e) {
              debugPrint("⚠️ Error in onJoinChannelSuccess: $e");
            }
            return;
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            try {
              debugPrint("👥 Remote user $remoteUid joined");
              _remoteUids.add(remoteUid);
              _remoteUsersController.add(List.unmodifiable(_remoteUids));
            } catch (e) {
              debugPrint("⚠️ Error in onUserJoined: $e");
            }
            return;
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            try {
              debugPrint("👋 Remote user $remoteUid left. Reason: $reason");
              _remoteUids.remove(remoteUid);
              _remoteUsersController.add(List.unmodifiable(_remoteUids));
            } catch (e) {
              debugPrint("⚠️ Error in onUserOffline: $e");
            }
            return;
          },
          onAudioVolumeIndication: (RtcConnection connection, List<AudioVolumeInfo> speakers, int speakerNumber, int totalVolume) {
            try {
              bool speaking = speakers.any((s) => s.uid == 0 && (s.volume ?? 0) > 15);
              _speakingController.add(speaking);
            } catch (e) {
              debugPrint("⚠️ Error in onAudioVolumeIndication: $e");
            }
            return;
          },
          onError: (ErrorCodeType err, String msg) {
            try {
              if (_engine == null) return;
              debugPrint("🛑 AGORA ERROR: $err, $msg");
              
              if (err == ErrorCodeType.errInvalidToken) {
                debugPrint("❌ CRITICAL: Agora Token was rejected. This usually means the App Certificate in the backend does not match the Agora Console.");
              }
            } catch (e) {
              debugPrint("⚠️ Error in onError callback: $e");
            }
            return;
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            try {
              debugPrint("🚪 Left channel");
              _remoteUids.clear();
              _remoteUsersController.add([]);
              _currentRoomId = null;
              _isRetrying = false;
            } catch (e) {
              debugPrint("⚠️ Error in onLeaveChannel callback: $e");
            }
            return;
          },
        ),
      );

      await _engine!.enableAudioVolumeIndication(interval: 200, smooth: 3, reportVad: true);
      await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
      await _engine!.enableAudio();
      
      try {
        await _engine!.setEnableSpeakerphone(_isSpeakerPhone);
      } catch (e) {
        debugPrint("⚠️ AGORA SPEAKERPHONE ERROR (Non-fatal): $e");
      }
      
      _isInitialized = true;
      _initCompleter?.complete();
    } catch (e) {
      debugPrint("🛑 AGORA INIT ERROR: $e");
      _initCompleter?.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  @override
  Future<void> joinRoom(String roomId, String userId) async {
    if (!_isInitialized) await initialize();
    if (_engine == null) return;

    try {
      await _engine!.leaveChannel();
      
      String? finalToken;

      // UX Improvement: If a manual tempToken is provided in AgoraConfig, use it for testing
      // Only fetch if a source is provided
      if (AgoraConfig.tempToken.isNotEmpty) {
        debugPrint("🧪 Using manual Testing Token from AgoraConfig");
        finalToken = AgoraConfig.tempToken;
      } else if (AgoraConfig.tokenUrl.isNotEmpty) {
        // Logic for Direct HTTP Bypass (onRequest)
        debugPrint("📡 Fetching token from Bypass HTTP URL...");
        final response = await Dio().post(
          AgoraConfig.tokenUrl,
          data: {
             'roomId': roomId,
             'uid': 0,
          },
        );
        
        if (response.data['data'] != null) {
          finalToken = response.data['data']['token'];
        } else {
          finalToken = response.data['rtcToken'] ?? response.data['token'];
        }
        debugPrint("✅ Bypass Token received");
      } else {
        // NO TOKEN SOURCE - Using Empty Token (Unsecured Mode)
        debugPrint("⚠️ NO TOKEN SOURCE: Joining with empty token (Unsecured Mode)...");
        finalToken = "";
      }
      
      _currentRoomId = roomId;
      
      // Ensure we are not already in a channel from a previous failed attempt
      await _engine?.leaveChannel();
      
      await _engine!.joinChannel(
        token: finalToken ?? "",
        channelId: roomId,
        uid: 0,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: false,
          publishCameraTrack: false,
          clientRoleType: ClientRoleType.clientRoleAudience,
        ),
      );
    } catch (e) {
      debugPrint("🛑 AGORA JOIN ERROR: $e");
      rethrow;
    }
  }

  @override
  Future<void> leaveRoom() async {
    if (_engine != null) {
      try {
        await _engine!.leaveChannel();
      } catch (e) {
        debugPrint("⚠️ AGORA LEAVE ERROR: $e");
      }
    }
  }

  @override
  Future<void> muteLocalAudio(bool mute) async {
    if (_engine != null) {
      try {
        await _engine!.muteLocalAudioStream(mute);
        _isMuted = mute;
      } catch (e) {
        debugPrint("⚠️ AGORA MUTE ERROR: $e");
      }
    }
  }

  Future<void> toggleSpeakerphone(bool enable) async {
    if (_engine != null) {
      try {
        await _engine!.setEnableSpeakerphone(enable);
        _isSpeakerPhone = enable;
      } catch (e) {
        debugPrint("⚠️ AGORA SPEAKER TOGGLE ERROR: $e");
      }
    }
  }

  @override
  Future<void> setBroadcasterRole() async {
    if (_engine != null) {
      try {
        await _engine!.updateChannelMediaOptions(ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: !_isMuted,
        ));
      } catch (e) {
        debugPrint("⚠️ AGORA SET BROADCASTER ERROR: $e");
      }
    }
  }

  @override
  Future<void> setAudienceRole() async {
    if (_engine != null) {
      try {
        await _engine!.updateChannelMediaOptions(ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          publishMicrophoneTrack: false,
        ));
      } catch (e) {
        debugPrint("⚠️ AGORA SET AUDIENCE ERROR: $e");
      }
    }
  }

  Future<void> toggleCamera(bool enable) async {
    if (_engine != null) {
      try {
        if (enable) {
          await _engine!.enableVideo();
          await _engine!.startPreview();
        } else {
          await _engine!.stopPreview();
          await _engine!.disableVideo();
        }
        await _engine!.updateChannelMediaOptions(ChannelMediaOptions(publishCameraTrack: enable));
        _isVideoEnabled = enable;
      } catch (e) {
        debugPrint("⚠️ AGORA CAMERA TOGGLE ERROR: $e");
      }
    }
  }

  Future<void> setMicVolume(int volume) async {
    if (_engine != null) {
      await _engine!.adjustRecordingSignalVolume(volume);
    }
  }

  Future<void> enableInEarMonitoring(bool enable) async {
    if (_engine != null) {
      await _engine!.enableInEarMonitoring(
        enabled: enable,
        includeAudioFilters: EarMonitoringFilterType.earMonitoringFilterBuiltInAudioFilters,
      );
    }
  }

  Future<void> setAudioEffectPreset(AudioEffectPreset preset) async {
    if (_engine != null) {
      await _engine!.setAudioEffectPreset(preset);
    }
  }

  Future<void> setVoiceBeautifierPreset(VoiceBeautifierPreset preset) async {
    if (_engine != null) {
      await _engine!.setVoiceBeautifierPreset(preset);
    }
  }

  Future<void> setLocalVoiceEqualization({required AudioEqualizationBandFrequency bandFrequency, required int bandGain}) async {
    if (_engine != null) {
      await _engine!.setLocalVoiceEqualization(
        bandFrequency: bandFrequency,
        bandGain: bandGain,
      );
    }
  }

  Future<void> startAudioMixing(String url) async {
    if (_engine != null) {
      try {
        await _engine!.startAudioMixing(
          filePath: url,
          loopback: false,
          cycle: 1,
        );
      } catch (e) {
        debugPrint("⚠️ AGORA START AUDIO MIXING ERROR: $e");
      }
    }
  }

  Future<void> pauseAudioMixing() async {
    if (_engine != null) {
      await _engine!.pauseAudioMixing();
    }
  }

  Future<void> resumeAudioMixing() async {
    if (_engine != null) {
      await _engine!.resumeAudioMixing();
    }
  }

  Future<void> stopAudioMixing() async {
    if (_engine != null) {
      await _engine!.stopAudioMixing();
    }
  }

  Future<void> adjustAudioMixingVolume(int volume) async {
    if (_engine != null) {
      await _engine!.adjustAudioMixingVolume(volume);
    }
  }

  @override
  void dispose() {
    if (_engine != null) {
      _engine!.release();
      _engine = null;
    }
    _speakingController.close();
    _remoteUsersController.close();
  }
}
