class ReceivedLikesSummary {
  final int totalCount, hiddenCount;
  final bool canViewAll;
  const ReceivedLikesSummary(
      {required this.totalCount,
      required this.hiddenCount,
      required this.canViewAll});
  factory ReceivedLikesSummary.fromJson(Map<String, dynamic> json) =>
      ReceivedLikesSummary(
        totalCount: (json['totalCount'] as num).toInt(),
        hiddenCount: (json['hiddenCount'] as num).toInt(),
        canViewAll: json['canViewAll'] == true,
      );
}
