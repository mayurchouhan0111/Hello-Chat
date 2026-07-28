class SVIPLevelModel {
  final int level;
  final String name;
  final int requiredPoints;
  final double equivalentUsd;
  final int validityDays;
  final int dailyDiamondReward;
  final String description;

  const SVIPLevelModel({
    required this.level,
    required this.name,
    required this.requiredPoints,
    required this.equivalentUsd,
    this.validityDays = 60,
    required this.dailyDiamondReward,
    this.description = 'Elite Status privileges unlocked.',
  });

  static const List<SVIPLevelModel> levels = [
    SVIPLevelModel(
      level: 1,
      name: 'SVIP 1',
      requiredPoints: 5000,
      equivalentUsd: 50.0,
      dailyDiamondReward: 25000,
      description: 'Family Battle Name privilege & 25,000 Daily Diamonds.',
    ),
    SVIPLevelModel(
      level: 2,
      name: 'SVIP 2',
      requiredPoints: 10000,
      equivalentUsd: 100.0,
      dailyDiamondReward: 50000,
      description: 'Family Logo edit privilege & 50,000 Daily Diamonds.',
    ),
    SVIPLevelModel(
      level: 3,
      name: 'SVIP 3',
      requiredPoints: 20000,
      equivalentUsd: 200.0,
      dailyDiamondReward: 100000,
      description: 'Friend Hide (2 IDs), CP Lock options & 100,000 Daily Diamonds.',
    ),
    SVIPLevelModel(
      level: 4,
      name: 'SVIP 4',
      requiredPoints: 50000,
      equivalentUsd: 500.0,
      dailyDiamondReward: 250000,
      description: 'Profile Hide (Self), Room Protection & 250,000 Daily Diamonds.',
    ),
    SVIPLevelModel(
      level: 5,
      name: 'SVIP 5',
      requiredPoints: 100000,
      equivalentUsd: 1000.0,
      dailyDiamondReward: 500000,
      description: 'Profile Hide (+2 IDs), Protection Delegation & 500,000 Daily Diamonds.',
    ),
    SVIPLevelModel(
      level: 6,
      name: 'SVIP 6',
      requiredPoints: 250000,
      equivalentUsd: 2500.0,
      dailyDiamondReward: 1000000,
      description: 'Global Room Kick, 5 CP Removal Requests & 1,000,000 Daily Diamonds.',
    ),
  ];

  static SVIPLevelModel getLevelByPoints(int points) {
    SVIPLevelModel current = levels.first;
    for (var level in levels) {
      if (points >= level.requiredPoints) {
        current = level;
      } else {
        break;
      }
    }
    return current;
  }

  static SVIPLevelModel getLevelByTier(int tier) {
    if (tier <= 0) return levels.first;
    if (tier > levels.length) return levels.last;
    return levels.firstWhere((l) => l.level == tier, orElse: () => levels.first);
  }

  // Privilege Helpers
  int get friendHideMaxUserIds {
    switch (level) {
      case 3: return 2;
      case 4: return 5;
      case 5: return 10;
      case 6: return 25;
      default: return 0;
    }
  }

  int get profileHideMaxUserIds {
    switch (level) {
      case 4: return 1; // Self only
      case 5: return 3; // Self + 2 additional
      case 6: return 11; // Self + 10 additional
      default: return 0;
    }
  }

  bool get hasRoomProtection => level >= 4;

  int get protectionDelegationMaxUsers {
    switch (level) {
      case 5: return 5;
      case 6: return 10;
      default: return 0;
    }
  }

  bool get hasGlobalKickPermission => level == 6;

  List<String> get cpLockOptions {
    switch (level) {
      case 3:
        return ['24 Hours', '72 Hours', '7 Days'];
      case 4:
        return ['24 Hours', '72 Hours', '7 Days', '30 Days'];
      case 5:
      case 6:
        return ['24 Hours', '72 Hours', '7 Days', '30 Days', 'Permanent'];
      default:
        return [];
    }
  }

  int get cpRemoveRequestLimit => level == 6 ? 5 : 0;

  Map<String, int> get tempIdLimits {
    switch (level) {
      case 1:
        return {'maxTargetIds': 5, 'durationHours': 24, 'limit10Digit': 5, 'limit8Digit': 2, 'limit6Digit': 1};
      case 2:
        return {'maxTargetIds': 7, 'durationHours': 72, 'limit10Digit': 7, 'limit8Digit': 3, 'limit6Digit': 1};
      case 3:
        return {'maxTargetIds': 10, 'durationHours': 168, 'limit10Digit': 10, 'limit8Digit': 5, 'limit6Digit': 2};
      case 4:
        return {'maxTargetIds': 25, 'durationHours': 360, 'limit10Digit': 25, 'limit8Digit': 10, 'limit6Digit': 5};
      case 5:
        return {'maxTargetIds': 50, 'durationHours': 720, 'limit10Digit': 50, 'limit8Digit': 20, 'limit6Digit': 10};
      case 6:
        return {'maxTargetIds': 100, 'durationHours': 720, 'limit10Digit': 100, 'limit8Digit': 30, 'limit6Digit': 15};
      default:
        return {'maxTargetIds': 0, 'durationHours': 0, 'limit10Digit': 0, 'limit8Digit': 0, 'limit6Digit': 0};
    }
  }

  Map<String, int> get bannerLimits {
    switch (level) {
      case 1: return {'24h': 1, '72h': 0, '7d': 0};
      case 2: return {'24h': 3, '72h': 0, '7d': 0};
      case 3: return {'24h': 5, '72h': 3, '7d': 0};
      case 4: return {'24h': 10, '72h': 5, '7d': 0};
      case 5: return {'24h': 20, '72h': 10, '7d': 2};
      case 6: return {'24h': 25, '72h': 10, '7d': 5};
      default: return {'24h': 0, '72h': 0, '7d': 0};
    }
  }
}

