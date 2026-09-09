import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hello_chat/core/widgets/svg_page_transition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SvgPageTransition Tests', () {
    testWidgets('renders destination child when animation is complete (t=1.0)', (tester) async {
      const targetText = 'Leaderboard Screen Content';
      
      await tester.pumpWidget(
        const MaterialApp(
          home: SvgPageTransition(
            animation: AlwaysStoppedAnimation<double>(1.0),
            child: Scaffold(body: Center(child: Text(targetText))),
          ),
        ),
      );

      expect(find.text(targetText), findsOneWidget);
    });

    testWidgets('renders animated SVG portal and overlay during in-between transition (t=0.5)', (tester) async {
      const targetText = 'Incoming Destination Screen';

      await tester.pumpWidget(
        const MaterialApp(
          home: SvgPageTransition(
            animation: AlwaysStoppedAnimation<double>(0.5),
            style: SvgTransitionStyle.cyberPortal,
            child: Scaffold(body: Center(child: Text(targetText))),
          ),
        ),
      );

      // Verify that SvgPicture widgets are active in the tree
      expect(find.byType(SvgPicture), findsWidgets);
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('animates through full transition sequence from 0.0 to 1.0 without errors', (tester) async {
      late AnimationController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return _TestTransitionHost(
                onControllerCreated: (c) => controller = c,
              );
            },
          ),
        ),
      );

      // Initial state (t = 0.0)
      expect(controller.value, 0.0);
      await tester.pump();

      // Forward halfway (t = 0.5)
      controller.value = 0.5;
      await tester.pump();
      expect(find.byType(SvgPicture), findsWidgets);

      // Forward to completion (t = 1.0)
      controller.value = 1.0;
      await tester.pumpAndSettle();
      expect(find.text('Page Destination Active'), findsOneWidget);
    });

    testWidgets('renders diagonal wipe style with cyber blade SVGs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SvgPageTransition(
            animation: AlwaysStoppedAnimation<double>(0.5),
            style: SvgTransitionStyle.diagonalWipe,
            child: Scaffold(body: Center(child: Text('Diagonal Target'))),
          ),
        ),
      );

      expect(find.byType(SvgPicture), findsWidgets);
    });

    testWidgets('buildSvgTransitionPage generates a valid CustomTransitionPage', (tester) async {
      final transitionPage = buildSvgTransitionPage(
        key: const ValueKey('test_key'),
        child: const Text('Page Content'),
      );

      expect(transitionPage.key, const ValueKey('test_key'));
      expect(transitionPage.transitionDuration, const Duration(milliseconds: 620));
      expect(transitionPage.reverseTransitionDuration, const Duration(milliseconds: 480));
    });

    testWidgets('SvgPageRoute creates a functional PageRouteBuilder', (tester) async {
      final route = SvgPageRoute(
        builder: (_) => const Scaffold(body: Text('Route Builder Content')),
      );

      expect(route.transitionDuration, const Duration(milliseconds: 620));
      expect(route.reverseTransitionDuration, const Duration(milliseconds: 480));
    });
  });
}

class _TestTransitionHost extends StatefulWidget {
  const _TestTransitionHost({required this.onControllerCreated});

  final ValueChanged<AnimationController> onControllerCreated;

  @override
  State<_TestTransitionHost> createState() => _TestTransitionHostState();
}

class _TestTransitionHostState extends State<_TestTransitionHost> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    widget.onControllerCreated(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SvgPageTransition(
      animation: _controller,
      child: const Scaffold(
        body: Center(child: Text('Page Destination Active')),
      ),
    );
  }
}
