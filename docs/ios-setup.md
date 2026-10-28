# iPhone-stöd i Zullo

Samma Flutter-app används för Android och iPhone. Androids Firebase-inställningar och funktioner behålls. Denna ändring förbereder iOS-projektet och testar kompilering i GitHubs Mac-miljö. Den publicerar ingen app och skapar inga Apple-/Firebase-konton.

## Vad vi har kontrollerat om kontona

Projektet innehåller nu Android- och iOS-klientkonfiguration för samma Firebaseprojekt. iOS-värdena kommer från användarens uppladdade GoogleService-Info.plist. Inget Apple Development Team eller någon iOS-provisioneringsprofil finns tillgänglig. Det finns ingen ansluten Apple-/Firebase-kontotjänst eller inloggad Firebase-CLI i denna miljö. GitHub-integrationen får HTTP 403 när den försöker lista Actions-secrets och variables; därför går det inte heller att kontrollera om sådana uppgifter redan lagts där.

Det går inte att dra slutsatsen att du saknar ett Apple-konto eller medlemskap. Kontostatus måste kontrolleras inloggad på [Apple Developer](https://developer.apple.com/account) och i [Firebase Console](https://console.firebase.google.com/). Skicka aldrig lösenord, APNs-nycklar, Apple-certifikat eller tjänstekontonycklar i chatten eller en PR.

## Förberett i koden

- iOS 13 som lägsta version, CocoaPods Podfile och inkluderade Pods-inställningar i Debug/Release/Profile. Första Mac-bygget identifierade en äldre, icke-modulär Firebase-header i Messaging 14.x. En kompatibilitetsinställning för just den headerimporten används i Messaging-poden och Runner; SDK:ns huvudversion uppgraderas inte som en dold del av iOS-arbetet.
- Bildbibliotekets användningsbeskrivning för befintligt val av profilbilder. Ingen kamera-/mikrofonbehörighet begärs för funktioner som appen inte använder.
- Push-entitlement och remote-notification-bakgrundsläge. Debug använder APNs development och Release/Profile production; rätt signering/provisionering krävs fortfarande.
- Validerade iOS-Firebase-klientinställningar från byggkonfiguration, utan påhittade registreringsvärden. Saknade inställningar ger ett tydligt fel. Android fortsätter använda tidigare Firebase-app.
- APNs kontrolleras före FCM-token på iPhone. Utebliven token, nätfel eller långsam tokenhämtning stoppar inte inloggning. Token-refresh kan registrera senare; inloggning gör också ett nytt försök. Nekad notisbehörighet ska inte låsa resten av appen.
- Backendadressen måste anges för iPhone. Android-emulatorns `10.0.2.2` väljs inte automatiskt för iPhone. Release kräver HTTPS; ingen generell ATS-avstängning har lagts till.

## Före första riktiga iPhone-testet

1. Kontrollera om Apple Developer-medlemskap redan finns. Signerad installation behöver rätt Apple-team; TestFlight och vanlig pushkonfiguration kräver betalt medlemskap. Varken medlemskap eller avgiftsbelagda tjänster beställs av denna PR.
2. Välj ett permanent bundle-ID i Xcode och registrera samma ID hos Apple och i rätt Firebaseprojekt. Firebase-appen är nu registrerad som `com.mesgungebremikael.zullo`, och alla Runner-konfigurationer använder det ID:t. Registrering/tillgänglighet hos Apple är fortfarande inte verifierad. Androids application-ID ska inte ändras.
3. Klart för Firebase: användarens iOS-app är registrerad i samma projekt som Android. Den uppladdade filen har lästs in i klientkonfigurationen. Backendens tjänstekonto måste tillhöra samma projekt för pushleverans.
4. Använd `config/ios.firebase.json` för den registrerade iPhone-appen. Filen innehåller offentliga Firebase-klientinställningar, aldrig Apple-signering eller Firebase-tjänstekonto. Ange den riktiga backendadressen separat med `--dart-define=ZULLO_API_URL=...`. För ett annat Firebaseprojekt kan exempelkonfigurationen kopieras till den git-ignorerade `config/ios.firebase.local.json`.
5. `ZULLO_IOS_FIREBASE_APP_ID` kommer från den registrerade iOS-appen (`1:…:ios:…`). SENDER_ID måste stämma med app-ID:t. BUNDLE_ID måste vara exakt samma som Xcodes PRODUCT_BUNDLE_IDENTIFIER och Apple-/Firebase-registreringen. PROJECT_ID/API_KEY ska komma från samma Firebaseprojekt. Ange verklig HTTPS-backend som ZULLO_API_URL.
6. Koden lämnar FirebaseOptions till native Firebase vid start. Denna lösning behöver därför inte lägga till GoogleService-Info.plist i Xcode för enbart Core/Messaging. Om FlutterFire CLI senare används ska dess genererade iOS-/Dart-konfiguration samordnas, så att två olika registreringar inte blandas. Google-inloggning är inte tillagd här.
7. Skapa eller återanvänd en APNs-autentiseringsnyckel hos Apple och ladda upp den i Firebase → Project settings → Cloud Messaging för rätt iOS-app. Lägg aldrig .p8-filen i Git. Välj rätt Apple-team och verifiera Push Notifications och Background Modes → Remote notifications i Xcode. Firebase AppDelegate-swizzling lämnas aktiverad.
8. Säkerställ att servern kör senaste backend och migrationen från chatt-PR #7. Denna iOS-ändring kräver ingen ny databasändring.

## Bygga på en Mac

```sh
flutter pub get --enforce-lockfile
flutter build ios --simulator --debug --no-codesign \
  --dart-define-from-file=config/ios.firebase.json \
  --dart-define=ZULLO_API_URL=https://DIN-RIKTIGA-BACKEND
```

För fysisk iPhone: öppna `ios/Runner.xcworkspace`, välj rätt Apple-team, anslut mobilen, godkänn datorn och aktivera Developer Mode om iOS kräver det. Kör sedan med riktiga inställningar:

```sh
flutter devices
flutter run -d DIN_IPHONE_ENHETS_ID \
  --dart-define-from-file=config/ios.firebase.json \
  --dart-define=ZULLO_API_URL=https://DIN-RIKTIGA-BACKEND
```

Din HP med Windows kan fortsätta användas för utveckling och Android. Den kan inte själv köra Xcode eller installera detta osignerade simulatorbygge på iPhone. En Mac/molnbyggtjänst med säker signering behövs för en installerbar iPhone-version. TestFlight är ett senare, separat publiceringssteg efter godkännande; en simulator-.app kan inte installeras på telefon.

## Automatiska kontroller

```sh
flutter test --reporter expanded
python3 .ci/check_analysis.py
python3 .ci/check_ios_setup.py
```

GitHub-jobbet `ios-build` kör `flutter build ios --simulator --debug --no-codesign` på macos-15. Det använder en avsiktligt ogiltig test-API-adress och den registrerade offentliga Firebase-klientkonfigurationen, men inget Apple-team eller signeringsnycklar. Kompilering startar inte appen. Det testar inte lyckad Firebase-start, signering, APNs, TestFlight eller iPhone-användning. Inga signerade appar publiceras eller laddas upp.

## Manuellt på telefon före lansering

Prova registrering/inloggning, profilbilder (beviljat/nekat/avbrutet bildval), tangentbord, skärmkanter och både ljus/mörk vy. Prova matchning och chatt med två testkonton, nätavbrott, återanslutning och omsändning. Prova iPhone-push i förgrund, bakgrund och stängd app, tryck på notisen, nekad notisbehörighet samt kontobyte och blockering. Kontrollera även att Android fortfarande får notiser och kan välja bilder. Riktiga konto-/pushprov går inte att ersätta med ett kompileringsresultat.

## Verifierat i förberedelse-PR #6

- 96 Fluttertester godkända, inklusive 19 nya tester för iOS-inställningar, APNs-ordning/tidsgränser och Androidregression.
- Analyskontrollen godkänd med 124 äldre anmärkningar, inga nya och inga analysfel. Baslinjen har minskats från 128.
- Verkliga Flutter-tjänster mot befintlig lokal backend/PostgreSQL klarade integrationstestet för matchningslista, meddelande/livehändelse, omsändning, läskvitto, återanslutning, obehörig åtkomst och blockering.
- GitHub klarade tester, webb-releasebygge, paketeringskontroll och det osignerade iOS-simulatorbygget på macos-15 efter den avgränsade Firebase-headerkorrigeringen.
- `ios/Podfile.lock` är hämtad från just det godkända Mac-bygget och dess checksumma stämmer med Podfile. Den låser de verkligt använda nativebiblioteken (inklusive Firebase SDK 10.25.0). CI nekar om ett nytt bygge ändrar låsfilen. Vid avsiktlig beroendeuppdatering ska låsfilen förnyas och granskas tillsammans med nytt Mac-byggresultat.

Detta är bygg- och testverifiering. Ingen iOS-start med riktiga Firebase-värden, pushleverans till en iPhone, Apple-signering eller TestFlight-publicering har verifierats.

## Registreringen som användaren bifogade

Firebaseprojekt: `zullo-13dac`. iOS bundle-ID: `com.mesgungebremikael.zullo`. iOS App-ID: `1:860454038998:ios:6a9d009a2d4b822b7e4877`. Avsändar-ID och projekt stämmer med befintlig Android-app, men iOS har ett eget App-ID och klient-API-nyckel. Androids värden ändras inte.

Bara de fem nödvändiga offentliga klientvärdena har överförts till `config/ios.firebase.json`. Originalfilen behöver inte läggas till i Xcode eftersom appen skickar FirebaseOptions från Dart. Testerna och paketeringskontrollen kontrollerar att Xcodes bundle-ID matchar registreringen. APNs-nyckel, Apple-team, provisioneringsprofil och verklig backendadress saknas fortfarande; inga sådana uppgifter har hittats på. Registreringen i Firebase bevisar inte registrering eller medlemskap hos Apple.
