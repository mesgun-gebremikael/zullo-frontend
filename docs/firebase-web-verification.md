# Firebase-beroenden och gemensam verifiering

Det extra releasebygget av frontend-main `24eb5c1` misslyckades i `firebase_messaging_web 3.5.18`: PromiseJsImpl/handleThenable saknades med den låsta `firebase_core_web 2.24.0`.

Denna PR höjer lägsta Firebase Messaging-version till 14.9.4, inom befintlig huvudversion. Låsfilen löser Messaging-webb till 3.8.7 och Core-webb till 2.17.5. Dessa paket använder `web 0.5.1`; därför anpassas även den låsta bildcacheversionen från 3.4.1 till 3.4.0 och dess webbimplementation från 1.3.1 till 1.3.0. Inga egna bildvisnings- eller meddelandefunktioner ändras. Detta är en avgränsad kompatibilitetsrättning, inte en uppdatering till senaste Firebase-huvudversion.

Verifierat efter rättningen:

- `flutter pub get --enforce-lockfile`.
- 77/77 befintliga Fluttertester.
- `python3 .ci/check_analysis.py`: 128 äldre anmärkningar, inga nya och inga analysfel.
- `flutter build web --release --dart-define=ZULLO_API_URL=https://api.example.invalid`: godkänt. Adressen är avsiktligt en ogiltig testadress; bygget ska inte publiceras. Kompilatorn rapporterar kvarvarande Wasm-inkompatibilitet i andra webbberoenden; det godkända bygget är JavaScript.
- Gemensamt integrationstest med backend-PR:ns `verify-flutter-interop.sh`: riktiga Fluttertjänster mot lokal Kestrel, HTTP/SignalR och egen PostgreSQL-testdatabas klarade matchningslista, meddelande/livehändelse, omsändning, läskvitto, återanslutning, obehörig åtkomst och blockering.

GitHub-kontrollen kompletteras med webb-releasebygget så att detta kompileringsfel upptäcks i kommande PR:er. GitHub-jobben har dock inte kunnat starta på grund av kontots faktureringsspärr; de lokala resultaten är det verifierade underlaget.

## Kör gemensamt test

Med båda projekten lokalt, Flutter och .NET i PATH samt separat lokal PostgreSQL:

```sh
cd /path/to/zullo-backend
bash Zullo.Api.Tests/verify-flutter-interop.sh /path/to/zullo-frontend
```

Det explicita testet finns i `test/integration_backend_interop.dart` och körs inte automatiskt av `flutter test`. Testvärden skapar kortlivade testidentiteter och raderar sin egen testdatabas. Inga produktionshemligheter eller externa Firebase-leveranser behövs.

## Fortfarande manuellt/ej konfigurerat

Firebasealternativen i projektet finns endast för Android. Webb och iOS saknar Firebase-appkonfiguration och kan därför inte starta normalt med nuvarande `DefaultFirebaseOptions`. Denna PR rättar kompileringen och skapar ingen webb-/iOS-Firebase-app. Det kräver riktiga appregistreringar i rätt Firebaseprojekt. Riktig push måste provas på telefon i förgrund, bakgrund och stängd app samt vid kontobyte/blockering. Android/iOS-releasebygge och signering är inte verifierade här.

Ingen merge eller produktionsuppdatering ingår. Se backendens parade verifieringsrapport för migrations-/serverbehov: backend #7 måste vara införd och migrationen `20261027235933_ReliableMessageDelivery` finnas i den använda databasen. Den nya backend-PR:n tillför ingen ytterligare migration.
