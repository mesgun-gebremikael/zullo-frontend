import 'package:flutter/material.dart';
import 'register_page.dart';
import 'login_page.dart';
import 'splash_page.dart';
import 'dart:ui';
import 'chat_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/auth_service.dart';
import 'services/current_chat.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'services/badge_service.dart';
import 'main_navigation.dart';
import 'services/auth_storage.dart';
import 'services/chat_coordinator.dart';
import 'models/chat_open_request.dart';
import 'services/chat_thread_cache_service.dart';



final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

OverlayEntry? _activeMessageOverlay;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'messages',
  'Messages',
  description: 'Chat messages',
  importance: Importance.max,
);

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

Future<void> _openChatFromLaunch(NotificationLaunchData launch) async {
  final token = await AuthStorage().getToken();

  if (token == null || token.isEmpty) {
    navigatorKey.currentState?.pushAndRemoveUntil(
      _instantRoute(const WelcomeScreen()),
      (route) => false,
    );
    return;
  }

  final authService = AuthService();
  final canOpen = await authService.canOpenChat(launch.userId);

  if (!canOpen) {
    navigatorKey.currentState?.pushAndRemoveUntil(
      _instantRoute(const MainNavigation(initialIndex: 3)),
      (route) => false,
    );
    return;
  }

  final existingThread = ChatThreadCacheService.getThread(launch.userId);

ChatCoordinator.instance.requestOpenChat(
  ChatOpenRequest(
    userId: launch.userId,
    displayName: launch.displayName,
    photoUrl: launch.photoUrl,
    openChatsListOnExit: true,
    fromNotification: true,
    forceRefreshThread: true,
  ),
);

navigatorKey.currentState?.pushAndRemoveUntil(
  _instantRoute(const MainNavigation(initialIndex: 3)),
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

    await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
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
   await BadgeService.refreshUnreadBadge();
   
   FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
  if (newToken.isEmpty) return;

  try {
    await AuthService().saveDeviceToken(newToken);
    print("Refreshed device token saved to backend");
  } catch (e) {
    print("Could not save refreshed device token: $e");
  }
});

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

            FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final launch = _parseNotificationLaunch(message);
      if (launch == null) return;

      if (CurrentChat.openUserId == launch.userId) {
        return;
      }

      final messageText =
          (message.data['messageText'] ?? message.notification?.body ?? '')
              .toString()
              .trim();

              try {
await BadgeService.refreshUnreadBadge();
} catch (e) {
  print("Badge error: $e");
}

            _showInAppMessageOverlay(
        launch: launch,
        messageText: messageText,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
     final initialHome = const SplashPage(skipNavigation: false);



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
  late final Animation<Offset> _enterSlideAnimation;
  late final Animation<double> _enterFadeAnimation;
  late final Animation<double> _enterScaleAnimation;

  double _dragOffsetY = 0;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _enterSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.14),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _enterFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _enterScaleAnimation = Tween<double>(
      begin: 0.992,
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

  Future<void> _dismissBanner() async {
    if (_isClosing) return;
    _isClosing = true;

    await _controller.reverse();
    widget.onClose();
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    final nextOffset = _dragOffsetY + details.delta.dy;

    // Bara uppåt eller väldigt lite neråt
    setState(() {
      _dragOffsetY = nextOffset.clamp(-160.0, 16.0);
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldDismiss = _dragOffsetY < -42 || velocity < -420;

    if (shouldDismiss) {
      _dismissBanner();
      return;
    }

    setState(() {
      _dragOffsetY = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dragProgress = (_dragOffsetY.abs() / 120).clamp(0.0, 1.0);
    final dynamicOpacity = 1 - (dragProgress * 0.22);
    final dynamicScale = 1 - (dragProgress * 0.025);

    return FadeTransition(
      opacity: _enterFadeAnimation,
      child: SlideTransition(
        position: _enterSlideAnimation,
        child: ScaleTransition(
          scale: _enterScaleAnimation,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutBack,
            offset: Offset(0, _dragOffsetY / 220),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              scale: dynamicScale,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: dynamicOpacity,
                child: Material(
                  color: Colors.transparent,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: GestureDetector(
                        onVerticalDragUpdate: _handleVerticalDragUpdate,
                        onVerticalDragEnd: _handleVerticalDragEnd,
                        child: InkWell(
                          onTap: widget.onOpen,
                          borderRadius: BorderRadius.circular(22),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  color: const Color(0xCC101114),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.15),
                                    width: 0.9,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.24),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 11, 12, 11),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(1.8),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFFFF5A5F),
                                              Color(0xFFFF7A59),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFFF5A5F)
                                                  .withOpacity(0.18),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: CircleAvatar(
                                          radius: 21,
                                          backgroundColor:
                                              const Color(0xFF17181A),
                                          backgroundImage:
                                              widget.photoUrl.isNotEmpty
                                                  ? NetworkImage(widget.photoUrl)
                                                  : null,
                                          child: widget.photoUrl.isEmpty
                                              ? const Icon(
                                                  Icons.person,
                                                  color: Colors.white70,
                                                  size: 20,
                                                )
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 11),
                                      Expanded(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    widget.senderName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      height: 1.05,
                                                      letterSpacing: 0.05,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 7,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.08),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withOpacity(0.09),
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Nu',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      height: 1,
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
                                                color: Color(0xFFECECEC),
                                                fontSize: 13.2,
                                                fontWeight: FontWeight.w500,
                                                height: 1.15,
                                              ),
                                            ),
                                          ],
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
            ),
          ),
        ),
      ),
    );
  }
}