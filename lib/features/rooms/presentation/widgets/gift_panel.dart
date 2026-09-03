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

import 'bell_winning_dialog.dart';

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
  String _selectedCategory = 'Gift';

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
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F0F1A), Color(0xFF181726)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -6)),
            ],
          ),
          padding: EdgeInsets.only(
            left: 14, right: 14, top: 10,
            bottom: 8 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            children: [
              // Top Drag Handle Indicator
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              _buildHeader(context, ref),
              const Gap(8),
              participantsAsync.when(
                data: (pts) => _buildRecipientSelector(pts),
                loading: () => const SizedBox(height: 52),
                error: (_, __) => const SizedBox(height: 52),
              ),
              const Divider(color: Colors.white12, height: 14),
              _buildCategoryTabs(),
              const SizedBox(height: 8),
              Expanded(
                child: giftsAsync.when(
                  data: (gifts) {
                    if (gifts.isEmpty) {
                      return const Center(child: Text("No gifts available", style: TextStyle(color: Colors.white54)));
                    }

                    final filteredGifts = gifts.where((g) {
                      if (_selectedCategory == 'All') return true;
                      final cat = g.category.toLowerCase().trim();
                      final sel = _selectedCategory.toLowerCase().trim();
                      if (sel == 'gift') return cat == 'gift' || cat == 'normal' || cat == 'standard';
                      if (sel == 'lucky fruit') return cat.contains('fruit');
                      return cat.contains(sel);
                    }).toList();

                    final displayGifts = filteredGifts.isNotEmpty ? filteredGifts : gifts;

                    return GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: displayGifts.length,
                      itemBuilder: (context, index) {
                        final gift = displayGifts[index];
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
                  loading: () => const SizedBox.shrink(),
                  error: (err, _) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.white70))),
                ),
              ),
              const Divider(color: Colors.white12, height: 12),
              _buildComboRow(),
              _buildFooter(diamondBalance, ref),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryTabs() {
    final categories = ['Gift', 'Lucky', 'Lucky fruit', 'Relationship', 'VIP', 'Custom', 'All'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF9100)])
                    : null,
                color: isSelected ? null : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecipientSelector(List<Participant> participants) {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    final recipients = participants.where((p) => 
      (p.role == 'host' || p.seatIndex != -1 || p.uid == widget.targetUid) && p.uid != currentUserUid
    ).toList();

    if (_selectedTargetUids.isEmpty && !_sendToAll && recipients.isNotEmpty) {
      final host = recipients.firstWhere(
        (p) => p.role == 'host',
        orElse: () => recipients.first,
      );
      _selectedTargetUids = [host.uid];
    }

    recipients.sort((a, b) {
      if (_selectedTargetUids.contains(a.uid) && !_selectedTargetUids.contains(b.uid)) return -1;
      if (!_selectedTargetUids.contains(a.uid) && _selectedTargetUids.contains(b.uid)) return 1;
      return 0;
    });

    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
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
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _sendToAll ? const Color(0xFF00E5FF) : Colors.white12, 
                    width: _sendToAll ? 2 : 1
                  ),
                  color: _sendToAll ? const Color(0xFF00E5FF).withOpacity(0.15) : Colors.white.withOpacity(0.06),
                  boxShadow: _sendToAll
                      ? [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.3), blurRadius: 8)]
                      : [],
                ),
                child: Center(
                  child: Text(
                    "All", 
                    style: TextStyle(
                      color: _sendToAll ? const Color(0xFF00E5FF) : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13
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
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFF00E5FF) : Colors.white12, 
                  width: isSelected ? 2 : 1
                ),
                color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.15) : Colors.white.withOpacity(0.04),
                boxShadow: isSelected
                    ? [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.3), blurRadius: 8)]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: CachedNetworkImageProvider(
                      p.profilePhotoUrl.isEmpty ? "https://picsum.photos/seed/${p.uid}/100" : p.profilePhotoUrl
                    ),
                  ),
                  const Gap(6),
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
                          style: TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.w900)
                        ),
                    ],
                  ),
                  const Gap(4),
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
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: combos.map((q) {
          final isSel = _selectedQuantity == q;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedQuantity = q);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSel
                    ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF9100)])
                    : null,
                color: isSel ? null : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSel ? const Color(0xFFFFD700) : Colors.white10,
                ),
              ),
              child: Text(
                "×$q",
                style: TextStyle(
                  color: isSel ? Colors.black : Colors.white70,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        const Text(
          "Send Gift",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.3),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => _showLuckyBagDialog(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF1744), Color(0xFFD50000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF1744).withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.6), width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("🧧", style: TextStyle(fontSize: 14)),
                Gap(5),
                Text("Lucky Bag", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
              ],
            ),
          ),
        ),
        const Gap(6),
        GestureDetector(
          onTap: () => _feedSampleGifts(context, ref),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber.withOpacity(0.4)),
            ),
            child: const Icon(Icons.refresh_rounded, size: 15, color: Colors.amber),
          ),
        ),
        const Gap(6),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
          ),
        ),
      ],
    );
  }

  void _showLuckyBagDialog(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController(text: '50000');
    final winnersController = TextEditingController(text: '10');
    int currentStep = 1;
    bool isDropping = false;

    final quickPools = [10000, 50000, 100000, 500000];
    final quickWinners = [5, 10, 20, 50];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final amt = int.tryParse(amountController.text) ?? 50000;
          final win = int.tryParse(winnersController.text) ?? 10;
          final perWinner = win > 0 ? (amt / win).round() : 0;

          return AlertDialog(
            backgroundColor: const Color(0xFF141221),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text("🧧", style: TextStyle(fontSize: 26)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentStep == 1 ? "Step 1: Diamond Pool" : "Step 2: Winner Count",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            Text(
                              currentStep == 1 ? "Select total diamonds to drop" : "Select number of lucky winners",
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 4,
                          decoration: BoxDecoration(
                            color: currentStep == 2 ? const Color(0xFFFFD700) : Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (currentStep == 1) ...[
                    const Text(
                      "Quick Select Pool:",
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: quickPools.map((pool) {
                        final isSel = amt == pool;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setDlgState(() => amountController.text = pool.toString());
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFFFFD700).withOpacity(0.2) : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isSel ? const Color(0xFFFFD700) : Colors.white12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const PremiumDiamond(size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  "${(pool / 1000).toStringAsFixed(0)}K",
                                  style: TextStyle(
                                    color: isSel ? const Color(0xFFFFD700) : Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 16),
                      onChanged: (_) => setDlgState(() {}),
                      decoration: InputDecoration(
                        labelText: "Custom Pool Amount",
                        labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                        prefixIcon: const Icon(Icons.diamond_rounded, color: Color(0xFFFFD700)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setDlgState(() => currentStep = 2);
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Next Step", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      "Quick Select Winners:",
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: quickWinners.map((w) {
                        final isSel = win == w;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setDlgState(() => winnersController.text = w.toString());
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFFFF4081).withOpacity(0.2) : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isSel ? const Color(0xFFFF4081) : Colors.white12),
                            ),
                            child: Text(
                              "$w Winners",
                              style: TextStyle(
                                color: isSel ? const Color(0xFFFF4081) : Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: winnersController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                      onChanged: (_) => setDlgState(() {}),
                      decoration: InputDecoration(
                        labelText: "Custom Winner Count",
                        labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                        prefixIcon: const Icon(Icons.group_rounded, color: Color(0xFFFF4081)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Estimated Payout", style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text("~$perWinner 💎 / winner", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          Text("$win Winners", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                side: const BorderSide(color: Colors.white24),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                              onPressed: () => setDlgState(() => currentStep = 1),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_back_rounded, size: 16),
                                  SizedBox(width: 4),
                                  Text("Back", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                backgroundColor: const Color(0xFFFFD700),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                              onPressed: isDropping ? null : () async {
                                setDlgState(() => isDropping = true);
                                try {
                                  await ref.read(giftServiceProvider).sendLuckyBag(
                                    roomId: widget.roomId,
                                    totalDiamonds: amt,
                                    winnerCount: win,
                                  );
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Text("🎉", style: TextStyle(fontSize: 18)),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text("Dropped Lucky Bag ($amt 💎) to room!", style: const TextStyle(fontWeight: FontWeight.bold))),
                                          ],
                                        ),
                                        backgroundColor: const Color(0xFFD97706),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    setDlgState(() => isDropping = false);
                                    String humanError = "Could not drop lucky bag. Please check your diamond balance.";
                                    final errStr = e.toString().toLowerCase();
                                    if (errStr.contains("balance") || errStr.contains("diamond") || errStr.contains("insufficient")) {
                                      humanError = "Insufficient diamonds! Please top-up to send lucky bag.";
                                    } else if (errStr.contains("network") || errStr.contains("socket") || errStr.contains("connection")) {
                                      humanError = "Network connection issue. Please check your internet.";
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(humanError, style: const TextStyle(fontWeight: FontWeight.bold))),
                                          ],
                                        ),
                                        backgroundColor: Colors.redAccent.shade700,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: isDropping 
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("DROP BAG", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13), maxLines: 1),
                                        SizedBox(width: 6),
                                        Text("🧧", style: TextStyle(fontSize: 16)),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter(int diamondBalance, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PremiumDiamond(size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      "$diamondBalance",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Top-up >",
                    style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: (_selectedGift == null || _isSending) ? null : () => _sendSelectedGift(ref),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                gradient: (_selectedGift != null && !_isSending)
                    ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF9100)])
                    : LinearGradient(colors: [Colors.grey.shade700, Colors.grey.shade800]),
                borderRadius: BorderRadius.circular(22),
                boxShadow: (_selectedGift != null && !_isSending)
                    ? [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4), blurRadius: 10)]
                    : [],
              ),
              alignment: Alignment.center,
              child: _isSending 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) 
                  : const Text(
                      "Send",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendSelectedGift(WidgetRef ref) async {
    if (_selectedGift == null) return;
    
    final currentUser = ref.read(currentUserProfileProvider).value;
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    
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
        : _selectedTargetUids;

    if (finalTargets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one recipient!")));
      return;
    }

    setState(() => _isSending = true);

    try {
      final results = await ref.read(giftServiceProvider).sendGift(
        roomId: widget.roomId,
        gift: _selectedGift!,
        targetUids: finalTargets,
        quantity: _selectedQuantity,
        isMoment: widget.isMoment,
      );

      if (mounted) {
        Navigator.pop(context);

        final isLucky = (_selectedGift!.category.toLowerCase() == 'lucky') || _selectedGift!.name.toLowerCase().contains('bell');
        if (isLucky && results.isNotEmpty) {
          final res = results.first;
          final multiplier = (res['luckyMultiplier'] as num?)?.toInt() ?? 0;
          final winningAmount = (res['winningAmount'] as num?)?.toInt() ?? (res['luckyRewardCoins'] as num?)?.toInt() ?? 0;
          final receiverBeans = (res['receiverBeans'] as num?)?.toInt() ?? 1;

          final currentUserUid = FirebaseAuth.instance.currentUser?.uid ?? '';
          final senderUser = ref.read(userProfileProvider(currentUserUid)).value;
          final senderName = senderUser?.displayName ?? "User";
          String receiverName = "User";
          try {
            final targetUid = finalTargets.first;
            final participants = ref.read(roomParticipantsProvider(widget.roomId)).value ?? [];
            final targetUser = participants.firstWhere((p) => p.uid == targetUid);
            receiverName = targetUser.displayName;
          } catch (_) {}

          BellWinningDialog.show(
            context: context,
            senderName: senderName,
            receiverName: receiverName,
            giftPrice: _selectedGift!.priceInDiamonds,
            multiplier: multiplier,
            winningAmount: winningAmount,
            receiverBeans: receiverBeans,
          );
        }
      }
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
    final isLucky = gift.category.toLowerCase().contains('lucky');

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.12) : const Color(0xFF1B1B26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.white.withOpacity(0.06),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.3), blurRadius: 10)]
              : [],
        ),
        padding: const EdgeInsets.all(5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: 42,
                  height: 42,
                  child: gift.imageUrl.startsWith('http') 
                    ? CachedNetworkImage(
                        imageUrl: gift.imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Icon(Icons.card_giftcard, color: Colors.white24, size: 24),
                        errorWidget: (context, url, error) => const Icon(Icons.card_giftcard, color: Colors.white24, size: 24),
                      )
                    : Center(child: Text(gift.imageUrl.isEmpty ? "🎁" : gift.imageUrl, style: const TextStyle(fontSize: 28))),
                ),
                if (isLucky)
                  Positioned(
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF0055), Color(0xFFFF5000)]),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 4)],
                      ),
                      child: const Text(
                        "JACKPOT",
                        style: TextStyle(color: Colors.white, fontSize: 6.5, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              gift.name, 
              style: TextStyle(
                color: isSelected ? const Color(0xFF00E5FF) : Colors.white,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ), 
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${gift.priceInDiamonds}", 
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 9.5, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 2),
                const PremiumDiamond(size: 9),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
