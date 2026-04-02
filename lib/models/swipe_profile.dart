class SwipeProfile {
  final String userId;
  final String displayName;
  final int age;
  final String countryCode;
  final String intention;
  final List<String> photoUrls;

  final String bio;
  final String religion;
  final String workout;
  final String smoking;
  final String pets;

    final int? heightCm;

  final String relationshipHistory;
  final String zodiacSign;

  final String alcohol;
  final String cannabis;

  final String childrenCount;
  final String wantChildren;

  final String workStatus;
  final String studyPlace;
  final String studySubject;
  final String workPlace;
  final String jobTitle;

  final String livePlace;
  final String originPlace;
  
  final List<String> interests;
  final double distanceKm;

  SwipeProfile({
    required this.userId,
    required this.displayName,
    required this.age,
    required this.countryCode,
    required this.intention,
    required this.photoUrls,
    required this.bio,
    required this.religion,
    required this.workout,
    required this.smoking,
    required this.pets,
        required this.heightCm,
    required this.relationshipHistory,
    required this.zodiacSign,
    required this.alcohol,
    required this.cannabis,
    required this.childrenCount,
    required this.wantChildren,
    required this.workStatus,
    required this.studyPlace,
    required this.studySubject,
    required this.workPlace,
    required this.jobTitle,
    required this.livePlace,
    required this.originPlace,
    required this.interests,
    required this.distanceKm,
  });

  factory SwipeProfile.fromJson(Map<String, dynamic> json) {
    final photos =
        (json['photoUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];

    final interests =
        (json['interests'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return SwipeProfile(
      userId: (json['userId'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      age: (json['age'] as num?)?.toInt() ?? 0,
      countryCode: (json['countryCode'] ?? '').toString(),
      intention: (json['intention'] ?? '').toString(),
      photoUrls: photos,
      bio: (json['bio'] ?? '').toString(),
      religion: (json['religion'] ?? '').toString(),
      workout: (json['workout'] ?? '').toString(),
      smoking: (json['smoking'] ?? '').toString(),
      pets: (json['pets'] ?? '').toString(),

            heightCm: (json['heightCm'] as num?)?.toInt(),
      relationshipHistory: (json['relationshipHistory'] ?? '').toString(),
      zodiacSign: (json['zodiacSign'] ?? '').toString(),
      alcohol: (json['alcohol'] ?? '').toString(),
      cannabis: (json['cannabis'] ?? '').toString(),
      childrenCount: (json['childrenCount'] ?? '').toString(),
      wantChildren: (json['wantChildren'] ?? '').toString(),
      workStatus: (json['workStatus'] ?? '').toString(),
      studyPlace: (json['studyPlace'] ?? '').toString(),
      studySubject: (json['studySubject'] ?? '').toString(),
      workPlace: (json['workPlace'] ?? '').toString(),
      jobTitle: (json['jobTitle'] ?? '').toString(),
      livePlace: (json['livePlace'] ?? '').toString(),
      originPlace: (json['originPlace'] ?? '').toString(),

      interests: interests,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
    );
  }
}


