import 'package:cloud_firestore/cloud_firestore.dart';

enum RelationshipType { friendship, cp }
enum RelationshipStatus { active, ended }

class RelationshipModel {
  final String id;
  final List<String> participants;
  final RelationshipType type;
  final RelationshipStatus status;
  final int intimacy;
  final int level;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime lastActivityAt;
  final Map<String, dynamic> intimacyBreakdown;

  RelationshipModel({
    required this.id,
    required this.participants,
    required this.type,
    this.status = RelationshipStatus.active,
    this.intimacy = 0,
    this.level = 1,
    required this.startedAt,
    this.endedAt,
    required this.lastActivityAt,
    this.intimacyBreakdown = const {},
  });

  factory RelationshipModel.fromMap(Map<String, dynamic> data, String docId) {
    return RelationshipModel(
      id: docId,
      participants: List<String>.from(data['participants'] ?? []),
      type: data['type'] == 'cp' ? RelationshipType.cp : RelationshipType.friendship,
      status: data['status'] == 'ended' ? RelationshipStatus.ended : RelationshipStatus.active,
      intimacy: (data['intimacy'] as num? ?? 0).toInt(),
      level: (data['level'] as num? ?? 1).toInt(),
      startedAt: (data['startedAt'] as dynamic) is Timestamp
          ? (data['startedAt'] as Timestamp).toDate()
          : DateTime.now(),
      endedAt: data['endedAt'] != null
          ? (data['endedAt'] as Timestamp).toDate()
          : null,
      lastActivityAt: (data['lastActivityAt'] as dynamic) is Timestamp
          ? (data['lastActivityAt'] as Timestamp).toDate()
          : DateTime.now(),
      intimacyBreakdown: Map<String, dynamic>.from(data['intimacyBreakdown'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'type': type == RelationshipType.cp ? 'cp' : 'friendship',
      'status': status == RelationshipStatus.ended ? 'ended' : 'active',
      'intimacy': intimacy,
      'level': level,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'lastActivityAt': Timestamp.fromDate(lastActivityAt),
      'intimacyBreakdown': intimacyBreakdown,
    };
  }

  bool get isActive => status == RelationshipStatus.active;
  bool get isCp => type == RelationshipType.cp;
  bool get isFriendship => type == RelationshipType.friendship;

  static const Map<int, String> levelNames = {
    1: 'Acquaintance',
    2: 'Friend',
    3: 'Close Friend',
    4: 'Best Friend',
    5: 'Soulmate',
  };

  static const Map<int, int> levelThresholds = {
    1: 0,
    2: 1000,
    3: 5000,
    4: 20000,
    5: 50000,
  };

  static int calculateLevel(int intimacy) {
    int lvl = 1;
    for (final entry in levelThresholds.entries) {
      if (intimacy >= entry.value) lvl = entry.key;
    }
    return lvl;
  }

  static int nextLevelIntimacy(int currentLevel) {
    return levelThresholds[currentLevel + 1] ?? levelThresholds.values.last;
  }

  static double levelProgress(int intimacy, int currentLevel) {
    final current = levelThresholds[currentLevel] ?? 0;
    final next = nextLevelIntimacy(currentLevel);
    if (next <= current) return 1.0;
    return (intimacy - current) / (next - current);
  }
}
