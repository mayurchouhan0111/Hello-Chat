import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/models/participant_model.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import 'viewers_list_sheet.dart';

class ActivePKBattleGrid extends ConsumerWidget {
  final RoomModel room;
  final List<Participant> participants;

  const ActivePKBattleGrid({
    super.key,
    required this.room,
    required this.participants,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Separate participants into teams
    final pkTeams = room.pkTeams ?? {};
    final leftTeam = participants.where((p) => pkTeams[p.uid] == 'left').toList();
    final rightTeam = participants.where((p) => pkTeams[p.uid] == 'right').toList();

    String leftHostUid = '';
    String rightHostUid = '';
    pkTeams.forEach((uid, team) {
      if (team == 'left' && (leftHostUid.isEmpty)) leftHostUid = uid;
      if (team == 'right' && (rightHostUid.isEmpty)) rightHostUid = uid;
    });

    final bool isFinished = room.pkPhase == 'finished';

    return Stack(
      children: [
        Container(
          height: 480,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              // Home Side
              Expanded(
                child: _buildTeamSide(
                  context, ref,
                  title: "HOME",
                  hostUid: leftHostUid,
                  teamMembers: leftTeam.where((p) => p.uid != leftHostUid).toList(),
                  themeColor: const Color(0xFF00E5FF),
                  isLeft: true,
                ),
              ),
              
              // Animated VS Divider
              _buildVSDivider(),

              // Away Side
              Expanded(
                child: _buildTeamSide(
                  context, ref,
                  title: "AWAY",
                  hostUid: rightHostUid,
                  teamMembers: rightTeam.where((p) => p.uid != rightHostUid).toList(),
                  themeColor: const Color(0xFFFF9100),
                  isLeft: false,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.95, 0.95)),

        // 🏆 WINNER SPLASH OVERLAY
        if (isFinished) _buildWinnerSplash(leftHostUid, rightHostUid),
      ],
    );
  }

  Widget _buildVSDivider() {
    return Column(
      children: [
        Expanded(child: Container(width: 1, color: Colors.white10)),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
            border: Border.all(color: Colors.white24, width: 2),
            boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 10)],
          ),
          child: const Text("VS", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
        ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
        Expanded(child: Container(width: 1, color: Colors.white10)),
      ],
    );
  }

