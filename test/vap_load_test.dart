import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/widgets/vap_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
  });

  test('VapAnimation.preCache loads gift_14.vap', () async {
    final path = await VapAnimation.preCache('assets/gifts-vap/gift_14.vap');
    print('Result for gift_14: $path');
    expect(path, isNotNull);
    expect(File(path!).existsSync(), isTrue);
    print('Extracted file size: ${File(path).lengthSync()} bytes');
  });
}
