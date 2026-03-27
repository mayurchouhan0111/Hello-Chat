import 'package:cloud_firestore/cloud_firestore.dart';

class MediaModel {
  final String mediaId;
  final String userId;
  final String imageUrl;
  final String tag;
  final String caption;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final bool isDeleted;

  MediaModel({
    required this.mediaId,
    required this.userId,
    required this.imageUrl,
    required this.tag,
    required this.caption,
    required this.createdAt,
    required this.likesCount,
    required this.commentsCount,
    required this.isDeleted,
  });

  factory MediaModel.fromMap(Map<String, dynamic> data) {
    return MediaModel(
      mediaId: data['mediaId'] ?? '',
      userId: data['userId'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      tag: data['tag'] ?? 'normal',
      caption: data['caption'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: data['likesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mediaId': mediaId,
      'userId': userId,
      'imageUrl': imageUrl,
      'tag': tag,
      'caption': caption,
      'createdAt': createdAt,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'isDeleted': isDeleted,
    };
  }
}
