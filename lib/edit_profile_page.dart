import 'dart:io';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'services/cloudinary_service.dart';


class EditProfilePage extends StatefulWidget {
  final bool startInPreviewMode;

  const EditProfilePage({
    super.key,
    this.startInPreviewMode = false,
  });

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
List<String> _interests = [];

String _intention = "";
String _religion = "";
String _workout = "";
String _smoking = "";
String _pets = "";

bool _isUploadingPhoto = false;

bool _isLoading = true;
bool _isSaving = false;
bool _isPreviewMode = false;
String? _error;

 @override
void initState() {
  super.initState();
  _isPreviewMode = widget.startInPreviewMode;
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

_interests = ((profile["interests"] as List?) ?? [])
    .map((e) => e.toString())
    .toList();

_intention = (profile["intention"] ?? "").toString();
_religion = (profile["religion"] ?? "").toString();
_workout = (profile["workout"] ?? "").toString();
_smoking = (profile["smoking"] ?? "").toString();
_pets = (profile["pets"] ?? "").toString();

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

List<String> _buildPreviewChips() {
  final chips = <String>[];

  if (_intention.trim().isNotEmpty) chips.add(_intention.trim());
  if (_religion.trim().isNotEmpty) chips.add(_religion.trim());
  if (_workout.trim().isNotEmpty) chips.add(_workout.trim());
  if (_smoking.trim().isNotEmpty) chips.add(_smoking.trim());
  if (_pets.trim().isNotEmpty) chips.add(_pets.trim());

  chips.addAll(
    _interests
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty),
  );

  return chips;
}



Widget _buildPreviewChip(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.16),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    ),
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
        : _isPreviewMode
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _buildTopToggle(),
                    const SizedBox(height: 24),
                   Expanded(
  child: EditProfilePreviewCard(
    photoUrls: _photoUrls,
    displayName: _displayName.text.trim(),
    ageText: _age.text.trim(),
    bio: _bio.text.trim(),
    chips: _buildPreviewChips(),
  ),
),
                  ],
                ),
              )
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
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        ..._photoUrls.asMap().entries.map((entry) {
                          final index = entry.key;
                          final url = entry.value;

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
                                    decoration: const BoxDecoration(
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
                                child: Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 30,
                                ),
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

class EditProfilePreviewCard extends StatefulWidget {
  final List<String> photoUrls;
  final String displayName;
  final String ageText;
  final String bio;
  final List<String> chips;

  const EditProfilePreviewCard({
    super.key,
    required this.photoUrls,
    required this.displayName,
    required this.ageText,
    required this.bio,
    required this.chips,
  });

  @override
  State<EditProfilePreviewCard> createState() => _EditProfilePreviewCardState();
}

class _EditProfilePreviewCardState extends State<EditProfilePreviewCard> {
  late final PageController _pageController;
  int _currentImageIndex = 0;

  List<String> get _photos {
    if (widget.photoUrls.isNotEmpty) return widget.photoUrls;
    return [
      "https://images.unsplash.com/photo-1524504388940-b1c1722653e1",
    ];
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant EditProfilePreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_currentImageIndex >= _photos.length) {
      _currentImageIndex = 0;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pageController.jumpToPage(0);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildPreviewChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 520,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _photos.length,
              onPageChanged: (index) {
                setState(() {
                  _currentImageIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return Image.network(
                  _photos[index],
                  fit: BoxFit.cover,
                );
              },
            ),

            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.10),
                      Colors.black.withOpacity(0.18),
                      Colors.black.withOpacity(0.78),
                    ],
                  ),
                ),
              ),
            ),

            IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                        _photos.length,
                        (index) => Expanded(
                          child: Container(
                            height: 4,
                            margin: EdgeInsets.only(
                              right: index == _photos.length - 1 ? 0 : 6,
                            ),
                            decoration: BoxDecoration(
                              color: index == _currentImageIndex
                                  ? Colors.white
                                  : Colors.white38,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.ageText.isNotEmpty
                          ? "${widget.displayName} ${widget.ageText}"
                          : widget.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Om mig & Livsstil",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.chips.isNotEmpty) ...[
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: widget.chips
                            .take(8)
                            .map((chip) => _buildPreviewChip(chip))
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (widget.bio.isNotEmpty)
                      Text(
                        widget.bio,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}