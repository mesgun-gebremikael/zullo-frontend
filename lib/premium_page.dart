import 'l10n/localization.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/account_session.dart';
import 'services/auth_storage.dart';
import 'services/commerce_service.dart';

class PremiumPage extends StatefulWidget {
  final bool activityOnly;
  final CommerceClient? commerce;
  final NativeBilling? billing;
  const PremiumPage(
      {super.key, this.commerce, this.billing, this.activityOnly = false});
  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  late final _commerce = widget.commerce ?? CommerceClient();
  late final _billing = widget.billing ?? RevenueCatBilling();
  final _generation = AccountSession.generation;
  CommerceState? _state;
  List<StoreOffer> _offers = [];
  String? _userId, _error;
  bool _busy = false;
  Timer? _timer;
  StreamSubscription<void>? _walletSubscription;
  bool get _active => mounted && AccountSession.isCurrent(_generation);
  @override
  void initState() {
    super.initState();
    _load();
    _walletSubscription =
        CommerceEvents.walletStream.listen((_) => _refreshBalance());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_active && _state?.boostUntil != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshBalance() async {
    try {
      final state = await _commerce.state();
      if (!_active) return;
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

  Future<void> _load() async {
    try {
      final state = await _commerce.state();
      if (!_active) return;
      final user = await AuthStorage().getUserId();
      if (!_active) return;
      setState(() {
        _state = state;
        _userId = user;
        _offers = [];
        _error = null;
      });
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
    }
  }

  Future<void> _action(Future<CommerceState> Function() operation) async {
    if (_busy || !_active) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final state = await operation();
      if (!_active) return;
      setState(() => _state = state);
      CommerceEvents.refreshDiscovery();
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
      if (_active) setState(() => _busy = false);
    }
  }

  Future<CommerceState> _buy(StoreOffer offer) async {
    final before = _state!;
    await _billing.buy(offer, _userId!);
    CommerceState? updated;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (!_active) throw SessionChangedException();
      updated = await _commerce.sync();
      final confirmed = switch (offer.id) {
        'zullo_premium_monthly' => updated.premium,
        'zullo_hide_activity_monthly' => updated.canHideActivity,
        'zullo_superlikes_5' => updated.superLikes >= before.superLikes + 5,
        'zullo_boost_1' => updated.boosts >= before.boosts + 1,
        'zullo_boosts_5' => updated.boosts >= before.boosts + 5,
        _ => false,
      };
      if (confirmed) return updated;
      if (attempt < 2) await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (_active) setState(() => _state = updated);
    throw const CommerceException(202,
        'Köpet väntar på verifiering. Köp inte igen. Uppdatera saldot om en stund eller återställ köp.');
  }

  String get _boostTime {
    final remaining =
        _state?.boostUntil?.difference(DateTime.now()).inSeconds ?? 0;
    if (remaining <= 0) return '';
    return '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!AccountSession.isCurrent(_generation)) return const Scaffold();
    final state = _state;
    final boostActive = _boostTime.isNotEmpty;
    final offers = _offers
        .where((offer) =>
            !widget.activityOnly ||
            offer.id == 'zullo_hide_activity_monthly' ||
            offer.id == 'zullo_premium_monthly')
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
                            const SizedBox(height: 16),
                            SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed:
                                      _busy || boostActive || state.boosts <= 0
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
                      '1 Boost per betalningsmånad',
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
                if (offers.isEmpty)
                  Text(
                      context.l10n
                          .purchasesAreUnavailableRightNowYouCanKeepUsingZullo,
                      style: TextStyle(color: Color(0xFF626A77))),
                for (final offer in offers)
                  Card(
                      child: ListTile(
                    title: Text(offer.id == 'zullo_hide_activity_monthly'
                        ? context.l10n.hideActivityOnly
                        : offer.title),
                    subtitle: Text(
                        '${offer.price}${offer.id == 'zullo_premium_monthly' || offer.id == 'zullo_hide_activity_monthly' ? context.l10n.perMonth : ''}'),
                    trailing: FilledButton(
                        onPressed: _busy ||
                                (offer.id == 'zullo_premium_monthly' &&
                                    state?.premium == true) ||
                                (offer.id == 'zullo_hide_activity_monthly' &&
                                    state?.canHideActivity == true)
                            ? null
                            : () => _action(() => _buy(offer)),
                        child: Text(context.l10n.buy)),
                  )),
                if (state?.activityPrivacyUntil?.isAfter(DateTime.now()) ==
                    true)
                  Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                          context.l10n
                              .yourSeparateHideActivitySubscriptionIsManagedInTheApp,
                          style: TextStyle(color: Color(0xFF626A77)))),
                if (offers.isNotEmpty)
                  Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                          context.l10n
                              .yourSubscriptionRenewsAutomaticallyUntilYouCancelInTheApp,
                          style: TextStyle(
                              color: Color(0xFF626A77), height: 1.4))),
                TextButton(
                    onPressed: _busy ||
                            state?.checkoutEnabled != true ||
                            !_billing.available ||
                            _userId == null
                        ? null
                        : () => _action(() async {
                              await _billing.restore(_userId!);
                              return _commerce.sync();
                            }),
                    child: Text(context.l10n.restorePurchases)),
                TextButton(
                    onPressed: _busy ? null : () => _action(_commerce.sync),
                    child: Text(context.l10n.refreshBalance)),
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
                          style: const TextStyle(color: Color(0xFFFFA6AD)))),
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
