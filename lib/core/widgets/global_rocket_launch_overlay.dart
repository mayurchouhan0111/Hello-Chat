import 'dart:async';
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/profile_provider.dart';
import '../utils/room_navigation_helper.dart';
import 'global_rocket_banner.dart';

class GlobalRocketLaunchOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const GlobalRocketLaunchOverlay({super.key, required this.child});

  @override
  ConsumerState<GlobalRocketLaunchOverlay> createState() => _GlobalRocketLaunchOverlayState();
}

class _GlobalRocketLaunchOverlayState extends ConsumerState<GlobalRocketLaunchOverlay> {
  StreamSubscription<QueryDocumentSnapshot<Map<String, dynamic>>?>? _subscription;
  final Queue<Map<String, dynamic>> _rocketQueue = Queue<Map<String, dynamic>>();
  Map<String, dynamic>? _activeRocket;
  Timer? _bannerTimer;
  String? _lastSeenDocId;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    debugPrint("🚀 [ROCKET] Starting optimized Global Listener...");
    
    _subscription = FirebaseFirestore.instance
        .collection('global_messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first : null)
        .listen((doc) {
      if (doc == null || !doc.exists) return;

      final docId = doc.id;
      if (docId == _lastSeenDocId) {
        debugPrint("🚀 [ROCKET] Skipping duplicate doc: $docId");
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      
      if (data['type'] == 'rocket_launch') {
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final level = data['level'] as int?;
        final roomId = data['roomId'] as String?;
        
        debugPrint("🚀 [ROCKET] New Rocket Message Detected: Level=$level, roomId=$roomId, createdAt=$createdAt");

        if (createdAt != null && level != null && roomId != null) {
          final now = DateTime.now();
          final diff = now.difference(createdAt).inSeconds.abs();
          
          // Only trigger if it's a FRESH message (within last 60 seconds)
          if (diff < 60) {
            debugPrint("🚀 [ROCKET] Queuing new rocket banner event!");
            _lastSeenDocId = docId;
            _queueEvent(data);
          } else {
            debugPrint("🚀 [ROCKET] Message ignored: diff=${diff}s");
          }
        }
      }
    }, onError: (e) {
      debugPrint("❌ [ROCKET] Firestore Listener Error: $e");
    });
  }

  void _queueEvent(Map<String, dynamic> data) {
    _rocketQueue.add(data);
    _processQueue();
  }

  void _processQueue() {
    if (_activeRocket != null) {
      // Already showing a banner
      return;
    }
    if (_rocketQueue.isEmpty) {
      return;
    }

    final nextEvent = _rocketQueue.removeFirst();
    final roomId = nextEvent['roomId'] as String?;

    if (roomId == null) {
      _processQueue();
      return;
    }

    // Check if the user is already in this room.
    // If they are, skip showing the global notification banner for this rocket.
    final currentUserProfile = ref.read(currentUserProfileProvider).value;
    if (currentUserProfile?.activeRoomId == roomId) {
      debugPrint("🚀 [ROCKET] User is already in room $roomId. Skipping banner.");
      _processQueue();
      return;
    }

    setState(() {
      _activeRocket = nextEvent;
    });

    // Start 10 seconds timer
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _activeRocket = null;
        });
        _processQueue();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_activeRocket != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 0,
            right: 0,
            child: _GlobalRocketBannerWrapper(
              event: _activeRocket!,
              onTap: () {
                final roomId = _activeRocket!['roomId'] as String;
                debugPrint("🚀 [ROCKET] Banner clicked, joining room: $roomId");
                RoomNavigationHelper.joinRoom(context, ref, roomId);
                
                // Dismiss the current banner and process the next
                _bannerTimer?.cancel();
                setState(() {
                  _activeRocket = null;
                });
                _processQueue();
              },
            ),
          ),
      ],
    );
  }
}

class _GlobalRocketBannerWrapper extends ConsumerWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;

  const _GlobalRocketBannerWrapper({
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomId = event['roomId'] as String? ?? '';
    final roomName = event['roomName'] as String? ?? 'Live Room';
    final level = event['level'] as int? ?? 1;
    final kingUid = event['kingUid'] as String? ?? '';

    // Watch profile for the user who triggered the rocket
    final userAsync = ref.watch(cachedUserProfileProvider(kingUid));

    final userName = userAsync.when(
      data: (user) => user?.displayName.isNotEmpty == true
          ? user!.displayName
          : (user?.username ?? 'Someone'),
      loading: () => 'Someone',
      error: (_, __) => 'Someone',
    );

    final userId = userAsync.when(
      data: (user) => user?.displayId ?? user?.username ?? kingUid,
      loading: () => '...',
      error: (_, __) => kingUid,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GlobalRocketBanner(
        userName: userName,
        userId: userId,
        roomName: roomName,
        roomId: roomId,
        level: level,
      ),
    );
  }
}
