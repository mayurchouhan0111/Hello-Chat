import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'dart:math' as math;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/game_provider.dart';
import '../../../../core/providers/profile_provider.dart';

class SpinWheelScreen extends ConsumerStatefulWidget {
  final String roomId;
  const SpinWheelScreen({super.key, required this.roomId});

  @override
  ConsumerState<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends ConsumerState<SpinWheelScreen> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  int _selectedBet = 10;
  final List<int> _betOptions = [10, 50, 100, 500];
  bool _isSpinning = false;
  double _currentRotation = 0.0;
  
  final List<String> _labels = ["0x", "1.2x", "1.5x", "2x", "0.5x", "5x", "0.2x", "10x"];
  
  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _spin() async {
    if (_isSpinning) return;
    
    setState(() => _isSpinning = true);

    try {
      // 1. Call Secure Cloud Logic
      await ref.read(gameActionProvider.notifier).playSpinWheel(_selectedBet);
      
      final result = ref.read(gameActionProvider).asData?.value;
      if (result == null) throw Exception("Failed to get result");

      // 2. Calculate target angle
      // Note: Rotation is reversed for "Ferris Wheel" feel
      final resultIndex = _labels.indexOf(result.label);
      final sectionAngle = (2 * math.pi) / _labels.length;
      final targetAngle = 10 * math.pi + (resultIndex * sectionAngle);

      final animation = Tween<double>(begin: _currentRotation, end: -targetAngle).animate(
        CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic),
      );

      _spinController.forward(from: 0).then((_) {
        setState(() {
          _isSpinning = false;
          _currentRotation = -targetAngle % (2 * math.pi);
        });
        _showWinnerDialog(result);
      });

    } catch (e) {
      setState(() => _isSpinning = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _showWinnerDialog(GameResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars, color: Colors.amber, size: 60).animate().scale().rotate(),
            const Gap(16),
            Text(
              result.prize > 0 ? "You Won!" : "Try Again",
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Gap(8),
            Text(
              result.prize > 0 ? "+${result.prize} Diamonds" : "Better luck next time!",
              style: TextStyle(color: result.prize > 0 ? Colors.green : Colors.grey, fontSize: 18),
            ),
            const Gap(24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text("Awesome!"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(currentUserProfileProvider).value?.diamondBalance ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Mega Spin Wheel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    const Icon(Icons.diamond, color: Colors.amber, size: 14),
                    const Gap(6),
                    Text("$balance", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Glow
          Positioned.fill(
             child: Container(
                decoration: BoxDecoration(
                   gradient: RadialGradient(
                      colors: [Colors.amber.withOpacity(0.08), Colors.transparent],
                      radius: 0.8,
                   )
                ),
             ),
          ),

          Column(
            children: [
              const Gap(40),
              
              // Ferris Wheel Architecture
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Base Stand
                    Positioned(
                       bottom: 40,
                       child: CustomPaint(
                          size: const Size(200, 150),
                          painter: WheelBasePainter(),
                       ),
                    ),

                    // Rotating Wheel
                    AnimatedBuilder(
                      animation: _spinController,
                      builder: (context, child) {
                        final rotation = _spinController.isAnimating 
                          ? Tween<double>(begin: _currentRotation, end: _currentRotation - 10 * math.pi).animate(
                              CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic)
                            ).value
                          : _currentRotation;
                        
                        return Transform.rotate(
                          angle: rotation,
                          child: Stack(
                             alignment: Alignment.center,
                             children: [
                                // Structure & Spokes
                                CustomPaint(
                                   size: const Size(340, 340),
                                   painter: FerrisWheelPainter(),
                                ),
                                
                                // Prize Circles (Orbiting)
                                ...List.generate(_labels.length, (index) {
                                   final angle = (index * (2 * math.pi) / _labels.length) - (math.pi / 2);
                                   const radius = 135.0;
                                   return Positioned(
                                      left: 170 + radius * math.cos(angle) - 28,
                                      top: 170 + radius * math.sin(angle) - 28,
                                      child: Transform.rotate(
                                         angle: -rotation, // Keep icons upright
                                         child: Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                               color: const Color(0xFF1E1E1E),
                                               shape: BoxShape.circle,
                                               border: Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
                                               boxShadow: [
                                                  BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 10)
                                               ]
                                            ),
                                            alignment: Alignment.center,
                                            child: Column(
                                               mainAxisAlignment: MainAxisAlignment.center,
                                               children: [
                                                  const Icon(Icons.diamond, color: Colors.amber, size: 12),
                                                  Text(_labels[index], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                                               ],
                                            ),
                                         ),
                                      ),
                                   );
                                }),
                             ],
                          ),
                        );
                      },
                    ),

                    // Central Logo
                    Container(
                       width: 70,
                       height: 70,
                       decoration: BoxDecoration(
                          color: const Color(0xFF0F0F0F),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber, width: 3),
                          boxShadow: [
                             BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 20)
                          ]
                       ),
                       child: ClipOval(
                          child: Image.network(
                             "https://api.dicebear.com/7.x/bottts/png?seed=hellochatlogo",
                             fit: BoxFit.cover,
                          ),
                       ),
                    ),
                    
                    // Fixed Pointer (Indicator)
                    Positioned(
                       top: 20,
                       child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                             color: Colors.redAccent,
                             borderRadius: BorderRadius.circular(10),
                             boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 10)]
                          ),
                          child: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 30),
                       ),
                    ),
                  ],
                ),
              ),

              // Control Panel
              Container(
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
                ),
                child: Column(
                  children: [
                    const Text("SELECT YOUR BET", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    const Gap(20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _betOptions.map((bet) => _buildBetChip(bet)).toList(),
                    ),
                    const Gap(32),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: _isSpinning ? null : _spin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 10,
                          shadowColor: AppColors.primary.withOpacity(0.3)
                        ),
                        child: Text(
                          _isSpinning ? "LAUNCHING..." : "SPIN TO WIN",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
                        ),
                      ),
                    ),
                    const Gap(16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildBetChip(int amount) {
    bool isSelected = _selectedBet == amount;
    return GestureDetector(
      onTap: () => setState(() => _selectedBet = amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? Colors.white24 : Colors.white10),
        ),
        child: Row(
          children: [
            const Icon(Icons.diamond, color: Colors.cyanAccent, size: 14),
            const Gap(6),
            Text("$amount", style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class FerrisWheelPainter extends CustomPainter {
  FerrisWheelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final innerRadius = 35.0;
    final outerRadius = 140.0;
    
    final spokePaint = Paint()
      ..color = Colors.amber.withOpacity(0.1)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
      
    final ringPaint = Paint()
      ..color = Colors.amber.withOpacity(0.05)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;

    // Draw Rings
    canvas.drawCircle(center, outerRadius, ringPaint);
    canvas.drawCircle(center, (outerRadius + innerRadius) / 2, ringPaint..strokeWidth = 2);

    // Draw Spokes
    const sections = 8;
    const sectionAngle = (2 * math.pi) / sections;
    for (int i = 0; i < sections; i++) {
        final angle = i * sectionAngle;
        canvas.drawLine(
           Offset(center.dx + math.cos(angle) * innerRadius, center.dy + math.sin(angle) * innerRadius),
           Offset(center.dx + math.cos(angle) * outerRadius, center.dy + math.sin(angle) * outerRadius),
           spokePaint
        );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WheelBasePainter extends CustomPainter {
   @override
   void paint(Canvas canvas, Size size) {
      final paint = Paint()
         ..shader = LinearGradient(
            colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.02)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter
         ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
         ..style = PaintingStyle.fill;
         
      final path = Path()
         ..moveTo(size.width * 0.2, 0)
         ..lineTo(size.width * 0.8, 0)
         ..lineTo(size.width, size.height)
         ..lineTo(0, size.height)
         ..close();
         
      canvas.drawPath(path, paint);
      
      // Support Beams
      final beamPaint = Paint()
         ..color = Colors.white.withOpacity(0.1)
         ..strokeWidth = 4
         ..style = PaintingStyle.stroke;
         
      canvas.drawLine(Offset(size.width * 0.4, 0), Offset(size.width * 0.1, size.height), beamPaint);
      canvas.drawLine(Offset(size.width * 0.6, 0), Offset(size.width * 0.9, size.height), beamPaint);
   }

   @override
   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
