import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/admin_wallet_service.dart';

class AdminWalletScreen extends StatefulWidget {
  const AdminWalletScreen({super.key});

  @override
  State<AdminWalletScreen> createState() => _AdminWalletScreenState();
}

class _AdminWalletScreenState extends State<AdminWalletScreen> {
  final AdminWalletService _service = AdminWalletService();
  late Future<Map<String, dynamic>> _overview;

  @override
  void initState() {
    super.initState();
    _overview = _service.getOverview();
  }

  void _refresh() {
    setState(() => _overview = _service.getOverview());
  }

  String _money(dynamic value) => NumberFormat.currency(
        symbol: r'$',
        decimalDigits: 2,
      ).format((value as num?)?.toDouble() ?? 0);

  String _errorText(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.message ?? 'Unable to load the Admin Wallet.';
    }
    return 'Unable to load the Admin Wallet. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1422),
        title: const Text(
          'ADMIN WALLET',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _overview,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded,
                        color: Colors.amber, size: 48),
                    const Gap(12),
                    Text(
                      _errorText(snapshot.error!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const Gap(16),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data ?? const <String, dynamic>{};
          final admins = (data['admins'] as List? ?? const [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          final transactions = (data['transactions'] as List? ?? const [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          final scope = data['scope']?.toString() ?? 'self';

          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _overview;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  scope == 'self'
                      ? 'YOUR 10% RECHARGE COMMISSION'
                      : scope == 'branch'
                          ? 'BRANCH ADMIN WALLET TOTAL'
                          : 'ALL ADMIN WALLET TOTAL',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const Gap(10),
                _BalanceCard(
                  balance: _money(data['totalBalanceUSD']),
                  earned: _money(data['totalEarnedUSD']),
                  recharge: _money(data['totalRechargeUSD']),
                ),
                if (scope != 'self') ...[
                  const Gap(22),
                  const _SectionTitle('ADMIN BALANCES'),
                  const Gap(10),
                  if (admins.isEmpty)
                    const _EmptyCard('No appointed Admin wallets found.')
                  else
                    ...admins.map(
                      (admin) => _AdminBalanceTile(
                        admin: admin,
                        money: _money,
                      ),
                    ),
                ],
                const Gap(22),
                const _SectionTitle('TRANSACTION HISTORY'),
                const Gap(10),
                if (transactions.isEmpty)
                  const _EmptyCard('No Admin commission transactions yet.')
                else
                  ...transactions.map(
                    (tx) => _TransactionTile(tx: tx, money: _money),
                  ),
                const Gap(32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.earned,
    required this.recharge,
  });

  final String balance;
  final String earned;
  final String recharge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF047857), Color(0xFF10B981)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AVAILABLE USD BALANCE',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
          const Gap(6),
          Text(balance,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900)),
          const Gap(16),
          Row(
            children: [
              Expanded(
                  child: _MiniMetric(label: 'Total earned', value: earned)),
              Expanded(
                  child:
                      _MiniMetric(label: 'Recharge volume', value: recharge)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
          const Gap(2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      );
}

class _AdminBalanceTile extends StatelessWidget {
  const _AdminBalanceTile({required this.admin, required this.money});
  final Map<String, dynamic> admin;
  final String Function(dynamic) money;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF131A29),
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFF1E3A5F),
            child: Icon(Icons.admin_panel_settings_rounded,
                color: Color(0xFF60A5FA)),
          ),
          title: Text(admin['displayName']?.toString() ?? 'Admin',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text('ID: ${admin['helloId'] ?? admin['uid']}',
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          trailing: Text(money(admin['usdCommissionBalance']),
              style: const TextStyle(
                  color: Color(0xFF34D399), fontWeight: FontWeight.w900)),
        ),
      );
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx, required this.money});
  final Map<String, dynamic> tx;
  final String Function(dynamic) money;

  @override
  Widget build(BuildContext context) {
    final timestamp = DateTime.tryParse(tx['timestamp']?.toString() ?? '');
    return Card(
      color: const Color(0xFF131A29),
      child: ListTile(
        leading: const Icon(Icons.south_west_rounded, color: Color(0xFF34D399)),
        title: Text('+${money(tx['commissionUSD'])}',
            style: const TextStyle(
                color: Color(0xFF34D399), fontWeight: FontWeight.w900)),
        subtitle: Text(
          'Recharge ${money(tx['rechargeUSD'])} · Agency ${tx['agencyId'] ?? '-'}\n'
          '${timestamp == null ? 'Date unavailable' : DateFormat.yMMMd().add_jm().format(timestamp.toLocal())}',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF131A29),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54)),
      );
}
