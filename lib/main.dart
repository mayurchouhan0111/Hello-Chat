import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/constants/app_strings.dart';

import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Connect to Local Emulators if in Debug Mode
  if (kDebugMode) {
    try {
      // 10.0.2.2 for Android Emulator, localhost for others
      final String host = (defaultTargetPlatform == TargetPlatform.android) 
          ? "10.0.2.2" : "localhost";
      
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
      FirebaseAuth.instance.useAuthEmulator(host, 9099);
      
      print('--- Firebase Emulators Connected: $host ---');
    } catch (e) {
      print('Failed to connect to emulators: $e');
    }
  }

  // Initialize Notifications
  final notifications = NotificationService();
  await notifications.initialize();
  
  runApp(
    const ProviderScope(
      child: HelloChatApp(),
    ),
  );
}

class HelloChatApp extends ConsumerWidget {
  const HelloChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      routerConfig: router,
    );
  }
}
