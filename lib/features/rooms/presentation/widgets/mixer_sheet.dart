import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../services/agora_voice_service.dart';

final mixerMicVolumeProvider = StateProvider<double>((ref) => 100.0);
final mixerPreviewProvider = StateProvider<bool>((ref) => false);
final mixerIntelligentEffectsProvider = StateProvider<bool>((ref) => true);
final mixerMusicEffectProvider = StateProvider<String>((ref) => 'Original');
final mixerEqualizerProvider = StateProvider<String>((ref) => 'None');

class MixerSheet extends ConsumerStatefulWidget {
  const MixerSheet({super.key});

  @override
  ConsumerState<MixerSheet> createState() => _MixerSheetState();
}

class _MixerSheetState extends ConsumerState<MixerSheet> {
  AgoraVoiceService? _getAgoraVoiceService() {
    final voiceService = ref.read(voiceServiceProvider);
    if (voiceService is AgoraVoiceService) {
      return voiceService;
    }
    return null;
  }

  void _onVolumeChanged(double value) {
    ref.read(mixerMicVolumeProvider.notifier).state = value;
    _getAgoraVoiceService()?.setMicVolume(value.toInt());
  }

  void _onPreviewToggled(bool value) {
    ref.read(mixerPreviewProvider.notifier).state = value;
    _getAgoraVoiceService()?.enableInEarMonitoring(value);
  }

  void _onIntelligentEffectsToggled(bool value) {
    ref.read(mixerIntelligentEffectsProvider.notifier).state = value;
    final preset = value ? VoiceBeautifierPreset.singingBeautifier : VoiceBeautifierPreset.voiceBeautifierOff;
    _getAgoraVoiceService()?.setVoiceBeautifierPreset(preset);
  }

  void _onMusicEffectSelected(String effect) {
    ref.read(mixerMusicEffectProvider.notifier).state = effect;
    
    AudioEffectPreset preset = AudioEffectPreset.audioEffectOff;
    switch (effect) {
      case 'Reverb':
        preset = AudioEffectPreset.roomAcousticsSpacial;
        break;
      case 'Studio':
        preset = AudioEffectPreset.roomAcousticsStudio;
        break;
      case 'Live Concert':
        preset = AudioEffectPreset.roomAcousticsVocalConcert;
        break;
      case 'KTV':
        preset = AudioEffectPreset.roomAcousticsKtv;
        break;
      case 'Original':
      default:
        preset = AudioEffectPreset.audioEffectOff;
        break;
    }
    
    _getAgoraVoiceService()?.setAudioEffectPreset(preset);
  }

  void _onEqualizerSelected(String eq) {
    ref.read(mixerEqualizerProvider.notifier).state = eq;
    
    // 10-band EQ: 31, 62, 125, 250, 500, 1k, 2k, 4k, 8k, 16k
    List<int> gains = List.filled(10, 0);

    switch (eq) {
      case 'Custom':
        // Mild V-shape for clear vocals
        gains = [3, 2, 1, -1, -2, -1, 1, 2, 3, 4];
        break;
      case 'Electronic':
        // Heavy bass and treble, scooped mids
        gains = [6, 5, 0, -2, -4, 0, 2, 4, 5, 6];
        break;
      case 'Rock':
        // Boosted lows and highs, slightly recessed mids
        gains = [5, 4, 3, 1, -1, -2, 1, 3, 4, 5];
        break;
      case 'None':
      default:
        gains = List.filled(10, 0);
        break;
    }
    
    final voiceService = _getAgoraVoiceService();
    if (voiceService != null) {
      final bands = [
        AudioEqualizationBandFrequency.audioEqualizationBand31,
        AudioEqualizationBandFrequency.audioEqualizationBand62,
        AudioEqualizationBandFrequency.audioEqualizationBand125,
        AudioEqualizationBandFrequency.audioEqualizationBand250,
        AudioEqualizationBandFrequency.audioEqualizationBand500,
        AudioEqualizationBandFrequency.audioEqualizationBand1k,
        AudioEqualizationBandFrequency.audioEqualizationBand2k,
        AudioEqualizationBandFrequency.audioEqualizationBand4k,
        AudioEqualizationBandFrequency.audioEqualizationBand8k,
        AudioEqualizationBandFrequency.audioEqualizationBand16k,
      ];
      
      for (int i = 0; i < 10; i++) {
        voiceService.setLocalVoiceEqualization(bandFrequency: bands[i], bandGain: gains[i]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final micVolume = ref.watch(mixerMicVolumeProvider);
    final previewEnabled = ref.watch(mixerPreviewProvider);
    final intelligentEffectsEnabled = ref.watch(mixerIntelligentEffectsProvider);
    final selectedMusicEffect = ref.watch(mixerMusicEffectProvider);
    final selectedEqualizer = ref.watch(mixerEqualizerProvider);

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Mixer",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded, color: Colors.black54),
                ),
              ],
            ),
          ),
          const Gap(24),
          
