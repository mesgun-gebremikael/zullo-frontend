import 'dart:math';
import 'services/chat_merge.dart';
import 'services/thread_history.dart';
import 'services/refresh_coordinator.dart';
import 'services/account_session.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/messages_service.dart';
import '../services/auth_storage.dart';
import '../services/auth_service.dart';
import '../services/block_service.dart';
import '../services/signalr_service.dart';
import '../services/current_chat.dart';
import '../services/badge_service.dart';
import 'services/chat_cache_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/unread_sync_service.dart';
import 'services/matches_cache_service.dart';
import 'services/matches_refresh_service.dart';
import 'models/chat_message_item.dart';
import 'services/chat_repository.dart';
import 'services/chat_thread_cache_service.dart';

class ChatPage extends StatefulWidget {
  final String userId; // other user id
  final String displayName;
  final String photoUrl;
  final bool openChatsListOnExit;
  final List<dynamic>? initialThreadData;
  final String? initialMeUserId;
  final MessagesService? messagesService;
  final SignalRService? liveService;
  final Future<void> Function()? refreshBadge;

  const ChatPage({
  super.key,
  required this.userId,
  required this.displayName,
  required this.photoUrl,
  this.openChatsListOnExit = false,
  this.initialThreadData,
  this.initialMeUserId,
  this.messagesService,
  this.liveService,
  this.refreshBadge,
});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  StreamSubscription<int>? _sessionChanges;
  final int _sessionGeneration = AccountSession.generation;
  bool get _sessionActive => AccountSession.isCurrent(_sessionGeneration);

  // ✅ Endast HTTP (inte https:7015)
  static final String _baseApiUrl = AuthService.baseApiUrl;

  late final MessagesService _messagesService;
  final AuthService _authService = AuthService();
  final BlockService _blockService = BlockService();

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  
bool _isReady = false;

  DateTime? _lastLoadedAt;
 // debug/insyn

  late final SignalRService _signalRService = widget.liveService ?? SignalRService();
  late final ThreadHistory _history;
  final _threadRefresh = RefreshCoordinator();
  final _readWatermark = ReadWatermark();
  final _random = Random.secure();
  bool _loadingOlder = false;
  StreamSubscription<void>? _reconnectedSubscription;
  Future<void> _refreshBadge() => widget.refreshBadge?.call() ?? BadgeService.refreshUnreadBadge();
   StreamSubscription<Map<String, dynamic>>? _messagesReadSubscription;
   StreamSubscription<Map<String, dynamic>>? _messagesSubscription;
   StreamSubscription<ChatRepositoryState>? _repositorySubscription;

    bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  bool _showInitialPlaceholder = false;
  bool _isThreadFetchInFlight = false;
  bool _hasLoadedInitialThread = false;

  final List<_UiMessage> _messages = [];

  // ✅ Riktig "me id" från AuthStorage (JWT-login)
  String? _meUserId;

  // Mark-read guard (så vi inte spam:ar endpoint)
  bool _markReadInFlight = false;
  DateTime? _lastMarkReadAtUtc;

@override
void initState() {
  super.initState();
  _sessionChanges = AccountSession.changes.listen((_) {
    if (mounted) setState(() {});
  });

  WidgetsBinding.instance.addObserver(this);
  _messagesService = widget.messagesService ?? MessagesService(_baseApiUrl, AuthStorage());
  _history = ThreadHistory(_messagesService, widget.userId);
  _reconnectedSubscription = _signalRService.reconnectedStream.listen((_) { unawaited(_loadThread(silent: true)); });
  CurrentChat.openUserId = widget.userId;

  _isLoading = false;

_repositorySubscription =
    ChatRepository.instance.stream.listen((state) {
  if (!mounted || !_sessionActive) return;

  final repoThread = ChatRepository.instance.threadFor(widget.userId);
  if (repoThread.isEmpty) return;

  final mapped = _mapRepositoryItemsToUi(mergeChatItems(_mapUiMessagesToRepositoryItems(_messages), repoThread));

  if (_sameUiMessages(_messages, mapped)) return;

  setState(() {
    _messages
      ..clear()
      ..addAll(mapped);
    _hasLoadedInitialThread = true;
    _isLoading = false;
    _error = null;
    _showInitialPlaceholder = false;
  });
});

 
_init();
}

void _hydrateInitialUiIfAvailable() {
  if (!mounted || !_sessionActive) return;
  if (_meUserId == null || _meUserId!.isEmpty) return;

  if (widget.initialThreadData != null && widget.initialThreadData!.isNotEmpty) {
    final parsed = _parseThread(widget.initialThreadData!);

    _messages
      ..clear()
      ..addAll(parsed);

    _hasLoadedInitialThread = true;
    _isLoading = false;
    _error = null;
    _showInitialPlaceholder = false;

    ChatThreadCacheService.setThread(widget.userId, widget.initialThreadData!);
    ChatCacheService.setMessages(widget.userId, List.from(parsed));
    _pushCurrentMessagesToRepository();
    return;
  }

  final cached = ChatCacheService.getMessages(widget.userId);
  if (cached != null && cached.isNotEmpty) {
    _messages
      ..clear()
      ..addAll(cached.cast<_UiMessage>());

    _hasLoadedInitialThread = true;
    _isLoading = false;
    _error = null;
    _showInitialPlaceholder = false;

    _pushCurrentMessagesToRepository();
    return;
  }

  _showInitialPlaceholder = true;
}

