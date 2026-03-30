import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/auth_storage.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {

final AuthService _authService = AuthService();
final AuthStorage _authStorage = AuthStorage();

String _emailText = 'Laddar...';
String _userIdText = 'Laddar...';

  bool _showActivityStatus = true;
  bool _incognitoMode = false;
  bool _marketingConsent = false;

  @override
void initState() {
  super.initState();
  _loadAccountInfo();
}

Future<void> _loadAccountInfo() async {
  try {
    final profile = await _authService.getMyProfile();
    final userId = await _authStorage.getUserId();

    if (!mounted) return;

    setState(() {
      _emailText = (profile["email"] ?? "Ingen e-post hittades").toString();
      _userIdText = userId ?? "Ingen user id hittades";
    });
  } catch (e) {
    if (!mounted) return;

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
                  'Andra användare kan se om du är aktiv eller nyligen varit aktiv',
              value: _showActivityStatus,
              onChanged: (value) {
                setState(() {
                  _showActivityStatus = value;
                });
              },
            ),
            const SizedBox(height: 8),
            _SettingsSwitchRow(
              icon: Icons.visibility_off,
              title: 'Inkognito Premium',
              subtitle: 'Bara personer som du gillar kan se din profil',
              value: _incognitoMode,
              onChanged: (value) {
                setState(() {
                  _incognitoMode = value;
                });
              },
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
  title: 'Blockade profiler',
  subtitle: 'Personer du har blockat',
  onTap: () {},
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