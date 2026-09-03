/// Data model for a reward item displayed in the Reward section.
class RewardModel {
  final String id;
  final String title;
  final RewardType type;
  final int amount;
  final String? duration;
  final String? iconUrl;
  final String? description;
  final bool isVisible;
  final int? rank; // Which rank this reward belongs to (1, 2, 3, or null for room owner)

  const RewardModel({
    required this.id,
    required this.title,
    required this.type,
    required this.amount,
    this.duration,
    this.iconUrl,
    this.description,
    this.isVisible = true,
    this.rank,
  });

  factory RewardModel.coins({required int amount, int? rank}) => RewardModel(
    id: 'coins_${rank ?? 0}',
    title: 'Coins',
    type: RewardType.coins,
    amount: amount,
    rank: rank,
  );

  factory RewardModel.exp({required int amount, int? rank}) => RewardModel(
    id: 'exp_${rank ?? 0}',
    title: 'EXP',
    type: RewardType.exp,
    amount: amount,
    rank: rank,
  );

  factory RewardModel.badge({required String duration, int? rank}) => RewardModel(
    id: 'badge_${rank ?? 0}',
    title: 'Badge',
    type: RewardType.badge,
    amount: 0,
    duration: duration,
    rank: rank,
  );

  RewardModel copyWith({
    String? id,
    String? title,
    RewardType? type,
    int? amount,
    String? duration,
    String? iconUrl,
    String? description,
    bool? isVisible,
    int? rank,
  }) {
    return RewardModel(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      duration: duration ?? this.duration,
      iconUrl: iconUrl ?? this.iconUrl,
      description: description ?? this.description,
      isVisible: isVisible ?? this.isVisible,
      rank: rank ?? this.rank,
    );
  }
}

enum RewardType {
  coins,
  exp,
  badge,
  frame,
  diamond,
}

/// Data model for a ranking position in the podium.
class RankingModel {
  final int rank;
  final String? userId;
  final String? username;
  final String? avatarUrl;
  final int score;
  final RewardModel? reward;

  const RankingModel({
    required this.rank,
    this.userId,
    this.username,
    this.avatarUrl,
    this.score = 0,
    this.reward,
  });

  bool get isEmpty => userId == null;

  RankingModel copyWith({
    int? rank,
    String? userId,
    String? username,
    String? avatarUrl,
    int? score,
    RewardModel? reward,
  }) {
    return RankingModel(
      rank: rank ?? this.rank,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      score: score ?? this.score,
      reward: reward ?? this.reward,
    );
  }
}

/// Represents the complete reward/ranking state for a rocket level.
class RocketRewardState {
  final int level;
  final Map<String, List<RewardModel>> tabRewards; // key: "room_owner", "top1", "top2", "top3"
  final List<RankingModel> rankings;
  final bool isLoading;
  final String? error;

  const RocketRewardState({
    required this.level,
    this.tabRewards = const {},
    this.rankings = const [],
    this.isLoading = false,
    this.error,
  });

  RocketRewardState copyWith({
    int? level,
    Map<String, List<RewardModel>>? tabRewards,
    List<RankingModel>? rankings,
    bool? isLoading,
    String? error,
  }) {
    return RocketRewardState(
      level: level ?? this.level,
      tabRewards: tabRewards ?? this.tabRewards,
      rankings: rankings ?? this.rankings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Creates default reward state for a given rocket level.
  factory RocketRewardState.defaultForLevel(int level) {
    final rewards = _getDefaultRewards(level);
    return RocketRewardState(
      level: level,
      tabRewards: {
        'room_owner': rewards,
        'top1': rewards,
        'top2': rewards,
        'top3': rewards,
      },
      rankings: const [],
    );
  }

  static List<RewardModel> _getDefaultRewards(int level) {
    switch (level) {
      case 0:
        return [
          RewardModel.coins(amount: 336000, rank: 1),
          RewardModel.exp(amount: 160000, rank: 2),
          RewardModel.badge(duration: '1 Days', rank: 3),
        ];
      case 1:
        return [
          RewardModel.coins(amount: 600000, rank: 1),
          RewardModel.exp(amount: 300000, rank: 2),
          RewardModel.badge(duration: '1 Days', rank: 3),
        ];
      case 2:
        return [
          RewardModel.coins(amount: 2000000, rank: 1),
          RewardModel.exp(amount: 1500000, rank: 2),
          RewardModel.badge(duration: '2 Days', rank: 3),
        ];
      case 3:
        return [
          RewardModel.coins(amount: 5000000, rank: 1),
          RewardModel.exp(amount: 3000000, rank: 2),
          RewardModel.badge(duration: '3 Days', rank: 3),
        ];
      case 4:
        return [
          RewardModel.coins(amount: 8000000, rank: 1),
          RewardModel.exp(amount: 5000000, rank: 2),
          RewardModel.badge(duration: '7 Days', rank: 3),
        ];
      default:
        return [
          RewardModel.coins(amount: 336000, rank: 1),
          RewardModel.exp(amount: 160000, rank: 2),
          RewardModel.badge(duration: '1 Days', rank: 3),
        ];
    }
  }
}
