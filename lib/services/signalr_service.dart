import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';
import 'account_session.dart';
import 'auth_storage.dart';
import 'api_config.dart';

abstract class ChatTransport {
  Stream<Map<String, dynamic>> get messages;
  Stream<Map<String, dynamic>> get reads;
  Stream<void> get reconnected;
  Future<void> connect(String token);
  Future<void> disconnect();
  Future<void> dispose();
}

class HubChatTransport implements ChatTransport {
  HubConnection? _connection;
  int _epoch = 0;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _reads = StreamController<Map<String, dynamic>>.broadcast();
  final _reconnected = StreamController<void>.broadcast();
  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;
  @override
  Stream<Map<String, dynamic>> get reads => _reads.stream;
  @override
  Stream<void> get reconnected => _reconnected.stream;

  @override
  Future<void> connect(String token) async {
    if (_connection?.state == HubConnectionState.Connected) return;
    final epoch = ++_epoch;
    await _connection?.stop();
    if (epoch != _epoch) return;
    final connection = HubConnectionBuilder()
        .withUrl('${ApiConfig.baseUrl}/hubs/chat',
            options:
                HttpConnectionOptions(accessTokenFactory: () async => token))
        .withAutomaticReconnect()
        .build();
    _connection = connection;
    connection.on('MessageReceived', (args) {
      if (epoch == _epoch && args != null && args.isNotEmpty) {
        _messages.add(Map<String, dynamic>.from(args.first as Map));
      }
    });
    connection.on('MessagesRead', (args) {
      if (epoch == _epoch && args != null && args.isNotEmpty) {
        _reads.add(Map<String, dynamic>.from(args.first as Map));
      }
    });
    connection.onreconnected(({connectionId}) {
      if (epoch == _epoch) _reconnected.add(null);
    });
    await connection.start();
    if (epoch != _epoch) await connection.stop();
  }

  @override
  Future<void> disconnect() async {
    _epoch++;
    final connection = _connection;
    _connection = null;
    await connection?.stop();
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _messages.close();
    await _reads.close();
    await _reconnected.close();
  }
}

class SignalRService {
  final ChatTransport _transport;
  final Duration connectionTimeout;
  final int _generation = AccountSession.generation;
  StreamSubscription<int>? _sessionSubscription;
  Future<void>? _connecting;
  bool _disposed = false;
  int _connectionEpoch = 0;
  SignalRService(
      {ChatTransport? transport,
      this.connectionTimeout = const Duration(seconds: 15)})
      : _transport = transport ?? HubChatTransport();

  Stream<Map<String, dynamic>> get messagesStream => _transport.messages
      .where((_) => !_disposed && AccountSession.isCurrent(_generation));
  Stream<Map<String, dynamic>> get messagesReadStream => _transport.reads
      .where((_) => !_disposed && AccountSession.isCurrent(_generation));
  Stream<void> get reconnectedStream => _transport.reconnected
      .where((_) => !_disposed && AccountSession.isCurrent(_generation));

  Future<void> connect() {
    AccountSession.check(_generation);
    if (_disposed) return Future.error(StateError('Connection disposed'));
    if (_connecting != null) return _connecting!;
    // Transport decides whether an existing connection actually needs restarting.
    final epoch = _connectionEpoch;
    late Future<void> operation;
    operation = Future<void>.microtask(() async {
      final token = await AuthStorage().getToken();
      AccountSession.check(_generation);
      if (token == null || token.isEmpty) {
        throw StateError('No authenticated session');
      }
      _sessionSubscription ??= AccountSession.changes.listen((_) {
        unawaited(disconnect().catchError((Object _) {}));
      });
      try {
        await _transport.connect(token).then((_) async {
          if (_disposed ||
              epoch != _connectionEpoch ||
              !AccountSession.isCurrent(_generation)) {
            throw SessionChangedException();
          }
        }).timeout(connectionTimeout);
      } catch (_) {
        _connectionEpoch++;
        await _transport.disconnect();
        rethrow;
      }
    }).whenComplete(() {
      if (identical(_connecting, operation)) _connecting = null;
    });
    _connecting = operation;
    return operation;
  }

  Future<void> disconnect() async {
    _connectionEpoch++;
    await _sessionSubscription?.cancel();
    _sessionSubscription = null;
    await _transport.disconnect();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await disconnect();
    // A late connect must finish before its transport controllers are closed.
    try {
      await _connecting;
    } catch (_) {}
    await _transport.dispose();
  }
}
