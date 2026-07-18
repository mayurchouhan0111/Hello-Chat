import 'package:cloud_firestore/cloud_firestore.dart';

class RoomBannerModel {
  final String id;
  final String imageUrl;
  final String actionType;
  final String actionValue;
  final int order;
  final bool enabled;

  RoomBannerModel({
    required this.id,
    required this.imageUrl,
    required this.actionType,
    required this.actionValue,
    this.order = 0,
    this.enabled = true,
  });

  factory RoomBannerModel.fromMap(Map<String, dynamic> map, String documentId) {
    return RoomBannerModel(
      id: documentId,
      imageUrl: map['imageUrl'] ?? '',
      actionType: map['actionType'] ?? 'navigation',
      actionValue: map['actionValue'] ?? '',
      order: map['order'] ?? 0,
      enabled: map['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'actionType': actionType,
      'actionValue': actionValue,
      'order': order,
      'enabled': enabled,
    };
  }
}
