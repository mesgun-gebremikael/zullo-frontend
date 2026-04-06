import 'package:flutter/material.dart';
import 'register_page.dart';
import 'login_page.dart';
import 'welcome_page.dart';
import 'splash_page.dart';
import 'chat_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/auth_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void _openChatFromMessage(RemoteMessage message) {
  final data = message.data;

  if (data['type'] != 'message') return;

  final senderUserId = data['senderUserId'];
  final senderName = data['senderName'] ?? 'Chat';
  final senderPhotoUrl = data['senderPhotoUrl'] ?? '';

  if (senderUserId == null || senderUserId.isEmpty) return;

  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => ChatPage(
        userId: senderUserId,
        displayName: senderName,
        photoUrl: senderPhotoUrl,
      ),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseMessaging.instance.requestPermission();

  final fcmToken = await FirebaseMessaging.instance.getToken();
  print("TOKEN: $fcmToken");

  if (fcmToken != null && fcmToken.isNotEmpty) {
    try {
      await AuthService().saveDeviceToken(fcmToken);
      print("Device token saved to backend");
    } catch (e) {
      print("Could not save device token: $e");
    }
  }

  runApp(const ZulloApp());
}

class ZulloApp extends StatefulWidget {
  const ZulloApp({super.key});

  @override
  State<ZulloApp> createState() => _ZulloAppState();
}

class _ZulloAppState extends State<ZulloApp> {
  String? _lastOpenedMessageId;

  @override
  void initState() {
    super.initState();
    _setupNotificationTapHandling();
  }

  Future<void> _setupNotificationTapHandling() async {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (_lastOpenedMessageId == message.messageId) return;
      _lastOpenedMessageId = message.messageId;
      _openChatFromMessage(message);
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_lastOpenedMessageId == initialMessage.messageId) return;
        _lastOpenedMessageId = initialMessage.messageId;
        _openChatFromMessage(initialMessage);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pink,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      home: const SplashPage(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'ZULLO',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Find someone who shares your culture, values, and future.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterPage(),
                    ),
                  );
                },
                child: const Text('Create account'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginPage(),
                    ),
                  );
                },
                child: const Text('Log in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
