import 'package:flutter/material.dart';
import 'services/account_session.dart';
import 'services/auth_service.dart';
import 'services/device_location_service.dart';
import 'services/commerce_service.dart';

class DiscoveryLocationPage extends StatefulWidget {
  final AuthService? authService;
  final DeviceLocationService? locationService;
  const DiscoveryLocationPage(
      {super.key, this.authService, this.locationService});
  @override
  State<DiscoveryLocationPage> createState() => _DiscoveryLocationPageState();
}

class _DiscoveryLocationPageState extends State<DiscoveryLocationPage> {
  late final auth = widget.authService ?? AuthService();
  late final location = widget.locationService ?? DeviceLocationService();
  final generation = AccountSession.generation;
  Map<String, dynamic>? settings;
  String? error;
  bool busy = false;
  bool get active => mounted && AccountSession.isCurrent(generation);
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await auth.discoverySettings();
      if (active) {
        setState(() {
          settings = value;
          error = null;
        });
      }
    } catch (_) {
      if (active) {
        setState(
            () => error = 'Inställningarna kunde inte hämtas. Försök igen.');
      }
    }
  }

  Future<void> _save(Map<String, dynamic> changes) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await auth.discoverySettings(update: changes);
      if (!active) return;
      setState(() => settings = value);
      CommerceEvents.refreshDiscovery();
    } catch (_) {
      if (active) {
        setState(() => error =
            'Ändringen kunde inte sparas. Dina tidigare val gäller fortfarande.');
      }
    } finally {
      if (active) setState(() => busy = false);
    }
  }

  Future<void> _updatePlace() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final place = await location.locate(requestPermission: true);
      if (!active || place == null) return;
      final value = await auth.discoverySettings(update: {
        'automaticLocation': true,
        'lat': place.lat,
        'lng': place.lng,
        'locationName': place.name
      });
      if (active) {
        setState(() => settings = value);
        CommerceEvents.refreshDiscovery();
      }
    } catch (failure) {
      if (active) {
        setState(() => error = failure is LocationFailure
            ? failure.message
            : 'Platsen kunde inte uppdateras. Kontrollera anslutningen och försök igen.');
      }
    } finally {
      if (active) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Plats & upptäckt')),
      body: settings == null
          ? Center(
              child: error == null
                  ? const CircularProgressIndicator()
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(error!),
                      TextButton(
                          onPressed: _load, child: const Text('Försök igen'))
                    ]))
          : ListView(padding: const EdgeInsets.all(20), children: [
              if (busy)
                const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator()),
              if (error != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(error!,
                        style: const TextStyle(color: Colors.red))),
              Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.near_me_outlined,
                            color: Color(0xFFEC2863), size: 30),
                        const SizedBox(height: 14),
                        Text(
                            settings!['automaticLocation'] == true
                                ? 'Din aktuella plats'
                                : 'Din sparade plats',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(
                            (settings!['locationName'] as String?)
                                        ?.isNotEmpty ==
                                    true
                                ? settings!['locationName']
                                : 'Plats är inte aktiverad',
                            style: const TextStyle(fontSize: 17)),
                        const SizedBox(height: 10),
                        const Text(
                            'Upptäck personer nära dig, även när du reser. Din exakta position visas inte för andra.'),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                            onPressed: busy ? null : _updatePlace,
                            icon: const Icon(Icons.my_location_rounded),
                            label: const Text('Uppdatera min plats')),
                        SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title:
                                const Text('Uppdatera när jag använder appen'),
                            subtitle: const Text(
                                'Ingen platsuppdatering i bakgrunden.'),
                            value: settings!['automaticLocation'] == true,
                            onChanged: busy
                                ? null
                                : (value) => value
                                    ? _updatePlace()
                                    : _save({'automaticLocation': false})),
                      ])),
              const SizedBox(height: 20),
              _option(
                  'Lite längre bort',
                  'Om dina vanliga filter inte ger profiler kan vi söka i ett närliggande, större område.',
                  'expandDistance'),
              const SizedBox(height: 12),
              _option(
                  'Lite utanför åldersintervallet',
                  'Om det inte finns fler profiler inom dina val kan vi visa upp till 5 år utanför intervallet. Alltid 18+.',
                  'expandAge'),
              const SizedBox(height: 18),
              Text(
                  'Ditt val: ${settings!['radiusKm']} km · ${settings!['minAge']}–${settings!['maxAge']} år',
                  style: const TextStyle(color: Color(0xFF697180))),
              const SizedBox(height: 8),
              const Text(
                  'Ändra avstånd, ålder och vem du vill träffa via filtret i Upptäck.'),
            ]));
  Widget _option(String title, String subtitle, String key) => DecoratedBox(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: SwitchListTile.adaptive(
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          value: settings![key] == true,
          onChanged: busy ? null : (value) => _save({key: value})));
}
