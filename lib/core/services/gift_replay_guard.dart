enum GiftSkipReason {
  none,
  notGiftType,
  missingAnimationPayload,
  duplicate,
  missingTimestamp,
  beforeJoin,
  expired,
  localEcho,
}

class GiftReplayDecision {
  final bool shouldPlay;
  final GiftSkipReason reason;
  final int ageMs;
  final String? logMessage;

  const GiftReplayDecision({
    required this.shouldPlay,
    required this.reason,
    required this.ageMs,
    this.logMessage,
  });

  bool get isSkipped => !shouldPlay;
}

/// Centralized, production-grade filter enforcing that old gift animations
/// never replay for new joiners or re-entering users.
class GiftReplayGuard {
  /// Evaluates whether a room gift message is eligible to play.
  static GiftReplayDecision evaluate({
    required String msgId,
    required String type,
    required String? animationUrl,
    required String? giftId,
    required DateTime? createdAt,
    required bool hasExplicitTimestamp,
    required int durationMs,
    required Set<String> processedMessageIds,
    required int joinTimeServerMs,
    required int nowServerMs,
    bool isLocalEcho = false,
  }) {
    // 1. Not a gift type
    if (type != 'gift') {
      return const GiftReplayDecision(
        shouldPlay: false,
        reason: GiftSkipReason.notGiftType,
        ageMs: 0,
      );
    }

    // 2. Missing animation payload
    final hasAnimUrl = animationUrl != null && animationUrl.trim().isNotEmpty;
    final hasGiftId = giftId != null && giftId.trim().isNotEmpty;
    if (!hasAnimUrl && !hasGiftId) {
      return const GiftReplayDecision(
        shouldPlay: false,
        reason: GiftSkipReason.missingAnimationPayload,
        ageMs: 0,
      );
    }

    // 3. Gate 1: Already processed message
    if (processedMessageIds.contains(msgId)) {
      return GiftReplayDecision(
        shouldPlay: false,
        reason: GiftSkipReason.duplicate,
        ageMs: 0,
        logMessage: '🎁 [GIFT_SKIP] reason=duplicate, msgId=$msgId',
      );
    }

    // 4. Local echo: sender already played it optimistically (even if server timestamp is pending)
    if (isLocalEcho) {
      return GiftReplayDecision(
        shouldPlay: false,
        reason: GiftSkipReason.localEcho,
        ageMs: 0,
        logMessage: '🎁 [GIFT_SKIP] reason=localEcho, msgId=$msgId, giftId=$giftId, age=0ms',
      );
    }

    // 5. Missing timestamp guard:
    // If a message document arrives without a server timestamp, we cannot prove
    // it was sent after the user joined. Reject immediately to prevent historical replay.
    if (!hasExplicitTimestamp || createdAt == null) {
      return GiftReplayDecision(
        shouldPlay: false,
        reason: GiftSkipReason.missingTimestamp,
        ageMs: 0,
        logMessage: '🎁 [GIFT_SKIP] reason=missingTimestamp, msgId=$msgId, giftId=$giftId, age=unknown',
      );
    }

    final createdAtMs = createdAt.millisecondsSinceEpoch;
    final ageMs = nowServerMs - createdAtMs;
    final effectiveDuration = durationMs > 0 ? durationMs : 5000;

    // 6. Gate 2: Sent before user joined the room (-2000ms jitter tolerance)
    if (joinTimeServerMs > 0 && createdAtMs < (joinTimeServerMs - 2000)) {
      return GiftReplayDecision(
        shouldPlay: false,
        reason: GiftSkipReason.beforeJoin,
        ageMs: ageMs,
        logMessage: '🎁 [GIFT_SKIP] reason=beforeJoin, msgId=$msgId, giftId=$giftId, createdAtMs=$createdAtMs, joinTimeMs=$joinTimeServerMs, age=${ageMs}ms',
      );
    }

    // 7. Gate 3: Message is old/expired (older than animation duration + 5000ms grace)
    if (ageMs > (effectiveDuration + 5000)) {
      return GiftReplayDecision(
        shouldPlay: false,
        reason: GiftSkipReason.expired,
        ageMs: ageMs,
        logMessage: '🎁 [GIFT_SKIP] reason=old, msgId=$msgId, giftId=$giftId, age=${ageMs}ms, maxTTL=${effectiveDuration + 5000}ms',
      );
    }

    // Passed all gates
    return GiftReplayDecision(
      shouldPlay: true,
      reason: GiftSkipReason.none,
      ageMs: ageMs,
    );
  }
}
