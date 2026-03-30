import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'edit_profile_page.dart';
import 'profile_settings_page.dart';
import 'profile_photo_preview_page.dart';

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

Future<void> _openPhotoPreview(String imageUrl) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProfilePhotoPreviewPage(imageUrl: imageUrl),
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

  Widget _buildProfileContent() {
    final photos = (_profile!["photoUrls"] as List?) ?? [];

    final imageUrl = photos.isNotEmpty
    ? photos[0].toString()
    : "https://images.unsplash.com/photo-1524504388940-b1c1722653e1";

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
           Stack(
  children: [
   GestureDetector(
  onTap: () => _openPhotoPreview(imageUrl),
  child: Container(
    height: 400,
    width: double.infinity,
    decoration: BoxDecoration(
      image: DecorationImage(
        image: NetworkImage(imageUrl),
        fit: BoxFit.cover,
      ),
    ),
  ),
),
    Positioned(
      top: 16,
      right: 16,
      child: GestureDetector(
        onTap: _openSettings,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.settings,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    ),
  ],
),
            const SizedBox(height: 16),

            Text(
              "${_profile!["displayName"] ?? ""}, ${_profile!["age"] ?? ""}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                (_profile!["bio"] ?? "").toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Padding(
  padding: const EdgeInsets.symmetric(horizontal: 24),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildInfoRow(
        "Söker",
        (_profile!["intention"] ?? "").toString(),
      ),
      _buildInfoRow(
        "Religion",
        (_profile!["religion"] ?? "").toString(),
      ),
      _buildInfoRow(
        "Träning",
        (_profile!["workout"] ?? "").toString(),
      ),
      _buildInfoRow(
        "Rökning",
        (_profile!["smoking"] ?? "").toString(),
      ),
      _buildInfoRow(
        "Husdjur",
        (_profile!["pets"] ?? "").toString(),
      ),
      _buildInfoRow(
        "Intressen",
        _formatList(_profile!["interests"]),
      ),
    ],
  ),
),

const SizedBox(height: 20),

            Container(
  width: double.infinity,
  margin: const EdgeInsets.symmetric(horizontal: 24),
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
    ),
    onPressed: _openEditProfile,
    child: const Text(
      "Redigera profil",
      style: TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
),
            const SizedBox(height: 40),
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