import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hello_chat/core/models/transaction_model.dart';
import 'package:hello_chat/providers/wallet_provider.dart';
import 'package:hello_chat/features/wallet/presentation/widgets/wallet/diamond_tab.dart';
import 'package:hello_chat/features/wallet/presentation/widgets/wallet/beans_tab.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(walletBalanceProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.black, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Wallet',
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: balanceAsync.when(
        data: (balance) => Column(
          children: [
            // 1. Exact TabBar (Text-only, no BG)
            _buildTabBar(),

            // 2. TabBarView
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  DiamondTab(diamondBalance: balance['diamonds'] ?? 0),
                  BeansTab(beansBalance: balance['beans'] ?? 0),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text("Error: $e")),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelColor: Colors.black,
        unselectedLabelColor: Colors.black26,
        labelPadding: const EdgeInsets.only(right: 20),
        labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, family: 'Roboto'),
        unselectedLabelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
        indicator: const RoundUnderlineTabIndicator(
          borderSide: BorderSide(width: 4, color: Colors.orangeAccent),
          insets: EdgeInsets.only(bottom: 2),
        ),
        tabs: const [
          Tab(text: 'Diamonds'),
          Tab(text: 'Beans'),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final transactionsAsync = ref.watch(walletTransactionsProvider);

    return transactionsAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return const Center(child: Text("No transactions yet."));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: transactions.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final tx = transactions[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _buildTransactionIcon(tx.type),
              title: Text(tx.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(tx.timestamp.toLocal().toString().split('.')[0], style: const TextStyle(fontSize: 12)),
              trailing: Text(
                "${tx.type == TransactionType.recharge || tx.type == TransactionType.gift_received ? '+' : '-'}${tx.amount}",
                style: TextStyle(
                  color: tx.type == TransactionType.recharge || tx.type == TransactionType.gift_received ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Center(child: Text("Error: $e")),
    );
  }

  Widget _buildTransactionIcon(TransactionType type) {
    IconData icon = Icons.help_outline;
    Color color = Colors.grey;
    switch (type) {
      case TransactionType.recharge:
        icon = Icons.add_card_rounded;
        color = Colors.blue;
        break;
      case TransactionType.gift_sent:
        icon = Icons.unarchive_rounded;
        color = const Color(0xFFFFD700);
        break;
      case TransactionType.gift_received:
        icon = Icons.archive_rounded;
        color = Colors.green;
        break;
      case TransactionType.cash_out:
        icon = Icons.account_balance_wallet_rounded;
        color = Colors.purple;
        break;
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class RoundUnderlineTabIndicator extends Decoration {
  final BorderSide borderSide;
  final EdgeInsetsGeometry insets;

  const RoundUnderlineTabIndicator({
    this.borderSide = const BorderSide(width: 2.0, color: Colors.blue),
    this.insets = EdgeInsets.zero,
  });

  @override
  Decoration? lerpFrom(Decoration? a, double t) {
    if (a is RoundUnderlineTabIndicator) {
      return RoundUnderlineTabIndicator(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        insets: EdgeInsets.lerp(a.insets as EdgeInsets?, insets as EdgeInsets?, t)!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  Decoration? lerpTo(Decoration? b, double t) {
    if (b is RoundUnderlineTabIndicator) {
      return RoundUnderlineTabIndicator(
        borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        insets: EdgeInsets.lerp(insets as EdgeInsets?, b.insets as EdgeInsets?, t)!,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _RoundUnderlinePainter(this, onChanged);
  }
}

class _RoundUnderlinePainter extends BoxPainter {
  final RoundUnderlineTabIndicator decoration;

  _RoundUnderlinePainter(this.decoration, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    assert(configuration.size != null);
    final Rect rect = offset & configuration.size!;
    final TextDirection? textDirection = configuration.textDirection;
    final Rect indicator = decoration.insets.resolve(textDirection).deflateRect(rect);
    
    // Create the rounded dash indicator
    final Paint paint = decoration.borderSide.toPaint()..strokeCap = StrokeCap.round;
    const double indicatorWidth = 14; // Professional short dash
    final double center = indicator.left + indicator.width / 2;
    
    canvas.drawLine(
      Offset(center - indicatorWidth / 2, indicator.bottom - decoration.borderSide.width),
      Offset(center + indicatorWidth / 2, indicator.bottom - decoration.borderSide.width),
      paint,
    );
  }
}
