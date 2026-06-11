import 'package:flutter/material.dart';
import 'onboarding_data.dart';
import 'onboarding_distance_page.dart';
import 'onboarding_shell.dart';

class OnboardingLocationPage extends StatefulWidget {
  final OnboardingData data;

  const OnboardingLocationPage({super.key, required this.data});

  @override
  State<OnboardingLocationPage> createState() => _OnboardingLocationPageState();
}

class _OnboardingLocationPageState extends State<OnboardingLocationPage> {
  final _livePlace = TextEditingController();
  final _originPlace = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      progress: 0.66,
      title: 'Var bor du?',
      subtitle: 'Detta hjälper andra förstå lite mer om dig.',
      canContinue: true,
      onNext: () {
        widget.data.livePlace = _livePlace.text.trim();
        widget.data.originPlace = _originPlace.text.trim();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OnboardingDistancePage(data: widget.data),
          ),
        );
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _field(_livePlace, 'Var bor du?', 'Stockholm, Göteborg, Oslo...'),
          const SizedBox(height: 24),
          _field(_originPlace, 'Var kommer du ifrån?', 'Asmara, Addis Abeba, Stockholm...'),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String title, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}