          // Mic Volume Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Mic Volume", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                GestureDetector(
                  onTap: () => _onVolumeChanged(100.0),
                  child: const Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 16, color: Colors.black38),
                      Gap(4),
                      Text("Volume Reset", style: TextStyle(fontSize: 14, color: Colors.black38, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Slider(
                    value: micVolume,
                    min: 0,
                    max: 100,
                    activeColor: const Color(0xFF00E5FF),
                    inactiveColor: Colors.grey.shade200,
                    onChanged: _onVolumeChanged,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Text(
                    "${micVolume.toInt()}",
                    style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),

          // Preview Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Preview", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                    Gap(4),
                    Text("Preview the tuned sound effect.", style: TextStyle(fontSize: 13, color: Colors.black45)),
                  ],
                ),
                Switch(
                  value: previewEnabled,
                  onChanged: _onPreviewToggled,
                  activeColor: const Color(0xFF00E5FF),
                ),
              ],
            ),
          ),
          const Gap(24),

          // Intelligent Audio Effects Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Intelligent Audio Effects", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                    Gap(4),
                    Text("Sound Enhancement", style: TextStyle(fontSize: 13, color: Colors.black45)),
                  ],
                ),
                Switch(
                  value: intelligentEffectsEnabled,
                  onChanged: _onIntelligentEffectsToggled,
                  activeColor: const Color(0xFF00E5FF),
                ),
              ],
            ),
          ),
          const Gap(24),

          // Music Effects
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text("Music Effects", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
          const Gap(16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildPresetItem('Original', selectedMusicEffect == 'Original', true, () => _onMusicEffectSelected('Original')),
                _buildPresetItem('Studio', selectedMusicEffect == 'Studio', false, () => _onMusicEffectSelected('Studio'), imageUrl: 'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?w=150'),
                _buildPresetItem('Reverb', selectedMusicEffect == 'Reverb', false, () => _onMusicEffectSelected('Reverb'), imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150'),
                _buildPresetItem('Live Concert', selectedMusicEffect == 'Live Concert', false, () => _onMusicEffectSelected('Live Concert'), imageUrl: 'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?w=150'),
                _buildPresetItem('KTV', selectedMusicEffect == 'KTV', false, () => _onMusicEffectSelected('KTV'), imageUrl: 'https://images.unsplash.com/photo-1516585427167-9f4af9627e6c?w=150'),
              ],
            ),
          ),
          const Gap(24),

          // Equalizer
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text("Equalizer", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
          const Gap(16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildPresetItem('None', selectedEqualizer == 'None', true, () => _onEqualizerSelected('None')),
                _buildPresetItem('Custom', selectedEqualizer == 'Custom', false, () => _onEqualizerSelected('Custom'), imageUrl: 'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?w=150'),
                _buildPresetItem('Electronic', selectedEqualizer == 'Electronic', false, () => _onEqualizerSelected('Electronic'), imageUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=150'),
                _buildPresetItem('Rock', selectedEqualizer == 'Rock', false, () => _onEqualizerSelected('Rock'), imageUrl: 'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=150'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetItem(String label, bool isSelected, bool isNone, VoidCallback onTap, {String? imageUrl}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent,
                  width: 2,
                ),
                image: !isNone && imageUrl != null ? DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ) : null,
                color: isNone ? Colors.white : Colors.grey.shade200,
              ),
              child: isNone 
                ? Icon(Icons.do_not_disturb_alt_rounded, color: Colors.grey.shade300, size: 30)
                : null,
            ),
            const Gap(8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.black87 : Colors.black54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
