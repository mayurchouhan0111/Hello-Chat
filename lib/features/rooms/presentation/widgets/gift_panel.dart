import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hello_chat/core/models/gift_model.dart';
import 'package:hello_chat/services/gift_service.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/models/user_model.dart';

class GiftPanel extends StatefulWidget {
  final String roomId;
  final String? targetUid;

  const GiftPanel({super.key, required this.roomId, this.targetUid});

  @override
  State<GiftPanel> createState() => _GiftPanelState();
}

class _GiftPanelState extends State<GiftPanel> {
  int _selectedQuantity = 1;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final userAsync = ref.watch(currentUserProfileProvider);
        final giftsStream = ref.watch(giftServiceProvider).getGiftsStream();

        return Container(
          height: 520, // Increased to fix overflow
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              _buildHeader(context, userAsync, ref),
              const Divider(color: Colors.white10),
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
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: gifts.length,
                      itemBuilder: (context, index) {
                        final gift = gifts[index];
                        return _GiftTile(
                          gift: gift, 
                          roomId: widget.roomId, 
                          targetUid: widget.targetUid,
                          quantity: _selectedQuantity,
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(color: Colors.white10),
              _buildComboRow(),
              _buildFooter(userAsync),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComboRow() {
    final combos = [1, 5, 10, 99, 520, 1314];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: combos.map((q) => GestureDetector(
          onTap: () => setState(() => _selectedQuantity = q),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _selectedQuantity == q ? Colors.cyanAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _selectedQuantity == q ? Colors.cyanAccent : Colors.transparent),
            ),
            child: Text("×$q", style: TextStyle(color: _selectedQuantity == q ? Colors.cyanAccent : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
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

  Widget _buildFooter(AsyncValue<dynamic> userAsync) {
    UserModel? userData;
    if (userAsync.hasValue) userData = userAsync.value as UserModel?;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.diamond, color: Colors.amber, size: 18),
          const SizedBox(width: 6),
          Text(
            "${userData?.diamondBalance ?? 0}",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Spacer(),
          const Text("Top-up", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          const Icon(Icons.chevron_right, color: Colors.cyanAccent, size: 18),
        ],
      ),
    );
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

class _GiftTile extends ConsumerWidget {
  final GiftModel gift;
  final String roomId;
  final String? targetUid;
  final int quantity;

  const _GiftTile({required this.gift, required this.roomId, this.targetUid, required this.quantity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        try {
          await ref.read(giftServiceProvider).sendGift(
            roomId: roomId,
            gift: gift,
            targetUid: targetUid,
            quantity: quantity,
          );
          if (context.mounted) Navigator.pop(context);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
        }
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
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
          Text(gift.name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          Text("${gift.priceInDiamonds} 💎", style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
