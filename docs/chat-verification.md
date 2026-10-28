# Chatt, återanslutning och tester

## Beteende

- Chatten hämtar de senaste 50 meddelandena. Knappen ”Visa äldre meddelanden” hämtar nästa sida. Efter återanslutning och när appen återgår från bakgrunden hämtas missade meddelanden och senaste läskvitto.
- Misslyckade sändningar kan skickas igen med samma leveransnyckel. Pågående, misslyckade och inkommande livemeddelanden behålls när ett äldre serversvar anländer. Ett bekräftat meddelande visas bara en gång.
- Läskvitton har en servergräns. Ett kvitto som kommer före HTTP-svaret gäller fortfarande för det meddelandet, men inte för ett senare skickat meddelande.
- Matchningsvyer delar pågående nätverksanrop. Täta ändringshändelser samlas, och tomma listor startar ingen fyrasekunderspollning. Flikarna skapas först när de öppnas.
- Befintliga minnescacher begränsas till 20 samtal med högst 200 meddelanden per cachepost. Den öppna chattens manuellt inlästa historik behålls i skärmen. Kontobyte tömmer användardata och stoppar gamla svar/livehändelser från att fylla nästa konto.

## Införande

Den parade backendändringen med `/messages/thread-page`, leveransnummer och migrationsnamnet `20261027235933_ReliableMessageDelivery` måste vara införd först. Den gamla backendversionen stöder inte denna frontendversion.

Ange den faktiska backendadressen när appen byggs:

```sh
flutter build apk --release --dart-define=ZULLO_API_URL=https://din-api-domän
```

Exempeldomänen ska ersättas. HTTPS krävs i release; konfiguration med lösenord, frågesträng eller fragment avvisas. Utvecklingsstandard är Android-emulatorns `http://10.0.2.2:5125`. Firebase och plattformarnas vanliga signering/inställningar behövs också. Ingen appbutikspublicering eller backenddriftsättning ingår i denna PR.

## Verifiering

```sh
flutter pub get --enforce-lockfile
flutter test --reporter expanded
python3 .ci/check_analysis.py
```

77 tester godkända i molnmiljön, inklusive 30 nya enhets- och skärmtester för denna ändring. Skärmtesterna öppnar riktiga `ChatPage`, `MainNavigation` och matchningsvyer med kontrollerad HTTP/live-transport. De provar stabil omsändningsnyckel, samtidiga svar, tidiga läskvitton, äldre historik, lat flikuppbyggnad och delade nätverksanrop. Övriga tester täcker bland annat kontobyte, återanslutningens tidsgräns, gamla anslutningsförsök, sidmarkörer, cachegränser och releasekonfiguration.

Statisk analys har inga fel men 128 äldre info-/varningsanmärkningar kvar (tidigare 146). `.ci/analysis_baseline.json` registrerar dessa utan radnummer. Kontrollskriptet och GitHub Actions nekar alla nya anmärkningar, fler förekomster och analysfel. Baslinjen är teknisk skuld och ska minskas, inte utökas för att kringgå kontroller.

Dessa tester använder inte riktiga telefoner eller produktions-Firebase. Android/iOS-bygge, push med appen stängd, långsam mobilanslutning, två fysiska enheter och verkligt bakgrundsläge måste fortfarande provas i staging före publik lansering. Backendens större PostgreSQL-/SignalR-lasttest beskrivs i dess parade PR.
