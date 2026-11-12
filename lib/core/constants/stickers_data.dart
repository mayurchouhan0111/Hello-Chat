class StickerPack {
  final String id;
  final String title;
  final List<String> stickers;

  const StickerPack({
    required this.id,
    required this.title,
    required this.stickers,
  });
}

class StickersData {
  // 5 Professional Sticker & 3D Emoji Packs for Hello Chat
  static const List<StickerPack> activePacks = [
    StickerPack(
      id: 'pack_emoji',
      title: '😎 Emoji',
      stickers: fluentEmojiPack,
    ),
    StickerPack(
      id: 'pack_mascot',
      title: '🥰 Mascots',
      stickers: partyMascotPack,
    ),
    StickerPack(
      id: 'pack_audio',
      title: '🎙️ Audio Party',
      stickers: audioPartyPack,
    ),
    StickerPack(
      id: 'pack_cuppy',
      title: '☕ Cuppy',
      stickers: cuppyPack,
    ),
    StickerPack(
      id: 'pack_chibi',
      title: '✨ Chibi',
      stickers: chibiPack,
    ),
  ];

  // Pack 0: Open-source Fluent 3D Expressive Emojis (matching ref mock)
  static const List<String> fluentEmojiPack = [
    'assets/stickers/emojis/01_grinning_face.png',
    'assets/stickers/emojis/02_relieved_face.png',
    'assets/stickers/emojis/03_winking_face.png',
    'assets/stickers/emojis/04_sunglasses.png',
    'assets/stickers/emojis/05_hugging_face.png',
    'assets/stickers/emojis/06_star_struck.png',
    'assets/stickers/emojis/07_heart_eyes.png',
    'assets/stickers/emojis/08_blowing_kiss.png',
    'assets/stickers/emojis/09_kissing_closed_eyes.png',
    'assets/stickers/emojis/10_red_heart.png',
    'assets/stickers/emojis/11_smirking_face.png',
    'assets/stickers/emojis/12_astonished_face.png',
    'assets/stickers/emojis/13_dizzy_face.png',
    'assets/stickers/emojis/14_flushed_face.png',
    'assets/stickers/emojis/15_anxious_sweat.png',
    'assets/stickers/emojis/16_screaming_fear.png',
    'assets/stickers/emojis/17_rofl.png',
    'assets/stickers/emojis/18_tears_of_joy.png',
    'assets/stickers/emojis/19_partying_face.png',
    'assets/stickers/emojis/20_zany_face.png',
    'assets/stickers/emojis/21_pouting_face.png',
    'assets/stickers/emojis/22_loudly_crying.png',
    'assets/stickers/emojis/23_fire.png',
    'assets/stickers/emojis/24_sparkles.png',
  ];

  // Pack 1: Audio & Party Vibes (Microphones, DJ, Instruments, Fireworks, Applause)
  static const List<String> audioPartyPack = [
    'assets/stickers/audio_party/audio_01_microphone_3d.png',
    'assets/stickers/audio_party/audio_02_studio_microphone_3d.png',
    'assets/stickers/audio_party/audio_03_headphone_3d.png',
    'assets/stickers/audio_party/audio_04_guitar_3d.png',
    'assets/stickers/audio_party/audio_05_saxophone_3d.png',
    'assets/stickers/audio_party/audio_06_violin_3d.png',
    'assets/stickers/audio_party/audio_07_drum_3d.png',
    'assets/stickers/audio_party/audio_08_radio_3d.png',
    'assets/stickers/audio_party/audio_09_musical_score_3d.png',
    'assets/stickers/audio_party/audio_10_speaker_high_volume_3d.png',
    'assets/stickers/audio_party/audio_11_megaphone_3d.png',
    'assets/stickers/audio_party/audio_12_party_popper_3d.png',
    'assets/stickers/audio_party/audio_13_partying_face_3d.png',
    'assets/stickers/audio_party/audio_14_clinking_glasses_3d.png',
    'assets/stickers/audio_party/audio_15_fire_3d.png',
    'assets/stickers/audio_party/audio_16_clapping_hands_3d_default.png',
    'assets/stickers/audio_party/audio_17_sign_of_the_horns_3d_default.png',
    'assets/stickers/audio_party/audio_18_love-you_gesture_3d_default.png',
    'assets/stickers/audio_party/audio_19_raising_hands_3d_default.png',
    'assets/stickers/audio_party/audio_20_victory_hand_3d_default.png',
    'assets/stickers/audio_party/audio_21_crown_3d.png',
    'assets/stickers/audio_party/audio_22_trophy_3d.png',
    'assets/stickers/audio_party/audio_23_gem_stone_3d.png',
    'assets/stickers/audio_party/audio_24_rocket_3d.png',
  ];

