class FamilyBattleRequestModel {
  final String id;
  final String challengerFamilyId;
  final String challengerName;
  final String? challengerAvatar;
  final String opponentFamilyId;
  final String opponentName;
  final String? opponentAvatar;
  final String? imageUrl;
  final String status;
  final DateTime createdAt;

  const FamilyBattleRequestModel({
    required this.id,
    required this.challengerFamilyId,
    required this.challengerName,
    this.challengerAvatar,
    required this.opponentFamilyId,
    required this.opponentName,
    this.opponentAvatar,
    this.imageUrl,
    this.status = 'pending',
    required this.createdAt,
  });

  bool get isPending => status == 'pending';

  factory FamilyBattleRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return FamilyBattleRequestModel(
      id: id,
      challengerFamilyId: map['challengerFamilyId'] ?? '',
      challengerName: map['challengerName'] ?? '',
      challengerAvatar: map['challengerAvatar'],
      opponentFamilyId: map['opponentFamilyId'] ?? '',
      opponentName: map['opponentName'] ?? '',
      opponentAvatar: map['opponentAvatar'],
      imageUrl: map['imageUrl'],
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'challengerFamilyId': challengerFamilyId,
      'challengerName': challengerName,
      'challengerAvatar': challengerAvatar,
      'opponentFamilyId': opponentFamilyId,
      'opponentName': opponentName,
      'opponentAvatar': opponentAvatar,
      'imageUrl': imageUrl,
      'status': status,
      'createdAt': createdAt,
    };
  }
}
