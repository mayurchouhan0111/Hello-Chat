import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/room_model.dart';
import '../../../../core/providers/room_support_provider.dart';
import '../../../../core/utils/week_helper.dart';
import '../../../../services/room_support_service.dart';
import 'floating_lucky_bag_widget.dart';
import 'rocket_progress_widget.dart';

class LiveRoomLayout extends StatelessWidget {
  const LiveRoomLayout({
    super.key,
    required this.room,
    required this.header,
    required this.seats,
    required this.chat,
    required this.actionBar,
    this.welcomeBanner,
  });

  final RoomModel room;
  final Widget header;
  final Widget seats;
  final Widget chat;
  final Widget actionBar;
  final Widget? welcomeBanner;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          header,
          Expanded(child: SingleChildScrollView(primary: false, child: seats)),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 6),
            child: SizedBox(
              height: room.capacity >= 12
                  ? (MediaQuery.sizeOf(context).height * 0.18)
                      .clamp(125.0, 175.0)
                  : (MediaQuery.sizeOf(context).height * 0.25)
                      .clamp(160.0, 240.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: chat),
                  FloatingLuckyBagWidget(roomId: room.roomId),
                  const SizedBox(width: 4),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      RocketProgressWidget(room: room),
                      const SizedBox(height: 6),
                      _RoomSupportButton(roomId: room.roomId),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.only(bottom: 4), child: actionBar),
        ],
      ),
    );
  }
}

class _RoomSupportButton extends ConsumerWidget {
  const _RoomSupportButton({required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycle = ref.watch(roomSupportCycleProvider(roomId)).valueOrNull;
    final current = cycle?['weekId'] == WeekHelper.getCurrentServerWeekId();
    final coins = current ? (cycle?['totalCoins'] as num?)?.toInt() ?? 0 : 0;
    final level = RoomSupportService.calculateLevel(coins);
    return Tooltip(
      message: level > 0 ? 'Room Support · Level $level' : 'Room Support',
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/room-support', extra: {'roomId': roomId}),
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/images/room_support_hero.png',
                    width: 44,
                    height: 44,
                    cacheWidth: 160,
                    excludeFromSemantics: true),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