  Widget _buildWinnerSplash(String leftHostUid, String rightHostUid) {
    final scores = room.pkScores ?? {};
    int leftTotal = 0, rightTotal = 0;
    room.pkTeams?.forEach((uid, side) {
      if (side == 'left') leftTotal += (scores[uid] ?? 0);
      if (side == 'right') rightTotal += (scores[uid] ?? 0);
    });

    final bool leftWins = leftTotal > rightTotal;
    final bool isDraw = leftTotal == rightTotal;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isDraw) ...[
             const Icon(Icons.stars_rounded, color: Colors.yellow, size: 80)
                .animate().scale(duration: 500.ms, curve: Curves.elasticOut)
                .then().shimmer(duration: 1.seconds),
             Text(
               leftWins ? "HOME VICTORY!" : "AWAY VICTORY!", 
               style: const TextStyle(color: Colors.yellow, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2, shadows: [Shadow(color: Colors.black, blurRadius: 10)])
             ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.5, end: 0),
          ] else
            const Text("IT'S A DRAW!", style: TextStyle(color: Colors.orange, fontSize: 32, fontWeight: FontWeight.w900)),
        ],
      ),
    ).animate().fadeOut(delay: 5.seconds, duration: 1.seconds);
  }

  Widget _buildTeamSide(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String hostUid,
    required List<Participant> teamMembers,
    required Color themeColor,
    required bool isLeft,
  }) {
    final hostProfile = ref.watch(userProfileProvider(hostUid));

    return Column(
      children: [
        const Gap(12),
        Text(
          title,
          style: TextStyle(
            color: themeColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const Gap(16),
        
        // Host Avatar
        hostProfile.when(
          data: (user) {
            final userData = user as UserModel?;
            return GestureDetector(
              onTap: () {
                final myUid = ref.read(authStateProvider).value?.uid;
                if (userData?.uid == myUid) {
                  _showSelfActions(context, ref, isHost: true);
                }
              },
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: themeColor.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)],
                        ),
                      ),
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: themeColor.withOpacity(0.2),
                        backgroundImage: (userData != null && userData.profilePhotoUrl.isNotEmpty) 
                          ? CachedNetworkImageProvider(userData.profilePhotoUrl)
                          : null,
                        child: userData == null ? const Icon(Icons.person, color: Colors.white24) : null,
                      ),
                      // Winner Overlay
                      if (room.pkEndTime != null && room.pkEndTime!.isBefore(DateTime.now()))
                        ...[
                          // Check if this side won
                          if (() {
                            final scores = room.pkScores ?? {};
                            int leftT = 0, rightT = 0;
                            room.pkTeams?.forEach((uid, side) {
                              if (side == 'left') leftT += (scores[uid] ?? 0);
                              if (side == 'right') rightT += (scores[uid] ?? 0);
                            });
                            return isLeft ? leftT > rightT : rightT > leftT;
                          }()) 
                            Positioned(
                              top: -15,
                              child: Column(
                                children: [
                                  const Icon(Icons.workspace_premium_rounded, color: Colors.yellow, size: 28)
                                      .animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds).scale(begin: const Offset(1,1), end: const Offset(1.2, 1.2)),
                                  const Text("WINNER", style: TextStyle(color: Colors.yellow, fontSize: 8, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                        ]
                      else
                        Positioned(
                          top: -12,
                          child: Icon(Icons.workspace_premium_rounded, color: isLeft ? Colors.yellowAccent : Colors.white70, size: 24)
                              .animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
                        ),
                    ],
                  ),
                  const Gap(8),
                  Text(
                    userData?.displayName ?? "Loading...",
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          },
          loading: () => const CircleAvatar(radius: 28, child: CircularProgressIndicator()),
          error: (_, __) => const CircleAvatar(radius: 28, child: Icon(Icons.error)),
        ),
        
        const Gap(20),
        
        // 3x3 Grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: 9,
              itemBuilder: (context, index) {
                if (index == 0) return _buildHostPlaceholder(themeColor);
                
                // For indices 1-8 (Seats 2-9)
                final memberIndex = index - 1;
                if (memberIndex < teamMembers.length) {
                  return _buildMemberSeat(teamMembers[memberIndex], themeColor, ref, context);
                }
                
                return _buildEmptySeat(context, ref, themeColor, isLeft);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHostPlaceholder(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Center(
        child: Text("HOST", style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMemberSeat(Participant p, Color color, WidgetRef ref, BuildContext context) {
    return GestureDetector(
      onTap: () {
        final myUid = ref.read(authStateProvider).value?.uid;
        if (p.uid == myUid) {
          _showSelfActions(context, ref, isHost: false);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: ClipOval(
          child: p.profilePhotoUrl.isNotEmpty 
            ? CachedNetworkImage(imageUrl: p.profilePhotoUrl, fit: BoxFit.cover)
            : const Icon(Icons.person, color: Colors.white38, size: 16),
        ),
      ).animate().scale(),
    );
  }

  Widget _buildEmptySeat(BuildContext context, WidgetRef ref, Color color, bool isLeft) {
    final myUid = ref.read(authStateProvider).value?.uid;
    final isChallenger = room.pkScores?.containsKey(myUid) ?? false;

    return GestureDetector(
      onTap: () {
        if (isChallenger) {
          _handleInviteToTeam(context, ref, isLeft ? 'left' : 'right');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Only the PK challengers can invite users to the team.")),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: isChallenger 
          ? Icon(Icons.add, color: color, size: 16)
          : Icon(Icons.lock_outline, color: Colors.white10, size: 14),
      ),
    );
  }

  void _handleInviteToTeam(BuildContext context, WidgetRef ref, String side) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ViewersListSheet(
        roomId: room.roomId,
        participants: participants,
        onUserSelected: (p) async {
          try {
            await ref.read(roomServiceProvider).inviteToPKTeam(
              roomId: room.roomId,
              targetUid: p.uid,
              side: side,
            );
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
            }
          }
        },
      ),
    );
  }

  void _showSelfActions(BuildContext context, WidgetRef ref, {required bool isHost}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Gap(12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const Gap(20),
          if (isHost && room.ownerUid == ref.read(authStateProvider).value?.uid)
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
              title: const Text("End PK Battle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await ref.read(roomServiceProvider).endPKBattle(room.roomId);
                } catch (e) {
                  debugPrint("Error ending PK: $e");
                }
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.orangeAccent),
              title: const Text("Leave PK Team", style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await ref.read(roomServiceProvider).leavePKTeam(room.roomId);
                } catch (e) {
                  debugPrint("Error leaving PK team: $e");
                }
              },
            ),
          const Gap(20),
        ],
      ),
    );
  }

  void _handleJoinTeam(BuildContext context, WidgetRef ref, String side) async {
    final myUid = ref.read(authStateProvider).value?.uid;
    if (myUid == null) return;

    // Show confirmation
    final res = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Join Team", style: TextStyle(color: Colors.white)),
        content: Text("Do you want to join the ${side == 'left' ? 'Home' : 'Away'} team?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
            child: const Text("JOIN"),
          ),
        ],
      ),
    );

    if (res == true) {
      try {
        await ref.read(roomServiceProvider).joinPKTeam(
          roomId: room.roomId,
          side: side,
        );
      } catch (e) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }
}
