import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/constants/app_strings.dart';

import 'core/services/notification_service.dart';
import 'core/services/config_service.dart';
import 'core/providers/profile_provider.dart';
import 'core/widgets/location_listener.dart';
import 'core/widgets/global_presence_observer.dart';
import 'core/widgets/floating_room_overlay.dart';
import 'core/widgets/global_notification_overlay.dart';
import 'core/widgets/global_rocket_launch_overlay.dart';
import 'core/widgets/global_engagement_banner.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  debugPrint('--- [APP START] ---');
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('--- [FIREBASE INITIALIZED] ---');

  // 🛡️ INITIALIZE APP CHECK
  // This resolves the [unauthenticated] error by proving the app's integrity.
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
  );
  debugPrint('--- [APP CHECK READY] ---');

  // 🛡️ FORCE DEBUG TOKEN LOGGING
  // This triggers a token fetch which forces the native SDK to print the Debug Token in Logcat.
  if (kDebugMode) {
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      debugPrint('🛡️ [AppCheck Diagnostic] Current Token: ${token?.substring(0, 10)}...');
      debugPrint('🛡️ [AppCheck Diagnostic] Check your Logcat (Native logs) for the "Debug Secret" to paste into Firebase Console.');
    } catch (e) {
      debugPrint('🛡️ [AppCheck Diagnostic] Error fetching token: $e');
    }
  }

  /*
  // Connect to Local Emulators (Used for development)
  if (kDebugMode) {
    _connectToEmulators();
  }
  */

  // Initialize Notifications
  NotificationService().initialize().then((_) {
    debugPrint('--- [NOTIFICATIONS READY] ---');
  }).catchError((e) {
    debugPrint('--- [NOTIFICATIONS ERROR: $e] ---');
  });
  
  runApp(
    const ProviderScope(
      child: HelloChatApp(),
    ),
  );
}

void _connectToEmulators() {
  try {
    // For Android Emulators use 10.0.2.2 to reach the PC host
    // For iOS emulators or real devices on same Wi-Fi, use your local PC IP
    final String host = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) 
        ? "10.0.2.2" 
        : "192.168.1.197"; 
    
    FirebaseFirestore.instance.settings = Settings(
      persistenceEnabled: false,
      host: '$host:8085',
      sslEnabled: false,
    );
    
    // Crucial: Use the same host/port for regional function instance
    FirebaseFunctions.instanceFor(region: 'us-central1').useFunctionsEmulator(host, 5001);
    FirebaseAuth.instance.useAuthEmulator(host, 9099);
    
    debugPrint('--- [EMULATORS: TRYING TO CONNECT TO $host] ---');
  } catch (e) {
    debugPrint('Error connecting to emulators: $e');
  }
}

class HelloChatApp extends ConsumerWidget {
  const HelloChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final configAsync = ref.watch(globalConfigProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);

    return LocationListener(
      child: GlobalPresenceObserver(
        child: MaterialApp.router(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          theme: appTheme,
          routerConfig: router,
          builder: (context, child) {
            return Stack(
              children: [
                if (child != null)
                  GlobalRocketLaunchOverlay(
                    child: GlobalNotificationOverlay(child: child),
                  ),
                
                // 🚀 Global Engagement Banner (Announcements)
                GlobalEngagementBanner(),

                // 💺 Room PIP Overlay
                const FloatingRoomOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMaintenanceScreen() {
    return Container(
      color: const Color(0xFF0F172A),
      width: double.infinity,
      height: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(0.1),
              ),
              child: const Icon(Icons.build_circle_rounded, color: Colors.orange, size: 80),
            ),
            const SizedBox(height: 40),
            const Text(
              "System Optimization",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Hello Chat is currently undergoing scheduled maintenance to improve your social experience. We will be back shortly!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 60),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: const Text("ESTIMATED RESUME: 2:00 PM", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ),
          ],
        ),
      ),
    );
  }

}
