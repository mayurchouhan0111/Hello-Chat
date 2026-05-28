import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../features/rooms/presentation/widgets/rocket_completion_vap_overlay.dart';

class GlobalRocketLaunchOverlay extends StatefulWidget {
  final Widget child;

  const GlobalRocketLaunchOverlay({super.key, required this.child});

  @override
  State<GlobalRocketLaunchOverlay> createState() => _GlobalRocketLaunchOverlayState();
}

class _GlobalRocketLaunchOverlayState extends State<GlobalRocketLaunchOverlay> {
  StreamSubscription? _subscription;
  int? _launchingLevel;
  bool _isVisible = false;
  DateTime? _lastLaunchTime;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    debugPrint("🚀 [ROCKET] Starting Global Listener...");
    
    // Listen to all changes in global_messages and filter locally
    // This avoids the need for complex Firestore composite indexes
    _subscription = FirebaseFirestore.instance
        .collection('global_messages')
        .snapshots()
        .listen((snapshot) {
      
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          
          if (data['type'] == 'rocket_launch') {
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            final level = data['level'] as int?;
            
            debugPrint("🚀 [ROCKET] New Rocket Message Detected: Level=$level, createdAt=$createdAt");

            if (createdAt != null && level != null) {
              final now = DateTime.now();
              final diff = now.difference(createdAt).inSeconds.abs();
              
              // Only trigger if it's a FRESH message (within last 60 seconds)
              if (diff < 60 && createdAt != _lastLaunchTime) {
                debugPrint("🚀 [ROCKET] Triggering Animation Sequence! (Diff: ${diff}s)");
                _lastLaunchTime = createdAt;
                _triggerAnimation(level);
              } else {
                debugPrint("🚀 [ROCKET] Message ignored: diff=${diff}s, isDuplicate=${createdAt == _lastLaunchTime}");
              }
            }
          }
        }
      }
    }, onError: (e) {
      debugPrint("❌ [ROCKET] Firestore Listener Error: $e");
    });
  }

  void _triggerAnimation(int level) {
    if (_isVisible) return;
    setState(() {
      _launchingLevel = level;
      _isVisible = true;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isVisible && _launchingLevel != null)
          RocketCompletionVapOverlay(
            level: _launchingLevel!,
            onComplete: () {
              if (mounted) {
                setState(() => _isVisible = false);
              }
            },
          ),
      ],
    );
  }
}
