import 'l10n/localization.dart';
import 'l10n/language_settings_page.dart';
import 'l10n/locale_catalog.dart';
import 'l10n/locale_controller.dart';
import 'discovery_location_page.dart';
import 'welcome_page.dart';
import 'account_management_page.dart';
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

  String? _emailText;
  bool _emailLoading = true, _emailLoadFailed = false;

  bool _showActivityStatus = true;
  bool _incognitoMode = false;
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
      setState(() {
        _showActivityStatus = !state.hideActivity;
        _incognitoMode = state.incognito;
      });
    } catch (_) {/* keep settings usable while temporarily offline */}
  }

  Future<void> _savePrivacy({bool? showActivity, bool? incognito}) async {
    if (_privacyBusy) return;
    _privacyBusy = true;
    try {
      final state = await CommerceClient().privacy(
          hideActivity: !(showActivity ?? _showActivityStatus),
          incognito: incognito ?? _incognitoMode);
      if (!mounted || !AccountSession.isCurrent(_generation)) return;
      setState(() {
        _showActivityStatus = !state.hideActivity;
        _incognitoMode = state.incognito;
      });
      CommerceEvents.refreshDiscovery();
    } on CommerceException catch (error) {
      if (!mounted) return;
      if (error.status == 402) {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => PremiumPage(
                    activityOnly: showActivity == false && incognito != true)));
        await _loadPrivacy();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr(error.message))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.thisSettingCouldNotBeSavedTryAgain)));
      }
    } finally {
      _privacyBusy = false;
    }
  }

  bool _loggingOut = false;
  Future<void> _logout() async {
    if (_loggingOut || !AccountSession.isCurrent(_generation)) return;
    _loggingOut = true;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(context.l10n.logOutOfZullo),
              content: Text(
                  context.l10n.yourProfileAndConversationsWillBeHereWhenYouLog),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(context.l10n.stay)),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(context.l10n.logOut))
              ],
            ));
    if (!mounted || !AccountSession.isCurrent(_generation)) return;
    if (accepted != true) {
      _loggingOut = false;
      return;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _authService.logout();
      if (AccountSession.isCurrent(_generation + 1) && navigator.mounted) {
        navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WelcomePage()),
            (_) => false);
      }
    } on SessionChangedException {
      // A newer account owns navigation now.
    } catch (_) {
      if (AccountSession.isCurrent(_generation + 1) && navigator.mounted) {
        navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WelcomePage()),
            (_) => false);
      } else if (AccountSession.isCurrent(_generation) && messenger.mounted) {
        messenger.showSnackBar(
            SnackBar(content: Text(context.l10n.couldNotLogOutTryAgain)));
      }
    } finally {
      _loggingOut = false;
    }
  }

  Future<void> _loadAccountInfo() async {
    try {
      final profile = await _authService.getMyAccount();

      if (!mounted || !AccountSession.isCurrent(_generation)) return;

      setState(() {
        _emailText = profile["email"]?.toString();
        _emailLoading = false;
      });
    } catch (e) {
      if (!mounted || !AccountSession.isCurrent(_generation)) return;

      setState(() {
        _emailLoading = false;
        _emailLoadFailed = true;
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
        title: Text(
          context.l10n.accountSettings,
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 21,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: LocaleController.instance,
              builder: (context, _) => _SettingsArrowRow(
                icon: Icons.language,
                title: context.l10n.languageSettingsTitle,
                subtitle: LocaleController.instance.locale == null
                    ? context.l10n.languageAutomatic
                    : LocaleCatalog.name(LocaleController.instance.locale!),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LanguageSettingsPage())),
              ),
            ),
            const SizedBox(height: 8),
            _SettingsArrowRow(
                icon: Icons.near_me_outlined,
                title: 'Plats & upptäckt',
                subtitle:
                    context.tr('Din plats och val för en bredare sökning'),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DiscoveryLocationPage()))),
            const SizedBox(height: 8),
            _SettingsArrowRow(
              icon: Icons.verified,
              title: 'Verifiera profil',
              subtitle: context.tr('Verifiering är inte tillgänglig ännu'),
              onTap: null,
            ),
            const SizedBox(height: 8),
            _SettingsSwitchRow(
              icon: Icons.power_settings_new,
              title: 'Aktivitetsstatus',
              subtitle: context.tr(
                  'På: matchningar ser din aktivitet. Stäng av med Dölj aktivitet eller ZULLO Premium för att dölja online och senast aktiv.'),
              value: _showActivityStatus,
              onChanged: (value) => _savePrivacy(showActivity: value),
            ),
            const SizedBox(height: 8),
            _SettingsSwitchRow(
              icon: Icons.visibility_off,
              title: 'Inkognito Premium',
              subtitle:
                  context.tr('Bara personer som du gillar kan se din profil'),
              value: _incognitoMode,
              onChanged: (value) => _savePrivacy(incognito: value),
            ),
            const SizedBox(height: 8),
            _SettingsArrowRow(
              icon: Icons.alternate_email,
              title: 'E-post',
              subtitle: _emailLoading
                  ? context.l10n.loading
                  : _emailLoadFailed
                      ? context.l10n.yourAccountCouldNotBeLoaded
                      : _emailText ?? context.l10n.notSpecified,
              onTap: null,
            ),
            const SizedBox(height: 8),
            _SettingsArrowRow(
              icon: Icons.block,
              title: 'Blockerade profiler',
              subtitle: context.tr('Personer du har blockerat'),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BlockedProfilesPage())),
            ),
            const SizedBox(height: 8),
            _SettingsArrowRow(
              icon: Icons.delete_outline,
              title: 'Radera eller pausa konto',
              subtitle: context.tr('Ta en paus eller stäng ditt konto'),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AccountManagementPage())),
            ),
            const SizedBox(height: 24),
            _SettingsArrowRow(
                icon: Icons.logout_rounded,
                title: 'Logga ut',
                subtitle: context.tr('Din profil finns kvar'),
                onTap: _logout),
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
  final VoidCallback? onTap;

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
                      context.tr(title),
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
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left
                        : Icons.chevron_right,
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
                  context.tr(title),
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
