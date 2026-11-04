class OnboardingData {
  String displayName = '';
  DateTime? birthDate;

  String gender = '';
  String interestedIn = '';

  List<String> photoUrls = [];

  String workStatus = '';
  String studyPlace = '';
  String studySubject = '';
  String workPlace = '';
  String jobTitle = '';
  String livePlace = '';
  String originPlace = '';

  String intention = '';
  int? heightCm;

  String workout = '';
  String pets = '';
  String smoking = '';

  String relationshipHistory = '';
  String zodiacSign = '';
  String religion = '';

  String childrenCount = '';
  String wantChildren = '';

  int distanceKm = 50;
  String bio = '';
  String promptKey = '', promptAnswer = '';
  void update(String field, Object? value) {
    switch (field) {
      case 'displayName':
        displayName = value as String;
      case 'gender':
        gender = value as String;
      case 'interestedIn':
        interestedIn = value as String;
      case 'workStatus':
        workStatus = value as String;
      case 'studyPlace':
        studyPlace = value as String;
      case 'studySubject':
        studySubject = value as String;
      case 'workPlace':
        workPlace = value as String;
      case 'jobTitle':
        jobTitle = value as String;
      case 'livePlace':
        livePlace = value as String;
      case 'originPlace':
        originPlace = value as String;
      case 'intention':
        intention = value as String;
      case 'workout':
        workout = value as String;
      case 'pets':
        pets = value as String;
      case 'smoking':
        smoking = value as String;
      case 'relationshipHistory':
        relationshipHistory = value as String;
      case 'zodiacSign':
        zodiacSign = value as String;
      case 'religion':
        religion = value as String;
      case 'childrenCount':
        childrenCount = value as String;
      case 'wantChildren':
        wantChildren = value as String;
      case 'promptAnswer':
        promptAnswer = value as String;
      case 'bio':
        bio = value as String;
      default:
        throw ArgumentError('Unknown onboarding field');
    }
  }

  Map<String, dynamic> toDraft() => {
        'displayName': displayName,
        'gender': gender,
        'interestedIn': interestedIn,
        'workStatus': workStatus,
        'studyPlace': studyPlace,
        'studySubject': studySubject,
        'workPlace': workPlace,
        'jobTitle': jobTitle,
        'livePlace': livePlace,
        'originPlace': originPlace,
        'intention': intention,
        'workout': workout,
        'pets': pets,
        'smoking': smoking,
        'relationshipHistory': relationshipHistory,
        'zodiacSign': zodiacSign,
        'religion': religion,
        'childrenCount': childrenCount,
        'wantChildren': wantChildren,
        'bio': bio,
        'promptKey': promptKey,
        'promptAnswer': promptAnswer,
        'birthDate': birthDate?.toIso8601String().split('T').first,
        'heightCm': heightCm,
        'distanceKm': distanceKm,
        'photoUrls': List<String>.from(photoUrls),
      };

  factory OnboardingData.fromDraft(Map<String, dynamic> draft) {
    final data = OnboardingData();
    data.displayName =
        draft['displayName'] is String ? draft['displayName'] as String : '';
    data.gender = draft['gender'] is String ? draft['gender'] as String : '';
    data.interestedIn =
        draft['interestedIn'] is String ? draft['interestedIn'] as String : '';
    data.workStatus =
        draft['workStatus'] is String ? draft['workStatus'] as String : '';
    data.studyPlace =
        draft['studyPlace'] is String ? draft['studyPlace'] as String : '';
    data.studySubject =
        draft['studySubject'] is String ? draft['studySubject'] as String : '';
    data.workPlace =
        draft['workPlace'] is String ? draft['workPlace'] as String : '';
    data.jobTitle =
        draft['jobTitle'] is String ? draft['jobTitle'] as String : '';
    data.livePlace =
        draft['livePlace'] is String ? draft['livePlace'] as String : '';
    data.originPlace =
        draft['originPlace'] is String ? draft['originPlace'] as String : '';
    data.intention =
        draft['intention'] is String ? draft['intention'] as String : '';
    data.workout = draft['workout'] is String ? draft['workout'] as String : '';
    data.pets = draft['pets'] is String ? draft['pets'] as String : '';
    data.smoking = draft['smoking'] is String ? draft['smoking'] as String : '';
    data.relationshipHistory = draft['relationshipHistory'] is String
        ? draft['relationshipHistory'] as String
        : '';
    data.zodiacSign =
        draft['zodiacSign'] is String ? draft['zodiacSign'] as String : '';
    data.religion =
        draft['religion'] is String ? draft['religion'] as String : '';
    data.childrenCount = draft['childrenCount'] is String
        ? draft['childrenCount'] as String
        : '';
    data.wantChildren =
        draft['wantChildren'] is String ? draft['wantChildren'] as String : '';
    data.bio = draft['bio'] is String ? draft['bio'] as String : '';
    data.promptKey =
        draft['promptKey'] is String ? draft['promptKey'] as String : '';
    data.promptAnswer =
        draft['promptAnswer'] is String ? draft['promptAnswer'] as String : '';
    data.birthDate = DateTime.tryParse(draft['birthDate']?.toString() ?? '');
    data.heightCm = draft['heightCm'] is int ? draft['heightCm'] as int : null;
    data.distanceKm = draft['distanceKm'] is int
        ? (draft['distanceKm'] as int).clamp(1, 300)
        : 50;
    data.photoUrls =
        (draft['photoUrls'] is List ? draft['photoUrls'] as List : [])
            .whereType<String>()
            .take(6)
            .toList();
    return data;
  }
  OnboardingData();
  Map<String, dynamic> toProfileUpdate({DateTime? today}) {
    final birth = birthDate;
    if (birth == null) {
      throw StateError('Födelsedatum saknas.');
    }
    final now = today ?? DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    if (age < 18 || age > 100) {
      throw StateError('Åldern måste vara mellan 18 och 100 år.');
    }
    return {
      'displayName': displayName,
      'age': age,
      'gender': gender,
      'interestedIn': interestedIn,
      'matchRadiusKm': distanceKm,
      'bio': bio,
      'promptKey': promptKey,
      'promptAnswer': promptAnswer,
      'photoUrls': List<String>.from(photoUrls),
      'interests': <String>[],
      'intention': intention,
      'religion': religion,
      'workout': workout,
      'smoking': smoking,
      'pets': pets,
      if (heightCm != null) 'heightCm': heightCm,
      'relationshipHistory': relationshipHistory,
      'zodiacSign': zodiacSign,
      'childrenCount': childrenCount,
      'wantChildren': wantChildren,
      'workStatus': workStatus,
      'studyPlace': studyPlace,
      'studySubject': studySubject,
      'workPlace': workPlace,
      'jobTitle': jobTitle,
      'livePlace': livePlace,
      'originPlace': originPlace,
    };
  }
}
