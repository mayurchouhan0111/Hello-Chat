import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/providers/overlay_provider.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:hello_chat/services/room_service.dart';
import 'package:hello_chat/services/voice_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FloatingRoomOverlayManager {
  OverlayEntry? _overlayEntry;
  bool _isInitialized = false;
  Offset _position = const Offset(20, 100);
  String? _currentRoomId;

  static final FloatingRoomOverlayManager _instance = FloatingRoomOverlayManager._internal();
  factory FloatingRoomOverlayManager() => _instance;
  FloatingRoomOverlayManager._internal();

  bool get isInitialized => _isInitialized;
  Offset get position => _position;
  String? get currentRoomId => _currentRoomId;

  void updatePosition(Offset newPosition) {
    _position = newPosition;
  }

  void showOverlay(BuildContext context, String roomId) {
    if (_overlayEntry != null && _isInitialized && _currentRoomId == roomId) {
      return;
    }

    removeOverlay();

    final overlay = Navigator.of(context).overlay;
    if (overlay == null) {
      debugPrint('[FloatingRoomOverlay] ERROR: No overlay found');
      return;
    }

    _currentRoomId = roomId;

    final capturedNavigator = Navigator.of(context, rootNavigator: true);
    final capturedRoomId = roomId;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => _FloatingRoomBubble(
        roomId: capturedRoomId,
        initialPosition: _position,
        onPositionChanged: (newPos) {
          _position = newPos;
        },
        onClose: () => removeOverlay(),
        onRestore: () {
          final rid = capturedRoomId;
          final ctx = _bubbleContext;
          removeOverlay();
          if (ctx != null && ctx.mounted) {
            GoRouter.of(ctx).push('/live-room/$rid');
          }
        },
      ),
    );

    _isInitialized = true;
    overlay.insert(_overlayEntry!);
    debugPrint('[FloatingRoomOverlay] Overlay inserted for room: $roomId');
  }

  void removeOverlay() {
    if (_overlayEntry != null) {
      try {
        _overlayEntry?.remove();
      } catch (e) {
        debugPrint('[FloatingRoomOverlay] Error removing overlay: $e');
      }
      _overlayEntry = null;
      _isInitialized = false;
      _currentRoomId = null;
      _bubbleContext = null;
      debugPrint('[FloatingRoomOverlay] Overlay removed');
    }
  }

  bool get isShowing => _overlayEntry != null && _isInitialized;

  void dispose() {
    removeOverlay();
  }

  BuildContext? _bubbleContext;

  void setBubbleContext(BuildContext ctx) {
    _bubbleContext = ctx;
  }

  void _handleRestore(BuildContext context, String roomId) {
    removeOverlay();
    final overlayState = RoomOverlayState(roomId: null, isMinimized: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        final navigator = Navigator.of(context, rootNavigator: true);
        if (navigator.mounted) {
          navigator.pushReplacementNamed('/live-room', arguments: roomId);
        }
      }
    });
  }
}

final floatingRoomOverlayManager = FloatingRoomOverlayManager();

class _FloatingRoomBubble extends StatefulWidget {
  final String roomId;
  final Offset initialPosition;
  final ValueChanged<Offset> onPositionChanged;
  final VoidCallback onClose;
  final VoidCallback onRestore;

  const _FloatingRoomBubble({
    required this.roomId,
    required this.initialPosition,
    required this.onPositionChanged,
    required this.onClose,
    required this.onRestore,
  });

  @override
  State<_FloatingRoomBubble> createState() => _FloatingRoomBubbleState();
}

class _FloatingRoomBubbleState extends State<_FloatingRoomBubble> with WidgetsBindingObserver {
  late Offset _position;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      floatingRoomOverlayManager.setBubbleContext(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted) return const SizedBox.shrink();

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final padding = mediaQuery.padding;
    final keyboardHeight = mediaQuery.viewInsets.bottom;

    final safeWidth = screenSize.width - 100;
    final safeHeight = screenSize.height - padding.top - padding.bottom - keyboardHeight - 100;

    return Positioned(
      left: _position.dx.clamp(8, safeWidth),
      top: _position.dy.clamp(padding.top + 8, safeHeight),
      child: GestureDetector(
        onTap: widget.onRestore,
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          if (!mounted) return;
          setState(() {
            _position = Offset(
              (_position.dx + details.delta.dx).clamp(8, safeWidth),
              (_position.dy + details.delta.dy).clamp(padding.top + 8, safeHeight),
            );
          });
        },
        onPanEnd: (_) {
          setState(() => _isDragging = false);
          widget.onPositionChanged(_position);
        },
        child: AnimatedScale(
          scale: _isDragging ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: _BubbleContent(roomId: widget.roomId),
        ),
      ),
    );
  }
}

class _BubbleContent extends ConsumerWidget {
  final String roomId;

  const _BubbleContent({required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(currentRoomStreamProvider(roomId));

    return roomAsync.when(
      data: (room) {
        if (room == null) {
          return _buildLoadingBubble();
        }

        final String imageUrl = room.coverUrl.isNotEmpty
            ? room.coverUrl
            : "https://picsum.photos/seed/${room.ownerUid}/200";

        return Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              )
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.grey[900]),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.live_tv, color: Colors.white24),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "LIVE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      final roomId = ref.read(roomOverlayProvider).roomId;
                      if (roomId != null) {
                        ref.read(roomServiceProvider).leaveRoom(roomId);
                        ref.read(voiceServiceProvider).leaveRoom();
                      }
                      ref.read(roomOverlayProvider.notifier).clear();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.close, color: Colors.white70, size: 14),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  left: 6,
                  right: 6,
                  child: Text(
                    room.name.isEmpty ? "Room" : room.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => _buildLoadingBubble(),
      error: (_, __) => _buildLoadingBubble(),
    );
  }

  Widget _buildLoadingBubble() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[900],
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
      ),
    );
  }
}