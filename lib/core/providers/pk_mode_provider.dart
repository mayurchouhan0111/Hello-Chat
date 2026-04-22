import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the selected PK mode in the matching bottom sheet.
///
/// The possible values are:
/// - 'ROOM PK'
/// - 'Guest Arena' (coming soon)
/// - 'Team PK' (coming soon)
///
/// The default mode is 'ROOM PK'.
final pkModeProvider = StateProvider<String>((ref) => 'ROOM PK');
