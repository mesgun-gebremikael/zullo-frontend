import '../theme/zullo_palette.dart';
import 'package:flutter/material.dart';
import '../models/swipe_profile.dart';

/// Full text lives below the photos, never in the photo overlay.
class ProfileStory extends StatelessWidget {
  final SwipeProfile profile;
  const ProfileStory({super.key, required this.profile});
  @override
  Widget build(BuildContext context) {
    final p = profile;
    Widget section(String title, List<String> values) {
      final items =
          values.map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
          padding: const EdgeInsets.only(top: 28),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ZulloPalette.ink)),
            const SizedBox(height: 12),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items
                    .map((text) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF5ECEF),
                            borderRadius: BorderRadius.circular(16)),
                        child: Text(text,
                            style: const TextStyle(
                                color: Color(0xFF594650), height: 1.4))))
                    .toList()),
          ]));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (p.bio.trim().isNotEmpty) ...[
        const SizedBox(height: 28),
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: ZulloPalette.canvas,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1E2E6))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.format_quote_rounded, color: ZulloPalette.rose),
                SizedBox(width: 8),
                Text('Om mig',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: ZulloPalette.ink))
              ]),
              const SizedBox(height: 12),
              SelectableText(p.bio.trim(),
                  style: const TextStyle(
                      fontSize: 17, height: 1.65, color: Color(0xFF514750))),
            ])),
      ],
      section('Jag söker', [p.intention]),
      section('Min vardag', [
        p.workStatus,
        if (p.livePlace.trim().isNotEmpty) 'Bor i ${p.livePlace}',
        if (p.originPlace.trim().isNotEmpty) 'Från ${p.originPlace}',
        if (p.heightCm != null) '${p.heightCm} cm',
        [p.jobTitle, p.workPlace].where((s) => s.trim().isNotEmpty).join(' · '),
        [p.studySubject, p.studyPlace]
            .where((s) => s.trim().isNotEmpty)
            .join(' · ')
      ]),
      section('Tro & livsstil', [
        if (!{'privat', 'private'}.contains(p.religion.trim().toLowerCase()))
          p.religion,
        if (p.workout.trim().isNotEmpty) 'Träning: ${p.workout}',
        if (p.smoking.trim().isNotEmpty) 'Rökning: ${p.smoking}',
        p.pets,
        if (p.alcohol.trim().isNotEmpty) 'Alkohol: ${p.alcohol}',
        if (p.cannabis.trim().isNotEmpty) 'Cannabis: ${p.cannabis}',
        p.relationshipHistory,
        p.zodiacSign,
        p.wantChildren,
        if (p.childrenCount.trim().isNotEmpty) 'Barn: ${p.childrenCount}'
      ]),
      section('Intressen', p.interests),
    ]);
  }
}
