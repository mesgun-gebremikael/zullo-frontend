import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/l10n/app_localizations.dart';
import 'package:zullo_app/models/swipe_profile.dart';
import 'package:zullo_app/widgets/profile_basics_section.dart';
import 'package:zullo_app/widgets/profile_story.dart';
import 'package:zullo_app/widgets/swipe_profile_card.dart';

SwipeProfile profile() => SwipeProfile.fromJson({
      'userId': 'choice-localization',
      'displayName': 'Man',
      'age': 24,
      'intention': 'Friendship',
      'religion': 'Kristen',
      'workout': 'Often',
      'smoking': 'No',
      'pets': 'Have',
      'heightCm': 183,
      'relationshipHistory': 'Relationship',
      'zodiacSign': 'Vädur',
      'alcohol': 'Never',
      'cannabis': 'No',
      'childrenCount': '2',
      'wantChildren': 'Yes',
      'workStatus': 'work',
      'studyPlace': 'Nej',
      'studySubject': 'Ja',
      'jobTitle': 'Man',
      'workPlace': 'Kvinna',
      'livePlace': 'Aldrig',
      'originPlace': 'Ibland',
      'bio': 'Vänner',
      'promptKey': 'small_joy',
      'promptAnswer': 'Kristendom',
      'interests': ['Resor', 'Unlisted hobby'],
      'distanceKm': 12,
      'photoUrls': List.generate(5, (i) => 'photo-$i'),
    });

Widget localized(Locale locale, Widget child) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('profile choices translate in $locale; authored text stays raw',
        (tester) async {
      await tester
          .pumpWidget(localized(locale, ProfileStory(profile: profile())));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(ProfileStory));
      final strings = AppLocalizations.of(context);
      expect(find.text(strings.friends), findsOneWidget);
      expect(find.text(strings.christianity), findsOneWidget);
      expect(find.text(strings.currentlyWorking), findsOneWidget);
      expect(find.text(strings.exerciseValue0(strings.often)), findsOneWidget);
      expect(find.text(strings.smokingValue0(strings.no)), findsOneWidget);
      expect(find.text(strings.havePets), findsOneWidget);
      expect(find.text(strings.iWantChildren), findsOneWidget);
      expect(find.text(strings.aLittleThingThatMakesMyDay), findsOneWidget);
      expect(find.text('Vänner'), findsOneWidget);
      expect(find.text('Kristendom'), findsOneWidget);
      expect(find.text('Man · Kvinna'), findsOneWidget);
      expect(find.text('Ja · Nej'), findsOneWidget);
      expect(find.text('${strings.currentCity} · Aldrig'), findsOneWidget);
      expect(find.text(strings.fromValue0('Ibland')), findsOneWidget);
      expect(find.text('Resor'), findsOneWidget);
      expect(find.text('Unlisted hobby'), findsOneWidget);
      expect(Directionality.of(context),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      expect(tester.takeException(), isNull);
    });

    testWidgets('swipe choices and photo navigation follow $locale',
        (tester) async {
      final image = MemoryImage(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='));
      await tester.pumpWidget(localized(
          locale,
          SwipeProfileCard(
              profile: profile(),
              width: 360,
              height: 640,
              photoBarsTop: 16,
              imageProvider: (_) => image)));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(SwipeProfileCard));
      final strings = AppLocalizations.of(context);
      expect(find.text('Man'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('${strings.currentCity} · Aldrig'), findsOneWidget);
      expect(find.text(strings.value0Km('12')), findsOneWidget);
      final box = tester.getRect(find.byType(SwipeProfileCard));
      final forwardX = locale.languageCode == 'ar' ? .25 : .75;
      Future<void> nextPhoto() async {
        await tester
            .tapAt(Offset(box.left + box.width * forwardX, box.top + 230));
        await tester.pumpAndSettle();
      }

      await nextPhoto();
      expect(find.text(strings.christianity), findsOneWidget);
      await nextPhoto();
      expect(find.text(strings.often), findsOneWidget);
      expect(find.text(strings.havePets), findsOneWidget);
      await nextPhoto();
      expect(find.text('Nej • Ja'), findsOneWidget);
      expect(find.text('Man • Kvinna'), findsOneWidget);
      await nextPhoto();
      expect(find.text(strings.friends), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('custom gender value stays raw while known options translate',
      (tester) async {
    final name = TextEditingController(text: 'Man');
    final age = TextEditingController(text: '24');
    final gender = TextEditingController(text: 'Vänner');
    final bio = TextEditingController(text: 'Kristendom');
    addTearDown(() {
      name.dispose();
      age.dispose();
      gender.dispose();
      bio.dispose();
    });
    await tester.pumpWidget(localized(const Locale('en'),
        ProfileBasicsSection(name: name, age: age, gender: gender, bio: bio)));
    await tester.pumpAndSettle();
    expect(find.text('Vänner'), findsOneWidget);
    expect(find.text('Kristendom'), findsOneWidget);
    expect(gender.text, 'Vänner');
    expect(tester.takeException(), isNull);
  });
}
