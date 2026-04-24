import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/services/reseller_service.dart';

class TransferDiamondsScreen extends ConsumerStatefulWidget {
  const TransferDiamondsScreen({super.key});

  @override
  ConsumerState<TransferDiamondsScreen> createState() => _TransferDiamondsScreenState();
}

class _TransferDiamondsScreenState extends ConsumerState<TransferDiamondsScreen> {
  final _helloIdController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isTransferring = false;

  Future<void> _handleTransfer() async {
    final helloId = _helloIdController.text.trim();
    final amountText = _amountController.text.trim();

    if (helloId.isEmpty || amountText.isEmpty) {
      _showWarning("All fields are required");
      return;
    }

    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showWarning("Invalid diamond amount");
      return;
    }

    setState(() => _isTransferring = true);
    try {
      final result = await ref.read(resellerServiceProvider).transferDiamonds(
        targetHelloId: helloId,
        amount: amount,
      );

      if (result['success'] == true) {
        if (mounted) {
           _showSuccessDialog(result['targetName'], amount);
           ref.refresh(currentUserProfileProvider);
        }
      }
    } catch (e) {
      if (mounted) _showWarning(e.toString());
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  void _showWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ));
  }

  void _showSuccessDialog(String? name, int amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: const Color(0xFF10B981), size: 48),
            ),
            const SizedBox(height: 24),
            const Text("TRANSFER COMPLETE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(
              "Sent $amount Diamonds to $name",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'SEND DIAMONDS',
          style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Recipient Information", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 4),
            const Text("Enter the unique ID of the customer.", style: TextStyle(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildInputField(
              controller: _helloIdController,
              label: "CUSTOMER HELLO ID",
              hint: "e.g. 1029384756",
              icon: Icons.person_search_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _amountController,
              label: "AMOUNT TO SEND",
              hint: "0",
              icon: Icons.diamond_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isTransferring ? null : _handleTransfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: _isTransferring
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("PROCEED TO TRANSFER", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.center,
              child: Text(
                "Diamonds are moved instantly upon confirmation.",
                style: TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black45, letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black12, fontWeight: FontWeight.bold),
            prefixIcon: Icon(icon, color: Colors.indigo, size: 20),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ],
    );
  }
}
