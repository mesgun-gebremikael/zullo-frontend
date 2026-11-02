import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/account_session.dart';
import '../welcome_page.dart';
import 'onboarding_data.dart';
import 'onboarding_shell.dart';
import 'onboarding_birthdate_page.dart';

class OnboardingNamePage extends StatefulWidget {
  final OnboardingData data;
  final AuthService? authService;

  const OnboardingNamePage({
    super.key,
    required this.data,
    this.authService,
  });

  @override
  State<OnboardingNamePage> createState() => _OnboardingNamePageState();
}

class _OnboardingNamePageState extends State<OnboardingNamePage> {
  late final TextEditingController _controller;
  bool _leaving = false;

  Future<void> _leaveOnboarding() async {
    if (_leaving) return;
    final generation = AccountSession.generation;
    setState(() => _leaving = true);
    var returnedToWelcome = false;
    try {
      // Only sign out locally. The created account remains available to resume.
      await (widget.authService ?? AuthService())
          .logout()
          .timeout(const Duration(seconds: 15));
      if (!mounted || AccountSession.generation != generation + 1) return;
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomePage()),
          (route) => false);
      returnedToWelcome = true;
    } on SessionChangedException {
      // A newer login/logout owns navigation.
    } catch (_) {
      if (mounted &&
          (AccountSession.isCurrent(generation) ||
              AccountSession.generation == generation + 1)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Kunde inte återgå till startsidan. Försök igen.')));
      }
    } finally {
      if (mounted && !returnedToWelcome) setState(() => _leaving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _leaveOnboarding();
        },
        child: OnboardingShell(
          progress: 0.08,
          title: 'Vad heter du\ni förnamn?',
          subtitle: '',
          onBack: _leaveOnboarding,
          canContinue: !_leaving && _controller.text.trim().isNotEmpty,
          onNext: () {
            final name = _controller.text.trim();

            if (_leaving || name.isEmpty) return;

            widget.data.displayName = name;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OnboardingBirthdatePage(data: widget.data),
              ),
            );
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
        ));
  }
}
