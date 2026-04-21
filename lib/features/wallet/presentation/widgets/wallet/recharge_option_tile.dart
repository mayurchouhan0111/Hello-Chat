import 'package:flutter/material.dart';
import 'package:hello_chat/core/widgets/premium_diamond.dart';

class RechargeOptionTile extends StatelessWidget {
  final String title;
  final dynamic subtitle;
  final Widget icon;
  final String? bonus;
  final String? description;
  final bool isExpandable;
  final List<int>? rechargeOptions;
  final VoidCallback? onTap;
  final ValueChanged<int>? onAmountSelected;

  const RechargeOptionTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.bonus,
    this.description,
    this.isExpandable = false,
    this.rechargeOptions,
    this.onTap,
    this.onAmountSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (isExpandable) {
      return Column(
        children: [
          ExpansionTile(
            leading: icon,
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Row(
                    children: [
                      subtitle is Widget ? subtitle : Text(subtitle.toString(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      if (bonus != null) ...[
                        const SizedBox(width: 8),
                        _buildBonusChip(bonus!),
                      ],
                    ],
                  ),
                if (description != null)
                  Text(description!, style: const TextStyle(color: Colors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
            trailing: const Icon(Icons.expand_more_rounded, size: 20, color: Colors.grey),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: const Border.fromBorderSide(BorderSide.none),
            collapsedShape: const Border.fromBorderSide(BorderSide.none),
            children: _buildExpandableChildren(),
          ),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
        ],
      );
    }

    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: icon,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: subtitle != null 
              ? (subtitle is Widget ? subtitle : Text(subtitle.toString(), style: const TextStyle(color: Colors.grey, fontSize: 12)))
              : null,
          trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
      ],
    );
  }

  Widget _buildBonusChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9C4), // Light yellow
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  List<Widget> _buildExpandableChildren() {
    if (rechargeOptions == null) return [const SizedBox.shrink()];
    return [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: rechargeOptions!.map((amt) => _buildAmountCard(amt)).toList(),
      ),
    ];
  }

  Widget _buildAmountCard(int amount) {
    return GestureDetector(
      onTap: () => onAmountSelected?.call(amount),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PremiumDiamond(size: 16),
              const SizedBox(width: 4),
              Text("$amount", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
