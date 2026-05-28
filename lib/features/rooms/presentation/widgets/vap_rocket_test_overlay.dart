import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vap_plugin/flutter_vap_plugin.dart';

class VapRocketTestOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const VapRocketTestOverlay({
    super.key,
    required this.onComplete,
  });

  @override
  State<VapRocketTestOverlay> createState() => _VapRocketTestOverlayState();
}

class _VapRocketTestOverlayState extends State<VapRocketTestOverlay> {
  // Initialize the controller
  final FlutterVapController _vapController = FlutterVapController();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isInitialized = true);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _startPlayback();
        });
      }
    });
  }

  Future<void> _startPlayback() async {
    const vapPath = 'assets/rocket/VAP/1-c.mp4';
    try {
      // Copy to temp file to avoid native asset loading issues
      final byteData = await DefaultAssetBundle.of(context).load(vapPath);
      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_test_vap.mp4');
      await tempFile.writeAsBytes(bytes);

      debugPrint("Test VAP copied to: ${tempFile.path}");

      await _vapController.play(
        path: tempFile.path,
        sourceType: VapSourceType.file,
        repeatCount: 1,
      );
    } catch (e) {
      debugPrint("VAP Playback Error: $e");
      if (mounted) {
        widget.onComplete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isInitialized)
            FlutterVapView(
              controller: _vapController,
              onVideoFinish: () {
                debugPrint("VAP Animation Finished");
                if (mounted) {
                  Future.delayed(const Duration(milliseconds: 500), widget.onComplete);
                }
              },
              onFailed: (errorType, errorMsg) {
                debugPrint("VAP Animation Failed: [$errorType] $errorMsg");
                if (mounted) {
                  widget.onComplete();
                }
              },
            ),
          
          Positioned(
            bottom: 50,
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _startPlayback,
                  child: const Text("Replay VAP"),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: widget.onComplete,
                  child: const Text("Close Test"),
                ),
              ],
            ),
          ),

          const Positioned(
            top: 100,
            child: Text(
              "VAP ANIMATION TEST MODE",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
