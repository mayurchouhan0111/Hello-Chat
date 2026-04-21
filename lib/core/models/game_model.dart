import 'package:cloud_firestore/cloud_firestore.dart';

class GameResultModel {
  final String id;
  final String uid;
  final String? roomId;
  final String gameType; // 'spin_wheel' or 'lucky_draw'
  final int betAmount;
  final int payoutAmount;
  final bool isWin;
  final DateTime timestamp;
  final String? serverSeed; // For Provably Fair verification
  final Map<String, dynamic>? metadata;

  GameResultModel({
    required this.id,
    required this.uid,
    this.roomId,
    required this.gameType,
    required this.betAmount,
    required this.payoutAmount,
    required this.isWin,
    required this.timestamp,
    this.serverSeed,
    this.metadata,
  });

  factory GameResultModel.fromMap(Map<String, dynamic> data) {
    return GameResultModel(
      id: data['id'] ?? '',
      uid: data['uid'] ?? '',
      roomId: data['roomId'],
      gameType: data['gameType'] ?? '',
      betAmount: (data['betAmount'] ?? 0) as int,
      payoutAmount: (data['payoutAmount'] ?? 0) as int,
      isWin: data['isWin'] ?? false,
      timestamp: data['timestamp'] != null 
          ? (data['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
      serverSeed: data['serverSeed'],
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'roomId': roomId,
      'gameType': gameType,
      'betAmount': betAmount,
      'payoutAmount': payoutAmount,
      'isWin': isWin,
      'timestamp': timestamp,
      'serverSeed': serverSeed,
      'metadata': metadata,
    };
  }
}
