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
