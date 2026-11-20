enum FamePeriod {
  daily,
  weekly,
  monthly,
  allTime;

  String get field {
    switch (this) {
      case FamePeriod.daily:
        return 'dailyBeansReceived';
      case FamePeriod.weekly:
        return 'weeklyBeansReceived';
      case FamePeriod.monthly:
        return 'monthlyBeansReceived';
      case FamePeriod.allTime:
        return 'totalBeansReceived';
    }
  }

  String get label {
    switch (this) {
      case FamePeriod.daily:
        return 'Daily';
      case FamePeriod.weekly:
        return 'Weekly';
      case FamePeriod.monthly:
        return 'Monthly';
      case FamePeriod.allTime:
        return 'All Time';
    }
  }
}

class FameTier {
  final int level;
  final String title;
  final int minPoints;
  final int colorValue;

  const FameTier({
    required this.level,
    required this.title,
    required this.minPoints,
    required this.colorValue,
  });
}

class FameCatalog {
  static const List<FameTier> tiers = [
    FameTier(
        level: 1, title: 'Rising Star', minPoints: 0, colorValue: 0xFF90A4AE),
    FameTier(
        level: 2,
        title: 'Bright Star',
        minPoints: 1000,
        colorValue: 0xFF4CAF50),
    FameTier(
        level: 3,
        title: 'Shining Star',
        minPoints: 5000,
        colorValue: 0xFF29B6F6),
    FameTier(
        level: 4, title: 'Superstar', minPoints: 20000, colorValue: 0xFF7E57C2),
    FameTier(level: 5, title: 'Idol', minPoints: 50000, colorValue: 0xFFFFA726),
    FameTier(
        level: 6,
        title: 'Celebrity',
        minPoints: 150000,
        colorValue: 0xFFEC407A),
    FameTier(
        level: 7,
        title: 'Super Celebrity',
        minPoints: 500000,
        colorValue: 0xFFEF5350),
    FameTier(
        level: 8,
        title: 'Fame Icon',
        minPoints: 1500000,
        colorValue: 0xFFFFD54F),
    FameTier(
        level: 9, title: 'Legend', minPoints: 5000000, colorValue: 0xFFFF7043),
    FameTier(
        level: 10,
        title: 'Hall of Fame',
        minPoints: 15000000,
        colorValue: 0xFF00E5FF),
  ];

  static FameTier tierFor(int points) {
    final safePoints = points < 0 ? 0 : points;
    var current = tiers.first;
    for (final tier in tiers) {
      if (safePoints >= tier.minPoints) {
        current = tier;
      } else {
        break;
      }
    }
    return current;
  }

  static FameTier? nextTier(int points) {
    final current = tierFor(points);
    if (current.level >= tiers.last.level) return null;
    return tiers[current.level];
  }

  static double progress(int points) {
    final safePoints = points < 0 ? 0 : points;
    final next = nextTier(safePoints);
    if (next == null) return 1.0;
    final current = tierFor(safePoints);
    final span = next.minPoints - current.minPoints;
    if (span <= 0) return 1.0;
    return ((safePoints - current.minPoints) / span).clamp(0.0, 1.0);
  }

  static int pointsToNext(int points) {
    final safePoints = points < 0 ? 0 : points;
    final next = nextTier(safePoints);
    if (next == null) return 0;
    return (next.minPoints - safePoints).clamp(0, next.minPoints);
  }
}

class FameEntry {
  final String uid;
  final String displayName;
  final String photoUrl;
  final String? country;
  final int points;

  const FameEntry({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    this.country,
    required this.points,
  });

  FameTier get tier => FameCatalog.tierFor(points);

  /// Builds a display-safe entry from untrusted Firestore data.
  ///
  /// [uid] is the document id and is authoritative: a stale or tampered `uid`
  /// field must never redirect profile navigation to another account.
  factory FameEntry.fromMap(
    String uid,
    Map<String, dynamic> data, {
    String pointsField = 'totalBeansReceived',
  }) {
    final rawName = _asText(data['displayName']).trim();
    return FameEntry(
      uid: uid,
      displayName: rawName.isEmpty ? 'User' : rawName,
      photoUrl: _asText(data['profilePhotoUrl'] ?? data['photoUrl']),
      country: _asTextOrNull(data['country']),
      points: _asPoints(data[pointsField]),
    );
  }

  static void sortByRank(List<FameEntry> entries) {
    entries.sort((a, b) {
      final byPoints = b.points.compareTo(a.points);
      if (byPoints != 0) return byPoints;
      final byName =
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      if (byName != 0) return byName;
      return a.uid.compareTo(b.uid);
    });
  }

  static int _asPoints(dynamic value) {
    final parsed =
        value is num ? value.toInt() : num.tryParse(_asText(value))?.toInt();
    if (parsed == null || parsed < 0) return 0;
    return parsed;
  }

  static String _asText(dynamic value) =>
      value is String ? value : (value == null ? '' : value.toString());

  static String? _asTextOrNull(dynamic value) {
    final text = _asText(value).trim();
    return text.isEmpty ? null : text;
  }
}
