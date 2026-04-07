import 'package:flutter/material.dart';
import 'register_page.dart';
import 'login_page.dart';
import 'splash_page.dart';
import 'dart:ui';
import 'chat_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/auth_service.dart';
import 'services/current_chat.dart';
import 'main_navigation.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

OverlayEntry? _activeMessageOverlay;

Route<T> _instantRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

void _hideInAppMessageOverlay() {
  _activeMessageOverlay?.remove();
  _activeMessageOverlay = null;
}

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

void _openChatFromLaunch(NotificationLaunchData launch) {
  navigatorKey.currentState?.pushAndRemoveUntil(
    _instantRoute(
      ChatPage(
        userId: launch.userId,
        displayName: launch.displayName,
        photoUrl: launch.photoUrl,
        openChatsListOnExit: true,
      ),
    ),
    (route) => false,
  );
}

void _showInAppMessageOverlay({
  required NotificationLaunchData launch,
  required String messageText,
}) {
  final overlayState = navigatorKey.currentState?.overlay;
  if (overlayState == null) return;

  _hideInAppMessageOverlay();

  _activeMessageOverlay = OverlayEntry(
    builder: (context) {
      final topPadding = MediaQuery.of(context).padding.top;

      return Positioned(
        top: topPadding + 10,
        left: 14,
        right: 14,
        child: _FloatingMessageBanner(
          photoUrl: launch.photoUrl,
          senderName: launch.displayName,
          messageText: messageText.isEmpty
              ? 'Skickade ett meddelande'
              : messageText,
          onClose: _hideInAppMessageOverlay,
          onOpen: () {
            _hideInAppMessageOverlay();
            _openChatFromLaunch(launch);
          },
        ),
      );
    },
  );

  overlayState.insert(_activeMessageOverlay!);

  Future.delayed(const Duration(seconds: 4), () {
    _hideInAppMessageOverlay();
  });
}

void _openChatFromMessage(RemoteMessage message) {
  final launch = _parseNotificationLaunch(message);
  if (launch == null) return;

  _openChatFromLaunch(launch);
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

      final launch = _parseNotificationLaunch(message);
      if (launch == null) return;

      _openChatFromLaunch(launch);
    });

          FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final launch = _parseNotificationLaunch(message);
      if (launch == null) return;

      if (CurrentChat.openUserId == launch.userId) {
        return;
      }

      final messageText =
          (message.data['messageText'] ?? message.notification?.body ?? '')
              .toString()
              .trim();

      _showInAppMessageOverlay(
        launch: launch,
        messageText: messageText,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
     final initialHome = widget.launchFromNotification != null
    ? ChatPage(
        userId: widget.launchFromNotification!.userId,
        displayName: widget.launchFromNotification!.displayName,
        photoUrl: widget.launchFromNotification!.photoUrl,
        openChatsListOnExit: true,
      )
    : const SplashPage(skipNavigation: false);


        return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
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

class _FloatingMessageBanner extends StatefulWidget {
  final String photoUrl;
  final String senderName;
  final String messageText;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  const _FloatingMessageBanner({
    required this.photoUrl,
    required this.senderName,
    required this.messageText,
    required this.onClose,
    required this.onOpen,
  });

  @override
  State<_FloatingMessageBanner> createState() => _FloatingMessageBannerState();
}

class _FloatingMessageBannerState extends State<_FloatingMessageBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.22),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.985,
      end: 1,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: InkWell(
                  onTap: widget.onOpen,
                  borderRadius: BorderRadius.circular(26),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xCC2B201B),
                          const Color(0xCC17110E),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.10),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.28),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF5864),
                                      Color(0xFFFF8A5B),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF5864)
                                          .withOpacity(0.18),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFF221915),
                                  backgroundImage: widget.photoUrl.isNotEmpty
                                      ? NetworkImage(widget.photoUrl)
                                      : null,
                                  child: widget.photoUrl.isEmpty
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.white70,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            widget.senderName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.08),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withOpacity(0.08),
                                            ),
                                          ),
                                          child: const Text(
                                            'Nu',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.messageText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFE9DCD4),
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        height: 1.15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: widget.onClose,
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.07),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.08),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

