import 'dart:convert';
import 'messages_service.dart';

String? messageCursor(Map message) {
  final sequence = message['sequence'];
  if (sequence is! num || sequence <= 0) return null;
  return base64Url
      .encode(utf8.encode(jsonEncode({'sequence': sequence.toInt()})))
      .replaceAll('=', '');
}

List<dynamic> mergeThreadRows(List<dynamic> oldRows, List<dynamic> newRows) {
  final rows = <String, Map<String, dynamic>>{};
  for (final value in [...oldRows, ...newRows]) {
    final row = Map<String, dynamic>.from(value as Map);
    final id = (row['id'] ?? '').toString();
    final clientId = (row['clientMessageId'] ?? '').toString();
    final key = id.isNotEmpty
        ? id
        : '${row['fromUserId']}:${row['toUserId']}:$clientId:${row['createdAtUtc']}';
    final previous = rows[key];
    if (row['readAtUtc'] == null && previous?['readAtUtc'] != null) {
      row['readAtUtc'] = previous!['readAtUtc'];
    }
    rows[key] = row;
  }
  final result = rows.values.toList();
  result.sort((a, b) {
    final aSequence = a['sequence'];
    final bSequence = b['sequence'];
    if (aSequence is num &&
        bSequence is num &&
        aSequence > 0 &&
        bSequence > 0) {
      return aSequence.compareTo(bSequence);
    }
    return (a['createdAtUtc'] ?? '')
        .toString()
        .compareTo((b['createdAtUtc'] ?? '').toString());
  });
  return result;
}

/// Owns cursor state for one visible conversation. No polling or second data cache.
class ThreadHistory {
  final MessagesService service;
  final String peer;
  List<dynamic> rows = [];
  String? _latest;
  String? _older;
  bool hasOlder = false;
  int? outgoingReadThrough;
  DateTime? outgoingReadAtUtc;

  void _accept(MessagePage page) {
    final through = page.outgoingReadThrough;
    if (through != null &&
        (outgoingReadThrough == null || through >= outgoingReadThrough!)) {
      outgoingReadThrough = through;
      outgoingReadAtUtc = page.outgoingReadAtUtc;
    }
  }

  bool _initialized = false;
  Future<List<dynamic>>? _syncing;
  Future<List<dynamic>>? _olderLoading;
  Future<void> _tail = Future.value();
  ThreadHistory(this.service, this.peer);

  Future<List<dynamic>> synchronize() => _singleFlight(() async {
        if (!_initialized) {
          final page = await service.getThreadPage(peer);
          _accept(page);
          rows = mergeThreadRows(rows, page.messages);
          _older = page.nextCursor;
          hasOlder = page.hasMore;
          _latest = page.latestCursor;
          _initialized = true;
        } else if (_latest != null) {
          var cursor = _latest;
          var more = true;
          while (more) {
            final page = await service.getThreadPage(peer, after: cursor);
            _accept(page);
            rows = mergeThreadRows(rows, page.messages);
            _latest = page.latestCursor ?? _latest;
            more = page.hasMore;
            if (more &&
                (page.nextCursor == null || page.nextCursor == cursor)) {
              throw StateError('Invalid history cursor');
            }
            cursor = page.nextCursor;
          }
        } else {
          // An empty conversation can receive its first message later.
          final page = await service.getThreadPage(peer);
          _accept(page);
          rows = mergeThreadRows(rows, page.messages);
          _older = page.nextCursor;
          hasOlder = page.hasMore;
          _latest = page.latestCursor;
        }
        return rows;
      });

  Future<List<dynamic>> loadOlder() => _singleFlight(() async {
        if (!hasOlder || _older == null) return rows;
        final page = await service.getThreadPage(peer, before: _older);
        _accept(page);
        rows = mergeThreadRows(rows, page.messages);
        if (page.hasMore && page.nextCursor == _older) {
          throw StateError('Invalid history cursor');
        }
        _older = page.nextCursor;
        hasOlder = page.hasMore;
        return rows;
      }, older: true);

  Future<List<dynamic>> _singleFlight(Future<List<dynamic>> Function() load,
      {bool older = false}) {
    final active = older ? _olderLoading : _syncing;
    if (active != null) return active;
    late Future<List<dynamic>> operation;
    operation = _tail.then((_) => load()).whenComplete(() {
      if (older && identical(_olderLoading, operation)) _olderLoading = null;
      if (!older && identical(_syncing, operation)) _syncing = null;
    });
    _tail = operation.then<void>((_) {}, onError: (Object _) {});
    if (older) {
      _olderLoading = operation;
    } else {
      _syncing = operation;
    }
    return operation;
  }
}
