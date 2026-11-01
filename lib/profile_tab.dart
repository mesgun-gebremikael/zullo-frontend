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

  Future<void> _openPremiumPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PremiumPage(),
      ),
    );
    _loadWallet();
  }

  Widget _buildMonetizationCard(
          {required IconData icon,
          required Color iconColor,
          required String title,
          required String subtitle,
          bool brand = false}) =>
      ProfilePurchaseCard(
          icon: icon,
          color: iconColor,
          title: title,
          subtitle: subtitle,
          brand: brand,
          onTap: _openPremiumPage);

  Widget _buildPremiumBox() => PremiumBenefitsCard(
      active: _wallet?.premium == true, onTap: _openPremiumPage);

  Widget _buildProfileContent() {
    final photos = (_profile!["photoUrls"] as List?) ?? [];

    final imageUrl = photos.isNotEmpty
        ? photos[0].toString()
        : "https://images.unsplash.com/photo-1524504388940-b1c1722653e1";

    final displayName = (_profile!["displayName"] ?? "").toString();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _openPhotoPreview,
                  child: CircleAvatar(
                    radius: 34,
                    backgroundImage: NetworkImage(imageUrl),
                    backgroundColor: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      color: Color(0xFF22262E),
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _openSettings,
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.settings,
                      color: Color(0xFF22262E),
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 68,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(34),
                  ),
                ),
                onPressed: _openEditProfile,
                icon: const Icon(Icons.edit, size: 28),
                label: const Text(
                  "Redigera profil",
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
      backgroundColor: const Color(0xFFF0F1F3),
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
                  ? const Center(
                      child: Text(
                        "Ingen profil",
                        style: TextStyle(color: Color(0xFF22262E)),
                      ),
                    )
                  : _buildProfileContent(),
    );
  }
}
