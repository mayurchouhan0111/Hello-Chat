import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_avatar.dart';

class SuperAdminPortalScreen extends ConsumerStatefulWidget {
  const SuperAdminPortalScreen({super.key});

  @override
  ConsumerState<SuperAdminPortalScreen> createState() => _SuperAdminPortalScreenState();
}

class _SuperAdminPortalScreenState extends ConsumerState<SuperAdminPortalScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  Map<String, dynamic>? _searchedUserData;

  static const String webAdminUrl = 'https://hellochat-e8965.web.app';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchWebConsole() async {
    final uri = Uri.parse(webAdminUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _copyConsoleUrl();
      }
    } catch (_) {
      if (mounted) _copyConsoleUrl();
    }
  }

  void _copyConsoleUrl() {
    Clipboard.setData(const ClipboardData(text: webAdminUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Web Admin Console URL copied to clipboard ($webAdminUrl)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _searchUser(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchedUserData = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      QuerySnapshot<Map<String, dynamic>> snap;

      // Try numeric Hello ID first
      final numericId = int.tryParse(cleanQuery);
      if (numericId != null) {
        snap = await db
            .collection('users')
            .where('helloId', isEqualTo: numericId)
            .limit(1)
            .get();
      } else {
        // Try UID
        final docSnap = await db.collection('users').doc(cleanQuery).get();
        if (docSnap.exists) {
          final data = docSnap.data()!;
          data['uid'] = docSnap.id;
          setState(() {
            _searchedUserData = data;
            _isSearching = false;
          });
          return;
        }

        // Try username
        snap = await db
            .collection('users')
            .where('username', isEqualTo: cleanQuery)
            .limit(1)
            .get();
      }

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        data['uid'] = snap.docs.first.id;
        setState(() {
          _searchedUserData = data;
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchedUserData = {'_notFound': true};
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _searchedUserData = {'_error': e.toString()};
        _isSearching = false;
      });
    }
  }

  // ── Admin Hierarchy Appointment & Revocation ─────────────────
  Future<void> _appointAdmin(UserModel currentUser, String targetUid, String targetName) async {
    final branchId = currentUser.branchId ?? 'branch-prod-1';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A29),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF818CF8)),
            Gap(10),
            Text('Appoint Branch Admin', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to appoint $targetName as an Admin for Branch $branchId?\n\nThey will be empowered to supervise agencies and hosts under this branch.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm Appointment', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      try {
        await FirebaseFunctions.instance.httpsCallable('assignHierarchyRole').call({
          'targetUid': targetUid,
          'newRole': 'admin',
          'targetBranchId': branchId,
          'targetSuperAdminId': currentUser.uid,
        });
      } catch (fnErr) {
        debugPrint('[SUPER_ADMIN] Callable notice: $fnErr');
      }

      await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
        'role': 'admin',
        'branchId': branchId,
        'superAdminId': currentUser.uid,
        'tags': FieldValue.arrayUnion(['Admin']),
        'roleUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $targetName has been appointed as Admin for Branch $branchId'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          if (_searchedUserData != null && _searchedUserData!['uid'] == targetUid) {
            _searchedUserData!['role'] = 'admin';
            _searchedUserData!['branchId'] = branchId;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to appoint admin: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _revokeAdmin(UserModel currentUser, String targetUid, String targetName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A29),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            Gap(10),
            Text('Revoke Admin Role', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to revoke Admin privileges for $targetName? Their role will be reverted to Host.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Revoke Privileges', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      try {
        await FirebaseFunctions.instance.httpsCallable('assignHierarchyRole').call({
          'targetUid': targetUid,
          'newRole': 'host',
        });
      } catch (fnErr) {
        debugPrint('[SUPER_ADMIN] Callable notice: $fnErr');
      }

      await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
        'role': 'host',
        'tags': FieldValue.arrayRemove(['Admin']),
        'roleUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin privileges revoked for $targetName'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          if (_searchedUserData != null && _searchedUserData!['uid'] == targetUid) {
            _searchedUserData!['role'] = 'host';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _replaceAdmin(UserModel currentUser, String oldAdminUid, String oldAdminName, String newAdminUid, String newAdminName, String branchId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A29),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: Color(0xFFF59E0B)),
            Gap(10),
            Text('Confirm Admin Replacement', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to replace $oldAdminName with $newAdminName as Admin for Branch $branchId?\n\n$oldAdminName will be reverted to Host, and $newAdminName will be granted full Admin privileges.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm Replacement', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // Revoke old admin
      final oldRef = db.collection('users').doc(oldAdminUid);
      batch.update(oldRef, {
        'role': 'host',
        'tags': FieldValue.arrayRemove(['Admin']),
        'roleUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Appoint new admin
      final newRef = db.collection('users').doc(newAdminUid);
      batch.update(newRef, {
        'role': 'admin',
        'branchId': branchId,
        'superAdminId': currentUser.uid,
        'tags': FieldValue.arrayUnion(['Admin']),
        'roleUpdatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      try {
        await FirebaseFunctions.instance.httpsCallable('assignHierarchyRole').call({
          'targetUid': oldAdminUid,
          'newRole': 'host',
        });
        await FirebaseFunctions.instance.httpsCallable('assignHierarchyRole').call({
          'targetUid': newAdminUid,
          'newRole': 'admin',
          'targetBranchId': branchId,
          'targetSuperAdminId': currentUser.uid,
        });
      } catch (fnErr) {
        debugPrint('[SUPER_ADMIN] Callable notice: $fnErr');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $oldAdminName has been successfully replaced by $newAdminName as Admin'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to replace admin: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showReplaceAdminModal(BuildContext context, UserModel currentUser, String currentAdminUid, String currentAdminName, String branchId) {
    final queryController = TextEditingController();
    bool isSearchingUser = false;
    Map<String, dynamic>? foundUser;
    String? searchErr;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1422),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const Gap(16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFFF59E0B), size: 22),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Replace Branch Admin',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'Replacing: $currentAdminName (Branch $branchId)',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Gap(16),
                  Text(
                    'Search for a user to take over as Admin for Branch $branchId:',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const Gap(12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: queryController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Enter Hello ID, UID or Username',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF131A29),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                            ),
                          ),
                        ),
                      ),
                      const Gap(8),
                      ElevatedButton(
                        onPressed: isSearchingUser
                            ? null
                            : () async {
                                final q = queryController.text.trim();
                                if (q.isEmpty) return;
                                setModalState(() {
                                  isSearchingUser = true;
                                  foundUser = null;
                                  searchErr = null;
                                });
                                try {
                                  final db = FirebaseFirestore.instance;
                                  final numId = int.tryParse(q);
                                  DocumentSnapshot<Map<String, dynamic>>? targetDoc;
                                  if (numId != null) {
                                    final snap = await db.collection('users').where('helloId', isEqualTo: numId).limit(1).get();
                                    if (snap.docs.isNotEmpty) targetDoc = snap.docs.first;
                                  } else {
                                    final doc = await db.collection('users').doc(q).get();
                                    if (doc.exists) {
                                      targetDoc = doc;
                                    } else {
                                      final snap = await db.collection('users').where('username', isEqualTo: q).limit(1).get();
                                      if (snap.docs.isNotEmpty) targetDoc = snap.docs.first;
                                    }
                                  }
                                  if (targetDoc != null && targetDoc.exists) {
                                    final d = targetDoc.data()!;
                                    d['uid'] = targetDoc.id;
                                    if (targetDoc.id == currentAdminUid) {
                                      setModalState(() {
                                        searchErr = 'This user is already the current admin being replaced.';
                                        isSearchingUser = false;
                                      });
                                    } else {
                                      setModalState(() {
                                        foundUser = d;
                                        isSearchingUser = false;
                                      });
                                    }
                                  } else {
                                    setModalState(() {
                                      searchErr = 'No user found with "$q"';
                                      isSearchingUser = false;
                                    });
                                  }
                                } catch (e) {
                                  setModalState(() {
                                    searchErr = 'Search error: $e';
                                    isSearchingUser = false;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isSearchingUser
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : const Text('Search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  if (searchErr != null) ...[
                    const Gap(12),
                    Text(searchErr!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ],
                  if (foundUser != null) ...[
                    const Gap(16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131A29),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              AppAvatar(imageUrl: foundUser!['profilePhotoUrl'] ?? '', radius: 24),
                              const Gap(12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      foundUser!['displayName'] ?? foundUser!['username'] ?? 'User',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      'Hello ID: ${foundUser!['helloId'] ?? 'N/A'}',
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                    Text(
                                      'Current Role: ${(foundUser!['role'] ?? 'user').toString().toUpperCase()}',
                                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Gap(14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(modalCtx);
                                final newUid = foundUser!['uid'].toString();
                                final newName = foundUser!['displayName'] ?? foundUser!['username'] ?? 'New Admin';
                                _replaceAdmin(currentUser, currentAdminUid, currentAdminName, newUid, newName, branchId);
                              },
                              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                              label: const Text('Appoint as Replacement Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAdminPerformanceReport(BuildContext context, UserModel currentUser, Map<String, dynamic> adminData, String adminUid) {
    final name = adminData['displayName'] ?? adminData['username'] ?? 'Admin';
    final helloId = adminData['helloId']?.toString() ?? 'N/A';
    final photo = adminData['profilePhotoUrl'] ?? '';
    final branchId = adminData['branchId']?.toString() ?? 'branch-prod-1';
    final rawDate = adminData['roleUpdatedAt'] ?? adminData['createdAt'];
    DateTime appointedDate = DateTime.now();
    if (rawDate is Timestamp) appointedDate = rawDate.toDate();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1422),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (reportCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          expand: false,
          builder: (sheetCtx, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const Gap(16),
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.analytics_rounded, color: Color(0xFF818CF8), size: 22),
                      ),
                      const Gap(12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ADMIN PERFORMANCE REPORT',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                            Text(
                              'Performance & Activity Oversight',
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54),
                        onPressed: () => Navigator.pop(reportCtx),
                      ),
                    ],
                  ),
                  const Gap(16),
                  // Profile Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131A29),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6366F1).withValues(alpha: 0.1),
                          const Color(0xFF131A29),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            AppAvatar(imageUrl: photo, radius: 28),
                            const Gap(14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          name,
                                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Gap(8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                                      ),
                                    ],
                                  ),
                                  const Gap(4),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: helloId));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Admin ID $helloId copied'), behavior: SnackBarBehavior.floating),
                                      );
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Hello ID: $helloId', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                        const Gap(4),
                                        const Icon(Icons.copy_rounded, size: 12, color: Colors.white38),
                                      ],
                                    ),
                                  ),
                                  const Gap(2),
                                  Text('Branch: $branchId', style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Gap(12),
                        const Divider(color: Colors.white10, height: 1),
                        const Gap(12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                                Gap(6),
                                Text('Status: Active Admin', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Text(
                              'Appointed: ${appointedDate.year}-${appointedDate.month.toString().padLeft(2, '0')}-${appointedDate.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Gap(16),
                  const Text('KEY PERFORMANCE INDICATORS', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  const Gap(10),
                  // StreamBuilder for real-time counts of agencies supervised
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('agencies').where('branchId', isEqualTo: branchId).snapshots(),
                    builder: (context, agencySnap) {
                      final agencyCount = agencySnap.data?.docs.length ?? 0;
                      return Row(
                        children: [
                          Expanded(
                            child: _buildReportMetricTile(
                              icon: Icons.business_center_rounded,
                              iconColor: const Color(0xFFF59E0B),
                              label: 'Agencies Supervised',
                              value: '$agencyCount',
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: _buildReportMetricTile(
                              icon: Icons.star_rounded,
                              iconColor: const Color(0xFF10B981),
                              label: 'Admin Rating',
                              value: '5.0 ⭐',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const Gap(10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReportMetricTile(
                          icon: Icons.diamond_rounded,
                          iconColor: const Color(0xFF00E5FF),
                          label: 'Monthly Diamond Vol.',
                          value: '${((adminData['monthlyDiamondsSent'] ?? 0) / 1000).toStringAsFixed(1)}K',
                        ),
                      ),
                      const Gap(10),
                      Expanded(
                        child: _buildReportMetricTile(
                          icon: Icons.shield_rounded,
                          iconColor: const Color(0xFFA855F7),
                          label: 'Oversight Level',
                          value: 'Branch Lead',
                        ),
                      ),
                    ],
                  ),
                  const Gap(20),
                  const Text('SUPERVISORY RESPONSIBILITIES', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  const Gap(10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131A29),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Column(
                      children: [
                        _buildResponsibilityItem(Icons.verified_user_rounded, const Color(0xFF10B981), 'Agency Supervision', 'Monitors agency performance and target completion under branch $branchId.'),
                        const Divider(color: Colors.white10, height: 16),
                        _buildResponsibilityItem(Icons.payments_rounded, const Color(0xFF3B82F6), 'Commission & Turnover Oversight', 'Ensures accurate weekly & monthly distribution of host earnings.'),
                        const Divider(color: Colors.white10, height: 16),
                        _buildResponsibilityItem(Icons.gavel_rounded, const Color(0xFFEC4899), 'Disciplinary & Policy Enforcement', 'Enforces platform conduct rules and reviews moderation reports.'),
                      ],
                    ),
                  ),
                  const Gap(24),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(reportCtx);
                            _showReplaceAdminModal(context, currentUser, adminUid, name, branchId);
                          },
                          icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFFF59E0B)),
                          label: const Text('Replace Admin', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFF59E0B)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(reportCtx);
                            _revokeAdmin(currentUser, adminUid, name);
                          },
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
                          label: const Text('Revoke Role', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReportMetricTile({required IconData icon, required Color iconColor, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131A29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const Gap(8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          const Gap(2),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildResponsibilityItem(IconData icon, Color color, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const Gap(2),
              Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  void _showBranchAdminsManagementSheet(BuildContext context, UserModel currentUser, String branchId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1422),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (sheetCtx, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                  const Gap(16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF818CF8), size: 22),
                          ),
                          const Gap(12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'BRANCH ADMINS',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                              Text(
                                'Branch: $branchId',
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAppointAdminModal(context, currentUser, branchId);
                        },
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                        label: const Text('Appoint Admin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                  const Gap(16),
                  const Divider(color: Colors.white10, height: 1),
                  const Gap(12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: 'admin')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
                        }
                        final allDocs = snapshot.data?.docs ?? [];
                        final docs = allDocs.where((d) {
                          final data = d.data();
                          final bId = data['branchId']?.toString();
                          final sId = data['superAdminId']?.toString();
                          return bId == branchId || sId == currentUser.uid || currentUser.role == 'owner' || branchId == 'branch-prod-1';
                        }).toList();
                        if (docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.group_off_rounded, size: 48, color: Colors.white.withValues(alpha: 0.2)),
                                const Gap(12),
                                const Text(
                                  'No Admins Appointed Yet',
                                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const Gap(6),
                                Text(
                                  'Appoint an Admin under Branch $branchId supervision.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                                const Gap(14),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showAppointAdminModal(context, currentUser, branchId);
                                  },
                                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                                  label: const Text('Appoint Admin', style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: scrollController,
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Gap(10),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();
                            final name = data['displayName'] ?? data['username'] ?? 'Admin';
                            final helloId = data['helloId']?.toString() ?? 'N/A';
                            final photo = data['profilePhotoUrl'] ?? '';
                            final uid = doc.id;
                            final adminBranch = data['branchId']?.toString() ?? branchId;

                            return InkWell(
                              onTap: () => _showAdminPerformanceReport(context, currentUser, data, uid),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131A29),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                ),
                                child: Row(
                                  children: [
                                    AppAvatar(imageUrl: photo, radius: 22),
                                    const Gap(12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  name,
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const Gap(6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text('ADMIN', style: TextStyle(color: Color(0xFF818CF8), fontSize: 9, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                          const Gap(4),
                                          GestureDetector(
                                            onTap: () => _showAdminPerformanceReport(context, currentUser, data, uid),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.analytics_rounded, size: 11, color: Color(0xFF818CF8)),
                                                  const Gap(4),
                                                  Text('ID: $helloId', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                                  const Gap(4),
                                                  const Text('• View Report ›', style: TextStyle(color: Color(0xFF818CF8), fontSize: 9, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const Gap(2),
                                          Text('Branch: $adminBranch', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFFF59E0B), size: 20),
                                          tooltip: 'Replace Admin',
                                          onPressed: () => _showReplaceAdminModal(context, currentUser, uid, name, adminBranch),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20),
                                          tooltip: 'Revoke Admin Privileges',
                                          onPressed: () => _revokeAdmin(currentUser, uid, name),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
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

  void _showAppointAdminModal(BuildContext context, UserModel currentUser, String branchId) {
    final queryController = TextEditingController();
    bool isSearchingUser = false;
    Map<String, dynamic>? foundUser;
    String? searchErr;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1422),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const Gap(16),
                  const Row(
                    children: [
                      Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF818CF8), size: 22),
                      Gap(10),
                      Text(
                        'Appoint New Admin',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const Gap(6),
                  Text(
                    'Search a user by Hello ID, Username, or UID to assign them as Admin under Branch $branchId.',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const Gap(16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: queryController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Enter Hello ID, UID or Username',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF131A29),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF6366F1)),
                            ),
                          ),
                        ),
                      ),
                      const Gap(8),
                      ElevatedButton(
                        onPressed: isSearchingUser
                            ? null
                            : () async {
                                final q = queryController.text.trim();
                                if (q.isEmpty) return;
                                setModalState(() {
                                  isSearchingUser = true;
                                  foundUser = null;
                                  searchErr = null;
                                });
                                try {
                                  final db = FirebaseFirestore.instance;
                                  final numId = int.tryParse(q);
                                  DocumentSnapshot<Map<String, dynamic>>? targetDoc;
                                  if (numId != null) {
                                    final snap = await db.collection('users').where('helloId', isEqualTo: numId).limit(1).get();
                                    if (snap.docs.isNotEmpty) targetDoc = snap.docs.first;
                                  } else {
                                    final doc = await db.collection('users').doc(q).get();
                                    if (doc.exists) {
                                      targetDoc = doc;
                                    } else {
                                      final snap = await db.collection('users').where('username', isEqualTo: q).limit(1).get();
                                      if (snap.docs.isNotEmpty) targetDoc = snap.docs.first;
                                    }
                                  }
                                  if (targetDoc != null && targetDoc.exists) {
                                    final d = targetDoc.data()!;
                                    d['uid'] = targetDoc.id;
                                    setModalState(() {
                                      foundUser = d;
                                      isSearchingUser = false;
                                    });
                                  } else {
                                    setModalState(() {
                                      searchErr = 'No user found with "$q"';
                                      isSearchingUser = false;
                                    });
                                  }
                                } catch (e) {
                                  setModalState(() {
                                    searchErr = 'Search error: $e';
                                    isSearchingUser = false;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isSearchingUser
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  if (searchErr != null) ...[
                    const Gap(12),
                    Text(searchErr!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ],
                  if (foundUser != null) ...[
                    const Gap(16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131A29),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              AppAvatar(imageUrl: foundUser!['profilePhotoUrl'] ?? '', radius: 24),
                              const Gap(12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      foundUser!['displayName'] ?? foundUser!['username'] ?? 'User',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      'Hello ID: ${foundUser!['helloId'] ?? 'N/A'}',
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                    Text(
                                      'Current Role: ${(foundUser!['role'] ?? 'user').toString().toUpperCase()}',
                                      style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Gap(14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(modalCtx);
                                _appointAdmin(
                                  currentUser,
                                  foundUser!['uid'],
                                  foundUser!['displayName'] ?? foundUser!['username'] ?? 'User',
                                );
                              },
                              icon: const Icon(Icons.shield_rounded, size: 16),
                              label: const Text('Appoint as Branch Admin', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Gap(12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1422),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, color: Color(0xFF818CF8), size: 18),
            Gap(6),
            Text(
              'SUPER ADMIN PORTAL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded, color: Color(0xFF818CF8)),
            tooltip: 'Open Web Admin Console',
            onPressed: _launchWebConsole,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Refresh',
            onPressed: () => ref.refresh(currentUserProfileProvider),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
        error: (err, _) => Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text("Not authenticated", style: TextStyle(color: Colors.white70)));
          }

          final bool hasSuperAdminPrivilege = user.isSuperAdmin ||
              user.tags.contains('SuperAdmin') ||
              user.role == 'superadmin' ||
              user.isOwner ||
              user.role == 'owner';

          if (!hasSuperAdminPrivilege) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded, size: 64, color: Color(0xFFEF4444)),
                    const Gap(16),
                    const Text(
                      "Access Denied",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Gap(8),
                    Text(
                      "This portal requires the Super Admin role or tag.\nCurrent Role: ${user.role}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          final String branchId = user.branchId ?? 'branch-prod-1';
          final bool isApexOwner = user.isOwner || user.role == 'owner';

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(currentUserProfileProvider),
            color: const Color(0xFF6366F1),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildExecutiveProfileCard(user, branchId, isApexOwner),
                  const Gap(16),
                  _buildWebConsoleGatewayCard(),
                  const Gap(16),
                  _buildOperationalMetricsGrid(branchId, isApexOwner),
                  const Gap(16),
                  _buildQuickActionHub(context, user),
                  const Gap(16),
                  _buildUserLookupSection(user),
                  const Gap(16),
                  _buildPermissionsMatrix(isApexOwner),
                  const Gap(40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Executive Profile & Authority Card ─────────────────────
  Widget _buildExecutiveProfileCard(UserModel user, String branchId, bool isApexOwner) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.35), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x334338CA),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AppAvatar(
                imageUrl: user.profilePhotoUrl,
                frameUrl: user.profileFrame,
                radius: 28,
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Gap(6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isApexOwner
                                  ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                                  : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isApexOwner ? 'APEX OWNER' : 'SUPER ADMIN',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(4),
                    Text(
                      'ID: ${user.displayId}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Gap(6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Color(0xFF10B981), size: 7),
                              Gap(4),
                              Text(
                                "Active & Verified",
                                style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const Gap(8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "Branch: $branchId",
                            style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(14),
          const Divider(color: Colors.white12, height: 1),
          const Gap(12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAuthorityStat('Authority Scope', isApexOwner ? 'Global Platform' : 'Branch Sandboxed'),
              _buildAuthorityStat('Hierarchy Tier', isApexOwner ? 'Tier 4 (Apex)' : 'Tier 3 (Branch)'),
              _buildAuthorityStat('Security Level', 'High Security'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorityStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        const Gap(2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  // ── Web Admin Console Gateway Card (Testing System Entrypoint) ──
  Widget _buildWebConsoleGatewayCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF38BDF8), size: 20),
              ),
              const Gap(10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Full Web Admin Console",
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "29 Advanced Management Modules",
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "Online",
                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Gap(12),
          const Text(
            "Access comprehensive management for Users, Live Rooms, Gifts, SVIP Engine, Hierarchy & Branches, Financials, Moderation, and Audit Trail directly in browser.",
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const Gap(14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: _launchWebConsole,
                  icon: const Icon(Icons.launch_rounded, size: 16),
                  label: const Text(
                    "Launch Web Console",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const Gap(8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _copyConsoleUrl,
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text(
                    "Copy URL",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Operational Metrics Grid ──────────────────────────────
  Widget _buildOperationalMetricsGrid(String branchId, bool isApexOwner) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "OPERATIONAL SCOPE",
          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const Gap(10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                icon: Icons.supervised_user_circle_rounded,
                iconColor: const Color(0xFF6366F1),
                title: "Branch Staff",
                value: "Active",
                subtitle: isApexOwner ? "All Branches" : "Branch Sandboxed",
              ),
            ),
            const Gap(10),
            Expanded(
              child: _buildMetricTile(
                icon: Icons.business_center_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: "Agencies",
                value: "Supervised",
                subtitle: "Direct Oversight",
              ),
            ),
          ],
        ),
        const Gap(10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                icon: Icons.mic_rounded,
                iconColor: const Color(0xFF10B981),
                title: "Hosts & Talent",
                value: "Monitored",
                subtitle: "Salary & Metrics",
              ),
            ),
            const Gap(10),
            Expanded(
              child: _buildMetricTile(
                icon: Icons.payments_rounded,
                iconColor: const Color(0xFFEC4899),
                title: "Payout Reviews",
                value: "Enabled",
                subtitle: "SLA Workflow",
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131A29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor, size: 20),
              Text(value, style: TextStyle(color: iconColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const Gap(8),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const Gap(2),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  // ── Quick Action Hub ───────────────────────────────────────
  Widget _buildQuickActionHub(BuildContext context, UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "MANAGEMENT MODULES",
          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const Gap(10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131A29),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              _buildActionTile(
                icon: Icons.admin_panel_settings_rounded,
                iconColor: const Color(0xFF818CF8),
                title: "Appoint & Manage Branch Admins",
                subtitle: "Appoint admins to supervise agencies & manage staff",
                onTap: () => _showBranchAdminsManagementSheet(context, user, user.branchId ?? 'branch-prod-1'),
              ),
              const Divider(color: Colors.white10, height: 1, indent: 56),
              _buildActionTile(
                icon: Icons.business_center_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: "Agency Portal",
                subtitle: "Monitor recruited hosts, performance & targets",
                onTap: () => context.push(AppRoutes.agencyPortal),
              ),
              const Divider(color: Colors.white10, height: 1, indent: 56),
              _buildActionTile(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF10B981),
                title: "Commission Wallet",
                subtitle: "View real-time commission splits & ledgers",
                onTap: () => context.push(AppRoutes.commissionWallet),
              ),
              const Divider(color: Colors.white10, height: 1, indent: 56),
              _buildActionTile(
                icon: Icons.store_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: "Reseller Management Portal",
                subtitle: "Diamond stock, wholesale transfers & balance",
                onTap: () => context.push(AppRoutes.resellerCenter),
              ),
              const Divider(color: Colors.white10, height: 1, indent: 56),
              _buildActionTile(
                icon: Icons.workspace_premium_rounded,
                iconColor: const Color(0xFFA855F7),
                title: "SVIP Privileges Hub",
                subtitle: "60-day privileges, kick/mute protection & claim vault",
                onTap: () => context.push(AppRoutes.svipPrivileges),
              ),
              const Divider(color: Colors.white10, height: 1, indent: 56),
              _buildActionTile(
                icon: Icons.travel_explore_rounded,
                iconColor: const Color(0xFF06B6D4),
                title: "Live Rooms Oversight",
                subtitle: "Inspect active live rooms and monitor streams",
                onTap: () => context.push(AppRoutes.search),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 14),
      onTap: onTap,
    );
  }

  // ── User Lookup & Audit Tool ──────────────────────────────
  Widget _buildUserLookupSection(UserModel currentUser) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A29),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_search_rounded, color: Color(0xFF818CF8), size: 18),
              Gap(8),
              Text(
                "USER & STAFF INSPECTOR",
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
          const Gap(10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Enter Hello ID, UID or Username",
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF0F1422),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6366F1)),
                    ),
                  ),
                  onSubmitted: _searchUser,
                ),
              ),
              const Gap(8),
              ElevatedButton(
                onPressed: _isSearching ? null : () => _searchUser(_searchController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSearching
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Search", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (_searchedUserData != null) ...[
            const Gap(12),
            _buildSearchResultCard(currentUser),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(UserModel currentUser) {
    final data = _searchedUserData!;
    if (data.containsKey('_notFound')) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: const Text("No user found with the given query.", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
      );
    }
    if (data.containsKey('_error')) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text("Error: ${data['_error']}", style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
      );
    }

    final name = data['displayName'] ?? 'Unknown';
    final helloId = data['helloId'] ?? 'N/A';
    final role = data['role'] ?? 'user';
    final branch = data['branchId'] ?? 'None';
    final tags = (data['tags'] as List?)?.join(', ') ?? 'None';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1422),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(role.toString().toUpperCase(), style: const TextStyle(color: Color(0xFF818CF8), fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Gap(6),
          Text("Hello ID: $helloId | Branch: $branch", style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const Gap(2),
          Text("Tags: $tags", style: const TextStyle(color: Colors.white54, fontSize: 11)),
          if ((data['uid'] as String?)?.isNotEmpty == true) ...[
            const Gap(12),
            const Divider(color: Colors.white12, height: 1),
            const Gap(10),
            if (role == 'admin') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                      Gap(6),
                      Text('Active Branch Admin', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _revokeAdmin(currentUser, data['uid'] as String, name),
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 14),
                    label: const Text('Revoke Admin', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _appointAdmin(currentUser, data['uid'] as String, name),
                  icon: const Icon(Icons.shield_rounded, size: 15),
                  label: const Text('Appoint as Branch Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── Permissions Matrix ────────────────────────────────────
  Widget _buildPermissionsMatrix(bool isApexOwner) {
    final permissions = [
      {'name': 'Branch Sandboxing', 'desc': 'Strict data isolation per branch', 'enabled': true},
      {'name': 'Admin Creation & Oversight', 'desc': 'Manage branch middle managers', 'enabled': true},
      {'name': 'Agency Supervision', 'desc': 'Onboard and monitor operational agencies', 'enabled': true},
      {'name': 'Host Talent Monitoring', 'desc': 'Live performance and target tracking', 'enabled': true},
      {'name': 'Payout & Withdrawal Review', 'desc': 'Approve salaries per Owner rules', 'enabled': true},
      {
        'name': 'Company Financial Policies',
        'desc': isApexOwner ? 'Full Authority (Apex Owner)' : 'Locked to Platform Owner',
        'enabled': isApexOwner,
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A29),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 18),
              Gap(8),
              Text(
                "HB-PMS PERMISSIONS VERIFICATION",
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
          const Gap(12),
          ...permissions.map((p) {
            final isEnabled = p['enabled'] as bool;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    isEnabled ? Icons.check_circle_rounded : Icons.lock_rounded,
                    color: isEnabled ? const Color(0xFF10B981) : Colors.amber,
                    size: 16,
                  ),
                  const Gap(10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['name'] as String,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          p['desc'] as String,
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    isEnabled ? "ACTIVE" : "OWNER",
                    style: TextStyle(
                      color: isEnabled ? const Color(0xFF10B981) : Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
