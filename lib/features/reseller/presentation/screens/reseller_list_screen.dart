import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/models/reseller_model.dart';
import '../../../../core/services/reseller_service.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../chats/presentation/screens/private_chat_screen.dart';

class ResellerListScreen extends ConsumerWidget {
  const ResellerListScreen({super.key});

  Future<void> _launchWhatsApp(BuildContext context, String phone) async {
    // 1. Sanitize phone number: strip non-numeric characters except leading '+'
    String clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid WhatsApp phone number."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (clean.startsWith('+')) {
      clean = clean.substring(1).replaceAll('+', '');
    }

    final nativeUri = Uri.parse("whatsapp://send?phone=$clean");
    final webUri = Uri.parse("https://wa.me/$clean");

    try {
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {
      // Fall through to web fallback
    }

    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("WhatsApp is not installed on this device or could not be opened."),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error opening WhatsApp: $e"),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _openPrivateLetter(
    BuildContext context,
    WidgetRef ref,
    ResellerModel reseller,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign in to send messages.")),
      );
      return;
    }

    final targetUid = reseller.userId.isNotEmpty ? reseller.userId : reseller.resellerId;
    if (targetUid == currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot chat with yourself.")),
      );
      return;
    }

    try {
      final chatService = ref.read(chatServiceProvider);
      final chatId = await chatService.getOrCreateChat(currentUser.uid, targetUid);
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PrivateChatScreen(
              chatId: chatId,
              otherUid: targetUid,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not open chat: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _formatCoins(int amount) {
    if (amount >= 100000000) {
      return "100000000+";
    } else if (amount >= 1000000) {
      return "${(amount / 1000000).toStringAsFixed(0)}M+";
    } else if (amount >= 1000) {
      return "${(amount / 1000).toStringAsFixed(0)}K+";
    }
    return "$amount+";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resellersAsync = ref.watch(activeResellersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Merchant List",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeResellersProvider);
        },
        child: Column(
          children: [
            // Top Promo Banner
            _buildPromoBanner(),

            // Resellers List
            Expanded(
              child: resellersAsync.when(
                data: (resellers) {
                  final activeList = resellers.where((r) => r.isActive).toList();
                  if (activeList.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Gap(80),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.storefront_rounded, size: 64, color: Colors.black26),
                              Gap(12),
                              Text(
                                "No active merchants available right now.",
                                style: TextStyle(color: Colors.black54, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: activeList.length,
                    separatorBuilder: (_, __) => const Gap(14),
                    itemBuilder: (context, index) {
                      final reseller = activeList[index];
                      return _buildMerchantCard(context, ref, reseller);
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFC107)),
                ),
                error: (e, __) => Center(
                  child: Text(
                    "Error loading merchant list: $e",
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Color(0xFFD97706),
              size: 22,
            ),
          ),
          const Gap(12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Merchant Recharge more benefit",
                  style: TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                Gap(2),
                Text(
                  "Direct recharge with official verified merchants",
                  style: TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantCard(BuildContext context, WidgetRef ref, ResellerModel reseller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header row: Label "Remaining gold coins" with dynamic stock balance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text(
                      "Remaining gold coins",
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          "🪙",
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    const Gap(6),
                    Text(
                      _formatCoins(reseller.coinBalance),
                      style: const TextStyle(
                        color: Color(0xFFD97706),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Profile section: Avatar, Flag, Name, Online status pill
                Row(
                  children: [
                    // Clean avatar with zero outer frame overlay
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      ),
                      child: ClipOval(
                        child: reseller.avatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: reseller.avatarUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: Colors.grey[200]),
                                errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.grey),
                              )
                            : const Icon(Icons.person, color: Colors.grey),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Country Flag
                              Text(
                                reseller.countryFlag,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const Gap(6),
                              // Username / Nickname
                              Flexible(
                                child: Text(
                                  reseller.name,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Gap(4),
                          // Online status pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF86EFAC), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF16A34A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const Gap(4),
                                const Text(
                                  "Online",
                                  style: TextStyle(
                                    color: Color(0xFF16A34A),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Gap(14),

                // 3. Identification info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ID
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "ID:${reseller.resellerId}",
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: reseller.resellerId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("ID copied to clipboard!"),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.copy_rounded, size: 13, color: Color(0xFF64748B)),
                                  Gap(4),
                                  Text(
                                    "Copy",
                                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(6),
                      // Whatsapp number
                      Text(
                        "Whatsapp number: ${reseller.whatsappNumber}",
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const Gap(16),

                // 4. Action Buttons (Side-by-side)
                Row(
                  children: [
                    // "Private letter" (Yellow button)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openPrivateLetter(context, ref, reseller),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC107),
                          foregroundColor: const Color(0xFF1E293B),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.mail_outline_rounded, size: 16),
                        label: const Text(
                          "Private letter",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const Gap(10),
                    // "Whatsapp" (Green button)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _launchWhatsApp(context, reseller.whatsappNumber),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.chat_rounded, size: 16),
                        label: const Text(
                          "Whatsapp",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
