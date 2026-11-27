import 'l10n/localization.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/account_session.dart';
import 'services/auth_storage.dart';
import 'services/commerce_service.dart';
import 'services/pending_store_purchase.dart';

class PremiumPage extends StatefulWidget {
  final bool activityOnly;
  final CommerceClient? commerce;
  final NativeBilling? billing;
  final PendingPurchaseStorage? purchaseStorage;
  final DateTime Function()? now;
  const PremiumPage(
      {super.key,
      this.commerce,
      this.billing,
      this.purchaseStorage,
      this.now,
      this.activityOnly = false});
  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> with WidgetsBindingObserver {
  late final _commerce = widget.commerce ?? CommerceClient();
  late final _billing = widget.billing ?? RevenueCatBilling();
  final _generation = AccountSession.generation;
  late final _purchaseStorage =
      widget.purchaseStorage ?? PendingPurchaseStorage();
  PendingStorePurchase? _pendingPurchase;
  bool _pendingReadFailed = false;
  static const _monthly = 'zullo_premium_monthly',
      _annual = 'zullo_premium_annual';
  bool _subscription(String id) => id == _monthly || id == _annual;
  bool get _checkoutBlocked => _pendingReadFailed || _pendingPurchase != null;
  CommerceState? _state;
  List<StoreOffer> _offers = [];
  String? _userId, _error;
  bool _busy = false, _loading = false, _loadingOffers = false;
  String? _busyProductId;
  Future<void>? _loadFuture, _walletRefresh;
  bool _walletRefreshRequested = false;
  int _stateRevision = 0;
  Timer? _timer;
  bool _foreground = true;
  int? _renderedBoostSeconds;
  DateTime _now() => widget.now?.call() ?? DateTime.now();
  int get _boostSeconds {
    final remaining = _state?.boostUntil?.difference(_now()).inSeconds ?? 0;
    return remaining > 0 ? remaining : 0;
  }

  void _tickBoost() {
    if (!_active || !_foreground) return;
    final remaining = _boostSeconds;
    if (_renderedBoostSeconds == remaining) return;
    _renderedBoostSeconds = remaining;
    if (_state?.boostUntil != null) setState(() {});
  }

  void _startBoostTimer() {
    _timer?.cancel();
    if (!_foreground || !_active) return;
    _tickBoost();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tickBoost());
  }

