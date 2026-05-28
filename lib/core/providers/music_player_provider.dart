import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/agora_voice_service.dart';
import 'room_provider.dart';

class MusicTrack {
  final String id;
  final String name;
  final String artist;
  final String url;
  
  MusicTrack({required this.id, required this.name, required this.artist, required this.url});
}

class MusicPlayerState {
  final List<MusicTrack> playlist;
  final MusicTrack? currentTrack;
  final bool isPlaying;
  final double volume;

  MusicPlayerState({
    required this.playlist,
    this.currentTrack,
    this.isPlaying = false,
    this.volume = 100.0,
  });

  MusicPlayerState copyWith({
    List<MusicTrack>? playlist,
    MusicTrack? currentTrack,
    bool? isPlaying,
    double? volume,
  }) {
    return MusicPlayerState(
      playlist: playlist ?? this.playlist,
      currentTrack: currentTrack ?? this.currentTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      volume: volume ?? this.volume,
    );
  }
}

class MusicPlayerNotifier extends StateNotifier<MusicPlayerState> {
  final Ref ref;

  MusicPlayerNotifier(this.ref) : super(MusicPlayerState(playlist: []));

  AgoraVoiceService? get _agoraVoiceService {
    final voiceService = ref.read(voiceServiceProvider);
    if (voiceService is AgoraVoiceService) {
      return voiceService;
    }
    return null;
  }

  void addToPlaylist(MusicTrack track) {
    if (!state.playlist.any((t) => t.id == track.id)) {
      state = state.copyWith(playlist: [...state.playlist, track]);
    }
  }

  void removeFromPlaylist(MusicTrack track) {
    final newList = state.playlist.where((t) => t.id != track.id).toList();
    state = state.copyWith(playlist: newList);
    if (state.currentTrack?.id == track.id) {
      stop();
    }
  }

  void playTrack(MusicTrack track) {
    _agoraVoiceService?.startAudioMixing(track.url);
    state = state.copyWith(currentTrack: track, isPlaying: true);
  }

  void pause() {
    if (state.isPlaying) {
      _agoraVoiceService?.pauseAudioMixing();
      state = state.copyWith(isPlaying: false);
    }
  }

  void resume() {
    if (!state.isPlaying && state.currentTrack != null) {
      _agoraVoiceService?.resumeAudioMixing();
      state = state.copyWith(isPlaying: true);
    }
  }

  void stop() {
    _agoraVoiceService?.stopAudioMixing();
    state = state.copyWith(currentTrack: null, isPlaying: false);
  }

  void setVolume(double volume) {
    _agoraVoiceService?.adjustAudioMixingVolume(volume.toInt());
    state = state.copyWith(volume: volume);
  }
  
  void playNext() {
    if (state.playlist.isEmpty) return;
    if (state.currentTrack == null) {
      playTrack(state.playlist.first);
      return;
    }
    final currentIndex = state.playlist.indexWhere((t) => t.id == state.currentTrack!.id);
    if (currentIndex != -1 && currentIndex < state.playlist.length - 1) {
      playTrack(state.playlist[currentIndex + 1]);
    } else {
      // Loop to beginning if at end
      playTrack(state.playlist.first);
    }
  }

  void playPrevious() {
    if (state.playlist.isEmpty) return;
    if (state.currentTrack == null) {
      playTrack(state.playlist.first);
      return;
    }
    final currentIndex = state.playlist.indexWhere((t) => t.id == state.currentTrack!.id);
    if (currentIndex > 0) {
      playTrack(state.playlist[currentIndex - 1]);
    } else {
      // Play last if at beginning
      playTrack(state.playlist.last);
    }
  }
}

final musicPlayerProvider = StateNotifierProvider<MusicPlayerNotifier, MusicPlayerState>((ref) {
  return MusicPlayerNotifier(ref);
});
