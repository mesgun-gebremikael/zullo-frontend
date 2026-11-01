import 'premium_page.dart';
import 'services/commerce_service.dart';
import 'blocked_profiles_page.dart';
import 'services/account_session.dart';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';

class ProfileSettingsPage extends StatefulWidget {
  final AuthService? authService;
  const ProfileSettingsPage({super.key, this.authService});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {

late final AuthService _authService = widget.authService ?? AuthService();
final int _generation = AccountSession.generation;

String _emailText = 'Laddar...';
String _userIdText = 'Laddar...';

  bool _showActivityStatus = true;
  bool _incognitoMode = false;
  bool _marketingConsent = false;
  bool _privacyBusy = false;

  @override
void initState() {
  super.initState();
  _loadAccountInfo();
  if (widget.authService == null) _loadPrivacy();
}

Future<void> _loadPrivacy() async {
  try {
    final state = await CommerceClient().state();
    if (!mounted || !AccountSession.isCurrent(_generation)) return;
    setState(() { _showActivityStatus = !state.hideActivity; _incognitoMode = state.incognito; });
  } catch (_) { /* keep settings usable while temporarily offline */ }
}
Future<void> _savePrivacy({bool? showActivity, bool? incognito}) async {
  if (_privacyBusy) return;
  _privacyBusy = true;
  try {
    final state = await CommerceClient().privacy(hideActivity: !(showActivity ?? _showActivityStatus), incognito: incognito ?? _incognitoMode);
    if (!mounted || !AccountSession.isCurrent(_generation)) return;
    setState(() { _showActivityStatus = !state.hideActivity; _incognitoMode = state.incognito; });
    CommerceEvents.refreshDiscovery();
  } on CommerceException catch (error) {
    if (!mounted) return;
    if (error.status == 402) { await Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumPage())); await _loadPrivacy(); }
    else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message))); }
  } catch (_) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kunde inte spara inställningen. Försök igen.')));
  } finally { _privacyBusy = false; }
}

Future<void> _loadAccountInfo() async {
  try {
    final profile = await _authService.getMyAccount();
    final userId = profile["userId"]?.toString();

    if (!mounted || !AccountSession.isCurrent(_generation)) return;

    setState(() {
      _emailText = (profile["email"] ?? "Ingen e-post hittades").toString();
      _userIdText = userId ?? "Ingen user id hittades";
    });
  } catch (e) {
    if (!mounted || !AccountSession.isCurrent(_generation)) return;

    setState(() {
      _emailText = "Kunde inte ladda e-post";
      _userIdText = "Kunde inte ladda user id";
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F3F3),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        title: const Text(
          'MITT KONTO',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            _SettingsArrowRow(
              icon: Icons.verified,
              title: 'Verifiera profil',
              subtitle: 'Bli verifierad så andra vet att du är på riktigt',
              onTap: () {},
            ),
            const SizedBox(height: 8),
            _SettingsSwitchRow(
              icon: Icons.power_settings_new,
              title: 'Aktivitetsstatus',
              subtitle:
                  'På: matchningar ser din aktivitet. Stäng av med ZULLO Premium för att dölja online och senast aktiv.',
              value: _showActivityStatus,
              onChanged: (value) => _savePrivacy(showActivity: value),
            ),
            const SizedBox(height: 8),
            _SettingsSwitchRow(
              icon: Icons.visibility_off,
              title: 'Inkognito Premium',
              subtitle: 'Bara personer som du gillar kan se din profil',
              value: _incognitoMode,
              onChanged: (value) => _savePrivacy(incognito: value),
            ),
            const SizedBox(height: 8),
           _SettingsArrowRow(
  icon: Icons.alternate_email,
  title: 'E-post',
  subtitle: _emailText,
  onTap: () {},
),
            const SizedBox(height: 8),
_SettingsSwitchRow(
  icon: Icons.campaign,
  title: 'Marknadsföringstillstånd',
  subtitle: 'Jag tillåter ZULLO att använda min profil och mina bilder i våra reklamer',
  value: _marketingConsent,
  onChanged: (value) {
    setState(() {
      _marketingConsent = value;
    });
  },
),
const SizedBox(height: 8),
_SettingsArrowRow(
  icon: Icons.block,
  title: 'Blockerade profiler',
  subtitle: 'Personer du har blockerat',
  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedProfilesPage())),
),
const SizedBox(height: 8),
_SettingsArrowRow(
  icon: Icons.delete_outline,
  title: 'Radera eller pausa konto',
  subtitle: 'Hantera ditt konto',
  onTap: () {},
),
const SizedBox(height: 28),
Text(
  'User ID: $_userIdText',
  style: const TextStyle(
    color: Colors.black38,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  ),
),
const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SettingsArrowRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsArrowRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  icon,
                  color: Colors.black87,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(
                  Icons.chevron_right,
                  color: Colors.black38,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(
              icon,
              color: Colors.black87,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}