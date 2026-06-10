import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';
import 'onboarding_data.dart';

class OnboardingPhotosPage extends StatefulWidget {
  final OnboardingData data;

  const OnboardingPhotosPage({
    super.key,
    required this.data,
  });

  @override
  State<OnboardingPhotosPage> createState() => _OnboardingPhotosPageState();
}

class _OnboardingPhotosPageState extends State<OnboardingPhotosPage> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String? _error;

  Future<void> _pickAndUploadImage() async {
    if (widget.data.photoUrls.length >= 6 || _isUploading) return;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1440,
      maxHeight: 1440,
    );

    if (picked == null) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    final file = File(picked.path);
    final url = await CloudinaryService.uploadImage(file);

    if (!mounted) return;

    if (url != null) {
      setState(() {
        widget.data.photoUrls.add(url);
        _isUploading = false;
      });
    } else {
      setState(() {
        _isUploading = false;
        _error = 'Bild-upload misslyckades.';
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      widget.data.photoUrls.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = widget.data.photoUrls.length >= 2 && !_isUploading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LinearProgressIndicator(
                value: 0.92,
                minHeight: 4,
                color: Color(0xFFFF4458),
                backgroundColor: Color(0xFFE8E8E8),
              ),
              const SizedBox(height: 18),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new),
              ),
              const SizedBox(height: 20),
              const Text(
                "Lägg till dina bilder",
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF20242C),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Minst 2 bilder krävs för att använda ZULLO.",
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 30),

              Expanded(
                child: GridView.builder(
                  itemCount: 6,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final hasPhoto = index < widget.data.photoUrls.length;

                    if (hasPhoto) {
                      final url = widget.data.photoUrls[index];

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              url,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: -6,
                            top: -6,
                            child: GestureDetector(
                              onTap: () => _removePhoto(index),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return InkWell(
                      onTap: _pickAndUploadImage,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFD0D5DD),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: _isUploading
                              ? const SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFFFF4458),
                                  ),
                                )
                              : const Icon(
                                  Icons.add,
                                  size: 34,
                                  color: Color(0xFFFF4458),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              Text(
                "${widget.data.photoUrls.length} / 6 bilder",
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF667085),
                  fontWeight: FontWeight.w700,
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    disabledBackgroundColor: const Color(0xFFE9ECEF),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: const Color(0xFF8E96A3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                  onPressed: canContinue
                      ? () {
                          print(widget.data.photoUrls);
                        }
                      : null,
                  child: const Text(
                    "Nästa",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}