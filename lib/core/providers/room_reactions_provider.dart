import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/emoji_reaction.dart';

final emojiReactionsProvider = StateProvider<Map<String, EmojiReaction>>((ref) => {});
