import 'package:flutter/material.dart';
import 'onboarding_data.dart';
import 'onboarding_shell.dart';

class OnboardingIntentionPage extends StatefulWidget {
  final OnboardingData data;

  const OnboardingIntentionPage({
    super.key,
    required this.data,
  });

  @override
  State<OnboardingIntentionPage> createState() =>
      _OnboardingIntentionPageState();
}

class _OnboardingIntentionPageState extends State<OnboardingIntentionPage> {
  String _selected = '';

  final List<Map<String, String>> _options = const [
    {
      'label': 'Seriöst förhållande',
      'value': 'Relationship',
    },
    {
      'label': 'Giftermål',
      'value': 'Marriage',
    },
    {
      'label': 'Dejta och se vart det leder',
      'value': 'Date',
    },
    {
      'label': 'Något seriöst',
      'value': 'Serious',
    },
    {
      'label': 'Jag vet inte än',
      'value': 'NotSure',
    },
  ];

 Widget _option(Map<String, String> option) {
  final label = option['label']!;
  final value = option['value']!;
  final isSelected = _selected == value;

  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          _selected = value;
        });
      },
      child: Container(
        constraints: const BoxConstraints(
  minHeight: 64,
),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF4458)
                : const Color(0xFFD5DAE1),
            width: isSelected ? 2.4 : 1.4,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 20.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF20242C),
                ),
              ),
            ),
            if (isSelected)
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
      progress: 0.40,
      title: 'Vad söker du?',
      subtitle:
          'Välj det som passar dig bäst. Du kan ändra detta senare.',
      canContinue: _selected.isNotEmpty,
      onNext: () {
        widget.data.intention = _selected;
        print(widget.data.intention);
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: _options.map(_option).toList(),
      ),
    );
  }
}