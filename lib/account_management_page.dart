import 'package:flutter/material.dart';
import 'services/account_service.dart';
import 'services/account_session.dart';
import 'services/auth_service.dart';
import 'services/commerce_service.dart';
import 'welcome_page.dart';

class AccountManagementPage extends StatefulWidget {
  final AccountService? service;
  const AccountManagementPage({super.key, this.service});
  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  late final _service = widget.service ?? AccountService();
  final _generation = AccountSession.generation;
  bool? _paused;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final paused = await _service.paused();
      if (mounted && AccountSession.isCurrent(_generation)) {
        setState(() => _paused = paused);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Kunde inte läsa kontostatus. Försök igen.');
      }
    }
  }

  Future<void> _toggle() async {
    if (_busy || _paused == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final paused = await _service.pause(!_paused!);
      if (!mounted || !AccountSession.isCurrent(_generation)) return;
      setState(() => _paused = paused);
      CommerceEvents.refreshDiscovery();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Kunde inte bekräfta ändringen. Försök igen.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => !AccountSession.isCurrent(_generation)
      ? const SizedBox.shrink()
      : Scaffold(
          appBar: AppBar(title: const Text('Hantera konto')),
          body: ListView(padding: const EdgeInsets.all(24), children: [
            const Icon(Icons.pause_circle_outline, size: 48),
            const SizedBox(height: 20),
            Text(
                _paused == true
                    ? 'Ditt konto är pausat'
                    : 'Ta en paus när du vill',
                style:
                    const TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text(
                'När kontot är pausat visas du inte i Swipa eller bland nya likes. Dina matchningar och chattar finns kvar. Du kan återaktivera kontot när du vill.',
                style: TextStyle(fontSize: 17, height: 1.5)),
            const SizedBox(height: 24),
            if (_paused == null && _error == null)
              const Center(child: CircularProgressIndicator()),
            FilledButton(
                onPressed: _paused == null || _busy ? null : _toggle,
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(_busy
                        ? 'Sparar…'
                        : _paused == true
                            ? 'Återaktivera konto'
                            : 'Pausa konto'))),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
              if (_paused == null)
                TextButton(onPressed: _load, child: const Text('Försök igen'))
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 20),
            const Text('Vill du lämna ZULLO?',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text(
                'Du kan stänga kontot och begära att dina uppgifter raderas. Det går inte att återaktivera ett stängt konto.',
                style: TextStyle(fontSize: 16, height: 1.5)),
            const SizedBox(height: 20),
            OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                AccountRemovalPage(service: _service))),
                child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('Stäng konto och begär radering',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red)))),
            const SizedBox(height: 24),
            const Text(
                'Paus eller kontostängning avslutar inte automatiskt abonnemang hos Apple eller Google. Hantera dem i butikens abonnemangsinställningar.',
                style: TextStyle(color: Color(0xFF626A77), height: 1.5)),
          ]));
}

class AccountRemovalPage extends StatefulWidget {
  final AccountService service;
  const AccountRemovalPage({super.key, required this.service});
  @override
  State<AccountRemovalPage> createState() => _AccountRemovalPageState();
}

class _AccountRemovalPageState extends State<AccountRemovalPage> {
  final _password = TextEditingController();
  final _generation = AccountSession.generation;
  bool _confirmed = false, _busy = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _remove() async {
    if (_busy || !_confirmed || _password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.remove(_password.text);
      if (!mounted || !AccountSession.isCurrent(_generation)) return;
      _password.clear();
      final navigator = Navigator.of(context, rootNavigator: true);
      await AuthService().logout();
      if (navigator.mounted && AccountSession.isCurrent(_generation + 1)) {
        navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WelcomePage()),
            (_) => false);
      }
    } on AccountException catch (e) {
      if (mounted && AccountSession.isCurrent(_generation)) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted && AccountSession.isCurrent(_generation)) {
        setState(() => _error = 'Kunde inte bekräfta begäran. Försök igen.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => !AccountSession.isCurrent(_generation)
      ? const SizedBox.shrink()
      : PopScope(
          canPop: !_busy,
          child: Scaffold(
              appBar: AppBar(title: const Text('Begär radering')),
              body: ListView(padding: const EdgeInsets.all(24), children: [
                const Text('Det här händer',
                    style:
                        TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                const Text(
                    'Kontot stängs direkt. Din profil och dina konversationer tas bort från ZULLO. Bildradering hos externa leverantörer behandlas separat. Vissa betalnings- och säkerhetsuppgifter kan behöva behållas.',
                    style: TextStyle(fontSize: 17, height: 1.5)),
                const SizedBox(height: 16),
                const Text(
                    'Avsluta eventuella abonnemang i App Store eller Google Play. Kontostängningen avslutar inte butikens debitering.',
                    style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 28),
                TextField(
                    controller: _password,
                    obscureText: true,
                    enabled: !_busy,
                    onChanged: (_) => setState(() {}),
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                        labelText: 'Bekräfta med ditt lösenord')),
                const SizedBox(height: 16),
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _confirmed,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _confirmed = value == true),
                    title: const Text(
                        'Jag förstår att kontot stängs och inte kan återaktiveras.')),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red))),
                const SizedBox(height: 20),
                FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700),
                    onPressed: !_confirmed || _password.text.isEmpty || _busy
                        ? null
                        : _remove,
                    child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                            _busy
                                ? 'Behandlar…'
                                : 'Stäng konto och begär radering',
                            textAlign: TextAlign.center))),
              ])));
}
