import 'l10n/localization.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'services/account_session.dart';
import 'services/auth_storage.dart';
import 'welcome_page.dart';
import 'services/auth_service.dart';
import 'onboarding/onboarding_start_page.dart';
import 'main_navigation.dart';

class SplashPage extends StatefulWidget {
  final bool skipNavigation;
  final AuthService? authService;
  final Duration startupDelay;
  final Duration checkTimeout;
  final AuthStorage? storage;

  const SplashPage(
      {super.key,
      this.skipNavigation = false,
      this.authService,
      this.storage,
      this.checkTimeout = const Duration(seconds: 30),
      this.startupDelay = const Duration(seconds: 2)});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  late final AuthStorage _storage = widget.storage ?? AuthStorage();
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!widget.skipNavigation) _checkLogin();
  }

  void _open(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<Widget> _destination(int generation) async {
    final token = await _storage.getToken();
    AccountSession.check(generation);
    if (token == null || token.isEmpty) return const WelcomePage();
    final exists = await (widget.authService ?? AuthService()).hasProfile();
    AccountSession.check(generation);
    return exists
        ? const MainNavigation()
        : OnboardingStartPage(authService: widget.authService);
  }

  Future<void> _checkLogin() async {
    if (_checking) return;
    _checking = true;
    final generation = AccountSession.generation;
    if (mounted) setState(() => _error = null);
    try {
      if (widget.startupDelay > Duration.zero) {
        await Future<void>.delayed(widget.startupDelay);
      }
      AccountSession.check(generation);
      final page = await _destination(generation).timeout(widget.checkTimeout);
      AccountSession.check(generation);
      _open(page);
    } on SessionChangedException {
      // A newer login/logout owns navigation now.
    } on ProfileSessionExpiredException {
      if (AccountSession.isCurrent(generation)) {
        final clearing = _storage.clearAuth();
        final clearingGeneration = AccountSession.generation;
        try {
          await clearing.timeout(widget.checkTimeout);
          if (AccountSession.isCurrent(clearingGeneration)) {
            _open(const WelcomePage());
          }
        } on SessionChangedException {
          // A newer session owns navigation.
        } catch (_) {
          if (mounted && AccountSession.isCurrent(clearingGeneration)) {
            setState(() => _error = 'Kunde inte öppna appen. Försök igen.');
          }
        }
      }
    } on TimeoutException {
      if (mounted && AccountSession.isCurrent(generation)) {
        setState(() => _error =
            'Anslutningen tog för lång tid. Kontrollera internet och försök igen.');
      }
    } catch (_) {
      // A transient server/storage error is not a missing profile or a logout.
      if (mounted && AccountSession.isCurrent(generation)) {
        setState(() => _error = 'Kunde inte öppna appen. Försök igen.');
      }
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
            child: _error == null
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(context.l10n.zullo,
                        style: TextStyle(
                            fontSize: 36, fontWeight: FontWeight.bold)),
                    if (!widget.skipNavigation) ...[
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(context.l10n.openingTheApp),
                    ],
                  ])
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(context.tr(_error!), textAlign: TextAlign.center)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                        onPressed: _checkLogin,
                        child: Text(context.l10n.tryAgain)),
                  ])),
      );
}
