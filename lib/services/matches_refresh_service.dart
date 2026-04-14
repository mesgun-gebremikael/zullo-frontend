import 'dart:async';

class MatchesRefreshService {
  MatchesRefreshService._();
  static final MatchesRefreshService instance = MatchesRefreshService._();

  final StreamController<void> _controller =
      StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void requestRefresh() {
    _controller.add(null);
  }
}