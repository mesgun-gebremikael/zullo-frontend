import 'package:flutter/material.dart';

class ProfilePhotoPreviewPage extends StatelessWidget {
  final Map<String, dynamic> profile;

  const ProfilePhotoPreviewPage({
    super.key,
    required this.profile,
  });

  List<String> _readPhotoUrls() {
    return ((profile["photoUrls"] as List?) ?? [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }

  List<String> _buildChips() {
    final chips = <String>[];

    final intention = (profile["intention"] ?? "").toString().trim();
    final religion = (profile["religion"] ?? "").toString().trim();
    final workout = (profile["workout"] ?? "").toString().trim();
    final smoking = (profile["smoking"] ?? "").toString().trim();
    final pets = (profile["pets"] ?? "").toString().trim();

    final interests = ((profile["interests"] as List?) ?? [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (intention.isNotEmpty) chips.add(intention);
    if (religion.isNotEmpty) chips.add(religion);
    if (workout.isNotEmpty) chips.add(workout);
    if (smoking.isNotEmpty) chips.add(smoking);
    if (pets.isNotEmpty) chips.add(pets);

    chips.addAll(interests);

    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final photos = _readPhotoUrls();

    final imageUrl = photos.isNotEmpty
        ? photos.first
        : "https://images.unsplash.com/photo-1524504388940-b1c1722653e1";

    final displayName = (profile["displayName"] ?? "").toString();
    final age = (profile["age"] ?? "").toString();
    final bio = (profile["bio"] ?? "").toString().trim();
    final chips = _buildChips();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Min profil",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    image: DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.08),
                          Colors.black.withOpacity(0.20),
                          Colors.black.withOpacity(0.82),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(
                              photos.isEmpty ? 1 : photos.length.clamp(1, 6),
                              (index) => Expanded(
                                child: Container(
                                  height: 4,
                                  margin: EdgeInsets.only(
                                    right: index ==
                                            (photos.isEmpty
                                                    ? 1
                                                    : photos.length.clamp(1, 6)) -
                                                1
                                        ? 0
                                        : 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: index == 0
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
                            age.isNotEmpty ? "$displayName $age" : displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (chips.isNotEmpty) ...[
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: chips.take(8).map((chip) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.10),
                                    ),
                                  ),
                                  child: Text(
                                    chip,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (bio.isNotEmpty)
                            Text(
                              bio,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}