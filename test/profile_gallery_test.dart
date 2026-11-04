import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/widgets/profile_gallery.dart';

void main() {
  final image = MemoryImage(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='));
  for (final direction in TextDirection.values) {
    testWidgets('six photos support taps, swipes and buttons in $direction',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Directionality(
        textDirection: direction,
        child: Scaffold(
            body: ProfileGallery(
          photos: List.generate(6, (i) => 'photo-$i'),
          imageProvider: (_) => image,
        )),
      )));
      await tester.pumpAndSettle();
      expect(find.text('1 / 6'), findsOneWidget);
      final gallery = tester.getRect(find.byType(ProfileGallery));
      final forwardX = direction == TextDirection.ltr ? .75 : .25;
      await tester.tapAt(
          Offset(gallery.left + gallery.width * forwardX, gallery.top + 100));
      await tester.pumpAndSettle();
      expect(find.text('2 / 6'), findsOneWidget);
      await tester.drag(find.byType(PageView),
          Offset(direction == TextDirection.ltr ? -500 : 500, 0));
      await tester.pumpAndSettle();
      expect(find.text('3 / 6'), findsOneWidget);
      await tester.tap(find.byTooltip('Föregående bild'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 6'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byTooltip('Nästa bild'));
        await tester.pumpAndSettle();
      }
      expect(find.text('6 / 6'), findsOneWidget);
      expect(find.byTooltip('Nästa bild'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('an empty gallery stays usable without navigation controls',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ProfileGallery(photos: []))));
    expect(find.byType(PageView), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
