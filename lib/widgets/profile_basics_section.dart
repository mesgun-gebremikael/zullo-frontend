import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The same controllers are used by save and preview; layout never discards data.
class ProfileBasicsSection extends StatelessWidget {
  final TextEditingController name;
  final TextEditingController age;
  final TextEditingController gender;
  final TextEditingController bio;

  const ProfileBasicsSection({
    super.key,
    required this.name,
    required this.age,
    required this.gender,
    required this.bio,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFED1460);
    final genders = {
      'Man',
      'Kvinna',
      'Icke-binär',
      if (gender.text.trim().isNotEmpty) gender.text.trim(),
    }.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Om mig',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ge en känsla av vem du är.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFECE7E9)),
          ),
          child: TextField(
            controller: bio,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Din presentation',
              hintText: 'Jag trivs bäst när…',
              alignLabelWithHint: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Grunduppgifter',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Det här visas på din profil.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFECE7E9)),
          ),
          child: Column(
            children: [
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Förnamn',
                  prefixIcon: Icon(Icons.person_outline, color: accent),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: age,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Ålder',
                  helperText: 'Du måste vara minst 18 år.',
                  prefixIcon: Icon(Icons.cake_outlined, color: accent),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue:
                    gender.text.trim().isEmpty ? null : gender.text.trim(),
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Kön',
                  prefixIcon: Icon(Icons.badge_outlined, color: accent),
                ),
                items: genders
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) gender.text = value;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
