import 'l10n/localization.dart';
import 'services/device_location_service.dart';
import 'theme/zullo_palette.dart';
import 'widgets/zullo_symbol.dart';
import 'welcome_page.dart';
import 'likes_page.dart';
import 'services/commerce_service.dart';
import 'services/relation_changes.dart';
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

class AppTabs {
  static const swipe = 0;
  static const likes = 1;
  static const chats = 2;
  static const profile = 3;
}

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

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  late final _locationSync = ForegroundLocationSync(_authService,
      isActive: () => mounted && _inForeground);
  Future<void> _refreshLocation() async {
    if (widget.pages != null || !_sessionActive) return;
    if (await _locationSync.refresh()) {
      if (mounted && _sessionActive) CommerceEvents.refreshDiscovery();
    }
  }

  StreamSubscription<ChatRepositoryState>? _repositorySubscription;
  StreamSubscription<int>? _sessionChanges;
  Timer? _presenceTimer;
  StreamSubscription<void>? _openDiscovery;
  StreamSubscription<void>? _accountClosed;
  StreamSubscription<void>? _sessionExpired;
  bool _endingSession = false;
  bool _inForeground = true;
  bool _presenceInFlight = false;
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

    _accountClosed = AccountSession.closedStream.listen((_) =>
        _endSession('Kontot är stängt. Din raderingsbegäran behandlas.'));
    _sessionExpired = AccountSession.expiredStream.listen(
        (_) => _endSession('Inloggningen behöver förnyas. Logga in igen.'));
    _openDiscovery = CommerceEvents.openDiscoveryStream.listen((_) {
      if (mounted && _sessionActive) setState(() => _selectedIndex = 0);
    });
    WidgetsBinding.instance.addObserver(this);
    if (widget.pages == null) {
      unawaited(_refreshLocation());
      unawaited(_pulsePresence());
      _presenceTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        unawaited(_pulsePresence());
        if (_inForeground) unawaited(_refreshLocation());
      });
    }
    _liveMessages = _live.messagesStream
        .listen((_) => MatchesRefreshService.instance.requestRefresh());
    _liveReads = _live.messagesReadStream
        .listen((_) => MatchesRefreshService.instance.requestRefresh());
    _liveReconnect = _live.reconnectedStream
        .listen((_) => MatchesRefreshService.instance.requestRefresh());
    _refreshEvents = MatchesRefreshService.instance.stream.listen((_) {
      unawaited(_loadUnreadStatus(force: true));
    });
    unawaited(_connectLive());
    _selectedIndex = widget.initialIndex;
    _loadUnreadStatus();

    _pages = widget.pages ??
        [
          const HomePage(),
          const LikesPage(),
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
      ChatCoordinator.instance.consumePendingRequest(expected: request);
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
    _openDiscovery?.cancel();
    _accountClosed?.cancel();
    _sessionExpired?.cancel();
    _presenceTimer?.cancel();
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

  Future<void> _pulsePresence() async {
    if (!mounted || !_sessionActive || !_inForeground || _presenceInFlight) {
      return;
    }
    _presenceInFlight = true;
    try {
      await CommerceClient().heartbeat();
      if (mounted && _sessionActive) CommerceEvents.walletChanged();
      if (mounted && _sessionActive) {
        MatchesRefreshService.instance.requestRefresh();
      }
    } catch (_) {/* retry on resume or next foreground heartbeat */} finally {
      _presenceInFlight = false;
    }
  }

  Future<void> _endSession(String message) async {
    if (!mounted || !_sessionActive || _endingSession) return;
    _endingSession = true;
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final expectedGeneration = _sessionGeneration + 1;
    try {
      await _authService.logout();
    } on SessionChangedException {
      return;
    } catch (_) {
      if (!AccountSession.isCurrent(expectedGeneration)) return;
    }
    if (!AccountSession.isCurrent(expectedGeneration)) return;
    if (navigator.mounted) {
      navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomePage()), (_) => false);
    }
    if (messenger.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(context.tr(message))));
    }
  }

  Future<void> _connectLive() async {
    if (!_sessionActive) return;
    try {
      await _live.connect();
    } catch (_) {/* Resume retries after a disconnected start. */}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed && mounted && _sessionActive) {
      if (widget.pages == null) unawaited(_pulsePresence());
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
        final revision = RelationChanges.revision;
        final matches = await _authService.getMatches();
        if (revision != RelationChanges.revision) return;
        if (!mounted || !_sessionActive) return;
        ChatRepository.instance.setChatList(matches
            .map((m) =>
                ChatListItem.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList());
        _syncUnreadFromRepository();
      } catch (_) {/* Retain last successful state while offline. */}
    }, invalidate: force);
  }

  void _syncUnreadFromRepository() {
    final hasUnread = ChatRepository.instance.chatList.any((m) => m.hasUnread);

    if (!mounted || !_sessionActive) return;

    setState(() {
      _hasUnreadMessages = hasUnread;
    });
  }

  List<ChatMessageItem> _mapThreadJsonToRepositoryItems(
      List<dynamic> data, String meUserId) {
    DateTime? parseUtcToLocal(dynamic raw) {
      if (raw == null) return null;

      var s = raw.toString().trim();
      if (s.isEmpty) return null;

      final hasTimezone = s.endsWith('Z') ||
          s.contains('+') ||
          RegExp(r'-\d{2}:\d{2}$').hasMatch(s);

      if (!hasTimezone) {
        s = '${s}Z';
      }

      final parsed = DateTime.tryParse(s);
      return parsed?.toLocal();
    }

    return data.map((m) {
      final fromUserId = (m['fromUserId'] ?? '').toString();
      final text = (m['text'] ?? '').toString();
      final createdLocal = parseUtcToLocal(m['createdAtUtc']) ?? DateTime.now();
      final readAtLocal = parseUtcToLocal(m['readAtUtc']);
      final clientMessageId = (m['clientMessageId'] ?? '').toString();

      return ChatMessageItem(
        serverId: m['id']?.toString(),
        sequence: (m['sequence'] as num?)?.toInt(),
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
        "pending": m.pending,
        "failed": m.failed,
        "id": m.serverId,
        "sequence": m.sequence,
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
        _selectedIndex = AppTabs.chats;
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
        _selectedIndex = AppTabs.chats;
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
      extendBody: false,
      backgroundColor: const Color(0xFFF0F1F3),
      body: IndexedStack(
        index: _selectedIndex,
        children: List<Widget>.generate(_pages.length,
            (i) => _visited.contains(i) ? _pages[i] : const SizedBox.shrink()),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height:
                  70 + (MediaQuery.textScalerOf(context).scale(11.5) - 11.5),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: const Color(0xFFE8EBF0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF20242C).withValues(alpha: .08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.explore_outlined,
                    symbol: ZulloSymbolKind.discover,
                    activeIcon: Icons.explore,
                    label: 'Swipa',
                    isActive: _selectedIndex == 0,
                    onTap: () => _onItemTapped(0),
                  ),
                  _NavItem(
                    icon: Icons.favorite_border,
                    activeIcon: Icons.favorite,
                    label: 'Likes',
                    isActive: _selectedIndex == AppTabs.likes,
                    onTap: () => _onItemTapped(AppTabs.likes),
                  ),
                  _NavItem(
                    icon: Icons.chat_bubble_outline,
                    symbol: ZulloSymbolKind.conversation,
                    activeIcon: Icons.chat_bubble,
                    label: 'Chattar',
                    isActive: _selectedIndex == AppTabs.chats,
                    showDot: _hasUnreadMessages,
                    onTap: () => _onItemTapped(AppTabs.chats),
                  ),
                  _NavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Profil',
                    isActive: _selectedIndex == AppTabs.profile,
                    onTap: () => _onItemTapped(AppTabs.profile),
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
  final ZulloSymbolKind? symbol;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool showDot;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    this.symbol,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    const inactiveColor = Color(0xFF697180);
    const inactiveTextColor = Color(0xFF697180);

    return Expanded(
      child: Semantics(
          button: true,
          selected: isActive,
          onTap: onTap,
          excludeSemantics: true,
          label: showDot
              ? context.l10n.value0UnreadMessages(context.tr(label))
              : context.tr(label),
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(
                  horizontal: isActive ? 12 : 4,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive ? ZulloPalette.tint : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: isActive
                      ? Border.all(
                          color: const Color(0xFFFFDFE9),
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
                        if (symbol != null)
                          ZulloSymbol(
                              kind: symbol!,
                              color:
                                  isActive ? ZulloPalette.rose : inactiveColor,
                              size: 25)
                        else
                          Icon(
                            isActive ? activeIcon : icon,
                            color: isActive ? ZulloPalette.rose : inactiveColor,
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
                                  color: const Color(0xFFFFFFFF),
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(label),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        color: isActive ? ZulloPalette.rose : inactiveTextColor,
                        fontSize: 11.5,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )),
    );
  }
}
