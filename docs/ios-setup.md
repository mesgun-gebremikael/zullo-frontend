# iPhone-stöd i Zullo

Samma Flutter-app används för Android och iPhone. Androids Firebase-inställningar och funktioner behålls. Denna ändring förbereder iOS-projektet och testar kompilering i GitHubs Mac-miljö. Den publicerar ingen app och skapar inga Apple-/Firebase-konton.

## Vad vi har kontrollerat om kontona

Projektet innehåller en Android-app i Firebase, men ingen registrerad iOS-appkonfiguration, inget Apple Development Team och ingen tillgänglig iOS-provisioneringsprofil. Det finns ingen ansluten Apple-/Firebase-kontotjänst eller inloggad Firebase-CLI i denna miljö. GitHub-integrationen får HTTP 403 när den försöker lista Actions-secrets och variables; därför går det inte heller att kontrollera om sådana uppgifter redan lagts där.

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
2. Välj ett permanent bundle-ID i Xcode och registrera samma ID hos Apple och i rätt Firebaseprojekt. Nuvarande `com.example.zulloApp` är en mall, inte ett verifierat registrerat publicerings-ID. Ändra alla Runner-byggkonfigurationer och motsvarande test-ID när det verkliga ID:t valts. Androids application-ID ska inte ändras.
3. Lägg till en Apple/iOS-app i det Firebaseprojekt som backendens Firebase-tjänstekonto använder. Hämta iOS-appens offentliga klientinställningar. Återanvänd inte Android-appens app-ID.
4. Kopiera `config/ios.firebase.example.json` till `config/ios.firebase.local.json` och ersätt alla platshållare. Filen innehåller endast klientkonfiguration och backendadress, aldrig signeringsnycklar eller tjänstekonto. Lokalfilen är git-ignorerad.
5. `ZULLO_IOS_FIREBASE_APP_ID` kommer från den registrerade iOS-appen (`1:…:ios:…`). SENDER_ID måste stämma med app-ID:t. BUNDLE_ID måste vara exakt samma som Xcodes PRODUCT_BUNDLE_IDENTIFIER och Apple-/Firebase-registreringen. PROJECT_ID/API_KEY ska komma från samma Firebaseprojekt. Ange verklig HTTPS-backend som ZULLO_API_URL.
6. Koden lämnar FirebaseOptions till native Firebase vid start. Denna lösning behöver därför inte lägga till GoogleService-Info.plist i Xcode för enbart Core/Messaging. Om FlutterFire CLI senare används ska dess genererade iOS-/Dart-konfiguration samordnas, så att två olika registreringar inte blandas. Google-inloggning är inte tillagd här.
7. Skapa eller återanvänd en APNs-autentiseringsnyckel hos Apple och ladda upp den i Firebase → Project settings → Cloud Messaging för rätt iOS-app. Lägg aldrig .p8-filen i Git. Välj rätt Apple-team och verifiera Push Notifications och Background Modes → Remote notifications i Xcode. Firebase AppDelegate-swizzling lämnas aktiverad.
8. Säkerställ att servern kör senaste backend och migrationen från chatt-PR #7. Denna iOS-ändring kräver ingen ny databasändring.

## Bygga på en Mac

```sh
flutter pub get --enforce-lockfile
flutter build ios --simulator --debug --no-codesign \
  --dart-define-from-file=config/ios.firebase.local.json
```

För fysisk iPhone: öppna `ios/Runner.xcworkspace`, välj rätt Apple-team, anslut mobilen, godkänn datorn och aktivera Developer Mode om iOS kräver det. Kör sedan med riktiga inställningar:

```sh
flutter devices
flutter run -d DIN_IPHONE_ENHETS_ID \
  --dart-define-from-file=config/ios.firebase.local.json
```

Din HP med Windows kan fortsätta användas för utveckling och Android. Den kan inte själv köra Xcode eller installera detta osignerade simulatorbygge på iPhone. En Mac/molnbyggtjänst med säker signering behövs för en installerbar iPhone-version. TestFlight är ett senare, separat publiceringssteg efter godkännande; en simulator-.app kan inte installeras på telefon.

## Automatiska kontroller

```sh
flutter test --reporter expanded
python3 .ci/check_analysis.py
python3 .ci/check_ios_setup.py
```

GitHub-jobbet `ios-build` kör `flutter build ios --simulator --debug --no-codesign` på macos-15. Det använder en avsiktligt ogiltig test-API-adress och ingen Firebase-/Apple-identitet, eftersom kompilering inte startar appen. Det testar inte lyckad Firebase-start, signering, APNs, TestFlight eller iPhone-användning. Inga signerade appar publiceras eller laddas upp.

## Manuellt på telefon före lansering

Prova registrering/inloggning, profilbilder (beviljat/nekat/avbrutet bildval), tangentbord, skärmkanter och både ljus/mörk vy. Prova matchning och chatt med två testkonton, nätavbrott, återanslutning och omsändning. Prova iPhone-push i förgrund, bakgrund och stängd app, tryck på notisen, nekad notisbehörighet samt kontobyte och blockering. Kontrollera även att Android fortfarande får notiser och kan välja bilder. Riktiga konto-/pushprov går inte att ersätta med ett kompileringsresultat.
