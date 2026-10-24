import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/gift_animation_overlay.dart';

Uint8List _box(String type, List<int> payload) {
  final int size = 8 + payload.length;
  return Uint8List.fromList([
    (size >> 24) & 0xff,
    (size >> 16) & 0xff,
    (size >> 8) & 0xff,
    size & 0xff,
    ...type.codeUnits,
    ...payload,
  ]);
}

/// Minimal MP4: ftyp + moov > trak > mdia > hdlr with [handlerType].
Uint8List _mp4WithHandler(String handlerType) {
  final Uint8List hdlr = _box('hdlr', <int>[
    0, 0, 0, 0, // version + flags
    0, 0, 0, 0, // pre_defined
    ...handlerType.codeUnits,
  ]);
  final Uint8List mdia = _box('mdia', hdlr);
  final Uint8List trak = _box('trak', mdia);
  final Uint8List moov = _box('moov', trak);
  final Uint8List ftyp = _box('ftyp', <int>[0x69, 0x73, 0x6f, 0x6d]); // 'isom'
  return Uint8List.fromList(<int>[...ftyp, ...moov]);
}

void main() {
  test('bundled gift_8.vap has an audio track', () async {
    expect(await mp4HasAudioTrack('assets/gifts-vap/gift_8.vap'), isTrue);
  });

  test('bundled gift_12.vap has an audio track', () async {
    expect(await mp4HasAudioTrack('assets/gifts-vap/gift_12.vap'), isTrue);
  });

  test('video-only mp4 reports no audio track', () async {
    final File f = File('${Directory.systemTemp.path}/hc_video_only.mp4')
      ..writeAsBytesSync(_mp4WithHandler('vide'));
    expect(await mp4HasAudioTrack(f.path), isFalse);
    f.deleteSync();
  });

  test('mp4 with soun handler reports audio track', () async {
    final File f = File('${Directory.systemTemp.path}/hc_soun.mp4')
      ..writeAsBytesSync(_mp4WithHandler('soun'));
    expect(await mp4HasAudioTrack(f.path), isTrue);
    f.deleteSync();
  });

  test('missing file reports no audio track (soundUrl fallback plays)', () async {
    expect(await mp4HasAudioTrack('${Directory.systemTemp.path}/hc_missing.vap'), isFalse);
  });

  test('real ffmpeg no-audio mp4 reports no audio track', () async {
    final File f = File('${Directory.systemTemp.path}/noaudio_test.mp4');
    if (!f.existsSync()) return; // optional local fixture
    expect(await mp4HasAudioTrack(f.path), isFalse);
  });
}
