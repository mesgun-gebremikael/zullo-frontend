import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:zullo_app/services/auth_storage.dart';

class SignalRService {
  HubConnection? _connection;

  // Stream för inkommande meddelanden
final _messageController = StreamController<Map<String, dynamic>>.broadcast();
final _messagesReadController =
        StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messagesStream => _messageController.stream;
  Stream<Map<String, dynamic>> get messagesReadStream =>
    _messagesReadController.stream;


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
    _connection!.on("MessagesRead", (args) {
  if (args != null && args.isNotEmpty) {
    final data = Map<String, dynamic>.from(args[0] as Map);
    _messagesReadController.add(data);
  }
});


    await _connection!.start();
    print("SignalR connected");
  }

  Future<void> disconnect() async {
    await _connection?.stop();
  }
}
