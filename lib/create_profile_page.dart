import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_storage.dart';

import 'home_page.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';

class CreateProfilePage extends StatefulWidget {
  const CreateProfilePage({super.key});

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  final _displayName = TextEditingController();
  final _age = TextEditingController(text: "24");
  final _gender = TextEditingController(text: "Man");
  final _bio = TextEditingController(text: "Hej! Jag söker en seriös relation.");
  String _selectedIntention = "Relationship";
   String _selectedReligion = "Private";

  final ImagePicker _picker = ImagePicker();
List<String> _photoUrls = [];
bool _isUploadingImage = false;

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _displayName.dispose();
    _age.dispose();
    _gender.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
 final picked = await _picker.pickImage(
  source: ImageSource.gallery,
  imageQuality: 82,
  maxWidth: 1440,
  maxHeight: 1440,
);

  if (picked == null) return;

  setState(() {
    _isUploadingImage = true;
    _error = null;
  });

  final file = File(picked.path);

  final url = await CloudinaryService.uploadImage(file);

  if (url != null) {
    setState(() {
      _photoUrls.add(url);
      _isUploadingImage = false;
    });
  } else {
    setState(() {
      _isUploadingImage = false;
      _error = "Bild-upload misslyckades.";
    });
  }
}

  Future<void> _saveProfile() async {
    final name = _displayName.text.trim();
    final age = int.tryParse(_age.text.trim()) ?? 0;
    final gender = _gender.text.trim();
    final bio = _bio.text.trim();

    if (name.isEmpty || age < 18 || gender.isEmpty) {
  setState(() => _error = "Fyll i namn, kön och ålder (18+).");
  return;
}

if (_photoUrls.length < 2) {
  setState(() => _error = "Lägg till minst 2 bilder.");
  return;
}

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // ✅ SUPERENKELT (A): hårdkodade testvärden
    const lat = 59.3293; // Stockholm
    const lng = 18.0686;
    const countryCode = "SE";

    final body = {
      "displayName": name,
      "age": age,
      "gender": gender,
      "bio": bio,

      // enums i backend skickas som string (du har JsonStringEnumConverter)
     "intention": _selectedIntention,
      "religion": _selectedReligion,
      "workout": "Sometimes",
      "smoking": "No",
      "pets": "Want",

      "interests": ["Musik", "Resor"],
     "photoUrls": _photoUrls,

      "lat": lat,
      "lng": lng,
      "countryCode": countryCode
    };

    try {
  // 1) Hämta token
  final token = await AuthStorage().getToken();
  if (token == null || token.isEmpty) {
    setState(() => _error = "Du är inte inloggad. Logga in igen.");
    return;
  }

  // 2) Skicka POST med Bearer token
  final res = await http.post(
  Uri.parse("http://10.0.2.2:5125/me/profile"),
  headers: {
    "Content-Type": "application/json",
    "Authorization": "Bearer $token",
  },
  body: jsonEncode(body),
);

  // 3) Acceptera både 200 och 201 (backend kan returnera 201)
  if (res.statusCode == 200 || res.statusCode == 201) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  } else if (res.statusCode == 401) {
    setState(() => _error = "Din inloggning har gått ut. Logga in igen.");
  } else {
    setState(() => _error = "Kunde inte spara profil: ${res.statusCode} ${res.body}");
  }
} catch (e) {
  setState(() => _error = "Nätverksfel: $e");
}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Skapa profil")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Snabbprofil (MVP)", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            TextField(controller: _displayName, decoration: const InputDecoration(labelText: "Namn (display)")),
            const SizedBox(height: 12),
            TextField(controller: _age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Ålder")),
            const SizedBox(height: 12),
            TextField(controller: _gender, decoration: const InputDecoration(labelText: "Kön (t.ex. Man/Kvinna)")),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
  value: _selectedIntention,
  decoration: const InputDecoration(
    labelText: "Vad söker du?",
  ),
  items: const [
    DropdownMenuItem(value: "Date", child: Text("Date")),
    DropdownMenuItem(value: "Relationship", child: Text("Relationship")),
    DropdownMenuItem(value: "Marriage", child: Text("Marriage")),
  ],
  onChanged: (value) {
    if (value == null) return;
    setState(() {
      _selectedIntention = value;
    });
  },
),
const SizedBox(height: 12),

DropdownButtonFormField<String>(
  value: _selectedReligion,
  decoration: const InputDecoration(
    labelText: "Religion",
  ),
  items: const [
    DropdownMenuItem(value: "Christian", child: Text("Christian")),
    DropdownMenuItem(value: "Muslim", child: Text("Muslim")),
    DropdownMenuItem(value: "Atheist", child: Text("Atheist")),
    DropdownMenuItem(value: "Private", child: Text("Private")),
  ],
  onChanged: (value) {
    if (value == null) return;
    setState(() {
      _selectedReligion = value;
    });
  },
),
const SizedBox(height: 12),

          
           TextField(controller: _bio, maxLines: 3, decoration: const InputDecoration(labelText: "Om mig")),

const SizedBox(height: 16),

SizedBox(
  height: 48,
  child: OutlinedButton(
    onPressed: _isUploadingImage ? null : _pickAndUploadImage,
    child: _isUploadingImage
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Text("Lägg till bild från galleri"),
  ),
),

const SizedBox(height: 12),

if (_photoUrls.isNotEmpty)
  Wrap(
    spacing: 8,
    runSpacing: 8,
    children: _photoUrls.map((url) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: 90,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    }).toList(),
  ),

if (_error != null) ...[
  const SizedBox(height: 12),
  Text(_error!, style: const TextStyle(color: Colors.red)),
],

const SizedBox(height: 20),

SizedBox(
  height: 48,
  child: ElevatedButton(
    onPressed: _isLoading ? null : _saveProfile,
    child: _isLoading
        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
        : const Text("Spara och fortsätt"),
  ),
),
          ],
        ),
      ),
    );
  }
}
