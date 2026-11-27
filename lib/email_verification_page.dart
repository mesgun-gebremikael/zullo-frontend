import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n/localization.dart';
import 'services/auth_service.dart';
import 'splash_page.dart';

class EmailVerificationPage extends StatefulWidget {
  final EmailVerificationChallenge challenge;
  final AuthService authService;
  const EmailVerificationPage(
      {super.key, required this.challenge, required this.authService});
  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  late EmailVerificationChallenge _challenge = widget.challenge;
  final _code = TextEditingController();
  Timer? _timer;
  bool _busy = false;
  String? _error;
  DateTime? _retryUntil;
  int get _remaining => ((_retryUntil ?? _challenge.nextSendAtUtc)
              .difference(DateTime.now().toUtc())
              .inMilliseconds /
          1000)
      .ceil()
      .clamp(0, 3600);
  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_remaining <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_remaining <= 0) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy) return;
    if (!RegExp(r'^[0-9]{6}$').hasMatch(_code.text)) {
      setState(() => _error = 'Ange den sexsiffriga koden.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.verifyEmail(_challenge, _code.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => SplashPage(
                  authService: widget.authService,
                  startupDelay: Duration.zero)),
          (_) => false);
    } catch (failure) {
      if (mounted) {
        setState(() => _error =
            failure is AuthRequestException || failure is AuthRateLimitException
                ? failure.toString()
                : 'Kunde inte ansluta. Kontrollera internet och försök igen.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _remaining > 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final replacement =
          await widget.authService.resendVerification(_challenge);
      if (mounted) {
        setState(() {
          _challenge = replacement;
          _retryUntil = null;
          _code.clear();
        });
      }
      _startTimer();
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        if (failure is AuthRateLimitException) {
          _retryUntil = DateTime.now()
              .toUtc()
              .add(Duration(seconds: failure.retryAfterSeconds));
        }
        _error =
            failure is AuthRequestException || failure is AuthRateLimitException
                ? failure.toString()
                : 'Kunde inte ansluta. Kontrollera internet och försök igen.';
      });
      _startTimer();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: Scaffold(
          appBar: AppBar(
              title: Text(context.tr('Bekräfta din e-postadress')),
              automaticallyImplyLeading: !_busy),
          body: SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: AutofillGroup(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        const Icon(Icons.mark_email_read_outlined,
                            size: 56, color: Color(0xFFFF2D75)),
                        const SizedBox(height: 24),
                        Text(context.tr('Kontrollera din inkorg'),
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Text(context.tr(
                            'Ange koden som skickades till din e-postadress. Kontrollera även skräpposten.')),
                        const SizedBox(height: 8),
                        Text(_challenge.email,
                            textDirection: TextDirection.ltr,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 28),
                        TextField(
                            key: const ValueKey('email-verification-code'),
                            controller: _code,
                            enabled: !_busy,
                            maxLength: 6,
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.center,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration: InputDecoration(
                                labelText: context.tr('Verifieringskod')),
                            onSubmitted: (_) => _verify()),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(context.tr(_error!),
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _busy ? null : _verify,
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Text(context.tr('Bekräfta e-postadress'))),
                        const SizedBox(height: 12),
                        TextButton(
                            onPressed: _busy || _remaining > 0 ? null : _resend,
                            child: Text(_remaining > 0
                                ? context.tr('Ny kod om $_remaining s')
                                : context.tr('Skicka en ny kod'))),
                      ]))))));
}
