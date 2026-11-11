import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Top SnackBar renders at the top with working action', (tester) async {
    bool actionTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  final mq = MediaQuery.of(context);
                  final topOffset = mq.padding.top + 16;
                  // SnackBar height ~48-60, so bottom margin pushes it to top
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Top SnackBar Notification'),
                      behavior: SnackBarBehavior.floating,
                      margin: EdgeInsets.only(
                        bottom: mq.size.height - (topOffset + 68),
                        left: 16,
                        right: 16,
                      ),
                      action: SnackBarAction(
                        label: 'ACTION',
                        onPressed: () {
                          actionTapped = true;
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Show SnackBar'),
              );
            },
          ),
        ),
      ),
    );

    // Tap button to show SnackBar
    await tester.tap(find.text('Show SnackBar'));
    await tester.pumpAndSettle();

    // Verify SnackBar text is found
    expect(find.text('Top SnackBar Notification'), findsOneWidget);

    // Verify position is near the top
    final snackBarTopLeft = tester.getTopLeft(find.text('Top SnackBar Notification'));
    print('SnackBar text Y coordinate: ${snackBarTopLeft.dy}');
    expect(snackBarTopLeft.dy, lessThan(100.0)); // Clearly at the top!

    // Tap Action button
    expect(find.text('ACTION'), findsOneWidget);
    await tester.tap(find.text('ACTION'));
    await tester.pump();
    expect(actionTapped, isTrue);
  });
}

