import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'register_page.dart';
import 'splash_page.dart';

class LoginPage extends StatefulWidget {
  final AuthService? authService;
  const LoginPage({super.key, this.authService});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  late final _auth = widget.authService ?? AuthService();
  bool _loading = false, _obscure = true;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Passwords are exact strings: spaces must match account creation.
      await _auth.login(email: _email.text.trim(), password: _password.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) =>
                  SplashPage(authService: _auth, startupDelay: Duration.zero)),
          (_) => false);
    } catch (failure) {
      if (mounted) {
        setState(() => _error = failure is AuthRequestException ||
                failure is AuthRateLimitException
            ? failure.toString()
            : 'Kunde inte logga in. Kontrollera anslutningen och försök igen.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_loading,
      child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
              title: const Text('Log in'),
              automaticallyImplyLeading: !_loading),
          body: SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: AutofillGroup(
                      child: Form(
                          key: _form,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 24),
                                const Text('Välkommen tillbaka',
                                    style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 12),
                                const Text(
                                    'Logga in och fortsätt där du slutade.',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF667085))),
                                const SizedBox(height: 32),
                                TextFormField(
                                    controller: _email,
                                    enabled: !_loading,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [
                                      AutofillHints.username
                                    ],
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                        labelText: 'E-postadress'),
                                    validator: (value) => value == null ||
                                            !value.trim().contains('@')
                                        ? 'Ange din e-postadress.'
                                        : null),
                                const SizedBox(height: 18),
                                TextFormField(
                                    controller: _password,
                                    enabled: !_loading,
                                    obscureText: _obscure,
                                    autofillHints: const [
                                      AutofillHints.password
                                    ],
                                    onFieldSubmitted: (_) => _login(),
                                    decoration: InputDecoration(
                                        labelText: 'Lösenord',
                                        suffixIcon: IconButton(
                                            tooltip: _obscure
                                                ? 'Visa lösenord'
                                                : 'Dölj lösenord',
                                            onPressed: () => setState(
                                                () => _obscure = !_obscure),
                                            icon: Icon(_obscure
                                                ? Icons.visibility_outlined
                                                : Icons
                                                    .visibility_off_outlined))),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'Ange ditt lösenord.'
                                            : null),
                                if (_error != null)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: Text(_error!,
                                          style: const TextStyle(
                                              color: Color(0xFFB42318)))),
                                const SizedBox(height: 24),
                                FilledButton(
                                    onPressed: _loading ? null : _login,
                                    child: _loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white))
                                        : const Text('Log in')),
                                const SizedBox(height: 12),
                                TextButton(
                                    onPressed: _loading
                                        ? null
                                        : () => Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const RegisterPage())),
                                    child: const Text(
                                        'Har du inget konto? Create account')),
                              ])))))));
}
