/// Shares an active refresh and runs one follow-up when a live event invalidates it.
class RefreshCoordinator {
  Future<void>? _current;
  bool _dirty = false;

  Future<void> run(Future<void> Function() refresh, {bool invalidate = false}) {
    final active = _current;
    if (active != null) {
      _dirty = _dirty || invalidate;
      return active;
    }
    late Future<void> operation;
    operation = Future<void>.microtask(() async {
      do {
        _dirty = false;
        await refresh();
      } while (_dirty);
    }).whenComplete(() {
      if (identical(_current, operation)) _current = null;
    });
    _current = operation;
    return operation;
  }
}
