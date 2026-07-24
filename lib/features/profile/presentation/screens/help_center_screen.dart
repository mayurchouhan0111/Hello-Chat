import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/constants/app_colors.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Wallet & Coins',
    'Rooms & Live',
    'VIP & Noble',
    'Account & Safety',
  ];

  final List<Map<String, String>> _faqs = [
    {
      'category': 'Wallet & Coins',
      'question': 'How do I earn and recharge Diamonds & Beans?',
      'answer': 'You can recharge diamonds in the Wallet screen via credit cards, Touch \'n Go, or authorized reseller portals. Beans can be earned by receiving gifts during live streams or participating in the Invite & Earn program.',
    },
    {
      'category': 'VIP & Noble',
      'question': 'How does SVIP and Noble status work?',
      'answer': 'SVIP status is calculated based on cumulative monthly recharge points. Noble status unlocks exclusive entrance titles, floating badges, custom chat bubbles, and room support privileges.',
    },
    {
      'category': 'Rooms & Live',
      'question': 'How do I start a live audio voice room & host PK battles?',
      'answer': 'Tap the "+" floating action button on the Home Screen, select "Create Room", set your room title & tags, and tap "Start Live". Inside your room, open the PK arena panel to challenge other hosts.',
    },
    {
      'category': 'Rooms & Live',
      'question': 'What are Intimacy Points and CP Relationship levels?',
      'answer': 'Intimacy points increase when sending gifts to close friends, voice chatting in rooms together, and maintaining daily streaks. Reaching CP Level unlocks special relationship badges.',
    },
    {
      'category': 'Wallet & Coins',
      'question': 'How do I withdraw host earnings or agency commission?',
      'answer': 'Go to Profile -> Wallet -> Withdraw Beans or Commission Wallet. Ensure your identity verification (KYC) is complete, then enter your bank details for instant payout.',
    },
    {
      'category': 'Account & Safety',
      'question': 'How do I manage my privacy settings & stealth mode?',
      'answer': 'Navigate to Settings -> Privacy Settings. You can toggle "Hide Online Status", enable "Stealth Mode", and manage your Blocked Users list at any time.',
    },
    {
      'category': 'Account & Safety',
      'question': 'How do I report inappropriate content or abusive users?',
      'answer': 'Tap on the user\'s avatar to open their profile card, then tap the "Report" flag icon. Select the reason for violation, and our moderation team will review it within 15 minutes.',
    },
  ];

  void _showTicketModal() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Gap(16),
            const Text("Submit Support Ticket", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const Gap(6),
            const Text("Describe your issue and our team will get back to you within 2 hours.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Gap(16),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: "Subject / Brief Summary",
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const Gap(12),
            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Detailed explanation of your problem...",
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const Gap(20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Ticket Submitted Successfully! We will respond via Inbox."), backgroundColor: Colors.green),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text("SUBMIT TICKET", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredFaqs = _faqs.where((faq) {
      final matchesCategory = _selectedCategory == 'All' || faq['category'] == _selectedCategory;
      final q = faq['question']!.toLowerCase();
      final a = faq['answer']!.toLowerCase();
      final query = _searchQuery.toLowerCase();
      final matchesQuery = q.contains(query) || a.contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("HELP CENTER", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.black, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🌟 Professional Hero Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF818CF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text("24/7 SUPPORT", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
                      const Icon(Icons.help_center_rounded, color: Colors.white70, size: 28),
                    ],
                  ),
                  const Gap(12),
                  const Text(
                    "How can we help you?",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                  const Gap(4),
                  const Text(
                    "Search articles or choose a category below.",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const Gap(20),
                  // Search Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
                      ],
                    ),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(color: Colors.black, fontSize: 14),
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search_rounded, color: AppColors.primary),
                        hintText: "Search help topic, e.g. Beans, VIP...",
                        hintStyle: TextStyle(color: Colors.black38, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fade().scale(begin: const Offset(0.96, 0.96)),

            const Gap(24),

            // 🏷️ Category Filter Chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const Gap(8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.black.withOpacity(0.06),
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3)),
                        ] : null,
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const Gap(24),

            // 📋 FAQ Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "FREQUENTLY ASKED QUESTIONS",
                  style: TextStyle(color: Colors.grey[700], fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
                Text(
                  "${filteredFaqs.length} Articles",
                  style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),

            const Gap(12),

            // ❓ FAQ Accordion List
            if (filteredFaqs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withOpacity(0.04)),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                    Gap(12),
                    Text("No matching articles found", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                    Gap(4),
                    Text("Try searching with different keywords or submit a ticket below.", style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                  ],
                ),
              )
            else
              ...filteredFaqs.asMap().entries.map((entry) {
                final index = entry.key;
                final faq = entry.value;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      iconColor: AppColors.primary,
                      collapsedIconColor: Colors.grey,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              faq['category']!,
                              style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const Gap(8),
                          Expanded(
                            child: Text(
                              faq['question']!,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(height: 1, color: Color(0xFFF3F4F6)),
                              const Gap(12),
                              Text(
                                faq['answer']!,
                                style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.5),
                              ),
                              const Gap(12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Text("Was this helpful?", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  const Gap(8),
                                  IconButton(
                                    icon: const Icon(Icons.thumb_up_alt_outlined, size: 16, color: Colors.grey),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Thank you for your feedback! 👍")),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fade(duration: 250.ms, delay: Duration(milliseconds: 30 * index)).slideY(begin: 0.05);
              }),

            const Gap(32),

            // 🎧 Live Support & Ticket Grid
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Connecting to Live Customer Support Agent...")),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 10)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.headset_mic_rounded, color: AppColors.primary, size: 22),
                          ),
                          const Gap(12),
                          const Text("24/7 Live Chat", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                          const Gap(2),
                          const Text("Chat with agent", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: GestureDetector(
                    onTap: _showTicketModal,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black.withOpacity(0.06)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), shape: BoxShape.circle),
                            child: const Icon(Icons.confirmation_number_rounded, color: Colors.amber, size: 22),
                          ),
                          const Gap(12),
                          const Text("Submit Ticket", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                          const Gap(2),
                          const Text("Response in 2 hrs", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const Gap(32),
          ],
        ),
      ),
    );
  }
}