 Future<void> _init() async {
  if (!_sessionActive) return;
  try {
    _meUserId = await AuthStorage().getUserId();
  } on SessionChangedException {
    return;
  }
  if (!mounted || !_sessionActive) return;

  // 1) Om meId saknas betyder det att user inte är inloggad korrekt
  if (_meUserId == null || _meUserId!.isEmpty) {
    setState(() {
      _isLoading = false;
      _error = "Du är inte inloggad (meUserId saknas). Logga in igen.";
    });
    return;
  }
  _hydrateInitialUiIfAvailable();


  UnreadSyncService.instance.markChatOpened(widget.userId);
  MatchesCacheService.clearUnreadForUser(widget.userId);
  MatchesRefreshService.instance.requestRefresh();

 


  // 3) Koppla listeners först
_messagesSubscription =
    _signalRService.messagesStream.listen((data) {
  _appendIncomingSignalRMessage(data);
});

_messagesReadSubscription =
    _signalRService.messagesReadStream.listen((data) {
  _applyLiveReadReceipt(data);
});


 // 4) Starta första thread-load direkt
unawaited(Future(() async {
  try {
    await _loadThread(silent: true);
  } catch (_) {
    // ignore i MVP
  }
}));

// 5) Koppla SignalR i bakgrunden utan att blockera första öppningen
unawaited(Future(() async {
  try {
    await _signalRService.connect();
  } catch (_) {
    // ignore i MVP
  }
}));

  // 6) MarkRead + badge i bakgrunden
  unawaited(Future(() async {
    try {
      await _messagesService.markRead(widget.userId);
      MatchesRefreshService.instance.requestRefresh();
      await _refreshBadge();
    } catch (_) {
      // ignore i MVP
    }
  }));

  setState(() {
  _isReady = true;
});

}


   @override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _reconnectedSubscription?.cancel();
  _sessionChanges?.cancel();
  if (CurrentChat.openUserId == widget.userId) {
    CurrentChat.openUserId = null;
  }

