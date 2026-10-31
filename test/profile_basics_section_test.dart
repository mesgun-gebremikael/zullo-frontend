import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/widgets/profile_basics_section.dart';

void main() {
  testWidgets('compact layout preserves existing identity and edits presentation', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final name = TextEditingController(text: 'Anna');
    final age = TextEditingController(text: '29');
    final gender = TextEditingController(text: 'Egen benämning');
    final bio = TextEditingController(text: 'Musik och promenader');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(16), child:
        ProfileBasicsSection(name: name, age: age, gender: gender, bio: bio))))));
    expect(find.text('Namn (display)'), findsNothing);
    expect(find.text('Förnamn'), findsOneWidget);
    expect(find.text('Egen benämning'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'En ny presentation');
    expect(bio.text, 'En ny presentation');
    expect(name.text, 'Anna');
    expect(age.text, '29');
    expect(gender.text, 'Egen benämning');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    for (final controller in [name, age, gender, bio]) { controller.dispose(); }
  });
}
