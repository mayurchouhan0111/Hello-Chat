import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SVGAAnimationController inspection', () async {
    final file = File('assets/svga/cat_gift.svga');
    final inflated = ZLibDecoder().decodeBytes(await file.readAsBytes());
    final movie = MovieEntity.fromBuffer(inflated);

    print('movie.params.frames: ${movie.params.frames}');
    print('movie.params.fps: ${movie.params.fps}');
    final vsync = const TestVSync();
    final ctrl = SVGAAnimationController(vsync: vsync);
    ctrl.videoItem = movie;
    print('ctrl.duration: ${ctrl.duration}');
    print('ctrl.frames: ${ctrl.frames}');
  });
}
