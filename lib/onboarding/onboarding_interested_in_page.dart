import 'package:flutter/material.dart';
import 'onboarding_data.dart';
import 'onboarding_shell.dart';
import 'onboarding_intention_page.dart';

class OnboardingInterestedInPage extends StatefulWidget {
  final OnboardingData data;

  const OnboardingInterestedInPage({
    super.key,
    required this.data,
  });

  @override
  State<OnboardingInterestedInPage> createState() =>
      _OnboardingInterestedInPageState();
}

class _OnboardingInterestedInPageState
    extends State<OnboardingInterestedInPage> {
  String _selected = '';

  Widget _option(String value) {
    final isSelected = _selected == value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selected = value;
          });
        },
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_rounded,
                  color: Color(0xFFFF4458),
                  size: 34,
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
      progress: 0.32,
      title: 'Vem är du\nintresserad av?',
      subtitle:
          'Välj vem du vill träffa så visar vi rätt profiler.',
      canContinue: _selected.isNotEmpty,
      onNext: () {
  widget.data.interestedIn = _selected;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => OnboardingIntentionPage(data: widget.data),
    ),
  );
},
      child: Column(
        children: [
          _option('Män'),
          _option('Kvinnor'),
          _option('Alla'),
        ],
      ),
    );
  }
}