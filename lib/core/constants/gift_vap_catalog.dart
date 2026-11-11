/// Bundled Tencent VAP gift assets in `assets/gifts-vap/`.
///
/// Single source of truth for the VAP gifts shipped inside the app binary.
/// Each entry maps a Firestore `gifts` doc id to its bundled `.vap` file,
/// the overlay [tier] it plays on, and its exact [durationMs].
///
/// The Firestore doc does NOT need any local-path interception: set the doc's
/// `lottieAssetPath` to [GiftVapSpec.assetPath] and the existing pipeline
/// auto-detects the `vap` format and plays it (see `SvgaParserUtil.getLocalVapPath`,
/// which returns any `assets/*.vap` as-is).
///
/// Tier + duration rules (per product spec):
///   NORMAL  ~5s   seat-anchored 200x200
///   MEDIUM  ~10s  mid-ground    360x360
///   LUXURY  15s   full-screen cinematic
/// Durations below are the *actual* encoded length of each `.vap` so the
/// overlay hold matches the animation exactly (no early cut-off, no dead air).
class GiftVapSpec {
  /// Firestore `gifts` document id. Also used as the play/dedupe key.
  final String giftId;

  /// Display name. EDIT THESE to your final gift names before release.
  final String name;

  /// Bundled asset path. Must match the real file under `assets/gifts-vap/`.
  final String assetPath;

  /// Overlay layer: `NORMAL` | `MEDIUM` | `LUXURY`.
  final String tier;

  /// Exact encoded duration in milliseconds (frames / fps).
  final int durationMs;

  /// Suggested price. EDIT to your economy.
  final int priceInDiamonds;

  /// Display size of the RGB frame (the visible animation).
  final int width;
  final int height;

  /// Shelf sort order in the gift panel.
  final int sortOrder;

  /// Icon asset or network URL
  final String imageUrl;

  const GiftVapSpec({
    required this.giftId,
    required this.name,
    required this.assetPath,
    required this.tier,
    required this.durationMs,
    required this.priceInDiamonds,
    required this.width,
    required this.height,
    required this.sortOrder,
    this.imageUrl = '',
  });

  /// Firestore doc body for this gift (drop straight into the `gifts` collection).
  ///
  /// `category` must be exactly `normal` / `medium` / `luxury` (lowercase) or the
  /// gift will not appear in the gift panel shelf (see `GiftPanel` filter).
  /// `animationFormat: 'vap'` is redundant (auto-detected from `.vap`) but explicit.
  Map<String, dynamic> toFirestoreDoc({String? customImageUrl}) => {
        'name': name,
        'priceInDiamonds': priceInDiamonds,
        'category': tier.toLowerCase(),
        'tier': tier,
        'imageUrl': customImageUrl ?? (imageUrl.isNotEmpty ? imageUrl : 'assets/images/gifts/$giftId.png'),
        'lottieAssetPath': assetPath,
        'soundUrl': '',
        'animationFormat': 'vap',
        'durationMs': durationMs,
        'minSvipLevel': 0,
        'sortOrder': sortOrder,
        'isActive': true,
      };
}

class GiftVapCatalog {
  GiftVapCatalog._();

  static const String assetDir = 'assets/gifts-vap';

  /// Target duration per tier (product spec). The overlay derives its minimum
  /// hold from these when a doc's `durationMs` is 0.
  static const int normalTargetMs = 5000;
  static const int mediumTargetMs = 10000;
  static const int luxuryTargetMs = 15000;

  /// Acceptable / hard playback bounds per enforced tier.
  static const int normalMinMs = 4500;
  static const int normalMaxMs = 6000;
  static const int mediumMinMs = 9000;
  static const int mediumMaxMs = 10500;

  /// Target playback duration for a tier (0 when the tier is not enforced).
  static int targetMsForTier(String tier) {
    switch (tier.trim().toUpperCase()) {
      case 'NORMAL':
        return normalTargetMs;
      case 'MEDIUM':
        return mediumTargetMs;
      case 'LUXURY':
        return luxuryTargetMs;
      default:
        return 0;
    }
  }

  /// Hard maximum playback duration for a tier (0 = no hard cap).
  static int maxMsForTier(String tier) {
    switch (tier.trim().toUpperCase()) {
      case 'NORMAL':
        return normalMaxMs;
      case 'MEDIUM':
        return mediumMaxMs;
      default:
        return 0;
    }
  }

