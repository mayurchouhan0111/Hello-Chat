import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Test decoding of SVGA files', () async {
    final dir = Directory('assets/VIP/VIP 1');
    expect(dir.existsSync(), true);

    final files = dir.listSync().where((f) => f.path.endsWith('.svga')).toList();
    for (final file in files) {
      final bytes = await File(file.path).readAsBytes();
      print('========================================');
      print('File: ${file.path}');
      try {
        final inflatedBytes = ZLibDecoder().decodeBytes(bytes);
        print('  Decoded bytes size: ${inflatedBytes.length}');
        final movie = MovieEntity.fromBuffer(inflatedBytes);
        print('  MovieEntity parsed successfully: version=${movie.version}');
        print('  Images count: ${movie.images.length}');
        movie.images.forEach((key, val) {
          print('    - Image key: $key (${val.length} bytes)');
        });
      } catch (e) {
        print('  ❌ ERROR: failed to decode/parse SVGA: $e');
      }
    }
  });
}
