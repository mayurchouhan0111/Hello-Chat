import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/widgets/app_toast.dart';
import 'package:hello_chat/services/gift_service.dart';

void showLuckyBagDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String roomId,
}) {
  int selectedAmount = 2000;
  int selectedWinners = 10;
  String selectedMode = 'instant';
  int selectedScheduleMinutes = 5;
  final blessingController = TextEditingController();
  bool isDropping = false;

  final amounts = [
    {'val': 2000, 'label': '2000', 'megaphone': false},
    {'val': 20000, 'label': '20k', 'megaphone': true},
    {'val': 200000, 'label': '200k', 'megaphone': true},
    {'val': 2000000, 'label': '2000k', 'megaphone': true},
  ];

  final winnersList = [10, 20, 40, 100];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) {
        final liveBalance =
            ref.watch(currentUserProfileProvider).value?.diamondBalance ?? 0;

        Widget timingOption({
          required String label,
          required bool selected,
          required VoidCallback onTap,
        }) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                constraints: const BoxConstraints(minHeight: 44),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFFFE0A3)
                      : const Color(0xFFFFF7EC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFFFA000)
                        : const Color(0xFFE4CBB5),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 19,
                      color: selected
                          ? const Color(0xFFFF8F00)
                          : const Color(0xFF9E7B66),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: const Color(0xFF5D3E2B),
                        fontSize: 12.5,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF3B65), Color(0xFFFF2553)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Festive Top Banner matching client reference
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Row(
                      children: [
                        // User Gold Balance Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.monetization_on_rounded,
                                  color: Color(0xFFFFD700), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '$liveBalance >',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          "Lucky Bag",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                            shadows: [
                              Shadow(
                                  color: Colors.black38,
                                  blurRadius: 4,
                                  offset: Offset(0, 1)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Cream Card Body
                  Container(
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBF2),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Gold Quantity
                        const Text(
                          "Gold Quantity",
                          style: TextStyle(
                            color: Color(0xFF5D3E2B),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: amounts.map((item) {
                            final val = item['val'] as int;
                            final label = item['label'] as String;
                            final hasMegaphone = item['megaphone'] as bool;
                            final isSel = selectedAmount == val;

                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setDlgState(() => selectedAmount = val);
                                  },
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        height: 38,
                                        decoration: BoxDecoration(
                                          gradient: isSel
                                              ? const LinearGradient(
                                                  colors: [
                                                    Color(0xFFFF305E),
                                                    Color(0xFFFF1848)
                                                  ],
                                                )
                                              : null,
                                          color: isSel
                                              ? null
                                              : const Color(0xFFFFECD6),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: isSel
                                              ? const [
                                                  BoxShadow(
                                                    color: Color(0x44FF1848),
                                                    blurRadius: 6,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Center(
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              color: isSel
                                                  ? Colors.white
                                                  : const Color(0xFF8B5738),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (hasMegaphone)
                                        Positioned(
                                          top: -4,
                                          right: 2,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF6D00),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: Colors.white,
                                                  width: 1),
                                            ),
                                            child: const Icon(
                                              Icons.campaign_rounded,
                                              size: 10,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),

                        // 2. Number of people
                        const Text(
                          "Number of people",
                          style: TextStyle(
                            color: Color(0xFF5D3E2B),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: winnersList.map((win) {
                            final isSel = selectedWinners == win;
                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setDlgState(() => selectedWinners = win);
                                  },
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    height: 38,
                                    decoration: BoxDecoration(
                                      gradient: isSel
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFFFF305E),
                                                Color(0xFFFF1848)
                                              ],
                                            )
                                          : null,
                                      color: isSel
                                          ? null
                                          : const Color(0xFFFFECD6),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: isSel
                                          ? const [
                                              BoxShadow(
                                                color: Color(0x44FF1848),
                                                blurRadius: 6,
                                                offset: Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$win',
                                        style: TextStyle(
                                          color: isSel
                                              ? Colors.white
                                              : const Color(0xFF8B5738),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),

                        // 3. Blessing
                        const Text(
                          "Blessing",
                          style: TextStyle(
                            color: Color(0xFF5D3E2B),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7EC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFFFE0B2), width: 1.2),
                          ),
                          child: TextField(
                            controller: blessingController,
                            maxLength: 28,
                            style: const TextStyle(
                              color: Color(0xFF5D3E2B),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              hintText: "Within 28 Characters",
                              hintStyle: TextStyle(
                                color: Color(0xFFB89F88),
                                fontSize: 12.5,
                              ),
                              counterText: "",
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 11),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 4. Instant or server-scheduled opening time.
                        const Text(
                          "Available time",
                          style: TextStyle(
                            color: Color(0xFF5D3E2B),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            timingOption(
                              label: 'Instant',
                              selected: selectedMode == 'instant',
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setDlgState(() => selectedMode = 'instant');
                              },
                            ),
                            timingOption(
                              label: '5 min',
                              selected: selectedMode == 'scheduled' &&
                                  selectedScheduleMinutes == 5,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setDlgState(() {
                                  selectedMode = 'scheduled';
                                  selectedScheduleMinutes = 5;
                                });
                              },
                            ),
                            timingOption(
                              label: '10 min',
                              selected: selectedMode == 'scheduled' &&
                                  selectedScheduleMinutes == 10,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setDlgState(() {
                                  selectedMode = 'scheduled';
                                  selectedScheduleMinutes = 10;
                                });
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // 5. Send Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF305E),
                                  Color(0xFFFF1848)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x55FF1848),
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: isDropping
                                  ? null
                                  : () async {
                                      if (liveBalance < selectedAmount) {
                                        AppToast.showError(
                                          context,
                                          "Insufficient diamonds! Available: $liveBalance",
                                        );
                                        return;
                                      }

                                      setDlgState(() => isDropping = true);
                                      try {
                                        final blessing =
                                            blessingController.text.trim();
                                        await ref
                                            .read(giftServiceProvider)
                                            .sendLuckyBag(
                                              roomId: roomId,
                                              totalDiamonds: selectedAmount,
                                              winnerCount: selectedWinners,
                                              message: blessing.isNotEmpty
                                                  ? blessing
                                                  : "Join and claim your Lucky Bag!",
                                              mode: selectedMode,
                                              scheduleMinutes: selectedMode ==
                                                      'scheduled'
                                                  ? selectedScheduleMinutes
                                                  : 0,
                                            );
                                        if (ctx.mounted) {
                                          Navigator.pop(ctx);
                                          AppToast.showSuccess(
                                            context,
                                            "Lucky Bag ($selectedAmount 💎) dropped to room!",
                                          );
                                        }
                                      } catch (e) {
                                        if (ctx.mounted) {
                                          setDlgState(
                                              () => isDropping = false);
                                          String humanError =
                                              "Could not drop lucky bag. Please check your diamond balance.";
                                          final errStr =
                                              e.toString().toLowerCase();
                                          if (errStr.contains("balance") ||
                                              errStr.contains("diamond") ||
                                              errStr
                                                  .contains("insufficient")) {
                                            humanError =
                                                "Insufficient diamonds! Please top-up to send lucky bag.";
                                          } else if (errStr
                                                  .contains("network") ||
                                              errStr.contains("socket") ||
                                              errStr.contains("connection")) {
                                            humanError =
                                                "Network connection issue. Please check your internet.";
                                          }
                                          AppToast.showError(
                                              context, humanError);
                                        }
                                      }
                                    },
                              child: isDropping
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      "Send",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
