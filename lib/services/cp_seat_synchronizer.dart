import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CpRelationshipModel {
  final String cpId;
  final String user1Id;
  final String user2Id;
  final bool isActive;
  final int cpLevel;
  final int cpPoints;

  CpRelationshipModel({
    required this.cpId,
    required this.user1Id,
    required this.user2Id,
    required this.isActive,
    required this.cpLevel,
    required this.cpPoints,
  });

  factory CpRelationshipModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CpRelationshipModel(
      cpId: doc.id,
      user1Id: data['user1Id'] ?? '',
      user2Id: data['user2Id'] ?? '',
      isActive: data['isActive'] ?? false,
      cpLevel: (data['cpLevel'] as num?)?.toInt() ?? 1,
      cpPoints: (data['cpPoints'] as num?)?.toInt() ?? 0,
    );
  }
}

class CpSeatSynchronizer {
  static final CpSeatSynchronizer instance = CpSeatSynchronizer._internal();
  CpSeatSynchronizer._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Checks if two users in a room form an active CP relationship
  Stream<CpRelationshipModel?> watchActiveCpRelationship(String userId1, String userId2) {
    if (userId1.isEmpty || userId2.isEmpty || userId1 == userId2) {
      return Stream.value(null);
    }

    return _firestore
        .collection('cp_relationships')
        .where('isActive', isEqualTo: true)
        .where('user1Id', whereIn: [userId1, userId2])
        .snapshots()
        .map((snapshot) {
      for (final doc in snapshot.docs) {
        final cp = CpRelationshipModel.fromFirestore(doc);
        if ((cp.user1Id == userId1 && cp.user2Id == userId2) ||
            (cp.user1Id == userId2 && cp.user2Id == userId1)) {
          return cp;
        }
      }
      return null;
    });
  }

  /// Calculates side-by-side seat positions for CP couple inside a room seat array.
  /// Standard seats array is 0 to 7 (8 seats). Dedicated CP pair seats are (1, 2) or (3, 4).
  List<int> calculateSideBySideCpSeats(int currentPartner1Seat, int currentPartner2Seat) {
    if (currentPartner1Seat >= 0 && (currentPartner1Seat + 1) < 8) {
      return [currentPartner1Seat, currentPartner1Seat + 1];
    }
    return [1, 2];
  }
}

/// Visual Frame styling for CP Seats scaling with CP Level
class CpSeatStyle {
  final List<Color> borderGradient;
  final Color glowColor;
  final String titleLabel;

  const CpSeatStyle({
    required this.borderGradient,
    required this.glowColor,
    required this.titleLabel,
  });

  static CpSeatStyle getStyleForLevel(int level) {
    switch (level) {
      case 1:
        return const CpSeatStyle(
          borderGradient: [Color(0xFFFF758C), Color(0xFFFF7EB3)],
          glowColor: Color(0x66FF758C),
          titleLabel: 'Sweet CP',
        );
      case 2:
        return const CpSeatStyle(
          borderGradient: [Color(0xFFF76B1C), Color(0xFFFAD961)],
          glowColor: Color(0x66F76B1C),
          titleLabel: 'Golden CP',
        );
      case 3:
        return const CpSeatStyle(
          borderGradient: [Color(0xFFA88BEB), Color(0xFFF8CEEC)],
          glowColor: Color(0x66A88BEB),
          titleLabel: 'Diamond CP',
        );
      case 4:
        return const CpSeatStyle(
          borderGradient: [Color(0xFF00C6FF), Color(0xFF0072FF)],
          glowColor: Color(0x6600C6FF),
          titleLabel: 'Royal CP',
        );
      case 5:
      default:
        return const CpSeatStyle(
          borderGradient: [Color(0xFFFF007F), Color(0xFF7F00FF), Color(0xFFFFD700)],
          glowColor: Color(0x99FF007F),
          titleLabel: 'Eternal CP',
        );
    }
  }
}

class CpSeatFrameWidget extends StatelessWidget {
  final int cpLevel;
  final Widget child;

  const CpSeatFrameWidget({
    super.key,
    required this.cpLevel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final style = CpSeatStyle.getStyleForLevel(cpLevel);

    return Container(
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: style.borderGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: style.glowColor,
            blurRadius: 8.0,
            spreadRadius: 2.0,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          child,
          Positioned(
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: style.borderGradient.first, width: 0.8),
              ),
              child: Text(
                '${style.titleLabel} L$cpLevel',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
