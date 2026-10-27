import 'account_session.dart';
import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:zullo_app/services/auth_storage.dart';

class SignalRService {
  HubConnection? _connection;
  final int _generation = AccountSession.generation;
  StreamSubscription<int>? _sessionSubscription;

  // Stream för inkommande meddelanden
final _messageController = StreamController<Map<String, dynamic>>.broadcast();
final _messagesReadController =
        StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messagesStream => _messageController.stream;
  Stream<Map<String, dynamic>> get messagesReadStream =>
    _messagesReadController.stream;


  Future<void> connect() async {
    AccountSession.check(_generation);
    final token = await AuthStorage().getToken();
    AccountSession.check(_generation);
    _sessionSubscription ??= AccountSession.changes.listen((_) {
      unawaited(disconnect().catchError((Object _) {}));
    });

    final hubUrl = "http://10.0.2.2:5125/hubs/chat";


   _connection = HubConnectionBuilder()
    .withUrl(
      hubUrl,
      options: HttpConnectionOptions(
        accessTokenFactory: () async => token ?? "",
      ),
    )
    .withAutomaticReconnect()
    .build();

    
 _connection!.onreconnecting(({error}) {
  print("SignalR reconnecting...");
});

_connection!.onreconnected(({connectionId}) {
  print("SignalR reconnected");
});

_connection!.onclose(({error}) {
  print("SignalR closed");
});




    // När vi får nytt meddelande från backend
      _connection!.on("MessageReceived", (args) { 
      if (AccountSession.isCurrent(_generation) && args != null && args.isNotEmpty) {
        final data = args[0] as Map<String, dynamic>;
        _messageController.add(data);
      }
    });
    _connection!.on("MessagesRead", (args) {
  if (AccountSession.isCurrent(_generation) && args != null && args.isNotEmpty) {
    final data = Map<String, dynamic>.from(args[0] as Map);
    _messagesReadController.add(data);
  }
});


    await _connection!.start();
    if (!AccountSession.isCurrent(_generation)) {
      await disconnect();
      throw SessionChangedException();
    }
    print("SignalR connected");
  }

  Future<void> disconnect() async {
    await _sessionSubscription?.cancel();
    _sessionSubscription = null;
    await _connection?.stop();
  }
}
