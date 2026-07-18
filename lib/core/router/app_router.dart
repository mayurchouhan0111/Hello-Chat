import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/rooms/presentation/screens/search_screen.dart' as room_search;
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/email_auth_screen.dart';
import '../../features/profile/presentation/screens/profile_setup_screen.dart';
import '../../features/profile/presentation/screens/reset_password_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_detail_screen.dart';
import '../../features/profile/presentation/screens/level_detail_screen.dart';
import '../../features/profile/presentation/screens/follow_list_screen.dart';
import '../../features/diamonds/presentation/screens/wallet_screen.dart';
import '../../features/vip/presentation/screens/vip_shop_screen.dart';
import '../../features/profile/presentation/screens/salary_history_screen.dart';
import '../../features/profile/presentation/screens/prestige_store_screen.dart';
import '../../features/profile/presentation/screens/noble_hall_screen.dart';
import '../../features/profile/presentation/screens/vip_center_screen.dart';
import '../../features/profile/presentation/screens/prestige_vault_screen.dart';
import '../../features/profile/presentation/screens/agency/agency_portal_screen.dart';
import '../../features/profile/presentation/screens/agency/svip_privileges_screen.dart';
import '../../features/profile/presentation/screens/invite_get_coins_screen.dart';
import '../../features/profile/presentation/screens/love_house_screen.dart';
import '../../features/profile/presentation/screens/cp_level_screen.dart';
import '../../features/profile/presentation/screens/friend_list_screen.dart';
import '../../features/profile/presentation/screens/friend_requests_screen.dart';
import '../../features/profile/presentation/screens/friendship_portal_screen.dart';
import '../../features/profile/presentation/screens/relationship_ranking_screen.dart';
import '../../features/profile/presentation/screens/prop_warehouse_screen.dart';
import '../../features/profile/presentation/screens/family/family_portal_screen.dart';
import '../../features/profile/presentation/screens/family/create_family_screen.dart';
import '../../features/profile/presentation/screens/family/family_list_screen.dart';
import '../../features/profile/presentation/screens/family/join_requests_screen.dart';
import '../../features/profile/presentation/screens/family/family_battle_screen.dart';
import '../../features/profile/presentation/screens/family/family_members_screen.dart';
import '../../features/profile/presentation/screens/family/family_detail_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/chats/presentation/screens/private_chat_screen.dart';
import '../../features/reseller/presentation/screens/reseller_dashboard_screen.dart';

import '../../features/rooms/presentation/screens/home_screen.dart';
import '../../features/moments/presentation/screens/add_moment_screen.dart';
import '../../features/leaderboards/presentation/screens/celebrity_ranking_screen.dart';
import '../../features/leaderboards/presentation/screens/contribution_ranking_screen.dart';
import '../../features/leaderboards/presentation/screens/leaderboard_screen.dart';
import '../../features/moments/presentation/screens/moment_detail_screen.dart';
import '../../features/games/presentation/screens/spin_wheel_screen.dart';
import '../../features/rooms/presentation/screens/create_room_screen.dart';
import '../../features/rooms/presentation/screens/live_room_screen.dart';
import '../../features/rooms/presentation/screens/active_pk_battle_screen.dart';
import '../providers/auth_provider.dart';

