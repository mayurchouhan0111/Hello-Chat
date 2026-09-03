import 'dart:ui' show PlatformDispatcher;
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
import 'core/services/asset_precache_service.dart';
import 'core/providers/profile_provider.dart';
import 'core/providers/room_provider.dart';
import 'core/widgets/location_listener.dart';
import 'core/widgets/global_presence_observer.dart';
import 'core/widgets/floating_room_overlay.dart';
import 'core/widgets/global_notification_overlay.dart';
import 'core/widgets/global_rocket_launch_overlay.dart';

import 'core/widgets/app_toast.dart';

import 'services/gift_service.dart';
import 'features/rooms/presentation/widgets/gift_animation_overlay.dart';
import 'core/utils/svga_parser_util.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🛡️ Catch Flutter framework UI build / layout errors
  FlutterError.onError = (FlutterErrorDetails details) {
    final exceptionStr = details.exception.toString();
    if (exceptionStr.contains('Invalid image data') || 
        exceptionStr.contains('HttpException: Invalid statusCode') ||
        exceptionStr.contains('ImageDecoder\$DecodeException') ||
        exceptionStr.contains('Failed to create image decoder')) {
      debugPrint('🛡️ [Handled Framework Error] (Non-fatal) ${details.exception}');
      return;
    }
    FlutterError.presentError(details);
    debugPrint('🛡️ [Flutter Framework Error] Exception: ${details.exception}');
    debugPrint('🛡️ [Flutter Framework Error Summary] ${details.summary}');
    debugPrint('🛡️ [Flutter Framework Error Context] ${details.context}');
    debugPrint('🛡️ [Flutter Framework Error Full] ${details.toString()}');
  };

  // 🛡️ Catch uncaught asynchronous exceptions (Futures, Streams, Isolate)
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    final errorStr = error.toString();
    if (errorStr.contains('Invalid image data') || 
        errorStr.contains('HttpException: Invalid statusCode') ||
        errorStr.contains('ImageDecoder\$DecodeException') ||
        errorStr.contains('Failed to create image decoder')) {
      debugPrint('🛡️ [Handled Async Error] (Non-fatal) $error');
      return true;
    }
    debugPrint('🛡️ [Uncaught Async Error] Error: $error');
    debugPrint('🛡️ [Uncaught Async Error] StackTrace: $stack');
    // Prevents app crash by telling the engine we have fully handled the error.
    return true; 
  };

  // 🛡️ Completely suppress the "Something Went Wrong" error card screen globally across all devices.
  // Instead of displaying a red error card or diagnostic sheet, log the error silently and return an imperceptible layout fallback.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('🛡️ [Widget Build Exception Suppressed] ${details.exception}');
    debugPrint('🛡️ [StackTrace] ${details.stack}');

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 200 || constraints.maxWidth < 200) {
          return const SizedBox.shrink();
        }
        return Material(
          color: const Color(0xFF0F172A),
          child: const SizedBox.shrink(),
        );
      },
    );
  };

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('⚠️ Firebase.initializeApp notice: $e');
  }
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

    ref.listen(currentUserProfileProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        final profile = next.value!;
        final vipNum = int.tryParse(profile.vipTier.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final role = profile.role;
        AssetPrecacheService.precacheUserAssets(context, vipLevel: vipNum, role: role);
        AssetPrecacheService.startBackgroundPrecache();
      }
    });

    if (profileAsync.hasValue && profileAsync.value != null) {
      _preloadGiftsOnStartup(ref);
    }

    return LocationListener(
      child: GlobalPresenceObserver(
        child: MaterialApp.router(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
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

bool _didPreloadGifts = false;

void _preloadGiftsOnStartup(WidgetRef ref) async {
  if (_didPreloadGifts) return;
  _didPreloadGifts = true;

  // Pre-initialize VoiceService (Agora RTC Engine) asynchronously in background
  // so that when user joins a live room, initialize() completes in 0ms!
  Future(() async {
    try {
      await ref.read(voiceServiceProvider).initialize();
    } catch (ve) {
      debugPrint("[AppPreload] Error background initializing VoiceService: $ve");
    }
  });

  try {
    final gifts = await ref.read(giftServiceProvider).getGiftsFuture();
    for (final gift in gifts) {
      final url = gift.lottieAssetPath.trim();
      if (url.isNotEmpty) {
        if (url.toLowerCase().contains('.svga')) {
          final localPath = SvgaParserUtil.getLocalGiftSvgaPath(url);
          if (localPath != null) {
            SvgaParserUtil.decodeSafeFromAssets(localPath);
          }
        } else {
          final localLottie = SvgaParserUtil.getLocalLottiePath(url);
          if (localLottie != null) {
            LottieCache.preloadLocal(localLottie);
          }
        }
      }
    }
  } catch (e) {
    debugPrint("[AppPreload] Error preloading local gift assets: $e");
  }
}
