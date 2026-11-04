import 'l10n/presence_text.dart';
import 'l10n/localization.dart';
import 'widgets/discovery_empty_state.dart';
import 'services/commerce_service.dart';
import 'services/relation_changes.dart';
import 'services/refresh_coordinator.dart';
import 'services/account_session.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/unread_sync_service.dart';
import 'services/chat_coordinator.dart';
import 'models/chat_open_request.dart';
import 'services/matches_cache_service.dart';
import 'services/matches_refresh_service.dart';
import 'services/profile_images.dart';
import 'models/chat_list_item.dart';
import 'services/chat_repository.dart';
import 'services/chat_thread_cache_service.dart';
import 'services/messages_service.dart';
import 'services/auth_storage.dart';

class MatchesPage extends StatefulWidget {
  final ValueChanged<bool>? onUnreadChanged;
  final AuthService? authService;

  const MatchesPage({
    super.key,
    this.onUnreadChanged,
    this.authService,
  });

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  StreamSubscription<int>? _sessionChanges;
  StreamSubscription<String>? _relationChanges;
  final int _sessionGeneration = AccountSession.generation;
  bool get _sessionActive => AccountSession.isCurrent(_sessionGeneration);

  late final AuthService _auth = widget.authService ?? AuthService();
  final _refresh = RefreshCoordinator();
  StreamSubscription<String>? _openedChatSubscription;

//StreamSubscription<Map<String, dynamic>>? _messagesReadSubscription;

  StreamSubscription<void>? _refreshSubscription;
  StreamSubscription<ChatRepositoryState>? _repositorySubscription;
  bool isLoading = true;
  String? error;
  List<dynamic> matches = [];
  late final MessagesService _messagesService;

