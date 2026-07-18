import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/models/event_model.dart';
import '../../../../core/services/event_service.dart';

class DynamicEventScreen extends ConsumerWidget {
  final String? eventId;
  final EventModel? event;

  const DynamicEventScreen({super.key, this.eventId, this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (event != null) {
      return _EventBody(event: event!);
    }

    final eventAsync = ref.watch(eventByIdProvider(eventId ?? ''));
    return eventAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        body: Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
      ),
      data: (ev) {
        if (ev == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('Event not found', style: TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              ),
            ),
          );
        }
        return _EventBody(event: ev);
      },
    );
  }
}

class _EventBody extends ConsumerWidget {
  final EventModel event;

  const _EventBody({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _createController(context, ref))),
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            left: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _bodyCss() {
    switch (event.backgroundType) {
      case 'gradient':
        final stops = event.backgroundGradient.join(', ');
        return 'linear-gradient(180deg, $stops)';
      case 'image':
        if (event.backgroundImage.isNotEmpty) {
          return 'url(${event.backgroundImage}) center/cover no-repeat';
        }
        break;
    }
    return event.backgroundColor;
  }

  WebViewController _createController(BuildContext context, WidgetRef ref) {
    final controller = WebViewController();

    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (nav) {
        if (nav.url.startsWith('hellochat://')) {
          _handleHellochatUrl(context, ref, nav.url);
          return NavigationDecision.prevent;
        }
        if (nav.url.startsWith('http://') || nav.url.startsWith('https://')) {
          return NavigationDecision.navigate;
        }
        return NavigationDecision.prevent;
      },
    ));

    controller.setBackgroundColor(Colors.transparent);
    final fullHtml = _buildHtml();
    controller.loadHtmlString(fullHtml);

    return controller;
  }

  String _buildHtml() {
    final theme = event.themeColor;
    final bg = _bodyCss();

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cinzel+Decorative:wght@700;900&family=Cinzel:wght@700;800;900&family=Outfit:wght@300;400;600;700;800&display=swap" rel="stylesheet">
  <style>
    :root { --theme: $theme; }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html { height: 100%; width: 100%; }
    body {
      min-height: 100%; width: 100%;
      overflow-x: hidden; overflow-y: auto;
      -webkit-overflow-scrolling: touch;
      background: $bg;
      background-attachment: fixed;
      color: #f5eccd;
      font-family: 'Outfit', sans-serif;
      -webkit-font-smoothing: antialiased;
    }
    img, video, iframe, table { max-width: 100%; height: auto; }
    a { text-decoration: none; color: inherit; }
  </style>
</head>
<body>
  <div id="app">${event.htmlContent.isEmpty ? '<div style="padding:40px;text-align:center;color:#888">No content</div>' : event.htmlContent}</div>
  <script>
    document.addEventListener('click', function(e) {
      var t = e.target.closest('a');
      if (t && t.getAttribute('href') && t.getAttribute('href').startsWith('hellochat://')) {
        e.preventDefault(); window.location.href = t.getAttribute('href');
      }
    });
  </script>
</body>
</html>
''';
  }

  void _handleHellochatUrl(BuildContext context, WidgetRef ref, String url) {
    if (url.startsWith('hellochat://wallet') || url.startsWith('hellochat://recharge')) {
      context.push('/wallet');
    } else if (url.startsWith('hellochat://route/')) {
      final path = url.substring('hellochat://route/'.length);
      context.push('/$path');
    } else if (url.startsWith('hellochat://claim/')) {
      final parts = url.substring('hellochat://claim/'.length).split('/');
      if (parts.length >= 2) {
        _claimReward(context, ref, parts[0], parts[1]);
      }
    }
  }

  void _claimReward(BuildContext context, WidgetRef ref, String milestoneId, String eventId) async {
    final result = await ref.read(eventServiceProvider).claimMilestoneReward(eventId, milestoneId);
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Reward claimed! +${result['rewardAmount']}"), backgroundColor: Colors.green),
      );
    }
  }
}