import '../../features/wallet/presentation/screens/withdrawal_history_screen.dart';
import '../../features/wallet/presentation/screens/withdraw_beans_screen.dart';
import '../../features/profile/presentation/screens/verification_screen.dart';
import '../../features/rooms/presentation/screens/room_support_screen.dart';
import '../../features/inbox/presentation/screens/inbox_screen.dart';
import '../../features/vip/presentation/screens/vip_rewards_screen.dart';
import '../../features/recharge_event/presentation/screens/recharge_event_detail_screen.dart';
import '../../features/events/presentation/screens/dynamic_event_screen.dart';

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
  static const nobleHall       = '/noble-hall';
  static const vipCenter       = '/vip-center';
  static const prestigeVault   = '/prestige-vault';
  static const luckySpin       = '/lucky-spin';
  static const agencyPortal     = '/agency-portal';
  static const search          = '/search';
  static const svipPrivileges   = '/svip-privileges';
  static const invite          = '/invite-get-coins';
  static const loveHouse       = '/love-house';
  static const cpLevel         = '/cp-level';
  static const propWarehouse   = '/prop-warehouse';
  static const familyPortal     = '/family-portal';
  static const createFamily     = '/create-family';
  static const familyList       = '/family-list';
  static const joinRequests     = '/join-requests';
  static const familyBattle     = '/family-battle';
  static const familyMembers    = '/family-members';
  static const familyDetail     = '/family-detail';
  static const settings         = '/settings';
  static const chatDetail       = '/chat-detail';
  static const pkBattle         = '/pk-battle';
  static const resellerCenter   = '/reseller-center';
  static const levelDetail      = '/level-detail';
  static const verification     = '/verification';
  static const withdrawalHistory = '/withdrawal-history';
  static const withdrawBeans     = '/withdraw-beans';
  static const roomSupport       = '/room-support';
  static const inbox             = '/inbox';
  static const vipRewards        = '/vip-rewards';
  static const rechargeEventDetail = '/recharge-event-detail';
  static const dynamicEvent        = '/event';
  static const friendList         = '/friend-list';
  static const friendRequests     = '/friend-requests';
  static const friendshipPortal   = '/friendship-portal';
  static const relationshipRanking = '/relationship-ranking';
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Use a listenable to refresh the router on auth state changes
  final authStream = ref.watch(authServiceProvider).user;
  User? _lastKnownUser;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: GoRouterRefreshStream(authStream),
    redirect: (context, state) async {
      // Get the current user directly from the service
      final user = ref.read(authServiceProvider).currentUser;
      
      final authRoutes = [
        AppRoutes.login,
        AppRoutes.otpVerify,
        AppRoutes.emailAuth,
        AppRoutes.forgotPassword,
        AppRoutes.resetPassword,
        AppRoutes.splash,
      ];
      final isAuthRoute = authRoutes.contains(state.matchedLocation);

      if (user == null) {
        // 🔒 Unauthenticated: only allow auth routes
        // Guard against transient null — if user was previously authenticated,
        // Firebase Auth may be still restoring the session (e.g. after app resume).
        // Wait briefly and recheck before redirecting to login.
        if (_lastKnownUser != null && !isAuthRoute) {
          await Future.delayed(const Duration(seconds: 1));
          final recheckUser = ref.read(authServiceProvider).currentUser;
          if (recheckUser != null) {
            _lastKnownUser = recheckUser;
            return null;
          }
        }
        _lastKnownUser = null;
        return isAuthRoute ? null : AppRoutes.login;
      }

      _lastKnownUser = user;

      // 🏠 Authenticated: If on login/splash/profile setup, force Home
      if (isAuthRoute || state.matchedLocation == AppRoutes.profileSetup) {
        debugPrint('--- [ROUTER: User Authenticated, Force Redirect to Home] ---');
        return AppRoutes.home;
      }

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
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return FollowListScreen(
            type: extra['type'] as String? ?? 'Followers',
            targetUid: extra['targetUid'] as String?,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.wallet,
        builder: (context, state) => const WalletScreen(),
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
        name: AppRoutes.liveRoom,
        path: '/live-room/:roomId',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId'] ?? '';
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
      GoRoute(
        path: AppRoutes.nobleHall,
        builder: (context, state) => const NobleHallScreen(),
      ),
      GoRoute(
        path: AppRoutes.vipCenter,
        builder: (context, state) => const VIPCarouselScreen(),
      ),
      GoRoute(
        path: AppRoutes.prestigeVault,
        builder: (context, state) => const PrestigeVaultScreen(),
      ),
      GoRoute(
        path: AppRoutes.luckySpin,
        builder: (context, state) => const SpinWheelScreen(),
      ),
      GoRoute(
        path: AppRoutes.agencyPortal,
        builder: (context, state) => const AgencyPortalScreen(),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => const room_search.SearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.svipPrivileges,
        builder: (context, state) => const SVIPPrivilegesScreen(),
      ),
      GoRoute(
        path: AppRoutes.invite,
        builder: (context, state) => const InviteGetCoinsScreen(),
      ),
      GoRoute(
        path: AppRoutes.loveHouse,
        builder: (context, state) => const LoveHouseScreen(),
      ),
      GoRoute(
        path: AppRoutes.cpLevel,
        builder: (context, state) => const CPLevelScreen(),
      ),
      GoRoute(
        path: AppRoutes.propWarehouse,
        builder: (context, state) => const PropWarehouseScreen(),
      ),
      GoRoute(
        path: AppRoutes.familyPortal,
        builder: (context, state) => const FamilyPortalScreen(),
      ),
      GoRoute(
        path: AppRoutes.createFamily,
        builder: (context, state) => const CreateFamilyScreen(),
      ),
      GoRoute(
        path: AppRoutes.familyList,
        builder: (context, state) => const FamilyListScreen(),
      ),
      GoRoute(
        path: AppRoutes.joinRequests,
        builder: (context, state) {
          final familyId = state.extra as String;
          return JoinRequestsScreen(familyId: familyId);
        },
      ),
      GoRoute(
        path: AppRoutes.familyBattle,
        builder: (context, state) {
          final familyId = state.extra as String;
          return FamilyBattleScreen(myFamilyId: familyId);
        },
      ),
      GoRoute(
        path: AppRoutes.familyMembers,
        builder: (context, state) {
          final familyId = state.extra as String;
          return FamilyMembersScreen(familyId: familyId);
        },
      ),
      GoRoute(
        path: AppRoutes.familyDetail,
        builder: (context, state) {
          final familyId = state.extra as String;
          return FamilyDetailScreen(familyId: familyId);
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.chatDetail,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return PrivateChatScreen(
            chatId: extra['chatId'] as String, 
            otherUid: extra['otherUid'] as String,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.pkBattle,
        pageBuilder: (context, state) {
          final roomId = state.extra as String? ?? '';
          return MaterialPage(
            key: state.pageKey,
            child: ActivePKBattleScreen(roomId: roomId),
            maintainState: false,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.resellerCenter,
        builder: (context, state) => const ResellerDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.levelDetail,
        builder: (context, state) => const LevelDetailScreen(),
      ),
      GoRoute(
        path: AppRoutes.verification,
        builder: (context, state) => const VerificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.withdrawalHistory,
        builder: (context, state) => const WithdrawalHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.withdrawBeans,
        builder: (context, state) => const WithdrawBeansScreen(),
      ),
      GoRoute(
        path: AppRoutes.roomSupport,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return RoomSupportScreen(roomId: extra?['roomId'] as String?);
        },
      ),
      GoRoute(
        path: AppRoutes.inbox,
        builder: (context, state) => const InboxScreen(),
      ),
      GoRoute(
        path: AppRoutes.vipRewards,
        builder: (context, state) => const VIPRewardsScreen(),
      ),
      GoRoute(
        path: AppRoutes.rechargeEventDetail,
        builder: (context, state) => const RechargeEventDetailScreen(),
      ),
      GoRoute(
        path: '/event/:eventId',
        name: AppRoutes.dynamicEvent,
        builder: (context, state) {
          final eventId = state.pathParameters['eventId'] ?? '';
          return DynamicEventScreen(eventId: eventId);
        },
      ),
      GoRoute(
        path: AppRoutes.friendList,
        builder: (context, state) => const FriendListScreen(),
      ),
      GoRoute(
        path: AppRoutes.friendRequests,
        builder: (context, state) => const FriendRequestsScreen(),
      ),
      GoRoute(
        path: AppRoutes.friendshipPortal,
        builder: (context, state) => const FriendshipPortalScreen(),
      ),
      GoRoute(
        path: AppRoutes.relationshipRanking,
        builder: (context, state) => const RelationshipRankingScreen(),
      ),
    ],
  );
});
