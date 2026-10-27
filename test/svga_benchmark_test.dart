import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';

void main() {
  test('Benchmark SVGA protobuf inflation and memory footprint', () {
    final targets = [
      ('cat_gift.svga', 'assets/svga/cat_gift.svga'),
      ('Crown 1_SVGA_SVGA.svga (SVIP 5)', 'assets/SVIP Kit/svip 5/Crown 1_SVGA_SVGA.svga'),
      ('Crown 1.svga (VIP 2)', 'assets/VIP/VIP 2/VIP 2/Crown 1.svga'),
    ];

    print('\n================ SVGA PROTOBUF DEFLATION & RAM BENCHMARK ================');
    for (final (label, relPath) in targets) {
      final f = File(relPath);
      final rawBytes = f.readAsBytesSync();
      final compressedLen = rawBytes.length;

      final sw = Stopwatch()..start();
      List<int> inflated;
      try {
        inflated = ZLibDecoder().decodeBytes(rawBytes);
      } catch (e) {
        inflated = rawBytes;
      }
      sw.stop();

      print('\n[$label]');
      print('  On-Disk File Size:       ${(compressedLen / (1024 * 1024)).toStringAsFixed(2)} MB ($compressedLen bytes)');
      print('  Inflated Protobuf Size:  ${(inflated.length / (1024 * 1024)).toStringAsFixed(2)} MB (${inflated.length} bytes)');
      print('  ZLib Parse / Inflate:    ${sw.elapsedMilliseconds} ms');
      print('  RAM Impact:              MovieEntity holds uncompressed protobuf + decoded bitmaps in RAM');
    }
    print('=========================================================================\n');
  });
}
