import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/user_model.dart';

void main() {
  test('UserModel fromMap defaults a missing role to user', () {
    final user = UserModel.fromMap({
      'uid': 'user-1',
      'displayName': 'Plain User',
    });

    expect(user.role, 'user');
  });

  test('UserModel constructor defaults a missing role to user', () {
    final now = DateTime.now();
    final user = UserModel(
      uid: 'user-2',
      createdAt: now,
      phoneNumber: null,
      username: 'plain',
      displayName: 'Plain User',
      lastActive: now,
    );

    expect(user.role, 'user');
  });
}