 _messagesSubscription?.cancel();
_messagesReadSubscription?.cancel();
_repositorySubscription?.cancel();
_controller.dispose();
_scroll.dispose();
unawaited(_signalRService.dispose());
super.dispose();

}



  void _handleBackNavigation() {
  Navigator.pop(context, true);
}

  Future<bool> _markReadIfNeeded(List<_UiMessage> parsed) async {
    // Finns inkommande olästa messages?
    final hasIncomingUnread =
        parsed.any((m) => !m.isMe && m.readAtLocal == null);
    if (!hasIncomingUnread) return false;

    // Guard: om vi nyligen körde markRead, hoppa över
    final nowUtc = DateTime.now().toUtc();
    if (_markReadInFlight) return false;
    if (_lastMarkReadAtUtc != null &&
        nowUtc.difference(_lastMarkReadAtUtc!).inSeconds < 2) {
      return false;
    }

    _markReadInFlight = true;
    _lastMarkReadAtUtc = nowUtc;

    try {
      await _messagesService.markRead(widget.userId);
      return true;
    } catch (_) {
      // ignore i MVP
      return false;
    } finally {
      _markReadInFlight = false;
    }
  }

  List<_UiMessage> _parseThread(dynamic data) {
    final parsed = <_UiMessage>[];
    final meId = _meUserId ?? "";

    for (final m in data) {
      // Backend shape:
      // { id, fromUserId, toUserId, text, createdAtUtc, readAtUtc }

      final text = (m['text'] ?? '').toString();
      final fromUserId = (m['fromUserId'] ?? '').toString();

      // createdAtUtc -> local
      final createdUtcRaw = m['createdAtUtc'];

      final createdLocal = _parseUtcStringToLocal(createdUtcRaw) ?? DateTime.now();


      // readAtUtc -> local (valfri)
     DateTime? readAtLocal;
      final readAtUtcRaw = m['readAtUtc'];
    if (readAtUtcRaw != null) {
     readAtLocal = _parseUtcStringToLocal(readAtUtcRaw);
}


    parsed.add(
  _UiMessage(
    text: text,
    isMe: fromUserId == meId,
    timeLocal: createdLocal,
    readAtLocal: readAtLocal,
    pending: m['pending'] == true,
    failed: m['failed'] == true,
    clientMessageId: (m['clientMessageId'] ?? '').toString(),
    serverId: m['id']?.toString(), sequence: (m['sequence'] as num?)?.toInt(),
  ),
);

    }

    parsed.sort((a, b) => a.timeLocal.compareTo(b.timeLocal));
    return parsed;
  }

  List<ChatMessageItem> _mapUiMessagesToRepositoryItems(List<_UiMessage> list) {
  return list
      .map(
        (m) => ChatMessageItem(
          text: m.text,
          isMe: m.isMe,
          timeLocal: m.timeLocal,
          readAtLocal: m.readAtLocal,
          pending: m.pending,
          failed: m.failed,
          clientMessageId: m.clientMessageId,
          serverId: m.serverId, sequence: m.sequence,
        ),
      )
      .toList();
}

List<_UiMessage> _mapRepositoryItemsToUi(List<ChatMessageItem> list) {
  return list
      .map(
        (m) => _UiMessage(
          text: m.text,
          isMe: m.isMe,
          timeLocal: m.timeLocal,
          readAtLocal: m.readAtLocal,
          pending: m.pending,
          failed: m.failed,
          clientMessageId: m.clientMessageId,
          serverId: m.serverId, sequence: m.sequence,
        ),
      )
      .toList();
}

bool _sameUiMessages(List<_UiMessage> a, List<_UiMessage> b) {
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    final x = a[i];
    final y = b[i];

    if (x.text != y.text) return false;
    if (x.isMe != y.isMe) return false;
    if (x.clientMessageId != y.clientMessageId) return false;
    if (x.timeLocal != y.timeLocal) return false;
    if (x.readAtLocal != y.readAtLocal) return false;
    if (x.pending != y.pending) return false;
    if (x.failed != y.failed) return false;
    if (x.serverId != y.serverId || x.sequence != y.sequence) return false;
  }

  return true;
}

void _pushCurrentMessagesToRepository() {
  if (!mounted || !_sessionActive) return;
  final repoItems = _mapUiMessagesToRepositoryItems(_messages);
  ChatRepository.instance.setThread(widget.userId, repoItems);
}

