import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/providers/recharge_event_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/router/app_router.dart';

class RechargeEventDetailScreen extends ConsumerStatefulWidget {
  const RechargeEventDetailScreen({super.key});

  @override
  ConsumerState<RechargeEventDetailScreen> createState() => _RechargeEventDetailScreenState();
}

class _RechargeEventDetailScreenState extends ConsumerState<RechargeEventDetailScreen> {
  late final WebViewController _controller;
  bool _isInitialized = false;
  bool _pageLoaded = false;
  
  // Local cache states to detect changes
  int _lastRecharge = -1;
  List<Map<String, dynamic>> _lastPackages = [];
  List<dynamic> _lastClaimedMilestones = [];
  String _lastTitle = '';
  String _lastDescription = '';
  String _lastEndDateStr = '';
  
  // Track actual injected values to prevent redundant loops & OOM crashes
  int _lastInjectedRecharge = -1;
  String _lastInjectedPackagesJson = '';
  String _lastInjectedClaimedJson = '';
  String _lastInjectedTitle = '';
  String _lastInjectedDescription = '';
  String _lastInjectedEndDateStr = '';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    _controller.setBackgroundColor(Colors.transparent);

    _controller.setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (nav) {
        return NavigationDecision.navigate;
      },
      onPageFinished: (url) {
        setState(() => _pageLoaded = true);
        _injectData();
      },
    ));

    // Register Javascript Bridge for WebView-to-Flutter communication
    _controller.addJavaScriptChannel(
      'FlutterApp',
      onMessageReceived: (JavaScriptMessage message) {
        if (message.message == 'back') {
          Navigator.pop(context);
        } else if (message.message == 'recharge') {
          context.push(AppRoutes.wallet);
        } else if (message.message.startsWith('claim:')) {
          final parts = message.message.split(':');
          final thresholdStr = parts.length > 1 ? parts[1] : '';
          final reward = parts.length > 2 ? parts[2] : 'Milestone Reward';
          _handleClaimReward(context, thresholdStr, reward);
        }
      },
    );
  }

  void _handleClaimReward(BuildContext context, String thresholdStr, String reward) async {
    final uid = ref.read(currentUserProfileProvider).value?.uid;
    if (uid == null) return;
    
    final threshold = int.tryParse(thresholdStr) ?? 0;
    
    // Parse Coin Amount from reward string if present (e.g., "10M Coins" -> 10,000,000, "30M Coins" -> 30,000,000)
    int coinsToCredit = 0;
    final rewardLower = reward.toLowerCase();
    if (rewardLower.contains('m coins') || rewardLower.contains('m coin')) {
      final reg = RegExp(r'(\d+)\s*m');
      final match = reg.firstMatch(rewardLower);
      if (match != null) {
        final mVal = int.tryParse(match.group(1) ?? '0') ?? 0;
        coinsToCredit = mVal * 1000000;
      }
    } else if (rewardLower.contains('k coins') || rewardLower.contains('k coin')) {
      final reg = RegExp(r'(\d+)\s*k');
      final match = reg.firstMatch(rewardLower);
      if (match != null) {
        final kVal = int.tryParse(match.group(1) ?? '0') ?? 0;
        coinsToCredit = kVal * 1000;
      }
    }

    // 1. Update user profile (claimedMilestones + diamondBalance)
    final Map<String, dynamic> userUpdates = {
      'claimedMilestones': FieldValue.arrayUnion([threshold, thresholdStr]),
    };
    if (coinsToCredit > 0) {
      userUpdates['diamondBalance'] = FieldValue.increment(coinsToCredit);
    }
    await FirebaseFirestore.instance.collection('users').doc(uid).set(userUpdates, SetOptions(merge: true));

    // 2. Add claimed gift/item to User Gifts / Claimed Rewards history
    await FirebaseFirestore.instance.collection('users').doc(uid).collection('claimed_rewards').add({
      'rewardName': reward,
      'threshold': threshold,
      'claimedAt': FieldValue.serverTimestamp(),
      'coinsCredited': coinsToCredit,
    });

    // 3. If reward includes a prop/mount/effect item, add it to User Vault (My Decoration)
    if (rewardLower.contains('effect') || rewardLower.contains('mount') || rewardLower.contains('frame')) {
      final category = rewardLower.contains('mount') ? 'mount' : 'frame';
      final expiry = rewardLower.contains('15 days') ? '15 Days' : (rewardLower.contains('30 days') ? '30 Days' : 'Permanent');
      
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('vault').add({
        'name': reward,
        'category': category,
        'type': 'Event Milestone Reward',
        'imageUrl': 'assets/images/super/super-admin.svga',
        'isEquipped': false,
        'acquiredAt': FieldValue.serverTimestamp(),
        'expiryDate': expiry,
      });
    }

    if (context.mounted) {
      String msg = "🎉 CLAIMED: $reward!";
      if (coinsToCredit > 0) {
        msg += " (+${coinsToCredit.toString()} Coins added to Wallet)";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1B5E20),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _injectData() {
    if (!_pageLoaded) return;

    // 1. Inject user progress and claimed milestone list
    final claimedJson = jsonEncode(_lastClaimedMilestones);
    if (_lastRecharge != _lastInjectedRecharge || claimedJson != _lastInjectedClaimedJson) {
      _lastInjectedRecharge = _lastRecharge;
      _lastInjectedClaimedJson = claimedJson;
      _controller.runJavaScript("if (window.setUserData) window.setUserData({ recharge: $_lastRecharge, claimedMilestones: $claimedJson });");
    }

    // 2. Only inject packages list if JSON representation is different to avoid infinite OOM loops
    final pkgsJson = jsonEncode(_lastPackages);
    if (pkgsJson != _lastInjectedPackagesJson) {
      _lastInjectedPackagesJson = pkgsJson;
      _controller.runJavaScript("if (window.setEventPackages) window.setEventPackages($pkgsJson);");
    }

    // 3. Inject event meta data dynamically (Title, Description, EndDate) from active Firestore document
    if (_lastTitle != _lastInjectedTitle || 
        _lastDescription != _lastInjectedDescription || 
        _lastEndDateStr != _lastInjectedEndDateStr) {
      _lastInjectedTitle = _lastTitle;
      _lastInjectedDescription = _lastDescription;
      _lastInjectedEndDateStr = _lastEndDateStr;
      
      final metaData = {
        'title': _lastTitle,
        'description': _lastDescription,
        'endDate': _lastEndDateStr
      };
      final metaJson = jsonEncode(metaData);
      _controller.runJavaScript("if (window.setEventMetaData) window.setEventMetaData($metaJson);");
    }
  }

  void _loadUrl(String eventId, String? customWebUrl, int userRecharge) {
    if (_isInitialized) return;
    _isInitialized = true;

    String finalUrl = '';
    if (customWebUrl != null && customWebUrl.isNotEmpty) {
      final uri = Uri.parse(customWebUrl);
      final queryParams = Map<String, String>.from(uri.queryParameters);
      queryParams['eventId'] = eventId;
      queryParams['recharge'] = userRecharge.toString(); // Hook user progress dynamics
      finalUrl = uri.replace(queryParameters: queryParams).toString();
    } else {
      // Local development fallback to Vite dev server port 5173
      String baseUrl = 'http://localhost:5173/premium_event/';
      if (!kIsWeb && Platform.isAndroid) {
        baseUrl = 'http://10.0.2.2:5173/premium_event/';
      }
      finalUrl = '$baseUrl?eventId=$eventId&recharge=$userRecharge';
    }

    _controller.loadRequest(Uri.parse(finalUrl));
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(activeRechargeEventProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF120C06),
      body: SafeArea(
        top: false,
        child: eventAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFD700)),
          ),
          error: (err, stack) => Center(
            child: Text(
              "Error: $err",
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
          data: (event) {
            if (event == null) {
              return _buildEmptyState(context);
            }
            final eventId = event['id'] as String;
            final customWebUrl = event['webUrl'] as String?;
            
            final userProfile = userProfileAsync.value;
            final userRecharge = userProfile?.monthlyRecharge ?? 0;
            final claimedMilestones = userProfile?.claimedMilestones ?? [];
            
            // Watch active event packages dynamically
            final packagesAsync = ref.watch(rechargeEventPackagesProvider(eventId));
            final packages = packagesAsync.value ?? [];

            final title = event['title'] as String? ?? '';
            final description = event['description'] as String? ?? '';
            
            String endDateStr = '';
            final endDateVal = event['endDate'];
            if (endDateVal is Timestamp) {
              endDateStr = endDateVal.toDate().toUtc().toIso8601String();
            } else if (endDateVal is String) {
              endDateStr = endDateVal;
            }

            // Detect actual deep content updates
            bool hasChanged = false;
            if (userRecharge != _lastRecharge) {
              _lastRecharge = userRecharge;
              hasChanged = true;
            }
            
            final claimedJson = jsonEncode(claimedMilestones);
            final lastClaimedJson = jsonEncode(_lastClaimedMilestones);
            if (claimedJson != lastClaimedJson) {
              _lastClaimedMilestones = claimedMilestones;
              hasChanged = true;
            }

            final pkgsJson = jsonEncode(packages);
            final lastPkgsJson = jsonEncode(_lastPackages);
            if (pkgsJson != lastPkgsJson) {
              _lastPackages = packages;
              hasChanged = true;
            }

            if (title != _lastTitle || description != _lastDescription || endDateStr != _lastEndDateStr) {
              _lastTitle = title;
              _lastDescription = description;
              _lastEndDateStr = endDateStr;
              hasChanged = true;
            }

            if (hasChanged) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _injectData();
              });
            }
            
            _loadUrl(eventId, customWebUrl, userRecharge);

            return Stack(
              children: [
                WebViewWidget(controller: _controller),
                // Back Button Overlay
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFFFD700), size: 16),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                // Floating Dev Test Bar Overlay (Commented Out)
                /*
                Positioned(
                  bottom: 75,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFD700), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.25),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "🧪 TEST:",
                          style: TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 6),
                        _buildTestBtn(context, userProfileAsync.value?.uid, "+\$5", 5),
                        const SizedBox(width: 4),
                        _buildTestBtn(context, userProfileAsync.value?.uid, "+\$10", 10),
                        const SizedBox(width: 4),
                        _buildTestBtn(context, userProfileAsync.value?.uid, "+\$50", 50),
                        const SizedBox(width: 4),
                        _buildResetBtn(context, userProfileAsync.value?.uid),
                      ],
                    ),
                  ),
                ),
                */
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTestBtn(BuildContext context, String? uid, String label, int amount) {
    return InkWell(
      onTap: uid == null ? null : () async {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'monthlyRecharge': FieldValue.increment(amount),
        }, SetOptions(merge: true));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Simulated +\$$amount recharge! Progress updated."),
              duration: const Duration(seconds: 1),
              backgroundColor: const Color(0xFF2E7D32),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFD700), width: 0.8),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildResetBtn(BuildContext context, String? uid) {
    return InkWell(
      onTap: uid == null ? null : () async {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'monthlyRecharge': 0,
        }, SetOptions(merge: true));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Reset recharge progress to \$0."),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.redAccent, width: 0.8),
        ),
        child: const Text(
          "Reset",
          style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFD700).withOpacity(0.05),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.15)),
            ),
            child: const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 64),
          ),
          const Gap(20),
          const Text(
            "UNDER DISCUSSION",
            style: TextStyle(color: Color(0xFFFFB300), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const Gap(8),
          const Text(
            "The Recharge Bonus Event screen is currently under discussion with the client and is incomplete.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
          const Gap(24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B1308),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFFFD700), width: 1),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

