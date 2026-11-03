import 'l10n/localization.dart';
import 'theme/zullo_palette.dart';
import 'services/profile_images.dart';
import 'widgets/commerce_cards.dart';
import 'dart:async';
import 'services/commerce_service.dart';
import 'services/account_session.dart';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'edit_profile_page.dart';
import 'profile_settings_page.dart';
import 'premium_page.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final AuthService _authService = AuthService();

  CommerceState? _wallet;
  StreamSubscription<void>? _commerceEvents;
  final _generation = AccountSession.generation;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadWallet();
    _commerceEvents = CommerceEvents.walletStream.listen((_) => _loadWallet());
  }

  @override
  void dispose() {
    _commerceEvents?.cancel();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    try {
      final wallet = await CommerceClient().state();
      if (mounted && AccountSession.isCurrent(_generation)) {
        setState(() => _wallet = wallet);
      }
    } catch (_) {/* profile remains usable if commerce is unavailable */}
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _authService.getMyProfile();

      if (!mounted) return;

      setState(() {
        _profile = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = "Kunde inte ladda profil";
        _isLoading = false;
      });
    }
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EditProfilePage(),
      ),
    );

    if (result == true) {
      _loadProfile();
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileSettingsPage(),
      ),
    );
  }

  Future<void> _openPhotoPreview() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EditProfilePage(startInPreviewMode: true),
      ),
    );

    if (result == true) {
      _loadProfile();
    }
  }

  Future<void> _openPremiumPage({bool activityOnly = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PremiumPage(activityOnly: activityOnly),
      ),
    );
    _loadWallet();
  }

  Widget _buildMonetizationCard(
          {required IconData icon,
          required Color iconColor,
          required String title,
          required String subtitle,
          bool brand = false,
          bool activityOnly = false}) =>
      ProfilePurchaseCard(
          icon: icon,
          color: iconColor,
          title: title,
          subtitle: subtitle,
          brand: brand,
          onTap: activityOnly
              ? () => _openPremiumPage(activityOnly: true)
              : _openPremiumPage);

  Widget _buildPremiumBox() => PremiumBenefitsCard(
      active: _wallet?.premium == true, onTap: _openPremiumPage);

  Widget _buildProfileContent() {
    final photos = (_profile!["photoUrls"] as List?) ?? [];

    final imageUrl = photos.isNotEmpty ? photos[0].toString() : "";

    final displayName = (_profile!["displayName"] ?? "").toString();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.yourLocationOnZullo,
                style: TextStyle(
                    color: ZulloPalette.rose,
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _openPhotoPreview,
                  child: CircleAvatar(
                    radius: 34,
                    backgroundImage: imageUrl.isEmpty
                        ? null
                        : ProfileImages.thumbnail(imageUrl),
                    backgroundColor: Colors.grey.shade800,
                    child: imageUrl.isEmpty
                        ? const Icon(Icons.person_outline, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      color: Color(0xFF22262E),
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: context.l10n.accountSettings,
                  onPressed: _openSettings,
                  style: IconButton.styleFrom(
                      backgroundColor: ZulloPalette.tint,
                      foregroundColor: ZulloPalette.rose,
                      minimumSize: const Size(48, 48)),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 68,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZulloPalette.rose,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(34),
                  ),
                ),
                onPressed: _openEditProfile,
                icon: const Icon(Icons.edit, size: 28),
                label: Text(
                  context.l10n.editProfile,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            _buildMonetizationCard(
              icon: Icons.star_rounded,
              iconColor: const Color(0xFF3283E8),
              title: "${_wallet?.superLikes ?? '—'} Superlikes",
              subtitle: "FÅ MER",
            ),
            const SizedBox(height: 18),
            _buildMonetizationCard(
              icon: Icons.rocket_launch_rounded,
              iconColor: const Color(0xFFB57CFF),
              title: "Mina Boosts · ${_wallet?.boosts ?? '—'}",
              subtitle: "FÅ MER",
            ),
            const SizedBox(height: 18),
            _buildMonetizationCard(
              icon: Icons.visibility_off_outlined,
              iconColor: const Color(0xFF5C6F87),
              title: "Dölj aktivitet",
              subtitle: _wallet?.canHideActivity == true
                  ? "INGÅR FÖR DIG"
                  : "KÖP SEPARAT",
              activityOnly: true,
            ),
            const SizedBox(height: 18),
            _buildMonetizationCard(
              icon: Icons.workspace_premium_rounded,
              iconColor: const Color(0xFFFF7FA8),
              title: "Prenumerationer",
              brand: true,
              subtitle: "Se planer",
            ),
            const SizedBox(height: 22),
            _buildPremiumBox(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZulloPalette.canvas,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                  ),
                )
              : _profile == null
                  ?  Center(
                      child: Text(
                        context.l10n.noProfile,
                        style: TextStyle(color: Color(0xFF22262E)),
                      ),
                    )
                  : _buildProfileContent(),
    );
  }
}
