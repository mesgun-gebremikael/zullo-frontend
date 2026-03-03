class SwipeProfile {
  final String userId;
  final String displayName;
  final int age;
  final String countryCode;
  final String intention;
  final List<String> photoUrls;

  SwipeProfile({
    required this.userId,
    required this.displayName,
    required this.age,
    required this.countryCode,
    required this.intention,
    required this.photoUrls,
  });

  factory SwipeProfile.fromJson(Map<String, dynamic> json) {
    final photos = (json['photoUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return SwipeProfile(
      userId: (json['userId'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      age: (json['age'] ?? 0) as int,
      countryCode: (json['countryCode'] ?? '').toString(),
      intention: (json['intention'] ?? '').toString(),
      photoUrls: photos,
    );
  }
}
