import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/l10n/app_localizations.dart';
import 'package:zullo_app/edit_profile_page.dart';
import 'package:zullo_app/l10n/app_localizations_ar.dart';
import 'package:zullo_app/l10n/app_localizations_en.dart';
import 'package:zullo_app/onboarding/onboarding_data.dart';
import 'package:zullo_app/onboarding/onboarding_steps.dart';
import 'package:zullo_app/onboarding/onboarding_wizard.dart';
import 'package:zullo_app/profile_settings_page.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/widgets/discovery_settings_sheet.dart';

class _AccountAuth extends AuthService {
  @override
  Future<Map<String, dynamic>> getMyAccount() async =>
      {'email': 'Friends@example.test'};

  @override
  Future<Map<String, dynamic>> getMyProfile() async => {
        'displayName': 'Profile',
        'age': 24,
        'gender': 'Kvinna',
        'bio': 'Alla',
        'livePlace': 'Alla',
        'photoUrls': <String>[],
        'intention': 'Friendship',
        'religion': 'Muslim',
      };
}

Widget _localized(Locale locale, Widget child) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  for (final code in ['en', 'ar']) {
    final strings = code == 'ar'
        ? AppLocalizationsAr()
        : AppLocalizationsEn() as AppLocalizations;
    final locale = Locale(code);

    testWidgets('$code onboarding localizes choices but saves canonical IDs',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = OnboardingData();
      await tester.pumpWidget(_localized(locale,
          OnboardingWizard(data: data, initialStep: OnboardingStep.intention)));
      await tester.pumpAndSettle();
      expect(find.text(strings.whatAreYouLookingFor), findsOneWidget);
      expect(find.text('Vad söker du?'), findsNothing);
      expect(Directionality.of(tester.element(find.byType(OnboardingWizard))),
          code == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      await tester.tap(find.text(strings.friends));
      await tester.pumpAndSettle();
      expect(data.intention, 'Friendship');
      await tester.tap(find.text(strings.next));
      await tester.pumpAndSettle();
      expect(data.intention, 'Friendship');
      expect(tester.takeException(), isNull);
    });

    testWidgets('$code onboarding translates labels and keeps raw city text',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // This city intentionally equals a canonical Swedish choice label.
      // It must remain user-authored text rather than becoming "Everyone".
      final data = OnboardingData()..livePlace = 'Alla';
      await tester.pumpWidget(_localized(locale,
          OnboardingWizard(data: data, initialStep: OnboardingStep.location)));
      await tester.pumpAndSettle();
      expect(find.text(strings.whereDoYouLive), findsWidgets);
      expect(find.text('Alla'), findsOneWidget);
      final field = tester.widget<TextFormField>(
          find.byKey(const ValueKey('onboarding-livePlace')));
      expect(field.initialValue, 'Alla');
      expect(data.livePlace, 'Alla');
      expect(tester.takeException(), isNull);
    });

    testWidgets('$code account rows localize and leave account email unchanged',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
          _localized(locale, ProfileSettingsPage(authService: _AccountAuth())));
      await tester.pumpAndSettle();
      expect(find.text(strings.accountSettings), findsOneWidget);
      expect(find.text(strings.locationDiscovery), findsOneWidget);
      expect(find.text(strings.activityStatus), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Friends@example.test'), 180);
      expect(find.text('Friends@example.test'), findsOneWidget);
      expect(find.text('E-post'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '$code editor localizes helper headings without translating input',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
          _localized(locale, EditProfilePage(authService: _AccountAuth())));
      await tester.pumpAndSettle();
      expect(find.text(strings.whatDoYouDoForWork), findsOneWidget);
      expect(find.text(strings.whoAreYouInterestedIn), findsOneWidget);
      expect(find.text(strings.doYouExercise), findsOneWidget);
      expect(find.text(strings.faithAndBeliefs), findsOneWidget);
      expect(find.text(strings.friends), findsOneWidget);
      expect(find.text('Tränar du?'), findsNothing);
      final inputs = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.controller?.text)
          .toList();
      expect(inputs.where((text) => text == 'Alla'), hasLength(2));
      expect(inputs, contains('Profile'));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '$code discovery choices display translated values and save IDs',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      DiscoveryPreferences? saved;
      await tester.pumpWidget(
          _localized(locale, Scaffold(body: Builder(builder: (context) {
        return FilledButton(
            onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => DiscoverySettingsSheet(
                    initial: const DiscoveryPreferences(
                        interestedIn: 'Kvinnor',
                        radiusKm: 50,
                        minAge: 18,
                        maxAge: 40),
                    onSave: (value) async => saved = value)),
            child: const Text('open'));
      }))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(strings.women), findsOneWidget);
      expect(find.text('Kvinnor'), findsNothing);
      await tester.tap(find.text(strings.women));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.everyone));
      await tester.pumpAndSettle();
      expect(find.text(strings.everyone), findsOneWidget);
      await tester.scrollUntilVisible(find.text(strings.saveSettings), 200);
      await tester.tap(find.text(strings.saveSettings));
      await tester.pumpAndSettle();
      expect(saved?.interestedIn, 'Alla');
      expect(saved?.radiusKm, 50);
      expect(tester.takeException(), isNull);
    });
  }
}