void _updateRepositoryLastMessage({
  required String text,
  required DateTime messageTimeLocal,
  required bool incrementUnread,
}) {
  if (!mounted || !_sessionActive) return;
  ChatRepository.instance.updateLastMessage(
    userId: widget.userId,
    text: text,
    messageTimeUtc: messageTimeLocal.toUtc(),
    incrementUnread: incrementUnread,
  );
}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && _sessionActive) {
      unawaited(_signalRService.connect().catchError((Object _) {}));
      unawaited(_loadThread(silent: true));
    }
  }

  Future<void> _loadThread({bool silent = false}) =>
      _threadRefresh.run(() => _performLoadThread(silent: silent), invalidate: true);

  Future<void> _loadOlder() async {
    if (_loadingOlder || !mounted || !_sessionActive) return;
    setState(() => _loadingOlder = true);
    try {
      final rows = await _history.loadOlder();
      if (!mounted || !_sessionActive) return;
      _mergeSnapshot(rows);
    } catch (_) {
      if (mounted && _sessionActive) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kunde inte hämta äldre meddelanden. Försök igen.')));
    } finally {
      if (mounted && _sessionActive) setState(() => _loadingOlder = false);
    }
  }

  List<_UiMessage> _mergeSnapshot(List<dynamic> rows) {
    final merged = mergeChatItems(_mapUiMessagesToRepositoryItems(_messages),
        _mapUiMessagesToRepositoryItems(_parseThread(rows)));
    _readWatermark.accept(_history.outgoingReadThrough, _history.outgoingReadAtUtc);
    final updated = merged.map(_readWatermark.apply).toList();
    final parsed = _mapRepositoryItemsToUi(updated);
    setState(() { _messages..clear()..addAll(parsed); });
    ChatCacheService.setMessages(widget.userId, List.from(parsed));
    ChatThreadCacheService.setThread(widget.userId, rows);
    _pushCurrentMessagesToRepository();
    return parsed;
  }

  Future<void> _performLoadThread({bool silent = false}) async {
    if (!mounted || !_sessionActive) return;
    _isThreadFetchInFlight = true;
    try {
      final rows = await _history.synchronize();
      if (!mounted || !_sessionActive) return;
      final didMarkRead = await _markReadIfNeeded(_parseThread(rows));
      if (!mounted || !_sessionActive) return;
      // Merge after all awaits so a live arrival or pending send cannot be erased.
      final shouldStick = !_hasLoadedInitialThread || _isNearBottom();
      final parsed = _mergeSnapshot(rows);
      setState(() {
        _error = null;
        _isLoading = false;
        _showInitialPlaceholder = false;
      });
      if (parsed.isNotEmpty) {
        final last = parsed.last;
        _updateRepositoryLastMessage(text: last.text, messageTimeLocal: last.timeLocal, incrementUnread: false);
      }
      if (didMarkRead) {
        MatchesRefreshService.instance.requestRefresh();
        unawaited(_refreshBadge().catchError((Object _) {}));
      }
      _lastLoadedAt = DateTime.now();
      if (shouldStick) _scrollToBottom(animated: _hasLoadedInitialThread);
      _hasLoadedInitialThread = true;
    } catch (error) {
      if (!mounted || !_sessionActive) return;
      setState(() {
        _error = error is ChatRequestException ? error.message : 'Kunde inte synkronisera chatten. Försök igen.';
        _isLoading = false;
        if (error is ChatRequestException && (error.statusCode == 401 || error.statusCode == 403)) _isReady = false;
      });
    } finally {
      _isThreadFetchInFlight = false;
    }
  }

   void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;

      const target = 0.0;

      if (!animated) {
        _scroll.jumpTo(target);
        return;
      }

      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }



     bool _isNearBottom() {
    if (!_scroll.hasClients) return true;
    return _scroll.position.pixels < 120;
  }


 Future<void> _send() async {
  if (!_sessionActive) return;
  if (!_isReady) return;

  final text = _controller.text.trim();
  if (text.isEmpty || _isSending) return;


  _controller.clear();

  // 🔥 skapa unikt id
  final clientMessageId = List<int>.generate(16, (_) => _random.nextInt(256)).map((n) => n.toRadixString(16).padLeft(2, '0')).join();

  final optimistic = _UiMessage(
    text: text,
    isMe: true,
    timeLocal: DateTime.now(),
    readAtLocal: null,
    pending: true,
    failed: false,
    clientMessageId: clientMessageId,
  );

  setState(() {
    _isSending = true;
    _messages.add(optimistic);
  });

  _pushCurrentMessagesToRepository();
  _updateRepositoryLastMessage(
  text: text,
  messageTimeLocal: optimistic.timeLocal,
  incrementUnread: false,
);

  _scrollToBottom();

  await _deliverMessage(clientMessageId, text);
}

Future<void> _retryMessage(_UiMessage message) async {
  if (!_sessionActive || !mounted || !_isReady || _isSending || !message.failed) return;
  final index = _messages.indexWhere((m) => m.isMe && m.clientMessageId == message.clientMessageId && m.failed);
  if (index < 0) return;
  setState(() {
    _isSending = true;
    _messages[index] = _messages[index].copyWith(pending: true, failed: false);
  });
  _pushCurrentMessagesToRepository();
  await _deliverMessage(message.clientMessageId, message.text);
}

