import 'account_session.dart';
import 'dart:async';

class MatchesRefreshService {
  MatchesRefreshService._();
  static final MatchesRefreshService instance = MatchesRefreshService._();

  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  int? _queuedGeneration;
  void requestRefresh() {
    final generation = AccountSession.generation;
    if (_queuedGeneration == generation) return;
    _queuedGeneration = generation;
    scheduleMicrotask(() {
      if (_queuedGeneration == generation) _queuedGeneration = null;
      if (AccountSession.isCurrent(generation)) _controller.add(null);
    });
  }
}
