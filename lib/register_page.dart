import 'l10n/localization.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'onboarding/onboarding_start_page.dart';

class RegisterPage extends StatefulWidget {
  final AuthService? authService;
  const RegisterPage({super.key, this.authService});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  late final AuthService _authService = widget.authService ?? AuthService();
  bool _isSubmitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Fyll i alla fält.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Lösenordet behöver minst 8 tecken.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await _authService.registerAndLogin(email: email, password: password);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) => OnboardingStartPage(authService: _authService)),
          (_) => false);
    } on TimeoutException {
      if (mounted) {
        setState(() => _error =
            'Servern svarade inte i tid. Kontot kan ha skapats. Prova att logga in.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            error is AuthRequestException || error is AuthRateLimitException
                ? error.toString()
                : 'Kunde inte ansluta. Kontrollera internet och försök igen.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: !_isSubmitting,
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.createAccount),
            automaticallyImplyLeading: !_isSubmitting,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.createAccount,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.joinZulloToday,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: emailController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.l10n.email,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.password,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ?  Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                                SizedBox(width: 12),
                                Text(context.l10n.creatingAccount)
                              ])
                        : Text(context.l10n.createAccount),
                  ),
                ),
                if (_isSubmitting)
                   Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                          context.l10n.waitingForTheServerTheFirstConnectionMayTakeA,
                          textAlign: TextAlign.center)),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(context.tr(_error!),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                          semanticsLabel: _error)),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          Navigator.pop(context);
                        },
                  child: Text(context.l10n.alreadyHaveAnAccountLogIn),
                ),
              ],
            ),
          ),
        ));
  }
}
