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
                      const Text('Intresserad av',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text('Välj vilka profiler du vill upptäcka.',
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
                                    title: Text(value,
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
              const Text('Dina upptäcktsval',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Hitta personer som passar det du söker.',
                  style: TextStyle(fontSize: 16, color: Color(0xFF626A77))),
              const SizedBox(height: 28),
              _card(ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  leading: const Icon(Icons.favorite_outline),
                  title: const Text('Intresserad av',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(_interest,
                      style: const TextStyle(
                          fontSize: 18, color: Color(0xFFE6296B))),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : _chooseInterest)),
              const SizedBox(height: 18),
              _card(Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Maxavstånd · ${_radius.round()} km',
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Slider(
                            value: _radius,
                            min: 1,
                            max: 300,
                            divisions: 299,
                            label: '${_radius.round()} km',
                            onChanged: _busy
                                ? null
                                : (value) => setState(() => _radius = value)),
                        const Text('Vi söker inom avståndet du väljer.',
                            style: TextStyle(color: Color(0xFF626A77))),
                      ]))),
              const SizedBox(height: 18),
              _card(Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Åldersspann · ${_ages.start.round()}–${_ages.end.round()}',
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        RangeSlider(
                            values: _ages,
                            min: 18,
                            max: 99,
                            divisions: 81,
                            onChanged: _busy
                                ? null
                                : (value) => setState(() => _ages = value)),
                      ]))),
              const SizedBox(height: 28),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red))),
              FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_busy ? 'Sparar…' : 'Spara inställningar',
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
