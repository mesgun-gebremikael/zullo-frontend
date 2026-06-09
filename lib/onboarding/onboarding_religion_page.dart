import 'package:flutter/material.dart';
import 'onboarding_data.dart';
import 'onboarding_shell.dart';

class OnboardingReligionPage extends StatefulWidget {
  final OnboardingData data;

  const OnboardingReligionPage({
    super.key,
    required this.data,
  });

  @override
  State<OnboardingReligionPage> createState() =>
      _OnboardingReligionPageState();
}

class _OnboardingReligionPageState extends State<OnboardingReligionPage> {
  String _selected = 'Private';

  final options = const [
    'Private',
    'Kristen',
    'Ortodox',
    'Muslim',
    'Katolik',
    'Ateist',
    'Agnostiker',
    'Annat',
  ];

  Widget _option(String value) {
    final selected = _selected == value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => setState(() => _selected = value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFF4458)
                  : const Color(0xFFD5DAE1),
              width: selected ? 2.4 : 1.4,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF20242C),
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_rounded,
                  color: Color(0xFFFF4458),
                  size: 32,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      progress: 0.56,
      title: 'Vad är din\nreligion?',
      subtitle: 'Du kan välja Privat om du inte vill visa detta.',
      canContinue: _selected.isNotEmpty,
      onNext: () {
        widget.data.religion = _selected;
        print(widget.data.religion);
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: options.map(_option).toList(),
      ),
    );
  }
}