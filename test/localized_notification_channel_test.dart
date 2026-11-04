import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/l10n/app_localizations.dart';
import 'package:zullo_app/l10n/app_localizations_en.dart';
import 'package:zullo_app/l10n/app_localizations_sv.dart';
import 'package:zullo_app/widgets/localized_notification_channel.dart';

void main() {
  testWidgets('channel labels update once per displayed locale',
      (tester) async {
    final changes = <(String, String)>[];
    Future<void> update(String name, String description) async {
      changes.add((name, description));
    }

    Widget app(String language) => MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => LocalizedNotificationChannel(
            onChange: update,
            child: child!,
          ),
          home: const Scaffold(body: Text('screen stays visible')),
        );

    await tester.pumpWidget(app('en'));
    await tester.pumpAndSettle();
    final en = AppLocalizationsEn();
    expect(changes, [(en.messages, en.chats)]);
    expect(find.text('screen stays visible'), findsOneWidget);

    // A fresh parent widget in the same locale is not another registration.
    await tester.pumpWidget(app('en'));
    await tester.pumpAndSettle();
    expect(changes, hasLength(1));

    await tester.pumpWidget(app('sv'));
    await tester.pumpAndSettle();
    final sv = AppLocalizationsSv();
    expect(changes, [(en.messages, en.chats), (sv.messages, sv.chats)]);
    expect(find.text('screen stays visible'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed native label update leaves rendering and locale usable',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => LocalizedNotificationChannel(
        onChange: (name, description) async {
          calls++;
          throw StateError('native channel unavailable');
        },
        child: child!,
      ),
      home: const Scaffold(body: Text('app remains available')),
    ));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('app remains available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending native update does not block the first frame',
      (tester) async {
    var called = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => LocalizedNotificationChannel(
        onChange: (name, description) {
          called = true;
          return Future<void>.delayed(const Duration(hours: 1));
        },
        child: child!,
      ),
      home: const Scaffold(body: Text('first frame')),
    ));
    expect(called, isTrue);
    expect(find.text('first frame'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Dispose the screen, then complete its fake native request so the test
    // leaves no pending timers. Production registration is platform-owned.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(hours: 1));
    expect(tester.takeException(), isNull);
  });
}
