import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/services/base_firebase_service.dart';

class WithdrawBeansScreen extends ConsumerStatefulWidget {
  const WithdrawBeansScreen({super.key});

  @override
  ConsumerState<WithdrawBeansScreen> createState() => _WithdrawBeansScreenState();
}

class _WithdrawBeansScreenState extends ConsumerState<WithdrawBeansScreen> {
  final _amountController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  String _selectedMethod = 'UPI';
  bool _isLoading = false;

  final List<String> _methods = ['UPI', 'Bank Transfer', 'PayPal'];

  void _submitRequest() async {
    final amountText = _amountController.text.trim();
    final accountText = _accountController.text.trim();
    
    if (amountText.isEmpty || accountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all details")),
      );
      return;
    }

    final amount = int.tryParse(amountText) ?? 0;
    if (amount < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Minimum withdrawal is 1000 Beans")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Call Cloud Function
      // final result = await ref.read(walletServiceProvider).requestWithdrawal(
      //   amount: amount,
      //   method: _selectedMethod,
      //   accountDetails: {
      //     'account': accountText,
      //     'ifsc': _ifscController.text.trim(),
      //   },
      // );
      
      // Mock Success for now
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Request Submitted"),
            content: const Text("Your withdrawal request has been received. Please wait 24-48 hours for processing."),
            actions: [
              TextButton(onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back
              }, child: const Text("OK"))
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Redeem Beans", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Balance Overview
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Active Earnings", style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.bold)),
                      Image.network("https://img.icons8.com/emoji/48/money-bag-emoji.png", width: 20),
                    ],
                  ),
                  const Gap(12),
                  userAsync.when(
                    data: (user) => Text(
                      "${user?.beansBalance ?? 0}",
                      style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900),
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Text("??", style: TextStyle(color: Colors.white)),
                  ),
                  const Text("Total Available Beans", style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),

            const Gap(32),

            // 2. Input Section
            const Text("Withdrawal Details", style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w900)),
            const Gap(16),
            
            _buildInputLabel("Amount to Redeem"),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration("e.g. 5000"),
            ),
            
            const Gap(20),
            
            _buildInputLabel("Select Payment Method"),
            _buildMethodSelector(),
            
            const Gap(20),
            
            _buildInputLabel(_selectedMethod == 'UPI' ? "UPI ID" : (_selectedMethod == 'PayPal' ? "PayPal Email" : "Bank Account Number")),
            TextField(
              controller: _accountController,
              decoration: _inputDecoration(_selectedMethod == 'UPI' ? "username@upi" : "account number"),
            ),
            
            if (_selectedMethod == 'Bank Transfer') ...[
              const Gap(20),
              _buildInputLabel("IFSC Code"),
              TextField(
                controller: _ifscController,
                decoration: _inputDecoration("BANK0001234"),
              ),
            ],

            const Gap(40),

            // 3. Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangle.circle(16),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Submit Withdrawal Request", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
            
            const Gap(20),
            const Center(
              child: Text(
                "Final amount depends on payment gateway fees\nand platform processing time (1-3 days).",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black38, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black12),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.black12, width: 0.5)),
    );
  }

  Widget _buildMethodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _methods.map((m) {
          final isSelected = _selectedMethod == m;
          return GestureDetector(
            onTap: () => setState(() => _selectedMethod = m),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? Colors.transparent : Colors.black12),
              ),
              child: Text(
                m,
                style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
