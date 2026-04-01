import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/providers/wallet_provider.dart';
import 'package:hello_chat/providers/game_provider.dart';
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
  int? _localBalance;
  bool _isSpinning = false;
  int _currentSegment = 0;
  final List<Map<String, dynamic>> _spinHistory = [];

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

  void _handleSpin() {
    final settings = ref.read(gameSettingsProvider).value;
    if (settings == null || !settings['isActive'] || _isSpinning) return;

    setState(() {
      _isSpinning = true;
      if (_localBalance != null) _localBalance = _localBalance! - _selectedWager;
    });

    final segmentsMap = (settings['segments'] as List);
    final List<SpinItem> items = segmentsMap.map((s) => SpinItem(name: s['name'], multiplier: s['multiplier'], emoji: s['emoji'])).toList();
    final List<int> weights = segmentsMap.map((s) => (s['weight'] as num).toInt()).toList();

    final totalWeight = weights.reduce((a, b) => a + b);
    double randomPoint = math.Random().nextInt(totalWeight).toDouble();
    int randomIdx = 0;
    for (int i = 0; i < weights.length; i++) {
        if (randomPoint < weights[i]) { randomIdx = i; break; }
        randomPoint -= weights[i];
    }
    
    final targetItem = items[randomIdx];
    final targetAngle = randomIdx * (2 * math.pi / 8);
    final rounds = 8 + math.Random().nextInt(5);
    final totalRotation = (rounds * 2 * math.pi) + targetAngle;

    _controller.reset();
    _animation = Tween<double>(begin: _pointerAngle % (2 * math.pi), end: totalRotation)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.addListener(() {
      final currentAngle = _animation.value % (2 * math.pi);
      final segment = ((currentAngle / (2 * math.pi / 8)).round()) % 8;
      if (segment != _currentSegment) setState(() => _currentSegment = segment);
    });

    _controller.forward().then((_) {
      final int winAmountRaw = _selectedWager * (targetItem.multiplier as num).toInt();
      final int winCap = (settings['maxWinCap'] as num?)?.toInt() ?? 50000;
      final int winAmount = math.min(winAmountRaw, winCap);

      setState(() {
        _pointerAngle = totalRotation;
        _isSpinning = false;
        _todayProfits += (winAmount - _selectedWager);
        if (_localBalance != null) {
           _localBalance = _localBalance! + winAmount;
        }
        _spinHistory.insert(0, {'item': targetItem, 'wager': _selectedWager, 'win': winAmount, 'time': DateTime.now()});
      });
      _showWinBanner(targetItem, winAmount);
    });
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

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF0F172A), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("MY RECORD", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_spinHistory.isEmpty) const Expanded(child: Center(child: Text("No records found", style: TextStyle(color: Colors.white54))))
            else Expanded(
              child: ListView.builder(
                itemCount: _spinHistory.length,
                itemBuilder: (context, i) {
                  final rec = _spinHistory[i];
                  return ListTile(
                    leading: Text(rec['item'].emoji, style: const TextStyle(fontSize: 24)),
                    title: Text("Won ${rec['win']} Coins", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text("Bet: ${rec['wager']} Diamonds", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    trailing: Text("${rec['time'].hour}:${rec['time'].minute}", style: const TextStyle(color: Colors.white24, fontSize: 10)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRankingSheet() {
    final mockRanking = [
      {'name': 'King_Player', 'win': 142000, 'avatar': '👑'},
      {'name': 'SpinMaster', 'win': 98500, 'avatar': '💎'},
      {'name': 'LuckyCharm', 'win': 76200, 'avatar': '🍀'},
    ];
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF0F172A), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("DAILY RANKING", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(child: ListView.builder(itemCount: mockRanking.length, itemBuilder: (context, i) {
              final player = mockRanking[i];
              return ListTile(leading: Text(player['avatar'].toString(), style: const TextStyle(fontSize: 24)), title: Text(player['name'].toString(), style: const TextStyle(color: Colors.white)), trailing: Text("${player['win']} Coins", style: const TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.w900)));
            })),
          ],
        ),
      ),
    );
  }

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

    balanceAsync.whenData((balance) {
      if (_localBalance == null) _localBalance = balance['diamonds'] ?? 0;
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.brown, size: 22),
            onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.brown, size: 26),
              onPressed: () => settingsAsync.whenData((s) => _showRulesSheet(s)))
        ],
      ),
      body: settingsAsync.when(
        data: (settings) {
          if (!settings['isActive']) return _buildMaintenanceScreen();

          final segmentsMap = (settings['segments'] as List);
          final items = segmentsMap.map((s) => SpinItem(name: s['name'], multiplier: s['multiplier'], emoji: s['emoji'])).toList();

          return Stack(
            children: [
              // 1. Ferris Wheel Frame Background
              Positioned.fill(
                child: Image.asset(
                  'assets/images/spin_bg.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFFDE047)),
                ),
              ),

              // 2. Main Game Content
              Align(
                alignment: const Alignment(0, -0.25), // Increased top spacing by shifting alignment down
                child: SizedBox(
                  width: 320,
                  height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // The Spinning Wheel
                      SizedBox(
                        width: 280,
                        height: 280,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 1. Pods (Static in background cabins)
                            CustomPaint(
                              size: const Size(280, 280),
                              painter: PodsPainter(items: items, activeIndex: _currentSegment),
                            ),

                            // 2. Revolving Light (The actual selector)
                            AnimatedBuilder(
                              animation: _animation,
                              builder: (context, child) => CustomPaint(
                                size: const Size(280, 280),
                                painter: GlowPointerPainter(angle: _animation.value),
                              ),
                            ),

                            // 3. Center Red Button with Countdown
                            Positioned(
                              child: GestureDetector(
                                onTap: _handleSpin,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFFFD700), width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.4),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        "Select time",
                                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        "${_countdown}s",
                                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                      ),
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
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
      ),
    );
  }

  Widget _buildMaintenanceScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.build_circle, color: Colors.brown, size: 80),
          const SizedBox(height: 16),
          const Text("GAME UNAVAILABLE", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.w900, fontSize: 24)),
          const SizedBox(height: 8),
          const Text("Admin has temporarily disabled this game.", style: TextStyle(color: Colors.brown, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMultipliersRow(List<SpinItem> items) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(item.emoji, style: const TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(height: 4),
                    Text("${item.multiplier}x", style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              )).toList(),
        ),
      );

  Widget _buildScoreBoard() {
    return Row( children: [ Expanded(child: _scoreCard("Coins left", (_localBalance ?? 0).toString(), const Color(0xFFFACC15))), const SizedBox(width: 12), Expanded(child: _scoreCard("Today's profits", _todayProfits.toString(), const Color(0xFF2DD4BF))) ]);
  }

  Widget _scoreCard(String label, String value, Color color) {
    return Container( padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)), const SizedBox(height: 2), Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)) ] ));
  }

  Widget _buildWagerRow(Map<String, dynamic> settings) {
    final wagers = [10, 50, 100, 5000];
    return Row( mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: wagers.map((w) => _wagerChip(w)).toList() );
  }

  Widget _wagerChip(int amount) {
    bool isSelected = _selectedWager == amount;
    return GestureDetector( onTap: () => setState(() => _selectedWager = amount), child: AnimatedContainer( duration: const Duration(milliseconds: 200), width: 62, height: 62, decoration: BoxDecoration(color: isSelected ? const Color(0xFFFACC15) : Colors.white.withOpacity(0.05), shape: BoxShape.circle, border: Border.all(color: isSelected ? Colors.white : Colors.white12, width: 2)), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.stars, color: isSelected ? Colors.brown : Colors.amber, size: 14), Text(amount.toString(), style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)) ] )));
  }

  Widget _buildActionButtons() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [ GestureDetector(onTap: _showHistorySheet, child: _miniAction(Icons.history_rounded, "My Record")), GestureDetector(onTap: _showRankingSheet, child: _miniAction(Icons.emoji_events_rounded, "Ranking")), GestureDetector(onTap: () => ref.read(gameSettingsProvider).whenData((s) => _showRulesSheet(s)), child: _miniAction(Icons.info_outline_rounded, "Rules")) ]);
  }

  Widget _miniAction(IconData icon, String text) {
    return Column( children: [ Icon(icon, color: Colors.white24, size: 20), const SizedBox(height: 4), Text(text, style: const TextStyle(color: Colors.white24, fontSize: 9)) ]);
  }
}

