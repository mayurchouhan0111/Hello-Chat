import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GlobalPresenceObserver extends ConsumerStatefulWidget {
  final Widget child;
  const GlobalPresenceObserver({super.key, required this.child});

  @override
  ConsumerState<GlobalPresenceObserver> createState() => _GlobalPresenceObserverState();
}

class _GlobalPresenceObserverState extends ConsumerState<GlobalPresenceObserver> with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DatabaseEvent>? _connectedSubscription;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenToAuthAndPresence();
  }

  void _listenToAuthAndPresence() {
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _setupUserPresence(user.uid);
      } else {
        _connectedSubscription?.cancel();
        _heartbeatTimer?.cancel();
      }
    });
  }

  void _setupUserPresence(String uid) {
    _connectedSubscription?.cancel();

    final database = FirebaseDatabase.instance;
    final presenceRef = database.ref("status/$uid");
    final connectedRef = database.ref(".info/connected");

    _connectedSubscription = connectedRef.onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (connected) {
        // 1. Set online status in Realtime Database
        presenceRef.set({
          'state': 'online',
          'last_changed': ServerValue.timestamp,
        });

        // 2. Queue offline status on disconnect (Server-side)
        presenceRef.onDisconnect().set({
          'state': 'offline',
          'last_changed': ServerValue.timestamp,
        });

        // 3. Directly mark online in Firestore user document
        _updateFirestoreOnlineStatus(uid, true);
      }
    });

    // Periodic heartbeat to keep Firestore lastActive timestamp fresh while app is open
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (FirebaseAuth.instance.currentUser?.uid == uid) {
        _updateFirestoreOnlineStatus(uid, true);
      }
    });
  }

  Future<void> _updateFirestoreOnlineStatus(String uid, bool isOnline) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'isOnline': isOnline,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("⚠️ PresenceObserver Firestore update error: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _connectedSubscription?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (state == AppLifecycleState.resumed) {
      FirebaseDatabase.instance.ref("status/$uid").set({
        'state': 'online',
        'last_changed': ServerValue.timestamp,
      });
      _updateFirestoreOnlineStatus(uid, true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      FirebaseDatabase.instance.ref("status/$uid").set({
        'state': 'offline',
        'last_changed': ServerValue.timestamp,
      });
      _updateFirestoreOnlineStatus(uid, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
