import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class TagLevelInfo {
  final int level;
  final String label;
  final String hexColor;
  final int threshold;

  const TagLevelInfo({
    required this.level,
    required this.label,
    required this.hexColor,
    required this.threshold,
  });
}

class DynamicTagConfig {
  final Map<int, int> hostThresholds;
  final Map<int, String> hostColors;
  final Map<int, int> agencyThresholds;
  final Map<int, String> agencyColors;

  DynamicTagConfig({
    required this.hostThresholds,
    required this.hostColors,
    required this.agencyThresholds,
    required this.agencyColors,
  });

  factory DynamicTagConfig.defaultConfig() {
    return DynamicTagConfig(
      hostThresholds: {
        1: 0,
        2: 200000,
        3: 500000,
        4: 1000000,
        5: 2500000,
      },
      hostColors: {
        1: '#4A90E2',
        2: '#9013FE',
        3: '#F5A623',
        4: '#D0021B',
        5: '#7ED321',
      },
      agencyThresholds: {
        1: 0,
        2: 500000,
        3: 1500000,
        4: 3000000,
        5: 5000000,
      },
      agencyColors: {
        1: '#20B2AA',
        2: '#8A2BE2',
        3: '#FF7F50',
        4: '#FF1493',
        5: '#FFD700',
      },
    );
  }

  factory DynamicTagConfig.fromFirestore(Map<String, dynamic> data) {
    Map<int, int> parseThresholds(Map<String, dynamic>? map, Map<int, int> fallback) {
      if (map == null) return fallback;
      final result = <int, int>{};
      for (int i = 1; i <= 5; i++) {
        result[i] = (map['level$i'] as num?)?.toInt() ?? fallback[i]!;
      }
      return result;
    }

    Map<int, String> parseColors(Map<String, dynamic>? map, Map<int, String> fallback) {
      if (map == null) return fallback;
      final result = <int, String>{};
      for (int i = 1; i <= 5; i++) {
        result[i] = (map['level$i'] as String?) ?? fallback[i]!;
      }
      return result;
    }

    final fallback = DynamicTagConfig.defaultConfig();
    return DynamicTagConfig(
      hostThresholds: parseThresholds(data['hostThresholds'] as Map<String, dynamic>?, fallback.hostThresholds),
      hostColors: parseColors(data['hostColors'] as Map<String, dynamic>?, fallback.hostColors),
      agencyThresholds: parseThresholds(data['agencyThresholds'] as Map<String, dynamic>?, fallback.agencyThresholds),
      agencyColors: parseColors(data['agencyColors'] as Map<String, dynamic>?, fallback.agencyColors),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hostThresholds': {
        'level1': hostThresholds[1],
        'level2': hostThresholds[2],
        'level3': hostThresholds[3],
        'level4': hostThresholds[4],
        'level5': hostThresholds[5],
      },
      'hostColors': {
        'level1': hostColors[1],
        'level2': hostColors[2],
        'level3': hostColors[3],
        'level4': hostColors[4],
        'level5': hostColors[5],
      },
      'agencyThresholds': {
        'level1': agencyThresholds[1],
        'level2': agencyThresholds[2],
        'level3': agencyThresholds[3],
        'level4': agencyThresholds[4],
        'level5': agencyThresholds[5],
      },
      'agencyColors': {
        'level1': agencyColors[1],
        'level2': agencyColors[2],
        'level3': agencyColors[3],
        'level4': agencyColors[4],
        'level5': agencyColors[5],
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class DynamicTagService extends ChangeNotifier {
  static final DynamicTagService instance = DynamicTagService._internal();
  DynamicTagService._internal() {
    _initListener();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DynamicTagConfig _config = DynamicTagConfig.defaultConfig();
  DynamicTagConfig get config => _config;

  void _initListener() {
    _firestore.collection('system_config').doc('dynamic_tags').snapshots().listen((doc) {
      if (doc.exists && doc.data() != null) {
        _config = DynamicTagConfig.fromFirestore(doc.data()!);
        notifyListeners();
      }
    }, onError: (err) {
      debugPrint('Error listening to dynamic tag config: $err');
    });
  }

  /// Calculates Host Level Tag (1-5) based on current diamond earnings
  TagLevelInfo getHostTagInfo(int diamondsEarned) {
    int currentLevel = 1;
    for (int lvl = 5; lvl >= 1; lvl--) {
      final target = _config.hostThresholds[lvl] ?? 0;
      if (diamondsEarned >= target) {
        currentLevel = lvl;
        break;
      }
    }

    return TagLevelInfo(
      level: currentLevel,
      label: 'Host L$currentLevel',
      hexColor: _config.hostColors[currentLevel] ?? '#4A90E2',
      threshold: _config.hostThresholds[currentLevel] ?? 0,
    );
  }

  /// Calculates Agency Level Tag (1-5) based on current agency diamond earnings
  TagLevelInfo getAgencyTagInfo(int diamondsEarned) {
    int currentLevel = 1;
    for (int lvl = 5; lvl >= 1; lvl--) {
      final target = _config.agencyThresholds[lvl] ?? 0;
      if (diamondsEarned >= target) {
        currentLevel = lvl;
        break;
      }
    }

    return TagLevelInfo(
      level: currentLevel,
      label: 'Agency L$currentLevel',
      hexColor: _config.agencyColors[currentLevel] ?? '#20B2AA',
      threshold: _config.agencyThresholds[currentLevel] ?? 0,
    );
  }
}
