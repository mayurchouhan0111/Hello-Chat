import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/participant_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/user_badge.dart';
import '../../../../core/utils/badge_utils.dart';
import '../../../../core/providers/profile_provider.dart';

class ViewersListSheet extends ConsumerStatefulWidget {
  final String roomId;
  final List<Participant> participants;
  final String ownerUid;
  final Function(Participant) onUserSelected;

  const ViewersListSheet({
    super.key,
    required this.roomId,
    required this.participants,
    required this.ownerUid,
    required this.onUserSelected,
  });

  @override
  ConsumerState<ViewersListSheet> createState() => _ViewersListSheetState();
}

class _ViewersListSheetState extends ConsumerState<ViewersListSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
    _initializeData();
  }

  void _initializeData() {
    Future.microtask(() {
      if (mounted) {
        if (widget.participants.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No viewers found';
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = null;
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(ViewersListSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participants != widget.participants) {
      _initializeData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[ViewersListSheet] $message');
    }
  }

  @override
  Widget build(BuildContext context) {
    final validParticipants = widget.participants.where((p) => p.uid.isNotEmpty).toList();
    final viewerCount = validParticipants.length;
    final vipCount = validParticipants.where((p) => p.vipTier != 'none' && p.vipTier.isNotEmpty).length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          _buildHeader(viewerCount),
          _buildTabs(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF8E54E9)))
              : TabBarView(
              controller: _tabController,
              children: [
                _buildViewerList('viewers', validParticipants),
                _buildViewerList('vip', validParticipants),
                _buildViewerList('guest_rank', validParticipants),
                _buildViewerList('contributors', validParticipants),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int viewerCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Text(
            "Viewers",
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "$viewerCount",
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, color: Colors.grey[600], size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              _buildTab('Viewers', 0),
              _buildTab('VIP', 1),
              _buildTab('Guest Rank', 2),
              _buildTab('Contributors', 3),
            ],
          ),
          Container(
            height: 1,
            color: Colors.grey[200],
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTabIndex = index);
          _tabController.animateTo(index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF8E54E9) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? const Color(0xFF8E54E9) : Colors.grey[500],
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewerList(String type, List<Participant> validParticipants) {
    List<Participant> typeParticipants;
    switch (type) {
      case 'vip':
        typeParticipants = validParticipants.where((p) => p.vipTier != 'none' && p.vipTier.isNotEmpty).toList();
        break;
      case 'guest_rank':
        typeParticipants = validParticipants.where((p) => p.seatIndex == -1 || p.uid == widget.ownerUid).toList()
          ..sort((a, b) => b.lastActive.compareTo(a.lastActive));
        break;
      case 'contributors':
        typeParticipants = List<Participant>.from(validParticipants)
          ..sort((a, b) => b.lastActive.compareTo(a.lastActive));
        break;
      default:
        typeParticipants = List<Participant>.from(validParticipants)
          ..sort((a, b) => b.lastActive.compareTo(a.lastActive));
    }

    if (typeParticipants.isEmpty) {
      return _buildEmptyState(type);
    }

    return Container(
      color: const Color(0xFFF5F5F5),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: typeParticipants.length,
        separatorBuilder: (_, __) => Container(
          height: 1,
          margin: const EdgeInsets.only(left: 60),
          color: Colors.grey[200],
        ),
        itemBuilder: (context, index) {
          return _ViewerListItem(
            participant: typeParticipants[index],
            isOwner: typeParticipants[index].uid == widget.ownerUid,
            onTap: () {
              Navigator.pop(context);
              widget.onUserSelected(typeParticipants[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    String message;
    IconData icon;

    switch (type) {
      case 'vip':
        message = "No VIP members";
        icon = Icons.workspace_premium_outlined;
        break;
      case 'guest_rank':
        message = "No guests";
        icon = Icons.person_outline;
        break;
      case 'contributors':
        message = "No contributors";
        icon = Icons.people_outline;
        break;
      default:
        message = "No viewers";
        icon = Icons.visibility_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.grey[400], size: 40),
          const Gap(8),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ViewerListItem extends ConsumerWidget {
  final Participant participant;
  final bool isOwner;
  final VoidCallback onTap;

  const _ViewerListItem({
    required this.participant,
    required this.isOwner,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserModel?> userAsync = ref.watch(userProfileProvider(participant.uid));
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    final isMe = currentUserUid == participant.uid;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _buildAvatar(),
              const Gap(8),
              Expanded(child: _buildUserInfo(userAsync)),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildAvatar() {
    return AppAvatar(
      imageUrl: participant.profilePhotoUrl.isEmpty 
        ? "https://picsum.photos/seed/${participant.uid}/100" 
        : participant.profilePhotoUrl,
      frameUrl: participant.profileFrame,
      vipTier: participant.vipTier,
      userLevel: participant.level,
      radius: 22,
      showFrame: true,
      frameMultiplier: 1.4,
      tags: participant.tags,
    );
  }

  Widget _buildUserInfo(AsyncValue<UserModel?> userAsync) {
    try {
      return userAsync.when(
        data: (user) {
          try {
            if (user == null) return _buildBasicInfo();
            return _buildRichInfo(user);
          } catch (e) {
            debugPrint("Error rendering rich info for participant: $e");
            return _buildBasicInfo();
          }
        },
        loading: () => _buildBasicInfo(),
        error: (err, stack) {
          debugPrint("Error loading profile for participant: $err");
          return _buildBasicInfo();
        },
      );
    } catch (e) {
      debugPrint("Error in _buildUserInfo: $e");
      return _buildBasicInfo();
    }
  }

  Widget _buildBasicInfo() {
    return Row(
      children: [
        Text(
          participant.displayName.isNotEmpty ? participant.displayName : "User",
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (isOwner) ...[
          const Gap(4),
          _buildTag("Host", const Color(0xFFFFD700), Colors.white),
        ],
      ],
    );
  }

  Widget _buildRichInfo(UserModel user) {
    try {
      final gender = participant.tags.contains('Male') ? 'M' :
                     participant.tags.contains('Female') ? 'F' : null;
      
      final badges = getBadgesForUser(user);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                user.displayName.isNotEmpty ? user.displayName : participant.displayName,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (isOwner)
                _buildTag("Host", const Color(0xFFFFD700), Colors.white),
              if (participant.role == 'admin')
                _buildTag("Admin", Colors.purple, Colors.white),
              if (gender != null)
                _buildGenderBadge(gender),
            ],
          ),
          if (badges.isNotEmpty) ...[
            const Gap(6),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: badges.length > 4 ? 4 : badges.length,
                separatorBuilder: (_, __) => const Gap(4),
                itemBuilder: (context, index) {
                  final badge = badges[index];
                  if (badge is UserBadge) {
                    return Transform.scale(
                      scale: 0.75,
                      alignment: Alignment.centerLeft,
                      child: UserBadge(
                        label: badge.label,
                        type: badge.type,
                        prefix: badge.prefix,
                        icon: badge.icon,
                        imageAsset: badge.imageAsset,
                        customFrameAsset: badge.customFrameAsset,
                        margin: EdgeInsets.zero,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ],
      );
    } catch (e) {
      debugPrint("Exception inside _buildRichInfo: $e");
      return _buildBasicInfo();
    }
  }

  Widget _buildGenderBadge(String gender) {
    final isMale = gender == 'M';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: isMale ? Colors.blue : Colors.pink,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        gender,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLevelBadge(int level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        "Lv.$level",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildVipBadge(String tier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.diamond, color: Colors.white, size: 10),
          const Gap(2),
          Text(
            tier.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSvipBadge(int level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Colors.white, size: 10),
          const Gap(2),
          Text(
            "SVIP$level",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTag(String tag) {
    Color bgColor;
    switch (tag.toLowerCase()) {
      case 'admin':
        bgColor = Colors.purple;
        break;
      case 'superadmin':
        bgColor = Colors.red;
        break;
      case 'moderator':
        bgColor = Colors.blue;
        break;
      case 'verified':
        bgColor = Colors.green;
        break;
      case 'partner':
        bgColor = Colors.cyan;
        break;
      default:
        bgColor = Colors.grey;
    }
    return _buildTag(tag, bgColor, Colors.white);
  }

  Widget _buildTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}