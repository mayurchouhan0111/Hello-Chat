import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final String description;
  final String type; // "recharge_bonus", "recharge_milestone", "generic"
  final String htmlContent;
  final String bannerImage;
  final String backgroundImage;
  final String backgroundType; // "color", "gradient", "image", "gif", "video", "html"
  final String backgroundColor;
  final List<String> backgroundGradient;
  final String themeColor;
  final String icon;
  final String buttonText;
  final String buttonColor;
  final String buttonAction; // "recharge", "url", "route"
  final String navigationTarget;
  final int priority;
  final bool isActive;
  final DateTime startDate;
  final DateTime endDate;
  final bool includeBonus;
  final DateTime? createdAt;

  EventModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.type,
    this.htmlContent = '',
    this.bannerImage = '',
    this.backgroundImage = '',
    this.backgroundType = 'color',
    this.backgroundColor = '#1a0a2e',
    this.backgroundGradient = const [],
    this.themeColor = '#FFD700',
    this.icon = 'stars',
    this.buttonText = 'Recharge Now',
    this.buttonColor = '#D32F2F',
    this.buttonAction = 'recharge',
    this.navigationTarget = '/wallet',
    this.priority = 100,
    this.isActive = true,
    required this.startDate,
    required this.endDate,
    this.includeBonus = false,
    this.createdAt,
  });

  factory EventModel.fromMap(Map<String, dynamic> map, String documentId) {
    return EventModel(
      id: documentId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? 'generic',
      htmlContent: map['htmlContent'] ?? '',
      bannerImage: map['bannerImage'] ?? '',
      backgroundImage: map['backgroundImage'] ?? '',
      backgroundType: map['backgroundType'] ?? 'color',
      backgroundColor: map['backgroundColor'] ?? '#1a0a2e',
      backgroundGradient: List<String>.from(map['backgroundGradient'] ?? []),
      themeColor: map['themeColor'] ?? '#FFD700',
      icon: map['icon'] ?? 'stars',
      buttonText: map['buttonText'] ?? 'Recharge Now',
      buttonColor: map['buttonColor'] ?? '#D32F2F',
      buttonAction: map['buttonAction'] ?? 'recharge',
      navigationTarget: map['navigationTarget'] ?? '/wallet',
      priority: map['priority'] ?? 100,
      isActive: map['isActive'] ?? true,
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      includeBonus: map['includeBonus'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'type': type,
      'htmlContent': htmlContent,
      'bannerImage': bannerImage,
      'backgroundImage': backgroundImage,
      'backgroundType': backgroundType,
      'backgroundColor': backgroundColor,
      'backgroundGradient': backgroundGradient,
      'themeColor': themeColor,
      'icon': icon,
      'buttonText': buttonText,
      'buttonColor': buttonColor,
      'buttonAction': buttonAction,
      'navigationTarget': navigationTarget,
      'priority': priority,
      'isActive': isActive,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'includeBonus': includeBonus,
    };
  }
}

class RechargePackageModel {
  final String id;
  final String eventId;
  final int rechargeAmount;
  final int baseCoins;
  final int bonusCoins;
  final int totalCoins;
  final int sortOrder;
  final bool isActive;

  RechargePackageModel({
    required this.id,
    required this.eventId,
    this.rechargeAmount = 0,
    this.baseCoins = 0,
    this.bonusCoins = 0,
    this.totalCoins = 0,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory RechargePackageModel.fromMap(Map<String, dynamic> map, String documentId) {
    final base = (map['baseCoins'] as num?)?.toInt() ?? 0;
    final bonus = (map['bonusCoins'] as num?)?.toInt() ?? 0;
    return RechargePackageModel(
      id: documentId,
      eventId: map['eventId'] ?? '',
      rechargeAmount: (map['rechargeAmount'] as num?)?.toInt() ?? 0,
      baseCoins: base,
      bonusCoins: bonus,
      totalCoins: (map['totalCoins'] as num?)?.toInt() ?? (base + bonus),
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] ?? true,
    );
  }
}

class RechargeMilestoneModel {
  final String id;
  final String eventId;
  final int targetAmount;
  final int rewardAmount;
  final String rewardType; // "coins", "badge", "item"
  final String label;
  final int sortOrder;
  final bool isActive;

  RechargeMilestoneModel({
    required this.id,
    required this.eventId,
    this.targetAmount = 0,
    this.rewardAmount = 0,
    this.rewardType = 'coins',
    this.label = '',
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory RechargeMilestoneModel.fromMap(Map<String, dynamic> map, String documentId) {
    return RechargeMilestoneModel(
      id: documentId,
      eventId: map['eventId'] ?? '',
      targetAmount: (map['targetAmount'] as num?)?.toInt() ?? 0,
      rewardAmount: (map['rewardAmount'] as num?)?.toInt() ?? 0,
      rewardType: map['rewardType'] ?? 'coins',
      label: map['label'] ?? '',
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] ?? true,
    );
  }
}

class UserEventProgressModel {
  final String uid;
  final String eventId;
  final int progress;
  final List<String> claimedMilestones;
  final DateTime? updatedAt;

  UserEventProgressModel({
    required this.uid,
    required this.eventId,
    this.progress = 0,
    this.claimedMilestones = const [],
    this.updatedAt,
  });

  factory UserEventProgressModel.fromMap(Map<String, dynamic> map) {
    return UserEventProgressModel(
      uid: map['uid'] ?? '',
      eventId: map['eventId'] ?? '',
      progress: (map['progress'] as num?)?.toInt() ?? 0,
      claimedMilestones: List<String>.from(map['claimedMilestones'] ?? []),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
