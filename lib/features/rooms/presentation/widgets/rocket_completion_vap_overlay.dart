import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vap_plugin/flutter_vap_plugin.dart';

class RocketCompletionVapOverlay extends StatefulWidget {
  final int level;
  final VoidCallback onComplete;

  const RocketCompletionVapOverlay({
    super.key,
    required this.level,
    required this.onComplete,
  });

  @override
  State<RocketCompletionVapOverlay> createState() => _RocketCompletionVapOverlayState();
}

class _RocketCompletionVapOverlayState extends State<RocketCompletionVapOverlay> {
  final FlutterVapController _vapController = FlutterVapController();
  bool _isInitialized = false;
  int _currentStep = 0; // 0: Animation B, 1: Animation C
  Completer<void>? _vapCompleter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isInitialized = true);
        _playSequence();
      }
    });
  }

  Future<void> _playSequence() async {
    debugPrint("🚀 [VAP] Starting Sequence: B -> C");
    
    // Sequence: Play B, then play C
    await _playVapAsset('b');
    
    if (mounted) {
      debugPrint("🚀 [VAP] Step B Finished. Starting C.");
      setState(() => _currentStep = 1);
      await _playVapAsset('c');
    }
    
    if (mounted) {
      debugPrint("🚀 [VAP] Sequence Complete.");
      widget.onComplete();
    }
  }

  Future<void> _playVapAsset(String type) async {
    _vapCompleter = Completer<void>();
    final vapAssetPath = 'assets/rocket/VAP/${widget.level}-$type.mp4';
    
    try {
      debugPrint("🚀 [VAP] Loading asset: $vapAssetPath");
      final byteData = await rootBundle.load(vapAssetPath);
      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/rocket_launch_${widget.level}_$type.mp4');
      await tempFile.writeAsBytes(bytes, flush: true);

      debugPrint("🚀 [VAP] Playing file: ${tempFile.path}");
      _vapController.play(
        path: tempFile.path,
        sourceType: VapSourceType.file,
        repeatCount: 0, 
      );
      
      // Wait for onVideoFinish or timeout (safety)
      await _vapCompleter!.future.timeout(const Duration(seconds: 12), onTimeout: () {
        debugPrint("⚠️ [VAP] Animation $type timed out.");
      });
    } catch (e) {
      debugPrint("❌ [VAP] Error ($type): $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isInitialized)
              Positioned.fill(
                child: FlutterVapView(
                  controller: _vapController,
                  onVideoFinish: () {
                    debugPrint("🚀 [VAP] Video Finished Callback");
                    if (_vapCompleter?.isCompleted == false) {
                      _vapCompleter?.complete();
                    }
                  },
                  onFailed: (errorType, errorMsg) {
                    debugPrint("❌ [VAP] Failed: [$errorType] $errorMsg");
                    if (_vapCompleter?.isCompleted == false) {
                      _vapCompleter?.complete();
                    }
                  },
                ),
              ),
            
            // Subtle UI indicator
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF00FFFF).withOpacity(0.4)),
                ),
                child: Text(
                  "LEVEL ${widget.level} ROCKET LAUNCHED!",
                  style: const TextStyle(
                    color: Color(0xFF00FFFF),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
