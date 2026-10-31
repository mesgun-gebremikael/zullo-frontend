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
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  late final AuthService _authService = widget.authService ?? AuthService();
  bool _isSubmitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
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
      await _authService.registerAndLogin(
          name: name, email: email, password: password);
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const OnboardingStartPage()));
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
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create account',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Join ZULLO today',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Skapar ditt konto…')
                          ])
                    : const Text('Create account'),
              ),
            ),
            if (_isSubmitting)
              const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                      'Väntar på servern. Första anslutningen kan ta en stund.',
                      textAlign: TextAlign.center)),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                      semanticsLabel: _error)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      Navigator.pop(context);
                    },
              child: const Text('Already have an account? Log in'),
            ),
          ],
        ),
      ),
    );
  }
}
