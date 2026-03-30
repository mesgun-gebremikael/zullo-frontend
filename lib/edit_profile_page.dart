import 'dart:io';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'services/cloudinary_service.dart';


class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final AuthService _authService = AuthService();

  final _displayName = TextEditingController();
  final _age = TextEditingController();
  final _gender = TextEditingController();
  final _bio = TextEditingController();

   List<String> _photoUrls = [];
   bool _isUploadingPhoto = false;

  bool _isLoading = true;  
  bool _isSaving = false;
  bool _isPreviewMode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  @override
  void dispose() {
    _displayName.dispose();
    _age.dispose();
    _gender.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _loadMyProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await _authService.getMyProfile();

      _displayName.text = (profile["displayName"] ?? "").toString();
      _age.text = (profile["age"] ?? "").toString();
      _gender.text = (profile["gender"] ?? "").toString();
      _bio.text = (profile["bio"] ?? "").toString();
       _photoUrls = ((profile["photoUrls"] as List?) ?? [])
    .map((e) => e.toString())
    .toList();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = "Kunde inte ladda profil: $e";
        _isLoading = false;
      });
    }
  }
  
  Future<void> _addPhoto() async {
  if (_photoUrls.length >= 6) {
    setState(() {
      _error = "Du kan ha max 6 bilder.";
    });
    return;
  }

  try {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    setState(() {
      _isUploadingPhoto = true;
      _error = null;
    });

    final uploadedUrl = await CloudinaryService.uploadImage(
      File(pickedFile.path),
    );

    if (!mounted) return;

    if (uploadedUrl == null || uploadedUrl.isEmpty) {
      setState(() {
        _isUploadingPhoto = false;
        _error = "Kunde inte ladda upp bilden.";
      });
      return;
    }

    setState(() {
      _photoUrls.add(uploadedUrl);
      _isUploadingPhoto = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _isUploadingPhoto = false;
      _error = "Fel vid bildupload: $e";
    });
  }
}

void _removePhotoAt(int index) {
  setState(() {
    _photoUrls.removeAt(index);
    _error = null;
  });
}



  Future<void> _saveProfile() async {
    final name = _displayName.text.trim();
    final age = int.tryParse(_age.text.trim()) ?? 0;
    final gender = _gender.text.trim();
    final bio = _bio.text.trim();

    if (name.isEmpty || age < 18 || gender.isEmpty) {
      setState(() {
        _error = "Fyll i namn, kön och ålder (18+).";
      });
      return;
    }

    if (_photoUrls.length < 2) {
  setState(() {
    _error = "Du måste ha minst 2 profilbilder.";
  });
  return;
}

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final current = await _authService.getMyProfile();

final interests = ((current["interests"] as List?) ?? [])
    .map((e) => e.toString())
    .toList();

await _authService.saveProfile(
  displayName: name,
  age: age,
  gender: gender,
  bio: bio,
  photoUrls: _photoUrls,
  interests: interests,
);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profilen sparades.")),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = "Kunde inte spara profil: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildTopToggle() {
  return Row(
    children: [
      Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isPreviewMode = false;
            });
          },
          child: Center(
            child: Text(
              "Redigera",
              style: TextStyle(
                color: _isPreviewMode ? Colors.grey : const Color(0xFFE91E63),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
      Container(
        width: 1,
        height: 34,
        color: Colors.grey.shade300,
      ),
      Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isPreviewMode = true;
            });
          },
          child: Center(
            child: Text(
              "Min profil",
              style: TextStyle(
                color: _isPreviewMode ? const Color(0xFFE91E63) : Colors.grey,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: AppBar(
    centerTitle: true,
   title: Text(_isPreviewMode ? "Min profil" : "Redigera Info"),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: GestureDetector(
          onTap: _isSaving ? null : _saveProfile,
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFF1F2430),
              shape: BoxShape.circle,
            ),
            child: _isSaving
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 28,
                  ),
          ),
        ),
      ),
    ],
  ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _displayName.text.isEmpty
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                   children: [
  const SizedBox(height: 8),
  _buildTopToggle(),
  const SizedBox(height: 24),

  const Text(
    "MEDIA",
    style: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
    ),
  ),
  const SizedBox(height: 12),
  Text(
    "Lägg till max 6 bilder.",
    style: TextStyle(
      fontSize: 16,
      color: Colors.grey.shade700,
    ),
  ),
  const SizedBox(height: 18),

  GridView.count(
  crossAxisCount: 3,
  shrinkWrap: true,
  crossAxisSpacing: 10,
  mainAxisSpacing: 10,
  physics: NeverScrollableScrollPhysics(),
  children: [
    ..._photoUrls.asMap().entries.map((entry) {
      int index = entry.key;
      String url = entry.value;

      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          Positioned(
            top: 5,
            right: 5,
            child: GestureDetector(
              onTap: () => _removePhotoAt(index),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      );
    }),

    if (_photoUrls.length < 6)
      GestureDetector(
        onTap: _addPhoto,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey,
          ),
          child: const Center(
            child: Icon(Icons.add, color: Colors.white, size: 30),
          ),
        ),
      ),
  ],
),

const SizedBox(height: 20),



                      TextField(
                        controller: _displayName,
                        decoration: const InputDecoration(
                          labelText: "Namn (display)",
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _age,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Ålder",
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _gender,
                        decoration: const InputDecoration(
                          labelText: "Kön",
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _bio,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: "Om mig",
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],

                      const SizedBox(height: 20),

                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          child: _isSaving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text("Spara ändringar"),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}