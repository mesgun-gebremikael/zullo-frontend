import 'services/signalr_service.dart';
import 'services/refresh_coordinator.dart';
import 'models/chat_list_item.dart';
import 'services/account_session.dart';
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
import 'services/auth_storage.dart';
import 'services/matches_cache_service.dart';
import 'services/matches_refresh_service.dart';
import 'services/chat_repository.dart';
import 'models/chat_message_item.dart';
import 'services/chat_thread_cache_service.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;
  final AuthService? authService;
  final SignalRService? liveService;
  final List<Widget>? pages;
 

  const MainNavigation({
    super.key,
    this.initialIndex = 0,
    this.authService,
    this.liveService,
    this.pages,
    
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}


class _MainNavigationState extends State<MainNavigation> with WidgetsBindingObserver {
  StreamSubscription<ChatRepositoryState>? _repositorySubscription;
  StreamSubscription<int>? _sessionChanges;
  final int _sessionGeneration = AccountSession.generation;
  bool get _sessionActive => AccountSession.isCurrent(_sessionGeneration);

  late int _selectedIndex;

  late final AuthService _authService = widget.authService ?? AuthService();
  late final SignalRService _live = widget.liveService ?? SignalRService();
  final _refresh = RefreshCoordinator();
  final Set<int> _visited = {};
  StreamSubscription<void>? _liveReconnect;
  StreamSubscription<void>? _refreshEvents;
  StreamSubscription<Map<String, dynamic>>? _liveMessages;
  StreamSubscription<Map<String, dynamic>>? _liveReads;
  bool _hasUnreadMessages = false;

  
 late final List<Widget> _pages;
StreamSubscription<ChatOpenRequest>? _openChatSubscription;
bool _isOpeningChat = false;
 



  @override
  void initState() {
    super.initState();
  _sessionChanges = AccountSession.changes.listen((_) {
    if (mounted) setState(() {});
  });


    WidgetsBinding.instance.addObserver(this);
    _liveMessages = _live.messagesStream.listen((_) => MatchesRefreshService.instance.requestRefresh());
    _liveReads = _live.messagesReadStream.listen((_) => MatchesRefreshService.instance.requestRefresh());
    _liveReconnect = _live.reconnectedStream.listen((_) => MatchesRefreshService.instance.requestRefresh());
    _refreshEvents = MatchesRefreshService.instance.stream.listen((_) { unawaited(_loadUnreadStatus(force: true)); });
    unawaited(_connectLive());
    _selectedIndex = widget.initialIndex;
    _loadUnreadStatus();

    _pages = widget.pages ?? [
      const HomePage(),
      const MatchesPage(), // Explore tillfällig
      const MatchesPage(), // Likes tillfällig
      MatchesPage(
        onUnreadChanged: (hasUnread) {
          if (!mounted || !_sessionActive) return;
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

_repositorySubscription = ChatRepository.instance.stream.listen((state) {
  _syncUnreadFromRepository();
});

final pendingRequest = ChatCoordinator.instance.consumePendingRequest();
if (pendingRequest != null) {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _handleOpenChatRequest(pendingRequest);
  });
}



  }

   @override
void dispose() {
  _sessionChanges?.cancel();
  _repositorySubscription?.cancel();
  _openChatSubscription?.cancel();
  WidgetsBinding.instance.removeObserver(this);
  _liveMessages?.cancel();
  _liveReads?.cancel();
  _liveReconnect?.cancel();
  _refreshEvents?.cancel();
  unawaited(_live.dispose());
  super.dispose();
}


  void _onItemTapped(int index) {
  setState(() {
    _selectedIndex = index;
  });

  _loadUnreadStatus();
}



Future<void> _connectLive() async {
  if (!_sessionActive) return;
  try { await _live.connect(); } catch (_) { /* Resume retries after a disconnected start. */ }
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed && mounted && _sessionActive) {
    unawaited(_connectLive());
    unawaited(_authService.syncPushToken());
    unawaited(_loadUnreadStatus(force: true));
  }
}

Future<void> _loadUnreadStatus({bool force = false}) {
  if (!_sessionActive) return Future.value();
  if (!force && ChatRepository.instance.hasLoadedList) {
    _syncUnreadFromRepository();
    return Future.value();
  }
  return _refresh.run(() async {
    if (!mounted || !_sessionActive) return;
    try {
      final matches = await _authService.getMatches();
      if (!mounted || !_sessionActive) return;
      ChatRepository.instance.setChatList(matches.map((m) => ChatListItem.fromJson(Map<String, dynamic>.from(m as Map))).toList());
      _syncUnreadFromRepository();
    } catch (_) { /* Retain last successful state while offline. */ }
  }, invalidate: force);
}

  void _syncUnreadFromRepository() {
  final hasUnread = ChatRepository.instance.chatList.any((m) => m.hasUnread);

  if (!mounted || !_sessionActive) return;

  setState(() {
    _hasUnreadMessages = hasUnread;
  });
}

  List<ChatMessageItem> _mapThreadJsonToRepositoryItems(List<dynamic> data, String meUserId) {
  DateTime? parseUtcToLocal(dynamic raw) {
    if (raw == null) return null;

    var s = raw.toString().trim();
    if (s.isEmpty) return null;

    final hasTimezone =
        s.endsWith('Z') || s.contains('+') || RegExp(r'-\d{2}:\d{2}$').hasMatch(s);

    if (!hasTimezone) {
      s = '${s}Z';
    }

    final parsed = DateTime.tryParse(s);
    return parsed?.toLocal();
  }

  return data.map((m) {
    final fromUserId = (m['fromUserId'] ?? '').toString();
    final text = (m['text'] ?? '').toString();
    final createdLocal =
        parseUtcToLocal(m['createdAtUtc']) ?? DateTime.now();
    final readAtLocal = parseUtcToLocal(m['readAtUtc']);
    final clientMessageId = (m['clientMessageId'] ?? '').toString();

    return ChatMessageItem(
      serverId: m['id']?.toString(), sequence: (m['sequence'] as num?)?.toInt(),
      text: text,
      isMe: fromUserId == meUserId,
      timeLocal: createdLocal,
      readAtLocal: readAtLocal,
      pending: m["pending"] == true,
      failed: m["failed"] == true,
      clientMessageId: clientMessageId,
    );
  }).toList();
}

List<dynamic>? _threadJsonFromRepository(String userId, String meUserId) {
  final repoThread = ChatRepository.instance.threadFor(userId);
  if (repoThread.isEmpty) return null;

  return repoThread.map((m) {
    return {
      "text": m.text,
      "pending": m.pending, "failed": m.failed,
      "id": m.serverId, "sequence": m.sequence,
      "fromUserId": m.isMe ? meUserId : userId,
      "toUserId": m.isMe ? userId : meUserId,
      "createdAtUtc": m.timeLocal.toUtc().toIso8601String(),
      "readAtUtc": m.readAtLocal?.toUtc().toIso8601String(),
      "clientMessageId": m.clientMessageId,
    };
  }).toList();
}

Future<void> _handleOpenChatRequest(ChatOpenRequest request) async {
  if (!_sessionActive) return;
  if (!mounted || !_sessionActive) return;
  if (_isOpeningChat) return;
  if (!request.isValid) return;

  _isOpeningChat = true;

  try {
    setState(() {
      _selectedIndex = 3;
    });

    final meUserId = await AuthStorage().getUserId();
    if (!mounted || !_sessionActive) return;
    if (meUserId == null || meUserId.isEmpty) return;

    UnreadSyncService.instance.markChatOpened(request.userId);
    ChatRepository.instance.clearUnreadForUser(request.userId);
    MatchesCacheService.clearUnreadForUser(request.userId);
    MatchesRefreshService.instance.requestRefresh();
    _syncUnreadFromRepository();

   List<dynamic>? initialThreadData =
    ChatThreadCacheService.getThread(request.userId);

initialThreadData ??= _threadJsonFromRepository(request.userId, meUserId);


if (initialThreadData != null && initialThreadData.isNotEmpty) {
  ChatThreadCacheService.setThread(request.userId, initialThreadData);

  final repoItems =
      _mapThreadJsonToRepositoryItems(initialThreadData, meUserId);

  ChatRepository.instance.setThread(request.userId, repoItems);
}

    final shouldRefresh = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ChatPage(
          userId: request.userId,
          displayName: request.displayName,
          photoUrl: request.photoUrl,
          openChatsListOnExit: request.openChatsListOnExit,
          initialThreadData: initialThreadData,
          initialMeUserId: meUserId,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (!mounted || !_sessionActive) return;

    if (shouldRefresh == true) {
      MatchesRefreshService.instance.requestRefresh();
      await _loadUnreadStatus();
    }
  } catch (e) {
    debugPrint('Open chat failed: $e');
    if (!mounted || !_sessionActive) return;

    setState(() {
      _selectedIndex = 3;
    });
  } finally {
    _isOpeningChat = false;
  }
}

  @override
  Widget build(BuildContext context) {
    if (!_sessionActive) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _visited.add(_selectedIndex);
    if (widget.pages == null) _pages[0] = HomePage(active: _selectedIndex == 0);
    return Scaffold(
      extendBody: true,
     body: IndexedStack(
  index: _selectedIndex,
  children: List<Widget>.generate(_pages.length, (i) => _visited.contains(i) ? _pages[i] : const SizedBox.shrink()),
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