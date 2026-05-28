import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/providers/overlay_provider.dart';

class FloatingRoomOverlay extends ConsumerStatefulWidget {
  const FloatingRoomOverlay({super.key});

  @override
  ConsumerState<FloatingRoomOverlay> createState() => _FloatingRoomOverlayState();
}

class _FloatingRoomOverlayState extends ConsumerState<FloatingRoomOverlay> {
  bool _contextInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeContext();
  }

  void _initializeContext() {
    if (!_contextInitialized && mounted) {
      _contextInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          try {
            ref.read(roomOverlayProvider.notifier).setContext(context);
          } catch (e) {
            debugPrint('[FloatingRoomOverlay] Error setting context: $e');
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _initializeContext();
    return const SizedBox.shrink();
  }
}