# Sessions- och kontobytestester

Kör `flutter test`. Testerna använder SharedPreferences-testlagring, kontrollerade HTTP-svar och riktig MatchesPage i widgettestet. Inga Firebase-nycklar eller externa tjänster behövs.

Kontrollerna omfattar att privat cache, oläststatus, aktuell chatt och väntande chattöppning töms vid sessionsbyte; att sena HTTP-svar och svarskroppar förkastas; att gamla tjänster inte kan använda nästa kontos token; att fördröjd utloggning inte raderar en ny inloggning; och att en notis kräver rätt mottagarkonto samt aktuell serverbehörighet.

Widgettestet ersätter projektets gamla counter-exempel som inte monterade någon app. Det monterar nu MatchesPage med kontrollerad HTTP-transport, visar konto A:s cache, byter session och kontrollerar att uppgifterna försvinner och inte återkommer för B.

Backend måste först uppdateras så att meddelandepush innehåller `recipientUserId`. Frontend avvisar avsiktligt notiser utan mottagaridentitet. Notiser som redan levererats till operativsystemet kan inte återkallas av dessa kontroller. Riktig FCM/SignalR-återanslutning och byte mellan konton ska även provas på telefon före lansering.

Tokenförnyelse och serverstyrd återkallelse återstår som separata steg. Skyddad lagring och inloggningsbegränsning beskrivs nedan.

## Skyddad lagring och inloggningsbegränsning

AuthStorage använder nu flutter_secure_storage: Android EncryptedSharedPreferences med Keystore-skydd och iOS Keychain med `first_unlock_this_device`. Token och användar-ID lagras som ett gemensamt JSON-värde. Ingen databasändring krävs.

Vid första läsning migreras en komplett äldre identitet från SharedPreferences. Den skyddade skrivningen måste lyckas innan de gamla värdena tas bort. Partiella eller skadade identiteter behandlas som utloggade. Ett befintligt säkert värde har företräde framför kvarvarande äldre uppgifter. Fel vid läsning/skrivning i plattformslagret får inte ge återgång till okrypterad användning. Utloggning tömmer båda lagringsplatserna; andra appinställningar behålls.

Androids automatiska appbackup stängs av (`allowBackup=false`) för att undvika återställning av krypterade data utan tillhörande enhetsnyckel. Detta påverkar också automatisk backup av övrig lokal appdata. Redan skapade externa backuper kan inte raderas av denna uppdatering. Beteende vid ominstallation, låst enhet och överföring mellan telefoner måste verifieras på de mobila målplattformarna.

Lagringstesterna använder pluginets minnesdubbel och injicerade plattformsfel. De verifierar migrering, korrupta värden, utloggning under pågående migrering och att vanliga kontobyten fortfarande fungerar. Dessa tester verifierar inte Android Keystore/iOS Keychain på fysisk enhet.

Vid HTTP 429 visar klienten väntetiden från Retry-After (med säkert reservvärde). Inga automatiska login-retries görs. JWT-livslängd och serverstyrd återkallelse ändras inte i denna PR.

## Profilflöde och sparade preferenser

`profile_update_test.dart` täcker komplett onboardingpayload (inklusive födelsedagsgräns, svenska värden, urvalspreferens och avstånd), bevarande av utelämnade fält, explicit borttagning av längd, ett enda filter-PATCH, sent svar efter kontobyte och skillnaden mellan saknad profil (404), utgången session (401) och tillfälligt serverfel.

Widgettesterna monterar den riktiga onboardingfrågan och profilredigeringen: sparat Män/Kvinnor/Alla återställs och saknad längd blir inte automatiskt 170 cm. Startvyn erbjuder återförsök vid tillfälliga fel utan att radera inloggningen eller öppna onboarding. Inloggade användare utan profil får samma onboardingflöde som nya konton.

Backendens profiluppdatering och datamigrering måste driftsättas före den nya klienten. Radie och profilfilter sparas tillsammans. Ortstext är fortfarande inte en verifierad geografisk position; klienten skickar inte påhittade koordinater. Verklig geolokalisering och belastningstester återstår som separata steg före publik lansering.
