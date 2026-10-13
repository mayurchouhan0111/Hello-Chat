import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/gift_model.dart';
import 'package:hello_chat/core/utils/svga_parser_util.dart';

void main() {
  group('SvgaParserUtil Asset Interception & Format Verification', () {
    test('Cloudinary SVGA URLs and gift IDs map to bundled SVGA assets', () {
      // Mystic Rings
      expect(
        SvgaParserUtil.getLocalGiftSvgaPath('https://res.cloudinary.com/dceh4ob2i/raw/upload/v1788474871/gifts/animations/qmoxmf6o8n03nxklpk8d.svga'),
        equals('assets/svga/mystic_rings.svga'),
      );
      expect(
        SvgaParserUtil.getLocalGiftSvgaPath('', giftId: 'mystic_rings'),
        equals('assets/svga/mystic_rings.svga'),
      );

      // Crystal Palace
      expect(
        SvgaParserUtil.getLocalGiftSvgaPath('https://res.cloudinary.com/dceh4ob2i/raw/upload/v1788474874/gifts/animations/omoseg3av1jq44ttwh8y.svga'),
        equals('assets/svga/100_optimized.svga'),
      );
      expect(
        SvgaParserUtil.getLocalGiftSvgaPath('', giftId: 'crystal_palace'),
        equals('assets/svga/100_optimized.svga'),
      );

      // Royal Carriage
      expect(
        SvgaParserUtil.getLocalGiftSvgaPath('https://res.cloudinary.com/dceh4ob2i/raw/upload/v1788474872/gifts/animations/lec9nqerf5xwsk2enf05.svga'),
        equals('assets/svga/235.svga'),
      );
      expect(
        SvgaParserUtil.getLocalGiftSvgaPath('', giftId: 'royal_carriage'),
        equals('assets/svga/235.svga'),
      );

      // Cat Gift
      expect(
        SvgaParserUtil.getLocalGiftSvgaPath('https://local.test/cat_gift.svga'),
        equals('assets/svga/cat_gift.svga'),
      );

      // Moonlight Panda (138.svga)
      expect(
        SvgaParserUtil.getLocalGiftSvgaPath('https://firebasestorage.googleapis.com/.../animation_1790953721172_138.svga'),
        equals('assets/animations/gifts/138.svga'),
      );

      // Love You
      expect(
        SvgaParserUtil.getLocalGiftSvgaPath('https://firebasestorage.googleapis.com/.../animation_1790955395700_Love%20You.svga'),
        equals('assets/animations/gifts/Love You.svga'),
      );
    });

    test('All bundled VAP / MP4 gifts map to local video assets', () {
      // Golden Dates
      expect(
        SvgaParserUtil.getLocalVapPath('https://firebasestorage.googleapis.com/.../animation_1790956334312_video.mp4', giftId: '1KH8e0SllU6TMYt7XysW'),
        equals('assets/animations/gifts/normal gift/lucky gift dates/video.mp4'),
      );

      // Golden Bell
      expect(
        SvgaParserUtil.getLocalVapPath('https://firebasestorage.googleapis.com/.../animation_1790956201919_video.mp4', giftId: 'adsj76GIQxiSYoPUIHJB'),
        equals('assets/animations/gifts/lucky gifts bell vap/lucky gifts bell vap/video.mp4'),
      );

      // Grand Piano
      expect(
        SvgaParserUtil.getLocalVapPath('https://firebasestorage.googleapis.com/.../animation_1790955592582_video.mp4', giftId: 'klpyoRCQMkbibDPlRe5G'),
        equals('assets/animations/gifts/169522/video.mp4'),
      );

      // Gourmet Feast
      expect(
        SvgaParserUtil.getLocalVapPath('https://firebasestorage.googleapis.com/.../animation_1790955912123_video.mp4', giftId: 'APOJwtxO9PfKBJz0aSiv'),
        equals('assets/animations/gifts/2529/video.mp4'),
      );

      // Sweet Romance
      expect(
        SvgaParserUtil.getLocalVapPath('https://firebasestorage.googleapis.com/.../animation_1790955821224_video.mp4', giftId: '4Kov1uz5BqFXjkvIkscS'),
        equals('assets/animations/gifts/251779/video.mp4'),
      );

      // Ruby Excalibur
      expect(
        SvgaParserUtil.getLocalVapPath('https://firebasestorage.googleapis.com/.../animation_1790956012255_video.mp4', giftId: 'x8Mo9Guuiz5XRstpjYkL'),
        equals('assets/animations/gifts/256006/video.mp4'),
      );

      // Crystal Princess
      expect(
        SvgaParserUtil.getLocalVapPath('https://firebasestorage.googleapis.com/.../animation_1790955699875_video.mp4', giftId: 'bDMkvLHqDMRVvoXonxLn'),
        equals('assets/animations/gifts/219667/video.mp4'),
      );

      // Crystal Windchime
      expect(
        SvgaParserUtil.getLocalVapPath('https://firebasestorage.googleapis.com/.../animation_1790956102727_video.mp4', giftId: 'PZjkxr8gMffDYFJ4qsAE'),
        equals('assets/animations/gifts/tencent-VAP-music/video.mp4'),
      );
    });

    test('Cloudinary Lottie URLs and IDs map to bundled JSON assets', () {
      // Rose
      expect(
        SvgaParserUtil.getLocalLottiePath('https://res.cloudinary.com/dceh4ob2i/raw/upload/v1788474860/gifts/animations/r3bwgs65eoklpc7uwcqc.json', giftId: 'rose'),
        equals('assets/animations/lottie/Rose.json'),
      );

      // Balloon
      expect(
        SvgaParserUtil.getLocalLottiePath('https://res.cloudinary.com/dceh4ob2i/raw/upload/v1788474862/gifts/animations/pucdrkh5wlymjygjpmj2.json', giftId: 'balloon'),
        equals('assets/animations/lottie/balloon.json'),
      );

      // Celebration Cake
      expect(
        SvgaParserUtil.getLocalLottiePath('https://res.cloudinary.com/dceh4ob2i/raw/upload/v1788474863/gifts/animations/dqvyi6mzfdihmswi5urq.json', giftId: 'cake'),
        equals('assets/animations/lottie/Celebration.json'),
      );

      // Car King
      expect(
        SvgaParserUtil.getLocalLottiePath('https://res.cloudinary.com/dceh4ob2i/raw/upload/v1788474868/gifts/animations/oky1znbm0zkuj6fwfzgb.json', giftId: 'car_king'),
        equals('assets/animations/lottie/Red Car.json'),
      );

      // Gold Crown
      expect(
        SvgaParserUtil.getLocalLottiePath('https://res.cloudinary.com/dceh4ob2i/raw/upload/v1788474869/gifts/animations/ioet2naw5dskdk1iyi1q.json', giftId: 'crown'),
        equals('assets/animations/lottie/Premium Gold.json'),
      );

      // Rocket
      expect(
        SvgaParserUtil.getLocalLottiePath('https://res.cloudinary.com/dceh4ob2i/raw/upload/v1788474870/gifts/animations/nc7tzgz2ndzt79nh8ohr.json', giftId: 'rocket'),
        equals('assets/animations/lottie/Rocket loader.json'),
      );
    });

    test('GiftModel.fromMap auto-detects SVGA and VAP format from URLs even if format field is json or empty', () {
      final svgaDoc = {
        'name': 'Mystic Rings',
        'animation_url': 'https://res.cloudinary.com/.../qmoxmf6o8n03nxklpk8d.svga',
        'animationFormat': 'json',
      };
      final gift = GiftModel.fromMap(svgaDoc, 'mystic_rings');
      expect(gift.animationFormat, equals('svga'));

      final vapDoc = {
        'name': 'Ruby Excalibur',
        'animation_url': 'https://firebasestorage.googleapis.com/.../animation_1790956012255_video.mp4',
        'animationFormat': '',
      };
      final vapGift = GiftModel.fromMap(vapDoc, 'x8Mo9Guuiz5XRstpjYkL');
      expect(vapGift.animationFormat, equals('vap'));
    });
  });
}
