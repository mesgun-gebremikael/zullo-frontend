import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'profile_tab.dart';
import 'home_page.dart';
import 'matches_page.dart';
import 'services/auth_service.dart';
import 'chat_page.dart';
import 'services/unread_sync_service.dart';
import 'services/chat_coordinator.dart';
import 'models/chat_open_request.dart';
import 'services/messages_service.dart';
import 'services/auth_storage.dart';
import 'services/chat_cache_service.dart';
import 'services/matches_cache_service.dart';
import 'services/matches_refresh_service.dart';



class MainNavigation extends StatefulWidget {
  final int initialIndex;
 

  const MainNavigation({
    super.key,
    this.initialIndex = 0,
    
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}


class _MainNavigationState extends State<MainNavigation> {
  late int _selectedIndex;

  final AuthService _authService = AuthService();
  Timer? _unreadPollTimer;
  bool _hasUnreadMessages = false;

  
 late final List<Widget> _pages;
 late final MessagesService _messagesService;
StreamSubscription<ChatOpenRequest>? _openChatSubscription;
bool _isOpeningChat = false;
 



  @override
  void initState() {
    super.initState();
    _messagesService = MessagesService(
  AuthService.baseApiUrl,
  AuthStorage(),
);

    _selectedIndex = widget.initialIndex;
    _loadUnreadStatus();

    _pages = [
      const HomePage(),
      const MatchesPage(), // Explore tillfällig
      const MatchesPage(), // Likes tillfällig
      MatchesPage(
        onUnreadChanged: (hasUnread) {
          if (!mounted) return;
          setState(() {
            _hasUnreadMessages = hasUnread;
          });
        },
      ),
      const ProfileTab(),
    ];

    _openChatSubscription =
    ChatCoordinator.instance.openChatStream.listen((request) async {
  await _handleOpenChatRequest(request);
});

final pendingRequest = ChatCoordinator.instance.consumePendingRequest();
if (pendingRequest != null) {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _handleOpenChatRequest(pendingRequest);
  });
}


    // Pollar unread-status så chat-dot i bottom nav hålls mer uppdaterad
    _unreadPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _loadUnreadStatus();
    });
  }

   @override
void dispose() {
  _openChatSubscription?.cancel();
  _unreadPollTimer?.cancel();
  super.dispose();
}


  void _onItemTapped(int index) {
  setState(() {
    _selectedIndex = index;
  });

  _loadUnreadStatus();
}



  Future<void> _loadUnreadStatus() async {
    try {
      final matches = await _authService.getMatches();

      if (!mounted) return;

      final hasUnread = matches.any((m) => m['hasUnread'] == true);
      setState(() {
        _hasUnreadMessages = hasUnread;
      });
    } catch (_) {
      // Behåll tyst här just nu
    }
  }

Future<void> _handleOpenChatRequest(ChatOpenRequest request) async {
  if (!mounted) return;
  if (_isOpeningChat) return;
  if (!request.isValid) return;

  _isOpeningChat = true;

  try {
    setState(() {
      _selectedIndex = 3;
    });

   UnreadSyncService.instance.markChatOpened(request.userId);
MatchesCacheService.clearUnreadForUser(request.userId);

final initialThreadData = await _messagesService.getThread(request.userId);
if (!mounted) return;

    final shouldRefresh = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ChatPage(
          userId: request.userId,
          displayName: request.displayName,
          photoUrl: request.photoUrl,
          openChatsListOnExit: request.openChatsListOnExit,
          initialThreadData: initialThreadData,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (!mounted) return;

    if (shouldRefresh == true) {
      MatchesRefreshService.instance.requestRefresh();
      await _loadUnreadStatus();
    }
  } catch (e) {
    debugPrint('Open chat failed: $e');
    if (!mounted) return;

    setState(() {
      _selectedIndex = 3;
    });
  } finally {
    _isOpeningChat = false;
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
     body: IndexedStack(
  index: _selectedIndex,
  children: _pages,
),

      bottomNavigationBar: SafeArea(
  top: false,
minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12), 
 child: ClipRRect(
    borderRadius: BorderRadius.circular(30),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
       height: 58,
padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
  color: const Color(0xFF1A120C).withOpacity(0.62),
  borderRadius: BorderRadius.circular(30),
  border: Border.all(
    color: const Color(0xFFC89B3C).withOpacity(0.18),
    width: 1,
  ),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.22),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ],
),
        child: Row(
          children: [
            _NavItem(
              icon: Icons.local_fire_department_outlined,
              activeIcon: Icons.local_fire_department,
              label: 'Swipa',
              isActive: _selectedIndex == 0,
              activeColor: const Color(0xFFFF4458),
              onTap: () => _onItemTapped(0),
            ),
            _NavItem(
              icon: Icons.explore_outlined,
              activeIcon: Icons.explore,
              label: 'Explore',
              isActive: _selectedIndex == 1,
              activeColor: Colors.white,
              onTap: () => _onItemTapped(1),
            ),
            _NavItem(
              icon: Icons.favorite_border,
              activeIcon: Icons.favorite,
              label: 'Likes',
              isActive: _selectedIndex == 2,
              activeColor: Colors.white,
              onTap: () => _onItemTapped(2),
            ),
            _NavItem(
  icon: Icons.chat_bubble_outline,
  activeIcon: Icons.chat_bubble,
  label: 'Chattar',
  isActive: _selectedIndex == 3,
  activeColor: Colors.white,
  showDot: _hasUnreadMessages,
  onTap: () => _onItemTapped(3),
),

            _NavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profil',
              isActive: _selectedIndex == 4,
              activeColor: Colors.white,
              onTap: () => _onItemTapped(4),
            ),
          ],
        ),
      ),
    ),
  ),
),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;
   final bool showDot;


  const _NavItem({
  required this.icon,
  required this.activeIcon,
  required this.label,
  required this.isActive,
  required this.activeColor,
  required this.onTap,
  this.showDot = false,
});


  @override
Widget build(BuildContext context) {
  const inactiveColor = Colors.white;
  const inactiveTextColor = Color(0xE6FFFFFF);

  return Expanded(
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: isActive ? 12 : 4,
            vertical: isActive ? 6 : 2,
          ),
          decoration: BoxDecoration(
            color: isActive
             ? const Color(0xFF3A2A1E).withOpacity(0.55)
             : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: isActive
      ? Border.all(
          color: const Color(0xFFC89B3C).withOpacity(0.25),
          width: 1,
        )
      : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
             Stack(
  clipBehavior: Clip.none,
  children: [
    Icon(
      isActive ? activeIcon : icon,
      color: isActive ? Colors.white : inactiveColor,
      size: isActive ? 22 : 20,
    ),
    if (showDot)
      Positioned(
        right: -2,
        top: -2,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFFF4458),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF1A120C),
              width: 1.2,
            ),
          ),
        ),
      ),
  ],
),

              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  color: isActive ? Colors.white : inactiveTextColor,
                  fontSize: isActive ? 9.5 : 9,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

class _ProfileTabPlaceholder extends StatelessWidget {
  const _ProfileTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Text(
            'Profil kommer snart',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}