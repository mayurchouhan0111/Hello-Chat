import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SVGAAnimationController forward behavior test', (WidgetTester tester) async {
    // Exercise controller timing independently of asset decoding and codecs.
    final movie = MovieEntity()
      ..version = '2.0'
      ..params = (MovieParams()
        ..viewBoxWidth = 100
        ..viewBoxHeight = 100
        ..fps = 30
        ..frames = 60);

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
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
