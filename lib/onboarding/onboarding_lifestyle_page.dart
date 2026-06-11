import 'package:flutter/material.dart';
import 'onboarding_data.dart';
import 'onboarding_family_page.dart';
import 'onboarding_shell.dart';

class OnboardingLifestylePage extends StatefulWidget {
  final OnboardingData data;

  const OnboardingLifestylePage({super.key, required this.data});

  @override
  State<OnboardingLifestylePage> createState() => _OnboardingLifestylePageState();
}

class _OnboardingLifestylePageState extends State<OnboardingLifestylePage> {
  double _heightCm = 170;
  String _workout = 'Ibland';
  String _pets = 'Vill inte ha';
  String _smoking = 'Nej';
  String _relationshipHistory = 'Varit i ett förhållande';
  String _zodiacSign = 'Vattuman';

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      progress: 0.78,
      title: 'Berätta mer om dig',
      subtitle: 'Du kan ändra detta senare i Redigera Info.',
      canContinue: true,
      onNext: () {
        widget.data.heightCm = _heightCm.round();
        widget.data.workout = _workout;
        widget.data.pets = _pets;
        widget.data.smoking = _smoking;
        widget.data.relationshipHistory = _relationshipHistory;
        widget.data.zodiacSign = _zodiacSign;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OnboardingFamilyPage(data: widget.data),
          ),
        );
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _section('Hur lång är du? ${_heightCm.round()} cm'),
          Slider(
            value: _heightCm,
            min: 140,
            max: 220,
            activeColor: const Color(0xFFE91E63),
            onChanged: (v) => setState(() => _heightCm = v),
          ),
          _chips('Tränar du?', ['Aldrig', 'Ibland', 'Ofta'], _workout, (v) => _workout = v),
          _chips('Husdjur', ['Har husdjur', 'Vill ha husdjur', 'Vill inte ha', 'Allergisk'], _pets, (v) => _pets = v),
          _chips('Använder du nikotin?', ['Nej', 'Ibland', 'Ja'], _smoking, (v) => _smoking = v),
          _chips('Har du varit i en relation?', ['Varit i ett förhållande', 'Inget seriöst', 'Aldrig haft ett förhållande'], _relationshipHistory, (v) => _relationshipHistory = v),
          _chips('Vad är ditt stjärntecken?', ['Vattuman', 'Vädur', 'Kräfta', 'Stenbock', 'Tvilling', 'Lejon', 'Våg', 'Fisk', 'Skytt', 'Skorpion', 'Oxe', 'Jungfru'], _zodiacSign, (v) => _zodiacSign = v),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
    );
  }

  Widget _chips(String title, List<String> values, String current, ValueChanged<String> onSelect) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(title),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: values.map((v) {
              final selected = current == v;
              return ChoiceChip(
                label: Text(v),
                selected: selected,
                selectedColor: const Color(0xFFE91E63),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF20242C),
                  fontWeight: FontWeight.w800,
                ),
                onSelected: (_) => setState(() => onSelect(v)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}