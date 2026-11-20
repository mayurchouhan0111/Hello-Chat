import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/room_model.dart';
import '../../../../core/providers/room_support_provider.dart';
import '../../../../core/utils/rocket_vap_config.dart';
import '../../../../core/widgets/svga_player.dart';
import 'rocket_detail_sheet.dart';

class RocketProgressWidget extends ConsumerWidget {
  const RocketProgressWidget({super.key, required this.room});

  final RoomModel room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(roomSupportConfigProvider).valueOrNull;
    final level = room.rocketLevel.clamp(0, 4);
    final target = roomSupportCoinsTargets(config)[level];
    final progress = (room.rocketFuel / target).clamp(0.0, 1.0);
    const fallback = 'assets/stickers/audio_party/audio_24_rocket_3d.png';

    final rocket = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox.square(
          dimension: 36,
          child: MediaQuery.disableAnimationsOf(context)
              ? Image.asset(fallback)
              : SvgaPlayer(
                  key: ValueKey(level),
                  assetPath: RocketVapConfig.svgaIconPath(level),
                  fallbackImagePath: fallback,
                  maxFps: 20,
                  maxRenderSize: const Size.square(120),
                ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 36,
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
            backgroundColor: const Color(0xCC263352),
            color: const Color(0xFF92BCFF),
          ),
        ),
      ],
    );

    final until = room.rocketCooldownUntil;
    final cooling = room.rocketStatus == 'cooldown' &&
        until != null &&
        until.isAfter(DateTime.now());
    return RepaintBoundary(
      child: Tooltip(
        message: 'Room Rocket · Level ${level + 1}',
        child: Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => RocketDetailSheet(room: room),
            ),
            child: SizedBox.square(
              dimension: 48,
              child: cooling
                  ? StreamBuilder<int>(
                      stream: Stream.periodic(
                              const Duration(seconds: 1), (i) => i)
                          .take(until.difference(DateTime.now()).inSeconds + 2),
                      builder: (context, _) {
                        final left = until.difference(DateTime.now());
                        if (left.isNegative) return rocket;
                        final seconds =
                            (left.inSeconds % 60).toString().padLeft(2, '0');
                        return Semantics(
                          label: 'Rocket cooldown',
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.hourglass_bottom_rounded,
                                  size: 17, color: Color(0xFF9EE5FF)),
                              Flexible(
                                  child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '${left.inMinutes}:$seconds',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600),
                                      ))),
                            ],
                          ),
                        );
                      },
                    )
                  : rocket,
            ),
          ),
        ),
      ),
    );
  }
}
