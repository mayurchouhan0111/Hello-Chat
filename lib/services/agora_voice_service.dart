import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
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
  final _speakingUidsController = StreamController<List<int>>.broadcast();
  final _remoteUsersController = StreamController<List<int>>.broadcast();
  final List<int> _remoteUids = [];
  String? _currentRoomId;
  String? _currentUserId;
  bool _isRetrying = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  ClientRoleType _currentRole = ClientRoleType.clientRoleAudience;

  Timer? _healthTimer;
  DateTime? _lastAudioTimestamp;
  DateTime? _lastHealthCheck;
  bool _isInChannel = false;

  static const Duration _healthCheckInterval = Duration(seconds: 10);
  static const Duration _audioStaleThreshold = Duration(seconds: 20);

  int getAgoraUid(String uid) {
    if (uid.isEmpty) return 0;
    return uid.hashCode & 0xFFFFFFFF;
  }

  @override
  bool get isMuted => _isMuted;

  @override
  Stream<bool> get isSpeakingStream => _speakingController.stream;

  @override
  Stream<List<int>> get speakingUidsStream => _speakingUidsController.stream;

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
        audioScenario: AudioScenarioType.audioScenarioGameStreaming,
      ));

      // Force default audio route to speakerphone
      await _engine!.setDefaultAudioRouteToSpeakerphone(true);

      // Set audio profile for professional music/singing quality
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileMusicHighQualityStereo,
      );

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            try {
              debugPrint("✅ Joined Agora channel: ${connection.channelId}");
              _isInChannel = true;
              _reconnectAttempts = 0;
              _lastAudioTimestamp = DateTime.now();
              _startHealthTimer();
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
              _lastAudioTimestamp = DateTime.now();
              if (_reconnectAttempts > 0) {
                _reconnectAttempts = 0;
                debugPrint("✅ Audio flowing again — reset reconnect attempts");
              }
              final localAgoraUid = getAgoraUid(_currentUserId ?? '');
              final List<int> speakingUids = [];
              for (final speaker in speakers) {
                if ((speaker.volume ?? 0) > 15) {
                  if (speaker.uid == 0 || speaker.uid == localAgoraUid) {
                    speakingUids.add(localAgoraUid);
                  } else if (speaker.uid != null) {
                    speakingUids.add(speaker.uid!);
                  }
                }
              }
              _speakingUidsController.add(speakingUids);
              _speakingController.add(speakingUids.contains(localAgoraUid));
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
              _isInChannel = false;
              _stopHealthTimer();
              _lastAudioTimestamp = null;
            } catch (e) {
              debugPrint("⚠️ Error in onLeaveChannel callback: $e");
            }
            return;
          },
          onAudioRoutingChanged: (int routing) {
            try {
              debugPrint("🔊 Agora Audio Routing changed: $routing");
            } catch (e) {
              debugPrint("⚠️ Error in onAudioRoutingChanged: $e");
            }
            return;
          },
          onClientRoleChanged: (RtcConnection connection, ClientRoleType oldRole, ClientRoleType newRole, ClientRoleOptions newRoleOptions) {
            try {
              debugPrint("👥 Agora Client Role changed from $oldRole to $newRole");
              _engine?.setEnableSpeakerphone(true);
            } catch (e) {
              debugPrint("⚠️ Error in onClientRoleChanged: $e");
            }
            return;
          },
          onClientRoleChangeFailed: (RtcConnection connection, ClientRoleChangeFailedReason reason, ClientRoleType role) {
            try {
              debugPrint("❌ Agora Client Role change failed to $role. Reason: $reason");
            } catch (e) {
              debugPrint("⚠️ Error in onClientRoleChangeFailed: $e");
            }
            return;
          },
          onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
            try {
              debugPrint("🔌 Agora Connection State Changed: state=$state, reason=$reason");
              if (state == ConnectionStateType.connectionStateConnected) {
                _reconnectAttempts = 0;
                _lastAudioTimestamp = DateTime.now();
                _isInChannel = true;
                _startHealthTimer();
                debugPrint("✅ Agora reconnection successful");
              } else if (state == ConnectionStateType.connectionStateFailed) {
                debugPrint("⚠️ Agora connection failed - attempting reconnect...");
                _attemptReconnect();
              } else if (state == ConnectionStateType.connectionStateDisconnected) {
                debugPrint("👋 Agora disconnected");
                _isInChannel = false;
                _stopHealthTimer();
              }
            } catch (e) {
              debugPrint("⚠️ Error in onConnectionStateChanged: $e");
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
    _currentUserId = userId;
    final bool wasJustInitialized = !_isInitialized;
    if (!_isInitialized) await initialize();
    if (_engine == null) return;

    if (wasJustInitialized) {
      // Give native Agora thread a short delay to settle its scenario settings
      await Future.delayed(const Duration(milliseconds: 250));
    }

    // Clean up any previous health/reconnect state before switching rooms
    final isSwitchingRoom = _isInChannel && _currentRoomId != null && _currentRoomId != roomId;
    _stopHealthTimer();
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _isRetrying = false;

    try {
      // Leave previous channel if switching rooms
      if (isSwitchingRoom) {
        debugPrint("🔄 Switching from room $_currentRoomId to $roomId");
        await _engine!.leaveChannel();
        _remoteUids.clear();
        _remoteUsersController.add([]);
      }

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
      _currentRole = ClientRoleType.clientRoleAudience;
      
      // Ensure we are not already in a channel from a previous failed attempt
      await _engine!.joinChannel(
        token: finalToken ?? "",
        channelId: roomId,
        uid: getAgoraUid(userId),
        options: ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: false,
          publishCameraTrack: false,
          clientRoleType: ClientRoleType.clientRoleAudience,
        ),
      );
      
      // Force speakerphone routing on channel entry
      await _engine!.setDefaultAudioRouteToSpeakerphone(true);
      await _engine!.setEnableSpeakerphone(true);
    } catch (e) {
      debugPrint("🛑 AGORA JOIN ERROR: $e");
      rethrow;
    }
  }

  void _startHealthTimer() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(_healthCheckInterval, (_) {
      if (!_isInChannel || _currentRoomId == null) {
        _stopHealthTimer();
        return;
      }
      if (_lastAudioTimestamp == null) return;
      final elapsed = DateTime.now().difference(_lastAudioTimestamp!);
      if (elapsed > _audioStaleThreshold) {
        debugPrint("⚠️ No audio for ${elapsed.inSeconds}s — triggering health reconnect...");
        _attemptReconnect();
      }
    });
  }

  void _stopHealthTimer() {
    _healthTimer?.cancel();
    _healthTimer = null;
  }

  void _attemptReconnect() {
    if (_isRetrying) return;
    if (_reconnectAttempts >= 3) {
      debugPrint("❌ Agora max reconnection attempts reached");
      _isRetrying = false;
      return;
    }

    _isRetrying = true;
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);

    debugPrint("🔄 Agora reconnection attempt $_reconnectAttempts/3 in ${delay.inSeconds}s...");

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (_engine == null || _currentRoomId == null || _currentUserId == null) {
        _isRetrying = false;
        return;
      }

      try {
        await _engine!.leaveChannel();
        await _engine!.joinChannel(
          token: "",
          channelId: _currentRoomId!,
          uid: getAgoraUid(_currentUserId!),
          options: ChannelMediaOptions(
            autoSubscribeAudio: true,
            publishMicrophoneTrack: _currentRole == ClientRoleType.clientRoleBroadcaster && !_isMuted,
            publishCameraTrack: false,
            clientRoleType: _currentRole,
          ),
        );
        debugPrint("✅ Agora reconnected to channel $_currentRoomId");
        _isRetrying = false;
      } catch (e) {
        debugPrint("⚠️ Agora reconnect attempt $_reconnectAttempts failed: $e");
        _isRetrying = false;
        _attemptReconnect();
      }
    });
  }

  @override
  Future<void> leaveRoom() async {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _isRetrying = false;
    _isInChannel = false;
    _stopHealthTimer();
    _lastAudioTimestamp = null;
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
        _currentRole = ClientRoleType.clientRoleBroadcaster;
        await _engine!.updateChannelMediaOptions(ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: !_isMuted,
          autoSubscribeAudio: true,
        ));
        await _engine!.setEnableSpeakerphone(true);
      } catch (e) {
        debugPrint("⚠️ AGORA SET BROADCASTER ERROR: $e");
      }
    }
  }

  @override
  Future<void> setAudienceRole() async {
    if (_engine != null) {
      try {
        _currentRole = ClientRoleType.clientRoleAudience;
        await _engine!.updateChannelMediaOptions(ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          publishMicrophoneTrack: false,
          autoSubscribeAudio: true,
        ));
        await _engine!.setEnableSpeakerphone(true);
      } catch (e) {
        debugPrint("⚠️ AGORA SET AUDIENCE ERROR: $e");
      }
    }
  }

  @override
  Future<void> onAppPaused() async {
    debugPrint("📱 App paused — muting mic, keeping channel alive");
    if (_isInChannel && _engine != null) {
      try {
        await _engine!.muteLocalAudioStream(true);
      } catch (e) {
        debugPrint("⚠️ Error muting audio on pause: $e");
      }
    }
  }

  @override
  Future<void> onAppResumed() async {
    debugPrint("📱 App resumed — checking connection health");
    if (!_isInChannel && _currentRoomId != null && _currentUserId != null) {
      debugPrint("🔄 Was disconnected — rejoining channel...");
      try {
        await _engine!.leaveChannel();
        await _engine!.joinChannel(
          token: "",
          channelId: _currentRoomId!,
          uid: getAgoraUid(_currentUserId!),
          options: ChannelMediaOptions(
            autoSubscribeAudio: true,
            publishMicrophoneTrack: _currentRole == ClientRoleType.clientRoleBroadcaster && !_isMuted,
            publishCameraTrack: false,
            clientRoleType: _currentRole,
          ),
        );
        _isInChannel = true;
        _lastAudioTimestamp = DateTime.now();
        _startHealthTimer();
        debugPrint("✅ Rejoined channel after resume");
      } catch (e) {
        debugPrint("⚠️ Error rejoining channel on resume: $e");
      }
    } else if (_isInChannel && _engine != null) {
      try {
        await _engine!.muteLocalAudioStream(_isMuted);
        await _engine!.setEnableSpeakerphone(true);
      } catch (e) {
        debugPrint("⚠️ Error restoring audio on resume: $e");
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
    _reconnectTimer?.cancel();
    _stopHealthTimer();
    if (_engine != null) {
      _engine!.release();
      _engine = null;
    }
    _speakingController.close();
    _speakingUidsController.close();
    _remoteUsersController.close();
  }
}
