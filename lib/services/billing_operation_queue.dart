import 'account_session.dart';

/// Native purchase identity must stay fixed throughout a purchase/restore.
/// Queued work from a previous account is discarded before touching the SDK.
class BillingOperationQueue {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final generation = AccountSession.generation;
    final result = _tail.then((_) async {
      AccountSession.check(generation);
      final value = await operation();
      AccountSession.check(generation);
      return value;
    });
    _tail = result.then<void>((_) {}).catchError((Object _) {});
    return result;
  }
}
