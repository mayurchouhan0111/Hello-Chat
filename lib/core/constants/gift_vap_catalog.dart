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
      giftId: 'vap_gift_1',
      name: 'Aurora Lights',
      assetPath: '$assetDir/gift_1.vap',
      tier: 'MEDIUM',
      durationMs: 9600, // 240f @ 25fps
      priceInDiamonds: 300,
      width: 1280,
      height: 720,
      sortOrder: 5,
      imageUrl: 'assets/images/gifts/vap_gift_1.png',
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
      sortOrder: 6,
      imageUrl: 'assets/images/gifts/vap_gift_3.png',
    ),
    GiftVapSpec(
      giftId: 'vap_gift_4',
      name: 'Pink Kiss',
      assetPath: '$assetDir/gift_4.vap',
      tier: 'MEDIUM',
      durationMs: 10000, // 240f @ 24fps
      priceInDiamonds: 500,
      width: 846,
      height: 1504,
      sortOrder: 7,
      imageUrl: 'assets/images/gifts/vap_gift_4.png',
    ),
    GiftVapSpec(
      giftId: 'vap_gift_5',
      name: 'Rhythm Bell',
      assetPath: '$assetDir/gift_5.vap',
      tier: 'MEDIUM',
      durationMs: 10000, // 240f @ 24fps
      priceInDiamonds: 500,
      width: 1504,
      height: 846,
      sortOrder: 8,
      imageUrl: 'assets/images/gifts/vap_gift_5.png',
    ),
    GiftVapSpec(
      giftId: 'vap_gift_6',
      name: 'Heart Wand',
      assetPath: '$assetDir/gift_6.vap',
      tier: 'MEDIUM',
      durationMs: 10000, // 240f @ 24fps
      priceInDiamonds: 800,
      width: 1504,
      height: 846,
      sortOrder: 9,
      imageUrl: 'assets/images/gifts/vap_gift_6.png',
    ),
    GiftVapSpec(
      giftId: 'vap_gift_7',
      name: 'Treasure Chest',
      assetPath: '$assetDir/gift_7.vap',
      tier: 'MEDIUM',
      durationMs: 10000, // 240f @ 24fps
      priceInDiamonds: 1000,
      width: 846,
      height: 1504,
      sortOrder: 10,
      imageUrl: 'assets/images/gifts/vap_gift_7.png',
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
      sortOrder: 11,
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
      sortOrder: 12,
      imageUrl: 'assets/images/gifts/vap_gift_8.png',
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
