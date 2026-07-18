enum RankingPeriod { daily, weekly, monthly }

class FamilyRankingModel {
  final String id;
  final String familyId;
  final String familyName;
  final String? familyAvatar;
  final int points;
  final int rank;
  final int level;
  final RankingPeriod period;
  final DateTime calculatedAt;

  const FamilyRankingModel({
    required this.id,
    required this.familyId,
    required this.familyName,
    this.familyAvatar,
    required this.points,
    required this.rank,
    required this.level,
    required this.period,
    required this.calculatedAt,
  });

  factory FamilyRankingModel.fromMap(Map<String, dynamic> map, String id) {
    return FamilyRankingModel(
      id: id,
      familyId: map['familyId'] ?? '',
      familyName: map['familyName'] ?? '',
      familyAvatar: map['familyAvatar'],
      points: map['points'] ?? 0,
      rank: map['rank'] ?? 0,
      level: map['level'] ?? 1,
      period: RankingPeriod.values.firstWhere(
        (e) => e.name == (map['period'] ?? 'daily'),
        orElse: () => RankingPeriod.daily,
      ),
      calculatedAt: (map['calculatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'familyId': familyId,
      'familyName': familyName,
      'familyAvatar': familyAvatar,
      'points': points,
      'rank': rank,
      'level': level,
      'period': period.name,
      'calculatedAt': calculatedAt,
    };
  }
}
