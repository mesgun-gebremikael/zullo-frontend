# ZULLO – bestående projektanteckningar

Uppdaterat 2026-11-26. Se också funktions- och lanseringsguiderna i docs/. Detta är sparade projektanteckningar, inte en schemalagd avisering.

## Uppskjutet av användaren
Resend/domän/SMTP skjuts upp uttryckligen. Påminn vid nästa arbete med registrering eller lanseringsförberedelser om: egen domän, Resend-konto, DNS-verifiering, API-nyckel som Render-hemlighet och verkligt inkorgstest. Ingen betaltjänst ska aktiveras. Guiden ligger i backend docs/RESEND_SETUP.md. Ny e-postregistrering är avsiktligt stängd med503 utan fungerande SMTP; befintlig login bevaras. Återinför aldrig obekräftade konton som genväg.

## Tidigare arbete
- Flutter-officiell lokalisering: 40 språk,544 kompletta UI-texter per språk, automatiskt/manuellt språkval, engelskt reservspråk och RTL. Modersmålsgranskning kvarstår.
- Profil-/chattgalleri, blockeringskort, modernare swipe/profil/navigation, religion och valfria samtalsfrågor. Upp till3 frågor med äldre svar bevarade. Hitta nya vänner.
- Automatisk GPS under användning/resume efter tillåtelse, ingen bakgrundsspårning; verklig radie-/åldersfallback med18+- och sekretessgränser.
- Verifierad mejlkod före nytt User/JWT, TLS-SMTP och begränsade försök/återförsök.
- Matchnotiskö, privat generisk meddelandepush och versionerad installationsägare vid kontobyten.
- Ett Premium med månad/år, separat Superlike/Boost-plånbok, verifierade serverrättigheter och kvittoskydd. Betalningar fortsatt avstängda. Okända avbrutna köp utan kvitto behöver auktoritativ återhämtning och butikstester före aktivering.
- GPS-kompatibilitetspatch och Java17-byggverktyg; varningar döljs inte.
- Senaste föregående kontroll:394 Fluttertester,311 servertester, ren Flutteranalys, PostgreSQL migration/konkurrens och servercontainer gröna. Slutlig Android/iOS-CI måste kontrolleras på rätt revision, tidigare resultat ska inte antas gälla nya ändringar.
- PR26 frontend (5aa569e) och PR22 backend (eb76ad8), ingen agentmerge eller produktion. Aktuell GitHubstatus behöver hämtas.

## Nytt uppdrag
Granska frontend och backend, förbättra konkret påvisade problem från A–Ö utan att förstöra befintligt. Fokus snabb mobilnavigation, lätta swipegester, snabba tydliga köpflöden och iOS/Android. Referensvideo: Instagram8.44sek,60fps, snabb flikväxling med bevarat innehåll och glidande markering. Emulatortest i debug kan inte bevisa fysisk telefons bildfrekvens.

## Tillstånd och lanseringsgränser
Tekniska beslut/fixar/tester och parallella agenter godkända. Ingen destruktiv databasändring, viktig dataradering, produktionspublicering eller betaltjänstaktivering utan separat godkännande. GPS, verkliga bilder/push, köp-/kvittosandbox, säker lagringsuppgradering, signering/APNs och språkgranskning måste verifieras före lansering.

## Dagens förbättringar av mobilflyt
Navigation behåller flikarnas innehåll och pausar dolda animationer; chattkvitton bygger inte om hemskärmen. Profil-/plånbokshämtningar samordnas och gamla kontosvar ignoreras. Swipe börjar animeras före nätverkssvar, förhindrar dubbeltryck och återställer vid fel/avbruten gest. Rewind, feed och swipe skyddas mot överlapp. Serverns feedfrågor har minskats från8 till3 och kvittohistorik hämtas i en batch med oförändrade ägar-/återbetalningsskydd. Köpknappen visar arbete direkt och kontot kontrolleras före butikens köpstart. Inga riktiga betalningar eller mejltjänster aktiverade. Se MOBILE_SMOOTHNESS_REVIEW.md (frontend) respektive MOBILE_PERFORMANCE_REVIEW.md (backend).

## Release-signering förberedd
Androids releasebygge får inte längre använda debugnyckeln. Ägarens nyckel kan anges via git-ignorerad android/key.properties eller ZULLO_ANDROID-signeringens miljövariabler. Saknade uppgifter stoppar releasebygget; vanlig emulatorstart fungerar utan dem. Se ANDROID_RELEASE_SIGNING.md. Ingen permanent nyckel har skapats åt ägaren, ingen appidentitet ändrad och ingen publicering/betalning aktiverad. Riktig ägarnyckel, butikskonfiguration och sandboxprov återstår.

## Sparade kvitton och återhämtning
Kända kvitton återhämtas via serververifiering efter autentiserad appstart/foreground samt i Premium. Ingen automatisk ny debitering eller native restore körs. Lokala slump-ID:n skyddar nya köpförsök mot gamla callbacks även vid identiska tidsstämplar; äldre poster bevaras. ID:t är inte betalningsbevis och löser inte kvittolösa avbrott. Se PURCHASE_RECOVERY.md. Backend har JWT-konfigurationsskydd och en isolerad riktig PostgreSQL-återställningskontroll, se respektive backendguide. Faktiska leverantörsbackuper, butikskoppling och telefon-/sandboxprov återstår.

## Aktiv sjuminutersgranskning 27 november 2026
Profilsparning tar nu en oföränderlig JSON-bild av det skickade formuläret före första väntan på autentiseringslagringen, så senare ändringar av bilder/intressen/svar inte ändrar anropet. Premium pausar Boost-timern i bakgrunden och slutar rita om efter utgången tid; aktiv nedräkning återupptas korrekt. Bildgalleriets byte från sista bild till kortare/tom lista och tillbaka är regressionstestat utan produktändring.
Lokalt: 446 apptester, 327 servertester, ren Flutter-analys och 40 kompletta språkkataloger. Backend stoppar nya lösenord över 72 UTF-8-byte för att undvika BCrypt-trunkering, med bevarad äldre inloggning. Lokaliserad klientförklaring av den nya maxgränsen återstår före lansering. Ingen ändrad hashmodell eller databas. Native-CI på denna revision inväntas, inte en del av sju minuters väntan. SMTP/domän är fortsatt pausat; betalningar/produktion aktiveras inte.