  // Pack 2: 3D Expressive Party Mascots (Cats, Pandas, Party Animals)
  static const List<String> partyMascotPack = [
    'assets/stickers/party_mascots/mascot_01_cat_with_tears_of_joy_3d.png',
    'assets/stickers/party_mascots/mascot_02_smiling_cat_with_heart-eyes_3d.png',
    'assets/stickers/party_mascots/mascot_03_grinning_cat_with_smiling_eyes_3d.png',
    'assets/stickers/party_mascots/mascot_04_kissing_cat_3d.png',
    'assets/stickers/party_mascots/mascot_05_weary_cat_3d.png',
    'assets/stickers/party_mascots/mascot_06_panda_3d.png',
    'assets/stickers/party_mascots/mascot_07_bear_3d.png',
    'assets/stickers/party_mascots/mascot_08_dog_face_3d.png',
    'assets/stickers/party_mascots/mascot_09_lion_3d.png',
    'assets/stickers/party_mascots/mascot_10_fox_3d.png',
    'assets/stickers/party_mascots/mascot_11_unicorn_3d.png',
    'assets/stickers/party_mascots/mascot_12_rabbit_face_3d.png',
    'assets/stickers/party_mascots/mascot_13_monkey_face_3d.png',
    'assets/stickers/party_mascots/mascot_14_hear-no-evil_monkey_3d.png',
    'assets/stickers/party_mascots/mascot_15_see-no-evil_monkey_3d.png',
    'assets/stickers/party_mascots/mascot_16_speak-no-evil_monkey_3d.png',
    'assets/stickers/party_mascots/mascot_17_hundred_points_3d.png',
    'assets/stickers/party_mascots/mascot_18_heart_on_fire_3d.png',
    'assets/stickers/party_mascots/mascot_19_sparkles_3d.png',
    'assets/stickers/party_mascots/mascot_20_star-struck_3d.png',
    'assets/stickers/party_mascots/mascot_21_rolling_on_the_floor_laughing_3d.png',
    'assets/stickers/party_mascots/mascot_22_smiling_face_with_sunglasses_3d.png',
    'assets/stickers/party_mascots/mascot_23_zany_face_3d.png',
    'assets/stickers/party_mascots/mascot_24_glowing_star_3d.png',
  ];

  // Pack 3: Cuppy Emotions
  static const List<String> cuppyPack = [
    'assets/stickers/cuppy/01_cuppy_smile.webp',
    'assets/stickers/cuppy/02_cuppy_lol.webp',
    'assets/stickers/cuppy/03_cuppy_rofl.webp',
    'assets/stickers/cuppy/04_cuppy_sad.webp',
    'assets/stickers/cuppy/05_cuppy_cry.webp',
    'assets/stickers/cuppy/06_cuppy_love.webp',
    'assets/stickers/cuppy/07_cuppy_hate.webp',
    'assets/stickers/cuppy/08_cuppy_lovewithmug.webp',
    'assets/stickers/cuppy/09_cuppy_lovewithcookie.webp',
    'assets/stickers/cuppy/10_cuppy_hmm.webp',
    'assets/stickers/cuppy/11_cuppy_upset.webp',
    'assets/stickers/cuppy/12_cuppy_angry.webp',
    'assets/stickers/cuppy/13_cuppy_curious.webp',
    'assets/stickers/cuppy/14_cuppy_weird.webp',
    'assets/stickers/cuppy/15_cuppy_bluescreen.webp',
    'assets/stickers/cuppy/16_cuppy_angry.webp',
    'assets/stickers/cuppy/17_cuppy_tired.webp',
    'assets/stickers/cuppy/18_cuppy_workhard.webp',
    'assets/stickers/cuppy/19_cuppy_shine.webp',
    'assets/stickers/cuppy/20_cuppy_disgusting.webp',
    'assets/stickers/cuppy/21_cuppy_hi.webp',
    'assets/stickers/cuppy/22_cuppy_bye.webp',
    'assets/stickers/cuppy/23_cuppy_greentea.webp',
    'assets/stickers/cuppy/24_cuppy_phone.webp',
    'assets/stickers/cuppy/25_cuppy_battery.webp',
  ];

  // Pack 4: Telegram Chibi Emotes
  static const List<String> chibiPack = [
    'assets/stickers/chibi_emotes/sticker_01.png',
    'assets/stickers/chibi_emotes/sticker_02.png',
    'assets/stickers/chibi_emotes/sticker_03.png',
    'assets/stickers/chibi_emotes/sticker_04.png',
    'assets/stickers/chibi_emotes/sticker_05.png',
    'assets/stickers/chibi_emotes/sticker_06.png',
    'assets/stickers/chibi_emotes/sticker_07.png',
    'assets/stickers/chibi_emotes/sticker_08.png',
    'assets/stickers/chibi_emotes/sticker_09.png',
    'assets/stickers/chibi_emotes/sticker_10.png',
    'assets/stickers/chibi_emotes/sticker_11.png',
    'assets/stickers/chibi_emotes/sticker_12.png',
    'assets/stickers/chibi_emotes/sticker_13.png',
    'assets/stickers/chibi_emotes/sticker_14.png',
    'assets/stickers/chibi_emotes/sticker_15.png',
    'assets/stickers/chibi_emotes/sticker_16.png',
    'assets/stickers/chibi_emotes/sticker_17.png',
    'assets/stickers/chibi_emotes/sticker_18.png',
    'assets/stickers/chibi_emotes/sticker_19.png',
    'assets/stickers/chibi_emotes/sticker_20.png',
    'assets/stickers/chibi_emotes/sticker_21.png',
    'assets/stickers/chibi_emotes/sticker_22.png',
    'assets/stickers/chibi_emotes/sticker_23.png',
    'assets/stickers/chibi_emotes/sticker_24.png',
  ];
}
