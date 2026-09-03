import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../../core/providers/profile_provider.dart';
import '../../../../../core/services/commission_wallet_service.dart';

class CommissionWalletScreen extends ConsumerStatefulWidget {
  const CommissionWalletScreen({super.key});

  @override
  ConsumerState<CommissionWalletScreen> createState() => _CommissionWalletScreenState();
}

class _CommissionWalletScreenState extends ConsumerState<CommissionWalletScreen> with SingleTickerProviderStateMixin {
  final CommissionWalletService _service = CommissionWalletService();
  late TabController _tabController;
  Map<String, dynamic> _policies = {
    'agencyCommissionRate': 0.30,
    'adminCommissionRate': 0.10,
    'usdToDiamondRate': 1000000,
    'supportedGateways': ['bKash', 'Nagad', 'Rocket', 'Bank Transfer', 'PayPal', 'Wise', 'Binance Pay', 'USDT TRC20', 'USDT BEP20']
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPolicies();
  }

  Future<void> _loadPolicies() async {
    final p = await _service.getFinancialPolicies();
    if (mounted) setState(() => _policies = p);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatUSD(double amt) => '\$${amt.toStringAsFixed(2)} USD';
  String _formatNum(int n) => NumberFormat('#,###').format(n);

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'USD Commission Wallet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.greenAccent),
            onPressed: () {
              ref.invalidate(currentUserProfileProvider);
              _loadPolicies();
            },
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User profile not found', style: TextStyle(color: Colors.white70)));
          }

