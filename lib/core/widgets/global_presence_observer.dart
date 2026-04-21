import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/room_service.dart';

class GlobalPresenceObserver extends ConsumerStatefulWidget {
  final Widget child;
  const GlobalPresenceObserver({super.key, required this.child});

  @override
  ConsumerState<GlobalPresenceObserver> createState() => _GlobalPresenceObserverState();
}

class _GlobalPresenceObserverState extends ConsumerState<GlobalPresenceObserver> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupRealtimePresence();
  }

  void _setupRealtimePresence() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final database = FirebaseDatabase.instance;
    final presenceRef = database.ref("status/$uid");
    final connectedRef = database.ref(".info/connected");

    connectedRef.onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (connected) {
        // 1. Set online in RTDB (Backend Function will sync this to Firestore)
        presenceRef.set({
          'state': 'online',
          'last_changed': ServerValue.timestamp,
        });

        // 2. Queue offline in RTDB for when we disconnect (App Kill/Crash/Background)
        // Note: RTDB handles this on the SERVER side.
        presenceRef.onDisconnect().set({
          'state': 'offline',
          'last_changed': ServerValue.timestamp,
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the app is moved to background, we could explicitly set offline
    // but RTDB connection often stays alive for a bit.
    // For "Real-time" accuracy, we trust the connection status.
    if (state == AppLifecycleState.resumed) {
      // Ensure we are online
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        FirebaseDatabase.instance.ref("status/$uid").set({
          'state': 'online',
          'last_changed': ServerValue.timestamp,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
