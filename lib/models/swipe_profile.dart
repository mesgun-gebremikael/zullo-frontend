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
      interests: interests,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
    );
  }
}


