import 'package:cloud_firestore/cloud_firestore.dart';

class BannerModel {
  final String bannerId;
  final String imageUrl;
  final String title;
  final String? subtitle;
  final String? buttonText;
  final String actionType; // "recharge", "room", "profile", "external_url", "none"
  final String? actionValue;
  final bool isActive;
  final int priority;
  final DateTime? createdAt;
  final String? createdBy;

  BannerModel({
    required this.bannerId,
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.buttonText,
    required this.actionType,
    this.actionValue,
    this.isActive = true,
    this.priority = 100,
    this.createdAt,
    this.createdBy,
  });

  factory BannerModel.fromMap(Map<String, dynamic> map, String documentId) {
    return BannerModel(
      bannerId: documentId,
      imageUrl: map['imageUrl'] ?? '',
      title: map['title'] ?? '',
      subtitle: map['subtitle'],
      buttonText: map['buttonText'],
      actionType: map['actionType'] ?? 'none',
      actionValue: map['actionValue'],
      isActive: map['isActive'] ?? true,
      priority: map['priority'] ?? 100,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : null,
      createdBy: map['createdBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bannerId': bannerId,
      'imageUrl': imageUrl,
      'title': title,
      'subtitle': subtitle,
      'buttonText': buttonText,
      'actionType': actionType,
      'actionValue': actionValue,
      'isActive': isActive,
      'priority': priority,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    };
  }
}
