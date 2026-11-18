import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/utils/rocket_vap_config.dart';
import 'package:hello_chat/core/widgets/vap_player.dart';
import 'package:tancent_vap/tancent_vap.dart';

void main() {
  group('Rocket VAP Avatar Configuration Tests', () {
    test('RocketVapConfig paths map correctly for all 5 levels', () {
      expect(RocketVapConfig.vapAssetPath(0, variant: 2), 'assets/animations/VAP/a (2).mp4');
      expect(RocketVapConfig.vapAssetPath(1, variant: 2), 'assets/animations/VAP/b (2).mp4');
      expect(RocketVapConfig.vapAssetPath(2, variant: 2), 'assets/animations/VAP/c (2).mp4');
      expect(RocketVapConfig.vapAssetPath(3, variant: 3), 'assets/animations/VAP/d (3).mp4');
      expect(RocketVapConfig.vapAssetPath(4, variant: 3), 'assets/animations/VAP/e (3).mp4');
    });

    testWidgets('VapAnimation instantiates with profileImageUrl and sets up VapView', (tester) async {
      const testAvatarUrl = 'https://example.com/test_avatar.jpg';
      const testAssetPath = 'assets/animations/VAP/a (2).mp4';

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VapAnimation(
            assetPath: testAssetPath,
            profileImageUrl: testAvatarUrl,
            loop: true,
          ),
        ),
      );

      final vapViewFinder = find.byType(VapView);
      expect(vapViewFinder, findsOneWidget);

      final vapView = tester.widget<VapView>(vapViewFinder);
      expect(vapView.vapTagContents, isNotNull);
      expect(vapView.vapTagContents!['user'], isA<ImageURLContent>());
      expect((vapView.vapTagContents!['user'] as ImageURLContent).url, testAvatarUrl);
      expect(vapView.vapTagContents!['avatar'], isA<ImageURLContent>());
      expect(vapView.vapTagContents!['headimg'], isA<ImageURLContent>());
    });
  });
}
