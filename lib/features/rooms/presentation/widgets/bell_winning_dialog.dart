import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

class BellWinningDialog extends StatefulWidget {
  final String senderName;
  final String receiverName;
  final String senderPhotoUrl;
  final String receiverPhotoUrl;
  final int giftPrice;
  final int multiplier;
  final int winningAmount;
  final int receiverBeans;
  final VoidCallback onDismiss;

  const BellWinningDialog({
    super.key,
    required this.senderName,
    required this.receiverName,
    this.senderPhotoUrl = '',
    this.receiverPhotoUrl = '',
    this.giftPrice = 5,
    required this.multiplier,
    required this.winningAmount,
    this.receiverBeans = 1,
    required this.onDismiss,
  });

  static void show({
    required BuildContext context,
    required String senderName,
    required String receiverName,
    String senderPhotoUrl = '',
    String receiverPhotoUrl = '',
    int giftPrice = 5,
    required int multiplier,
    required int winningAmount,
    int receiverBeans = 1,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => BellWinningDialog(
        senderName: senderName,
        receiverName: receiverName,
        senderPhotoUrl: senderPhotoUrl,
        receiverPhotoUrl: receiverPhotoUrl,
        giftPrice: giftPrice,
        multiplier: multiplier,
        winningAmount: winningAmount,
        receiverBeans: receiverBeans,
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  State<BellWinningDialog> createState() => _BellWinningDialogState();
}

class _BellWinningDialogState extends State<BellWinningDialog> {
  @override
  Widget build(BuildContext context) {
    final bool isWin = widget.multiplier > 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1035), Color(0xFF0F0B1E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isWin ? const Color(0xFFFFD700).withValues(alpha: 0.6) : Colors.white24,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isWin ? const Color(0xFFFFD700).withValues(alpha: 0.3) : Colors.black54,
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Banner Notice (Step 1)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("🔔", style: TextStyle(fontSize: 16)),
                    const Gap(6),
                    Flexible(
                      child: Text(
                        "${widget.senderName} sent Bell to ${widget.receiverName}",
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Gap(6),
                    const Text("🔔", style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),

              const Gap(24),

              // Visual Bell Icon & Winning Ray Animation (Step 2)
              Stack(
                alignment: Alignment.center,
                children: [
                  if (isWin) ...[
                    // Glowing Light Burst Rays
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFFD700).withValues(alpha: 0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ).animate(onPlay: (c) => c.repeat()).scale(
                          duration: 2000.ms,
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1.2, 1.2),
                        ),
                  ],

                  // Main Bell Graphic
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isWin ? const Color(0xFF3B2500) : const Color(0xFF22222E),
                      border: Border.all(
                        color: isWin ? const Color(0xFFFFD700) : Colors.white24,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isWin ? const Color(0xFFFFB800).withValues(alpha: 0.5) : Colors.black45,
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        isWin ? "🔔" : "🛎️",
                        style: TextStyle(
                          fontSize: 64,
                          shadows: isWin
                              ? [const Shadow(color: Colors.amber, blurRadius: 20)]
                              : null,
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .scale(duration: 400.ms, curve: Curves.elasticOut)
                      .shake(duration: 600.ms, hz: 4),
                ],
              ),

              const Gap(16),

              // Ribbon Badge
              if (isWin) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF0055), Color(0xFFFF5500)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF0055).withValues(alpha: 0.5),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Text(
                    "WIN ×${widget.multiplier}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 1.2,
                    ),
                  ),
                ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),

                const Gap(16),

                const Text(
                  "WINNING",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),

                const Gap(4),

                // Amount Text
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${widget.winningAmount}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: Color(0xFF00E5FF), blurRadius: 15),
                        ],
                      ),
                    ),
                    const Gap(8),
                    const Text("💎", style: TextStyle(fontSize: 32)),
                  ],
                ).animate().fade().scale(delay: 300.ms),

                const Gap(4),

                const Text(
                  "DIAMONDS",
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),

                const Gap(16),

                // Winner Subtitle Announcement
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("🎉", style: TextStyle(fontSize: 14)),
                      const Gap(6),
                      Text(
                        "${widget.senderName} won ${widget.winningAmount} Diamonds!",
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // No Win State
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "No Win",
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),

                const Gap(12),

                const Text(
                  "Better luck next time!",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              const Gap(24),

              // Bottom Result Summary Pill (Step 3)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Sender
                    Column(
                      children: [
                        Text(
                          widget.senderName,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const Text("Sender", style: TextStyle(color: Colors.white38, fontSize: 9)),
                      ],
                    ),

                    const Text("➔", style: TextStyle(color: Colors.amber, fontSize: 16)),

                    // Gift
                    Column(
                      children: [
                        const Text("🔔 Bell", style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text("${widget.giftPrice} 💎", style: const TextStyle(color: Colors.white54, fontSize: 9)),
                      ],
                    ),

                    const Text("➔", style: TextStyle(color: Colors.amber, fontSize: 16)),

                    // Receiver
                    Column(
                      children: [
                        Text(
                          widget.receiverName,
                          style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Text("+${widget.receiverBeans} Bean 🫘", style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),

              const Gap(20),

              // Close Button
              GestureDetector(
                onTap: widget.onDismiss,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: const BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                  ),
                  child: const Center(
                    child: Text(
                      "OK",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
