import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/providers/room_provider.dart';

class RoomWelcomeMessageScreen extends ConsumerStatefulWidget {
  final RoomModel room;

  const RoomWelcomeMessageScreen({super.key, required this.room});

  @override
  ConsumerState<RoomWelcomeMessageScreen> createState() => _RoomWelcomeMessageScreenState();
}

class _RoomWelcomeMessageScreenState extends ConsumerState<RoomWelcomeMessageScreen> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isSaving = false;
  bool _isFocused = false;
  static const int _maxLength = 500;

  final List<String> _quickTemplates = [
    "🎉 Welcome to our room! Enjoy your stay ✨",
    "👋 Welcome friends! Feel free to grab a mic 🎙️",
    "👑 Welcome VIP! Thanks for joining us today 🌟",
    "✨ Hi! Make yourself at home and chat with us! 💬",
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.room.welcomeMessage);
    _controller.addListener(() {
      setState(() {});
    });
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    setState(() => _isSaving = true);
    try {
      await ref.read(roomServiceProvider).updateRoomWelcomeMessage(widget.room.roomId, text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF00E5FF), size: 20),
                Gap(10),
                Text("Room Welcome Message saved successfully!"),
              ],
            ),
            backgroundColor: const Color(0xFF16213E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save: $e"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textLength = _controller.text.length;
    final progress = (textLength / _maxLength).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Room Welcome Message Setting",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          // Background ambient glow circles
          Positioned(
            top: -60, right: -60,
            child: Container(
              width: 240, height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E5FF).withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 100, left: -80,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD4E157).withValues(alpha: 0.05),
              ),
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header description card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00E5FF).withValues(alpha: 0.10),
                          const Color(0xFF673AB7).withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF00E5FF), size: 22),
                        ),
                        const Gap(14),
                        const Expanded(
                          child: Text(
                            "Set the Room Welcome Message, it will be automatically sent when friends enter your room",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13.5,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),

                  const Gap(22),

                  // Section Title & Clear Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Custom Welcome Message",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_controller.text.isNotEmpty)
                        GestureDetector(
                          onTap: () => _controller.clear(),
                          child: const Text(
                            "Clear Text",
                            style: TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Gap(10),

                  // Main Text Area Box
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111728),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isFocused 
                            ? const Color(0xFF00E5FF) 
                            : Colors.white.withValues(alpha: 0.12),
                        width: _isFocused ? 1.8 : 1.0,
                      ),
                      boxShadow: _isFocused ? [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                          blurRadius: 16,
                          spreadRadius: 0,
                        ),
                      ] : [],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          maxLength: _maxLength,
                          maxLines: 6,
                          minLines: 4,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.5,
                          ),
                          decoration: const InputDecoration(
                            filled: false,
                            fillColor: Colors.transparent,
                            hintText: "Add your custom room welcome message...",
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            counterText: "",
                          ),
                        ),
                        const Gap(10),
                        Row(
                          children: [
                            // Progress bar
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 4,
                                  backgroundColor: Colors.white10,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    progress > 0.9 
                                        ? Colors.orangeAccent 
                                        : const Color(0xFF00E5FF),
                                  ),
                                ),
                              ),
                            ),
                            const Gap(12),
                            Text(
                              "$textLength/$_maxLength",
                              style: TextStyle(
                                color: progress > 0.9 ? Colors.orangeAccent : Colors.white38,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0),

                  const Gap(22),

                  // Quick Templates Section
                  const Text(
                    "Quick Templates",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickTemplates.map((template) {
                      return GestureDetector(
                        onTap: () {
                          _controller.text = template;
                          _controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: template.length),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161F35),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            template,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ).animate().fadeIn(duration: 400.ms),

                  const Gap(24),

                  // Live Preview Card
                  const Text(
                    "Live Chat Preview",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "👋 Guest enter the room",
                          style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const Gap(6),
                        Text(
                          "@Guest 👉 ${_controller.text.trim().isNotEmpty ? _controller.text.trim() : 'Welcome to our room!'}",
                          style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 450.ms),

                  const Gap(32),

                  // Premium Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD4E157), Color(0xFF00E5FF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save_rounded, color: Colors.black87, size: 20),
                                  Gap(8),
                                  Text(
                                    "Save Welcome Message",
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1)),

                  const Gap(16),

                  // Footer Note
                  const Center(
                    child: Text(
                      "Welcome Message will only be sent when you are in your room",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Gap(20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
