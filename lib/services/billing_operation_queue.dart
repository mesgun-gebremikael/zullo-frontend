import 'account_session.dart';

/// Native purchase identity must stay fixed throughout a purchase/restore.
/// Queued work from a previous account is discarded before touching the SDK.
class BillingOperationQueue {
  Future<void> _tail = Future.value();

  /// Only a successful purchase receipt may opt into result preservation: its
  /// caller must persist it against the original account before checking the
  /// session again. This never permits an obsolete operation to start.
  Future<T> run<T>(Future<T> Function() operation,
      {Future<void> Function()? prepare,
      bool preserveResultOnSessionChange = false}) {
    final generation = AccountSession.generation;
    final result = _tail.then((_) async {
      AccountSession.check(generation);
      if (prepare != null) {
        await prepare();
        // Identity configuration can outlive logout. Never open a store sheet
        // for that obsolete account after preparation finishes.
        AccountSession.check(generation);
      }
      final value = await operation();
      if (!preserveResultOnSessionChange) AccountSession.check(generation);
      return value;
    });
    _tail = result.then<void>((_) {}).catchError((Object _) {});
    return result;
  }
}
