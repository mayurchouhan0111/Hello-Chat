import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:dio/dio.dart';
import '../../../../core/constants/app_keys.dart';

class YouTubePanel extends ConsumerStatefulWidget {
  final String roomId;
  const YouTubePanel({super.key, required this.roomId});

  @override
  ConsumerState<YouTubePanel> createState() => _YouTubePanelState();
}

class _YouTubePanelState extends ConsumerState<YouTubePanel> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _categoryController;
  final yt.YoutubeExplode _yt = yt.YoutubeExplode();
  final Dio _dio = Dio();
  
  final List<String> _categories = ["Favourite", "Popular", "Music", "Movie", "Funny", "Gaming", "News"];
  List<dynamic> _videos = []; // Changed to dynamic to handle API response
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _categoryController = TabController(length: _categories.length, vsync: this, initialIndex: 1);
    _categoryController.addListener(() {
      if (!_categoryController.indexIsChanging) {
        _fetchCategory(_categories[_categoryController.index]);
      }
    });
    _fetchCategory("Popular");
  }

  @override
  void dispose() {
    _yt.close();
    _categoryController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategory(String category) async {
    String query;
    if (category == "Popular") {
      query = "trending";
    } else if (category == "Favourite") {
      query = "top music videos";
    } else if (category == "Music") {
      query = "new music videos";
    } else {
      query = category;
    }
    _searchVideos(query);
  }

  Future<void> _onSearch(String val) async {
    if (val.isEmpty) return;
    
    // Check if it's a direct URL first
    if (val.contains("youtube.com") || val.contains("youtu.be")) {
       try {
        final videoId = YoutubePlayerController.convertUrlToId(val);
        if (videoId != null) {
          _onVideoTap(videoId);
          return;
        }
      } catch (_) {}
    }

    _searchVideos(val);
  }

  Future<void> _searchVideos(String query) async {
    setState(() => _isLoading = true);
    try {
      final searchList = await _yt.search.getVideos(query);
      setState(() {
        _videos = searchList.toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("YouTube Search Error: $e");
      // Retry once after delay if rate-limited
      if (e.toString().contains('RequestLimitExceeded') ||
          e.toString().contains('rate limit') ||
          e.toString().contains('429')) {
        debugPrint("Rate limited on search — retrying after 2s...");
        await Future.delayed(const Duration(seconds: 2));
        try {
          final retryList = await _yt.search.getVideos(query);
          if (mounted) {
            setState(() {
              _videos = retryList.toList();
              _isLoading = false;
            });
          }
          return;
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('YouTube is rate-limiting requests. Please wait a moment and try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  bool _isSelecting = false;

  void _onVideoTap(String videoId) async {
    if (_isSelecting) return;
    setState(() => _isSelecting = true);

    debugPrint('👆 [YouTubePanel] Video Selected: $videoId. Skipping embed check to avoid rate limits...');
    
    await ref.read(roomServiceProvider).setYoutubeVideo(widget.roomId, videoId);
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<bool> _isVideoEmbeddable(String videoId) async {
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 1. Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.play_circle_filled_rounded, color: Colors.red, size: 32),
                const Gap(8),
                const Text(
                  "YouTube",
                  style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.close, color: Colors.black, size: 28),
                  tooltip: 'Cancel',
                ),
              ],
            ),
          ),

          // 2. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.black, fontSize: 16),
                decoration: InputDecoration(
                  hintText: "Search keywords or video link",
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 22),
                  suffixIcon: _searchController.text.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.cancel, color: Color(0xFF94A3B8), size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _fetchCategory("Popular");
                        },
                      )
                    : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (val) => setState(() {}),
                onSubmitted: _onSearch,
              ),
            ),
          ),

          // 3. Category Tabs
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TabBar(
              controller: _categoryController,
              isScrollable: true,
              indicatorColor: Colors.black,
              indicatorSize: TabBarIndicatorSize.label,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              labelColor: Colors.black,
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
              dividerColor: Colors.transparent,
              tabs: _categories.map((c) => Tab(text: c)).toList(),
            ),
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 1),

          // 4. Video List or Loading
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.red))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  itemCount: _videos.length,
                  separatorBuilder: (_, __) => const Gap(20),
                  itemBuilder: (context, index) {
                    final yt.Video video = _videos[index];
                    return _buildVideoTile(video);
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoTile(yt.Video video) {
    final videoId = video.id.value;
    final title = video.title;
    final author = video.author;
    final thumbnailUrl = video.thumbnails.mediumResUrl;

    return InkWell(
      onTap: () => _onVideoTap(videoId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                thumbnailUrl,
                width: 150,
                height: 85,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: Colors.black12, width: 150, height: 85),
              ),
            ),
            const Gap(12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.bold, height: 1.2),
                  ),
                  const Gap(6),
                  Text(
                    author,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                ],
              ),
            ),
            // Action
            const Padding(
              padding: EdgeInsets.only(left: 8, top: 2),
              child: Icon(Icons.bookmark_border_rounded, color: Color(0xFF64748B), size: 24),
            ),
          ],
        ),
      ),
    );
  }
}
