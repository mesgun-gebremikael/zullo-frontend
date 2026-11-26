import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zullo_app/models/conversation_prompt.dart';
import 'package:zullo_app/models/swipe_profile.dart';
import 'package:zullo_app/onboarding/onboarding_data.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/widgets/conversation_prompt_editor.dart';
import 'package:zullo_app/widgets/profile_story.dart';

const saved = [
  ProfileConversationPrompt(key: 'small_joy', answer: 'قهوة مع أصدقائي ☕'),
  ProfileConversationPrompt(key: 'weekend', answer: '海辺を歩く'),
  ProfileConversationPrompt(key: 'ask_me', answer: 'Mina tomater 🍅'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'old draft upgrades to collection and three answers survive serialization',
      () {
    final old = OnboardingData.fromDraft(
        {'promptKey': 'ask_me', 'promptAnswer': 'Original answer'});
    expect(old.effectivePrompts.single.answer, 'Original answer');
    old.setConversationPrompts(saved);
    final roundtrip = OnboardingData.fromDraft(Map<String, dynamic>.from(
        jsonDecode(jsonEncode(old.toDraft())) as Map));
    expect(roundtrip.effectivePrompts.map((p) => p.toJson()).toList(),
        saved.map((p) => p.toJson()).toList());
    expect(roundtrip.promptKey, 'small_joy');
    expect(roundtrip.promptAnswer, saved.first.answer);
    roundtrip.update('promptAnswer', 'Updated first answer');
    expect(roundtrip.effectivePrompts.first.answer, 'Updated first answer');
    expect(roundtrip.effectivePrompts.last.answer, saved.last.answer);
    roundtrip.setConversationPrompts([]);
    expect(roundtrip.toDraft()['promptKey'], '');
    expect(roundtrip.toDraft()['conversationPrompts'], isEmpty);
  });
  test('explicit empty collection does not resurrect obsolete legacy fields',
      () {
    final json = {
      'conversationPrompts': <dynamic>[],
      'promptKey': 'weekend',
      'promptAnswer': 'Obsolete answer'
    };
    expect(ProfileConversationPrompt.read(json), isEmpty);
    expect(OnboardingData.fromDraft(json).effectivePrompts, isEmpty);
    expect(SwipeProfile.fromJson(json).effectivePrompts, isEmpty);
    expect(
        SwipeProfile.fromJson(
                {'promptKey': 'weekend', 'promptAnswer': 'Legacy answer'})
            .effectivePrompts
            .single
            .answer,
        'Legacy answer');
  });
  test(
      'profile save transmits all answers and projects the first for old clients',
      () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthStorage().clearAuth();
    await AuthStorage().saveAuth(token: 'token', userId: 'owner');
    Map<String, dynamic>? body;
    final auth = AuthService(client: MockClient((request) async {
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{}', 200);
    }));
    await auth.saveProfile(
        displayName: 'Person',
        age: 24,
        gender: 'Man',
        bio: 'Bio',
        photoUrls: ['a', 'b'],
        interests: [],
        intention: 'Friendship',
        religion: '',
        workout: '',
        smoking: '',
        pets: '',
        promptKey: saved.first.key,
        promptAnswer: saved.first.answer,
        conversationPrompts: saved.map((p) => p.toJson()).toList());
    expect(body!['conversationPrompts'], saved.map((p) => p.toJson()).toList());
    expect(body!['promptKey'], saved.first.key);
    expect(body!['promptAnswer'], saved.first.answer);
  });
  testWidgets(
      'three prompt editor excludes duplicates and removing one preserves other answers',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var values = saved.toList();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: StatefulBuilder(
                    builder: (context, setState) => ConversationPromptsEditor(
                        prompts: values,
                        onChanged: (next) =>
                            setState(() => values = next)))))));
    await tester.pumpAndSettle();
    expect(find.byType(OutlinedButton), findsNWidgets(3));
    expect(find.text('3 / 3'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pumpAndSettle();
    final sheet = find.byType(DraggableScrollableSheet);
    expect(
        find.descendant(
            of: sheet, matching: find.text('Min perfekta lediga dag')),
        findsNothing);
    expect(
        find.descendant(of: sheet, matching: find.text('Fråga mig gärna om')),
        findsNothing);
    final nextQuestion = find.descendant(
        of: sheet, matching: find.text('En oväntad talang jag har'));
    await Scrollable.ensureVisible(tester.element(nextQuestion), alignment: .3);
    await tester.pumpAndSettle();
    await tester.tap(nextQuestion);
    await tester.pumpAndSettle();
    expect(values.first.key, 'unexpected_skill');
    expect(values.first.answer, saved.first.answer);
    await tester.ensureVisible(find.text('Ta bort samtalsfrågan').first);
    await tester.tap(find.text('Ta bort samtalsfrågan').first);
    await tester.pumpAndSettle();
    expect(values.length, 2);
    expect(values.first.answer, saved[1].answer);
    expect(values.last.answer, saved[2].answer);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.byType(OutlinedButton),
        findsNWidgets(3)); // Two existing, one add.
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'full profile displays each question and unchanged authored answer',
      (tester) async {
    final profile = SwipeProfile.fromJson(
        {'conversationPrompts': saved.map((p) => p.toJson()).toList()});
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body:
                SingleChildScrollView(child: ProfileStory(profile: profile)))));
    for (final prompt in saved) {
      await tester.ensureVisible(find.text(prompt.answer));
      expect(find.text(prompt.answer), findsOneWidget);
    }
    expect(find.byType(SelectableText), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
