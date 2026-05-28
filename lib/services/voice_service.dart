abstract class VoiceService {
  Future<void> initialize();
  Future<void> joinRoom(String roomId, String userId);
  Future<void> leaveRoom();
  Future<void> muteLocalAudio(bool mute);
  Future<void> toggleSpeakerphone(bool enable);
  Future<void> setBroadcasterRole();
  Future<void> setAudienceRole();
  Stream<bool> get isSpeakingStream;
  bool get isMuted;
  void dispose();
}
