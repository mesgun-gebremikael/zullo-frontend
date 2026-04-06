import 'package:flutter/material.dart';
import 'register_page.dart';
import 'login_page.dart';
import 'splash_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/auth_service.dart';
import 'main_navigation.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationLaunchData {
  final String userId;
  final String displayName;
  final String photoUrl;

  const NotificationLaunchData({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
  });
}

NotificationLaunchData? _parseNotificationLaunch(RemoteMessage? message) {
  if (message == null) return null;

  final data = message.data;
  if (data['type'] != 'message') return null;

  final senderUserId = data['senderUserId'];
  if (senderUserId == null || senderUserId.isEmpty) return null;

  return NotificationLaunchData(
    userId: senderUserId,
    displayName: data['senderName'] ?? 'Chat',
    photoUrl: data['senderPhotoUrl'] ?? '',
  );
}

void _openChatFromMessage(RemoteMessage message) {
  final parsed = _parseNotificationLaunch(message);
  if (parsed == null) return;

  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => MainNavigation(
        initialIndex: 3,
        openChatUserId: parsed.userId,
        openChatDisplayName: parsed.displayName,
        openChatPhotoUrl: parsed.photoUrl,
      ),
    ),
    (route) => false,
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

  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  final launchFromNotification = _parseNotificationLaunch(initialMessage);

  runApp(
    ZulloApp(
      launchFromNotification: launchFromNotification,
    ),
  );
}

class ZulloApp extends StatefulWidget {
  final NotificationLaunchData? launchFromNotification;

  const ZulloApp({
    super.key,
    this.launchFromNotification,
  });

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
  }

  @override
  Widget build(BuildContext context) {
    final initialHome = widget.launchFromNotification != null
        ? MainNavigation(
            initialIndex: 3,
            openChatUserId: widget.launchFromNotification!.userId,
            openChatDisplayName: widget.launchFromNotification!.displayName,
            openChatPhotoUrl: widget.launchFromNotification!.photoUrl,
          )
        : const SplashPage();

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
      home: initialHome,
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


