import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DinoModel {
  final String id;
  final String ownerUid;
  final String name;
  final String type; // e.g., 'T-Rex', 'Triceratops'
  final int level;
  final int xp;
  final double health; // 0.0 to 1.0
  final double energy; // 0.0 to 1.0
  final DateTime lastFed;
  final DateTime lastPlayed;
  final String stage; // 'Egg', 'Baby', 'Teen', 'Adult'

  DinoModel({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.type,
    required this.level,
    required this.xp,
    required this.health,
    required this.energy,
    required this.lastFed,
    required this.lastPlayed,
    required this.stage,
  });

  factory DinoModel.fromMap(Map<String, dynamic> data, String id) {
    return DinoModel(
      id: id,
      ownerUid: data['ownerUid'] ?? '',
      name: data['name'] ?? 'My Dino',
      type: data['type'] ?? 'T-Rex',
      level: data['level'] ?? 1,
      xp: data['xp'] ?? 0,
      health: (data['health'] ?? 1.0).toDouble(),
      energy: (data['energy'] ?? 1.0).toDouble(),
      lastFed: data['lastFed'] != null 
          ? (data['lastFed'] as Timestamp).toDate() 
          : DateTime.now(),
      lastPlayed: data['lastPlayed'] != null 
          ? (data['lastPlayed'] as Timestamp).toDate() 
          : DateTime.now(),
      stage: data['stage'] ?? 'Egg',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerUid': ownerUid,
      'name': name,
      'type': type,
      'level': level,
      'xp': xp,
      'health': health,
      'energy': energy,
      'lastFed': lastFed,
      'lastPlayed': lastPlayed,
      'stage': stage,
    };
  }

  // Calculate current effective stats based on time decay
  DinoModel calculateCurrentStats() {
    final now = DateTime.now();
    final hoursSinceFed = now.difference(lastFed).inHours;
    final hoursSincePlayed = now.difference(lastPlayed).inHours;

    // Decay 5% health per hour if not fed
    double currentHealth = (health - (hoursSinceFed * 0.05)).clamp(0.0, 1.0);
    // Decay 10% energy per hour if not played
    double currentEnergy = (energy - (hoursSincePlayed * 0.1)).clamp(0.0, 1.0);

    return copyWith(health: currentHealth, energy: currentEnergy);
  }

  DinoModel copyWith({
    String? name,
    int? level,
    int? xp,
    double? health,
    double? energy,
    DateTime? lastFed,
    DateTime? lastPlayed,
    String? stage,
  }) {
    return DinoModel(
      id: id,
      ownerUid: ownerUid,
      name: name ?? this.name,
      type: type,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      health: health ?? this.health,
      energy: energy ?? this.energy,
      lastFed: lastFed ?? this.lastFed,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      stage: stage ?? this.stage,
    );
  }

  // 🦕 Helper to get Stage-based Icon
  IconData getStageIcon() {
    switch (stage) {
      case 'Egg': return Icons.egg_rounded;
      case 'Baby': return Icons.child_care_rounded;
      case 'Teen': return Icons.smart_toy_rounded;
      case 'Adult': return Icons.pets_rounded;
      default: return Icons.egg_rounded;
    }
  }
}
