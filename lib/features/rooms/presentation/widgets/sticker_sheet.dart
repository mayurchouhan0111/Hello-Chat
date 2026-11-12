import 'package:flutter/material.dart';
import '../../../../core/constants/stickers_data.dart';

class StickerSheet extends StatelessWidget {
  final Function(String stickerPath) onStickerSelected;
  final Color? backgroundColor;
  final bool showHandle;

  const StickerSheet({
    super.key,
    required this.onStickerSelected,
    this.backgroundColor,
    this.showHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    const packs = StickersData.activePacks;

    return DefaultTabController(
      length: packs.length,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.48,
        decoration: BoxDecoration(
          color: backgroundColor ?? const Color(0xFF0F111A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              if (showHandle)
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicator: BoxDecoration(
                    color: const Color(0xFF252938),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                  tabs: packs.map((pack) => Tab(text: pack.title)).toList(),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: packs.map((pack) => _buildStickerGrid(context, pack.stickers)).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickerGrid(BuildContext context, List<String> stickers) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final path = stickers[index];
        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            onStickerSelected(path);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                path,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.sentiment_satisfied_alt_rounded,
                  color: Colors.white38,
                  size: 28,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
