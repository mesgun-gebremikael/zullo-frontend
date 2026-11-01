import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/account_session.dart';
import 'services/auth_storage.dart';
import 'services/commerce_service.dart';

class PremiumPage extends StatefulWidget {
  final CommerceClient? commerce;
  final NativeBilling? billing;
  const PremiumPage({super.key, this.commerce, this.billing});
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
    return Scaffold(
      backgroundColor: const Color(0xFF0E1016),
      appBar: AppBar(
          backgroundColor: const Color(0xFF0E1016),
          foregroundColor: Colors.white,
          title: const Text('ZULLO Premium')),
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
                          colors: [Color(0xFF805326), Color(0xFF33243A)])),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.workspace_premium_rounded,
                            color: Color(0xFFFFD99D), size: 40),
                        const SizedBox(height: 12),
                        Text(
                            state?.premium == true
                                ? 'Din Premium är aktiv'
                                : 'Mer av ZULLO',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        const Text(
                            'Upptäck fler möjligheter. Matchning och chatt finns kvar gratis.',
                            style:
                                TextStyle(color: Colors.white70, height: 1.5)),
                      ]),
                ),
                const SizedBox(height: 20),
                if (state != null)
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
                                      ? 'Boost aktiv · $_boostTime kvar'
                                      : 'Aktivera Boost · 30 minuter'),
                                )),
                          ]))),
                const SizedBox(height: 12),
                const Text('Det här ingår i Premium',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700)),
                for (final feature in const [
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
                    '3 Superlikes per vecka',
                    'Visa extra intresse. Matchning kräver fortfarande ett gensvar.'
                  ),
                  (
                    Icons.bolt,
                    '1 Boost per betalningsmånad',
                    'Prioriterad synlighet i 30 minuter för personer vars inställningar passar.'
                  ),
                  (
                    Icons.visibility_off,
                    'Inkognito och dold aktivitet',
                    'Välj vem som kan upptäcka dig och om matchningar ser din senaste aktivitet.'
                  ),
                ])
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(feature.$1, color: const Color(0xFFEBC186)),
                      title: Text(feature.$2,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(feature.$3,
                          style: const TextStyle(color: Colors.white60))),
                const SizedBox(height: 16),
                if (_offers.isEmpty)
                  const Text(
                      'Köp är inte tillgängliga just nu. Du kan fortsätta använda ZULLO gratis.',
                      style: TextStyle(color: Colors.white70)),
                for (final offer in _offers)
                  Card(
                      child: ListTile(
                    title: Text(offer.title),
                    subtitle: Text(
                        '${offer.price}${offer.id == 'zullo_premium_monthly' ? ' per månad' : ''}'),
                    trailing: FilledButton(
                        onPressed: _busy ||
                                (offer.id == 'zullo_premium_monthly' &&
                                    state?.premium == true)
                            ? null
                            : () => _action(() => _buy(offer)),
                        child: const Text('Köp')),
                  )),
                if (_offers.isNotEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                          'Abonnemanget förnyas automatiskt tills du säger upp det i App Store eller Google Play. Veckans inkluderade Superlikes och månadens inkluderade Boost sparas inte till nästa period. Separat köpta krediter finns kvar på ditt konto tills de används.',
                          style:
                              TextStyle(color: Colors.white60, height: 1.4))),
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
                    child: const Text('Återställ köp')),
                TextButton(
                    onPressed: _busy ? null : () => _action(_commerce.sync),
                    child: const Text('Uppdatera saldo')),
                if (RevenueCatBilling.termsUrl.isNotEmpty)
                  TextButton(
                      onPressed: () =>
                          launchUrl(Uri.parse(RevenueCatBilling.termsUrl)),
                      child: const Text('Köpvillkor')),
                if (RevenueCatBilling.privacyUrl.isNotEmpty)
                  TextButton(
                      onPressed: () =>
                          launchUrl(Uri.parse(RevenueCatBilling.privacyUrl)),
                      child: const Text('Integritetspolicy')),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_error!,
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
