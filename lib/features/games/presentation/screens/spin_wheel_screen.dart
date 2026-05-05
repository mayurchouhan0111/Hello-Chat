import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hello_chat/core/widgets/premium_diamond.dart';
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
  int _countdown = 30;
  Timer? _timer;
  int _currentSegment = 0;
  Map<String, int> _currentBets = {};
  Map<String, int> _betClickCounts = {};
  String? _focusedIcon;
  String? _lastResultType;
  int _selectedChipValue = 10;
  int _todayProfits = 0;
  bool _isSpinning = false;
  bool _isBetLocked = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuart);
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final secondsIntoCycle = (now % 30000) ~/ 1000;
        final newCountdown = 30 - secondsIntoCycle;

        if (newCountdown != _countdown) {
          setState(() {
            _countdown = newCountdown;
            // Lock bets in the last 5 seconds
            if (_countdown <= 5 && !_isBetLocked) {
              _isBetLocked = true;
            }
            // Trigger spin automatically when global timer hits 0
            if (_countdown == 30 && !_isSpinning) {
              _handleSpin();
            }
          });
        }
      }
    });
  }

  void _handleSpin() async {
    final settings = ref.read(gameSettingsProvider).value;
    if (settings == null || !settings['isActive'] || _isSpinning) return;
    
    // Timer is now global, DO NOT cancel it
    final segmentsMap = (settings['segments'] as List);
    final wallet = ref.read(walletBalanceProvider).value;
    final diamonds = wallet?['diamonds'] ?? 0;
    final beans = wallet?['beans'] ?? 0;

    final totalBet = _currentBets.values.fold(0, (sum, val) => sum + val);

    // Total playing power check
    if (totalBet > 0) {
      final totalPlayingPower = diamonds + (beans * 2 / 7).floor();
      if (totalPlayingPower < totalBet) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient Diamonds & Stars")));
         return;
      }
    }

    setState(() {
      _isSpinning = true;
      _isBetLocked = true;
    });

    try {
      final result = await ref.read(gameServiceProvider).playSpinWheel(
        betAmount: totalBet, // Keeping for backward compatibility
        bets: _currentBets,  // New multi-bet structure
        roomId: widget.roomId,
      );
      
      final prize = (result['prize'] as num?)?.toInt() ?? 0;
      final label = result['label'] as String? ?? "0x";
      final type = result['type'] as String? ?? "standard";
      _lastResultType = type;

      int targetIdx = segmentsMap.indexWhere((s) {
        final mStr = s['multiplier'].toString().toLowerCase().replaceAll('x', '').trim();
        final nameStr = (s['name'] ?? "").toString().toLowerCase().replaceAll('x', '').trim();
        final labelStr = label.toLowerCase().replaceAll('x', '').trim();
        return mStr == labelStr || nameStr == labelStr;
      });

      if (targetIdx == -1) {
        targetIdx = math.Random().nextInt(segmentsMap.length.clamp(1, 8));
      }

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
        _todayProfits += (prize - totalBet);
      });

      // Refresh backend data
      ref.invalidate(walletBalanceProvider);
      ref.invalidate(userGameHistoryProvider);
      ref.invalidate(luckySpinStatsProvider);

      final winningItem = SpinItem(
        name: segmentsMap[targetIdx]['name'], 
        multiplier: totalBet > 0 ? (prize / totalBet).round() : 0, 
        emoji: segmentsMap[targetIdx]['emoji'],
        category: segmentsMap[targetIdx]['category']
      );
      
      _showWinBanner(winningItem, prize, type);

      // 2. Clear state for next round
      setState(() {
        _currentBets = {};
        _betClickCounts = {};
        _isBetLocked = false;
        _isSpinning = false;
      });

    } catch (e) {
      setState(() {
        _isSpinning = false;
        _isBetLocked = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showWinBanner(SpinItem item, int amount, String type) {
    final isSalad = type == 'salad';
    final isPizza = type == 'pizza';
    final title = isSalad ? "SALAD HIT!" : (isPizza ? "PIZZA HIT!" : "CONGRATULATIONS!");
    final color1 = isSalad ? const Color(0xFF22C55E) : (isPizza ? const Color(0xFFEF4444) : const Color(0xFFFFD700));
    final color2 = isSalad ? const Color(0xFF166534) : (isPizza ? const Color(0xFF991B1B) : const Color(0xFFFF8C00));

    showGeneralDialog(
      context: context, barrierDismissible: true, barrierLabel: "Win", barrierColor: Colors.black45, transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 320, padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color1, color2], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: color1.withOpacity(0.5), blurRadius: 30, spreadRadius: 5)],
              border: Border.all(color: Colors.white70, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(alignment: Alignment.center, children: [Icon(isSalad ? Icons.eco : (isPizza ? Icons.local_pizza : Icons.stars_rounded), color: Colors.white30, size: 100), Text(item.emoji, style: const TextStyle(fontSize: 60))]),
                const SizedBox(height: 12),
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 1)),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(15)), child: Text("WIN $amount COINS", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                const SizedBox(height: 20),
                GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]), child: Text("RECEIVE", style: TextStyle(color: color2, fontWeight: FontWeight.bold, fontSize: 16)))),
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
      backgroundColor: const Color(0xFFFDE047),
      extendBodyBehindAppBar: true,
      body: settingsAsync.when(
        data: (settings) {
          if (!settings['isActive']) return _buildMaintenanceScreen();

          final segmentsMap = (settings['segments'] as List);
          final items = segmentsMap.map((s) => SpinItem(
            name: s['name'], 
            multiplier: (s['multiplier'] as num).toInt(), 
            emoji: s['emoji'],
            category: s['category']
          )).toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final scale = constraints.maxWidth / 375;
              
              return Stack(
                children: [
              // 1. Background Image
               Positioned.fill(
                child: Image.asset(
                  'assets/images/processed_image.webp',
                  fit: BoxFit.fill,
                  errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFFDE047)),
                ),
              ),

              // 2. Header Elements
              _buildHeader(settings, statsAsync.value?['currentRound'] ?? 0, scale),

              // 3. Main Circular Game
              Align(
                alignment: const Alignment(0, -0.55),
                child: SizedBox(
                  width: 360 * scale, height: 420 * scale,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 360 * scale, height: 420 * scale,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            CustomPaint(
                              size: Size(360 * scale, 420 * scale), 
                              painter: PodsPainter(
                                items: items, 
                                activeIndex: _currentSegment, 
                                betClickCounts: _betClickCounts,
                                scale: scale,
                                saladHits: statsAsync.value?['todaySaladHits'] ?? 0,
                                pizzaHits: statsAsync.value?['todayPizzaHits'] ?? 0,
                              ),
                            ),
                            
                            // Salad & Pizza Buttons (Positioned lower with negative offset)
                            Positioned(
                              bottom: -29 * scale,
                              left: 30 * scale,
                              child: _buildJackpotTab("Salad", "🥗", scale),
                            ),
                            Positioned(
                              bottom: -29 * scale,
                              right: 30 * scale,
                              child: _buildJackpotTab("Pizza", "🍕", scale),
                            ),
                            
                            // Interactive Betting Pods (Shifted center to 180, 210)
                            ...List.generate(items.length, (index) {
                              final angle = index * (2 * math.pi / 8) - (math.pi / 2);
                              const radiusX = 135.0;
                              const radiusY = 156.0;
                              final podX = math.cos(angle) * radiusX * scale;
                              final podY = math.sin(angle) * radiusY * scale;
                              final name = items[index].name;
                              final bet = _currentBets[name] ?? 0;

                              return Positioned(
                                left: (180 * scale) + podX - (35 * scale),
                                top: (210 * scale) + podY - (40 * scale),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _isBetLocked ? null : () {
                                    setState(() {
                                      _currentBets[name] = (_currentBets[name] ?? 0) + _selectedChipValue;
                                      _betClickCounts[name] = (_betClickCounts[name] ?? 0) + 1;
                                    });
                                  },
                                  child: Container(
                                    width: 70 * scale, height: 80 * scale,
                                    color: Colors.transparent, // Hit area
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (bet > 0)
                                          Positioned(
                                            top: 0,
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
                                              decoration: BoxDecoration(
                                                color: Colors.amber,
                                                borderRadius: BorderRadius.circular(10 * scale),
                                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                              ),
                                              child: Text(
                                                bet >= 1000 ? "${(bet/1000).toStringAsFixed(1)}k" : bet.toString(),
                                                style: TextStyle(color: Colors.black, fontSize: 10 * scale, fontWeight: FontWeight.w900),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),

                            IgnorePointer(
                              child: AnimatedBuilder(
                                animation: _animation,
                                builder: (context, child) => CustomPaint(size: Size(360 * scale, 420 * scale), painter: GlowPointerPainter(angle: _animation.value, scale: scale)),
                              ),
                            ),
                            Positioned(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // White Hub
                                  Container(
                                    width: 120 * scale, height: 120 * scale,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.transparent),
                                      boxShadow: const [],
                                    ),
                                    child: Center(
                                      child: Padding(
                                        padding: EdgeInsets.only(bottom: 25 * scale),
                                        child: Text("🐼", style: TextStyle(fontSize: 65 * scale)),
                                      ),
                                    ),
                                  ),
                                  // Select Time Banner
                                  Positioned(
                                    bottom: 0,
                                    child: Container(
                                      width: 90 * scale,
                                      padding: EdgeInsets.symmetric(vertical: 2 * scale),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(10 * scale),
                                        border: Border.all(color: Colors.transparent),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text("Select time", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9 * scale)),
                                          Text("${_countdown}s", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14 * scale)),
                                        ],
                                      ),
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
                ),
              ),

              // 4. Betting Section
              _buildBettingSection(settings, scale, statsAsync.value),

              if (_countdown <= 5 && !_isSpinning)
                IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(15)),
                      child: const Text("BETS CLOSED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
                    ),
                  ),
                ),

              // 5. Bottom Panel (Includes History & Balance) - Moved to TOP of Z-order
              _buildBottomPanel(
                balanceAsync.value?['diamonds'] ?? 0, 
                historyAsync.value ?? [],
                statsAsync.value,
                scale,
              ),
              
              Positioned(
                top: 40, left: 10,
                child: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22), onPressed: () => Navigator.pop(context)),
              ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> settings, int currentRound, double scale) {
    return Positioned(
      top: 70 * scale, left: 20 * scale, right: 20 * scale,
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

  Widget _buildBettingSection(Map<String, dynamic> settings, double scale, Map<String, dynamic>? stats) {
    final segments = (settings['segments'] as List);
    final saladHits = stats?['todaySaladHits'] ?? 0;
    final pizzaHits = stats?['todayPizzaHits'] ?? 0;
    
    return Positioned(
      bottom: 197 * scale, left: 10 * scale, right: 10 * scale,
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(bottom: 12 * scale),
            padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10 * scale)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 14 * scale),
                SizedBox(width: 4 * scale),
                Text("7 = 2", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 12 * scale)),
              ],
            ),
          ),
          SizedBox(height: 12 * scale),
          // Chip Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChip(10, const Color(0xFFFFD700), scale),
              SizedBox(width: 16 * scale),
              _buildChip(50, const Color(0xFFFFD700), scale),
              SizedBox(width: 24 * scale),
              _buildChip(100, const Color(0xFFFFD700), scale),
              SizedBox(width: 16 * scale),
              _buildChip(1000, const Color(0xFFFFD700), scale),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJackpotTab(String label, String emoji, double scale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56 * scale, height: 56 * scale,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFD700), width: 3 * scale),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8 * scale, offset: const Offset(0, 3))],
          ),
          child: Center(child: Text(emoji, style: TextStyle(fontSize: 32 * scale))),
        ),
        Transform.translate(
          offset: Offset(0, -3 * scale),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4 * scale),
              border: Border.all(color: Colors.transparent),
              boxShadow: const [],
            ),
            child: Text("$label >", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10 * scale, letterSpacing: 0.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(int value, Color color, double scale) {
  bool isSelected = _selectedChipValue == value;

  return GestureDetector(
    onTap: () => setState(() => _selectedChipValue = value),
    child: Container(
      width: 64 * scale,
      height: 64 * scale,
      decoration: BoxDecoration(
        color: isSelected ? Colors.red : color,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(
          color: isSelected ? Colors.white : Colors.black26,
          width: isSelected ? 3 * scale : 1 * scale,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 8 * scale,
            offset: Offset(0, 4 * scale),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected)
              Icon(Icons.stars, color: Colors.amber, size: 18 * scale),
            Text(
              value >= 1000 ? "${(value / 1000).floor()}k" : value.toString(),
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 14 * scale,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildResultBar(List<dynamic> history, double scale) {
    final settings = ref.read(gameSettingsProvider).value;
    final segments = settings?['segments'] as List? ?? [];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 2 * scale),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
      ),
      child: Row(
        children: [
          SizedBox(width: 16 * scale),
          Text("Result", style: TextStyle(color: Colors.black87, fontSize: 14 * scale, fontWeight: FontWeight.bold)),
          SizedBox(width: 12 * scale),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: history.map((rec) {
                  final emoji = rec['emoji'] ?? '🎡';
                  bool isNew = history.indexOf(rec) == 0;

                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 4 * scale),
                    width: 34 * scale, height: 34 * scale,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black45, width: 1),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Text(emoji, style: TextStyle(fontSize: 18 * scale)),
                        if (isNew)
                          Positioned(
                            bottom: -4 * scale,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 1 * scale),
                              decoration: BoxDecoration(
                                color: Colors.yellow,
                                borderRadius: BorderRadius.circular(4 * scale),
                                border: Border.all(color: Colors.black87, width: 1),
                              ),
                              child: Text("New", style: TextStyle(color: Colors.black, fontSize: 7 * scale, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(int balance, List<dynamic> history, Map<String, dynamic>? stats, double scale) {
    // Robust data extraction with fallbacks
    final todayWinners = stats?['todayWinners'] as List? ?? [];
    final topFromList = todayWinners.isNotEmpty ? todayWinners.first : null;
    final lastRound = stats?['lastRound'] as Map<String, dynamic>?;

    final topWinnerName = stats?['topWinnerName'] ?? topFromList?['name'] ?? "No data";
    final topWinnerAmount = stats?['topWinnerAmount'] ?? topFromList?['amount'] ?? 0;
    
    final lastWinnerName = stats?['lastWinnerName'] ?? lastRound?['winnerName'] ?? "None";
    final lastWinnerAmount = stats?['lastWinnerAmount'] ?? lastRound?['winnerAmount'] ?? 0;

    // Calculate Today's Stats from local history
    final now = DateTime.now();
    final todayHistory = history.where((h) {
      if (h['timestamp'] == null) return false;
      final ts = h['timestamp'] is Timestamp ? (h['timestamp'] as Timestamp).toDate() : DateTime.parse(h['timestamp'].toString());
      return ts.year == now.year && ts.month == now.month && ts.day == now.day;
    }).toList();
    
    final gamesPlayed = todayHistory.length;
    final wins = todayHistory.where((h) => (h['prize'] ?? 0) > 0).length;

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        height: 190 * scale,
        padding: EdgeInsets.only(top: 8 * scale, bottom: 8 * scale),
        decoration: const BoxDecoration(
          color: Color(0xFFE52E2E),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16 * scale),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => ref.invalidate(luckySpinStatsProvider),
                    child: _buildSwapButton(isRefresh: true, scale: scale),
                  ),
                  SizedBox(width: 8 * scale),
                  Expanded(
                    child: _buildBalanceBox(
                      null, // Use custom icon
                      Colors.orange, 
                      "Current Amount", 
                      balance.toString(), 
                      false,
                      scale,
                      customIcon: const PremiumDiamond(size: 12),
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20 * scale),
                        onTap: () {
                          ref.invalidate(userGameHistoryProvider);
                        },
                        child: _buildBalanceBox(
                          Icons.insights, 
                          Colors.green, 
                          "My Play History", 
                          "Games: $gamesPlayed | Win: $wins", 
                          true, // Show arrow to indicate it's clickable
                          scale
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8 * scale),
            _buildResultBar(history, scale),
            SizedBox(height: 8 * scale),
            
            // New Shifted Stats Row (Minimum Border Radius)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16 * scale),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showLeaderboardSheet(),
                      child: _buildBalanceBox(
                        Icons.emoji_events, 
                        Colors.amber, 
                        "Highest Diamond", 
                        "$topWinnerName: $topWinnerAmount", 
                        true,
                        scale,
                        borderRadius: 4 * scale
                      ),
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  Expanded(
                    child: _buildBalanceBox(
                      Icons.history, 
                      Colors.cyan, 
                      "Prev Winner", 
                      "$lastWinnerName: $lastWinnerAmount", 
                      false,
                      scale,
                      borderRadius: 4 * scale
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 8 * scale),
            GestureDetector(
              onTap: () {},
              child: Text(
                "Catatan saya >",
                style: TextStyle(color: Colors.black87, fontSize: 11 * scale, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwapButton({bool isRefresh = false, required double scale}) {
    return Container(
      padding: EdgeInsets.all(6 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black87, width: 1.5 * scale),
      ),
      child: Icon(
        isRefresh ? Icons.refresh : Icons.swap_horizontal_circle_outlined, 
        color: Colors.amber, 
        size: 24 * scale
      ),
    );
  }

  void _showLeaderboardSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final stats = ref.watch(luckySpinStatsProvider).value;
          final todayWinners = stats?['todayWinners'] as List? ?? [];
          
          return Container(
            padding: const EdgeInsets.all(24),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("TODAY'S HIGHEST", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                if (todayWinners.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("No winners yet today", style: TextStyle(color: Colors.white70)),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: todayWinners.length,
                      itemBuilder: (context, index) {
                        final w = todayWinners[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.amber.withOpacity(0.2), 
                                radius: 15, 
                                child: Text("${index + 1}", style: const TextStyle(color: Colors.amber, fontSize: 12))
                              ),
                              const SizedBox(width: 12),
                              Text(w['name'] ?? "Unknown", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                              const Spacer(),
                              Text("${w['amount'] ?? 0}", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber, 
                      foregroundColor: Colors.black,
                      shape: const StadiumBorder()
                    ),
                    child: const Text("CLOSE"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceBox(IconData? icon, Color iconColor, String label, String value, bool hasArrow, double scale, {double? borderRadius, Widget? customIcon}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius ?? 20 * scale),
        border: Border.all(color: Colors.black87, width: 1.2 * scale),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: Colors.black87, fontSize: 8 * scale, fontWeight: FontWeight.bold)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (customIcon != null) customIcon,
              if (customIcon == null && icon != null) Icon(icon, color: iconColor, size: 12 * scale),
              SizedBox(width: 4 * scale),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(color: Colors.black, fontSize: 10 * scale, fontWeight: FontWeight.w900),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasArrow) Icon(Icons.chevron_right, color: Colors.black54, size: 12 * scale),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterText() {
    return const SizedBox.shrink();
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
  final String name; final int multiplier; final String emoji; final String? category;
  SpinItem({required this.name, required this.multiplier, required this.emoji, this.category});
}

class PodsPainter extends CustomPainter {
  final List<SpinItem> items; final int activeIndex; final double scale;
  final int saladHits; final int pizzaHits;
  final Map<String, int> betClickCounts;
  PodsPainter({required this.items, required this.activeIndex, required this.betClickCounts, this.scale = 1.0, this.saladHits = 0, this.pizzaHits = 0});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2); 
    final radiusX = 135.0 * scale;
    final radiusY = 155.0 * scale;
    for (int i = 0; i < items.length; i++) {
        final angle = i * (2 * math.pi / 8) - (math.pi / 2);
        final podCenter = Offset(center.dx + math.cos(angle) * radiusX, center.dy + math.sin(angle) * radiusY);
        
        // 1. Transparent Pod (No Border)
        final podPaint = Paint()
          ..color = Colors.transparent
          ..style = PaintingStyle.fill;
        canvas.drawCircle(podCenter, 70 * scale, podPaint);

        // 4. Draw Emoji (Top)
        final emojiPainter = TextPainter(text: TextSpan(text: items[i].emoji, style: TextStyle(fontSize: 32 * scale)), textDirection: TextDirection.ltr)..layout();
        emojiPainter.paint(canvas, podCenter - Offset(emojiPainter.width / 2, 25 * scale));

        // 5. Draw Win Label (Bottom)
        final labelPainter = TextPainter(
          text: TextSpan(
            text: "win ${items[i].multiplier} times", 
            style: TextStyle(color: Colors.black, fontSize: 9 * scale, fontWeight: FontWeight.w900)
          ), 
          textDirection: TextDirection.ltr
        )..layout();
        labelPainter.paint(canvas, podCenter - Offset(labelPainter.width / 2, -15 * scale));

        // 6. Draw Coin Icons (Dynamic based on Clicks)
        final clickCount = betClickCounts[items[i].name] ?? 0;
        if (clickCount > 0) {
          final coinsPainter = TextPainter(
            text: TextSpan(
              text: "🪙" * clickCount.clamp(1, 3), // Max 3 coins
              style: TextStyle(fontSize: 10 * scale)
            ), 
            textDirection: TextDirection.ltr
          )..layout();
          coinsPainter.paint(canvas, podCenter - Offset(coinsPainter.width / 2, -25 * scale));
        }

        // Sold Out Overlay
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GlowPointerPainter extends CustomPainter {
  final double angle; final double scale;
  GlowPointerPainter({required this.angle, this.scale = 1.0});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2); 
    final radiusX = 130.0 * scale;
    final radiusY = 148.0 * scale;
    final segmentAngleStep = 2 * math.pi / 8;
    final snappedAngle = (angle / segmentAngleStep).floor() * segmentAngleStep - (math.pi / 2);
    final lightPos = Offset(center.dx + math.cos(snappedAngle) * radiusX, center.dy + math.sin(snappedAngle) * radiusY);
    
    // Outer golden glow
    canvas.drawCircle(lightPos, 45 * scale, Paint()..color = const Color(0xFFFFD700).withOpacity(0.35)..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * scale));
    // Inner white highlight (main focused light)
    canvas.drawCircle(lightPos, 38 * scale, Paint()..color = Colors.white.withOpacity(0.5)..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * scale));
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}