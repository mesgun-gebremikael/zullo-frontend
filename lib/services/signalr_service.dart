import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:zullo_app/services/auth_storage.dart';

class SignalRService {
  HubConnection? _connection;

  // Stream för inkommande meddelanden
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messagesStream => _messageController.stream;

  Future<void> connect() async {
    final token = await AuthStorage().getToken();

    final hubUrl = "http://10.0.2.2:5125/hubs/chat";


    _connection = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token ?? "",
          ),
        )
        .build();

    // När vi får nytt meddelande från backend
      _connection!.on("MessageReceived", (args) { 
      if (args != null && args.isNotEmpty) {
        final data = args[0] as Map<String, dynamic>;
        _messageController.add(data);
      }
    });

    await _connection!.start();
    print("SignalR connected");
  }

  Future<void> disconnect() async {
    await _connection?.stop();
  }
}
