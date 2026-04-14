 import 'dart:async';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/signalr_service.dart';
import 'chat_page.dart';
import 'premium_page.dart';
import 'services/unread_sync_service.dart';
import 'services/chat_coordinator.dart';
import 'models/chat_open_request.dart';
import 'services/matches_cache_service.dart';
import 'services/matches_refresh_service.dart';
import 'services/matches_cache_service.dart';
import 'package:cached_network_image/cached_network_image.dart';


class MatchesPage extends StatefulWidget {
  final ValueChanged<bool>? onUnreadChanged;

  const MatchesPage({
    super.key,
    this.onUnreadChanged,
  });


  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  final AuthService _auth = AuthService();
  final SignalRService _signalRService = SignalRService();
  StreamSubscription<String>? _openedChatSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
//StreamSubscription<Map<String, dynamic>>? _messagesReadSubscription;
bool _signalRConnected = false;
StreamSubscription<void>? _refreshSubscription;

  bool isLoading = true;
  String? error;
  List<dynamic> matches = [];
  List<dynamic> likesReceived = [];


  @override
void initState() {
  super.initState();

  final cachedMatches = MatchesCacheService.getMatches();
  final cachedLikes = MatchesCacheService.getLikesReceived();

  if (cachedMatches != null && cachedLikes != null) {
    matches = List<dynamic>.from(cachedMatches);
    likesReceived = List<dynamic>.from(cachedLikes);
    isLoading = false;
  }

  loadMatches(silent: cachedMatches != null && cachedLikes != null);
  _refreshSubscription =
    MatchesRefreshService.instance.stream.listen((_) async {
  if (!mounted) return;
  await loadMatches(silent: true);
});

  _openedChatSubscription =
      UnreadSyncService.instance.openedChatStream.listen((userId) {
    if (!mounted) return;
    _clearUnreadLocally(userId);
  });

  if (widget.onUnreadChanged != null) {
    _setupSignalR();
  }
}