Future<void> _deliverMessage(String clientMessageId, String text) async {
  try {
    final sent = await _messagesService.sendMessage(
      toUserId: widget.userId,
      text: text,
      clientMessageId: clientMessageId,
    );

    final sentCreatedAtLocal =
        _parseUtcStringToLocal(sent['createdAtUtc']) ?? DateTime.now();

    if (!mounted || !_sessionActive) return;

   setState(() {
  final idx = _messages.indexWhere(
    (m) => m.clientMessageId == clientMessageId,
  );

  if (idx != -1) {
    final existing = _messages[idx];

    _messages[idx] = _UiMessage(
      serverId: sent['id']?.toString(), sequence: (sent['sequence'] as num?)?.toInt(),
      text: text,
      isMe: true,
      timeLocal: sentCreatedAtLocal,
      readAtLocal: sent['readAtUtc'] != null
          ? _parseUtcStringToLocal(sent['readAtUtc'])
          : existing.readAtLocal ?? (((sent['sequence'] as num?)?.toInt() ?? 0) > 0 &&
              _readWatermark.through != null && (sent['sequence'] as num).toInt() <= _readWatermark.through!
              ? _readWatermark.at : null),
      pending: false,
      failed: false,
      clientMessageId: clientMessageId,
    );
  }
});


  ChatCacheService.setMessages(widget.userId, List.from(_messages));
  ChatThreadCacheService.clearThread(widget.userId);
_pushCurrentMessagesToRepository();
_updateRepositoryLastMessage(
  text: text,
  messageTimeLocal: sentCreatedAtLocal,
  incrementUnread: false,
);
_scrollToBottom();

  } catch (e) {
  if (!mounted || !_sessionActive) return;

  setState(() {
    if (e is ChatRequestException && (e.statusCode == 401 || e.statusCode == 403)) _isReady = false;
    final idx = _messages.indexWhere(
      (m) => m.clientMessageId == clientMessageId,
    );

    if (idx != -1) {
      _messages[idx] =
          _messages[idx].copyWith(pending: false, failed: true);
    }
  });

  _pushCurrentMessagesToRepository();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("Kunde inte skicka: $e")),
  );
}
  finally {
    if (mounted) {
      setState(() => _isSending = false);
    }
  }
}


Future<void> _blockUser() async {
  if (!_sessionActive) return;
  try {
    await _blockService.blockUser(widget.userId);

    if (!mounted || !_sessionActive) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Användaren blockerades.")),
    );

    Navigator.pop(context, true);
  } catch (e) {
    if (!mounted || !_sessionActive) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Kunde inte blockera: $e")),
    );
  }
}

