import '../l10n/localization.dart';
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
        Text(
          context.l10n.aboutMe,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.yourBioAppearsOnYourFullProfileWithRoomTo,
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
            maxLength: 1000,
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) =>
                  newValue.text.length <= 1000 ? newValue : oldValue)
            ],
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: context.l10n.yourBio,
              hintText: context.l10n.iFeelHappiestWhen,
              alignLabelWithHint: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          context.l10n.theBasics,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.thisAppearsOnYourProfile,
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
                decoration: InputDecoration(
                  labelText: context.l10n.firstName,
                  prefixIcon: Icon(Icons.person_outline, color: accent),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: age,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: context.l10n.age,
                  helperText: context.l10n.youMustBeAtLeastYearsOld,
                  prefixIcon: Icon(Icons.cake_outlined, color: accent),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue:
                    gender.text.trim().isEmpty ? null : gender.text.trim(),
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.gender,
                  prefixIcon: Icon(Icons.badge_outlined, color: accent),
                ),
                items: genders
                    .map(
                      (value) => DropdownMenuItem(
                          value: value,
                          child: Text(const {'Man', 'Kvinna', 'Icke-binär'}
                                  .contains(value)
                              ? context.tr(value)
                              : value)),
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
