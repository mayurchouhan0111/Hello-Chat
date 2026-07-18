class FamilyBattleModel {
  final String id;
  final String familyAId;
  final String familyBId;
  final String? familyAName;
  final String? familyBName;
  final String? familyAAvatar;
  final String? familyBAvatar;
  final String? imageUrl;
  final int familyAPoints;
  final int familyBPoints;
  final DateTime startedAt;
  final int durationSeconds;
  final String status;
  final String? winnerId;

  const FamilyBattleModel({
    required this.id,
    required this.familyAId,
    required this.familyBId,
    this.familyAName,
    this.familyBName,
    this.familyAAvatar,
    this.familyBAvatar,
    this.imageUrl,
    this.familyAPoints = 0,
    this.familyBPoints = 0,
    required this.startedAt,
    this.durationSeconds = 180,
    this.status = 'active',
    this.winnerId,
  });

  int get elapsedSeconds => DateTime.now().difference(startedAt).inSeconds;
  int get remainingSeconds => (durationSeconds - elapsedSeconds).clamp(0, durationSeconds);
  bool get isActive => status == 'active';
  bool get isExpired => elapsedSeconds >= durationSeconds;
  bool get isCompleted => status == 'completed';

  String get winnerName =>
      winnerId == familyAId
          ? (familyAName ?? familyAId)
          : winnerId == familyBId
              ? (familyBName ?? familyBId)
              : '';

  factory FamilyBattleModel.fromMap(Map<String, dynamic> map, String id) {
    return FamilyBattleModel(
      id: id,
      familyAId: map['familyAId'] ?? '',
      familyBId: map['familyBId'] ?? '',
      familyAName: map['familyAName'],
      familyBName: map['familyBName'],
      familyAAvatar: map['familyAAvatar'],
      familyBAvatar: map['familyBAvatar'],
      imageUrl: map['imageUrl'],
      familyAPoints: map['familyAPoints'] ?? 0,
      familyBPoints: map['familyBPoints'] ?? 0,
      startedAt: (map['startedAt'] as dynamic)?.toDate() ?? DateTime.now(),
      durationSeconds: map['durationSeconds'] ?? 180,
      status: map['status'] ?? 'active',
      winnerId: map['winnerId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'familyAId': familyAId,
      'familyBId': familyBId,
      'familyAName': familyAName,
      'familyBName': familyBName,
      'familyAAvatar': familyAAvatar,
      'familyBAvatar': familyBAvatar,
      'imageUrl': imageUrl,
      'familyAPoints': familyAPoints,
      'familyBPoints': familyBPoints,
      'startedAt': startedAt,
      'durationSeconds': durationSeconds,
      'status': status,
      'winnerId': winnerId,
    };
  }

  FamilyBattleModel copyWith({
    int? familyAPoints,
    int? familyBPoints,
    String? status,
    String? winnerId,
  }) {
    return FamilyBattleModel(
      id: id,
      familyAId: familyAId,
      familyBId: familyBId,
      familyAName: familyAName,
      familyBName: familyBName,
      familyAAvatar: familyAAvatar,
      familyBAvatar: familyBAvatar,
      familyAPoints: familyAPoints ?? this.familyAPoints,
      familyBPoints: familyBPoints ?? this.familyBPoints,
      startedAt: startedAt,
      durationSeconds: durationSeconds,
      status: status ?? this.status,
      winnerId: winnerId ?? this.winnerId,
    );
  }
}
