import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/widgets/conversation_prompt_editor.dart';

void main() {
  testWidgets(
      'switching question preserves authored answer until explicit removal',
      (tester) async {
    var selected = 'small_joy';
    var answer = 'Tacos with my friends';
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: StatefulBuilder(
      builder: (context, setState) => ConversationPromptEditor(
        promptKey: selected,
        answer: answer,
        onChanged: (key, value) => setState(() {
          selected = key;
          answer = value;
        }),
      ),
    )))));
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Min perfekta lediga dag'));
    await tester.pumpAndSettle();
    expect(selected, 'weekend');
    expect(answer, 'Tacos with my friends');
    expect(find.text('Tacos with my friends'), findsOneWidget);
    await tester.tap(find.text('Ta bort samtalsfrågan'));
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(answer, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
