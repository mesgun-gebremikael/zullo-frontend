import 'account_session.dart';
import 'auth_storage.dart';
import 'commerce_service.dart';
import 'pending_store_purchase.dart';

/// Retries only an already-recorded checkout after an authenticated app restart.
/// This service never starts a native purchase or treats local data as payment
/// proof. The server remains responsible for verifying and granting purchases.
class KnownPurchaseRecovery {
  KnownPurchaseRecovery({
    AuthStorage? authStorage,
    PendingPurchaseStorage? purchaseStorage,
    CommerceClient? commerce,
    bool Function()? isActive,
  })  : _authStorage = authStorage ?? AuthStorage(),
        _purchaseStorage = purchaseStorage ?? PendingPurchaseStorage(),
        _commerce = commerce ?? CommerceClient(),
        _isActive = isActive ?? (() => true);

  final AuthStorage _authStorage;
  final PendingPurchaseStorage _purchaseStorage;
  final CommerceClient _commerce;
  final bool Function() _isActive;
  final int _generation = AccountSession.generation;
  Future<void>? _inFlight;
  bool _disposed = false;
  bool get _active =>
      !_disposed && AccountSession.isCurrent(_generation) && _isActive();

  Future<void> retry() {
    if (!_active) return Future.value();
    return _inFlight ??= _recover().whenComplete(() => _inFlight = null);
  }

  Future<void> _recover() async {
    try {
      final owner = await _authStorage.getUserId();
      if (!_active || owner == null || owner.isEmpty) return;
      final pending = await _purchaseStorage.read(owner);
      if (!_active || pending?.receipt == null) return;
      // A crash can occur after saving the exact receipt but before synchronizing
      // the provider. This grants only server-verified rights to the signed-in
      // owner; clearing a guard still requires Premium's exact receipt proof.
      await _commerce.sync();
      if (_active) CommerceEvents.refreshDiscovery();
    } catch (_) {
      // Offline/corrupt storage/provider failure retains the existing guard.
      // A later foreground retry is safe; no unknown outcome is inferred.
    }
  }

  void dispose() => _disposed = true;
}
