import '../l10n/localization.dart';
import '../models/profile_choices.dart';
import 'conversation_prompt_editor.dart';
import '../theme/zullo_palette.dart';
import 'package:flutter/material.dart';
import '../models/swipe_profile.dart';

/// Localize persisted choice codes without passing user-authored text through
/// the interface-label adapter. Older clients stored English enum aliases.
String localizedProfileChoice(
    BuildContext context, String field, String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '';
  const aliases = <String, Map<String, String>>{
    'workStatus': {'study': 'Pluggar just nu', 'work': 'Jobbar just nu'},
    'workout': {'Never': 'Aldrig', 'Sometimes': 'Ibland', 'Often': 'Ofta'},
    'smoking': {'No': 'Nej', 'Sometimes': 'Ibland', 'Yes': 'Ja'},
    'alcohol': {
      'Never': 'Aldrig',
      'No': 'Nej',
      'Sometimes': 'Ibland',
      'Often': 'Ofta',
      'Yes': 'Ja'
    },
    'cannabis': {
      'Never': 'Aldrig',
      'No': 'Nej',
      'Sometimes': 'Ibland',
      'Often': 'Ofta',
      'Yes': 'Ja'
    },
    'pets': {
      'Have': 'Har husdjur',
      'Want': 'Vill ha husdjur',
      'No': 'Vill inte ha husdjur',
      'Allergic': 'Allergisk mot husdjur'
    },
    'relationshipHistory': {
      'relationship': 'Varit i ett förhållande',
      'Relationship': 'Varit i ett förhållande',
      'casual': 'Inget seriöst',
      'Casual': 'Inget seriöst',
      'never': 'Aldrig haft ett förhållande',
      'Never': 'Aldrig haft ett förhållande'
    },
    'wantChildren': {
      'yes': 'Jag vill ha barn',
      'Yes': 'Jag vill ha barn',
      'maybe': 'Inte säker än',
      'Maybe': 'Inte säker än',
      'no': 'Jag vill inte ha barn',
      'No': 'Jag vill inte ha barn'
    },
    'childrenCount': {
      '0': 'Jag har inga barn',
      '1': '1 barn',
      '2': '2 barn',
      '3': '3 barn',
      '4+': '4 eller fler',
      '4 eller fler barn': '4 eller fler'
    },
    'religion': {
      'Christian': 'Kristendom',
      'Orthodox': 'Ortodox kristendom',
      'Catholic': 'Katolsk kristendom',
      'Jewish': 'Judendom',
      'Judisk': 'Judendom',
      'Islam': 'Islam',
      'Hindu': 'Hinduism',
      'Buddhist': 'Buddhism',
      'Sikh': 'Sikhism',
      'Atheist': 'Ateistisk',
      'Ateist': 'Ateistisk'
    },
  };
  if (field == 'religion' &&
      {'private', 'privat'}.contains(raw.toLowerCase())) {
    return '';
  }
  final alias = (aliases[field] ?? const <String, String>{})[raw];
  final label = field == 'intention'
      ? intentionOptions[raw] ?? raw
      : field == 'religion'
          ? religionOptions[raw] ?? alias ?? raw
          : alias ?? raw;
  return context.tr(label);
}

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
            Text(context.tr(title),
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
                            color: const Color(0xFFF2F4F7),
                            borderRadius: BorderRadius.circular(16)),
                        child: Text(text,
                            style: const TextStyle(
                                color: Color(0xFF424B59), height: 1.4))))
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
                border: Border.all(color: const Color(0xFFE8EBF0))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.format_quote_rounded, color: ZulloPalette.rose),
                SizedBox(width: 8),
                Text(context.l10n.aboutMe,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: ZulloPalette.ink))
              ]),
              const SizedBox(height: 12),
              SelectableText(p.bio.trim(),
                  style: const TextStyle(
                      fontSize: 17, height: 1.65, color: Color(0xFF424B59))),
            ])),
      ],
      if (conversationPrompts.containsKey(p.promptKey) &&
          p.promptAnswer.trim().isNotEmpty) ...[
        const SizedBox(height: 24),
        Text(context.tr(conversationPrompts[p.promptKey]!),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        SelectableText(p.promptAnswer.trim(),
            style: const TextStyle(fontSize: 17, height: 1.6)),
      ],
      if (p.outsideDistance || p.outsideAge)
        Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text(
                context.l10n.shownBecauseYouChoseToSearchALittleBeyondYour)),
      section('Jag söker',
          [localizedProfileChoice(context, 'intention', p.intention)]),
      section(context.l10n.theBasics, [
        localizedProfileChoice(context, 'workStatus', p.workStatus),
        if (p.livePlace.trim().isNotEmpty)
          '${context.l10n.currentCity} · ${p.livePlace}',
        if (p.originPlace.trim().isNotEmpty)
          context.l10n.fromValue0(p.originPlace),
        if (p.heightCm != null)
          context.l10n.heightCentimeters(p.heightCm.toString()),
        [p.jobTitle, p.workPlace].where((s) => s.trim().isNotEmpty).join(' · '),
        [p.studySubject, p.studyPlace]
            .where((s) => s.trim().isNotEmpty)
            .join(' · ')
      ]),
      section(context.l10n.myLifestyle, [
        localizedProfileChoice(context, 'religion', p.religion),
        if (p.workout.trim().isNotEmpty)
          context.l10n.exerciseValue0(
              localizedProfileChoice(context, 'workout', p.workout)),
        if (p.smoking.trim().isNotEmpty)
          context.l10n.smokingValue0(
              localizedProfileChoice(context, 'smoking', p.smoking)),
        localizedProfileChoice(context, 'pets', p.pets),
        if (p.alcohol.trim().isNotEmpty)
          '${context.l10n.alcohol}: ${localizedProfileChoice(context, 'alcohol', p.alcohol)}',
        if (p.cannabis.trim().isNotEmpty)
          '${context.tr('Cannabis')}: ${localizedProfileChoice(context, 'cannabis', p.cannabis)}',
        localizedProfileChoice(
            context, 'relationshipHistory', p.relationshipHistory),
        localizedProfileChoice(context, 'zodiacSign', p.zodiacSign),
        localizedProfileChoice(context, 'wantChildren', p.wantChildren),
        if (p.childrenCount.trim().isNotEmpty)
          '${context.l10n.children}: ${localizedProfileChoice(context, 'childrenCount', p.childrenCount)}'
      ]),
      // Interest strings currently have no canonical catalog or editing choices;
      // retain their original content, just like other free-form profile text.
      section(context.tr('Intressen'), p.interests),
    ]);
  }
}