  /// Only shelf categories with product duration rules are enforced.
  /// CP (`mystic_rings`), Lucky, VIP, SVIP and Luxury are intentionally excluded.
  static bool isDurationEnforced(String category) {
    switch (category.trim().toLowerCase()) {
      case 'normal':
      case 'medium':
      case 'vap':
      case 'svga':
        return true;
      default:
        return false;
    }
  }

  /// Playback length derived from the asset duration and the tier target/cap.
  /// Pure Dart: no Flutter or `dart:math` dependency.
  static int effectivePlaybackMs({
    required String tier,
    required int assetDurationMs,
  }) {
    final int target = targetMsForTier(tier);
    if (target <= 0) return assetDurationMs;
    final int max = maxMsForTier(tier);
    if (max <= 0) return assetDurationMs > target ? assetDurationMs : target;
    final int min = tier.trim().toUpperCase() == 'NORMAL' ? normalMinMs : mediumMinMs;
    if (assetDurationMs < min) return target;
    if (assetDurationMs > max) return max;
    return assetDurationMs;
  }

  /// All bundled VAP gifts. Order = sortOrder.
  static const List<GiftVapSpec> all = [
    // ── NORMAL ~5s ───────────────────────────────────────────────
    GiftVapSpec(
      giftId: 'vap_gift_13',
      name: 'Sweet Bloom', // EDIT
      assetPath: '$assetDir/gift_13.vap',
      tier: 'NORMAL',
      durationMs: 5000, // 120f @ 24fps
      priceInDiamonds: 10,
      width: 846,
      height: 1504,
      sortOrder: 0,
    ),
    GiftVapSpec(
      giftId: 'vap_gift_12',
      name: 'Mini Rose',
      assetPath: '$assetDir/gift_12.vap',
      tier: 'NORMAL',
      durationMs: 5333, // 128f @ 24fps
      priceInDiamonds: 10,
      width: 846,
      height: 1504,
      sortOrder: 1,
      imageUrl: 'assets/images/gifts/vap_gift_12.png',
    ),
    GiftVapSpec(
      giftId: 'vap_gift_11',
      name: 'Twinkle Star',
      assetPath: '$assetDir/gift_11.vap',
      tier: 'NORMAL',
      durationMs: 6000, // 144f @ 24fps
      priceInDiamonds: 20,
      width: 846,
      height: 1504,
      sortOrder: 2,
      imageUrl: 'assets/images/gifts/vap_gift_11.png',
    ),
    GiftVapSpec(
      giftId: 'vap_gift_10',
      name: 'Candy Heart',
      assetPath: '$assetDir/gift_10.vap',
      tier: 'NORMAL',
      durationMs: 6667, // 160f @ 24fps
      priceInDiamonds: 50,
      width: 846,
      height: 1504,
      sortOrder: 3,
      imageUrl: 'assets/images/gifts/vap_gift_10.png',
    ),

    // ── MEDIUM ~10s ──────────────────────────────────────────────
    GiftVapSpec(
      giftId: 'vap_gift_2',
      name: 'Sweet Bear',
      assetPath: '$assetDir/gift_2.vap',
      tier: 'MEDIUM',
      durationMs: 7800, // 195f @ 25fps
      priceInDiamonds: 200,
      width: 478,
      height: 850,
      sortOrder: 4,
      imageUrl: 'assets/images/gifts/vap_gift_2.png',
    ),
    GiftVapSpec(
      giftId: 'vap_gift_3',
      name: 'Neon Heart',
      assetPath: '$assetDir/gift_3.vap',
      tier: 'MEDIUM',
      durationMs: 9600, // 240f @ 25fps
      priceInDiamonds: 300,
      width: 720,
      height: 1280,
      sortOrder: 5,
      imageUrl: 'assets/images/gifts/vap_gift_3.png',
    ),

    // ── LUXURY 15s ───────────────────────────────────────────────
    GiftVapSpec(
      giftId: 'vap_gift_9',
      name: 'Crystal Castle',
      assetPath: '$assetDir/gift_9.vap',
      tier: 'LUXURY',
      durationMs: 11900, // 357f @ 30fps
      priceInDiamonds: 2000,
      width: 846,
      height: 1504,
      sortOrder: 6,
      imageUrl: 'assets/images/gifts/vap_gift_9.png',
    ),
    GiftVapSpec(
      giftId: 'vap_gift_8',
      name: 'Royal Crown',
      assetPath: '$assetDir/gift_8.vap',
      tier: 'LUXURY',
      durationMs: 15567, // 467f @ 30fps
      priceInDiamonds: 5000,
      width: 846,
      height: 1504,
      sortOrder: 7,
      imageUrl: 'assets/images/gifts/vap_gift_8.png',
    ),

    // ── Gemini-cleaned VAP gifts (gift_14..22) ──────────────────────────
    GiftVapSpec(
      giftId: 'vap_gift_14',
      name: 'Shadow Knight', // EDIT
      assetPath: '$assetDir/gift_14.vap',
      tier: 'LUXURY',
      durationMs: 13000, // 390f @ 30fps
      priceInDiamonds: 2000,
      width: 846,
      height: 1504,
      sortOrder: 8,
      imageUrl: 'assets/images/gifts/vap_gift_14.png',
    ),
    GiftVapSpec(
      giftId: 'vap_gift_15',
      name: 'Blazing Sword', // EDIT
      assetPath: '$assetDir/gift_15.vap',
      tier: 'MEDIUM',
      durationMs: 10000, // 240f @ 24fps
      priceInDiamonds: 250,
      width: 720,
      height: 1280,
      sortOrder: 9,
      imageUrl: 'assets/images/gifts/vap_gift_15.png',
    ),
    GiftVapSpec(
      giftId: 'vap_gift_16',
      name: 'Christmas Ride', // EDIT
      assetPath: '$assetDir/gift_16.vap',
      tier: 'MEDIUM',
      durationMs: 10000, // 240f @ 24fps
      priceInDiamonds: 250,
      width: 720,
      height: 1280,
      sortOrder: 10,
      imageUrl: 'assets/images/gifts/vap_gift_16.png',
    ),
    GiftVapSpec(
      giftId: 'vap_gift_17',
      name: 'Golden Promise', // EDIT
      assetPath: '$assetDir/gift_17.vap',
      tier: 'NORMAL',
      durationMs: 6833, // 164f @ 24fps
      priceInDiamonds: 30,
      width: 720,
      height: 1280,
      sortOrder: 11,
      imageUrl: 'assets/images/gifts/vap_gift_17.png',
    ),
    GiftVapSpec(
      giftId: 'vap_gift_18',
      name: 'Wedding Vows', // EDIT
      assetPath: '$assetDir/gift_18.vap',
      tier: 'NORMAL',
      durationMs: 6875, // 165f @ 24fps
      priceInDiamonds: 40,
      width: 720,
      height: 1280,
      sortOrder: 12,
      imageUrl: 'assets/images/gifts/vap_gift_18.png',
    ),
    GiftVapSpec(
      giftId: 'vap_gift_19',
      name: 'Cake Date', // EDIT
      assetPath: '$assetDir/gift_19.vap',
      tier: 'MEDIUM',
      durationMs: 9000, // 216f @ 24fps
      priceInDiamonds: 200,
      width: 720,
      height: 1280,
      sortOrder: 13,
      imageUrl: 'assets/images/gifts/vap_gift_19.png',
    ),
    GiftVapSpec(
      giftId: 'vap_gift_20',
      name: 'Glam Sheep', // EDIT
      assetPath: '$assetDir/gift_20.vap',
      tier: 'NORMAL',
      durationMs: 7417, // 178f @ 24fps
      priceInDiamonds: 50,
      width: 720,
      height: 1280,
      sortOrder: 14,
      imageUrl: 'assets/images/gifts/vap_gift_20.png',
    ),
    GiftVapSpec(
      giftId: 'vap_gift_21',
      name: 'Red Lotus', // EDIT
      assetPath: '$assetDir/gift_21.vap',
      tier: 'MEDIUM',
      durationMs: 10000, // 240f @ 24fps
      priceInDiamonds: 300,
      width: 720,
      height: 1280,
      sortOrder: 15,
      imageUrl: 'assets/images/gifts/vap_gift_21.png',
    ),
    GiftVapSpec(
      giftId: 'vap_gift_22',
      name: 'Tearful Sheep', // EDIT
      assetPath: '$assetDir/gift_22.vap',
      tier: 'NORMAL',
      durationMs: 8000, // 192f @ 24fps
      priceInDiamonds: 50,
      width: 720,
      height: 1280,
      sortOrder: 16,
      imageUrl: 'assets/images/gifts/vap_gift_22.png',
    ),
  ];

  static GiftVapSpec? byId(String giftId) {
    for (final s in all) {
      if (s.giftId == giftId) return s;
    }
    return null;
  }

  static List<GiftVapSpec> forTier(String tier) =>
      all.where((s) => s.tier == tier.toUpperCase()).toList();

  static List<GiftVapSpec> get normal => forTier('NORMAL');
  static List<GiftVapSpec> get medium => forTier('MEDIUM');
  static List<GiftVapSpec> get luxury => forTier('LUXURY');
}
