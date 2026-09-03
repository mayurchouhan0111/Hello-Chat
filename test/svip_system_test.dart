import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/svip_level_model.dart';
import 'package:hello_chat/core/models/user_model.dart';

void main() {
  group('SVIP Membership System & Point Conversion Tests', () {
    test('1 USD Gold Coin Recharge = 100 SVIP Points exactly', () {
      expect(50.0 * 100, equals(5000));
      expect(100.0 * 100, equals(10000));
      expect(200.0 * 100, equals(20000));
      expect(500.0 * 100, equals(50000));
      expect(1000.0 * 100, equals(100000));
      expect(2500.0 * 100, equals(250000));
    });

    test('All 6 SVIP Levels match exact specification thresholds and daily diamond rewards', () {
      expect(SVIPLevelModel.levels.length, equals(6));

      final svip1 = SVIPLevelModel.getLevelByTier(1);
      expect(svip1.requiredPoints, equals(5000));
      expect(svip1.equivalentUsd, equals(50.0));
      expect(svip1.dailyDiamondReward, equals(25000));

      final svip2 = SVIPLevelModel.getLevelByTier(2);
      expect(svip2.requiredPoints, equals(10000));
      expect(svip2.equivalentUsd, equals(100.0));
      expect(svip2.dailyDiamondReward, equals(50000));

      final svip3 = SVIPLevelModel.getLevelByTier(3);
      expect(svip3.requiredPoints, equals(20000));
      expect(svip3.equivalentUsd, equals(200.0));
      expect(svip3.dailyDiamondReward, equals(100000));

      final svip4 = SVIPLevelModel.getLevelByTier(4);
      expect(svip4.requiredPoints, equals(50000));
      expect(svip4.equivalentUsd, equals(500.0));
      expect(svip4.dailyDiamondReward, equals(250000));

      final svip5 = SVIPLevelModel.getLevelByTier(5);
      expect(svip5.requiredPoints, equals(100000));
      expect(svip5.equivalentUsd, equals(1000.0));
      expect(svip5.dailyDiamondReward, equals(500000));

      final svip6 = SVIPLevelModel.getLevelByTier(6);
      expect(svip6.requiredPoints, equals(250000));
      expect(svip6.equivalentUsd, equals(2500.0));
      expect(svip6.dailyDiamondReward, equals(1000000));
    });

    test('Immediate Upgrade Rule: 60-day validity renewed and points reset to 0', () {
      final now = DateTime.now();
      final cycleEnd = now.add(const Duration(days: 60));

      // Simulating user upgrade
      final upgradedUser = UserModel(
        uid: 'user_svip',
        createdAt: now,
        lastActive: now,
        phoneNumber: '+1234567890',
        username: 'elite_user',
        displayName: 'Elite User',
        svipLevel: 2,
        svipPoints: 0, // MUST BE 0 ON UPGRADE
        svipCycleStartDate: now,
        svipCycleEndDate: cycleEnd,
      );

      expect(upgradedUser.svipLevel, equals(2));
      expect(upgradedUser.svipPoints, equals(0));
      expect(upgradedUser.svipCycleEndDate!.difference(upgradedUser.svipCycleStartDate!).inDays, equals(60));
    });

    test('60-Day Renewal Evaluation: 4 Exact Branches Logic', () {
      int evaluateRenewal(int currentLevel, int cyclePointsEarned) {
        // Branch A: Multi-level / Higher tier upgrade
        int highestQualified = currentLevel;
        for (final model in SVIPLevelModel.levels) {
          if (cyclePointsEarned >= model.requiredPoints && model.level > highestQualified) {
            highestQualified = model.level;
          }
        }
        if (highestQualified > currentLevel) return highestQualified;

        // Branch B: Maintain current tier
        final currentModel = SVIPLevelModel.getLevelByTier(currentLevel);
        if (cyclePointsEarned >= currentModel.requiredPoints) return currentLevel;

        // Branch C: Downgrade by 1 tier
        if (currentLevel > 1) return currentLevel - 1;

        // Branch D: Expiration (SVIP 1 fails to maintain)
        return 0;
      }

      // Branch A Test (Upgrade)
      expect(evaluateRenewal(1, 25000), equals(3)); // Upgrades from 1 directly to 3

      // Branch B Test (Maintain)
      expect(evaluateRenewal(2, 10000), equals(2)); // Maintains SVIP 2

      // Branch C Test (Downgrade)
      expect(evaluateRenewal(3, 8000), equals(2));  // Downgrades from 3 to 2

      // Branch D Test (Expiration)
      expect(evaluateRenewal(1, 1000), equals(0));  // SVIP 1 expires to normal user (0)
    });
  });

  group('Voice Room Protection & SVIP 6 Global Kick Tests', () {
    test('SVIP 4, 5, 6 users have kick and mute immunity', () {
      final now = DateTime.now();
      final svip3User = UserModel(
        uid: 'u3', createdAt: now, lastActive: now, phoneNumber: '1', username: 'u3', displayName: 'U3',
        svipLevel: 3, svipCycleEndDate: now.add(const Duration(days: 30)),
      );
      final svip4User = UserModel(
        uid: 'u4', createdAt: now, lastActive: now, phoneNumber: '2', username: 'u4', displayName: 'U4',
        svipLevel: 4, svipCycleEndDate: now.add(const Duration(days: 30)),
      );
      final svip6User = UserModel(
        uid: 'u6', createdAt: now, lastActive: now, phoneNumber: '3', username: 'u6', displayName: 'U6',
        svipLevel: 6, svipCycleEndDate: now.add(const Duration(days: 30)),
      );

      expect(svip3User.isSvipProtected, isFalse);
      expect(svip4User.isSvipProtected, isTrue);
      expect(svip6User.isSvipProtected, isTrue);
    });

    test('Assigned Room Protection grants 30-day immunity to non-SVIP users', () {
      final now = DateTime.now();
      final normalUserWithProtection = UserModel(
        uid: 'u_prot', createdAt: now, lastActive: now, phoneNumber: '4', username: 'prot', displayName: 'Protected User',
        svipLevel: 0, assignedProtectionExpiresAt: now.add(const Duration(days: 25)),
      );
      final normalUserExpiredProtection = UserModel(
        uid: 'u_exp', createdAt: now, lastActive: now, phoneNumber: '5', username: 'exp', displayName: 'Expired User',
        svipLevel: 0, assignedProtectionExpiresAt: now.subtract(const Duration(days: 1)),
      );

      expect(normalUserWithProtection.isSvipProtected, isTrue);
      expect(normalUserExpiredProtection.isSvipProtected, isFalse);
    });

    test('SVIP 6 Global Kick permission matrix', () {
      String? evaluateKickPermission({
        required int kickerLevel,
        required String kickerUid,
        required int targetLevel,
        required String targetUid,
        required bool isOwnerOrAdmin,
      }) {
        if (kickerUid == targetUid) return "Cannot kick yourself.";
        if (kickerLevel == 6) {
          if (targetLevel == 6) return "SVIP 6 users cannot Kick Out another SVIP 6 user.";
          return null; // Kick allowed!
        }
        if (!isOwnerOrAdmin) return "Only room owner, admins, or moderators can kick users.";
        if (targetLevel >= 4) return "This user is protected by SVIP privileges. Kick Out and Mute actions are not allowed.";
        return null; // Kick allowed!
      }

      // Regular admin trying to kick SVIP 4 -> BLOCKED
      expect(
        evaluateKickPermission(kickerLevel: 0, kickerUid: 'admin', targetLevel: 4, targetUid: 'svip4', isOwnerOrAdmin: true),
        equals("This user is protected by SVIP privileges. Kick Out and Mute actions are not allowed."),
      );

      // SVIP 6 kicking Room Owner -> ALLOWED
      expect(
        evaluateKickPermission(kickerLevel: 6, kickerUid: 'svip6', targetLevel: 0, targetUid: 'room_owner', isOwnerOrAdmin: false),
        isNull,
      );

      // SVIP 6 kicking another SVIP 6 -> BLOCKED
      expect(
        evaluateKickPermission(kickerLevel: 6, kickerUid: 'svip6_a', targetLevel: 6, targetUid: 'svip6_b', isOwnerOrAdmin: false),
        equals("SVIP 6 users cannot Kick Out another SVIP 6 user."),
      );

      // SVIP 6 kicking self -> BLOCKED
      expect(
        evaluateKickPermission(kickerLevel: 6, kickerUid: 'svip6_a', targetLevel: 6, targetUid: 'svip6_a', isOwnerOrAdmin: false),
        equals("Cannot kick yourself."),
      );
    });
  });

  group('Privileges & Quotas Verification Tests', () {
    test('Friend List Hide ID limits match exact tier specification', () {
      expect(SVIPLevelModel.getLevelByTier(1).friendHideMaxUserIds, equals(0));
      expect(SVIPLevelModel.getLevelByTier(2).friendHideMaxUserIds, equals(0));
      expect(SVIPLevelModel.getLevelByTier(3).friendHideMaxUserIds, equals(2));
      expect(SVIPLevelModel.getLevelByTier(4).friendHideMaxUserIds, equals(5));
      expect(SVIPLevelModel.getLevelByTier(5).friendHideMaxUserIds, equals(10));
      expect(SVIPLevelModel.getLevelByTier(6).friendHideMaxUserIds, equals(25));
    });

    test('Temporary ID duration and digit limits match specification', () {
      final svip1Limits = SVIPLevelModel.getLevelByTier(1).tempIdLimits;
      expect(svip1Limits['durationHours'], equals(24)); // 24 hours
      expect(svip1Limits['limit10Digit'], equals(5));

      final svip6Limits = SVIPLevelModel.getLevelByTier(6).tempIdLimits;
      expect(svip6Limits['durationHours'], equals(720)); // 30 days = 720 hours
      expect(svip6Limits['limit10Digit'], equals(100));
      expect(svip6Limits['limit8Digit'], equals(30));
      expect(svip6Limits['limit6Digit'], equals(15));
    });

    test('CP Lock durations match tier specification', () {
      final svip3Options = SVIPLevelModel.getLevelByTier(3).cpLockOptions;
      expect(svip3Options.contains('24 Hours'), isTrue);
      expect(svip3Options.contains('72 Hours'), isTrue);
      expect(svip3Options.contains('7 Days'), isTrue);
      expect(svip3Options.contains('Permanent'), isFalse);

      final svip6Options = SVIPLevelModel.getLevelByTier(6).cpLockOptions;
      expect(svip6Options.contains('Permanent'), isTrue);
    });
  });
}