Future<void> _showReportDialog() async {
  if (!_sessionActive) return;
  final reasons = [
    "Spam",
    "Otrevlig",
    "Fejkprofil",
    "Nakenbild",
    "Annat",
  ];

  String selectedReason = reasons.first;

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text("Rapportera användare"),
        content: StatefulBuilder(
          builder: (context, setLocalState) {
            return DropdownButton<String>(
              value: selectedReason,
              isExpanded: true,
              items: reasons.map((r) {
                return DropdownMenuItem(
                  value: r,
                  child: Text(r),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setLocalState(() => selectedReason = value);
              },
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Avbryt"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, selectedReason),
            child: const Text("Rapportera"),
          ),
        ],
      );
    },
  );

  if (result == null || result.isEmpty) return;

  try {
    await _authService.reportUser(
      reportedUserId: widget.userId,
      reason: result,
    );

    if (!mounted || !_sessionActive) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Användaren har rapporterats.")),
    );
  } catch (e) {
    if (!mounted || !_sessionActive) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Kunde inte rapportera: $e")),
    );
  }
}
  //----

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _two(int n) => n.toString().padLeft(2, '0');
  String _formatTime(DateTime dt) => "${_two(dt.hour)}:${_two(dt.minute)}";

  String _formatDateSw(DateTime dt) {
    const months = [
      "jan", "feb", "mar", "apr", "maj", "jun",
      "jul", "aug", "sep", "okt", "nov", "dec"
    ];
    final m = months[(dt.month - 1).clamp(0, 11)];
    return "${dt.day} $m ${dt.year}";
  }

   DateTime? _parseUtcStringToLocal(dynamic raw) {
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
    
    void _appendIncomingSignalRMessage(Map<String, dynamic> data) {
  if (!mounted || !_sessionActive) return;
  final fromUserId = (data['fromUserId'] ?? '').toString();
  final toUserId = (data['toUserId'] ?? '').toString();
  final text = (data['text'] ?? '').toString().trim();
  final clientMessageId = (data['clientMessageId'] ?? '').toString();

  if (text.isEmpty) return;

  final isIncoming =
      fromUserId == widget.userId && toUserId == (_meUserId ?? '');

  final isOwn = fromUserId == (_meUserId ?? '') && toUserId == widget.userId;
  if (!isIncoming && !isOwn) return;

  final createdAtLocal =
      _parseUtcStringToLocal(data['createdAtUtc']) ?? DateTime.now();

  final serverId = data['id']?.toString();
  if (_messages.any((m) => serverId != null && m.serverId == serverId && !m.pending)) return;
  final message = _UiMessage(
    serverId: serverId, sequence: (data['sequence'] as num?)?.toInt(),
    text: text, isMe: isOwn, timeLocal: createdAtLocal,
    readAtLocal: _parseUtcStringToLocal(data['readAtUtc']),
    pending: false, failed: false, clientMessageId: clientMessageId,
  );
  final merged = mergeChatItems(_mapUiMessagesToRepositoryItems(_messages), _mapUiMessagesToRepositoryItems([message]))
      .map(_readWatermark.apply).toList();
  setState(() {
    _messages..clear()..addAll(_mapRepositoryItemsToUi(merged));
    _error = null;
    _isLoading = false;
  });

ChatCacheService.setMessages(widget.userId, List.from(_messages));
ChatThreadCacheService.clearThread(widget.userId);
_pushCurrentMessagesToRepository();
_updateRepositoryLastMessage(
  text: text,
  messageTimeLocal: createdAtLocal,
  incrementUnread: false,
);
_scrollToBottom();

  if (!isIncoming) return;
  Future(() async {
    try {
      await _messagesService.markRead(widget.userId);
      MatchesRefreshService.instance.requestRefresh();
      await _refreshBadge();
    } catch (_) {
      // ignore i MVP
    }
  });
}


 void _applyLiveReadReceipt(Map<String, dynamic> data) {
  if (!mounted || !_sessionActive) return;
  final chatUserId = (data['chatUserId'] ?? '').toString();

  if (chatUserId != widget.userId) return;

  final readAtLocal =
      _parseUtcStringToLocal(data['readAtUtc']) ?? DateTime.now();

  _readWatermark.accept((data['readThroughSequence'] as num?)?.toInt(), readAtLocal);
  final serverIds = (data['messageIds'] as List?)?.map((id) => id.toString()).toSet();
  final clientIds = (data['clientMessageIds'] as List?)?.map((id) => id.toString()).toSet();
  setState(() {
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];

      final included = _readWatermark.through != null
          ? m.sequence != null && m.sequence! <= _readWatermark.through!
          : serverIds != null ? serverIds.contains(m.serverId) || (m.serverId == null && clientIds?.contains(m.clientMessageId) == true)
          : !m.timeLocal.toUtc().isAfter(readAtLocal.toUtc());
      if (m.isMe && m.readAtLocal == null && included) {
        _messages[i] = m.copyWith(readAtLocal: _readWatermark.at ?? readAtLocal);
      }
    }
  });