   Future<void> _setupSignalR() async {
  await _signalRService.connect();
  _signalRConnected = true;

  _messageSubscription = _signalRService.messagesStream.listen((data) async {
    if (!mounted) return;
    await loadMatches(silent: true);
  });

 // _messagesReadSubscription = _signalRService.messagesReadStream.listen((data) async {
   // if (!mounted) return;
   // await loadMatches(silent: true);
 // });
}




@override
void dispose() {
  _openedChatSubscription?.cancel(); // NYTT
  _messageSubscription?.cancel();
   _refreshSubscription?.cancel();
  if (_signalRConnected) {
    _signalRService.disconnect();
  }

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

  void _precacheMatchImages(List<dynamic> list) {
  if (!mounted) return;

  for (final m in list.take(12)) {
    final photoUrl = (m["photoUrl"] ?? "").toString().trim();
    if (photoUrl.isEmpty) continue;

    precacheImage(
      CachedNetworkImageProvider(photoUrl),
      context,
    );
  }
}

   Future<void> loadMatches({bool silent = false}) async {
    if (!silent) {
      setState(() {
        if (matches.isEmpty && likesReceived.isEmpty) {
          isLoading = true;
        }
        error = null;
      });
    }

    try {
      final matchesData = await _auth.getMatches();
final matchesList = List<dynamic>.from(matchesData);

_applyLocalUnreadOverride(matchesList);
_sortMatchesInUi(matchesList);

final hasUnread = matchesList.any((m) => m['hasUnread'] == true);
widget.onUnreadChanged?.call(hasUnread);

      final likesData = await _auth.getLikesReceived();
      final likesList = List<dynamic>.from(likesData);

     if (!mounted) return;

MatchesCacheService.setData(
  matches: matchesList,
  likesReceived: likesList,
);

setState(() {
  matches = matchesList;
  likesReceived = likesList;
  isLoading = false;
  error = null;
});

_precacheMatchImages(matchesList);
    } catch (e) {
      if (!mounted) return;

      if (!silent) {
        setState(() {
          error = "Kunde inte ladda matches: $e";
          isLoading = false;
        });
      }
    }
  }

  void _clearUnreadLocally(String userId) {
  bool changed = false;

  for (final m in matches) {
    final currentUserId = (m["userId"] ?? "").toString();
    if (currentUserId != userId) continue;

    if (m["hasUnread"] == true || ((m["unreadMessageCount"] as num?)?.toInt() ?? 0) > 0) {
      m["hasUnread"] = false;
      m["unreadMessageCount"] = 0;
      changed = true;
    }
  }

  if (!changed) return;

  final hasUnreadAny = matches.any((m) => m["hasUnread"] == true);

  setState(() {});
  widget.onUnreadChanged?.call(hasUnreadAny);
}

  Future<void> _openChat(dynamic m) async {
  final userId = (m["userId"] ?? "").toString();
  final name = (m["displayName"] ?? "").toString();
  final photoUrl = (m["photoUrl"] ?? "").toString();

  if (userId.isEmpty) return;

  _clearUnreadLocally(userId);

  ChatCoordinator.instance.requestOpenChat(
    ChatOpenRequest(
      userId: userId,
      displayName: name.isEmpty ? 'Chat' : name,
      photoUrl: photoUrl,
      openChatsListOnExit: false,
      fromNotification: false,
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final newMatches = matches.where((m) {
                        final lastText = (m['lastMessageText'] ?? '').toString().trim();
                        return lastText.isEmpty;
                       }).toList();

                      final messageMatches = matches.where((m) {
                         final lastText = (m['lastMessageText'] ?? '').toString().trim();
                         return lastText.isNotEmpty;
                       }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Matches"),
      ),
      body: RefreshIndicator(
        onRefresh: loadMatches,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 140),
                      Center(child: Text(error!)),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                    children: [
                      // ✅ LIKES (Premium-lås i MVP)
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PremiumPage(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.55,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  likesReceived.isEmpty
                                      ? "Inga nya likes än"
                                      : "${likesReceived.length} personer har gillat dig — Premium för att se vem",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      

                      if (newMatches.isEmpty && messageMatches.isEmpty) ...[
                        const SizedBox(height: 140),
                        const Center(child: Text("Inga matches än")),
                      ] else ...[
                       if (newMatches.isNotEmpty) ...[
  Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: const [
      Text(
        "New Matches",
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
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, i) {
        final m = newMatches[i];
        final name = (m["displayName"] ?? "").toString();
        final photoUrl = (m["photoUrl"] ?? "").toString();
        final hasUnread = (m["hasUnread"] == true);
        final unreadCount = (m["unreadMessageCount"] as num?)?.toInt() ?? 0;


        return InkWell(
          onTap: () => _openChat(m),
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 82,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasUnread
                          ? cs.primary
                          : cs.primary.withValues(alpha: 0.55),
                      width: 2,
                    ),
                  ),
                 child: Stack(
  clipBehavior: Clip.none,
  children: [
    CircleAvatar(
      radius: 30,
      backgroundColor: cs.surfaceContainerHighest,
      backgroundImage:
    photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
      child: photoUrl.isEmpty
          ? Icon(
              Icons.person,
              color: cs.onSurface.withValues(alpha: 0.7),
            )
          : null,
    ),
    if (unreadCount > 0)
      Positioned(
        right: -4,
        top: -2,
        child: _UnreadCountBadge(count: unreadCount),
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
                       const Text(
  "Messages",
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
                          final photoUrl =
                              (m["photoUrl"] ?? "").toString();
                          final hasUnread = (m["hasUnread"] == true);
                          final unreadCount = (m["unreadMessageCount"] as num?)?.toInt() ?? 0;


                          final lastText =
                              (m['lastMessageText'] ?? '').toString().trim();
                          final subtitleText =
                              lastText.isNotEmpty ? lastText : "Säg hej 👋";

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 18,
                                  spreadRadius: 1,
                                  color: Colors.black.withValues(alpha: 0.06),
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
    ? CachedNetworkImageProvider(photoUrl)
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
    child: _UnreadCountBadge(count: unreadCount),
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
                                subtitleText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: hasUnread
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  color: hasUnread
                                      ? cs.onSurface
                                      : cs.onSurface.withValues(alpha: 0.65),
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
    );
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