  StreamSubscription<void>? _walletSubscription;
  bool get _active => mounted && AccountSession.isCurrent(_generation);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _walletSubscription =
        CommerceEvents.walletStream.listen((_) => _refreshBalance());
    _startBoostTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _walletSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _startBoostTimer();
    } else {
      _timer?.cancel();
    }
    if (state == AppLifecycleState.resumed &&
        _active &&
        _pendingPurchase?.receipt != null) {
      // Retry only an existing checkout. Never open a purchase sheet on resume.
      // _load shares one in-flight operation across repeated foreground events.
      unawaited(_load());
    }
  }

  Future<void> _refreshBalance() {
    if (_busy || _loading || !_active) return Future.value();
    if (_walletRefresh != null) {
      _walletRefreshRequested = true;
      return _walletRefresh!;
    }
    final revision = _stateRevision;
    Future<void> drain() async {
      do {
        _walletRefreshRequested = false;
        await _performWalletRefresh(revision);
      } while (_walletRefreshRequested &&
          _active &&
          !_busy &&
          !_loading &&
          revision == _stateRevision);
    }

    return _walletRefresh = drain().whenComplete(() => _walletRefresh = null);
  }

  Future<void> _performWalletRefresh(int revision) async {
    try {
      final fresh = await _commerce.state();
      if (!_active || revision != _stateRevision || _busy || _loading) return;
      final state = await _reconcile(fresh);
      if (!_active || revision != _stateRevision) return;
      setState(() {
        if (state.superLikes > (_state?.superLikes ?? 0) ||
            state.boosts > (_state?.boosts ?? 0) ||
            (state.premium && _state?.premium != true)) {
          _error = null;
        }
        _state = state;
      });
    } catch (_) {/* retain the last verified balance until retry */}
  }

  Future<void> _load() {
    if (_busy || !_active) return Future.value();
    if (_loadFuture != null) return _loadFuture!;
    _stateRevision++;
    setState(() => _loading = true);
    return _loadFuture = _performLoad().whenComplete(() {
      _loadFuture = null;
      if (_active) setState(() => _loading = false);
    });
  }

  Future<void> _performLoad() async {
    try {
      var state = await _commerce.state();
      if (!_active) return;
      final user = await AuthStorage().getUserId();
      if (!_active) return;
      PendingStorePurchase? pending;
      var readFailed = false;
      if (user != null) {
        try {
          pending = await _purchaseStorage.read(user);
        } catch (_) {
          readFailed = true;
        }
      }
      if (!_active) return;
      setState(() {
        _pendingPurchase = pending;
        _pendingReadFailed = readFailed;
        _state = state;
        _userId = user;
        _loadingOffers =
            state.checkoutEnabled && _billing.available && user != null;
        _error = null;
      });
      if (pending?.receipt != null) {
        try {
          // A process can end after storing the receipt but before the first
          // provider sync. Refresh the authoritative ledger before checking the
          // exact receipt; a stale GET balance must not leave it stuck forever.
          state = await _commerce.sync();
          if (!_active) return;
          state = await _reconcile(state);
          if (!_active) return;
          setState(() => _state = state);
        } catch (_) {
          if (!_active) return;
          // The provider can be offline after its receipt was already committed
          // to our ledger. Exact server proof can still release that guard;
          // never infer confirmation from the balance or product history.
          try {
            state = await _reconcile(state);
            if (!_active) return;
            if (_pendingPurchase == null) {
              // Proof may follow a webhook newer than the initial GET snapshot.
              // Refresh its wallet, but never invent a grant if that read fails.
              try {
                state = await _commerce.state();
              } catch (_) {/* retain the last verified server balance */}
              if (!_active) return;
            }
            setState(() => _state = state);
          } catch (_) {
            if (!_active) return;
          }
          if (_pendingPurchase != null) {
            // Keep the receipt and last verified balance for the next retry.
            setState(() => _error =
                'Ett köp väntar på verifiering. Köp inte igen. Uppdatera saldot eller återställ köp.');
          }
        }
      }
      if (state.checkoutEnabled && _billing.available && user != null) {
        try {
          final offers = await _billing.offers(user);
          if (_active) setState(() => _offers = offers);
        } catch (_) {
          if (_active) {
            setState(() => _error =
                'Köpalternativen kunde inte laddas. Du kan försöka igen eller återställa köp.');
          }
        }
      }
    } catch (_) {
      if (_active) {
        setState(() => _error = 'Kunde inte hämta Premium. Försök igen.');
      }
    } finally {
      if (_active) setState(() => _loadingOffers = false);
    }
  }

  Future<void> _action(Future<CommerceState> Function() operation,
      {String? productId}) async {
    if (_busy || _loading || !_active) return;
    _stateRevision++;
    setState(() {
      _busy = true;
      _busyProductId = productId;
      _error = null;
    });
    try {
      final state = await operation();
      if (!_active) return;
      setState(() => _state = state);
      CommerceEvents.refreshDiscovery();
    } on PendingCheckoutException {
      if (_active) {
        setState(() => _error =
            'Ett köp väntar på verifiering. Köp inte igen. Uppdatera saldot eller återställ köp.');
      }
    } on PlatformException catch (error) {
      if (_active &&
          PurchasesErrorHelper.getErrorCode(error) !=
              PurchasesErrorCode.purchaseCancelledError) {
        setState(() => _error =
            'Köpet är inte bekräftat ännu. Försök återställa köp eller uppdatera saldot.');
      }
    } catch (error) {
      if (_active) {
        setState(() => _error = error is CommerceException
            ? error.message
            : 'Kunde inte bekräfta köpet. Försök igen eller återställ köp.');
      }
    } finally {
      if (_active) {
        setState(() {
          _busy = false;
          _busyProductId = null;
        });
      }
    }
  }

  Future<CommerceState> _buy(StoreOffer offer) async {
    if (_userId == null || !_active || _state?.checkoutEnabled != true) {
      throw SessionChangedException();
    }
    final user = _userId!;
    // Verify the checkout kill switch/provider health for consumables too.
    // A failed refresh must never fall back to a stale, chargeable paywall.
    final current = await _commerce.sync();
    if (!_active) throw SessionChangedException();
    setState(() => _state = current);
    if (!current.checkoutEnabled ||
        (_subscription(offer.id) && current.premium)) {
      return current;
    }
    final pending = await _purchaseStorage.reserve(user, offer.id);
    _pendingPurchase = pending;
    var billingInvoked = false;
    try {
      AccountSession.check(_generation);
      billingInvoked = true;
      final receipt = await _billing.buy(offer, user);
      // Keep the original account's guard even when logout races a store result.
      if (receipt.productId != pending.productId ||
          receipt.transactionId.isEmpty ||
          !const {'app_store', 'play_store'}.contains(receipt.store)) {
        throw StateError('The store receipt does not identify this checkout');
      }
      final attached =
          await _purchaseStorage.attachReceipt(user, pending, receipt);
      _pendingPurchase = attached
          ? pending.withReceipt(receipt)
          : await _purchaseStorage.read(user);
      AccountSession.check(_generation);
      for (var attempt = 0; attempt < 3; attempt++) {
        final state = await _reconcile(await _commerce.sync());
        if (!_active) throw SessionChangedException();
        setState(() => _state = state);
        if (_pendingPurchase == null) return state;
        if (attempt < 2) await Future<void>.delayed(const Duration(seconds: 2));
      }
      throw const CommerceException(202,
          'Ett köp väntar på verifiering. Köp inte igen. Uppdatera saldot eller återställ köp.');
    } on CheckoutNotStartedException {
      // The native adapter proves no purchase operation was invoked. In
      // contrast, an unknown result after launch must retain the guard.
      await _purchaseStorage.clear(user, expected: pending);
      if (_active) _pendingPurchase = await _purchaseStorage.read(user);
      rethrow;
    } on SessionChangedException {
      if (!billingInvoked) {
        await _purchaseStorage.clear(user, expected: pending);
      }
      rethrow;
    } on PlatformException catch (error) {
      if (PurchasesErrorHelper.getErrorCode(error) ==
          PurchasesErrorCode.purchaseCancelledError) {
        await _purchaseStorage.clear(user, expected: pending);
        if (_active) _pendingPurchase = await _purchaseStorage.read(user);
      }
      rethrow;
    }
  }

  Future<CommerceState> _reconcile(CommerceState state) async {
    if (!_active || _userId == null) return state;
    final pending = _pendingPurchase;
    if (pending == null) return state;
    final receipt = pending.receipt;
    if (_subscription(pending.productId)) {
      // Subscription access comes only from the provider-verified server state.
      if (state.premium) {
        await _purchaseStorage.clear(_userId!, expected: pending);
        if (_active) _pendingPurchase = await _purchaseStorage.read(_userId!);
      }
      return state;
    }
    // Product/date/history is not proof of this checkout: another device or a
    // previous purchase can have the same product and a nearby timestamp. An
    // interrupted purchase without its exact receipt must remain blocked until
    // a future authenticated server-attempt protocol can correlate it safely.
    if (receipt != null) {
      final status = await _commerce.purchaseStatus(receipt);
      if (!_active) throw SessionChangedException();
      if (status.verified || status.refunded) {
        await _purchaseStorage.clear(_userId!, expected: pending);
        _pendingPurchase = await _purchaseStorage.read(_userId!);
        if (status.refunded) {
          _error =
              'Köpet har återbetalats. Ditt verifierade saldo har uppdaterats.';
        }
      }
    }
    return state;
  }

  Future<CommerceState> _restore() async {
    await _billing.restore(_userId!);
    return _reconcile(await _commerce.sync());
  }

  Future<void> _manageSubscription() async {
    final uri = Uri.parse(Theme.of(context).platform == TargetPlatform.iOS
        ? 'https://apps.apple.com/account/subscriptions'
        : 'https://play.google.com/store/account/subscriptions');
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {/* Give an actionable explanation without platform details. */}
    if (mounted && AccountSession.isCurrent(_generation)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr(
              'Öppna App Store eller Google Play för att hantera ditt abonnemang.'))));
    }
  }

  String get _boostTime {
    final remaining = _boostSeconds;
    if (remaining <= 0) return '';
    return '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!AccountSession.isCurrent(_generation)) return const Scaffold();
    final state = _state;
    final boostActive = _boostTime.isNotEmpty;
    final offers =
        (state?.checkoutEnabled == true ? _offers : const <StoreOffer>[])
            .where((offer) =>
                _subscription(offer.id) ||
                (!widget.activityOnly &&
                    const {
                      'zullo_superlikes_5',
                      'zullo_boost_1',
                      'zullo_boosts_5'
                    }.contains(offer.id)))
            .toList();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF22262E),
          title: Text(widget.activityOnly
              ? context.l10n.hideActivity
              : 'ZULLO Premium')),
      body: state == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                          colors: [Color(0xFF20242C), Color(0xFF49243D)])),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.workspace_premium_rounded,
                            color: Color(0xFFFF83AF), size: 40),
                        const SizedBox(height: 12),
                        Text(
                            widget.activityOnly
                                ? (state?.canHideActivity == true
                                    ? context.l10n.hideActivityIsIncludedForYou
                                    : context.l10n.hideActivity)
                                : (state?.premium == true
                                    ? context.l10n.yourPremiumIsActive
                                    : context.l10n.getMore),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(
                            widget.activityOnly
                                ? context.l10n
                                    .hideYourOnlineAndLastActiveStatusFromYourMatches
                                : context.l10n
                                    .discoverMorePossibilitiesMatchingAndChattingStayFree,
                            style: const TextStyle(
                                color: Colors.white70, height: 1.5)),
                      ]),
                ),
                const SizedBox(height: 20),
                Text(context.tr(
                    'Ett Premium. Välj månadsvis eller årsvis – samma förmåner i båda.')),
                if (_checkoutBlocked)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(context.tr(_pendingReadFailed ||
                              _pendingPurchase?.receipt == null
                          ? 'Köpet saknar fullständig bekräftelse. Nya köp är spärrade för att undvika dubbel debitering. Kontrollera köpet i App Store eller Google Play.'
                          : 'Ett köp väntar på verifiering. Köp inte igen. Uppdatera saldot eller återställ köp.'))),
                if (state != null && !widget.activityOnly)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(children: [
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _balance(
                                      Icons.star_rounded,
                                      '${state.superLikes}',
                                      'Superlikes',
                                      Colors.blue),
                                  _balance(
                                      Icons.bolt_rounded,
                                      '${state.boosts}',
                                      'Boosts',
                                      Colors.deepPurple),
                                ]),
                            if (state.includedSuperLikes != null &&
                                state.purchasedSuperLikes != null)
                              const Text('Superlikes'),
                            if (state.includedSuperLikes != null &&
                                state.purchasedSuperLikes != null)
                              Text(context.tr(
                                  'Ingår: ${state.premium ? state.includedSuperLikes : 0} · Köpta: ${state.purchasedSuperLikes}')),
                            if (state.includedBoosts != null &&
                                state.purchasedBoosts != null)
                              Text('Boosts'),
                            if (state.includedBoosts != null &&
                                state.purchasedBoosts != null)
                              Text(context.tr(
                                  'Ingår: ${state.premium ? state.includedBoosts : 0} · Köpta: ${state.purchasedBoosts}')),
                            if (state.premium && state.nextBoostRefresh != null)
                              Text(context.tr(
                                  'Nästa påfyllning: ${MaterialLocalizations.of(context).formatMediumDate(state.nextBoostRefresh!.toLocal())}')),
                            const SizedBox(height: 16),
                            SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _busy ||
                                          _loading ||
                                          boostActive ||
                                          state.boosts <= 0
                                      ? null
                                      : () => _action(_commerce.boost),
                                  icon: const Icon(Icons.bolt),
                                  label: Text(boostActive
                                      ? context.l10n.boostActiveRemaining(
                                          (_boostTime).toString())
                                      : context.l10n.activateBoost30Minutes),
                                )),
                          ]))),
                const SizedBox(height: 12),
                if (!widget.activityOnly) ...[
                  Text(context.l10n.includedWithPremium,
                      style: TextStyle(
                          color: Color(0xFF22262E),
                          fontSize: 21,
                          fontWeight: FontWeight.w700)),
                  for (final feature in [
                    (
                      Icons.favorite,
                      'Se vem som gillar dig',
                      'Se vanliga inkommande likes före matchning.'
                    ),
                    (
                      Icons.all_inclusive,
                      'Fler likes och ångra',
                      'Ingen vanlig like-kvot. Ångra en vanlig swipe, men inte en match eller Superlike.'
                    ),
                    (
                      Icons.star,
                      context.l10n.threeSuperlikesPerWeek,
                      'Visa extra intresse. Matchning kräver fortfarande ett gensvar.'
                    ),
                    (
                      Icons.bolt,
                      context.tr('1 Boost varje månad'),
                      'Prioriterad synlighet i 30 minuter för personer vars inställningar passar.'
                    ),
                    (
                      Icons.visibility_off,
                      context.l10n.premiumIncognito,
                      'Välj vem som kan upptäcka dig och om matchningar ser din senaste aktivitet.'
                    ),
                  ])
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            Icon(feature.$1, color: const Color(0xFFEC2863)),
                        title: Text(context.tr(feature.$2),
                            style: const TextStyle(color: Color(0xFF22262E))),
                        subtitle: Text(context.tr(feature.$3),
                            style: const TextStyle(color: Color(0xFF626A77)))),
                ],
                const SizedBox(height: 16),
                if (_loadingOffers && offers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: CircularProgressIndicator(
                            semanticsLabel: context.l10n.loading)),
                  ),
                if (!_loadingOffers && offers.isEmpty)
                  Text(
                      context.l10n
                          .purchasesAreUnavailableRightNowYouCanKeepUsingZullo,
                      style: TextStyle(color: Color(0xFF626A77))),
                for (final offer in offers)
                  Card(
                      child: ListTile(
                    title: Text(offer.id == _monthly
                        ? context.tr('Månadsvis')
                        : offer.id == _annual
                            ? context.tr('Årsvis')
                            : offer.title),
                    subtitle: Text(
                        '${offer.price}${offer.id == 'zullo_premium_monthly' || offer.id == 'zullo_hide_activity_monthly' ? context.l10n.perMonth : offer.id == _annual ? context.tr(' per år') : ''}'),
                    trailing: FilledButton(
                        onPressed: _busy ||
                                _loading ||
                                _checkoutBlocked ||
                                (_subscription(offer.id) &&
                                    state?.premium == true) ||
                                (offer.id == 'zullo_hide_activity_monthly' &&
                                    state?.canHideActivity == true)
                            ? null
                            : () =>
                                _action(() => _buy(offer), productId: offer.id),
                        child: _busy && _busyProductId == offer.id
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  semanticsLabel: context.l10n.loading,
                                ))
                            : Text(context.l10n.buy)),
                  )),
                if (state?.activityPrivacyUntil?.isAfter(DateTime.now()) ==
                    true)
                  Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                          context.tr(
                              'Ditt separata abonnemang för Dölj aktivitet finns kvar. Premium avslutar det inte automatiskt. Hantera det i App Store eller Google Play för att undvika dubbla abonnemang.'),
                          style: TextStyle(color: Color(0xFF626A77)))),
                if (offers.isNotEmpty)
                  Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                          context.tr(
                              '3 Superlikes per vecka och 1 Boost varje månad. Oanvända inkluderade krediter sparas inte. Köpta krediter finns kvar tills de används.'),
                          style: TextStyle(
                              color: Color(0xFF626A77), height: 1.4))),
                TextButton(
                    onPressed: _busy ||
                            _loading ||
                            state?.checkoutEnabled != true ||
                            !_billing.available ||
                            _userId == null
                        ? null
                        : () => _action(_restore),
                    child: Text(context.l10n.restorePurchases)),
                TextButton(
                    onPressed: _busy || _loading
                        ? null
                        : () => _action(
                            () async => _reconcile(await _commerce.sync())),
                    child: Text(context.l10n.refreshBalance)),
                TextButton(
                    onPressed: _manageSubscription,
                    child: Text(context.tr('Hantera abonnemang i butiken'))),
                if (RevenueCatBilling.termsUrl.isNotEmpty)
                  TextButton(
                      onPressed: () =>
                          launchUrl(Uri.parse(RevenueCatBilling.termsUrl)),
                      child: Text(context.l10n.purchaseTerms)),
                if (RevenueCatBilling.privacyUrl.isNotEmpty)
                  TextButton(
                      onPressed: () =>
                          launchUrl(Uri.parse(RevenueCatBilling.privacyUrl)),
                      child: Text(context.l10n.privacyPolicy)),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(context.tr(_error!),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
              ]),
            ),
    );
  }

  Widget _balance(IconData icon, String amount, String label, Color color) =>
      Column(children: [
        Icon(icon, color: color),
        Text(amount,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        Text(label)
      ]);
}
