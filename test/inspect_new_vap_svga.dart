import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';

void main() async {
  final baseDir = Directory('assets/animations/VAP');
  final files = baseDir.listSync().where((f) => f.path.endsWith('.svga')).toList();
  files.sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final bytes = await File(file.path).readAsBytes();
    print('=' * 80);
    print('FILE: ${file.path} (${bytes.length} bytes)');
    print('=' * 80);

    try {
      final inflatedBytes = ZLibDecoder().decodeBytes(bytes);
      final movie = MovieEntity.fromBuffer(inflatedBytes);
      
      print('  Version: ${movie.version}');
      print('  Params:');
      print('    viewBox: ${movie.params.viewBoxWidth} x ${movie.params.viewBoxHeight}');
      print('    fps: ${movie.params.fps}');
      print('    frames: ${movie.params.frames}');

      // IMAGES - these are the dynamically replaceable image slots
      print('');
      print('  IMAGES (${movie.images.length}):');
      if (movie.images.isEmpty) {
        print('    NONE - No images found');
      } else {
        movie.images.forEach((key, val) {
          print('    - Key: "$key" (${val.length} bytes)');
        });
      }

      // SPRITES
      print('');
      print('  SPRITES (${movie.sprites.length}):');
      if (movie.sprites.isEmpty) {
        print('    NONE - No sprites found');
      } else {
        for (int i = 0; i < movie.sprites.length; i++) {
          final sprite = movie.sprites[i];
          print('    Sprite $i:');
          print('      imageKey: "${sprite.imageKey}"');
          print('      frames: ${sprite.frames.length}');
          if (sprite.frames.isNotEmpty) {
            final frame = sprite.frames[0];
            print('      layout: ${frame.layout?.width ?? "?"} x ${frame.layout?.height ?? "?"}');
            print('      transform: tx=${frame.transform?.tx ?? 0}, ty=${frame.transform?.ty ?? 0}, a=${frame.transform?.a ?? 1}, d=${frame.transform?.d ?? 1}');
            print('      alpha: ${frame.alpha ?? 1.0}');
          }
        }
      }

      // Check for any additional metadata in the movie
      print('');
      print('  AUDIO (${movie.audios.length}):');
      for (final audio in movie.audios) {
        print('    - audioKey: "${audio.audioKey}"');
      }

      // Print the proto as JSON for deep inspection
      print('');
      print('  RAW PROTO FIELDS:');
      final jsonStr = jsonEncode(movie.toProto3Json());
      // Print only first 3000 chars to avoid flooding
      if (jsonStr.length > 3000) {
        print('  ${jsonStr.substring(0, 3000)}...');
      } else {
        print('  $jsonStr');
      }

    } catch (e) {
      print('  ERROR: $e');
    }
    print('');
  }

  // Also inspect old rocket SVGA for comparison
  print('');
  print('=' * 80);
  print('COMPARISON: Old rocket SVGA files');
  print('=' * 80);

  final oldDir = Directory('assets/rocket/Rocket set SVGA');
  if (oldDir.existsSync()) {
    final oldFiles = oldDir.listSync().where((f) => f.path.endsWith('.svga')).toList();
    oldFiles.sort((a, b) => a.path.compareTo(b.path));
    for (final file in oldFiles) {
      final bytes = await File(file.path).readAsBytes();
      print('');
      print('--- ${file.path} (${bytes.length} bytes) ---');
      try {
        final inflatedBytes = ZLibDecoder().decodeBytes(bytes);
        final movie = MovieEntity.fromBuffer(inflatedBytes);
        print('  Images: ${movie.images.length}');
        movie.images.forEach((key, val) {
          print('    Key: "$key" (${val.length} bytes)');
        });
        print('  Sprites: ${movie.sprites.length}');
        for (int i = 0; i < movie.sprites.length && i < 5; i++) {
          final sprite = movie.sprites[i];
          print('    Sprite $i: imageKey="${sprite.imageKey}"');
        }
      } catch (e) {
        print('  ERROR: $e');
      }
    }
  }
}
