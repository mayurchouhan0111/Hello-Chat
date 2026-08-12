import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/models/svip_level_model.dart';
import '../../../../core/providers/profile_provider.dart';

class CPLockDialog extends ConsumerStatefulWidget {
  final String cpId;
  final String targetUid;
  final bool isLocked;

  const CPLockDialog({
    super.key,
    required this.cpId,
    required this.targetUid,
    this.isLocked = false,
  });

  static void show(BuildContext context, {required String cpId, required String targetUid, bool isLocked = false}) {
    showDialog(
      context: context,
      builder: (context) => CPLockDialog(cpId: cpId, targetUid: targetUid, isLocked: isLocked),
    );
  }

  @override
  ConsumerState<CPLockDialog> createState() => _CPLockDialogState();
}

class _CPLockDialogState extends ConsumerState<CPLockDialog> {
  String _selectedDuration = '24 Hours';
  bool _isSubmitting = false;

  Future<void> _lockCp(int svipLevel) async {
    final levelModel = SVIPLevelModel.getLevelByTier(svipLevel);
    final options = levelModel.cpLockOptions;

    if (!options.contains(_selectedDuration)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Your SVIP level does not support $_selectedDuration lock.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('lockCp');
      final res = await callable.call({
        'cpId': widget.cpId,
        'lockDuration': _selectedDuration,
      });

      if (res.data != null && res.data['success'] == true) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔒 CP Relationship locked for $_selectedDuration!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception:', '').trim()), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _requestSvip6Remove() async {
    setState(() => _isSubmitting = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('requestSvip6CpRemove');
      final res = await callable.call({
        'cpId': widget.cpId,
        'targetUid': widget.targetUid,
      });

      if (res.data != null && res.data['success'] == true) {
        final remaining = res.data['remainingAllowance'];
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Removal request sent to CP partner! ($remaining requests left)'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception:', '').trim()), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return AlertDialog(
      backgroundColor: const Color(0xFF18181B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(Icons.lock_clock_rounded, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          Text(
            widget.isLocked ? 'Locked CP Options' : 'CP Lock System',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: userAsync.when(
        loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: Colors.amber))),
        error: (err, _) => Text('Error: $err', style: const TextStyle(color: Colors.white)),
        data: (user) {
          final svipLevel = user?.svipLevel ?? 0;
          final levelModel = SVIPLevelModel.getLevelByTier(svipLevel);
          final options = levelModel.cpLockOptions;

          if (svipLevel < 3) {
            return const Text(
              'CP Lock system is available exclusively for SVIP 3 and above members.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            );
          }

          if (widget.isLocked) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This CP relationship is currently locked. The "Break CP" option is hidden for both partners.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (svipLevel == 6) ...[
                  const Text(
                    'As an SVIP 6 member, you can send a removal request to your CP partner (Max 5 requests per cycle).',
                    style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ] else ...[
                  const Text(
                    'Only the Admin Panel can force unlock or break this CP relationship before expiration.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select CP Lock Duration:',
                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((opt) {
                  final isSelected = _selectedDuration == opt;
                  return ChoiceChip(
                    label: Text(opt, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                    selected: isSelected,
                    selectedColor: Colors.amber,
                    backgroundColor: Colors.white10,
                    onSelected: (val) => setState(() => _selectedDuration = opt),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
        ),
        userAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (user) {
            final svipLevel = user?.svipLevel ?? 0;
            if (widget.isLocked && svipLevel == 6) {
              return ElevatedButton(
                onPressed: _isSubmitting ? null : _requestSvip6Remove,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white),
                child: const Text('REQUEST CP REMOVAL', style: TextStyle(fontWeight: FontWeight.bold)),
              );
            } else if (!widget.isLocked && svipLevel >= 3) {
              return ElevatedButton(
                onPressed: _isSubmitting ? null : () => _lockCp(svipLevel),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                child: const Text('APPLY LOCK', style: TextStyle(fontWeight: FontWeight.bold)),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
