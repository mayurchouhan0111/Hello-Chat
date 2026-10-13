import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/utils/svga_parser_util.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SVGAAnimationController forward behavior test', (WidgetTester tester) async {
    final movie = await SvgaParserUtil.decodeSafeFromAssets('assets/svga/cat_gift.svga');
    expect(movie, isNotNull);

    late SVGAAnimationController controller;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            final tickerProvider = tester;
            controller = SVGAAnimationController(vsync: tickerProvider);
            controller.videoItem = movie;
            controller.forward(from: 0.0);
            return SVGAImage(controller);
          },
        ),
      ),
    );

    expect(controller.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.value, greaterThan(0.0));
  });
}
