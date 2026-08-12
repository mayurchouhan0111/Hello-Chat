import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/models/svip_level_model.dart';
import '../../../../core/providers/profile_provider.dart';

class TempIdTargetSheet extends ConsumerStatefulWidget {
  const TempIdTargetSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const TempIdTargetSheet(),
    );
  }

  @override
  ConsumerState<TempIdTargetSheet> createState() => _TempIdTargetSheetState();
}

class _TempIdTargetSheetState extends ConsumerState<TempIdTargetSheet> {
  final _idController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest(int svipLevel) async {
    final targetIdStr = _idController.text.trim();
    if (targetIdStr.isEmpty) return;

    final targetId = int.tryParse(targetIdStr);
    if (targetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid numeric Hello ID.')),
      );
      return;
    }

    final levelModel = SVIPLevelModel.getLevelByTier(svipLevel);
    final limits = levelModel.tempIdLimits;
    final len = targetIdStr.length;

    // Validate digit category
    if (len == 10 && (limits['limit10Digit'] ?? 0) <= 0) {
      _showError('Your SVIP level does not allow 10-digit ID targets.');
      return;
    } else if (len == 8 && (limits['limit8Digit'] ?? 0) <= 0) {
      _showError('Your SVIP level does not allow 8-digit ID targets.');
      return;
    } else if (len == 6 && (limits['limit6Digit'] ?? 0) <= 0) {
      _showError('Your SVIP level does not allow 6-digit ID targets.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('requestTempIdSwap');
      final res = await callable.call({'targetHelloId': targetId});
      if (res.data != null && res.data['success'] == true) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Temporary ID swap request sent! Awaiting target user approval.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF141416),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.amber)),
          error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
          data: (user) {
            final svipLevel = user?.svipLevel ?? 0;
            final levelModel = SVIPLevelModel.getLevelByTier(svipLevel);
            final limits = levelModel.tempIdLimits;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.swap_horiz_rounded, color: Colors.amber, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Temporary ID Swap',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Text(
                        'SVIP $svipLevel',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Allowed Digit Limits for SVIP $svipLevel:',
                  style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildChip('10-Digit: ${limits['limit10Digit']}'),
                    const SizedBox(width: 8),
                    _buildChip('8-Digit: ${limits['limit8Digit']}'),
                    const SizedBox(width: 8),
                    _buildChip('6-Digit: ${limits['limit6Digit']}'),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _idController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Enter Target User Hello ID...',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                    filled: true,
                    fillColor: Colors.black45,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.amber),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : () => _submitRequest(svipLevel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text(
                            'SEND SWAP REQUEST',
                            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white54.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
