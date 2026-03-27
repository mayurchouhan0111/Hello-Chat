import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/email_auth_screen.dart';
import '../../features/profile/presentation/screens/profile_setup_screen.dart';
import '../../features/profile/presentation/screens/reset_password_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_detail_screen.dart';
import '../../features/profile/presentation/screens/follow_list_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import '../../features/vip/presentation/screens/vip_shop_screen.dart';
import '../../features/profile/presentation/screens/salary_history_screen.dart';
import '../../features/profile/presentation/screens/prestige_store_screen.dart';

import '../../features/rooms/presentation/screens/home_screen.dart';
import '../../features/moments/presentation/screens/add_moment_screen.dart';
import '../../features/leaderboards/presentation/screens/leaderboard_screen.dart';
import '../../features/moments/presentation/screens/moment_detail_screen.dart';
import '../../features/rooms/presentation/screens/create_room_screen.dart';
import '../../features/rooms/presentation/screens/live_room_screen.dart';
import '../providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppRoutes {
  // Auth
  static const splash          = '/';
  static const login           = '/login';
  static const otpVerify       = '/otp-verify';
  static const forgotPassword  = '/forgot-password';
  static const profileSetup    = '/profile-setup';
  static const resetPassword   = '/reset-password';
  static const editProfile     = '/edit-profile';
  static const emailAuth       = '/email-auth';
  static const userProfile     = '/user-profile';
  static const followList      = '/follow-list';
  static const addMoment       = '/add-moment';

  // Main (with bottom nav)
  static const home            = '/home';
  static const wallet          = '/wallet';
  
  static const leaderboard     = '/leaderboard';
  static const momentDetail    = '/moment-detail';
  static const createRoom      = '/create-room';
  static const liveRoom        = '/live-room';
  static const vipShop         = '/vip-shop';
  static const salaryHistory   = '/salary-history';
  static const prestigeStore   = '/prestige-store';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) async {
      final user = authState.value;
      final isLoggingIn = state.matchedLocation == AppRoutes.login || 
                          state.matchedLocation == AppRoutes.otpVerify ||
                          state.matchedLocation == AppRoutes.emailAuth ||
                          state.matchedLocation == AppRoutes.forgotPassword ||
                          state.matchedLocation == AppRoutes.splash;

      if (user == null) {
        return isLoggingIn ? null : AppRoutes.login;
      }

      // If user is logged in, check if they have a profile (username set)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final hasProfile = userDoc.exists && (userDoc.data()?['username'] as String? ?? '').isNotEmpty;

      if (!hasProfile) {
        return state.matchedLocation == AppRoutes.profileSetup ? null : AppRoutes.profileSetup;
      }

      if (isLoggingIn) return AppRoutes.home;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.otpVerify,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return OtpScreen(
            verificationId: extra['verificationId'] ?? '',
            phone: extra['phone'] ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.leaderboard,
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.userProfile,
        builder: (context, state) {
          final userId = state.extra as String? ?? 'User';
          return ProfileDetailScreen(userId: userId);
        },
      ),
      GoRoute(
        path: AppRoutes.followList,
        builder: (context, state) {
          final type = state.extra as String? ?? 'Followers';
          return FollowListScreen(type: type);
        },
      ),
      GoRoute(
        path: AppRoutes.wallet,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: AppRoutes.leaderboard,
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.addMoment,
        builder: (context, state) => const AddMomentScreen(),
      ),
      GoRoute(
        path: AppRoutes.emailAuth,
        builder: (context, state) => const EmailAuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.momentDetail,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return MomentDetailScreen(
            ownerUid: extra['ownerUid'] ?? '',
            mediaId: extra['mediaId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.createRoom,
        builder: (context, state) => const CreateRoomScreen(),
      ),
      GoRoute(
        path: AppRoutes.liveRoom,
        builder: (context, state) {
          final roomId = state.extra as String? ?? '';
          return LiveRoomScreen(roomId: roomId);
        },
      ),
      GoRoute(
        path: AppRoutes.vipShop,
        builder: (context, state) => const VIPShopScreen(),
      ),
      GoRoute(
        path: AppRoutes.salaryHistory,
        builder: (context, state) => const SalaryHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.prestigeStore,
        builder: (context, state) => const PrestigeStoreScreen(),
      ),
    ],
  );
});
