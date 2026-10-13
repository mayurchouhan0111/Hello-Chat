import 'dart:io';
import 'package:archive/archive.dart' as archive;
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/utils/svga_parser_util.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MovieEntity loadMovie(String path) {
    final file = File(path);
    final bytes = file.readAsBytesSync();
    final inflated = archive.ZLibDecoder().decodeBytes(bytes);
    return MovieEntity.fromBuffer(inflated);
  }

  test('SvgaParserUtil.getPreparedAudios extracts embedded audio correctly', () async {
    // 1. cat_gift.svga (has sound)
    final catMovie = loadMovie('assets/svga/cat_gift.svga');
    expect(catMovie, isA<MovieEntity>());
    final catAudios = await SvgaParserUtil.getPreparedAudios(catMovie, 'assets/svga/cat_gift.svga', 30);
    print('cat_gift audios: ${catAudios.length}');
    expect(catAudios.isNotEmpty, true);
    expect(catAudios.first.file.existsSync(), true);
    expect(catAudios.first.file.lengthSync(), greaterThan(10000));
    expect(catAudios.first.delayMs, 0);

    // 2. 100_optimized.svga (Crystal Palace - has sound)
    final palaceMovie = loadMovie('assets/svga/100_optimized.svga');
    final palaceAudios = await SvgaParserUtil.getPreparedAudios(palaceMovie, 'assets/svga/100_optimized.svga', 30);
    print('100_optimized audios: ${palaceAudios.length}');
    expect(palaceAudios.isNotEmpty, true);
    expect(palaceAudios.first.file.existsSync(), true);

    // 3. 138.svga (has sound)
    final pandaMovie = loadMovie('assets/animations/gifts/138.svga');
    final pandaAudios = await SvgaParserUtil.getPreparedAudios(pandaMovie, 'assets/animations/gifts/138.svga', 30);
    print('138.svga audios: ${pandaAudios.length}');
    expect(pandaAudios.isNotEmpty, true);
    expect(pandaAudios.first.file.existsSync(), true);

    // 4. Love You.svga (has sound)
    final loveMovie = loadMovie('assets/animations/gifts/Love You.svga');
    final loveAudios = await SvgaParserUtil.getPreparedAudios(loveMovie, 'assets/animations/gifts/Love You.svga', 30);
    print('Love You.svga audios: ${loveAudios.length}');
    expect(loveAudios.isNotEmpty, true);
    expect(loveAudios.first.file.existsSync(), true);

    // 5. mystic_rings.svga (no sound)
    final ringMovie = loadMovie('assets/svga/mystic_rings.svga');
    final ringAudios = await SvgaParserUtil.getPreparedAudios(ringMovie, 'assets/svga/mystic_rings.svga', 30);
    print('mystic_rings audios: ${ringAudios.length}');
    expect(ringAudios.isEmpty, true);

    // 6. 235.svga (no sound)
    final carriageMovie = loadMovie('assets/svga/235.svga');
    final carriageAudios = await SvgaParserUtil.getPreparedAudios(carriageMovie, 'assets/svga/235.svga', 30);
    print('235.svga audios: ${carriageAudios.length}');
    expect(carriageAudios.isEmpty, true);
  });
}
