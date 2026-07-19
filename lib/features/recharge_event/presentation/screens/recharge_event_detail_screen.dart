import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  
  // Track actual injected values to prevent redundant loops & OOM crashes
  int _lastInjectedRecharge = -1;
  String _lastInjectedPackagesJson = '';

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
        }
      },
    );
  }

  void _injectData() {
    if (!_pageLoaded) return;

    // 1. Only inject user progress if it actually changed or hasn't been injected yet
    if (_lastRecharge != _lastInjectedRecharge) {
      _lastInjectedRecharge = _lastRecharge;
      _controller.runJavaScript("if (window.setUserData) window.setUserData({ recharge: $_lastRecharge });");
    }

    // 2. Only inject packages list if JSON representation is different to avoid infinite OOM loops
    final pkgsJson = jsonEncode(_lastPackages);
    if (pkgsJson != _lastInjectedPackagesJson) {
      _lastInjectedPackagesJson = pkgsJson;
      _controller.runJavaScript("if (window.setEventPackages) window.setEventPackages($pkgsJson);");
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
            
            final userRecharge = userProfileAsync.value?.monthlyRecharge ?? 0;
            
            // Watch active event packages dynamically
            final packagesAsync = ref.watch(rechargeEventPackagesProvider(eventId));
            final packages = packagesAsync.value ?? [];

            // Detect actual deep content updates
            bool hasChanged = false;
            if (userRecharge != _lastRecharge) {
              _lastRecharge = userRecharge;
              hasChanged = true;
            }
            
            final pkgsJson = jsonEncode(packages);
            final lastPkgsJson = jsonEncode(_lastPackages);
            if (pkgsJson != lastPkgsJson) {
              _lastPackages = packages;
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
              ],
            );
          },
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