          if (user.isSuperAdmin && !user.isOwner) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Super Admins operate as branch supervision authorities and do not participate in the commission wallet system.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ),
            );
          }

          final usdBalance = user.usdCommissionBalance;
          final pendingBalance = user.pendingWithdrawalBalance;
          final totalEarned = user.totalCommissionEarned;
          final totalWithdrawn = user.totalWithdrawnUSD;
          final totalRecharge = user.totalRechargeGenerated;

          return SafeArea(
            child: Column(
              children: [
                // ─── Balance Header Cards ────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF18181B),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Available Balance Main Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF10B981)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'AVAILABLE COMMISSION BALANCE',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.verified_user_rounded, color: Colors.white, size: 12),
                                      Gap(4),
                                      Text(
                                        'USD SECURE',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Gap(8),
                            Text(
                              _formatUSD(usdBalance),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 32,
                              ),
                            ),
                            if (pendingBalance > 0) ...[
                              const Gap(6),
                              Row(
                                children: [
                                  const Icon(Icons.lock_clock, color: Colors.amberAccent, size: 14),
                                  const Gap(4),
                                  Text(
                                    'Pending Locked: ${_formatUSD(pendingBalance)}',
                                    style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Gap(16),

                      // Metrics Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              label: 'LIFETIME EARNED',
                              value: _formatUSD(totalEarned),
                              icon: Icons.trending_up_rounded,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: _buildMetricTile(
                              label: 'TOTAL WITHDRAWN',
                              value: _formatUSD(totalWithdrawn),
                              icon: Icons.account_balance_wallet_rounded,
                              color: Colors.purpleAccent,
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: _buildMetricTile(
                              label: 'HOST RECHARGES',
                              value: _formatUSD(totalRecharge),
                              icon: Icons.bolt_rounded,
                              color: Colors.amberAccent,
                            ),
                          ),
                        ],
                      ),
                      const Gap(20),

                      // ─── Action Buttons ────────────────────────────────
                      Row(
                        children: [
                          // 1. Convert to Diamonds
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: usdBalance > 0 ? () => _showConvertToDiamondsModal(user.uid, usdBalance) : null,
                              icon: const Icon(Icons.diamond_rounded, size: 18),
                              label: const Text(
                                'BUY DIAMONDS',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyanAccent.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 4,
                              ),
                            ),
                          ),
                          const Gap(10),

                          // 2. Direct Financial Withdrawal
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: usdBalance > 0 ? () => _showWithdrawalModal(user.uid, usdBalance) : null,
                              icon: const Icon(Icons.payments_rounded, size: 18),
                              label: const Text(
                                'WITHDRAW',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 4,
                              ),
                            ),
                          ),
                          const Gap(10),

                          // 3. Transfer to Reseller
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: usdBalance > 0 ? () => _showResellerTransferModal(user.uid, usdBalance) : null,
                              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                              label: const Text(
                                'RESELLER',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.amberAccent,
                                side: const BorderSide(color: Colors.amberAccent),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ─── History Ledger Tabs ─────────────────────────────
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.greenAccent,
                  labelColor: Colors.greenAccent,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  tabs: const [
                    Tab(text: 'DIAMONDS'),
                    Tab(text: 'WITHDRAWALS'),
                    Tab(text: 'RESELLER'),
                    Tab(text: 'EARNINGS'),
                  ],
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDiamondConversionsTab(user.uid),
                      _buildWithdrawalsTab(user.uid),
                      _buildResellerTransfersTab(user.uid),
                      _buildEarningsTab(user.uid),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
        error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const Gap(4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w800, fontSize: 8),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Gap(4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── Option 3: Convert USD -> Diamonds Modal ─────────────────────
  void _showConvertToDiamondsModal(String uid, double availableUSD) {
    final TextEditingController amountController = TextEditingController(text: '1.00');
    final int rate = _policies['usdToDiamondRate'] ?? 1000000;
    bool isProcessing = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF18181B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double enteredUSD = double.tryParse(amountController.text) ?? 0.0;
            final int previewDiamonds = (enteredUSD * rate).toInt();

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.diamond_rounded, color: Colors.cyanAccent, size: 24),
                          Gap(8),
                          Text(
                            'Convert USD to Diamonds',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Gap(6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.cyanAccent, size: 16),
                        const Gap(8),
                        Expanded(
                          child: Text(
                            'Default Conversion Rate: 1 USD = ${_formatNum(rate)} Diamonds',
                            style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(16),

                  Text(
                    'Available USD Balance: ${_formatUSD(availableUSD)}',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const Gap(10),

                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                    decoration: InputDecoration(
                      labelText: 'USD Amount to Convert',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.attach_money_rounded, color: Colors.greenAccent),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      errorText: errorText,
                    ),
                    onChanged: (_) {
                      setModalState(() {
                        errorText = null;
                      });
                    },
                  ),
                  const Gap(16),

                  // Conversion Live Preview Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        const Text('YOU WILL RECEIVE', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w800, fontSize: 10)),
                        const Gap(4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.diamond_rounded, color: Colors.cyanAccent, size: 22),
                            const Gap(6),
                            Text(
                              _formatNum(previewDiamonds),
                              style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w900, fontSize: 26),
                            ),
                            const Gap(4),
                            const Text('Diamonds', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Gap(24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              final amt = double.tryParse(amountController.text) ?? 0.0;
                              if (amt <= 0) {
                                setModalState(() => errorText = 'Enter a valid positive amount.');
                                return;
                              }
                              if (amt > availableUSD) {
                                setModalState(() => errorText = 'Insufficient USD commission balance.');
                                return;
                              }

                              setModalState(() => isProcessing = true);
                              try {
                                final res = await _service.convertCommissionToDiamonds(amt);
                                if (mounted) {
                                  Navigator.pop(ctx);
                                  ref.invalidate(currentUserProfileProvider);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✅ Successfully converted \$${amt.toStringAsFixed(2)} USD to ${_formatNum(res['diamondsReceived'] as int)} Diamonds!'),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() {
                                  isProcessing = false;
                                  errorText = e.toString().replaceAll('Exception: ', '');
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isProcessing
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('CONFIRM & CONVERT NOW', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Option 2: Direct Withdrawal Modal ────────────────────────────
  void _showWithdrawalModal(String uid, double availableUSD) {
    final TextEditingController amountController = TextEditingController(text: '10.00');
    final TextEditingController accountController = TextEditingController();
    final List<String> gateways = List<String>.from(_policies['supportedGateways'] ?? ['bKash', 'Nagad', 'Rocket', 'Bank Transfer', 'PayPal', 'Wise', 'Binance Pay', 'USDT TRC20', 'USDT BEP20']);
    String selectedGateway = gateways.isNotEmpty ? gateways.first : 'bKash';
    bool isProcessing = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF18181B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.payments_rounded, color: Color(0xFF10B981), size: 24),
                          Gap(8),
                          Text(
                            'Withdraw USD Commission',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Gap(6),
                  Text(
                    'Available Balance: ${_formatUSD(availableUSD)}',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const Gap(16),

                  DropdownButtonFormField<String>(
                    value: selectedGateway,
                    dropdownColor: Colors.black,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Select Payment Gateway / Method',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    items: gateways.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedGateway = val);
                    },
                  ),
                  const Gap(12),

                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Withdrawal Amount (USD)',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.attach_money_rounded, color: Colors.greenAccent),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      errorText: errorText,
                    ),
                  ),
                  const Gap(12),

                  TextField(
                    controller: accountController,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Payment Account Details (IBAN / Phone / Address)',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.account_balance_rounded, color: Colors.greenAccent),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const Gap(20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              final amt = double.tryParse(amountController.text) ?? 0.0;
                              final details = accountController.text.trim();

                              if (amt <= 0 || details.isEmpty) {
                                setModalState(() => errorText = 'Amount and account details required.');
                                return;
                              }
                              if (amt > availableUSD) {
                                setModalState(() => errorText = 'Amount exceeds available balance.');
                                return;
                              }

                              setModalState(() => isProcessing = true);
                              try {
                                await _service.submitCommissionWithdrawal(
                                  usdAmount: amt,
                                  paymentMethod: selectedGateway,
                                  paymentAccountDetails: details,
                                );
                                if (mounted) {
                                  Navigator.pop(ctx);
                                  ref.invalidate(currentUserProfileProvider);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✅ Withdrawal request submitted! Awaiting Owner review.'),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() {
                                  isProcessing = false;
                                  errorText = e.toString().replaceAll('Exception: ', '');
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isProcessing
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('SUBMIT WITHDRAWAL REQUEST', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Option 1: Reseller Transfer Modal ───────────────────────────
  void _showResellerTransferModal(String uid, double availableUSD) {
    final TextEditingController resellerIdController = TextEditingController();
    final TextEditingController amountController = TextEditingController(text: '10.00');
    bool isProcessing = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF18181B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.swap_horiz_rounded, color: Colors.amberAccent, size: 24),
                          Gap(8),
                          Text(
                            'Transfer to Reseller Wallet',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Gap(16),

                  TextField(
                    controller: resellerIdController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Target Reseller Hello ID',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.badge_rounded, color: Colors.amberAccent),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const Gap(12),

                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Transfer Amount (USD)',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.attach_money_rounded, color: Colors.amberAccent),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      errorText: errorText,
                    ),
                  ),
                  const Gap(20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              final rId = resellerIdController.text.trim();
                              final amt = double.tryParse(amountController.text) ?? 0.0;

                              if (rId.isEmpty || amt <= 0) {
                                setModalState(() => errorText = 'Target Reseller ID and amount required.');
                                return;
                              }
                              if (amt > availableUSD) {
                                setModalState(() => errorText = 'Amount exceeds available balance.');
                                return;
                              }

                              setModalState(() => isProcessing = true);
                              try {
                                final res = await _service.transferCommissionToReseller(rId, amt);
                                if (mounted) {
                                  Navigator.pop(ctx);
                                  ref.invalidate(currentUserProfileProvider);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✅ Transferred \$${amt.toStringAsFixed(2)} USD to Reseller ${res['targetName']}!'),
                                      backgroundColor: Colors.amber.shade800,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() {
                                  isProcessing = false;
                                  errorText = e.toString().replaceAll('Exception: ', '');
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent.shade700,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isProcessing
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : const Text('EXECUTE RESELLER TRANSFER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Tab 1: Diamond Conversions History ────────────────────────────
  Widget _buildDiamondConversionsTab(String uid) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.streamDiamondConversions(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('No diamond conversion records', style: TextStyle(color: Colors.grey)));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = list[index];
            final usd = (item['usdAmount'] as num? ?? 0.0).toDouble();
            final diamonds = (item['diamondsReceived'] as num? ?? 0).toInt();

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.diamond_rounded, color: Colors.cyanAccent, size: 20),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Converted ${_formatUSD(usd)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Gap(2),
                        Text(
                          'Rate: 1 USD = ${_formatNum(item['conversionRate'] as int? ?? 1000000)} Diamonds',
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+${_formatNum(diamonds)}',
                        style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                      const Gap(2),
                      const Text(
                        'Completed',
                        style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Tab 2: Direct Withdrawals History ────────────────────────────
  Widget _buildWithdrawalsTab(String uid) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.streamWithdrawals(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('No withdrawal records', style: TextStyle(color: Colors.grey)));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = list[index];
            final usd = (item['usdAmount'] as num? ?? 0.0).toDouble();
            final status = (item['status'] as String? ?? 'pending').toLowerCase();
            final method = item['paymentMethod'] as String? ?? 'Bank';

            Color statusColor = Colors.amber;
            if (status == 'paid' || status == 'approved') statusColor = Colors.greenAccent;
            if (status == 'rejected') statusColor = Colors.redAccent;
            if (status == 'processing') statusColor = Colors.blueAccent;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.payments_rounded, color: statusColor, size: 20),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatUSD(usd),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const Gap(2),
                        Text(
                          'Method: $method • ${item['paymentAccountDetails'] ?? ''}',
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 10),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Tab 3: Reseller Transfers History ────────────────────────────
  Widget _buildResellerTransfersTab(String uid) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.streamResellerTransfers(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('No reseller transfer records', style: TextStyle(color: Colors.grey)));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = list[index];
            final usd = (item['transferAmountUSD'] as num? ?? 0.0).toDouble();

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.swap_horiz_rounded, color: Colors.amberAccent, size: 20),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transferred ${_formatUSD(usd)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Gap(2),
                        Text(
                          'Target: ${item['targetName'] ?? 'Reseller'} (ID: ${item['targetHelloId'] ?? ''})',
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'COMPLETED',
                    style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 10),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Tab 4: Real-Time Commission Earnings Ledger ──────────────────
  Widget _buildEarningsTab(String uid) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.streamCommissionEarnings(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('No commission earnings logged yet', style: TextStyle(color: Colors.grey)));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = list[index];
            final commUSD = (item['commissionUSD'] as num? ?? 0.0).toDouble();
            final rechargeUSD = (item['rechargeUSD'] as num? ?? 0.0).toDouble();
            final rate = ((item['commissionRate'] as num? ?? 0.3) * 100).toInt();

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.trending_up_rounded, color: Colors.greenAccent, size: 20),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '+${_formatUSD(commUSD)} ($rate% Comm)',
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Gap(2),
                        Text(
                          'Host Recharge: ${_formatUSD(rechargeUSD)} • Host UID: ${(item['hostUid'] as String? ?? '').slice(0, 8)}...',
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

extension StringSlice on String {
  String slice(int start, int end) {
    if (length <= end) return this;
    return substring(start, end);
  }
}
