import 'package:flutter/material.dart';
import 'onboarding_data.dart';
import 'onboarding_shell.dart';

class OnboardingGenderPage extends StatefulWidget {
  final OnboardingData data;

  const OnboardingGenderPage({
    super.key,
    required this.data,
  });

  @override
  State<OnboardingGenderPage> createState() => _OnboardingGenderPageState();
}

class _OnboardingGenderPageState extends State<OnboardingGenderPage> {
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
                    color: Color(0xFF20242C),
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
      progress: 0.24,
      title: 'Vilket kön\nidentifierar du dig som?',
      subtitle:
          'Välj det som stämmer bäst. Detta hjälper oss visa din profil för rätt personer.',
      canContinue: _selected.isNotEmpty,
      onNext: () {
        widget.data.gender = _selected;
        print(widget.data.gender);
      },
      child: Column(
        children: [
          _option('Man'),
          _option('Kvinna'),
        ],
      ),
    );
  }
}