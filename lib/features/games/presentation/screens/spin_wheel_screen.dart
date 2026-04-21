import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/providers/wallet_provider.dart';
import 'package:hello_chat/core/providers/game_provider.dart';
import 'package:hello_chat/core/services/game_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';

class SpinWheelScreen extends ConsumerStatefulWidget {
  final String? roomId;
  const SpinWheelScreen({super.key, this.roomId});

  @override
  ConsumerState<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends ConsumerState<SpinWheelScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _pointerAngle = 0.0;
  int _countdown = 22;
  Timer? _timer;
  int _selectedWager = 10;
  int _todayProfits = 0;
  bool _isSpinning = false;
  int _currentSegment = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuart);
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_countdown > 0) {
            _countdown--;
          } else if (!_isSpinning) {
            _handleSpin();
            _countdown = 22;
          }
        });
      }
    });
  }

  void _handleSpin() async {
    final settings = ref.read(gameSettingsProvider).value;
    if (settings == null || !settings['isActive'] || _isSpinning) return;

    final balance = ref.read(walletBalanceProvider).value?['diamonds'] ?? 0;
    if (balance < _selectedWager) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient diamonds")));
       return;
    }

    setState(() => _isSpinning = true);

    try {
      final result = await ref.read(gameServiceProvider).playSpinWheel(
        betAmount: _selectedWager,
        roomId: widget.roomId,
      );
      
      final prize = result['prize'] as int;
      final label = result['label'] as String;

      // Map backend label to segment index (based on backend outcomes array order)
      // outcomes order: 0x, 1.1x, 1.5x, 2x, 0.5x, 5x, 0.1x, 20x
      final List<String> backendLabels = ["0x", "1.1x", "1.5x", "2x", "0.5x", "5x", "0.1x", "20x"];
      final targetIdx = backendLabels.indexOf(label);
      if (targetIdx == -1) throw Exception("Invalid outcome from server");

      final targetAngle = targetIdx * (2 * math.pi / 8);
      final rounds = 8 + math.Random().nextInt(3);
      final totalRotation = (rounds * 2 * math.pi) + targetAngle;

      _controller.reset();
      _animation = Tween<double>(begin: _pointerAngle % (2 * math.pi), end: totalRotation)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

      _controller.addListener(() {
        final currentAngle = _animation.value % (2 * math.pi);
        final segment = ((currentAngle / (2 * math.pi / 8)).round()) % 8;
        if (segment != _currentSegment) setState(() => _currentSegment = segment);
      });

      await _controller.forward();
      
      setState(() {
        _pointerAngle = totalRotation;
        _isSpinning = false;
        _todayProfits += (prize - _selectedWager);
      });

      final segmentsMap = (settings['segments'] as List);
      final winningItem = SpinItem(
        name: segmentsMap[targetIdx]['name'], 
        multiplier: (prize / _selectedWager).round(), 
        emoji: segmentsMap[targetIdx]['emoji']
      );
      
      _showWinBanner(winningItem, prize);

    } catch (e) {
      setState(() => _isSpinning = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showWinBanner(SpinItem item, int amount) {
    showGeneralDialog(
      context: context, barrierDismissible: true, barrierLabel: "Win", barrierColor: Colors.black45, transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 320, padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.5), blurRadius: 30, spreadRadius: 5)],
              border: Border.all(color: Colors.white70, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(alignment: Alignment.center, children: [const Icon(Icons.stars_rounded, color: Colors.white30, size: 100), Text(item.emoji, style: const TextStyle(fontSize: 60))]),
                const SizedBox(height: 12),
                const Text("CONGRATULATIONS!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 1)),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(15)), child: Text("WIN $amount COINS", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                const SizedBox(height: 20),
                GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]), child: const Text("RECEIVE", style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold, fontSize: 16)))),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (context, anim1, anim2, child) => ScaleTransition(scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack), child: FadeTransition(opacity: anim1, child: child)),
    );
  }

  void _showRulesSheet(Map<String, dynamic> settings) {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF0F172A), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Text("GAME RULES", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
            const SizedBox(height: 24),
            _ruleItem("1. Select wager (min: ${settings['minWager']}, max: ${settings['maxWager']})."),
            _ruleItem("2. Tap the central countdown to spin."),
            _ruleItem("3. Landing on an icon grants its multiplier payout."),
            _ruleItem("4. Max win limit: ${settings['maxWinCap']} diamonds."),
            _ruleItem("5. Daily profit limit per user applies."),
            const SizedBox(height: 32),
            Center(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFACC15), foregroundColor: Colors.black, shape: StadiumBorder(), padding: EdgeInsets.symmetric(horizontal: 60)), child: const Text("GOT IT"))),
          ],
        ),
      ),
    );
  }

  Widget _ruleItem(String text) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)));

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(walletBalanceProvider);
    final settingsAsync = ref.watch(gameSettingsProvider);
    final statsAsync = ref.watch(luckySpinStatsProvider);
    final historyAsync = ref.watch(userGameHistoryProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: settingsAsync.when(
        data: (settings) {
          if (!settings['isActive']) return _buildMaintenanceScreen();

          final segmentsMap = (settings['segments'] as List);
          final items = segmentsMap.map((s) => SpinItem(name: s['name'], multiplier: s['multiplier'], emoji: s['emoji'])).toList();

          return Stack(
            children: [
              // 1. Background Image
              Positioned.fill(
                child: Image.asset(
                  'assets/images/spin_bg.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFFDE047)),
                ),
              ),

              // 2. Header Elements
              _buildHeader(settings, statsAsync.value?['currentRound'] ?? 0),

              // 3. Main Circular Game
              Align(
                alignment: const Alignment(0, -0.25),
                child: SizedBox(
                  width: 320, height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 280, height: 280,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(size: const Size(280, 280), painter: PodsPainter(items: items, activeIndex: _currentSegment)),
                            AnimatedBuilder(
                              animation: _animation,
                              builder: (context, child) => CustomPaint(size: const Size(280, 280), painter: GlowPointerPainter(angle: _animation.value)),
                            ),
                            Positioned(
                              child: GestureDetector(
                                onTap: _isSpinning ? null : _handleSpin,
                                child: Container(
                                  width: 94, height: 94,
                                  decoration: BoxDecoration(color: const Color(0xFFEF4444), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFFD700), width: 3.5)),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text("Select time", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      Text("${_countdown}s", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                                    ],
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

              // 4. Betting Section
              _buildBettingSection(),

              // 5. Result History
              _buildResultHistory(historyAsync.value ?? []),

              // 6. Bottom Red Bar
              _buildBottomBar(balanceAsync.value?['diamonds'] ?? 0),

              // 7. Footer text
              _buildFooterText(),
              
              Positioned(
                top: 40, left: 10,
                child: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22), onPressed: () => Navigator.pop(context)),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> settings, int currentRound) {
    return Positioned(
      top: 50, left: 20, right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Today's $currentRound Round", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
          GestureDetector(
            onTap: () => _showRulesSheet(settings),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: const Text("Rules >", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBettingSection() {
    return Positioned(
      bottom: 183, left: 0, right: 0,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stars, color: Colors.amber, size: 14),
              const Text(" 7 = ", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              const Icon(Icons.diamond, color: Colors.cyan, size: 14),
              const Text(" 2", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChip(10, Colors.red, true),
              const SizedBox(width: 10),
              _buildChip(50, const Color(0xFFFFD700), false),
              const SizedBox(width: 10),
              _buildChip(100, const Color(0xFFFFD700), false),
              const SizedBox(width: 10),
              _buildChip(1000, const Color(0xFFFFD700), false),
            ],
          ),
        ],
      ),
    );
  }

 Widget _buildChip(int value, Color color, bool isRed) {
  bool isSelected = _selectedWager == value;

  return GestureDetector(
    onTap: () => setState(() => _selectedWager = value),
    child: Container(
      width: 60,                    // Compact square size
      height: 60,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),   // 12 radius as requested
        border: Border.all(
          color: isSelected ? Colors.white : Colors.black26,
          width: isSelected ? 3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isRed)
              const Icon(Icons.stars, color: Colors.amber, size: 18),
            Text(
              value.toString(),
              style: TextStyle(
                color: isRed ? Colors.white : Colors.brown[900],
                fontWeight: FontWeight.w900,
                fontSize: 16,           // Slightly bigger for better visibility
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildResultHistory(List<Map<String, dynamic>> history) {
    final settings = ref.read(gameSettingsProvider).value;
    final segments = settings?['segments'] as List? ?? [];
    
    return Positioned(
      bottom: 125, left: 0, right: 0,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: const BoxDecoration(color: Colors.red, borderRadius: BorderRadius.only(topRight: Radius.circular(10), bottomRight: Radius.circular(10))),
            child: const Text("Result", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: history.map((rec) {
                  final label = rec['label'] as String? ?? "0x";
                  final segment = segments.firstWhere((s) => "${s['multiplier']}x" == label || s['multiplier'].toString() == label.replaceAll('x',''), orElse: () => null);
                  final emoji = segment?['emoji'] ?? '🎡';
                  bool isNew = history.indexOf(rec) == 0;
                  
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(emoji, style: const TextStyle(fontSize: 20)),
                      ),
                      if (isNew) Positioned(
                        top: -5, right: -5,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: Colors.yellow, borderRadius: BorderRadius.circular(4)),
                          child: const Text("New", style: TextStyle(color: Colors.black, fontSize: 6, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(int balance) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        height: 120, width: double.infinity, 
        color: const Color(0xFFEF4444), 
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: 45, left: 16, right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildBalanceBox(Icons.stars, Colors.amber, "Sisa Koin", balance.toString()),
                  _buildBalanceBox(Icons.diamond, Colors.cyan, "Keuntungan Hari ini", _todayProfits.toString()),
                ],
              ),
            ),
            const Positioned(
              bottom: 20,
              child: Text("Catatan saya >", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceBox(IconData icon, Color iconColor, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.black54, fontSize: 8, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900, height: 1.1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterText() {
    return const SizedBox.shrink(); // Integrated into _buildBottomBar
  }

  Widget _buildMaintenanceScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.build_circle, color: Colors.brown, size: 80),
          const SizedBox(height: 16),
          const Text("GAME UNAVAILABLE", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.w900, fontSize: 24)),
        ],
      ),
    );
  }
}

class SpinItem {
  final String name; final int multiplier; final String emoji;
  SpinItem({required this.name, required this.multiplier, required this.emoji});
}

class PodsPainter extends CustomPainter {
  final List<SpinItem> items; final int activeIndex;
  PodsPainter({required this.items, required this.activeIndex});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2); 
    final radius = 125.0; 
    for (int i = 0; i < items.length; i++) {
        final angle = i * (2 * math.pi / 8) - (math.pi / 2);
        final podCenter = Offset(center.dx + math.cos(angle) * radius, center.dy + math.sin(angle) * radius);
        TextPainter(text: TextSpan(text: items[i].emoji, style: const TextStyle(fontSize: 22)), textDirection: TextDirection.ltr)..layout()..paint(canvas, podCenter - const Offset(11, 24));
        TextPainter(text: TextSpan(text: "win ${items[i].multiplier}x", style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout()..paint(canvas, podCenter - const Offset(18, -12));
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GlowPointerPainter extends CustomPainter {
  final double angle;
  GlowPointerPainter({required this.angle});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2); 
    final radius = 125.0; 
    final segmentAngleStep = 2 * math.pi / 8;
    final snappedAngle = (angle / segmentAngleStep).floor() * segmentAngleStep - (math.pi / 2);
    final lightPos = Offset(center.dx + math.cos(snappedAngle) * radius, center.dy + math.sin(snappedAngle) * radius);
    
    // Outer golden glow
    canvas.drawCircle(lightPos, 45, Paint()..color = const Color(0xFFFFD700).withOpacity(0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    // Inner white highlight (main focused light)
    canvas.drawCircle(lightPos, 38, Paint()..color = Colors.white.withOpacity(0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}