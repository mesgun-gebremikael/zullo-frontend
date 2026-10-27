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

  const SplashPage(
      {super.key,
      this.skipNavigation = false,
      this.authService,
      this.startupDelay = const Duration(seconds: 2)});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final AuthStorage _storage = AuthStorage();
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
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) {
        _open(const WelcomePage());
        return;
      }
      final exists = await (widget.authService ?? AuthService()).hasProfile();
      AccountSession.check(generation);
      _open(exists ? const MainNavigation() : const OnboardingStartPage());
    } on SessionChangedException {
      // A newer login/logout owns navigation now.
    } on ProfileSessionExpiredException {
      if (AccountSession.isCurrent(generation)) {
        final clearing = _storage.clearAuth();
        final clearingGeneration = AccountSession.generation;
        try {
          await clearing;
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
                ? const Text('ZULLO',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold))
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!),
                    const SizedBox(height: 16),
                    ElevatedButton(
                        onPressed: _checkLogin,
                        child: const Text('Försök igen')),
                  ])),
      );
}
