import '../splash_page.dart';
import 'confirm_leave.dart';
import '../services/account_session.dart';
import '../welcome_page.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/onboarding_draft_service.dart';
import 'profile_setup_controller.dart';
import 'onboarding_wizard.dart';

class OnboardingStartPage extends StatefulWidget {
  final AuthService? authService;
  final OnboardingDraftService? draftService;
  const OnboardingStartPage({super.key, this.authService, this.draftService});
  @override
  State<OnboardingStartPage> createState() => _OnboardingStartPageState();
}

class _OnboardingStartPageState extends State<OnboardingStartPage> {
  late final OnboardingDraftService service = widget.draftService ??
      (widget.authService ?? AuthService()).onboardingDrafts;
  ProfileSetupController? setup;
  Object? error;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool preferServer = false}) async {
    if (loading) return;
    setup?.dispose();
    setup = null;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = await ProfileSetupController.load(service,
          preferServer: preferServer);
      if (!mounted) {
        next.dispose();
        return;
      }
      setup?.dispose();
      setState(() {
        setup = next;
        loading = false;
      });
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = failure;
          loading = false;
        });
      }
    }
  }

  Future<void> _reload() async {
    final accept = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                scrollable: true,
                title: const Text('Öppna kontots sparade utkast?'),
                content: const Text(
                    'De lokala val som inte har synkroniserats ersätts med utkastet på ditt konto.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Avbryt')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Öppna utkast'))
                ]));
    if (accept == true && mounted) await _load(preferServer: true);
  }

  Future<void> _leaveError() async {
    final generation = AccountSession.generation;
    if (!await confirmLeaveProfile(context) ||
        !mounted ||
        !AccountSession.isCurrent(generation)) {
      return;
    }
    setState(() => loading = true);
    try {
      await (widget.authService ?? AuthService())
          .logout()
          .timeout(const Duration(seconds: 15));
      if (!mounted || AccountSession.generation != generation + 1) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomePage()), (_) => false);
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = const DraftException('Kunde inte logga ut. Försök igen.');
        });
      }
    }
  }

  @override
  void dispose() {
    setup?.dispose();
    service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Öppnar din påbörjade profil…')
      ])));
    }
    if (error != null) {
      return Scaffold(
          body: SafeArea(
              child: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                            error is DraftException
                                ? (error as DraftException).message
                                : 'Kunde inte hämta din påbörjade profil. Dina sparade svar har inte ändrats.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: error is DraftException &&
                                    [
                                      'profile_exists',
                                      'session_expired'
                                    ].contains((error as DraftException).code)
                                ? () => Navigator.of(context, rootNavigator: true)
                                    .pushAndRemoveUntil(
                                        MaterialPageRoute(
                                            builder: (_) => const SplashPage(
                                                startupDelay: Duration.zero)),
                                        (_) => false)
                                : () => _load(),
                            child: Text(error is DraftException &&
                                    (error as DraftException).code ==
                                        'profile_exists'
                                ? 'Öppna din profil'
                                : error is DraftException &&
                                        (error as DraftException).code ==
                                            'session_expired'
                                    ? 'Logga in igen'
                                    : 'Försök igen')),
                        TextButton(
                            onPressed: _leaveError,
                            child: const Text('Till startsidan')),
                        if (error is DraftException &&
                            (error as DraftException).code == 'draft_conflict')
                          TextButton(
                              onPressed: _reload,
                              child: const Text('Öppna kontots utkast')),
                      ])))));
    }
    return OnboardingWizard(
        key: ObjectKey(setup),
        controller: setup!,
        authService: widget.authService,
        onReload: _reload);
  }
}
