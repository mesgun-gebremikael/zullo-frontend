import 'dart:async';
import 'package:zullo_app/services/signalr_service.dart';

class FakeChatTransport implements ChatTransport {
  final messageEvents = StreamController<Map<String, dynamic>>.broadcast();
  final readEvents = StreamController<Map<String, dynamic>>.broadcast();
  final reconnectEvents = StreamController<void>.broadcast();
  Completer<void>? connectGate;
  Completer<void> connectStarted = Completer<void>();
  bool connected = false;
  int _epoch = 0;
  int connections = 0;
  int disconnections = 0;
  int failAttempts = 0;
  String? token;
  @override
  Stream<Map<String, dynamic>> get messages => messageEvents.stream;
  @override
  Stream<Map<String, dynamic>> get reads => readEvents.stream;
  @override
  Stream<void> get reconnected => reconnectEvents.stream;
  @override
  Future<void> connect(String token) async {
    if (connected) return;
    connections++;
    final epoch = _epoch;
    this.token = token;
    if (!connectStarted.isCompleted) connectStarted.complete();
    if (failAttempts > 0) {
      failAttempts--;
      throw StateError('Simulated offline start');
    }
    await connectGate?.future;
    if (epoch == _epoch) connected = true;
  }

  @override
  Future<void> disconnect() async {
    disconnections++;
    _epoch++;
    connected = false;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await messageEvents.close();
    await readEvents.close();
    await reconnectEvents.close();
  }
}
