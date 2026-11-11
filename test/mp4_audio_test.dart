import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

Future<bool> mp4HasAudioTrackOld(String path) async {
  try {
    final Uint8List bytes = await File(path).readAsBytes();
    for (final (type, start, end) in _mp4BoxesOld(bytes, 0, bytes.length)) {
      if (type != 'moov') continue;
      for (final (t1, s1, e1) in _mp4BoxesOld(bytes, start, end)) {
        if (t1 != 'trak') continue;
        for (final (t2, s2, e2) in _mp4BoxesOld(bytes, s1, e1)) {
          if (t2 != 'mdia') continue;
          for (final (t3, s3, e3) in _mp4BoxesOld(bytes, s2, e2)) {
            if (t3 == 'hdlr' &&
                e3 - s3 >= 12 &&
                String.fromCharCodes(bytes, s3 + 8, s3 + 12) == 'soun') {
              return true;
            }
          }
        }
      }
    }
    return false;
  } catch (_) {
    return false;
  }
}

Iterable<(String, int, int)> _mp4BoxesOld(Uint8List bytes, int start, int end) sync* {
  int pos = start;
  while (pos + 8 <= end) {
    int size = (bytes[pos] << 24) | (bytes[pos + 1] << 16) | (bytes[pos + 2] << 8) | bytes[pos + 3];
    int header = 8;
    if (size == 1) {
      if (pos + 16 > end) return;
      size = 0;
      for (int i = 0; i < 8; i++) {
        size = (size << 8) | bytes[pos + 8 + i];
      }
      header = 16;
    } else if (size == 0) {
      size = end - pos;
    }
    if (size < header || pos + size > end) return;
    final type = String.fromCharCodes(bytes, pos + 4, pos + 8);
    yield (type, pos + header, pos + size);
    pos += size;
  }
}

Future<bool> mp4HasAudioTrackNew(String path) async {
  RandomAccessFile? raf;
  try {
    final file = File(path);
    if (!await file.exists()) return false;
    final fileLength = await file.length();
    if (fileLength < 16) return false;

    raf = await file.open(mode: FileMode.read);
    return await _hasAudioTrackInBoxes(raf, 0, fileLength);
  } catch (e) {
    return false;
  } finally {
    try {
      await raf?.close();
    } catch (_) {}
  }
}

Future<bool> _hasAudioTrackInBoxes(RandomAccessFile raf, int start, int end) async {
  int pos = start;
  final headerBuffer = Uint8List(16);

  while (pos + 8 <= end) {
    await raf.setPosition(pos);
    final bytesRead = await raf.readInto(headerBuffer, 0, 8);
    if (bytesRead < 8) break;

    int size = (headerBuffer[0] << 24) |
        (headerBuffer[1] << 16) |
        (headerBuffer[2] << 8) |
        headerBuffer[3];
    final type = String.fromCharCodes(headerBuffer.sublist(4, 8));
    int headerSize = 8;

    if (size == 1) {
      if (pos + 16 > end) break;
      final extraRead = await raf.readInto(headerBuffer, 8, 16);
      if (extraRead < 8) break;
      size = 0;
      for (int i = 0; i < 8; i++) {
        size = (size << 8) | headerBuffer[8 + i];
      }
      headerSize = 16;
    } else if (size == 0) {
      size = end - pos;
    }

    if (size < headerSize || pos + size > end) break;

    final payloadStart = pos + headerSize;
    final payloadEnd = pos + size;

    if (type == 'moov' || type == 'trak' || type == 'mdia') {
      if (await _hasAudioTrackInBoxes(raf, payloadStart, payloadEnd)) {
        return true;
      }
    } else if (type == 'hdlr') {
      if (payloadEnd - payloadStart >= 12) {
        await raf.setPosition(payloadStart + 8);
        final hdlrType = await raf.read(4);
        if (hdlrType.length == 4 && String.fromCharCodes(hdlrType) == 'soun') {
          return true;
        }
      }
    }

    pos += size;
  }
  return false;
}

void main() {
  test('mp4HasAudioTrack matches old behavior with zero memory overhead', () async {
    final vapFiles = [
      'assets/gifts-vap/gift_14.vap',
      'assets/gifts-vap/gift_20.vap',
      'assets/gifts-vap/gift_22.vap',
    ];

    for (final path in vapFiles) {
      if (File(path).existsSync()) {
        final oldResult = await mp4HasAudioTrackOld(path);
        final newResult = await mp4HasAudioTrackNew(path);
        expect(newResult, equals(oldResult), reason: 'Failed for $path');
      }
    }
  });
}
