class RelationshipLevelModel {
  final int level;
  final String name;
  final int minIntimacy;
  final int maxIntimacy;
  final String? badgeIcon;
  final List<Map<String, dynamic>> rewards;

  RelationshipLevelModel({
    required this.level,
    required this.name,
    required this.minIntimacy,
    required this.maxIntimacy,
    this.badgeIcon,
    this.rewards = const [],
  });

  factory RelationshipLevelModel.fromMap(Map<String, dynamic> data) {
    return RelationshipLevelModel(
      level: (data['level'] as num?)?.toInt() ?? 1,
      name: data['name'] as String? ?? 'Level ${data['level']}',
      minIntimacy: (data['minIntimacy'] as num?)?.toInt() ?? 0,
      maxIntimacy: (data['maxIntimacy'] as num?)?.toInt() ?? 999,
      badgeIcon: data['badgeIcon'] as String?,
      rewards: (data['rewards'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'level': level,
      'name': name,
      'minIntimacy': minIntimacy,
      'maxIntimacy': maxIntimacy,
      'badgeIcon': badgeIcon,
      'rewards': rewards,
    };
  }
}
