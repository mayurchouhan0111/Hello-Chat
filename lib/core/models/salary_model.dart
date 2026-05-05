import 'package:cloud_firestore/cloud_firestore.dart';

class SalaryLevel {
  final int level;
  final int targetBeans;
  final String label;

  const SalaryLevel({
    required this.level,
    required this.targetBeans,
    required this.label,
  });

  // Split calculations (Host 60%, Agency 30%, Admin 10%)
  double get hostShare => targetBeans * 0.6;
  double get agencyShare => targetBeans * 0.3;
  double get adminShare => targetBeans * 0.1;

  static const List<SalaryLevel> allLevels = [
    SalaryLevel(level: 1, targetBeans: 10000, label: "Lv.1 Beginner"),
    SalaryLevel(level: 2, targetBeans: 50000, label: "Lv.2 Rising Star"),
    SalaryLevel(level: 3, targetBeans: 150000, label: "Lv.3 Influencer"),
    SalaryLevel(level: 4, targetBeans: 500000, label: "Lv.4 Professional"),
    SalaryLevel(level: 5, targetBeans: 1500000, label: "Lv.5 Elite"),
    SalaryLevel(level: 6, targetBeans: 5000000, label: "Lv.6 Master"),
    SalaryLevel(level: 7, targetBeans: 15000000, label: "Lv.7 Legend"),
    SalaryLevel(level: 8, targetBeans: 50000000, label: "Lv.8 Mythic"),
    SalaryLevel(level: 9, targetBeans: 150000000, label: "Lv.9 Immortal"),
    SalaryLevel(level: 10, targetBeans: 500000000, label: "Lv.10 Ultimate"),
  ];

  static SalaryLevel getLevel(int level) {
    return allLevels.firstWhere((l) => l.level == level, orElse: () => allLevels.first);
  }
}

class SalaryStatus {
  final String uid;
  final int currentLevel;
  final int totalBeansEarned;
  final int currentMonthBeans;
  final List<int> completedLevels;
  final DateTime lastDailyPayout;
  final DateTime lastBiWeeklyPayout;

  SalaryStatus({
    required this.uid,
    this.currentLevel = 0,
    this.totalBeansEarned = 0,
    this.currentMonthBeans = 0,
    this.completedLevels = const [],
    required this.lastDailyPayout,
    required this.lastBiWeeklyPayout,
  });

  factory SalaryStatus.fromMap(Map<String, dynamic> map) {
    return SalaryStatus(
      uid: map['uid'] ?? '',
      currentLevel: map['currentLevel'] ?? 0,
      totalBeansEarned: map['totalBeansEarned'] ?? 0,
      currentMonthBeans: map['currentMonthBeans'] ?? 0,
      completedLevels: List<int>.from(map['completedLevels'] ?? []),
      lastDailyPayout: (map['lastDailyPayout'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      lastBiWeeklyPayout: (map['lastBiWeeklyPayout'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'currentLevel': currentLevel,
      'totalBeansEarned': totalBeansEarned,
      'currentMonthBeans': currentMonthBeans,
      'completedLevels': completedLevels,
      'lastDailyPayout': Timestamp.fromDate(lastDailyPayout),
      'lastBiWeeklyPayout': Timestamp.fromDate(lastBiWeeklyPayout),
    };
  }
}

class SalaryPayout {
  final String id;
  final String uid;
  final String? agencyId;
  final double amount;
  final String type; // 'host', 'agency', 'admin'
  final int level;
  final DateTime scheduledDate;
  final String status; // 'pending', 'paid'
  final DateTime createdAt;

  SalaryPayout({
    required this.id,
    required this.uid,
    this.agencyId,
    required this.amount,
    required this.type,
    required this.level,
    required this.scheduledDate,
    this.status = 'pending',
    required this.createdAt,
  });

  factory SalaryPayout.fromMap(Map<String, dynamic> map, String id) {
    return SalaryPayout(
      id: id,
      uid: map['uid'] ?? '',
      agencyId: map['agencyId'],
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: map['type'] ?? 'host',
      level: map['level'] ?? 0,
      scheduledDate: (map['scheduledDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'agencyId': agencyId,
      'amount': amount,
      'type': type,
      'level': level,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
