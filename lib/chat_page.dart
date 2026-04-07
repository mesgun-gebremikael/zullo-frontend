import 'dart:async';
import 'package:flutter/material.dart';
import 'main_navigation.dart';
import '../services/messages_service.dart';
import '../services/auth_storage.dart';
import '../services/auth_service.dart';
import '../services/block_service.dart';
import '../services/current_chat.dart';

class ChatPage extends StatefulWidget {
  final String userId; // other user id
  final String displayName;
  final String photoUrl;
  final bool openChatsListOnExit;

  const ChatPage({
    super.key,
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    this.openChatsListOnExit = false,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // ✅ Endast HTTP (inte https:7015)
  static const String _baseApiUrl = 'http://10.0.2.2:5125';

  late final MessagesService _messagesService;
  final AuthService _authService = AuthService();
  final BlockService _blockService = BlockService();

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  

  Timer? _pollTimer;
  DateTime? _lastLoadedAt; // debug/insyn

    bool _isLoading = true;
  bool _isSending = false;
  String? _error;
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
    _messagesService = MessagesService(_baseApiUrl, AuthStorage());

    CurrentChat.openUserId = widget.userId;

    // 0) Hämta meId först, sen load
    _init();
  }

  Future<void> _init() async {
   _meUserId = await AuthStorage().getUserId();

    // Om meId saknas betyder det att user inte är inloggad korrekt
    if (_meUserId == null || _meUserId!.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = "Du är inte inloggad (meUserId saknas). Logga in igen.";
      });
      return;
    }

    // 1) Ladda tråd (inkl smart markRead om behövs)
       // 1) Ladda tråd en gång
    await _loadThread();

    // 2) Markera som läst direkt, men ladda inte om hela tråden igen här
    try {
      await _messagesService.markRead(widget.userId);
    } catch (_) {
      // ignore i MVP
    }

    // 2) Poll (MVP): bara hämta tråd
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_isThreadFetchInFlight) return;
      _loadThread(silent: true);


  print("NOW local: ${DateTime.now()}");
print("TIMEZONE name: ${DateTime.now().timeZoneName}");
print("TIMEZONE offset: ${DateTime.now().timeZoneOffset}");

});
  }

    @override
  void dispose() {
    if (CurrentChat.openUserId == widget.userId) {
      CurrentChat.openUserId = null;
    }

    _controller.dispose();
    _scroll.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

    void _handleBackNavigation() {
    if (widget.openChatsListOnExit) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigation(initialIndex: 3),
        ),
        (route) => false,
      );
      return;
    }

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
      print("RAW createdAtUtc: $createdUtcRaw");
      print("RAW readAtUtc: ${m['readAtUtc']}");

      final createdLocal = _parseUtcStringToLocal(createdUtcRaw) ?? DateTime.now();
       print("PARSED createdLocal: $createdLocal");


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
          pending: false,
          failed: false,
        ),
      );
    }

    parsed.sort((a, b) => a.timeLocal.compareTo(b.timeLocal));
    return parsed;
  }

  Future<void> _loadThread({bool silent = false}) async {
      if (_isThreadFetchInFlight) return;
    _isThreadFetchInFlight = true; 

   
if (!silent) {
  setState(() {
    //  visa inte loading om vi redan har UI
    _error = null;
  });
} 


    try {
      final data = await _messagesService.getThread(widget.userId);
      final parsed = _parseThread(data);

      await _markReadIfNeeded(parsed);

      if (!mounted) return;

      setState(() {
        _messages
          ..clear()
          ..addAll(parsed);
        _isLoading = false;
        _error = null;
      });

      
               final shouldStickToBottom = !_hasLoadedInitialThread || _isNearBottom();

      _lastLoadedAt = DateTime.now();

      if (shouldStickToBottom) {
        _scrollToBottom(animated: _hasLoadedInitialThread);
      }

      _hasLoadedInitialThread = true;

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Kunde inte ladda chat: $e";
        _isLoading = false;
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
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _controller.clear();

    // 1) Optimistic (Tinder-känsla)
    final optimistic = _UiMessage(
      text: text,
      isMe: true,
      timeLocal: DateTime.now(),
      readAtLocal: null,
      pending: true,
      failed: false,
    );

    setState(() {
      _isSending = true;
      _messages.add(optimistic);
    });

    _scrollToBottom();

    try {
      await _messagesService.sendMessage(
        toUserId: widget.userId,
        text: text,
      );

      await _loadThread();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        final idx = _messages.lastIndexWhere((m) => identical(m, optimistic));
        if (idx != -1) {
          _messages[idx] =
              _messages[idx].copyWith(pending: false, failed: true);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kunde inte skicka: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

Future<void> _blockUser() async {
  try {
    await _blockService.blockUser(widget.userId);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Användaren blockerades.")),
    );

    Navigator.pop(context, true);
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Kunde inte blockera: $e")),
    );
  }
}

Future<void> _showReportDialog() async {
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

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Användaren har rapporterats.")),
    );
  } catch (e) {
    if (!mounted) return;
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


  @override
   Widget build(BuildContext context) {
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
    widget.photoUrl.isNotEmpty ? NetworkImage(widget.photoUrl) : null,
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
                    children: const [
                      SizedBox(height: 140),
                      Center(child: Text("Säg hej 👋")),
                    ],
                  )
                : ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
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
  if (_isLoading && _messages.isEmpty)
  const Positioned(
    top: 10,
    left: 0,
    right: 0,
    child: Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
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
                      onPressed: _isSending ? null : _send,
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
  final String text;
  final bool isMe;
  final DateTime timeLocal;

  final DateTime? readAtLocal;

  final bool pending;
  final bool failed;

  const _UiMessage({
    required this.text,
    required this.isMe,
    required this.timeLocal,
    required this.readAtLocal,
    required this.pending,
    required this.failed,
  });

  _UiMessage copyWith({bool? pending, bool? failed, DateTime? readAtLocal}) =>
      _UiMessage(
        text: text,
        isMe: isMe,
        timeLocal: timeLocal,
        readAtLocal: readAtLocal ?? this.readAtLocal,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
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