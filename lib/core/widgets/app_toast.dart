import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

enum ToastType { success, error, diamond, info, warning }

class AppToast {
  static void showSuccess(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title ?? "Success", type: ToastType.success);
  }

  static void showError(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title ?? "Oops!", type: ToastType.error);
  }

  static void showDiamond(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title ?? "Recharge Successful", type: ToastType.diamond);
  }

  static void showInfo(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title ?? "Notice", type: ToastType.info);
  }

  static void showWarning(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title ?? "Heads Up", type: ToastType.warning);
  }

  static OverlayEntry? _activeOverlay;

  /// Displays a floating toast directly on top of all modal dialogs and bottom sheets
  static void showOverlay(
    BuildContext context, {
    required String message,
    String? title,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _activeOverlay?.remove();
    _activeOverlay = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      show(context, message: message, title: title, type: type, duration: duration);
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: _ToastWidget(
            title: title,
            message: message,
            type: type,
            onDismiss: () {
              if (entry.mounted) entry.remove();
              if (_activeOverlay == entry) _activeOverlay = null;
            },
          ),
        ),
      ),
    );

    _activeOverlay = entry;
    overlay.insert(entry);

    Future.delayed(duration, () {
      if (entry.mounted) {
        entry.remove();
        if (_activeOverlay == entry) _activeOverlay = null;
      }
    });
  }

  static void show(
    BuildContext context, {
    required String message,
    String? title,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = rootScaffoldMessengerKey.currentState ?? ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: _ToastWidget(
          title: title,
          message: message,
          type: type,
          onDismiss: () => messenger.hideCurrentSnackBar(),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: duration,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _ToastWidget extends StatelessWidget {
  final String? title;
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  const _ToastWidget({
    this.title,
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  Color get _accentColor {
    switch (type) {
      case ToastType.success:
        return const Color(0xFF10B981); // Emerald Green
      case ToastType.error:
        return const Color(0xFFFF4B6E); // Coral Rose Red
      case ToastType.diamond:
        return const Color(0xFFFFB800); // Gold Amber
      case ToastType.info:
        return const Color(0xFF00E5FF); // Electric Cyan
      case ToastType.warning:
        return const Color(0xFFF59E0B); // Amber
    }
  }

  IconData get _iconData {
    switch (type) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.error:
        return Icons.error_rounded;
      case ToastType.diamond:
        return Icons.diamond_rounded;
      case ToastType.info:
        return Icons.info_rounded;
      case ToastType.warning:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xF0121722), // Deep Luxury Frosted Slate
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: accent.withOpacity(0.55),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.25),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 1. Glowing 3D Badge Icon
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          accent,
                          accent.withOpacity(0.65),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _iconData,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 2. Text Area (Title + Message)
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null && title!.isNotEmpty) ...[
                          Text(
                            title!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          message,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 3. Dismiss Close Button
                  GestureDetector(
                    onTap: onDismiss,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withOpacity(0.5),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: 0.3, end: 0, duration: 250.ms, curve: Curves.easeOutBack).fadeIn(duration: 200.ms);
  }
}
