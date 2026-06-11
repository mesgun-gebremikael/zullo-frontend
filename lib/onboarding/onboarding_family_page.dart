import 'package:flutter/material.dart';
import 'onboarding_bio_page.dart';
import 'onboarding_data.dart';
import 'onboarding_shell.dart';

class OnboardingFamilyPage extends StatefulWidget {
  final OnboardingData data;

  const OnboardingFamilyPage({super.key, required this.data});

  @override
  State<OnboardingFamilyPage> createState() => _OnboardingFamilyPageState();
}

class _OnboardingFamilyPageState extends State<OnboardingFamilyPage> {
  String _childrenCount = 'Jag har inga barn';
  String _wantChildren = 'Inte säker än';

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      progress: 0.86,
      title: 'Familj och framtid',
      subtitle: 'Detta hjälper dig matcha med rätt personer.',
      canContinue: true,
      onNext: () {
        widget.data.childrenCount = _childrenCount;
        widget.data.wantChildren = _wantChildren;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OnboardingBioPage(data: widget.data),
          ),
        );
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _chips('Hur många barn har du?', [
            'Jag har inga barn',
            '1 barn',
            '2 barn',
            '3 barn',
            '4 eller fler',
          ], _childrenCount, (v) => _childrenCount = v),
          _chips('Vill du ha barn i framtiden?', [
            'Jag vill ha barn',
            'Inte säker än',
            'Jag vill inte ha barn',
          ], _wantChildren, (v) => _wantChildren = v),
        ],
      ),
    );
  }

  Widget _chips(String title, List<String> values, String current, ValueChanged<String> onSelect) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
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