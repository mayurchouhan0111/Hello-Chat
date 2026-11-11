import 'package:flutter/material.dart';
import 'package:hello_chat/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

class YouTubePanel extends ConsumerStatefulWidget {
  final String roomId;
  final bool isEmbedded;

  const YouTubePanel({
    super.key,
    required this.roomId,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<YouTubePanel> createState() => _YouTubePanelState();
}

class _YouTubePanelState extends ConsumerState<YouTubePanel> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _categoryController;
  final yt.YoutubeExplode _yt = yt.YoutubeExplode();

  final List<String> _categories = [
    "Popular",
    "Music",
    "Movie",
    "Gaming",
    "Funny",
    "Favourite",
    "News",
  ];
  List<dynamic> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _categoryController = TabController(length: _categories.length, vsync: this, initialIndex: 0);
    _categoryController.addListener(() {
      if (!_categoryController.indexIsChanging && mounted) {
        setState(() {});
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
      query = "trending music videos";
    } else if (category == "Favourite") {
      query = "top music hits 2026";
    } else if (category == "Music") {
      query = "new released song";
    } else if (category == "Movie") {
      query = "movie trailer scene";
    } else if (category == "Gaming") {
      query = "gaming highlights";
    } else {
      query = category;
    }
    _searchVideos(query);
  }

  Future<void> _onSearch(String val) async {
    final query = val.trim();
    if (query.isEmpty) return;

    if (query.contains("youtube.com") || query.contains("youtu.be")) {
      try {
        final videoId = YoutubePlayerController.convertUrlToId(query);
        if (videoId != null) {
          _onVideoTap(videoId);
          return;
        }
      } catch (_) {}
    }

    _searchVideos(query);
  }

  Future<void> _searchVideos(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await _yt.search.search(query);
      if (mounted) {
        setState(() {
          _videos = results.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onVideoTap(String videoId) async {
    try {
      await ref.read(roomServiceProvider).setYoutubeVideo(widget.roomId, videoId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, 
            content: Row(
              children: [
                Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 20),
                Gap(8),
                Text(
                  "Playing video in room...",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text("Failed to play: $e")),
        );
      }
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return "HD";
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.isEmbedded ? null : MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: widget.isEmbedded ? Colors.transparent : const Color(0xFF0F111E),
        borderRadius: widget.isEmbedded ? null : const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // 1. Header (Standalone only)
          if (!widget.isEmbedded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_circle_filled_rounded, color: Color(0xFFEF4444), size: 22),
                  ),
                  const Gap(10),
                  const Text(
                    "YouTube Stream",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                  ),
                ],
              ),
            ),

          // 2. Modern Polished Dark Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF16192A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500),
                cursorColor: const Color(0xFFEF4444),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF16192A),
                  hintText: "Search songs, videos or paste link...",
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12.5),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFEF4444), size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, color: Colors.white54, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                            _fetchCategory(_categories[_categoryController.index]);
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: _onSearch,
              ),
            ),
          ),

          // 3. Category Capsule Tabs (Smooth Pill Bar)
          Container(
            height: 38,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: TabBar(
              controller: _categoryController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(19),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: _categories.asMap().entries.map((entry) {
                final isSelected = _categoryController.index == entry.key;
                return Tab(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.08),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // 4. Video List with Modern Cards or Loading
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFFEF4444),
                          strokeWidth: 2.8,
                        ),
                        Gap(12),
                        Text(
                          "Loading YouTube streams...",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : _videos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.search_off_rounded, color: Colors.white38, size: 42),
                            ),
                            const Gap(12),
                            const Text(
                              "No videos found",
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const Gap(4),
                            const Text(
                              "Try another search term or paste a link",
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _videos.length,
                        separatorBuilder: (_, __) => const Gap(10),
                        itemBuilder: (context, index) {
                          final yt.Video video = _videos[index];
                          return _buildModernVideoCard(video);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernVideoCard(yt.Video video) {
    final videoId = video.id.value;
    final title = video.title;
    final author = video.author;
    final thumbnailUrl = video.thumbnails.mediumResUrl;
    final durationStr = _formatDuration(video.duration);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onVideoTap(videoId),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF16192A), Color(0xFF101322)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. High-Quality Thumbnail with Duration Badge
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      width: 124,
                      height: 74,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 124,
                        height: 74,
                        color: const Color(0xFF1E2338),
                        child: const Center(
                          child: Icon(Icons.movie_outlined, color: Colors.white24, size: 24),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 124,
                        height: 74,
                        color: const Color(0xFF1E2338),
                        child: const Center(
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white38, size: 28),
                        ),
                      ),
                    ),
                  ),

                  // Duration Pill Overlay at bottom right
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        durationStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(12),

              // 2. Video Title, Channel & Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const Gap(5),
                    Row(
                      children: [
                        const Icon(
                          Icons.account_circle_outlined,
                          size: 13,
                          color: Colors.white38,
                        ),
                        const Gap(4),
                        Expanded(
                          child: Text(
                            author,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap(8),

              // 3. Glowing Red Action Play Button
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
