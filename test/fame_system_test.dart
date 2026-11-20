import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/fame_model.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/providers/fame_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/widgets/fame_badge.dart';
import 'package:hello_chat/features/profile/presentation/screens/fame_screen.dart';

void main() {
  group('FameCatalog', () {
    test('level boundaries map to the correct tier', () {
      expect(FameCatalog.tierFor(0).level, 1);
      expect(FameCatalog.tierFor(999).level, 1);
      expect(FameCatalog.tierFor(1000).level, 2);
      expect(FameCatalog.tierFor(4999).level, 2);
      expect(FameCatalog.tierFor(5000).level, 3);
      expect(FameCatalog.tierFor(15000000).level, 10);
      expect(FameCatalog.tierFor(999999999).level, 10);
    });

    test('next tier, progress and remaining points', () {
      expect(FameCatalog.nextTier(0)!.title, 'Bright Star');
      expect(FameCatalog.progress(0), 0.0);
      expect(FameCatalog.progress(500), closeTo(0.5, 0.0001));
      expect(FameCatalog.progress(1000), 0.0);
      expect(FameCatalog.pointsToNext(1000), 4000);
      expect(FameCatalog.nextTier(15000000), isNull);
      expect(FameCatalog.progress(15000000), 1.0);
      expect(FameCatalog.pointsToNext(15000000), 0);
    });

    test('FameEntry reads the selected period field', () {
      final doc = {
        'uid': 'u1',
        'displayName': 'Ava',
        'profilePhotoUrl': 'https://example.com/a.png',
        'dailyBeansReceived': 120,
        'weeklyBeansReceived': 900,
        'totalBeansReceived': 25000,
      };

      expect(
          FameEntry.fromMap('u1', doc, pointsField: 'dailyBeansReceived')
              .points,
          120);
      expect(
          FameEntry.fromMap('u1', doc, pointsField: 'weeklyBeansReceived')
              .points,
          900);
      expect(
          FameEntry.fromMap('u1', doc, pointsField: 'totalBeansReceived')
              .tier
              .level,
          4);
    });

    test('each period ranks by the matching public counter', () {
      expect(FamePeriod.daily.field, 'dailyBeansReceived');
      expect(FamePeriod.weekly.field, 'weeklyBeansReceived');
      expect(FamePeriod.monthly.field, 'monthlyBeansReceived');
      expect(FamePeriod.allTime.field, 'totalBeansReceived');
    });

    test('negative and malformed points are sanitized', () {
      expect(FameCatalog.tierFor(-1).level, 1);
      expect(FameCatalog.progress(-500), 0.0);
      expect(FameCatalog.pointsToNext(-500), 1000);

      final entry = FameEntry.fromMap('doc-id', {
        'uid': 'someone-else',
        'displayName': 123,
        'profilePhotoUrl': 42,
        'country': '   ',
        'totalBeansReceived': '1500',
      });
      expect(entry.uid, 'doc-id');
      expect(entry.displayName, '123');
      expect(entry.photoUrl, '42');
      expect(entry.country, isNull);
      expect(entry.points, 1500);

      expect(FameEntry.fromMap('x', {'totalBeansReceived': -50}).points, 0);
      expect(FameEntry.fromMap('y', {'totalBeansReceived': 'nope'}).points, 0);

      final empty = FameEntry.fromMap('z', {'displayName': '  '});
      expect(empty.displayName, 'User');
      expect(empty.photoUrl, '');
      expect(empty.points, 0);
    });

    test('ranking sort is deterministic for equal points', () {
      final entries = [
        const FameEntry(uid: 'b', displayName: 'Zoe', photoUrl: '', points: 10),
        const FameEntry(uid: 'c', displayName: 'amy', photoUrl: '', points: 10),
        const FameEntry(uid: 'a', displayName: 'Amy', photoUrl: '', points: 10),
        const FameEntry(uid: 'd', displayName: 'Max', photoUrl: '', points: 99),
      ];

      FameEntry.sortByRank(entries);

      expect(entries.map((e) => e.uid).toList(), ['d', 'a', 'c', 'b']);
    });
  });

  group('FameBadge', () {
    testWidgets('renders the level and title', (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: FameBadge(points: 25000))));

      expect(find.textContaining('Fame 4'), findsOneWidget);
      expect(find.textContaining('Superstar'), findsOneWidget);
    });

    testWidgets('compact mode shows only the level', (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: FameBadge(points: 0, compact: true))));

      expect(find.text('Fame 1'), findsOneWidget);
    });

    testWidgets('exposes an accessible label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: FameBadge(points: 25000))));

      expect(find.bySemanticsLabel('Fame level 4, Superstar'), findsOneWidget);
      handle.dispose();
    });
  });

  group('FameScreen', () {
    final me = UserModel(
      uid: 'me',
      createdAt: DateTime(2026),
      lastActive: DateTime(2026),
      phoneNumber: '100',
      username: 'me',
      displayName: 'Me',
      totalBeansReceived: 12000,
    );

    Widget buildScreen(List<FameEntry> entries) {
      return ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) => Stream.value(me)),
          fameLeaderboardProvider
              .overrideWith((ref, period) => Stream.value(entries)),
        ],
        child: const MaterialApp(home: FameScreen()),
      );
    }

    testWidgets('shows own fame level and the ranking', (tester) async {
      await tester.pumpWidget(buildScreen(const [
        FameEntry(uid: 'a', displayName: 'Ava', photoUrl: '', points: 25000),
        FameEntry(uid: 'b', displayName: 'Ben', photoUrl: '', points: 300),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Fame Hall'), findsOneWidget);
      expect(find.text('Shining Star'), findsOneWidget);
      expect(find.text('12,000'), findsOneWidget);
      expect(find.text('Ava'), findsOneWidget);
      expect(find.text('Ben'), findsOneWidget);
      expect(find.text('25K'), findsOneWidget);
    });

    testWidgets('shows an empty state when nobody has fame', (tester) async {
      await tester.pumpWidget(buildScreen(const []));
      await tester.pumpAndSettle();

      expect(find.text('No Fame yet'), findsOneWidget);
    });

    testWidgets('period switch queries the selected window', (tester) async {
      final periods = <FamePeriod>[];
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) => Stream.value(me)),
          fameLeaderboardProvider.overrideWith((ref, period) {
            periods.add(period);
            return Stream.value(const <FameEntry>[]);
          }),
        ],
        child: const MaterialApp(home: FameScreen()),
      ));
      await tester.pumpAndSettle();

      expect(periods, [FamePeriod.daily]);

      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();

      expect(periods.last, FamePeriod.weekly);
    });

    testWidgets('shows loading instead of a fake level', (tester) async {
      final profile = StreamController<UserModel?>();
      addTearDown(profile.close);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) => profile.stream),
          fameLeaderboardProvider
              .overrideWith((ref, period) => Stream.value(const <FameEntry>[])),
        ],
        child: const MaterialApp(home: FameScreen()),
      ));
      await tester.pump();

      expect(find.text('Loading Fame…'), findsOneWidget);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('leaderboard error offers a working retry', (tester) async {
      var calls = 0;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) => Stream.value(me)),
          fameLeaderboardProvider.overrideWith((ref, period) {
            calls++;
            return Stream<List<FameEntry>>.error(Exception('offline'));
          }),
        ],
        child: const MaterialApp(home: FameScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Could not load Fame ranking'), findsOneWidget);
      expect(calls, 1);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(calls, 2);
    });

    testWidgets('profile error is surfaced without fake points',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) {
            calls++;
            return Stream<UserModel?>.error(Exception('offline'));
          }),
          fameLeaderboardProvider
              .overrideWith((ref, period) => Stream.value(const <FameEntry>[])),
        ],
        child: const MaterialApp(home: FameScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Fame unavailable'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('0'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(calls, 2);
    });

    testWidgets('long names and 2x text do not overflow', (tester) async {
      tester.view.physicalSize = const Size(960, 9000);
      tester.view.devicePixelRatio = 3.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(buildScreen([
        FameEntry(
          uid: 'a',
          displayName: 'A' * 120,
          photoUrl: '',
          points: 15000000,
        ),
      ]));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Fame 10'), findsWidgets);
    });
  });
}
