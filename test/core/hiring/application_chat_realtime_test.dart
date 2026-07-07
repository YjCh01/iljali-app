import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/hiring/application_chat_realtime_client.dart';

void main() {
  test('wsUrlFor converts http(s) to ws(s)', () {
    expect(
      ApplicationChatRealtimeClient.wsUrlFor(
        httpBaseUrl: 'https://api.iljari.app',
        applicationId: 'app_abc123',
        senderRole: 'seeker',
      ),
      'wss://api.iljari.app/v1/chat-sync/ws/app_abc123?role=seeker',
    );
    expect(
      ApplicationChatRealtimeClient.wsUrlFor(
        httpBaseUrl: 'http://localhost:8000/',
        applicationId: 'app_x',
        senderRole: 'employer',
      ),
      'ws://localhost:8000/v1/chat-sync/ws/app_x?role=employer',
    );
  });
}
