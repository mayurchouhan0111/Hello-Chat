import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/gift_model.dart';

GiftModel gift({
  String category = 'Normal',
  String tier = '',
  Map<String, dynamic>? from,
}) =>
    from != null
        ? GiftModel.fromMap(from, 'doc1')
        : GiftModel(
            giftId: 'doc1',
            name: 'Test',
            priceInDiamonds: 100,
            category: category,
            imageUrl: '',
            lottieAssetPath: '',
            tier: tier,
          );

void main() {
  group('GiftModel.animationTier', () {
    test('derives tier from category when tier field is empty', () {
      expect(gift(category: 'Normal').animationTier, 'NORMAL');
      expect(gift(category: 'Lucky').animationTier, 'NORMAL');
      expect(gift(category: 'Family Battle').animationTier, 'NORMAL');
      expect(gift(category: 'SVIP').animationTier, 'NORMAL');
      expect(gift(category: 'Medium').animationTier, 'MEDIUM');
      expect(gift(category: 'luxury').animationTier, 'LUXURY');
    });

    test('explicit tier wins over category, case-insensitively', () {
      expect(gift(category: 'Luxury', tier: 'NORMAL').animationTier, 'NORMAL');
      expect(gift(category: 'Normal', tier: 'medium').animationTier, 'MEDIUM');
    });

    test('garbage tier falls back to category derivation', () {
      expect(gift(category: 'Normal', tier: 'BANANA').animationTier, 'NORMAL');
      expect(gift(category: 'Luxury', tier: 'BANANA').animationTier, 'LUXURY');
    });
  });

  test('fromMap reads documented spec aliases', () {
    final m = gift(from: {
      'name': 'Phoenix',
      'category': 'Luxury',
      'price_diamonds': 5000,
      'animation_type': 'SVGA',
      'animation_url': 'https://cdn/phoenix.svga',
      'duration_ms': 8000,
      'isActive': true,
    });
    expect(m.priceInDiamonds, 5000);
    expect(m.animationFormat, 'SVGA');
    expect(m.lottieAssetPath, 'https://cdn/phoenix.svga');
    expect(m.durationMs, 8000);
    expect(m.animationTier, 'LUXURY');
  });

  test('canonical fields and tier/duration round-trip through fromMap', () {
    final m = gift(from: {
      'name': 'Rose',
      'category': 'Normal',
      'priceInDiamonds': 50,
      'tier': 'MEDIUM',
      'durationMs': 4000,
      'animationFormat': 'json',
      'lottieAssetPath': 'https://cdn/rose.json',
      'isActive': true,
    });
    expect(m.tier, 'MEDIUM');
    expect(m.durationMs, 4000);
    expect(m.animationTier, 'MEDIUM');
    expect(m.toMap()['tier'], 'MEDIUM');
    expect(m.toMap()['durationMs'], 4000);
  });
}
