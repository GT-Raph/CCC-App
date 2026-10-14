/// A branch's YouTube live stream, as last seen by the `check-live-streams`
/// Supabase function.
class LiveStream {
  const LiveStream({
    required this.branchId,
    required this.status,
    this.videoId,
    this.title,
    this.scheduledStartAt,
    this.actualStartAt,
    this.checkedAt,
  });

  factory LiveStream.fromRow(Map<String, dynamic> row) {
    DateTime? time(String column) {
      final value = row[column] as String?;
      return value == null ? null : DateTime.parse(value).toLocal();
    }

    return LiveStream(
      branchId: row['branch_id'] as String,
      status: row['status'] as String? ?? 'offline',
      videoId: row['video_id'] as String?,
      title: row['title'] as String?,
      scheduledStartAt: time('scheduled_start_at'),
      actualStartAt: time('actual_start_at'),
      checkedAt: time('checked_at'),
    );
  }

  final String branchId;

  /// "live", "upcoming" or "offline".
  final String status;
  final String? videoId;

  /// The stream's YouTube title.
  final String? title;
  final DateTime? scheduledStartAt;
  final DateTime? actualStartAt;
  final DateTime? checkedAt;

  /// Live, and checked recently enough to trust. The checker looks at live
  /// streams every two minutes, so a much older reading means it stopped.
  bool isLiveAt(DateTime now) {
    final checked = checkedAt;
    return status == 'live' &&
        videoId != null &&
        checked != null &&
        now.difference(checked) < const Duration(minutes: 20);
  }

  String get watchUrl => 'https://www.youtube.com/watch?v=$videoId';
}
