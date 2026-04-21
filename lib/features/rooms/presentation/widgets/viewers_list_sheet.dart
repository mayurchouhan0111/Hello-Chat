import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/participant_model.dart';
import '../../../../core/widgets/app_avatar.dart';
import 'package:gap/gap.dart';

class ViewersListSheet extends ConsumerWidget {
  final String roomId;
  final List<Participant> participants;
  final Function(Participant) onUserSelected;

  const ViewersListSheet({
    super.key,
    required this.roomId,
    required this.participants,
    required this.onUserSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewers = participants.where((p) => p.seatIndex == -1).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const Gap(12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
          const Gap(16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Viewers (${viewers.length})", style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.black54)),
              ],
            ),
          ),
          const Divider(color: Colors.black12, height: 1),
          Expanded(
            child: viewers.isEmpty 
              ? const Center(child: Text("No viewers in the room yet.", style: TextStyle(color: Colors.black38)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: viewers.length,
                    itemBuilder: (context, index) {
                      final p = viewers[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            onUserSelected(p);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Row(
                            children: [
                              AppAvatar(
                                imageUrl: p.profilePhotoUrl.isEmpty ? "https://picsum.photos/seed/${p.uid}/100" : p.profilePhotoUrl,
                                radius: 22,
                                vipTier: p.vipTier,
                                frameUrl: p.profileFrame,
                                showFrame: true,
                                frameMultiplier: 1.2,
                              ),
                              const Gap(12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      p.displayName.isNotEmpty ? p.displayName : "User", 
                                      style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      "ID: ${p.uid}", 
                                      style: TextStyle(color: Colors.black38, fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Gap(8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: const Text(
                                  "Profile",
                                  style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
