class ResellerModel {
  final String resellerId;
  final String userId;
  final String name;
  final String avatarUrl;
  final String countryFlag;
  final String whatsappNumber;
  final int coinBalance;
  final bool isOnline;
  final String status; // 'ACTIVE', 'INACTIVE'

  const ResellerModel({
    required this.resellerId,
    required this.userId,
    required this.name,
    this.avatarUrl = '',
    this.countryFlag = '🇲🇾',
    required this.whatsappNumber,
    this.coinBalance = 0,
    this.isOnline = true,
    this.status = 'ACTIVE',
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  /// Sanitized digits-only phone number for WhatsApp deep link and wa.me URL.
  String get sanitizedWhatsappNumber =>
      whatsappNumber.replaceAll(RegExp(r'[^\d]'), '');

  /// Formatted coin balance display (e.g., '100000000+').
  String get formattedCoinBalance => '$coinBalance+';

  factory ResellerModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawId = map['reseller_id'] ?? map['resellerId'] ?? map['helloId'] ?? map['displayId'] ?? docId ?? '';
    final rawUid = map['user_id'] ?? map['userId'] ?? map['uid'] ?? docId ?? '';
    final rawName = map['name'] ?? map['displayName'] ?? map['username'] ?? 'Official Merchant';
    final rawAvatar = map['avatar_url'] ?? map['avatarUrl'] ?? map['profilePhotoUrl'] ?? '';
    final rawFlag = map['country_flag'] ?? map['countryFlag'] ?? '🇲🇾';
    final rawWhatsapp = map['whatsapp_number'] ?? map['whatsappNumber'] ?? map['phoneNumber'] ?? '+601112280539';
    final rawCoins = map['coin_balance'] ?? map['coinBalance'] ?? map['diamondStock'] ?? map['currentDiamonds'] ?? 100000000;
    final rawOnline = map['is_online'] ?? map['isOnline'] ?? (map['status'] == 'Online' || map['status'] == 'ACTIVE' || true);
    final rawStatus = (map['status']?.toString().toUpperCase() == 'INACTIVE' || map['isReseller'] == false)
        ? 'INACTIVE'
        : 'ACTIVE';

    int parsedCoins = 100000000;
    if (rawCoins is num) {
      parsedCoins = rawCoins.toInt();
    } else if (rawCoins is String) {
      parsedCoins = int.tryParse(rawCoins.replaceAll(RegExp(r'[^\d]'), '')) ?? 100000000;
    }

    return ResellerModel(
      resellerId: rawId.toString(),
      userId: rawUid.toString(),
      name: rawName.toString(),
      avatarUrl: rawAvatar.toString(),
      countryFlag: rawFlag.toString(),
      whatsappNumber: rawWhatsapp.toString(),
      coinBalance: parsedCoins,
      isOnline: rawOnline is bool ? rawOnline : true,
      status: rawStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reseller_id': resellerId,
      'user_id': userId,
      'name': name,
      'avatar_url': avatarUrl,
      'country_flag': countryFlag,
      'whatsapp_number': whatsappNumber,
      'coin_balance': coinBalance,
      'is_online': isOnline,
      'status': status,
    };
  }

  ResellerModel copyWith({
    String? resellerId,
    String? userId,
    String? name,
    String? avatarUrl,
    String? countryFlag,
    String? whatsappNumber,
    int? coinBalance,
    bool? isOnline,
    String? status,
  }) {
    return ResellerModel(
      resellerId: resellerId ?? this.resellerId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      countryFlag: countryFlag ?? this.countryFlag,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      coinBalance: coinBalance ?? this.coinBalance,
      isOnline: isOnline ?? this.isOnline,
      status: status ?? this.status,
    );
  }
}
