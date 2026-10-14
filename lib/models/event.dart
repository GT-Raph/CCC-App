class Event {
  const Event({
    required this.id,
    required this.title,
    required this.church,
    required this.dateLabel,
    required this.host,
    required this.address,
    required this.description,
    required this.images,
    required this.phone,
    required this.email,
    required this.website,
    required this.contactAddress,
    this.branchId,
    this.forAllBranches = false,
    this.startsAt,
    this.endsAt,
    this.joinable = false,
  });

  /// An `events` row; [imageUrl] turns stored image paths into links.
  factory Event.fromRow(
    Map<String, dynamic> row, {
    required String Function(String path) imageUrl,
  }) {
    final startsAt = DateTime.parse(row['starts_at'] as String).toLocal();
    final endsAt = row['ends_at'] == null
        ? null
        : DateTime.parse(row['ends_at'] as String).toLocal();
    String text(String column) => ((row[column] as String?) ?? '').trim();
    return Event(
      id: row['id'] as String,
      title: text('title'),
      church: ((row['branches'] as Map?)?['name'] as String? ?? '').trim(),
      branchId: row['branch_id'] as String?,
      forAllBranches: row['for_all_branches'] as bool? ?? false,
      startsAt: startsAt,
      endsAt: endsAt,
      dateLabel: eventDateLabel(startsAt),
      host: text('host'),
      address: text('address'),
      description: text('description'),
      images: [
        for (final path in (row['image_paths'] as List?) ?? const [])
          imageUrl(path as String),
      ],
      phone: text('phone'),
      email: text('email'),
      website: text('website'),
      contactAddress: text('address'),
    );
  }

  final String id;
  final String title;

  /// The host branch's name.
  final String church;
  final String dateLabel;
  final String host;
  final String address;
  final String description;

  /// Photos published with the event.
  final List<String> images;
  final String phone;
  final String email;
  final String website;
  final String contactAddress;

  /// The branch holding the event; its YouTube channel carries the stream.
  final String? branchId;

  /// Shown to members of every branch, not just the host branch's.
  final bool forAllBranches;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// Joinable events show "Join Now"; the rest offer "Remind Me".
  final bool joinable;

  /// The host branch, noting when everyone is invited.
  String get churchLabel => forAllBranches && church.isNotEmpty
      ? '$church, for all branches'
      : church;

  /// Events without an end time are taken to last three hours.
  DateTime? get endsOrAssumed =>
      endsAt ?? startsAt?.add(const Duration(hours: 3));

  bool hasEndedAt(DateTime now) {
    final end = endsOrAssumed;
    return end != null && now.isAfter(end.add(const Duration(minutes: 30)));
  }

  /// From half an hour before the start until half an hour after the end,
  /// the time a branch's live stream is taken to be this event's.
  bool isOnAt(DateTime now) {
    final start = startsAt;
    final end = endsOrAssumed;
    if (start == null || end == null) return false;
    return !now.isBefore(start.subtract(const Duration(minutes: 30))) &&
        !hasEndedAt(now);
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      title,
      church,
      host,
      address,
    ].any((value) => value.toLowerCase().contains(q));
  }

  String get shareText => '$title\n$churchLabel\n$dateLabel\n$address';
}

/// "19th October 2026, 09:00 AM", as the design writes event dates.
String eventDateLabel(DateTime time) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final day = time.day;
  final suffix = (day % 100 >= 11 && day % 100 <= 13)
      ? 'th'
      : switch (day % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  String two(int value) => value.toString().padLeft(2, '0');
  return '$day$suffix ${months[time.month - 1]} ${time.year}, '
      '${two(hour)}:${two(time.minute)} ${time.hour < 12 ? 'AM' : 'PM'}';
}
