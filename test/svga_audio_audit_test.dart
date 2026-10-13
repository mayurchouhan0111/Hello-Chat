import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';

void main() {
  test('Audit all SVGA files in assets for embedded audio', () async {
    final assetsDir = Directory('assets');
    final allFiles = assetsDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.svga'))
        .toList();

    print('\n================ SVGA AUDIO AUDIT REPORT ================');
    print('Total SVGA files found: ${allFiles.length}\n');

    final filesWithAudio = <String>[];
    final filesWithoutAudio = <String>[];

    for (final file in allFiles) {
      try {
        final bytes = await file.readAsBytes();
        List<int> inflated;
        if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
          // Zip format
          final archive = ZipDecoder().decodeBytes(bytes);
          final movieBin = archive.findFile('movie.binary');
          if (movieBin != null) {
            inflated = movieBin.content as List<int>;
          } else {
            print('⚠️ [ZIP without movie.binary] ${file.path}');
            continue;
          }
        } else {
          inflated = ZLibDecoder().decodeBytes(bytes);
        }

        final movie = MovieEntity.fromBuffer(inflated);
        if (movie.audios.isNotEmpty) {
          filesWithAudio.add(file.path);
          print('🔊 HAS SOUND: ${file.path}');
          print('   Params: frames=${movie.params.frames}, fps=${movie.params.fps}');
          print('   Audios count: ${movie.audios.length}');
          for (final a in movie.audios) {
            final audioBytes = movie.images[a.audioKey];
            String format = 'UNKNOWN';
            if (audioBytes != null && audioBytes.length >= 4) {
              if (audioBytes[0] == 0x49 && audioBytes[1] == 0x44 && audioBytes[2] == 0x33) {
                format = 'MP3 (ID3)';
              } else if (audioBytes[0] == 0xFF && (audioBytes[1] & 0xE0) == 0xE0) {
                format = 'MP3 (MPEG Sync)';
              } else if (audioBytes[0] == 0x52 && audioBytes[1] == 0x49 && audioBytes[2] == 0x46 && audioBytes[3] == 0x46) {
                format = 'WAV (RIFF)';
              } else if (audioBytes[0] == 0x4F && audioBytes[1] == 0x67 && audioBytes[2] == 0x67 && audioBytes[3] == 0x53) {
                format = 'OGG (OggS)';
              }
            }
            print('   - Key: "${a.audioKey}", startFrame: ${a.startFrame}, endFrame: ${a.endFrame}, startTime: ${a.startTime}, totalTime: ${a.totalTime}, bytes: ${audioBytes?.length ?? 0}, detected format: $format');
          }
        } else {
          filesWithoutAudio.add(file.path);
        }
      } catch (e) {
        print('❌ ERROR reading ${file.path}: $e');
      }
    }

    print('\n================ SUMMARY ================');
    print('Files WITH audio: ${filesWithAudio.length}');
    for (final p in filesWithAudio) {
      print('  + $p');
    }
    print('\nFiles WITHOUT audio: ${filesWithoutAudio.length}');
    print('=========================================\n');
  });
}
