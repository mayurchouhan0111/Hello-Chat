import 'package:cloud_firestore/cloud_firestore.dart';

enum RankingPeriod { daily, weekly, monthly, allTime }

class RelationshipRankingModel {
  final String id;
  final String relationshipId;
  final List<String> participants;
  final int intimacy;
  final int level;
  final RankingPeriod period;
  final int rank;
  final DateTime calculatedAt;

  RelationshipRankingModel({
    required this.id,
    required this.relationshipId,
    required this.participants,
    required this.intimacy,
    required this.level,
    required this.period,
    required this.rank,
    required this.calculatedAt,
  });

  factory RelationshipRankingModel.fromMap(Map<String, dynamic> data, String docId) {
    return RelationshipRankingModel(
      id: docId,
      relationshipId: data['relationshipId'] as String? ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      intimacy: (data['intimacy'] as num?)?.toInt() ?? 0,
      level: (data['level'] as num?)?.toInt() ?? 1,
      period: _parsePeriod(data['period'] as String?),
      rank: (data['rank'] as num?)?.toInt() ?? 0,
      calculatedAt: (data['calculatedAt'] as dynamic) is Timestamp
          ? (data['calculatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'relationshipId': relationshipId,
      'participants': participants,
      'intimacy': intimacy,
      'level': level,
      'period': period.name,
      'rank': rank,
      'calculatedAt': Timestamp.fromDate(calculatedAt),
    };
  }

  static RankingPeriod _parsePeriod(String? value) {
    switch (value) {
      case 'daily': return RankingPeriod.daily;
      case 'weekly': return RankingPeriod.weekly;
      case 'monthly': return RankingPeriod.monthly;
      default: return RankingPeriod.allTime;
    }
  }
}
