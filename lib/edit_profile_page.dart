import 'dart:io';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'services/cloudinary_service.dart';
import 'models/swipe_profile.dart';
import 'widgets/swipe_profile_card.dart';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';


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
String _childrenCount = "";
String _wantChildren = "";

String _relationshipHistory = "";
String _zodiacSign = "";
String _alcohol = "";
String _cannabis = "";

String _workStatus = "";
final _studyPlace = TextEditingController();
final _studySubject = TextEditingController();
final _workPlace = TextEditingController();
final _jobTitle = TextEditingController();
final _livePlace = TextEditingController();
final _originPlace = TextEditingController();



int _heightCm = 170;

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
_livePlace.dispose();
_originPlace.dispose();
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
_heightCm = (profile["heightCm"] as num?)?.toInt() ?? 170;

_relationshipHistory = (profile["relationshipHistory"] ?? "").toString();
_zodiacSign = (profile["zodiacSign"] ?? "").toString();

_alcohol = (profile["alcohol"] ?? "").toString();
_cannabis = (profile["cannabis"] ?? "").toString();

_childrenCount = (profile["childrenCount"] ?? "").toString();
_wantChildren = (profile["wantChildren"] ?? "").toString();

_workStatus = (profile["workStatus"] ?? "").toString();
_studyPlace.text = (profile["studyPlace"] ?? "").toString();
_studySubject.text = (profile["studySubject"] ?? "").toString();
_workPlace.text = (profile["workPlace"] ?? "").toString();
_jobTitle.text = (profile["jobTitle"] ?? "").toString();

