import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/models/participant_model.dart';
import '../../../../core/models/message_model.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/router/app_router.dart';
import '../widgets/seat_grid.dart';
import '../widgets/chat_widget.dart';
import '../widgets/gift_panel.dart';
import '../widgets/gift_animation_overlay.dart';
import '../widgets/pk_battle_widget.dart';
import '../widgets/entry_effect_overlay.dart';
import '../../../../core/services/broadcast_service.dart';

import '../../../games/presentation/widgets/games_panel.dart';

class LiveRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  const LiveRoomScreen({super.key, required this.roomId});

  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen> {
  final TextEditingController _chatController = TextEditingController();
  Participant? _entryParticipant;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(roomServiceProvider).joinRoom(widget.roomId);
      await ref.read(voiceServiceProvider).joinRoom(widget.roomId, ref.read(authStateProvider).value?.uid ?? 'guest');
    });
  }

  @override
  void dispose() {
    ref.read(voiceServiceProvider).leaveRoom();
    _chatController.dispose();
    super.dispose();
  }

  void _leaveRoom() async {
    await ref.read(roomServiceProvider).leaveRoom(widget.roomId);
    if (mounted) context.pop();
  }

  void _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    await ref.read(chatServiceProvider).sendTextMessage(widget.roomId, uid, text);
    _chatController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(currentRoomStreamProvider(widget.roomId));
    final participantsAsync = ref.watch(roomParticipantsProvider(widget.roomId));
    final messagesAsync = ref.watch(roomMessagesProvider(widget.roomId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: roomAsync.when(
        data: (room) {
          if (room == null || room.status == 'ended') {
            return _buildRoomEndedSummary();
          }

          return GiftAnimationOverlay(
            roomId: widget.roomId,
            child: Stack(
              children: [
                // Background Image/Blur
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(room.coverUrl.isEmpty ? "https://picsum.photos/seed/${room.roomId}/600/1200" : room.coverUrl),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
                    ),
                  ),
                ),
                
                // Entry Effect
                if (_entryParticipant != null)
                  EntryEffectOverlay(
                    participant: _entryParticipant!,
                    onEnd: () => setState(() => _entryParticipant = null),
                  ),

                SafeArea(
                  child: Column(
                    children: [
                      // Top Bar
                      _buildTopBar(room),

                      // Global Broadcast Ticker
                      _buildBroadcastTicker(),

                      // Hidden trigger listener
                      participantsAsync.when(
                        data: (pts) {
                          if (_entryParticipant == null && pts.isNotEmpty) {
                            final latest = pts.last;
                          }
                          return const SizedBox.shrink();
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      
                      // PK Battle Widget
                      PKBattleWidget(room: room),

                      // Capacity Grid
                      Expanded(
                        flex: 2,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: participantsAsync.when(
                            data: (participants) => SeatGrid(
                              participants: participants,
                              capacity: room.capacity,
                              onSeatTap: (index) => _onSeatTap(index, participants),
                              onUserLongPress: (p) => _showUserOptions(p),
                            ),
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, __) => Text("Error: $e", style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),

                      // Chat Overlay
                      Expanded(
                        flex: 1,
                        child: messagesAsync.when(
                          data: (messages) => ChatWidget(messages: messages),
                          loading: () => const SizedBox(),
                          error: (e, __) => Text("Chat Error: $e", style: const TextStyle(color: Colors.white)),
                        ),
                      ),

                      // Bottom Bar
                      _buildBottomBar(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text("Error loading room: $e", style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _buildTopBar(RoomModel room) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const Gap(4),
                Text(room.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _leaveRoom,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Say something...",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const Gap(12),
          IconButton(
            icon: const Icon(Icons.games_outlined, color: Colors.purpleAccent, size: 28),
            onPressed: () => _showGamesPanel(),
          ),
          IconButton(
            icon: const Icon(Icons.card_giftcard, color: Colors.amber, size: 28),
            onPressed: () => _showGiftPanel(),
          ),
        ],
      ),
    );
  }

  void _showGamesPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GamesPanel(roomId: widget.roomId),
    );
  }

  void _showGiftPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GiftPanel(roomId: widget.roomId),
    );
  }

  void _onSeatTap(int index, List<Participant> participants) {
    // Handle seat tap
  }

  void _showUserOptions(Participant p) {
    // Show user options
  }

  Widget _buildBroadcastTicker() {
    return ref.watch(activeBroadcastsProvider).when(
      data: (announcements) {
        if (announcements.isEmpty) return const SizedBox.shrink();
        final msg = announcements.first.message;

        return Container(
          width: double.infinity,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: const Color(0xFF00E5FF).withOpacity(0.3),
                  child: const Icon(Icons.volume_up_rounded, size: 14, color: Colors.white),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      msg,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildRoomEndedSummary() {
    return const Center(child: Text("Room Ended", style: TextStyle(color: Colors.white)));
  }
}
