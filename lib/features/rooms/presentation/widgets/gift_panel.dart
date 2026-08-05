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
  List<String> _selectedTargetUids = [];
  bool _sendToAll = false;

  @override
  void initState() {
    super.initState();
    if (widget.targetUid != null) {
      _selectedTargetUids.add(widget.targetUid!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final diamondBalance = ref.watch(currentUserProfileProvider.select((u) => u.value?.diamondBalance ?? 0));
        final giftsAsync = ref.watch(giftsStreamProvider);
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
              _buildHeader(context, ref),
              Gap(8),
              participantsAsync.when(
                data: (pts) => _buildRecipientSelector(pts),
                loading: () => const SizedBox(height: 60),
                error: (_, __) => const SizedBox(height: 60),
              ),
              const Divider(color: Colors.white10, height: 24),
              Expanded(
                child: giftsAsync.when(
                  data: (gifts) {
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
                        );
                      },
                    );
                  },
                  loading: () => const SizedBox.shrink(), // Silent background load, no spinner!
                  error: (err, _) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.white70))),
                ),
              ),
              const Divider(color: Colors.white10),
              _buildComboRow(),
              _buildFooter(diamondBalance, ref),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecipientSelector(List<Participant> participants) {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    // Filter to show Host + Anyone on Seats + Target User (exclude current user - no self-gifting)
    final recipients = participants.where((p) => 
      (p.role == 'host' || p.seatIndex != -1 || p.uid == widget.targetUid) && p.uid != currentUserUid
    ).toList();

    // If no selection yet, default to host
    if (_selectedTargetUids.isEmpty && !_sendToAll && recipients.isNotEmpty) {
      final host = recipients.firstWhere(
        (p) => p.role == 'host',
        orElse: () => recipients.first,
      );
      _selectedTargetUids = [host.uid];
    }

    // Move selected targets to the front
    recipients.sort((a, b) {
      if (_selectedTargetUids.contains(a.uid) && !_selectedTargetUids.contains(b.uid)) return -1;
      if (!_selectedTargetUids.contains(a.uid) && _selectedTargetUids.contains(b.uid)) return 1;
      return 0;
    });

    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recipients.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _sendToAll = !_sendToAll;
                  if (_sendToAll) _selectedTargetUids.clear();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _sendToAll ? const Color(0xFF00E5FF) : Colors.transparent, 
                    width: 2
                  ),
                  color: _sendToAll ? const Color(0xFF00E5FF).withOpacity(0.1) : Colors.white12,
                ),
                child: Center(
                  child: Text(
                    "All", 
                    style: TextStyle(
                      color: _sendToAll ? const Color(0xFF00E5FF) : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14
                    ),
                  ),
                ),
              ),
            );
          }

          final p = recipients[index - 1];
          final isSelected = _selectedTargetUids.contains(p.uid);
          
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (_sendToAll) _sendToAll = false;
                if (_selectedTargetUids.contains(p.uid)) {
                  _selectedTargetUids.remove(p.uid);
                } else {
                  _selectedTargetUids.add(p.uid);
                }
              });
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
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Send Gift", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Row(
          children: [
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

  Widget _buildFooter(int diamondBalance, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const PremiumDiamond(size: 18),
          const SizedBox(width: 6),
          Text(
            "$diamondBalance",
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
    
    final currentUser = ref.read(currentUserProfileProvider).value;
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    
    // Category sending restriction validation
    if (_selectedGift!.category.toLowerCase() == 'vip') {
      final isVipActive = currentUser != null && currentUser.vipTier != null && currentUser.vipTier != 'none' && currentUser.vipExpiry != null && currentUser.vipExpiry!.isAfter(DateTime.now());
      if (!isVipActive) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("👑 Only active VIP members can send VIP gifts!")));
        return;
      }
    } else if (_selectedGift!.category.toLowerCase() == 'svip') {
      final userSvipLevel = currentUser?.svipLevel ?? 0;
      final reqLevel = _selectedGift!.minSvipLevel > 0 ? _selectedGift!.minSvipLevel : 1;
      if (userSvipLevel < reqLevel) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("⚡ SVIP Level $reqLevel required to send this gift!")));
        return;
      }
    }
    
    final finalTargets = _sendToAll 
        ? ref.read(roomParticipantsProvider(widget.roomId)).value?.where((p) => 
            (p.role == 'host' || p.seatIndex != -1) && p.uid != currentUserUid
          ).map((e) => e.uid).toList() ?? []
        : List<String>.from(_selectedTargetUids);

    if (finalTargets.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No recipients selected")));
      return;
    }

    if (finalTargets.contains(currentUserUid)) {
      finalTargets.remove(currentUserUid);
      if (finalTargets.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You cannot send a gift to yourself")));
        return;
      }
    }
    
    setState(() => _isSending = true);
    try {
      await ref.read(giftServiceProvider).sendGift(
        roomId: widget.roomId,
        gift: _selectedGift!,
        targetUids: finalTargets,
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
                    placeholder: (context, url) => const Icon(Icons.card_giftcard, color: Colors.white10),
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
