class RelationshipRewardModel {
  final String id;
  final String type;
  final String name;
  final String? icon;
  final String? assetUrl;
  final int requiredLevel;
  final bool isActive;

  RelationshipRewardModel({
    required this.id,
    required this.type,
    required this.name,
    this.icon,
    this.assetUrl,
    required this.requiredLevel,
    this.isActive = true,
  });

  factory RelationshipRewardModel.fromMap(Map<String, dynamic> data, String docId) {
    return RelationshipRewardModel(
      id: docId,
      type: data['type'] as String? ?? 'badge',
      name: data['name'] as String? ?? '',
      icon: data['icon'] as String?,
      assetUrl: data['assetUrl'] as String?,
      requiredLevel: (data['requiredLevel'] as num?)?.toInt() ?? 1,
      isActive: (data['isActive'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'name': name,
      'icon': icon,
      'assetUrl': assetUrl,
      'requiredLevel': requiredLevel,
      'isActive': isActive,
    };
  }
}
