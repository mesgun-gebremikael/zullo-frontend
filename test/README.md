# Sessions- och kontobytestester

Kör `flutter test`. Testerna använder SharedPreferences-testlagring, kontrollerade HTTP-svar och riktig MatchesPage i widgettestet. Inga Firebase-nycklar eller externa tjänster behövs.

Kontrollerna omfattar att privat cache, oläststatus, aktuell chatt och väntande chattöppning töms vid sessionsbyte; att sena HTTP-svar och svarskroppar förkastas; att gamla tjänster inte kan använda nästa kontos token; att fördröjd utloggning inte raderar en ny inloggning; och att en notis kräver rätt mottagarkonto samt aktuell serverbehörighet.

Widgettestet ersätter projektets gamla counter-exempel som inte monterade någon app. Det monterar nu MatchesPage med kontrollerad HTTP-transport, visar konto A:s cache, byter session och kontrollerar att uppgifterna försvinner och inte återkommer för B.

Backend måste först uppdateras så att meddelandepush innehåller `recipientUserId`. Frontend avvisar avsiktligt notiser utan mottagaridentitet. Notiser som redan levererats till operativsystemet kan inte återkallas av dessa kontroller. Riktig FCM/SignalR-återanslutning och byte mellan konton ska även provas på telefon före lansering.

Säker tokenlagring, tokenförnyelse och inloggningsbegränsning ingår i separata steg; denna ändring behåller befintligt lagringsformat.
