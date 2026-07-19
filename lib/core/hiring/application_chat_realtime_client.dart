import 'dart:async';
import 'dart:convert';

import 'package:map/core/config/env_config.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 지원 건 채팅 WebSocket — REST 저장 후 서버가 즉시 push
class ApplicationChatRealtimeClient {
  ApplicationChatRealtimeClient({
    required this.applicationId,
    required this.senderRole,
    this.onConnectionStateChanged,
  });

  final String applicationId;
  final String senderRole;
  final void Function(bool connected)? onConnectionStateChanged;

  final _incoming = StreamController<Map<String, dynamic>>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _connected = false;

  Stream<Map<String, dynamic>> get incomingMessages => _incoming.stream;

  bool get isConnected => _connected;

  static String wsUrlFor({
    required String httpBaseUrl,
    required String applicationId,
    required String senderRole,
    String? token,
  }) {
    final trimmed = httpBaseUrl.replaceAll(RegExp(r'/$'), '');
    final wsBase = trimmed
        .replaceFirst(RegExp(r'^https://', caseSensitive: false), 'wss://')
        .replaceFirst(RegExp(r'^http://', caseSensitive: false), 'ws://');
    final uri = Uri.parse('$wsBase/v1/chat-sync/ws/$applicationId').replace(
      queryParameters: {
        'role': senderRole,
        if (token != null && token.isNotEmpty) 'token': token,
      },
    );
    return uri.toString();
  }

  Future<void> connect() async {
    if (_disposed || !EnvConfig.isComplianceApiEnabled) return;
    final base = EnvConfig.complianceApiBaseUrl;
    if (base.isEmpty) return;

    await _subscription?.cancel();
    await _channel?.sink.close();

    final url = wsUrlFor(
      httpBaseUrl: base,
      applicationId: applicationId,
      senderRole: senderRole,
      token: AuthSession.instance.accessToken,
    );

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _subscription = _channel!.stream.listen(
        _onData,
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
        cancelOnError: true,
      );
    } on Object {
      _setConnected(false);
      _scheduleReconnect();
    }
  }

  void _onData(dynamic data) {
    if (data is! String) return;
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      final type = map['type'] as String? ?? '';
      if (type == 'connected') {
        _setConnected(true);
        return;
      }
      if (type == 'message' && map['payload'] is Map) {
        _incoming.add(Map<String, dynamic>.from(map['payload'] as Map));
      }
    } on Object {
      // malformed frame — ignore
    }
  }

  void _handleDisconnect() {
    _setConnected(false);
    if (!_disposed) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_disposed) return;
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (!_disposed) unawaited(connect());
    });
  }

  void _setConnected(bool value) {
    if (_connected == value) return;
    _connected = value;
    onConnectionStateChanged?.call(value);
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _incoming.close();
  }
}
