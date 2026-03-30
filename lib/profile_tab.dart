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

  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
}

Widget _buildInfoRow(String title, String value) {
  if (value.trim().isEmpty) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

String _formatList(dynamic value) {
  if (value is List && value.isNotEmpty) {
    return value.map((e) => e.toString()).join(", ");
  }
  return "";
}  
Widget _buildMonetizationCard({
  required IconData icon,
  required Color iconColor,
  required String title,
  required String subtitle,
}) {
  return GestureDetector(
    onTap: _openPremiumPage,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.03),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ),
        ],
      ),
    ),
  );
}
Widget _buildPremiumBox() {
  return GestureDetector(
    onTap: _openPremiumPage,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2B1B14),
            Color(0xFF17110E),
            Color(0xFF0F0F10),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFC08B5C).withOpacity(0.35),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFC08B5C).withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFE5B07A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "ZULLO Premium",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5B07A),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  "Uppgradera",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "Detta ingår",
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(
                child: Text(
                  "Se vem som gillar dig",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
              Icon(Icons.check_circle_rounded, color: Color(0xFFE5B07A)),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: Text(
                  "Toppval",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
              Icon(Icons.check_circle_rounded, color: Color(0xFFE5B07A)),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: Text(
                  "Superlikes ingår",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
              Icon(Icons.check_circle_rounded, color: Color(0xFFE5B07A)),
            ],
          ),
          const SizedBox(height: 28),
          const Center(
            child: Text(
              "Se alla funktioner",
              style: TextStyle(
                color: Color(0xFFE5B07A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

 Widget _buildProfileContent() {
  final photos = (_profile!["photoUrls"] as List?) ?? [];

  final imageUrl = photos.isNotEmpty
      ? photos[0].toString()
      : "https://images.unsplash.com/photo-1524504388940-b1c1722653e1";

  final displayName = (_profile!["displayName"] ?? "").toString();

  return SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
                    color: Colors.white,
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
                    color: Colors.white.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: Colors.white,
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
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
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
  icon: Icons.favorite_rounded,
  iconColor: const Color(0xFF58C4D8),
  title: "0 Superlikes",
  subtitle: "FÅ MER",
),
const SizedBox(height: 18),
_buildMonetizationCard(
  icon: Icons.rocket_launch_rounded,
  iconColor: const Color(0xFFB57CFF),
  title: "Mina Boosts",
  subtitle: "FÅ MER",
),
const SizedBox(height: 18),
_buildMonetizationCard(
  icon: Icons.workspace_premium_rounded,
  iconColor: const Color(0xFFFF7FA8),
  title: "Prenumerationer",
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
      backgroundColor: Colors.black,
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
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : _buildProfileContent(),
    );
  }
}