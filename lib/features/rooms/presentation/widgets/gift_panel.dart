import 'package:flutter/material.dart';
import 'package:hello_chat/core/widgets/premium_diamond.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hello_chat/core/models/gift_model.dart';
import 'package:hello_chat/services/gift_service.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/models/participant_model.dart';
import 'package:hello_chat/core/providers/room_provider.dart';

class GiftPanel extends StatefulWidget {
  final String roomId;
  final String? targetUid;
  final bool isMoment;

  const GiftPanel({
    super.key, 
    required this.roomId, 
    this.targetUid,
    this.isMoment = false,
  });

  @override
  State<GiftPanel> createState() => _GiftPanelState();
}

class _GiftPanelState extends State<GiftPanel> {
  int _selectedQuantity = 1;
  GiftModel? _selectedGift;
  bool _isSending = false;
  String? _selectedTargetUid;

  @override
  void initState() {
    super.initState();
    _selectedTargetUid = widget.targetUid;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final userAsync = ref.watch(currentUserProfileProvider);
        final giftsStream = ref.watch(giftServiceProvider).getGiftsStream();
        final participantsAsync = ref.watch(roomParticipantsProvider(widget.roomId));

        return Container(
          height: 560, // Adjusted for recipient row
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              _buildHeader(context, userAsync, ref),
              Gap(8),
              participantsAsync.when(
                data: (pts) => _buildRecipientSelector(pts),
                loading: () => const SizedBox(height: 60),
                error: (_, __) => const SizedBox(height: 60),
              ),
              const Divider(color: Colors.white10, height: 24),
              Expanded(
                child: StreamBuilder<List<GiftModel>>(
                  stream: giftsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final gifts = snapshot.data ?? [];
                    if (gifts.isEmpty) {
                      return const Center(child: Text("No gifts available", style: TextStyle(color: Colors.white54)));
                    }

                    return GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.7,
                      ),
                      itemCount: gifts.length,
                      itemBuilder: (context, index) {
                        final gift = gifts[index];
                        return _GiftTile(
                          gift: gift, 
                          isSelected: _selectedGift?.giftId == gift.giftId,
                          onSelect: () {
                             HapticFeedback.selectionClick();
                             setState(() => _selectedGift = gift);
                          },
                        ).animate().scale(
                          duration: 300.ms, 
                          curve: Curves.easeOutBack, 
                          delay: (index * 30).ms
                        ).fadeIn();
                      },
                    );
                  },
                ),
              ),
              const Divider(color: Colors.white10),
              _buildComboRow(),
              _buildFooter(userAsync, ref),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecipientSelector(List<Participant> participants) {
    // If no selection yet, default to host
    if (_selectedTargetUid == null && participants.isNotEmpty) {
      final host = participants.firstWhere((p) => p.role == 'host', orElse: () => participants.first);
      _selectedTargetUid = host.uid;
    }

    // Filter to show Host + Anyone on Seats
    final recipients = participants.where((p) => p.role == 'host' || p.seatIndex != -1).toList();

    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recipients.length,
        itemBuilder: (context, index) {
          final p = recipients[index];
          final isSelected = _selectedTargetUid == p.uid;
          
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedTargetUid = p.uid);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent, 
                  width: 2
                ),
                color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.1) : Colors.transparent,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: CachedNetworkImageProvider(
                      p.profilePhotoUrl.isEmpty ? "https://picsum.photos/seed/${p.uid}/100" : p.profilePhotoUrl
                    ),
                  ),
                  Gap(8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.displayName.isNotEmpty ? p.displayName : "User",
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF00E5FF) : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      if (p.role == 'host')
                        const Text(
                          "Host", 
                          style: TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold)
                        ),
                    ],
                  ),
                  Gap(8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildComboRow() {
    final combos = [1, 5, 10, 99, 520, 1314];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: combos.map((q) => GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedQuantity = q);
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _selectedQuantity == q ? const Color(0xFFFFD700).withOpacity(0.2) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _selectedQuantity == q ? const Color(0xFFFFD700) : Colors.transparent),
            ),
            child: Text("×$q", style: TextStyle(color: _selectedQuantity == q ? const Color(0xFFFFD700) : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
          ).animate(key: ValueKey(_selectedQuantity == q)).scale(
            duration: 200.ms, 
            curve: Curves.easeOutBack,
            begin: _selectedQuantity == q ? const Offset(0.9, 0.9) : const Offset(1, 1),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AsyncValue<dynamic> userAsync, WidgetRef ref) {
    UserModel? userData;
    if (userAsync.hasValue) userData = userAsync.value as UserModel?;
    final isAdmin = userData?.tags.any((t) => t == 'Admin' || t == 'SuperAdmin') ?? false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Send Gift", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Row(
          children: [
            if (isAdmin)
              TextButton.icon(
                onPressed: () => _feedSampleGifts(context, ref),
                icon: const Icon(Icons.refresh, size: 16, color: Colors.amber),
                label: const Text("Feed Gifts", style: TextStyle(color: Colors.amber, fontSize: 12)),
              ),
            IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter(AsyncValue<dynamic> userAsync, WidgetRef ref) {
    UserModel? userData;
    if (userAsync.hasValue) userData = userAsync.value as UserModel?;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const PremiumDiamond(size: 18),
          const SizedBox(width: 6),
          Text(
            "${userData?.diamondBalance ?? 0}",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Spacer(),
          const Text("Top-up", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
          const Icon(Icons.chevron_right, color: Color(0xFFFFD700), size: 18),
          const SizedBox(width: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              minimumSize: const Size(80, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            onPressed: (_selectedGift == null || _isSending) ? null : () => _sendSelectedGift(ref),
            child: _isSending 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) 
                : const Text("Send", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendSelectedGift(WidgetRef ref) async {
    if (_selectedGift == null) return;
    setState(() => _isSending = true);
    try {
      await ref.read(giftServiceProvider).sendGift(
        roomId: widget.roomId,
        gift: _selectedGift!,
        targetUid: _selectedTargetUid,
        quantity: _selectedQuantity,
        isMoment: widget.isMoment,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _feedSampleGifts(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(giftServiceProvider).feedSampleGifts();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sample gifts seeded successfully!")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}

class _GiftTile extends StatelessWidget {
  final GiftModel gift;
  final bool isSelected;
  final VoidCallback onSelect;

  const _GiftTile({
    required this.gift, 
    this.isSelected = false,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent, width: 1.5),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: gift.imageUrl.startsWith('http') 
                ? CachedNetworkImage(
                    imageUrl: gift.imageUrl,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    errorWidget: (context, url, error) => const Icon(Icons.card_giftcard, color: Colors.white24),
                  )
                : Center(child: Text(gift.imageUrl.isEmpty ? "🎁" : gift.imageUrl, style: const TextStyle(fontSize: 30))),
            ),
            const SizedBox(height: 6),
          Text(
            gift.name, 
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500), 
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${gift.priceInDiamonds} ", 
                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const PremiumDiamond(size: 10),
            ],
          ),
        ],
      ),
    ),
  );
}
}
