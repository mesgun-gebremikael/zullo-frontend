import 'dart:io';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'services/cloudinary_service.dart';
import 'models/swipe_profile.dart';
import 'widgets/swipe_profile_card.dart';

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
   SwipeProfile? _cachedPreviewProfile;
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

String _workStatus = "";
final _studyPlace = TextEditingController();
final _studySubject = TextEditingController();
final _workPlace = TextEditingController();
final _jobTitle = TextEditingController();

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
  _studyPlace.dispose();
  _studySubject.dispose();
  _workPlace.dispose();
  _jobTitle.dispose();
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

SwipeProfile _buildPreviewProfile() {
  if (_cachedPreviewProfile != null) {
    return _cachedPreviewProfile!;
  }

  final profile = SwipeProfile(
    userId: 'preview-user',
    displayName: _displayName.text.trim().isEmpty
        ? 'Din profil'
        : _displayName.text.trim(),
    age: int.tryParse(_age.text.trim()) ?? 18,
    countryCode: '',
    intention: _intention,
    photoUrls: _photoUrls,
    bio: _bio.text.trim(),
    religion: _religion,
    workout: _workout,
    smoking: _smoking,
    pets: _pets,
    interests: _interests,
    distanceKm: 0,
  );

  _cachedPreviewProfile = profile;
  return profile;
}

Widget _buildChoiceChip({
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE91E63) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? const Color(0xFFE91E63) : Colors.grey.shade300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

Widget _buildQuestionTitle({
  required IconData icon,
  required String title,
  String? subtitle,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFFE91E63),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildIntentionSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildQuestionTitle(
        icon: Icons.favorite_border_rounded,
        title: "Vad hoppas du hitta här?",
        subtitle: "Välj det som passar dig bäst just nu.",
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _buildChoiceChip(
            label: "Date",
            selected: _intention == "Date",
            onTap: () {
              setState(() {
                _intention = "Date";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Relation",
            selected: _intention == "Relationship",
            onTap: () {
              setState(() {
                _intention = "Relationship";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Gifta mig",
            selected: _intention == "Marriage",
            onTap: () {
              setState(() {
                _intention = "Marriage";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Något seriöst",
            selected: _intention == "Serious",
            onTap: () {
              setState(() {
                _intention = "Serious";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Jag vet inte än",
            selected: _intention == "NotSure",
            onTap: () {
              setState(() {
                _intention = "NotSure";
                _cachedPreviewProfile = null;
              });
            },
          ),
        ],
      ),
    ],
  );
}

Widget _buildWorkStudySection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildQuestionTitle(
        icon: Icons.work_outline_rounded,
        title: "Vad jobbar du med?",
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _buildChoiceChip(
            label: "Pluggar just nu",
            selected: _workStatus == "study",
            onTap: () {
              setState(() {
                _workStatus = "study";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Jobbar just nu",
            selected: _workStatus == "work",
            onTap: () {
              setState(() {
                _workStatus = "work";
                _cachedPreviewProfile = null;
              });
            },
          ),
        ],
      ),

      if (_workStatus == "study") ...[
        const SizedBox(height: 24),
        _buildQuestionTitle(
          icon: Icons.school_outlined,
          title: "Var pluggar du?",
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _studyPlace,
          decoration: const InputDecoration(
            hintText: "Stockholm, universitet, skola...",
          ),
          onChanged: (_) {
            _cachedPreviewProfile = null;
          },
        ),
        const SizedBox(height: 20),
        _buildQuestionTitle(
          icon: Icons.menu_book_outlined,
          title: "Vad pluggar du?",
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _studySubject,
          decoration: const InputDecoration(
            hintText: "Data, ekonomi, vård...",
          ),
          onChanged: (_) {
            _cachedPreviewProfile = null;
          },
        ),
      ],

      if (_workStatus == "work") ...[
        const SizedBox(height: 24),
        _buildQuestionTitle(
          icon: Icons.business_outlined,
          title: "Var jobbar du?",
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _workPlace,
          decoration: const InputDecoration(
            hintText: "Företag, plats, bransch...",
          ),
          onChanged: (_) {
            _cachedPreviewProfile = null;
          },
        ),
        const SizedBox(height: 20),
        _buildQuestionTitle(
          icon: Icons.badge_outlined,
          title: "Vad har du för jobbtitel?",
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _jobTitle,
          decoration: const InputDecoration(
            hintText: "Utvecklare, lärare, chaufför...",
          ),
          onChanged: (_) {
            _cachedPreviewProfile = null;
          },
        ),
      ],
    ],
  );
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
  child: LayoutBuilder(
    builder: (context, constraints) {
      return Center(
        child: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: SwipeProfileCard(
            profile: _buildPreviewProfile(),
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            photoBarsTop: 66,
            distanceFallbackKm: 0,
          ),
        ),
      );
    },
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

                   _buildWorkStudySection(),
                    const SizedBox(height: 24),

                   _buildIntentionSection(),
                    const SizedBox(height: 24),

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


