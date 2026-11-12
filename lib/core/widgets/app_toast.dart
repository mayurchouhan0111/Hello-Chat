import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

enum ToastType { success, error, diamond, info, warning }

class AppToast {
  /// Sanitizes technical error messages and prefixes into polite, human-friendly English.
  static String sanitizeErrorMessage(String rawMessage) {
    if (rawMessage.trim().isEmpty) {
      return "Something went wrong. Please try again.";
    }

    String msg = rawMessage.trim();

    // Repeatedly strip known technical wrappers and exception headers
    bool changed;
    do {
      changed = false;
      final before = msg;

      // Strip common exception wrappers like 'Exception:', 'FirebaseException:', etc.
      msg = msg.replaceFirst(
        RegExp(r'^(Exception|Error|FirebaseException|FirebaseFunctionsException|PlatformException):\s*', caseSensitive: false),
        '',
      );

      // Strip [package/code] prefixes, e.g. [firebase_functions/failed-precondition] or [cloud_firestore/permission-denied]
      msg = msg.replaceAll(RegExp(r'\[[a-zA-Z0-9_\-]+/[a-zA-Z0-9_\-]+\]'), '').trim();

      // Strip generic "Purchase Failed:" / "Action Failed:" / "Operation Failed:" wrappers
      msg = msg.replaceFirst(
        RegExp(r'^(Purchase|Action|Operation|Request|Update|Load)\s+Failed:\s*', caseSensitive: false),
        '',
      );

      if (msg != before) {
        changed = true;
      }
    } while (changed);

    msg = msg.trim();
    final lower = msg.toLowerCase();

    // Domain mappings for human-friendly English sentences
    if (lower.contains('insufficient') && (lower.contains('diamond') || lower.contains('balance'))) {
      return 'Insufficient diamonds. Please recharge your wallet to proceed.';
    }
    if (lower.contains('insufficient') && lower.contains('bean')) {
      return 'Insufficient beans. Please recharge or earn beans to proceed.';
    }
    if (lower.contains('permission-denied') || lower.contains('permission denied') || lower.contains('insufficient permissions') || lower.contains('missing or insufficient permissions')) {
      return 'You do not have permission to perform this action.';
    }
    if (lower.contains('unauthenticated') || lower.contains('not authenticated') || lower.contains('user-not-found') || lower.contains('must be logged in')) {
      return 'Please log in to continue.';
    }
    if (lower.contains('unavailable') || lower.contains('network-request-failed') || lower.contains('socketexception') || lower.contains('failed host lookup') || lower.contains('client is offline')) {
      return 'Network connection issue. Please check your internet connection.';
    }
    if (lower.contains('deadline-exceeded') || lower.contains('timeout') || lower.contains('timed out')) {
      return 'Request timed out. Please try again.';
    }
    if (lower.contains('already-exists') || lower.contains('already exists')) {
      return 'This request or item already exists.';
    }
    if (lower.contains('active cp') || lower.contains('already have an active cp') || lower.contains('active relationship') || lower.contains('already partner')) {
      return 'You or this user already have an active partner.';
    }
    if (lower.contains('blocked this user') || lower.contains('you have blocked')) {
      return 'You have blocked this user. Unblock them to continue.';
    }
    if (lower.contains('cannot send messages to this user') || lower.contains('they blocked')) {
      return 'Unable to send messages to this user.';
    }
    if (lower.contains('not-found') || lower.contains('document does not exist') || lower.contains('not found')) {
      return 'The requested item could not be found.';
    }
    if (lower.contains('internal') || lower.contains('server-error') || lower.contains('unknown error')) {
      return 'Something went wrong on our end. Please try again later.';
    }

    // Clean up any stray quotes
    msg = msg.replaceAll(RegExp(r'''^["']|["']$'''), '').trim();

    if (msg.isNotEmpty) {
      // Ensure sentence capitalization and terminal punctuation
      msg = msg[0].toUpperCase() + msg.substring(1);
      if (!msg.endsWith('.') && !msg.endsWith('!') && !msg.endsWith('?')) {
        msg = '$msg.';
      }
      return msg;
    }

    return 'An unexpected error occurred. Please try again.';
  }

  static void showSuccess(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title ?? "Success", type: ToastType.success);
  }

  static void showError(BuildContext context, String message, {String? title}) {
    final sanitized = sanitizeErrorMessage(message);
    show(context, message: sanitized, title: title ?? "Oops!", type: ToastType.error);
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
    final finalMessage = type == ToastType.error ? sanitizeErrorMessage(message) : message;
    _activeOverlay?.remove();
    _activeOverlay = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      show(context, message: finalMessage, title: title, type: type, duration: duration);
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
            message: finalMessage,
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
    showOverlay(context, message: message, title: title, type: type, duration: duration);
  }
}

/// Calculates the exact top margin required to position a floating SnackBar
/// at the top of the viewport (just beneath the status bar/app bar).
EdgeInsets topSnackBarMargin(BuildContext context, {double extraTop = 0}) {
  final mq = MediaQuery.maybeOf(context);
  final screenHeight = mq?.size.height ?? 800.0;
  final topPadding = (mq?.padding.top ?? 40.0) + extraTop;
  return EdgeInsets.only(
    bottom: (screenHeight - (topPadding + 76.0)).clamp(0.0, screenHeight),
    left: 16.0,
    right: 16.0,
  );
}

/// A SnackBar subclass that automatically positions itself at the top of the screen
/// ensuring full visibility, immunity to bottom sheets/keyboards, and full SnackBarAction functionality.
class TopSnackBar extends SnackBar {
  TopSnackBar({
    super.key,
    required super.content,
    required BuildContext context,
    super.backgroundColor,
    super.elevation = 6,
    super.shape,
    super.action,
    super.actionOverflowThreshold,
    super.showCloseIcon,
    super.closeIconColor,
    super.duration = const Duration(seconds: 4),
    super.animation,
    super.onVisible,
    super.dismissDirection = DismissDirection.up,
    super.clipBehavior = Clip.hardEdge,
    SnackBarBehavior? behavior,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
  }) : super(
          behavior: behavior ?? SnackBarBehavior.floating,
          margin: margin ?? topSnackBarMargin(context),
          padding: padding,
        );
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
    ).animate().slideY(begin: -0.3, end: 0, duration: 250.ms, curve: Curves.easeOutBack).fadeIn(duration: 200.ms);
  }
}
