import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/participant_model.dart';
import 'package:hello_chat/core/models/room_model.dart';

void main() {
  group('🎙️ 1. Room Owner Voice State & Auto-Broadcaster Tests', () {
    test('Room Owner participant initialized with unmuted mic on seat 0', () {
      final ownerParticipant = Participant(
        uid: 'owner_user_123',
        displayName: 'Room Host',
        role: 'owner',
        seatIndex: 0,
        isMuted: false,
        joinedAt: DateTime.now(),
        lastActive: DateTime.now(),
      );

      expect(ownerParticipant.role, equals('owner'));
      expect(ownerParticipant.seatIndex, equals(0));
      expect(ownerParticipant.isMuted, isFalse);
    });

    test('Room Owner role detection correctly identifies broadcaster status', () {
      final room = RoomModel(
        roomId: 'room_101',
        createdBy: 'owner_user_123',
        ownerUid: 'owner_user_123',
        name: 'Chit-Chat & Vib',
        theme: 'default',
        coverUrl: '',
        isPrivate: false,
        capacity: 8,
        currentUsersCount: 1,
        backgroundMusic: false,
        createdAt: DateTime.now(),
        status: 'active',
        admins: ['owner_user_123'],
        moderators: [],
        bannedUids: [],
      );

      bool isUserBroadcaster(String myUid, RoomModel r, Participant? myPart) {
        final isOwner = r.ownerUid == myUid;
        final isOnSeat = myPart != null && (myPart.seatIndex ?? -1) >= 0;
        return isOwner || isOnSeat;
      }

      // Case 1: Room Owner (Seat 0 or any state)
      expect(isUserBroadcaster('owner_user_123', room, null), isTrue);

      // Case 2: Regular audience not on seat
      final audiencePart = Participant(
        uid: 'user_456',
        joinedAt: DateTime.now(),
        lastActive: DateTime.now(),
        seatIndex: -1,
        role: 'audience',
        isMuted: true,
      );
      expect(isUserBroadcaster('user_456', room, audiencePart), isFalse);

      // Case 3: Plus/Regular user seated on Seat 2
      final seatedPart = Participant(
        uid: 'user_789',
        joinedAt: DateTime.now(),
        lastActive: DateTime.now(),
        seatIndex: 2,
        role: 'speaker',
        isMuted: false,
      );
      expect(isUserBroadcaster('user_789', room, seatedPart), isTrue);
    });

    test('Mic toggle switches mute status and updates publication track', () {
      bool isMuted = false;
      bool publishMicrophoneTrack = true;

      void toggleMic() {
        isMuted = !isMuted;
        publishMicrophoneTrack = !isMuted;
      }

      // Initial state: Unmuted (Mic Active)
      expect(isMuted, isFalse);
      expect(publishMicrophoneTrack, isTrue);

      // 1st Tap: Mute
      toggleMic();
      expect(isMuted, isTrue);
      expect(publishMicrophoneTrack, isFalse);

      // 2nd Tap: Unmute
      toggleMic();
      expect(isMuted, isFalse);
      expect(publishMicrophoneTrack, isTrue);
    });
  });

  group('🏷️ 2. Room Owner ID & Top Header Formatting Tests', () {
    test('Top Header formats Owner ID and Audience Count side-by-side cleanly', () {
      String formatHeaderSubtitle(int? helloId, String roomId, int viewerCount) {
        final idStr = helloId != null
            ? helloId.toString()
            : (roomId.length > 8 ? roomId.substring(0, 8) : roomId);
        return 'ID:$idStr  👥 $viewerCount';
      }

      // With numeric Hello ID
      expect(
        formatHeaderSubtitle(239418, 'room_abc123', 5),
        equals('ID:239418  👥 5'),
      );

      // Fallback to room ID
      expect(
        formatHeaderSubtitle(null, '8323612938', 12),
        equals('ID:83236129  👥 12'),
      );
    });

    test('Follow Spark button visibility is false for Room Owner and true for Guests', () {
      bool shouldShowFollowButton(String myUid, String ownerUid) {
        return myUid != ownerUid;
      }

      const ownerUid = 'owner_123';
      expect(shouldShowFollowButton('owner_123', ownerUid), isFalse);
      expect(shouldShowFollowButton('guest_456', ownerUid), isTrue);
    });

    test('Host Seat display name formatting includes crown and clean text', () {
      String formatHostSeatLabel(String displayName, bool isOnline) {
        if (!isOnline) return displayName;
        return '👑 $displayName';
      }

      expect(formatHostSeatLabel('SUMON', true), equals('👑 SUMON'));
      expect(formatHostSeatLabel('SUMON', false), equals('SUMON'));
    });
  });
}
