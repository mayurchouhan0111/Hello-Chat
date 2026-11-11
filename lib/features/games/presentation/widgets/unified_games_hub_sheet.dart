import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'games_panel.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/youtube_panel.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/pk_matching_bottom_sheet.dart';

class UnifiedGamesHubSheet extends StatefulWidget {
  final String roomId;
  final int initialCategory; // 0 = Games, 1 = YouTube, 2 = PK

  const UnifiedGamesHubSheet({
    super.key,
    required this.roomId,
    this.initialCategory = 0,
  });

  @override
  State<UnifiedGamesHubSheet> createState() => _UnifiedGamesHubSheetState();
}

class _UnifiedGamesHubSheetState extends State<UnifiedGamesHubSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_CategoryTab> _tabs = const [
    _CategoryTab(
      title: 'Games',
      icon: Icons.sports_esports_rounded,
      activeColor: Color(0xFF818CF8),
      glowColor: Color(0xFF6366F1),
    ),
    _CategoryTab(
      title: 'YouTube',
      icon: Icons.play_circle_filled_rounded,
      activeColor: Color(0xFFF87171),
      glowColor: Color(0xFFEF4444),
    ),
    _CategoryTab(
      title: 'PK',
      icon: Icons.military_tech_rounded,
      activeColor: Color(0xFFFBBF24),
      glowColor: Color(0xFFF59E0B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialCategory.clamp(0, _tabs.length - 1),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = _tabs[_tabController.index];

    return Container(
      height: MediaQuery.of(context).size.height * 0.74,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF101322), Color(0xFF070810)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: activeTab.glowColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
          BoxShadow(
            color: activeTab.glowColor.withValues(alpha: 0.12),
            blurRadius: 32,
            spreadRadius: 2,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header with Segmented Category Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF181C2E),
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            activeTab.glowColor,
                            activeTab.glowColor.withValues(alpha: 0.85),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: activeTab.glowColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white60,
                      labelPadding: EdgeInsets.zero,
                      tabs: _tabs.map((tab) {
                        return Tab(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(tab.icon, size: 16),
                                  const Gap(5),
                                  Text(
                                    tab.title,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const Gap(8),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Tab content area
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Games Tab
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: GamesPanel(
                    roomId: widget.roomId,
                    onSwitchTab: (tabIndex) {
                      _tabController.animateTo(tabIndex);
                    },
                  ),
                ),

                // 2. YouTube Tab
                YouTubePanel(roomId: widget.roomId, isEmbedded: true),

                // 3. PK Tab (Embedded mode: enforces host-only controls)
                PKMatchingBottomSheet(roomId: widget.roomId, isEmbedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTab {
  final String title;
  final IconData icon;
  final Color activeColor;
  final Color glowColor;

  const _CategoryTab({
    required this.title,
    required this.icon,
    required this.activeColor,
    required this.glowColor,
  });
}
