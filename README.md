# ZULLO – Frontend

ZULLO är en dejtingapplikation utvecklad med Flutter och Dart. Användare kan skapa profiler, upptäcka andra personer, matcha och chatta.

## Tekniker
- Flutter och Dart
- ASP.NET Core Web API som backend
- JWT för autentiserade API-anrop
- SignalR för realtidschatt
- Firebase Cloud Messaging för pushnotiser
- Cloudinary för profilbilder
- Shared Preferences för lokal lagring

## Funktioner
- Registrering och inloggning
- Stegvis profilskapande och uppladdning av bilder
- Redigering av profiluppgifter
- Swipe, likes och matchningar
- Realtidschatt och notiser
- Inställningar för bland annat ålder och avstånd

## Projektstruktur
- `lib/main.dart` – appens startpunkt
- `lib/main_navigation.dart` – huvudnavigation
- `lib/onboarding/` – introduktion och profilskapande
- `lib/services/` – apptjänster och API-anrop
- `lib/models/` – datamodeller
- `lib/widgets/` – återanvändbara komponenter
- `lib/swipe_page.dart` – swipe
- `lib/matches_page.dart` – matchningar
- `lib/chat_page.dart` – chatt
- `lib/config.dart` – appkonfiguration

## Starta lokalt
Du behöver Flutter SDK med Dart 3, en kompatibel emulator eller enhet samt en fungerande [ZULLO-backend](https://github.com/mesgun-gebremikael/zullo-backend).

1. Klona projektet.
2. Ange backendadressen med `--dart-define=ZULLO_API_URL=https://din-api-domän`. Releasebyggen kräver HTTPS. Standardadressen för utveckling är `http://10.0.2.2:5125`.
3. Konfigurera Firebase för den plattform du använder.
4. Kör:

```bash
flutter pub get
flutter run --dart-define=ZULLO_API_URL=http://10.0.2.2:5125
```

Observera att `localhost` i en emulator inte alltid pekar på utvecklingsdatorn.

## Testning
Projektet har en `test/`-mapp. Befintliga Flutter-tester kan köras med:

```bash
flutter test
```

GitHub-kontrollen kör tester och `python3 .ci/check_analysis.py`. Analyskontrollen nekar nya anmärkningar och alla analysfel; 128 befintliga anmärkningar är dokumenterade i `.ci/analysis_baseline.json`.

Se [chattens verifiering och införande](docs/chat-verification.md) för testresultat, beroendet till backendändringen och kvarvarande mobilprovning.

## Backend
[ZULLO – Backend API](https://github.com/mesgun-gebremikael/zullo-backend)

## Status
Appen körs i utvecklingsmiljö och är ännu inte publicerad i en appbutik.

**Utvecklare:** Mesgun Gebremikael
