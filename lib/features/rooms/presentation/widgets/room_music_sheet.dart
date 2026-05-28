import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../../../../core/models/room_model.dart';
import '../../../../core/providers/music_player_provider.dart';

class RoomMusicSheet extends ConsumerStatefulWidget {
  final RoomModel room;
  final bool isAdmin;

  const RoomMusicSheet({super.key, required this.room, required this.isAdmin});

  @override
  ConsumerState<RoomMusicSheet> createState() => _RoomMusicSheetState();
}

class _RoomMusicSheetState extends ConsumerState<RoomMusicSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<MusicTrack> _localFiles = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _scanToAdd() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          for (var file in result.files) {
            if (file.path != null) {
              final newTrack = MusicTrack(
                id: const Uuid().v4(),
                name: file.name,
                artist: 'Local file',
                url: file.path!,
              );
              // avoid duplicates by path
              if (!_localFiles.any((t) => t.url == file.path)) {
                _localFiles.add(newTrack);
              }
            }
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Added ${result.files.length} audio files.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking files: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(musicPlayerProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const Gap(12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
          const Gap(8),
          const Text("Room music", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Gap(16),
          
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF00E5FF),
              labelColor: const Color(0xFF00E5FF),
              unselectedLabelColor: Colors.black54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              dividerColor: Colors.transparent, // Removes the black line
              tabs: const [
                Tab(text: "Playlist"),
                Tab(text: "Local music"),
              ],
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPlaylistTab(playerState),
                _buildLocalMusicTab(),
              ],
            ),
          ),
          
          if (playerState.playlist.isNotEmpty || playerState.currentTrack != null)
            _buildPersistentPlayer(playerState),
        ],
      ),
    );
  }

  Widget _buildPlaylistTab(MusicPlayerState playerState) {
    if (playerState.playlist.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade300),
            const Gap(16),
            const Text("No Music", style: TextStyle(color: Colors.black45, fontSize: 16, fontWeight: FontWeight.bold)),
            const Gap(24),
            if (widget.isAdmin)
              GestureDetector(
                onTap: () => _tabController.animateTo(1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF00B8D4)]),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: const Text("Add songs now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      itemCount: playerState.playlist.length,
      itemBuilder: (context, index) {
        final track = playerState.playlist[index];
        final isPlaying = playerState.currentTrack?.id == track.id;
        
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: isPlaying ? const Color(0xFF00E5FF).withOpacity(0.1) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
              color: isPlaying ? const Color(0xFF00E5FF) : Colors.black38,
            ),
          ),
          title: Text(track.name, style: TextStyle(fontWeight: isPlaying ? FontWeight.bold : FontWeight.w600, color: isPlaying ? const Color(0xFF00E5FF) : Colors.black87)),
          subtitle: Text(track.artist, style: const TextStyle(fontSize: 12, color: Colors.black45)),
          trailing: widget.isAdmin 
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.black54),
                      onPressed: () => ref.read(musicPlayerProvider.notifier).playTrack(track),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.black38),
                      onPressed: () => ref.read(musicPlayerProvider.notifier).removeFromPlaylist(track),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }

  Widget _buildLocalMusicTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: "Search music or sing",
                    hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.black38),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const Gap(16),
              if (widget.isAdmin)
                GestureDetector(
                  onTap: _scanToAdd,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFF00E5FF)),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: const Text("Scan to add", style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
            ],
          ),
        ),
        
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
            itemCount: _localFiles.length,
            itemBuilder: (context, index) {
              final track = _localFiles[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.audio_file_rounded, color: Colors.black26, size: 36),
                title: Text(track.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text("Artist: ${track.artist}", style: const TextStyle(color: Colors.black45, fontSize: 12)),
                trailing: widget.isAdmin
                    ? GestureDetector(
                        onTap: () {
                          ref.read(musicPlayerProvider.notifier).addToPlaylist(track);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added ${track.name} to playlist.")));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.black87, size: 20),
                        ),
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPersistentPlayer(MusicPlayerState playerState) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF00B8D4)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.music_note_rounded, color: Colors.white),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playerState.currentTrack?.name ?? "No song playing",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text("1.0x", style: TextStyle(color: Colors.black45, fontSize: 12)),
                  ],
                ),
              ),
              if (widget.isAdmin) ...[
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded),
                  onPressed: () => ref.read(musicPlayerProvider.notifier).playPrevious(),
                ),
                GestureDetector(
                  onTap: () {
                    final notifier = ref.read(musicPlayerProvider.notifier);
                    if (playerState.isPlaying) {
                      notifier.pause();
                    } else if (playerState.currentTrack != null) {
                      notifier.resume();
                    } else if (playerState.playlist.isNotEmpty) {
                      notifier.playTrack(playerState.playlist.first);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFF00E5FF), shape: BoxShape.circle),
                    child: Icon(playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: () => ref.read(musicPlayerProvider.notifier).playNext(),
                ),
              ],
            ],
          ),
          if (widget.isAdmin) ...[
            const Gap(8),
            Row(
              children: [
                const Icon(Icons.volume_down_rounded, color: Colors.black45, size: 20),
                Expanded(
                  child: Slider(
                    value: playerState.volume,
                    min: 0,
                    max: 100,
                    activeColor: const Color(0xFF00E5FF),
                    inactiveColor: Colors.grey.shade200,
                    onChanged: (val) => ref.read(musicPlayerProvider.notifier).setVolume(val),
                  ),
                ),
                const Icon(Icons.volume_up_rounded, color: Colors.black45, size: 20),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
