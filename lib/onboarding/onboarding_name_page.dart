import 'package:flutter/material.dart';
import 'onboarding_data.dart';
import 'onboarding_shell.dart';

class OnboardingNamePage extends StatefulWidget {
  final OnboardingData data;

  const OnboardingNamePage({
    super.key,
    required this.data,
  });

  @override
  State<OnboardingNamePage> createState() => _OnboardingNamePageState();
}

class _OnboardingNamePageState extends State<OnboardingNamePage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: widget.data.displayName,
    );

    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      progress: 0.08,
      title: 'Vad heter du\ni förnamn?',
      subtitle: '',
      canContinue: _controller.text.trim().isNotEmpty,
      onNext: () {
        widget.data.displayName = _controller.text.trim();

        print(widget.data.displayName);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            style: const TextStyle(
              fontSize: 24,
            ),
            decoration: const InputDecoration(
              border: UnderlineInputBorder(),
              hintText: 'Skriv ditt namn',
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Så här kommer det att se ut på din profil.',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF596273),
            ),
          ),
        ],
      ),
    );
  }
}