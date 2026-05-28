import 'package:flutter/material.dart';
import '../../../../core/constants/stickers_data.dart';

class StickerSheet extends StatelessWidget {
  final Function(String stickerPath) onStickerSelected;

  const StickerSheet({super.key, required this.onStickerSelected});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const TabBar(
              indicatorColor: Colors.pinkAccent,
              labelColor: Colors.pinkAccent,
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(text: "Hot Cherry"),
                Tab(text: "Utya Duck"),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildStickerGrid(context, StickersData.hotCherry),
                  _buildStickerGrid(context, StickersData.utyaDuck),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerGrid(BuildContext context, List<String> stickers) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
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
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                path,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}
