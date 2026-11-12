import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/constants/stickers_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stickers Asset Bundle Verification', () {
    test('All active sticker packs exist and are non-empty', () {
      expect(StickersData.activePacks.length, 5);
      for (final pack in StickersData.activePacks) {
        expect(pack.stickers.isNotEmpty, isTrue, reason: '${pack.title} must have stickers');
      }
    });

    test('Every sticker in all 5 packs can be loaded from rootBundle', () async {
      int totalLoaded = 0;
      for (final pack in StickersData.activePacks) {
        for (final stickerPath in pack.stickers) {
          final byteData = await rootBundle.load(stickerPath);
          expect(byteData.lengthInBytes, greaterThan(0), reason: '$stickerPath must have content');
          totalLoaded++;
        }
      }
      expect(totalLoaded, 121);
    });
  });
}

