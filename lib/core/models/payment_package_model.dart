class PaymentPackageModel {
  final String packageId;
  final int diamonds;
  final int bonusDiamonds;
  final int priceINR; // in paise
  final int priceUSD; // in cents
  final bool active;
  final int sortOrder;
  final String? tag;

  const PaymentPackageModel({
    required this.packageId,
    required this.diamonds,
    this.bonusDiamonds = 0,
    required this.priceINR,
    required this.priceUSD,
    this.active = true,
    this.sortOrder = 0,
    this.tag,
  });

  int get totalDiamonds => diamonds + bonusDiamonds;
  double get priceINRRupees => priceINR / 100.0;
  double get priceUSDNominal => priceUSD / 100.0;

  String get formattedINR => "₹${priceINRRupees.toStringAsFixed(priceINR % 100 == 0 ? 0 : 2)}";
  String get formattedUSD => "\$${priceUSDNominal.toStringAsFixed(priceUSD % 100 == 0 ? 0 : 2)}";

  factory PaymentPackageModel.fromMap(String id, Map<String, dynamic> map) {
    return PaymentPackageModel(
      packageId: id,
      diamonds: (map['diamonds'] as num?)?.toInt() ?? 0,
      bonusDiamonds: (map['bonusDiamonds'] as num?)?.toInt() ?? 0,
      priceINR: (map['priceINR'] as num?)?.toInt() ?? 0,
      priceUSD: (map['priceUSD'] as num?)?.toInt() ?? 0,
      active: map['active'] as bool? ?? true,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      tag: map['tag'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'diamonds': diamonds,
      'bonusDiamonds': bonusDiamonds,
      'priceINR': priceINR,
      'priceUSD': priceUSD,
      'active': active,
      'sortOrder': sortOrder,
      'tag': tag,
    };
  }
}
