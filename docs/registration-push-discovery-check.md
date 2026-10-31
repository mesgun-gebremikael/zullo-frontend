# Kontroll efter ägarens merge och separata serveruppdatering

Ändringen kräver ingen ny databasmigration eller Render-inställning. Backend
behöver den nya versionen för att hantera samtidig registrering utan 500.
Frontend kan provas med befintlig backend; båda bör uppdateras före slutkontrollen.

- Skapa ett nytt testkonto på Android: en knapptryckning visar vänteläge och
  leder direkt till onboarding. Dubbeltryck ska inte skicka fler förfrågningar.
  Registreringssvarets JWT används direkt; lösenordet skickas inte en andra gång.
- Testa samma e-post igen: visa begripligt fel, aldrig logga in på det befintliga
  kontot utan att kontrollera lösenordet genom vanlig inloggning.
- Notisbehörighet måste vara tillåten i Android. Testa på en emulator med Google
  Play-tjänster och senare fysisk mobil. Testa ett helt nytt konto utan separat
  ut-/inloggning. På mottagaren: lämna själva konversationen, skicka från den
  andra användaren och kontrollera in-app-bannern. Lägg sedan mottagarappen i
  bakgrunden med hemknappen och kontrollera Android-notisen och öppning av rätt
  chatt. Appen undertrycker avsiktligt bannern för redan öppen konversation.
- Om FCM fortfarande inte levererar: kontrollera serverloggen för PUSH OK/FAIL
  och att Firebase Admin använder samma Firebase-projekt som mobilappen. Dela
  inga nyckelfiler, token eller lösenord. Automatiska tester simulerar FCM;
  de verifierar inte verklig leverans från Google eller Apple.
- Lämna Swipa synlig med tom lista; skapa en passande profil på andra mobilen.
  Den ska dyka upp vid nästa kontroll, inom cirka 20 sekunder plus nätverkstid.
  Bakgrund och andra flikar ska inte polla. Befintliga kort ska inte hoppa om.
- Redigera info: presentation och grunduppgifter ligger efter bilderna, före
  övriga profilval. Kontrollera förnamn, ålder, kön och presentation, spara och
  öppna igen. Befintlig egen könsbenämning ska bevaras. Testa liten skärm.

Render Free kan fortfarande behöva runt en minut för att vakna. Den här ändringen
visar väntan och begränsar auth-anrop till 90 sekunder; den tar inte bort plattformens
kallstart. Bilduppladdningens hastighet är inte ändrad eller verifierad här.