ChatCacheService.setMessages(widget.userId, List.from(_messages));
ChatThreadCacheService.clearThread(widget.userId);
_pushCurrentMessagesToRepository();
}



  @override
   Widget build(BuildContext context) {
    if (!_sessionActive) return const SizedBox.shrink();
  // bara för att inte “unused”-varnas
  final _ = _lastLoadedAt;

  final scheme = Theme.of(context).colorScheme;

  return PopScope<bool>(
  canPop: false,
  onPopInvokedWithResult: (didPop, result) {
    if (didPop) return;
    _handleBackNavigation();
  },
  child: Scaffold(
    appBar: AppBar(
            leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _handleBackNavigation,
      ),
     actions: [
  PopupMenuButton<String>(
    onSelected: (value) {
      if (value == "report") {
        _showReportDialog();
      }

      if (value == "block") {
        _blockUser();
      }
    },
    itemBuilder: (context) => const [
      PopupMenuItem(
        value: "report",
        child: Text("Rapportera"),
      ),
      PopupMenuItem(
        value: "block",
        child: Text("Blockera"),
      ),
    ],
  ),
],
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.surfaceContainerHighest,
           backgroundImage:
    widget.photoUrl.isNotEmpty
        ? CachedNetworkImageProvider(widget.photoUrl)
        : null,
child: widget.photoUrl.isEmpty
    ? Icon(Icons.person, color: scheme.onSurface.withValues(alpha: 0.75))
    : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.displayName,
              overflow: TextOverflow.ellipsis,
            ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
             child: _error != null
    ? Center(child: Text(_error!))
    : Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await _loadThread();
            },
        child: _messages.isEmpty
    ? ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 140),
          Center(
            child: _showInitialPlaceholder
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _hasLoadedInitialThread
                    ? const Text("Säg hej 👋")
                    : const SizedBox.shrink(),
          ),
        ],
      )
    : ListView.builder(
            controller: _scroll,
            reverse: true,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            itemCount: _messages.length + (_history.hasOlder ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _messages.length) {
                return TextButton(
                onPressed: _loadingOlder || _isThreadFetchInFlight ? null : _loadOlder,
                child: Text(_loadingOlder ? 'Hämtar…' : 'Visa äldre meddelanden'),
              );
              }
              final reversedIndex = _messages.length - 1 - i;
              final m = _messages[reversedIndex];

              final showDateChip = reversedIndex == 0
                  ? true
                  : !_isSameDay(
                      _messages[reversedIndex - 1].timeLocal,
                      m.timeLocal,
                    );

              return Column(
                children: [
                  _MessageBubble(
                    text: m.text,
                    isMe: m.isMe,
                    timeText: _formatTime(m.timeLocal),
                    pending: m.pending,
                    failed: m.failed,
                    readAtLocal: m.readAtLocal,
                  ),
                  if (m.failed && m.isMe) TextButton(
                    onPressed: _isSending || !_isReady ? null : () => _retryMessage(m),
                    child: const Text('Skicka igen'),
                  ),
                  if (showDateChip) ...[
                    const SizedBox(height: 8),
                    _DateChip(text: _formatDateSw(m.timeLocal)),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),

          ),
  

        ],
    ),
      ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: "Skriv ett meddelande…",
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest.withOpacity(0.55),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 46,
                    width: 46,
                    child: ElevatedButton(
                     onPressed: (_isSending || !_isReady) ? null : _send,

                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Icon(Icons.send),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
  //----------------------------------------------------------
}
//--------------------------------------------------------
class _UiMessage {
  final String? serverId;
  final int? sequence;
  final String text;
  final bool isMe;
  final DateTime timeLocal;

  final DateTime? readAtLocal;

  final bool pending;
  final bool failed;

  // 🔥 NYTT – kopplar message till backend
  final String clientMessageId;

  const _UiMessage({
    this.serverId,
    this.sequence,
    required this.text,
    required this.isMe,
    required this.timeLocal,
    required this.readAtLocal,
    required this.pending,
    required this.failed,
    required this.clientMessageId,
  });

  _UiMessage copyWith({
    bool? pending,
    bool? failed,
    DateTime? readAtLocal,
  }) =>
      _UiMessage(
        serverId: serverId, sequence: sequence,
        text: text,
        isMe: isMe,
        timeLocal: timeLocal,
        readAtLocal: readAtLocal ?? this.readAtLocal,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
        clientMessageId: clientMessageId,
      );
}


class _DateChip extends StatelessWidget {
  final String text;
  const _DateChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.70),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withOpacity(0.70),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String timeText;
  final bool pending;
  final bool failed;

  final DateTime? readAtLocal;

  const _MessageBubble({
    required this.text,
    required this.isMe,
    required this.timeText,
    required this.pending,
    required this.failed,
    required this.readAtLocal,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bubbleColor = isMe
        ? scheme.primary.withOpacity(0.12)
        : scheme.surfaceContainerHighest.withOpacity(0.85);

    final timeColor = scheme.onSurface.withOpacity(0.55);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(text),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
  timeText,
  style: TextStyle(
    fontSize: 10.5,
    color: timeColor,
    fontWeight: FontWeight.w500,
  ),
),

                if (pending) ...[
                  const SizedBox(width: 6),
                  Text("Skickar…",
                      style: TextStyle(fontSize: 11, color: timeColor)),
                ] else if (failed) ...[
                  const SizedBox(width: 6),
                  Text(
                    "Misslyckades",
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.error.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else if (isMe) ...[
                  const SizedBox(width: 6),
                  Text(
  readAtLocal != null ? "Sedd" : "Levererad",
  style: TextStyle(
    fontSize: 10.5,
    color: readAtLocal != null
        ? scheme.primary.withOpacity(0.92)
        : timeColor,
    fontWeight: readAtLocal != null
        ? FontWeight.w700
        : FontWeight.w500,
    letterSpacing: 0.1,
  ),
),

                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}