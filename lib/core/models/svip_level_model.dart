class SVIPLevelModel {
  final int level;
  final String name;
  final int monthlyRechargeRequirement;
  final int svipPoints;
  final String description;

  const SVIPLevelModel({
    required this.level,
    required this.name,
    required this.monthlyRechargeRequirement,
    required this.svipPoints,
    this.description = 'Elite Status privileges unlocked.',
  });

  static const List<SVIPLevelModel> levels = [
    SVIPLevelModel(level: 1, name: 'SVIP1', monthlyRechargeRequirement: 10000000, svipPoints: 1000),
    SVIPLevelModel(level: 2, name: 'SVIP2', monthlyRechargeRequirement: 30000000, svipPoints: 3000),
    SVIPLevelModel(level: 3, name: 'SVIP3', monthlyRechargeRequirement: 50000000, svipPoints: 5000),
    SVIPLevelModel(level: 4, name: 'SVIP4', monthlyRechargeRequirement: 100000000, svipPoints: 10000),
    SVIPLevelModel(level: 5, name: 'SVIP5', monthlyRechargeRequirement: 200000000, svipPoints: 20000),
    SVIPLevelModel(level: 6, name: 'SVIP6', monthlyRechargeRequirement: 300000000, svipPoints: 30000),
    SVIPLevelModel(level: 7, name: 'SVIP7', monthlyRechargeRequirement: 500000000, svipPoints: 50000),
  ];


  static SVIPLevelModel getLevelForRecharge(int amount) {
    SVIPLevelModel current = levels.first;
    for (var level in levels) {
      if (amount >= level.monthlyRechargeRequirement) {
        current = level;
      } else {
        break;
      }
    }
    return current;
  }
}
