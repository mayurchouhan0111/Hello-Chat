import 'package:flutter/material.dart';
import '../../../../core/constants/stickers_data.dart';

class StickerSheet extends StatelessWidget {
  final Function(String stickerPath) onStickerSelected;

  const StickerSheet({super.key, required this.onStickerSelected});

  @override
  Widget build(BuildContext context) {
    final packs = StickersData.activePacks;

    return DefaultTabController(
      length: packs.length,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.42,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: Colors.pinkAccent,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: Colors.pinkAccent,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
              tabs: packs.map((pack) => Tab(text: pack.title)).toList(),
            ),
            Expanded(
              child: TabBarView(
                children: packs.map((pack) => _buildStickerGrid(context, pack.stickers)).toList(),
              ),
            ),
          ],
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
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final path = stickers[index];
        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            onStickerSelected(path);
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
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
