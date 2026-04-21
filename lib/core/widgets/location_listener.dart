import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/services/location_service.dart';

class LocationListener extends ConsumerStatefulWidget {
  final Widget child;
  const LocationListener({super.key, required this.child});

  @override
  ConsumerState<LocationListener> createState() => _LocationListenerState();
}

class _LocationListenerState extends ConsumerState<LocationListener> {
  bool _hasUpdated = false;

  @override
  Widget build(BuildContext context) {
    // Watch current user profile
    final profileAsync = ref.watch(currentUserProfileProvider);

    profileAsync.whenData((user) {
      if (user != null && !_hasUpdated) {
        _updateLocation(user.uid);
      }
    });

    return widget.child;
  }

  Future<void> _updateLocation(String uid) async {
    _hasUpdated = true; // Prevent multiple updates in one session
    try {
      final country = await ref.read(locationServiceProvider).getCurrentCountry();
      if (country != null) {
        await ref.read(profileServiceProvider).updateUserLocation(uid, country);
        debugPrint('Updated user location to: $country');
      }
    } catch (e) {
      debugPrint('Failed to update location: $e');
    }
  }
}
