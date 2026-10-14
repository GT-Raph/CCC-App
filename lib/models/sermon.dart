/// A recorded sermon from one branch, or for every branch.
class Sermon {
  const Sermon({
    required this.id,
    required this.branchId,
    required this.title,
    required this.preacher,
    required this.preachedOn,
    required this.audioUrl,
    this.description = '',
    this.duration,
  });

  /// Builds a sermon from a `sermons` row; [audioUrl] turns the stored file
  /// path into a link the player can stream.
  factory Sermon.fromRow(
    Map<String, dynamic> row, {
    required String Function(String path) audioUrl,
  }) {
    final seconds = row['duration_seconds'] as int?;
    return Sermon(
      id: row['id'] as String,
      branchId: row['branch_id'] as String?,
      title: (row['title'] as String).trim(),
      preacher: ((row['preacher'] as String?) ?? '').trim(),
      preachedOn: DateTime.parse(row['preached_on'] as String),
      description: ((row['description'] as String?) ?? '').trim(),
      audioUrl: audioUrl(row['audio_path'] as String),
      duration: seconds == null || seconds <= 0
          ? null
          : Duration(seconds: seconds),
    );
  }

  final String id;

  /// The branch whose members hear it; null when every branch does.
  final String? branchId;
  final String title;
  final String preacher;
  final DateTime preachedOn;
  final String description;
  final String audioUrl;

  /// Length as entered with the upload; the player's own reading wins once
  /// the audio has loaded.
  final Duration? duration;

  bool get forAllBranches => branchId == null;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      title,
      preacher,
      description,
      dateLabel,
    ].any((value) => value.toLowerCase().contains(q));
  }

  /// "12 Oct 2026".
  String get dateLabel =>
      '${preachedOn.day} ${_months[preachedOn.month - 1]} ${preachedOn.year}';

  String? get durationLabel {
    final duration = this.duration;
    return duration == null ? null : lengthLabel(duration);
  }

  String shareText(String branchName) => [
    title,
    if (preacher.isNotEmpty) preacher,
    '$branchName, $dateLabel',
    audioUrl,
  ].join('\n');

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}

/// "48 min", "1 h 5 min".
String lengthLabel(Duration duration) {
  final minutes = (duration.inSeconds / 60).round();
  if (minutes < 1) return '1 min';
  if (minutes < 60) return '$minutes min';
  final rest = minutes % 60;
  return rest == 0 ? '${minutes ~/ 60} h' : '${minutes ~/ 60} h $rest min';
}

/// Player clock: "4:05" or "1:02:09".
String clockLabel(Duration duration) {
  final seconds = duration.inSeconds % 60;
  final minutes = duration.inMinutes % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  return duration.inHours > 0
      ? '${duration.inHours}:${two(minutes)}:${two(seconds)}'
      : '${duration.inMinutes}:${two(seconds)}';
}
