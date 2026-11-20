import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/utils/async_send_gate.dart';
import 'package:hello_chat/services/chat_service.dart';

void main() {
  group('AsyncSendGate', () {
    test('drops a duplicate tap while a send is in flight', () async {
      final gate = AsyncSendGate();
      final release = Completer<void>();
      var sends = 0;

      final first = gate.run(() async {
        sends++;
        await release.future;
      });
      expect(gate.isBusy, isTrue);

      final duplicate = await gate.run(() async => sends++);
      expect(duplicate, isFalse);
      expect(sends, 1);

      release.complete();
      expect(await first, isTrue);
      expect(gate.isBusy, isFalse);

      expect(await gate.run(() async => sends++), isTrue);
      expect(sends, 2);
    });

    test('reopens after a failure so the user can retry', () async {
      final gate = AsyncSendGate();

      await expectLater(
        gate.run(() async => throw Exception('offline')),
        throwsException,
      );
      expect(gate.isBusy, isFalse);

      expect(await gate.run(() async {}), isTrue);
    });
  });

  group('ChatService.describePrivateSendError', () {
    test('keeps actionable block messages', () {
      expect(
        ChatService.describePrivateSendError(
          Exception(
              'You have blocked this user. Unblock them to send a message.'),
        ),
        contains('blocked'),
      );
      expect(
        ChatService.describePrivateSendError(
          Exception('You cannot send messages to this user.'),
        ),
        contains('cannot send messages'),
      );
    });

    test('collapses transport errors into a retry message', () {
      expect(
        ChatService.describePrivateSendError(
          Exception('UNAVAILABLE: failed to connect'),
        ),
        'Message not sent. Check your connection and try again.',
      );
    });
  });
}
