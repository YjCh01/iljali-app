import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/hiring/chat_room_leave_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('leave hides application for that user only', () async {
    const email = 'seeker@example.com';
    const appId = 'app_1';

    expect(
      await ChatRoomLeaveService.isLeft(
        applicationId: appId,
        userEmail: email,
      ),
      isFalse,
    );

    await ChatRoomLeaveService.leave(
      applicationId: appId,
      userEmail: email,
    );

    expect(
      await ChatRoomLeaveService.isLeft(
        applicationId: appId,
        userEmail: email,
      ),
      isTrue,
    );
    expect(
      await ChatRoomLeaveService.isLeft(
        applicationId: appId,
        userEmail: 'other@example.com',
      ),
      isFalse,
    );
  });

  test('filterVisible removes left rooms', () async {
    const email = 'corp@example.com';
    final items = [
      _StubRoom('app_a'),
      _StubRoom('app_b'),
    ];

    await ChatRoomLeaveService.leave(
      applicationId: 'app_a',
      userEmail: email,
    );

    final visible = await ChatRoomLeaveService.filterVisible(
      items: items,
      applicationIdOf: (r) => r.id,
      userEmail: email,
    );

    expect(visible.map((e) => e.id).toList(), ['app_b']);
  });
}

class _StubRoom {
  _StubRoom(this.id);
  final String id;
}