  @override
  void initState() {
    super.initState();
    _sessionChanges = AccountSession.changes.listen((_) {
      if (mounted) setState(() {});
    });

    _relationChanges = RelationChanges.stream.listen((other) {
      if (!mounted || !_sessionActive) return;
      setState(() {
        matches.removeWhere((row) => row['userId'].toString() == other);
      });
    });
    _messagesService = MessagesService(
      AuthService.baseApiUrl,
      AuthStorage(),
    );

    final cachedMatches = MatchesCacheService.getMatches();

    if (cachedMatches != null) {
      matches = List<dynamic>.from(cachedMatches);
      isLoading = false;

      final cachedItems = _mapMatchesToChatItems(matches);
      ChatRepository.instance.setChatList(cachedItems);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_sessionActive) return;
        _precacheMatchImages(matches);
      });
    }

    _repositorySubscription = ChatRepository.instance.stream.listen((state) {
      if (!mounted || !_sessionActive) return;

      final mapped = _mapChatItemsToUi(state.chatList);
      final hasUnread = state.chatList.any((m) => m.hasUnread);

      setState(() {
        matches = mapped;
        isLoading = false;
        error = null;
      });

      _precacheMatchImages(mapped);

      widget.onUnreadChanged?.call(hasUnread);
    });

    loadMatches(silent: cachedMatches != null);
    _refreshSubscription =
        MatchesRefreshService.instance.stream.listen((_) async {
      if (!mounted || !_sessionActive) return;
      await loadMatches(silent: true, invalidate: true);
    });

    _openedChatSubscription =
        UnreadSyncService.instance.openedChatStream.listen((userId) {
      if (!mounted || !_sessionActive) return;
      _clearUnreadLocally(userId);
    });
  }

  @override
  void dispose() {
    _sessionChanges?.cancel();
    _relationChanges?.cancel();
    _openedChatSubscription?.cancel(); // NYTT

    _refreshSubscription?.cancel();
    _repositorySubscription?.cancel();

    super.dispose();
  }

  DateTime? _tryParseUtc(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString();
    if (s.trim().isEmpty) return null;
    return DateTime.tryParse(s);
  }

  void _applyLocalUnreadOverride(List<dynamic> list) {
    for (final m in list) {
      final userId = (m["userId"] ?? "").toString();
      if (userId.isEmpty) continue;

      final openedAt = UnreadSyncService.instance.getOpenedAt(userId);
      if (openedAt == null) continue;

      final lastMessageAt = _tryParseUtc(m["lastMessageAtUtc"]);
      if (lastMessageAt == null) continue;

      final lastMessageAtUtc =
          lastMessageAt.isUtc ? lastMessageAt : lastMessageAt.toUtc();

      if (!lastMessageAtUtc.isAfter(openedAt)) {
        m["hasUnread"] = false;
        m["unreadMessageCount"] = 0;
      }
    }
  }

  void _sortMatchesInUi(List<dynamic> list) {
    list.sort((a, b) {
      // final aUnread = (a['hasUnread'] == true);
      //final bUnread = (b['hasUnread'] == true);
      //if (aUnread != bUnread) return aUnread ? -1 : 1;

      final aDt = _tryParseUtc(a['lastMessageAtUtc']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final bDt = _tryParseUtc(b['lastMessageAtUtc']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      return bDt.compareTo(aDt);
    });
  }

  List<ChatListItem> _mapMatchesToChatItems(List<dynamic> list) {
    final items = list
        .map((m) => ChatListItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    items.sort((a, b) {
      final aTime = a.lastMessageAtUtc ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final bTime = b.lastMessageAtUtc ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      return bTime.compareTo(aTime);
    });

    return items;
  }

  List<dynamic> _mapChatItemsToUi(List<ChatListItem> items) {
    return items
        .map((item) => {
              "userId": item.userId,
              "displayName": item.displayName,
              "photoUrl": item.photoUrl,
              "age": item.age,
              "lastMessageText": item.lastMessageText,
              "lastMessageAtUtc": item.lastMessageAtUtc?.toIso8601String(),
              "matchCreatedAtUtc": item.matchCreatedAtUtc?.toIso8601String(),
              "lastActivityUtc": item.lastActivityUtc?.toIso8601String(),
              "hasUnread": item.hasUnread,
              "unreadMessageCount": item.unreadMessageCount,
            })
        .toList();
  }

  void _precacheMatchImages(List<dynamic> list) {
    if (!mounted || !_sessionActive) return;

    for (final m in list.take(12)) {
      final photoUrl = (m["photoUrl"] ?? "").toString().trim();
      if (photoUrl.isEmpty) continue;

      precacheImage(
        ProfileImages.avatar(photoUrl),
        context,
      );
    }
  }

  Future<void> _warmTopChatThreads(List<dynamic> list) async {
    if (!_sessionActive) return;
    final messageMatches = list.where((m) {
      final lastText = (m['lastMessageText'] ?? '').toString().trim();
      return lastText.isNotEmpty;
    }).take(2);

    for (final m in messageMatches) {
      if (!mounted || !_sessionActive) return;
      final userId = (m["userId"] ?? "").toString();
      if (userId.isEmpty) continue;
      if (ChatThreadCacheService.hasThread(userId)) continue;

      try {
        final thread = await ChatThreadCacheService.loadOnce(
            userId,
            () async =>
                (await _messagesService.getThreadPage(userId)).messages);
        if (!mounted || !_sessionActive) return;
        ChatThreadCacheService.setThread(userId, thread);
      } catch (_) {
        // tyst
      }
    }
  }

  Future<void> loadMatches({bool silent = false, bool invalidate = false}) =>
      _refresh.run(() => _performLoadMatches(silent: silent || !isLoading),
          invalidate: invalidate);

  Future<void> _performLoadMatches({bool silent = false}) async {
    if (!mounted || !_sessionActive) return;
    if (!silent) {
      setState(() {
        if (matches.isEmpty) {
          isLoading = true;
        }
        error = null;
      });
    }

    try {
      final revision = RelationChanges.revision;
      final matchesData = await _auth.getMatches();
      if (revision != RelationChanges.revision) return;
      if (!mounted || !_sessionActive) return;
      final matchesList = List<dynamic>.from(matchesData);

      _applyLocalUnreadOverride(matchesList);
      _sortMatchesInUi(matchesList);

      final chatItems = _mapMatchesToChatItems(matchesList);
      ChatRepository.instance.setChatList(chatItems);

      final hasUnread = chatItems.any((m) => m.hasUnread);
      widget.onUnreadChanged?.call(hasUnread);

      if (!mounted || !_sessionActive) return;

      final mappedForUi = _mapChatItemsToUi(chatItems);

      MatchesCacheService.setMatches(mappedForUi);

      setState(() {
        matches = mappedForUi;
        isLoading = false;
        error = null;
      });

      _precacheMatchImages(mappedForUi);
      _warmTopChatThreads(mappedForUi);
    } catch (e) {
      if (!mounted || !_sessionActive) return;

      if (!silent) {
        setState(() {
          error =
              "Kunde inte hämta dina chattar. Dra nedåt för att försöka igen.";
          isLoading = false;
        });
      }
    }
  }

  void _clearUnreadLocally(String userId) {
    ChatRepository.instance.clearUnreadForUser(userId);
    MatchesCacheService.clearUnreadForUser(userId);

    final updated = _mapChatItemsToUi(ChatRepository.instance.chatList);
    final hasUnreadAny =
        ChatRepository.instance.chatList.any((m) => m.hasUnread);

    setState(() {
      matches = updated;
    });

    widget.onUnreadChanged?.call(hasUnreadAny);
  }

  Future<void> _openChat(dynamic m) async {
    if (!_sessionActive) return;
    final userId = (m["userId"] ?? "").toString();
    final name = (m["displayName"] ?? "").toString();
    final photoUrl = (m["photoUrl"] ?? "").toString();
    final hasUnread = (m["hasUnread"] == true);
    final unreadCount = (m["unreadMessageCount"] as num?)?.toInt() ?? 0;
    final forceRefreshThread = hasUnread || unreadCount > 0;
    final lastText = (m["lastMessageText"] ?? "").toString();
    final lastMessageAtUtc = (m["lastMessageAtUtc"] ?? "").toString();

    if (userId.isEmpty) return;

    _clearUnreadLocally(userId);

    ChatCoordinator.instance.requestOpenChat(
      ChatOpenRequest(
        userId: userId,
        displayName: name.isEmpty ? 'Chat' : name,
        photoUrl: photoUrl,
        openChatsListOnExit: false,
        fromNotification: false,
        forceRefreshThread: forceRefreshThread,
        previewMessageText: forceRefreshThread ? lastText : null,
        previewMessageAtUtc: forceRefreshThread ? lastMessageAtUtc : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionActive) return const SizedBox.shrink();
    const cs = ColorScheme.light();

    final newMatches = matches.where((m) {
      final lastText = (m['lastMessageText'] ?? '').toString().trim();
      return lastText.isEmpty;
    }).toList();

    final messageMatches = matches.where((m) {
      final lastText = (m['lastMessageText'] ?? '').toString().trim();
      return lastText.isNotEmpty;
    }).toList();

    return Theme(
        data: ThemeData.light(useMaterial3: true),
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF22262E),
            title: Text(context.l10n.chats,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          ),
          body: RefreshIndicator(
            onRefresh: loadMatches,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? ListView(
                        children: [
                          const SizedBox(height: 140),
                          Center(child: Text(context.tr(error!))),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
                        children: [
                          if (newMatches.isEmpty && messageMatches.isEmpty) ...[
                            ConstrainedBox(
                                constraints: BoxConstraints(
                                    minHeight:
                                        MediaQuery.sizeOf(context).height * .7),
                                child: DiscoveryEmptyState(
                                    likes: false,
                                    onAction: CommerceEvents.openDiscovery)),
                          ] else ...[
                            if (newMatches.isNotEmpty) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    context.l10n.newMatches,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 112,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: newMatches.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 12),
                                  itemBuilder: (context, i) {
                                    final m = newMatches[i];
                                    final name =
                                        (m["displayName"] ?? "").toString();
                                    final photoUrl =
                                        (m["photoUrl"] ?? "").toString();
                                    final hasUnread = (m["hasUnread"] == true);
                                    final unreadCount =
                                        (m["unreadMessageCount"] as num?)
                                                ?.toInt() ??
                                            0;

                                    return InkWell(
                                      onTap: () => _openChat(m),
                                      borderRadius: BorderRadius.circular(18),
                                      child: SizedBox(
                                        width: 82,
                                        child: Column(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.all(2.5),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: hasUnread
                                                      ? cs.primary
                                                      : cs.primary.withValues(
                                                          alpha: 0.55),
                                                  width: 2,
                                                ),
                                              ),
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  CircleAvatar(
                                                    radius: 30,
                                                    backgroundColor: cs
                                                        .surfaceContainerHighest,
                                                    backgroundImage: photoUrl
                                                            .isNotEmpty
                                                        ? ProfileImages.avatar(
                                                            photoUrl)
                                                        : null,
                                                    child: photoUrl.isEmpty
                                                        ? Icon(
                                                            Icons.person,
                                                            color: cs.onSurface
                                                                .withValues(
                                                                    alpha: 0.7),
                                                          )
                                                        : null,
                                                  ),
                                                  if (unreadCount > 0)
                                                    Positioned(
                                                      right: -4,
                                                      top: -2,
                                                      child: _UnreadCountBadge(
                                                          count: unreadCount),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                            Text(
                              context.l10n.messages,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...List.generate(messageMatches.length, (i) {
                              final m = messageMatches[i];
                              final name = (m["displayName"] ?? "").toString();
                              final age = (m["age"] ?? 0).toString();
                              final photoUrl = (m["photoUrl"] ?? "").toString();
                              final hasUnread = (m["hasUnread"] == true);
                              final unreadCount =
                                  (m["unreadMessageCount"] as num?)?.toInt() ??
                                      0;

                              final lastText = (m['lastMessageText'] ?? '')
                                  .toString()
                                  .trim();
                              final subtitleText = lastText.isNotEmpty
                                  ? lastText
                                  : context.l10n.sayHello338;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: cs.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                      color:
                                          Colors.black.withValues(alpha: 0.06),
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  leading: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor:
                                            cs.surfaceContainerHighest,
                                        backgroundImage: photoUrl.isNotEmpty
                                            ? ProfileImages.avatar(photoUrl)
                                            : null,
                                        child: photoUrl.isEmpty
                                            ? Icon(
                                                Icons.person,
                                                color: cs.onSurface.withValues(
                                                  alpha: 0.7,
                                                ),
                                              )
                                            : null,
                                      ),
                                      if (unreadCount > 0)
                                        Positioned(
                                          right: -6,
                                          bottom: -4,
                                          child: _UnreadCountBadge(
                                              count: unreadCount),
                                        ),
                                    ],
                                  ),
                                  title: Text(
                                    "$name, $age",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: cs.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    [
                                      subtitleText,
                                      PresenceText.format(
                                          DateTime.tryParse(m['lastActivityUtc']
                                                  ?.toString() ??
                                              ''),
                                          strings: context.l10n)
                                    ]
                                        .where((text) => text.isNotEmpty)
                                        .join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: hasUnread
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      color: hasUnread
                                          ? cs.onSurface
                                          : cs.onSurface
                                              .withValues(alpha: 0.65),
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right,
                                    color: cs.onSurface.withValues(alpha: 0.45),
                                  ),
                                  onTap: () => _openChat(m),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
          ),
        ));
  }
}

class _UnreadCountBadge extends StatelessWidget {
  final int count;

  const _UnreadCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final displayText = count > 99 ? '99+' : count.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4458),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          displayText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}
