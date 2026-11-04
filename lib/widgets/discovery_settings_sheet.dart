import '../l10n/localization.dart';
import '../discovery_location_page.dart';
import 'package:flutter/material.dart';

class DiscoveryPreferences {
  final String interestedIn;
  final int radiusKm, minAge, maxAge;
  const DiscoveryPreferences(
      {required this.interestedIn,
      required this.radiusKm,
      required this.minAge,
      required this.maxAge});
}

class DiscoverySettingsSheet extends StatefulWidget {
  final DiscoveryPreferences initial;
  final Future<void> Function(DiscoveryPreferences) onSave;
  const DiscoverySettingsSheet(
      {super.key, required this.initial, required this.onSave});
  @override
  State<DiscoverySettingsSheet> createState() => _DiscoverySettingsSheetState();
}

class _DiscoverySettingsSheetState extends State<DiscoverySettingsSheet> {
  late String _interest = widget.initial.interestedIn;
  late double _radius = widget.initial.radiusKm.clamp(1, 300).toDouble();
  late RangeValues _ages = RangeValues(
      widget.initial.minAge.toDouble(), widget.initial.maxAge.toDouble());
  bool _busy = false;
  String? _error;
  Future<void> _chooseInterest() async {
    final choice = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (context) => SafeArea(
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(context.l10n.interestedIn,
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(context.l10n.chooseWhichProfilesYouWantToDiscover,
                          style: TextStyle(color: Color(0xFF626A77))),
                      const SizedBox(height: 20),
                      for (final value in ['Kvinnor', 'Män', 'Alla'])
                        Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                                color: value == _interest
                                    ? const Color(0xFFFFEEF3)
                                    : const Color(0xFFF4F5F7),
                                borderRadius: BorderRadius.circular(20),
                                child: ListTile(
                                    minVerticalPadding: 18,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    title: Text(context.tr(value),
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600)),
                                    trailing: Icon(
                                        value == _interest
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: value == _interest
                                            ? const Color(0xFFE6296B)
                                            : const Color(0xFF9198A4)),
                                    onTap: () =>
                                        Navigator.pop(context, value)))),
                    ])))));
    if (mounted && choice != null) setState(() => _interest = choice);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(DiscoveryPreferences(
          interestedIn: _interest,
          radiusKm: _radius.round(),
          minAge: _ages.start.round(),
          maxAge: _ages.end.round()));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Kunde inte spara. Dina tidigare inställningar gäller fortfarande. Försök igen.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .83,
        minChildSize: .5,
        maxChildSize: .95,
        builder: (context, controller) => SafeArea(
            child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                children: [
              Text(context.l10n.yourDiscoveryPreferences,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(context.l10n.findPeopleWhoFitWhatYouReLookingFor,
                  style: TextStyle(fontSize: 16, color: Color(0xFF626A77))),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.near_me_outlined),
                  title: Text(context.l10n.locationMoreDiscoveryOptions),
                  trailing: Icon(Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded),
                  onTap: _busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DiscoveryLocationPage()))),
              const SizedBox(height: 28),
              _card(ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  leading: const Icon(Icons.favorite_outline),
                  title: Text(context.l10n.interestedIn,
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(context.tr(_interest),
                      style: const TextStyle(
                          fontSize: 18, color: Color(0xFFE6296B))),
                  trailing: Icon(Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left
                      : Icons.chevron_right),
                  onTap: _busy ? null : _chooseInterest)),
              const SizedBox(height: 18),
              _card(Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            context.l10n.maximumDistanceValue0Km(
                                (_radius.round()).toString()),
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Slider(
                            value: _radius,
                            min: 1,
                            max: 300,
                            divisions: 299,
                            label: context.l10n
                                .value0Km(_radius.round().toString()),
                            onChanged: _busy
                                ? null
                                : (value) => setState(() => _radius = value)),
                        Text(context.l10n.weSearchWithinYourChosenDistance,
                            style: TextStyle(color: Color(0xFF626A77))),
                      ]))),
              const SizedBox(height: 18),
              _card(Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            context.l10n.ageRangeValue0Value1(
                                (_ages.start.round()).toString(),
                                (_ages.end.round()).toString()),
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        RangeSlider(
                            values: _ages,
                            min: 18,
                            max: 100,
                            divisions: 82,
                            onChanged: _busy
                                ? null
                                : (value) => setState(() => _ages = value)),
                      ]))),
              const SizedBox(height: 28),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(context.tr(_error!),
                        style: const TextStyle(color: Colors.red))),
              FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          _busy
                              ? context.l10n.saving
                              : context.l10n.saveSettings,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)))),
            ])),
      ));
  Widget _card(Widget child) => Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF4F5F7),
          borderRadius: BorderRadius.circular(24)),
      child: child);
}
