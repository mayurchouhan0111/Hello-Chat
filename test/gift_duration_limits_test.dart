import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/constants/gift_vap_catalog.dart';
import 'package:hello_chat/core/utils/svga_parser_util.dart';

void main() {
  group('GiftVapCatalog.effectivePlaybackMs', () {
    test('NORMAL target 5000ms with 6000ms hard cap', () {
      expect(GiftVapCatalog.effectivePlaybackMs(tier: 'NORMAL', assetDurationMs: 1250), 5000);
      expect(GiftVapCatalog.effectivePlaybackMs(tier: 'NORMAL', assetDurationMs: 2667), 5000);
      expect(GiftVapCatalog.effectivePlaybackMs(tier: 'NORMAL', assetDurationMs: 4500), 4500);
      expect(GiftVapCatalog.effectivePlaybackMs(tier: 'NORMAL', assetDurationMs: 6667), 6000);
      expect(GiftVapCatalog.effectivePlaybackMs(tier: 'NORMAL', assetDurationMs: 5000), 5000);
      expect(GiftVapCatalog.effectivePlaybackMs(tier: 'NORMAL', assetDurationMs: 6000), 6000);
    });

    test('MEDIUM target 10000ms with 10500ms hard cap', () {
      expect(GiftVapCatalog.effectivePlaybackMs(tier: 'MEDIUM', assetDurationMs: 3067), 10000);
      expect(GiftVapCatalog.effectivePlaybackMs(tier: 'MEDIUM', assetDurationMs: 7800), 10000);
      expect(GiftVapCatalog.effectivePlaybackMs(tier: 'MEDIUM', assetDurationMs: 9600), 9600);
      expect(GiftVapCatalog.effectivePlaybackMs(tier: 'MEDIUM', assetDurationMs: 10000), 10000);
      expect(GiftVapCatalog.effectivePlaybackMs(tier: 'MEDIUM', assetDurationMs: 10500), 10500);
    });

    test('LUXURY floors at 15000ms and unknown tiers keep the asset duration', () {
      expect(GiftVapCatalog.effectivePlaybackMs(tier: 'LUXURY', assetDurationMs: 15567), 15567);
      expect(GiftVapCatalog.effectivePlaybackMs(tier: 'LUXURY', assetDurationMs: 1000), 15000);
      expect(GiftVapCatalog.effectivePlaybackMs(tier: 'UNKNOWN', assetDurationMs: 1234), 1234);
    });
  });

  group('GiftVapCatalog.isDurationEnforced', () {
    test('enforced shelf categories are case-insensitive', () {
      for (final category in ['Normal', 'normal', 'NORMAL', 'Medium', 'MEDIUM', 'VAP', 'vap', 'SVGA', 'svga']) {
        expect(GiftVapCatalog.isDurationEnforced(category), isTrue, reason: category);
      }
    });

    test('CP, Lucky, VIP, SVIP and Luxury are excluded', () {
      for (final category in ['CP', 'Lucky', 'VIP', 'SVIP', 'Luxury', 'Relationship', 'Special']) {
        expect(GiftVapCatalog.isDurationEnforced(category), isFalse, reason: category);
      }
    });
  });

  group('Known Firestore Normal/Medium gifts play inside product bounds', () {
    final cases = <({
      String name,
      String category,
      String tier,
      int assetMs,
      int minMs,
      int maxMs,
    })>[
      (name: 'Golden Dates', category: 'Normal', tier: 'NORMAL', assetMs: 1250, minMs: 4500, maxMs: 6000),
      (name: 'E2E Lottie', category: 'Normal', tier: 'NORMAL', assetMs: 5000, minMs: 4500, maxMs: 6000),
      (name: 'Balloon', category: 'Normal', tier: 'NORMAL', assetMs: 2667, minMs: 4500, maxMs: 6000),
      (name: 'Cake', category: 'Normal', tier: 'NORMAL', assetMs: 2000, minMs: 4500, maxMs: 6000),
      (name: 'Cat Gift', category: 'Normal', tier: 'NORMAL', assetMs: 4000, minMs: 4500, maxMs: 6000),
      (name: 'New Game', category: 'Normal', tier: 'NORMAL', assetMs: 5000, minMs: 4500, maxMs: 6000),
      (name: 'Sweet Bloom', category: 'Normal', tier: 'NORMAL', assetMs: 5000, minMs: 4500, maxMs: 6000),
      (name: 'Mini Rose', category: 'Normal', tier: 'NORMAL', assetMs: 5333, minMs: 4500, maxMs: 6000),
      (name: 'Twinkle Star', category: 'Normal', tier: 'NORMAL', assetMs: 6000, minMs: 4500, maxMs: 6000),
      (name: 'Candy Heart', category: 'Normal', tier: 'NORMAL', assetMs: 6667, minMs: 4500, maxMs: 6000),
      (name: 'Sweet Romance', category: 'Medium', tier: 'MEDIUM', assetMs: 5000, minMs: 9000, maxMs: 10500),
      (name: 'heart', category: 'Medium', tier: 'MEDIUM', assetMs: 3500, minMs: 9000, maxMs: 10500),
      (name: 'Ruby Excalibur', category: 'Medium', tier: 'MEDIUM', assetMs: 5042, minMs: 9000, maxMs: 10500),
      (name: 'Gourmet Feast', category: 'VAP', tier: 'MEDIUM', assetMs: 3067, minMs: 9000, maxMs: 10500),
      (name: 'Love You', category: 'SVGA', tier: 'MEDIUM', assetMs: 7120, minMs: 9000, maxMs: 10500),
    ];

    for (final c in cases) {
      test('${c.name} (asset ${c.assetMs}ms)', () {
        expect(GiftVapCatalog.isDurationEnforced(c.category), isTrue, reason: c.name);
        final int playback = GiftVapCatalog.effectivePlaybackMs(
          tier: c.tier,
          assetDurationMs: c.assetMs,
        );
        expect(
          playback,
          inInclusiveRange(c.minMs, c.maxMs),
          reason: '${c.name} playback ${playback}ms outside ${c.minMs}-${c.maxMs}ms',
        );
      });
    }
  });

  group('Bundled VAP durations match the catalog', () {
    for (final spec in GiftVapCatalog.all) {
      test('${spec.giftId} (${spec.assetPath})', () {
        final file = File(spec.assetPath);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Missing bundled VAP file: ${spec.assetPath}',
        );

        final int measured =
            SvgaParserUtil.parseVapOrMp4DurationMs(file.readAsBytesSync());
        expect(
          measured,
          greaterThan(0),
          reason:
              'Parser returned 0 for ${spec.giftId} (${spec.assetPath}); the file is missing a vapc header or mvhd box',
        );
        expect(
          (measured - spec.durationMs).abs(),
          lessThanOrEqualTo(50),
          reason:
              '${spec.giftId} catalog=${spec.durationMs}ms measured=${measured}ms (tolerance 50ms)',
        );
      });
    }
  });
}
