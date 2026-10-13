import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';

void main() {
  test('client-supplied cat_gift.svga decodes as a valid SVGA', () async {
    final file = File('assets/svga/cat_gift.svga');
    expect(file.existsSync(), true);

    final inflated = ZLibDecoder().decodeBytes(await file.readAsBytes());
    final movie = MovieEntity.fromBuffer(inflated);

    expect(movie.version, isNotEmpty);
    expect(movie.images, isNotEmpty);
    expect(movie.sprites, isNotEmpty);
    print('cat_gift.svga OK: version=${movie.version} '
        'images=${movie.images.length} sprites=${movie.sprites.length} audios=${movie.audios.length}');
    for (final a in movie.audios) {
      print('  Audio: key=${a.audioKey} start=${a.startFrame} end=${a.endFrame}');
    }

    final svgaDir = Directory('assets/svga');
    for (final f in svgaDir.listSync().whereType<File>().where((f) => f.path.endsWith('.svga'))) {
      final inf = ZLibDecoder().decodeBytes(await f.readAsBytes());
      final m = MovieEntity.fromBuffer(inf);
      print('${f.path}: audios=${m.audios.length}');
      for (final a in m.audios) {
        print('  Audio in ${f.path}: key=${a.audioKey} start=${a.startFrame} end=${a.endFrame}');
      }
    }
  });
}
