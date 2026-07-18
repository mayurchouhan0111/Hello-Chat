import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tancent_vap/tancent_vap.dart';
import 'package:path_provider/path_provider.dart';

class VapAnimation extends StatefulWidget {
  final String assetPath;
  final String? profileImageUrl;
  final Uint8List? profileImageBytes;
  final BoxFit fit;
  final bool loop;
  final VoidCallback? onComplete;

  const VapAnimation({
    super.key,
    required this.assetPath,
    this.profileImageUrl,
    this.profileImageBytes,
    this.fit = BoxFit.contain,
    this.loop = false,
    this.onComplete,
  });

  @override
  State<VapAnimation> createState() => _VapAnimationState();
}

class _VapAnimationState extends State<VapAnimation> {
  VapController? _controller;
  bool _hasError = false;
  String? _tempFilePath;

  @override
  void didUpdateWidget(VapAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _hasError = false;
    }
    if (oldWidget.profileImageUrl != widget.profileImageUrl ||
        oldWidget.profileImageBytes != widget.profileImageBytes) {
      _setProfileTag();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _setProfileTag() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      if (widget.profileImageUrl != null && widget.profileImageUrl!.isNotEmpty) {
        await ctrl.setVapTagContent('user', ImageURLContent(widget.profileImageUrl!));
      } else if (widget.profileImageBytes != null) {
        await ctrl.setVapTagContent('user', ImageBase64Content(base64Encode(widget.profileImageBytes!)));
      }
    } catch (e) {
      debugPrint('VapAnimation: Failed to set profile tag - $e');
    }
  }

  ScaleType _mapFit(BoxFit fit) {
    return switch (fit) {
      BoxFit.cover => ScaleType.centerCrop,
      BoxFit.fill => ScaleType.fitXY,
      _ => ScaleType.fitCenter,
    };
  }

  Future<String> _ensureTempFile() async {
    final tempDir = await getTemporaryDirectory();
    final safeName = widget.assetPath.replaceAll(RegExp(r'[^\w.]'), '_');
    final tempFile = File('${tempDir.path}/$safeName');
    if (!tempFile.existsSync()) {
      final data = await rootBundle.load(widget.assetPath);
      await tempFile.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }
    _tempFilePath = tempFile.path;
    return _tempFilePath!;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return const SizedBox.shrink();

    return VapView(
      key: ValueKey(widget.assetPath),
      scaleType: _mapFit(widget.fit),
      repeat: widget.loop ? 99999 : 0,
      onViewCreated: _onViewCreated,
    );
  }

  Future<void> _onViewCreated(VapController controller) async {
    _controller = controller;

    controller.setAnimListener(
      onVideoComplete: () => widget.onComplete?.call(),
      onFailed: (code, type, msg) {
        debugPrint('VapAnimation failed: [$code] $type - $msg');
        if (mounted) setState(() => _hasError = true);
      },
    );

    await _setProfileTag();

    if (!mounted) return;
    try {
      final path = await _ensureTempFile();
      if (widget.loop) {
        await controller.setLoop(99999);
      }
      await controller.playFile(path);
      debugPrint('VapAnimation: Playing ${widget.assetPath} from $path${widget.loop ? ' (looping)' : ''}');
    } catch (e) {
      debugPrint('VapAnimation: Failed to start ${widget.assetPath} - $e');
      if (mounted) setState(() => _hasError = true);
    }
  }
}