_livePlace.text = (profile["livePlace"] ?? "").toString();
_originPlace.text = (profile["originPlace"] ?? "").toString();


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

            print('EDIT PROFILE values before save:');
      print('heightCm=$_heightCm');
      print('relationshipHistory=$_relationshipHistory');
      print('zodiacSign=$_zodiacSign');
      print('alcohol=$_alcohol');
      print('cannabis=$_cannabis');
      print('childrenCount=$_childrenCount');
      print('wantChildren=$_wantChildren');
      print('workStatus=$_workStatus');
      print('studyPlace=${_studyPlace.text}');
      print('studySubject=${_studySubject.text}');
      print('workPlace=${_workPlace.text}');
      print('jobTitle=${_jobTitle.text}');
      print('livePlace=${_livePlace.text}');
      print('originPlace=${_originPlace.text}');
  await _authService.saveProfile(
  displayName: _displayName.text,
  age: int.parse(_age.text),
  gender: _gender.text,
  bio: _bio.text,
  photoUrls: _photoUrls,
  interests: _interests,
  intention: _intention,
  religion: _religion,
  workout: _workout,
  smoking: _smoking,
  pets: _pets,

  // 🔥 NYA FÄLT (DETTA VAR BUGGEN)
  heightCm: _heightCm,
  relationshipHistory: _relationshipHistory,
  zodiacSign: _zodiacSign,
  alcohol: _alcohol,
  cannabis: _cannabis,
  childrenCount: _childrenCount,
  wantChildren: _wantChildren,
  workStatus: _workStatus,
  studyPlace: _studyPlace.text,
  studySubject: _studySubject.text,
  workPlace: _workPlace.text,
  jobTitle: _jobTitle.text,
  livePlace: _livePlace.text,
  originPlace: _originPlace.text,
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

    heightCm: _heightCm,
    relationshipHistory: _relationshipHistory,
    zodiacSign: _zodiacSign,
    alcohol: _alcohol,
    cannabis: _cannabis,
    childrenCount: _childrenCount,
    wantChildren: _wantChildren,
    workStatus: _workStatus,
    studyPlace: _studyPlace.text.trim(),
    studySubject: _studySubject.text.trim(),
    workPlace: _workPlace.text.trim(),
    jobTitle: _jobTitle.text.trim(),
    livePlace: _livePlace.text.trim(),
    originPlace: _originPlace.text.trim(),

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

Widget _buildReligionSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildQuestionTitle(
        icon: Icons.spa_outlined,
        title: "Är du religiös?",
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _buildChoiceChip(
            label: "Agnostiker",
            selected: _religion == "Agnostiker",
            onTap: () {
              setState(() {
                _religion = "Agnostiker";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Ateist",
            selected: _religion == "Ateist",
            onTap: () {
              setState(() {
                _religion = "Ateist";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Buddhist",
            selected: _religion == "Buddhist",
            onTap: () {
              setState(() {
                _religion = "Buddhist";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Katolik",
            selected: _religion == "Katolik",
            onTap: () {
              setState(() {
                _religion = "Katolik";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Kristen",
            selected: _religion == "Kristen",
            onTap: () {
              setState(() {
                _religion = "Kristen";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Hindu",
            selected: _religion == "Hindu",
            onTap: () {
              setState(() {
                _religion = "Hindu";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Judisk",
            selected: _religion == "Judisk",
            onTap: () {
              setState(() {
                _religion = "Judisk";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Muslim",
            selected: _religion == "Muslim",
            onTap: () {
              setState(() {
                _religion = "Muslim";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
  label: "Ortodox",
  selected: _religion == "Ortodox",
  onTap: () {
    setState(() {
      _religion = "Ortodox";
      _cachedPreviewProfile = null;
    });
  },
),
          _buildChoiceChip(
            label: "Sikh",
            selected: _religion == "Sikh",
            onTap: () {
              setState(() {
                _religion = "Sikh";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Andlig, inte religiös",
            selected: _religion == "Andlig, inte religiös",
            onTap: () {
              setState(() {
                _religion = "Andlig, inte religiös";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Annat",
            selected: _religion == "Annat",
            onTap: () {
              setState(() {
                _religion = "Annat";
                _cachedPreviewProfile = null;
              });
            },
          ),
        ],
      ),
    ],
  );
}

Widget _buildLifestyleSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildQuestionTitle(
        icon: Icons.fitness_center_outlined,
        title: "Tränar du?",
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _buildChoiceChip(
            label: "Aldrig",
            selected: _workout == "Never",
            onTap: () {
              setState(() {
                _workout = "Never";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Ibland",
            selected: _workout == "Sometimes",
            onTap: () {
              setState(() {
                _workout = "Sometimes";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Ofta",
            selected: _workout == "Often",
            onTap: () {
              setState(() {
                _workout = "Often";
                _cachedPreviewProfile = null;
              });
            },
          ),
        ],
      ),

      const SizedBox(height: 24),

      _buildQuestionTitle(
        icon: Icons.pets_outlined,
        title: "Husdjur",
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _buildChoiceChip(
            label: "Har husdjur",
            selected: _pets == "Have",
            onTap: () {
              setState(() {
                _pets = "Have";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Vill ha husdjur",
            selected: _pets == "Want",
            onTap: () {
              setState(() {
                _pets = "Want";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Vill inte ha",
            selected: _pets == "No",
            onTap: () {
              setState(() {
                _pets = "No";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Allergisk",
            selected: _pets == "Allergic",
            onTap: () {
              setState(() {
                _pets = "Allergic";
                _cachedPreviewProfile = null;
              });
            },
          ),
        ],
      ),

      const SizedBox(height: 24),

      _buildQuestionTitle(
        icon: Icons.smoking_rooms_outlined,
        title: "Använder du nikotin?",
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _buildChoiceChip(
            label: "Nej",
            selected: _smoking == "No",
            onTap: () {
              setState(() {
                _smoking = "No";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Ibland",
            selected: _smoking == "Sometimes",
            onTap: () {
              setState(() {
                _smoking = "Sometimes";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Ja",
            selected: _smoking == "Yes",
            onTap: () {
              setState(() {
                _smoking = "Yes";
                _cachedPreviewProfile = null;
              });
            },
          ),
        ],
      ),
    ],
  );
}  


Widget _buildRelationshipHistorySection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildQuestionTitle(
        icon: Icons.favorite_outline_rounded,
        title: "Har du varit i en relation?",
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _buildChoiceChip(
            label: "Varit i ett förhållande",
            selected: _relationshipHistory == "relationship",
            onTap: () {
              setState(() {
                _relationshipHistory = "relationship";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Inget seriöst",
            selected: _relationshipHistory == "casual",
            onTap: () {
              setState(() {
                _relationshipHistory = "casual";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Aldrig haft ett förhållande",
            selected: _relationshipHistory == "never",
            onTap: () {
              setState(() {
                _relationshipHistory = "never";
                _cachedPreviewProfile = null;
              });
            },
          ),
        ],
      ),
    ],
  );
}

Widget _buildZodiacSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildQuestionTitle(
        icon: Icons.auto_awesome_outlined,
        title: "Vad är ditt stjärntecken?",
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _buildChoiceChip(
            label: "Vattuman",
            selected: _zodiacSign == "Vattuman",
            onTap: () {
              setState(() {
                _zodiacSign = "Vattuman";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Vädur",
            selected: _zodiacSign == "Vädur",
            onTap: () {
              setState(() {
                _zodiacSign = "Vädur";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Kräfta",
            selected: _zodiacSign == "Kräfta",
            onTap: () {
              setState(() {
                _zodiacSign = "Kräfta";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Stenbock",
            selected: _zodiacSign == "Stenbock",
            onTap: () {
              setState(() {
                _zodiacSign = "Stenbock";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Tvilling",
            selected: _zodiacSign == "Tvilling",
            onTap: () {
              setState(() {
                _zodiacSign = "Tvilling";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Lejon",
            selected: _zodiacSign == "Lejon",
            onTap: () {
              setState(() {
                _zodiacSign = "Lejon";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Våg",
            selected: _zodiacSign == "Våg",
            onTap: () {
              setState(() {
                _zodiacSign = "Våg";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Fisk",
            selected: _zodiacSign == "Fisk",
            onTap: () {
              setState(() {
                _zodiacSign = "Fisk";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Skytt",
            selected: _zodiacSign == "Skytt",
            onTap: () {
              setState(() {
                _zodiacSign = "Skytt";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Skorpion",
            selected: _zodiacSign == "Skorpion",
            onTap: () {
              setState(() {
                _zodiacSign = "Skorpion";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Oxe",
            selected: _zodiacSign == "Oxe",
            onTap: () {
              setState(() {
                _zodiacSign = "Oxe";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Jungfru",
            selected: _zodiacSign == "Jungfru",
            onTap: () {
              setState(() {
                _zodiacSign = "Jungfru";
                _cachedPreviewProfile = null;
              });
            },
          ),
        ],
      ),
    ],
  );
}

String _heightDisplayCm() {
  return "$_heightCm cm";
}

String _heightDisplayFt() {
  final totalInches = (_heightCm / 2.54).round();
  final feet = totalInches ~/ 12;
  final inches = totalInches % 12;
  return "$feet'$inches\"";
}

int _cmToFeet(int cm) {
  final totalInches = (cm / 2.54).round();
  return totalInches ~/ 12;
}

int _cmToInchesPart(int cm) {
  final totalInches = (cm / 2.54).round();
  return totalInches % 12;
}

int _feetAndInchesToCm(int feet, int inches) {
  final totalInches = (feet * 12) + inches;
  return (totalInches * 2.54).round();
}

Future<void> _openHeightPicker() async {
  int tempCm = _heightCm;

  int tempFeet = _cmToFeet(_heightCm);
  int tempInches = _cmToInchesPart(_heightCm);

  final cmController = FixedExtentScrollController(
    initialItem: math.max(0, tempCm - 140),
  );

  final feetController = FixedExtentScrollController(
    initialItem: math.max(0, tempFeet - 4),
  );

  final inchesController = FixedExtentScrollController(
    initialItem: tempInches.clamp(0, 11),
  );

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      bool useCm = true;

      return StatefulBuilder(
        builder: (context, setModalState) {
          final maxInchesForFeet = tempFeet >= 8 ? 6 : 11;

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Hur lång är du?",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _heightCm = tempCm.clamp(140, 260);
                            _cachedPreviewProfile = null;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1F2430),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              useCm = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: useCm
                                  ? const Color(0xFFE91E63)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              "cm",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: useCm ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              useCm = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !useCm
                                  ? const Color(0xFFE91E63)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              "fot",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !useCm ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 220,
                    child: useCm
                        ? CupertinoPicker(
                            scrollController: cmController,
                            itemExtent: 44,
                            onSelectedItemChanged: (index) {
                              tempCm = 140 + index;
                              tempFeet = _cmToFeet(tempCm);
                              tempInches = _cmToInchesPart(tempCm);
                            },
                            children: List.generate(
                              121,
                              (index) {
                                final cm = 140 + index;
                                return Center(
                                  child: Text(
                                    "$cm cm",
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                );
                              },
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: CupertinoPicker(
                                  scrollController: feetController,
                                  itemExtent: 44,
                                  onSelectedItemChanged: (index) {
                                    tempFeet = 4 + index;

                                    final maxAllowedInches =
                                        tempFeet >= 8 ? 6 : 11;

                                    if (tempInches > maxAllowedInches) {
                                      tempInches = maxAllowedInches;
                                    }

                                    tempCm = _feetAndInchesToCm(
                                      tempFeet,
                                      tempInches,
                                    ).clamp(140, 260);
                                  },
                                  children: List.generate(
                                    5,
                                    (index) {
                                      final ft = 4 + index;
                                      return Center(
                                        child: Text(
                                          "$ft fot",
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Expanded(
                                child: CupertinoPicker(
                                  scrollController: FixedExtentScrollController(
                                    initialItem: tempInches.clamp(0, maxInchesForFeet),
                                  ),
                                  itemExtent: 44,
                                  onSelectedItemChanged: (index) {
                                    tempInches = index;
                                    tempCm = _feetAndInchesToCm(
                                      tempFeet,
                                      tempInches,
                                    ).clamp(140, 260);
                                  },
                                  children: List.generate(
                                    maxInchesForFeet + 1,
                                    (index) {
                                      return Center(
                                        child: Text(
                                          "$index tum",
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "${tempCm} cm • ${_cmToFeet(tempCm)}'${_cmToInchesPart(tempCm)}\"",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildHeightSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildQuestionTitle(
        icon: Icons.height_rounded,
        title: "Hur lång är du?",
        subtitle: "Välj din längd i cm eller fot.",
      ),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: _openHeightPicker,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
         decoration: BoxDecoration(
  color: const Color(0xFFF7F7F7),
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: Colors.grey.shade200),
),
            
          
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "${_heightDisplayCm()} • ${_heightDisplayFt()}",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Icon(
                Icons.unfold_more_rounded,
                color: Color(0xFFE91E63),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildChildrenCountSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildQuestionTitle(
        icon: Icons.child_care_outlined,
        title: "Hur många barn har du?",
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _buildChoiceChip(
            label: "Jag har inga barn",
            selected: _childrenCount == "0",
            onTap: () {
              setState(() {
                _childrenCount = "0";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "1 barn",
            selected: _childrenCount == "1",
            onTap: () {
              setState(() {
                _childrenCount = "1";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "2 barn",
            selected: _childrenCount == "2",
            onTap: () {
              setState(() {
                _childrenCount = "2";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "3 barn",
            selected: _childrenCount == "3",
            onTap: () {
              setState(() {
                _childrenCount = "3";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "4 eller fler",
            selected: _childrenCount == "4+",
            onTap: () {
              setState(() {
                _childrenCount = "4+";
                _cachedPreviewProfile = null;
              });
            },
          ),
        ],
      ),
    ],
  );
}

Widget _buildWantChildrenSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildQuestionTitle(
        icon: Icons.stroller_outlined,
        title: "Vill du ha barn i framtiden?",
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _buildChoiceChip(
            label: "Jag vill ha barn",
            selected: _wantChildren == "yes",
            onTap: () {
              setState(() {
                _wantChildren = "yes";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Inte säker än",
            selected: _wantChildren == "maybe",
            onTap: () {
              setState(() {
                _wantChildren = "maybe";
                _cachedPreviewProfile = null;
              });
            },
          ),
          _buildChoiceChip(
            label: "Jag vill inte ha barn",
            selected: _wantChildren == "no",
            onTap: () {
              setState(() {
                _wantChildren = "no";
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

Widget _buildLivePlaceSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildQuestionTitle(
        icon: Icons.location_on_outlined,
        title: "Var bor du?",
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _livePlace,
        decoration: const InputDecoration(
          hintText: "Stockholm, Göteborg, Oslo...",
        ),
        onChanged: (_) {
          _cachedPreviewProfile = null;
        },
      ),
    ],
  );
}

Widget _buildOriginPlaceSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildQuestionTitle(
        icon: Icons.home_outlined,
        title: "Var kommer du ifrån?",
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _originPlace,
        decoration: const InputDecoration(
          hintText: "Asmara, Addis Abeba, Stockholm...",
        ),
        onChanged: (_) {
          _cachedPreviewProfile = null;
        },
      ),
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

_buildLivePlaceSection(),
const SizedBox(height: 24),

_buildOriginPlaceSection(),
const SizedBox(height: 24),

 _buildIntentionSection(),
const SizedBox(height: 24),

_buildHeightSection(),
const SizedBox(height: 24),

_buildLifestyleSection(),
const SizedBox(height: 24),

_buildRelationshipHistorySection(),
const SizedBox(height: 24),

_buildZodiacSection(),
const SizedBox(height: 24),

_buildReligionSection(),
const SizedBox(height: 24),

_buildChildrenCountSection(),
const SizedBox(height: 24),

_buildWantChildrenSection(),
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


