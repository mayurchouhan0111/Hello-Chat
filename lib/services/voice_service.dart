abstract class VoiceService {
  Future<void> initialize();
  Future<void> joinRoom(String roomId, String userId);
  Future<void> leaveRoom();
  Future<void> muteLocalAudio(bool mute);
  Future<void> toggleSpeakerphone(bool enable);
  Future<void> setBroadcasterRole();
  Future<void> setAudienceRole();
  Future<void> onAppPaused();
  Future<void> onAppResumed();
  Stream<bool> get isSpeakingStream;
  Stream<List<int>> get speakingUidsStream;
  bool get isMuted;
  void dispose();
}
