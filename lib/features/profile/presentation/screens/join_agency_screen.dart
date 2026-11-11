import 'dart:async';
import 'package:hello_chat/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';

class JoinAgencyScreen extends ConsumerStatefulWidget {
  const JoinAgencyScreen({super.key});

  @override
  ConsumerState<JoinAgencyScreen> createState() => _JoinAgencyScreenState();
}

class _JoinAgencyScreenState extends ConsumerState<JoinAgencyScreen> {
  final TextEditingController _idController = TextEditingController();
  bool _isSearching = false;
  bool _isApplying = false;
  Map<String, dynamic>? _foundAgency;
  String? _searchError;

  // Mint green brand colors from screenshot
  static const Color _mintGreen = Color(0xFF7DE2A0);
  static const Color _darkTeal = Color(0xFF042A27);
  static const Color _bgPineDark = Color(0xFF012020);
  static const Color _cardPine = Color(0xFF063534);
  static const Color _borderPine = Color(0xFF0B4C4A);

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _searchAgency() async {
    final query = _idController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text('Please enter Agency ID to search')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
      _foundAgency = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('searchAgencyForJoin');
      final result = await callable.call({'query': query});
      final data = result.data as Map<dynamic, dynamic>?;

      if (data != null && data['found'] == true && data['agency'] != null) {
        setState(() {
          _foundAgency = Map<String, dynamic>.from(data['agency']);
        });
      } else {
        setState(() {
          _searchError = data?['message']?.toString() ?? 'No active agency found with ID "$query".';
        });
      }
    } catch (e) {
      setState(() {
        _searchError = 'Search failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _applyToJoin(String agencyId, String agencyName) async {
    setState(() {
      _isApplying = true;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('applyToJoinAgency');
      final result = await callable.call({'agencyId': agencyId});
      final data = result.data as Map<dynamic, dynamic>?;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, 
            backgroundColor: const Color(0xFF065F46),
            content: Text(
              data?['message']?.toString() ??
                  'Application to join "$agencyName" submitted successfully! Results will be issued within 24 hours.',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
        setState(() {
          _foundAgency = null;
          _idController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, 
            backgroundColor: Colors.red.shade800,
            content: Text('Failed to submit application: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  void _showApplicationRecords() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bgPineDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _ApplicationRecordsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPineDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Join Agency',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Search Box matching Image 4
              Container(
                height: 52,
                padding: const EdgeInsets.only(left: 14, right: 6),
                decoration: BoxDecoration(
                  color: _cardPine,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderPine, width: 1.2),
                ),
                child: Row(
                  children: [
                    const Text(
                      'ID:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Gap(10),
                    Expanded(
                      child: TextField(
                        controller: _idController,
                        style: const TextStyle(color: Colors.white, fontSize: 14.5),
                        cursorColor: _mintGreen,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searchAgency(),
                        decoration: const InputDecoration(
                          hintText: 'Enter Agency ID',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13.5),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const Gap(6),
                    SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        onPressed: _isSearching ? null : _searchAgency,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _mintGreen,
                          foregroundColor: _darkTeal,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isSearching
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(_darkTeal),
                                ),
                              )
                            : const Text(
                                'Search',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _darkTeal,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const Gap(12),

              // 2. Note text under search bar
              const Text(
                'The application result will be issued within 24 hours after sending the application',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),

              const Gap(24),

              // 3. Search Result Agency Card (if found)
              if (_foundAgency != null) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _cardPine,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _mintGreen.withValues(alpha: 0.4), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _foundAgency!['logoUrl'] != null &&
                                    _foundAgency!['logoUrl'].toString().isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: _foundAgency!['logoUrl'].toString(),
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.business_rounded,
                                      color: _mintGreen,
                                      size: 32,
                                    ),
                                  )
                                : const Icon(
                                    Icons.business_rounded,
                                    color: _mintGreen,
                                    size: 32,
                                  ),
                          ),
                          const Gap(14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _foundAgency!['name']?.toString() ?? 'Agency',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Gap(4),
                                Text(
                                  'Agency ID: ${_foundAgency!['agencyId']}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const Gap(2),
                                Text(
                                  'Owner: ${_foundAgency!['ownerName'] ?? 'Owner'}',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_foundAgency!['description'] != null &&
                          _foundAgency!['description'].toString().isNotEmpty) ...[
                        const Gap(12),
                        Text(
                          _foundAgency!['description'].toString(),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const Gap(16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _isApplying
                              ? null
                              : () => _applyToJoin(
                                    _foundAgency!['agencyId'].toString(),
                                    _foundAgency!['name']?.toString() ?? 'Agency',
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _mintGreen,
                            foregroundColor: _darkTeal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: _isApplying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(_darkTeal),
                                  ),
                                )
                              : const Text(
                                  'Apply to Join Agency',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: _darkTeal,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_searchError != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 22),
                      const Gap(10),
                      Expanded(
                        child: Text(
                          _searchError!,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // 4. "Application Record" pill button pinned at bottom
              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 220,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _showApplicationRecords,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mintGreen,
                      foregroundColor: _darkTeal,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Application Record',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _darkTeal,
                      ),
                    ),
                  ),
                ),
              ),

              const Gap(16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet displaying the user's submitted agency join applications
class _ApplicationRecordsSheet extends StatefulWidget {
  const _ApplicationRecordsSheet();

  @override
  State<_ApplicationRecordsSheet> createState() => _ApplicationRecordsSheetState();
}

class _ApplicationRecordsSheetState extends State<_ApplicationRecordsSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _applications = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getMyJoinApplications');
      final result = await callable.call();
      final data = result.data as Map<dynamic, dynamic>?;
      if (data != null && data['applications'] is List) {
        setState(() {
          _applications = (data['applications'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(16),
          const Text(
            'Application Records',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(6),
          const Text(
            'Results are issued within 24 hours of application submission.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const Gap(16),
          if (_loading) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: CircularProgressIndicator(color: Color(0xFF7DE2A0)),
              ),
            ),
          ] else if (_error != null) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Failed to load: $_error', style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
          ] else if (_applications.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Text(
                  'No applications found.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ),
          ] else ...[
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _applications.length,
                separatorBuilder: (_, __) => const Gap(10),
                itemBuilder: (context, idx) {
                  final app = _applications[idx];
                  final status = app['status']?.toString() ?? 'pending';
                  final agencyName = app['agencyName']?.toString() ?? 'Agency';
                  final agencyLogo = app['agencyLogo']?.toString() ?? '';
                  final remainingMs = (app['remainingMs'] as num?)?.toInt() ?? 0;
                  final hoursLeft = (remainingMs / (1000 * 60 * 60)).clamp(0, 24).toStringAsFixed(1);

                  Color badgeColor = Colors.amber;
                  String statusLabel = 'Pending ($hoursLeft h left)';
                  if (status == 'accepted') {
                    badgeColor = const Color(0xFF7DE2A0);
                    statusLabel = 'Accepted';
                  } else if (status == 'rejected') {
                    badgeColor = Colors.redAccent;
                    statusLabel = 'Rejected';
                  } else if (status == 'expired') {
                    badgeColor = Colors.grey;
                    statusLabel = 'Expired (24h passed)';
                  }

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF063534),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF0B4C4A)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: agencyLogo.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: agencyLogo,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(
                                    Icons.business_rounded,
                                    color: Color(0xFF7DE2A0),
                                  ),
                                )
                              : const Icon(
                                  Icons.business_rounded,
                                  color: Color(0xFF7DE2A0),
                                ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                agencyName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const Gap(3),
                              Text(
                                'Agency ID: ${app['agencyId']}',
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
