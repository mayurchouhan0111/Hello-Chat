import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/constants/gift_vap_catalog.dart';
import 'package:hello_chat/core/models/gift_model.dart';
import 'package:hello_chat/core/utils/svga_parser_util.dart';

void main() {
  group('🎬 Tencent VAP Gifts 12-Asset Suite', () {
    test('1. GiftVapCatalog contains exactly 12 bundled gifts', () {
      expect(GiftVapCatalog.all.length, equals(12));
      expect(GiftVapCatalog.normal.length, equals(3));
      expect(GiftVapCatalog.medium.length, equals(7));
      expect(GiftVapCatalog.luxury.length, equals(2));
    });

    test('2. All 12 .vap files exist in assets/gifts-vap and have non-zero size', () {
      for (final spec in GiftVapCatalog.all) {
        final file = File(spec.assetPath);
        expect(file.existsSync(), isTrue, reason: 'Missing VAP file: ${spec.assetPath}');
        expect(file.lengthSync(), greaterThan(100000), reason: 'VAP file too small: ${spec.assetPath}');
      }
    });

    test('3. All 12 icon PNGs exist in assets/images/gifts and have non-zero size', () {
      for (final spec in GiftVapCatalog.all) {
        final iconPath = 'assets/images/gifts/${spec.giftId}.png';
        final file = File(iconPath);
        expect(file.existsSync(), isTrue, reason: 'Missing icon file: $iconPath');
        expect(file.lengthSync(), greaterThan(1000), reason: 'Icon file too small: $iconPath');
      }
    });

    test('4. SvgaParserUtil.getLocalVapPath maps all 12 gifts correctly', () {
      for (final spec in GiftVapCatalog.all) {
        // Direct asset path
        final resolvedFromAsset = SvgaParserUtil.getLocalVapPath(spec.assetPath);
        expect(resolvedFromAsset, equals(spec.assetPath));

        // By giftId
        final resolvedFromId = SvgaParserUtil.getLocalVapPath('', giftId: spec.giftId);
        expect(resolvedFromId, equals(spec.assetPath), reason: 'Failed lookup by ID for ${spec.giftId}');

        // By combo-suffixed ID (e.g. vap_gift_1_0)
        final resolvedFromSuffixedId = SvgaParserUtil.getLocalVapPath('', giftId: '${spec.giftId}_2');
        expect(resolvedFromSuffixedId, equals(spec.assetPath));
      }
    });

    test('5. GiftModel.fromMap correctly parses all 12 VAP specs to valid models', () {
      for (final spec in GiftVapCatalog.all) {
        final doc = spec.toFirestoreDoc();
        final model = GiftModel.fromMap(doc, spec.giftId);

        expect(model.giftId, equals(spec.giftId));
        expect(model.name, equals(spec.name));
        expect(model.priceInDiamonds, equals(spec.priceInDiamonds));
        expect(model.category, equals(spec.tier.toLowerCase()));
        expect(model.tier, equals(spec.tier));
        expect(model.animationTier, equals(spec.tier));
        expect(model.animationFormat, equals('vap'));
        expect(model.durationMs, equals(spec.durationMs));
        expect(model.isActive, isTrue);
      }
    });

    test('6. No VAP gift name contains deactivated keywords (e.g. lucky)', () {
      for (final spec in GiftVapCatalog.all) {
        final lowerName = spec.name.toLowerCase();
        expect(lowerName.contains('lucky'), isFalse, reason: 'Gift ${spec.giftId} contains "lucky"');
        expect(lowerName.contains('edit'), isFalse, reason: 'Gift ${spec.giftId} still has EDIT placeholder');
      }
    });

    test('7. VAP gifts adhere strictly to duration tiers', () {
      for (final spec in GiftVapCatalog.normal) {
        expect(spec.durationMs, inInclusiveRange(4500, 7500));
        expect(spec.tier, equals('NORMAL'));
      }
      for (final spec in GiftVapCatalog.medium) {
        expect(spec.durationMs, inInclusiveRange(7000, 11000));
        expect(spec.tier, equals('MEDIUM'));
      }
      for (final spec in GiftVapCatalog.luxury) {
        expect(spec.durationMs, inInclusiveRange(11000, 16000));
        expect(spec.tier, equals('LUXURY'));
      }
    });
  });
}
