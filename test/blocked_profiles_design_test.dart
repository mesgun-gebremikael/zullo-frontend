import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/blocked_profiles_page.dart';
import 'package:zullo_app/services/block_service.dart';

class _Blocks extends BlockService {
  final removed = <String>[];
  @override
  Future<List<Map<String, dynamic>>> getBlockedUsers() async => [
        {
          'userId': 'one',
          'displayName': 'A long profile display name',
          'age': 29,
          'photoUrl':
              'https://res.cloudinary.com/example/image/upload/photo.jpg'
        },
        {'userId': 'two', 'displayName': 'Profil', 'age': null, 'photoUrl': ''},
      ];
  @override
  Future<void> unblockUser(String userId) async => removed.add(userId);
}

void main() {
  testWidgets(
      'blocked cards show available identity without requiring hidden data and confirm removal',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _Blocks();
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
      child: BlockedProfilesPage(service: service),
    )));
    await tester.pumpAndSettle();
    expect(find.text('A long profile display name'), findsOneWidget);
    expect(find.text('29 år'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsWidgets);
    await tester.tap(find.text('Avblockera').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();
    expect(service.removed, isEmpty);
    await tester.tap(find.text('Avblockera').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Avblockera').last);
    await tester.pumpAndSettle();
    expect(service.removed, ['one']);
    expect(find.text('A long profile display name'), findsNothing);
    expect(find.text('Profil'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
