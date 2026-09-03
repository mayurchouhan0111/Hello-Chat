import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/reseller_service.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/router/app_router.dart';

class ResellerListScreen extends ConsumerWidget {
  const ResellerListScreen({super.key});

  Future<void> _launchWhatsApp(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse("https://wa.me/$cleanPhone");
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not launch WhatsApp for $cleanPhone")),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error opening WhatsApp: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resellersAsync = ref.watch(activeResellersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Authorized Resellers",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: resellersAsync.when(
        data: (resellers) {
          if (resellers.isEmpty) {
            return const Center(
              child: Text("No active resellers found", style: TextStyle(color: Colors.white60)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: resellers.length,
            separatorBuilder: (_, __) => const Gap(12),
            itemBuilder: (context, index) {
              final reseller = resellers[index];
              final uid = reseller['uid']?.toString() ?? '';
              final name = reseller['displayName']?.toString() ?? 'Reseller';
              final helloId = reseller['helloId']?.toString() ?? '';
              final photo = reseller['profilePhotoUrl']?.toString() ?? '';
              final phone = reseller['whatsappNumber']?.toString() ?? '+601112280539';
              final status = reseller['status']?.toString() ?? 'Active';
              final rate = reseller['discountRate']?.toString() ?? 'Special Rate';

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        AppAvatar(
                          imageUrl: photo,
                          radius: 24,
                          showFrame: false,
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Gap(6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      rate,
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Gap(4),
                              Text(
                                "ID: $helloId • $status",
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Gap(16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                            label: const Text("Join WhatsApp", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () => _launchWhatsApp(context, phone),
                          ),
                        ),
                        const Gap(10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text("Send Message", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              context.push('/chat/$uid');
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.amber)),
        error: (e, __) => Center(child: Text("Error loading resellers: $e", style: const TextStyle(color: Colors.white70))),
      ),
    );
  }
}
