import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/room_theme_model.dart';
import 'package:hello_chat/core/providers/auth_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/seat_grid.dart';

void main() {
  for (final theme in RoomThemeCatalog.allThemes) {
    for (final capacity in [8, 9, 12, 13, 16]) {
      for (final youtube in [false, true]) {
        for (final width in [320.0, 393.0]) {
          testWidgets('${theme.id} seats=$capacity youtube=$youtube width=$width large text', (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(ProviderScope(
              overrides: [
                authStateProvider.overrideWith((ref) => Stream.value(null)),
                roomParticipantsProvider.overrideWith((ref, id) => Stream.value([])),
                batchedProfilesProvider.overrideWith((ref, ids) => Stream.value({})),
              ],
              child: MaterialApp(home: MediaQuery(
                data: MediaQueryData(size: Size(width, 800), textScaler: const TextScaler.linear(2)),
                child: Scaffold(body: Align(alignment: Alignment.topCenter, child: SizedBox(
                  height: 480,
                  child: SeatGrid(roomId: 'layout-only', capacity: capacity,
                    isYoutubeActive: youtube, theme: theme,
                    onSeatTap: (_) {}, onSeatLongPress: (_) {}, onUserLongPress: (_) {}),
                ))),
              )),
            ));
            await tester.pump();
            final seats = find.byType(EmptySeatWidget);
            expect(seats, findsNWidgets(youtube ? capacity : capacity - 1));
            for (final element in seats.evaluate()) {
              final rect = tester.getRect(find.byWidget(element.widget));
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(width));
              expect(rect.bottom, lessThanOrEqualTo(480));
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          });
        }
      }
    }
  }
}
