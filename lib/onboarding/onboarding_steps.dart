enum OnboardingStep {
  name,
  birthDate,
  gender,
  interestedIn,
  intention,
  religion,
  work,
  location,
  distance,
  height,
  workout,
  pets,
  smoking,
  relationship,
  zodiac,
  children,
  wantChildren,
  bio,
  photos,
}

class OnboardingQuestion {
  final String title;
  final String? field;
  final Map<String, String> options;
  const OnboardingQuestion(this.title, {this.field, this.options = const {}});
}

const onboardingQuestions = <OnboardingStep, OnboardingQuestion>{
  OnboardingStep.name:
      OnboardingQuestion('Vad heter du i förnamn?', field: 'displayName'),
  OnboardingStep.birthDate: OnboardingQuestion('När föddes du?'),
  OnboardingStep.gender: OnboardingQuestion('Hur identifierar du dig?',
      field: 'gender', options: {'Man': 'Man', 'Kvinna': 'Kvinna'}),
  OnboardingStep.interestedIn: OnboardingQuestion('Vem vill du träffa?',
      field: 'interestedIn',
      options: {'Män': 'Män', 'Kvinnor': 'Kvinnor', 'Alla': 'Alla'}),
  OnboardingStep.intention:
      OnboardingQuestion('Vad söker du?', field: 'intention', options: {
    'Relationship': 'Seriöst förhållande',
    'Marriage': 'Giftermål',
    'Date': 'Dejta och se vart det leder',
    'Serious': 'Något seriöst',
    'NotSure': 'Jag vet inte än'
  }),
  OnboardingStep.religion:
      OnboardingQuestion('Vad är din religion?', field: 'religion', options: {
    'Private': 'Privat',
    'Kristen': 'Kristen',
    'Ortodox': 'Ortodox',
    'Muslim': 'Muslim',
    'Katolik': 'Katolik',
    'Ateist': 'Ateist',
    'Agnostiker': 'Agnostiker',
    'Annat': 'Annat'
  }),
  OnboardingStep.work: OnboardingQuestion('Vad jobbar du med?'),
  OnboardingStep.location: OnboardingQuestion('Var bor du?'),
  OnboardingStep.distance:
      OnboardingQuestion('Hur långt bort vill du träffa någon?'),
  OnboardingStep.height: OnboardingQuestion('Hur lång är du?'),
  OnboardingStep.workout: OnboardingQuestion('Tränar du?',
      field: 'workout',
      options: {'Aldrig': 'Aldrig', 'Ibland': 'Ibland', 'Ofta': 'Ofta'}),
  OnboardingStep.pets:
      OnboardingQuestion('Har du husdjur?', field: 'pets', options: {
    'Har husdjur': 'Har husdjur',
    'Vill ha husdjur': 'Vill ha husdjur',
    'Vill inte ha': 'Vill inte ha',
    'Allergisk': 'Allergisk'
  }),
  OnboardingStep.smoking: OnboardingQuestion('Använder du nikotin?',
      field: 'smoking',
      options: {'Nej': 'Nej', 'Ibland': 'Ibland', 'Ja': 'Ja'}),
  OnboardingStep.relationship: OnboardingQuestion('Har du varit i en relation?',
      field: 'relationshipHistory',
      options: {
        'Varit i ett förhållande': 'Varit i ett förhållande',
        'Inget seriöst': 'Inget seriöst',
        'Aldrig haft ett förhållande': 'Aldrig haft ett förhållande'
      }),
  OnboardingStep.zodiac: OnboardingQuestion('Vad är ditt stjärntecken?',
      field: 'zodiacSign',
      options: {
        'Vattuman': 'Vattuman',
        'Vädur': 'Vädur',
        'Kräfta': 'Kräfta',
        'Stenbock': 'Stenbock',
        'Tvilling': 'Tvilling',
        'Lejon': 'Lejon',
        'Våg': 'Våg',
        'Fisk': 'Fisk',
        'Skytt': 'Skytt',
        'Skorpion': 'Skorpion',
        'Oxe': 'Oxe',
        'Jungfru': 'Jungfru'
      }),
  OnboardingStep.children: OnboardingQuestion('Hur många barn har du?',
      field: 'childrenCount',
      options: {
        'Jag har inga barn': 'Jag har inga barn',
        '1 barn': '1 barn',
        '2 barn': '2 barn',
        '3 barn': '3 barn',
        '4 eller fler': '4 eller fler'
      }),
  OnboardingStep.wantChildren: OnboardingQuestion(
      'Vill du ha barn i framtiden?',
      field: 'wantChildren',
      options: {
        'Jag vill ha barn': 'Jag vill ha barn',
        'Inte säker än': 'Inte säker än',
        'Jag vill inte ha barn': 'Jag vill inte ha barn'
      }),
  OnboardingStep.bio:
      OnboardingQuestion('Berätta mer om dig själv', field: 'bio'),
  OnboardingStep.photos: OnboardingQuestion('Lägg till dina bilder'),
};