class SpinItem {
  final String name; final int multiplier; final String emoji;
  SpinItem({required this.name, required this.multiplier, required this.emoji});
}

class WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2); final radius = size.width / 2 - 20;
    final wheelPaint = Paint()..color = const Color(0xFFFACC15)..strokeWidth = 3..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, wheelPaint);
    final spokePaint = Paint()..color = const Color(0xFFFACC15).withOpacity(0.4)..strokeWidth = 2;
    for (int i = 0; i < 8; i++) {
       final angle = i * (2 * math.pi / 8) - (math.pi / 2);
       canvas.drawLine(center, Offset(center.dx + math.cos(angle) * (radius - 10), center.dy + math.sin(angle) * (radius - 10)), spokePaint);
    }
    canvas.drawCircle(center, 35, Paint()..color = const Color(0xFFFDE047));
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PodsPainter extends CustomPainter {
  final List<SpinItem> items; final int activeIndex;
  PodsPainter({required this.items, required this.activeIndex});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2); 
    final radius = 125.0; // Optimized radius for 280x280 frame area
    
    for (int i = 0; i < items.length; i++) {
        final angle = i * (2 * math.pi / 8) - (math.pi / 2);
        final podCenter = Offset(center.dx + math.cos(angle) * radius, center.dy + math.sin(angle) * radius);
        
        TextPainter(
          text: TextSpan(text: items[i].emoji, style: const TextStyle(fontSize: 22)), 
          textDirection: TextDirection.ltr
        )..layout()..paint(canvas, podCenter - const Offset(11, 24));
        
        TextPainter(
          text: TextSpan(
            text: "win ${items[i].multiplier}x", 
            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)
          ), 
          textDirection: TextDirection.ltr
        )..layout()..paint(canvas, podCenter - const Offset(18, -12));
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
    canvas.drawCircle(lightPos, 42, Paint()..color = const Color(0xFFFFD700).withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    // Inner white highlight
    canvas.drawCircle(lightPos, 35, Paint()..color = Colors.white.withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    // Sharp border stroke
    canvas.drawCircle(lightPos, 34, Paint()..color = Colors.white.withOpacity(0.8)..style = PaintingStyle.stroke..strokeWidth = 2);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SupportPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final basePath = Path()
      ..moveTo(30, size.height - 40)
      ..lineTo(size.width - 30, size.height - 40)
      ..lineTo(size.width - 10, size.height - 10)
      ..lineTo(10, size.height - 10)
      ..close();
    canvas.drawPath(basePath, Paint()..color = const Color(0xFF3B82F6));

    _drawStripedLeg(canvas, Offset(center.dx - 55, size.height - 45), -0.18);
    _drawStripedLeg(canvas, Offset(center.dx + 55, size.height - 45), 0.18);
  }

  void _drawStripedLeg(Canvas canvas, Offset start, double angle) {
    final path = Path()
      ..moveTo(start.dx - 18, start.dy)
      ..lineTo(start.dx + 18, start.dy)
      ..lineTo(start.dx + (angle * 90), start.dy - 145)
      ..lineTo(start.dx + (angle * 90) - 20, start.dy - 145)
      ..close();

    canvas.drawPath(path, Paint()..color = const Color(0xFF2563EB));

    canvas.save();
    canvas.clipPath(path);
    final stripePaint = Paint()..color = const Color(0xFFFDE047)..strokeWidth = 10;
    for (int i = 0; i < 12; i++) {
      canvas.drawLine(
        Offset(start.dx - 60, start.dy - (i * 26)),
        Offset(start.dx + 80, start.dy - (i * 26) - 20),
        stripePaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}