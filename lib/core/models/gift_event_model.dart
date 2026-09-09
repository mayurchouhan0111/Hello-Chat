import 'package:cloud_firestore/cloud_firestore.dart';

class EventGiftItem {
  final String giftId;
  final String name;
  final int priceInDiamonds;
  final int eventPoints;
  final String imageUrl;

  const EventGiftItem({
    required this.giftId,
    required this.name,
    required this.priceInDiamonds,
    required this.eventPoints,
    this.imageUrl = '',
  });

  factory EventGiftItem.fromMap(Map<String, dynamic> map) {
    return EventGiftItem(
      giftId: map['giftId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      priceInDiamonds: (map['priceInDiamonds'] as num?)?.toInt() ?? 0,
      eventPoints: (map['eventPoints'] as num?)?.toInt() ?? 0,
      imageUrl: map['imageUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'giftId': giftId,
      'name': name,
      'priceInDiamonds': priceInDiamonds,
      'eventPoints': eventPoints,
      'imageUrl': imageUrl,
    };
  }
}

class EventRewardTier {
  final int rankFrom;
  final int rankTo;
  final String title;
  final int diamonds;
  final String frameUrl;
  final int frameDays;
  final String avatarFrameUrl;
  final String entryEffectUrl;
  final String badgeTitle;
  final String customReward;

  const EventRewardTier({
    required this.rankFrom,
    required this.rankTo,
    required this.title,
    this.diamonds = 0,
    this.frameUrl = '',
    this.frameDays = 30,
    this.avatarFrameUrl = '',
    this.entryEffectUrl = '',
    this.badgeTitle = '',
    this.customReward = '',
  });

  factory EventRewardTier.fromMap(Map<String, dynamic> map) {
    return EventRewardTier(
      rankFrom: (map['rankFrom'] as num?)?.toInt() ?? 1,
      rankTo: (map['rankTo'] as num?)?.toInt() ?? 1,
      title: map['title']?.toString() ?? '',
      diamonds: (map['diamonds'] as num?)?.toInt() ?? 0,
      frameUrl: map['frameUrl']?.toString() ?? '',
      frameDays: (map['frameDays'] as num?)?.toInt() ?? 30,
      avatarFrameUrl: map['avatarFrameUrl']?.toString() ?? '',
      entryEffectUrl: map['entryEffectUrl']?.toString() ?? '',
      badgeTitle: map['badgeTitle']?.toString() ?? '',
      customReward: map['customReward']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rankFrom': rankFrom,
      'rankTo': rankTo,
      'title': title,
      'diamonds': diamonds,
      'frameUrl': frameUrl,
      'frameDays': frameDays,
      'avatarFrameUrl': avatarFrameUrl,
      'entryEffectUrl': entryEffectUrl,
      'badgeTitle': badgeTitle,
      'customReward': customReward,
    };
  }
}

class GiftEventModel {
  final String id;
  final String title;
  final String description;
  final String rules;
  final String bannerUrl;
  final String backgroundUrl;
  final String themeColor;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final String rankingDuration;
  final int rankingDisplayCount;
  final List<EventGiftItem> gifts;
  final List<EventRewardTier> rewards;
  final int totalEventPoints;
  final int totalGiftsSent;
  final bool distributed;

  const GiftEventModel({
    required this.id,
    required this.title,
    this.description = '',
    this.rules = '',
    this.bannerUrl = '',
    this.backgroundUrl = '',
    this.themeColor = '#FFD700',
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.rankingDuration = 'event_duration',
    this.rankingDisplayCount = 50,
    this.gifts = const [],
    this.rewards = const [],
    this.totalEventPoints = 0,
    this.totalGiftsSent = 0,
    this.distributed = false,
  });

  bool get isLive {
    final now = DateTime.now();
    return isActive && now.isAfter(startDate) && now.isBefore(endDate);
  }

  Duration get remainingDuration {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return Duration.zero;
    return endDate.difference(now);
  }

  String get formattedTimeRemaining {
    final d = remainingDuration;
    if (d == Duration.zero) return 'Ended';
    if (d.inDays > 0) return '${d.inDays}d left';
    if (d.inHours > 0) return '${d.inHours}h left';
    return '${d.inMinutes}m left';
  }

  List<String> get rulesList {
    if (rules.isEmpty) return [];
    return rules
        .split('\n')
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toList();
  }

  factory GiftEventModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    String parseRules(dynamic val) {
      if (val == null) return '';
      if (val is List) {
        return val
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .join('\n');
      }
      if (val is String) {
        var s = val.trim();
        if (s.startsWith('[') && s.endsWith(']')) {
          s = s.substring(1, s.length - 1);
          return s
              .split(RegExp(r',\s*'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .join('\n');
        }
        return s;
      }
      return val.toString();
    }

    final rawGifts = map['gifts'] as List<dynamic>? ?? [];
    final parsedGifts = rawGifts
        .whereType<Map<String, dynamic>>()
        .map((g) => EventGiftItem.fromMap(g))
        .toList();

    final rawRewards = map['rewards'] as List<dynamic>? ?? [];
    final parsedRewards = rawRewards
        .whereType<Map<String, dynamic>>()
        .map((r) => EventRewardTier.fromMap(r))
        .toList();

    return GiftEventModel(
      id: docId,
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      rules: parseRules(map['rules']),
      bannerUrl: map['bannerUrl']?.toString() ?? '',
      backgroundUrl: map['backgroundUrl']?.toString() ?? '',
      themeColor: map['themeColor']?.toString() ?? '#FFD700',
      startDate: parseDate(map['startDate']),
      endDate: parseDate(map['endDate']),
      isActive: (map['isActive'] as bool?) ?? (map['enabled'] as bool?) ?? (map['status'] == 'active'),
      rankingDuration: map['rankingDuration']?.toString() ?? 'event_duration',
      rankingDisplayCount: (map['rankingDisplayCount'] as num?)?.toInt() ?? 50,
      gifts: parsedGifts,
      rewards: parsedRewards,
      totalEventPoints: (map['totalEventPoints'] as num?)?.toInt() ?? 0,
      totalGiftsSent: (map['totalGiftsSent'] as num?)?.toInt() ?? 0,
      distributed: map['distributed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'rules': rules,
      'bannerUrl': bannerUrl,
      'backgroundUrl': backgroundUrl,
      'themeColor': themeColor,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'rankingDuration': rankingDuration,
      'rankingDisplayCount': rankingDisplayCount,
      'gifts': gifts.map((g) => g.toMap()).toList(),
      'rewards': rewards.map((r) => r.toMap()).toList(),
      'totalEventPoints': totalEventPoints,
      'totalGiftsSent': totalGiftsSent,
      'distributed': distributed,
    };
  }
}

class EventParticipant {
  final String uid;
  final String displayName;
  final String profilePhotoUrl;
  final String gender;
  final int level;
  final String vipTier;
  final int points;
  final int giftCount;
  final int diamondsSpent;
  final int rank;

  const EventParticipant({
    required this.uid,
    required this.displayName,
    this.profilePhotoUrl = '',
    this.gender = 'female',
    this.level = 1,
    this.vipTier = 'none',
    this.points = 0,
    this.giftCount = 0,
    this.diamondsSpent = 0,
    this.rank = 0,
  });

  factory EventParticipant.fromMap(Map<String, dynamic> map, String docId, {int rank = 0}) {
    return EventParticipant(
      uid: docId.isNotEmpty ? docId : (map['uid']?.toString() ?? ''),
      displayName: map['displayName']?.toString() ?? 'User',
      profilePhotoUrl: map['profilePhotoUrl']?.toString() ?? '',
      gender: map['gender']?.toString() ?? 'female',
      level: (map['level'] as num?)?.toInt() ?? 1,
      vipTier: map['vipTier']?.toString() ?? 'none',
      points: (map['points'] as num?)?.toInt() ?? 0,
      giftCount: (map['giftCount'] as num?)?.toInt() ?? 0,
      diamondsSpent: (map['diamondsSpent'] as num?)?.toInt() ?? 0,
      rank: rank,
    );
  }
}
