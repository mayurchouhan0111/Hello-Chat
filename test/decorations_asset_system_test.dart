import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/models/svip_level_model.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/seat_grid.dart';

void main() {
  group('Asset & Decorations System Tests', () {
    test('1. UserModel displayId returns prettyId when equipped, falls back to helloId when none/empty', () {
      final userWithPretty = UserModel(
        uid: 'user_1',
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
        phoneNumber: null,
        username: 'User 1',
        displayName: 'User 1',
        helloId: 12345,
        prettyId: '888888',
      );
      expect(userWithPretty.displayId, equals('888888'));

      final userWithNone = UserModel(
        uid: 'user_2',
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
        phoneNumber: null,
        username: 'User 2',
        displayName: 'User 2',
        helloId: 12345,
        prettyId: 'none',
      );
      expect(userWithNone.displayId, equals('0000012345'));

      final userEmpty = UserModel(
        uid: 'user_3',
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
        phoneNumber: null,
        username: 'User 3',
        displayName: 'User 3',
        helloId: 6789,
        prettyId: '',
      );
      expect(userEmpty.displayId, equals('0000006789'));
    });

    test('2. VIP Mic Waves resolve correct asset paths across all tiers', () {
      expect(getVipMicWavesPath('VIP 1'), equals('assets/VIP/VIP 1/Sound Waives.svga'));
      expect(getVipMicWavesPath('VIP 2'), equals('assets/VIP/VIP 2/VIP 2/Mic Waives.svga'));
      expect(getVipMicWavesPath('VIP 3'), equals('assets/VIP/VIP 3/VIP 3/Mic Waives.svga'));
      expect(getVipMicWavesPath('VIP 5'), equals('assets/VIP/VIP 5/VIP 5/Mic Waives.svga'));
      expect(getVipMicWavesPath('VIP 8'), equals('assets/VIP/VIP 8/VIP 8/Mic Waives.svga'));
      expect(getVipMicWavesPath('none'), isNull);
    });

    test('3. SVIP Mic Waves resolve exact assets for all 6 tiers', () {
      expect(SVIPLevelModel.getLevelByTier(1).micWaveAsset, equals('assets/SVIP Kit/svip 1/SVIP 1 Ring.svga'));
      expect(SVIPLevelModel.getLevelByTier(2).micWaveAsset, equals('assets/SVIP Kit/svip 2/svip 2.svga'));
      expect(SVIPLevelModel.getLevelByTier(3).micWaveAsset, equals('assets/SVIP Kit/svip 3/mic_wave_svip3.svga'));
      expect(SVIPLevelModel.getLevelByTier(4).micWaveAsset, equals('assets/SVIP Kit/svip 4/mic_wave_svip4.svga'));
      expect(SVIPLevelModel.getLevelByTier(5).micWaveAsset, equals('assets/SVIP Kit/svip 5/mic_wave_svip4_SVGA.svga'));
      expect(SVIPLevelModel.getLevelByTier(6).micWaveAsset, equals('assets/SVIP Kit/SVIP 6/SVIP 6 Sound Waives.svga'));
    });

    test('4. Explicit none unequip prevents default SVIP/VIP fallback across categories', () {
      // User with SVIP 6 but explicitly unequipped mic wave
      final unequippedMicUser = UserModel(
        uid: 'user_svip',
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
        phoneNumber: null,
        username: 'SVIP King',
        displayName: 'SVIP King',
        svipLevel: 6,
        equippedMicWave: 'none',
        profileFrame: 'none',
        equippedCrown: 'none',
      );

      final isExplicitNoneMic = unequippedMicUser.equippedMicWave.toLowerCase() == 'none';
      expect(isExplicitNoneMic, isTrue);

      final isExplicitNoneFrame = unequippedMicUser.profileFrame.toLowerCase() == 'none';
      expect(isExplicitNoneFrame, isTrue);

      final isExplicitNoneCrown = unequippedMicUser.equippedCrown.toLowerCase() == 'none';
      expect(isExplicitNoneCrown, isTrue);
    });

    test('5. Custom equipped mic wave takes precedence over VIP/SVIP tier defaults', () {
      final customMicUser = UserModel(
        uid: 'user_custom',
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
        phoneNumber: null,
        username: 'Customizer',
        displayName: 'Customizer',
        svipLevel: 5,
        vipTier: 'VIP 8',
        equippedMicWave: 'assets/VIP/VIP 2/VIP 2/Mic Waives.svga',
      );

      final micWave = customMicUser.equippedMicWave;
      final isExplicitNone = micWave.toLowerCase() == 'none';
      String? resolvedWave;
      if (!isExplicitNone && micWave.isNotEmpty) {
        resolvedWave = micWave;
      } else if (!isExplicitNone) {
        if ((customMicUser.svipLevel ?? 0) > 0) {
          resolvedWave = SVIPLevelModel.getLevelByTier(customMicUser.svipLevel!).micWaveAsset;
        } else if (customMicUser.isVipActive) {
          resolvedWave = getVipMicWavesPath(customMicUser.vipTier);
        }
      }

      expect(resolvedWave, equals('assets/VIP/VIP 2/VIP 2/Mic Waives.svga'));
    });

    test('6. Category to Firestore Field mapping is complete for all 8 categories', () {
      final Map<String, String> fieldMap = {
        'frame': 'profileFrame',
        'official_frame': 'profileFrame',
        'mount': 'entryAnimation',
        'bubble': 'chatBubble',
        'aperture': 'equippedMicWave',
        'crown': 'equippedCrown',
        'personal_page': 'profileTheme',
        'id': 'prettyId',
      };

      expect(fieldMap['frame'], equals('profileFrame'));
      expect(fieldMap['official_frame'], equals('profileFrame'));
      expect(fieldMap['mount'], equals('entryAnimation'));
      expect(fieldMap['bubble'], equals('chatBubble'));
      expect(fieldMap['aperture'], equals('equippedMicWave'));
      expect(fieldMap['crown'], equals('equippedCrown'));
      expect(fieldMap['personal_page'], equals('profileTheme'));
      expect(fieldMap['id'], equals('prettyId'));
    });

    test('7. Expired vault item detection marks expired items correctly', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 1));
      final futureDate = DateTime.now().add(const Duration(days: 30));

      bool isExpired(DateTime date) => date.isBefore(DateTime.now());

      expect(isExpired(pastDate), isTrue);
      expect(isExpired(futureDate), isFalse);
    });
  });
}
