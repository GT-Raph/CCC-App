/// A church ministry or fellowship that members can join.
class Ministry {
  const Ministry({
    required this.id,
    required this.name,
    required this.focus,
    required this.meets,
    required this.venue,
    required this.members,
    required this.about,
    this.images = const [],
    this.branchId,
  });

  /// A `ministries` row; [imageUrl] turns stored image paths into links.
  factory Ministry.fromRow(
    Map<String, dynamic> row, {
    required String Function(String path) imageUrl,
  }) {
    String text(String column) => ((row[column] as String?) ?? '').trim();
    return Ministry(
      id: row['id'] as String,
      branchId: row['branch_id'] as String?,
      name: text('name'),
      focus: text('focus'),
      meets: text('meets'),
      venue: text('venue'),
      members: text('members_label'),
      about: text('about'),
      images: [
        for (final path in (row['image_paths'] as List?) ?? const [])
          imageUrl(path as String),
      ],
    );
  }

  final String id;
  final String name;

  /// The ministry's branch; null for a church-wide ministry.
  final String? branchId;

  /// Who the ministry is for or what it does, e.g. "Women's fellowship".
  final String focus;

  /// When it meets, e.g. "Saturdays, 4:00 PM".
  final String meets;
  final String venue;

  /// Rounded member count as the church gives it, e.g. "50+"; may be empty.
  final String members;
  final String about;

  /// Photos for the card strip and details carousel. Ministries without
  /// photos show a text-only card.
  final List<String> images;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      name,
      focus,
      meets,
      venue,
    ].any((value) => value.toLowerCase().contains(q));
  }

  String get shareText => [
    if (focus.isEmpty) name else '$name, $focus',
    if (meets.isNotEmpty) meets,
    if (venue.isNotEmpty) venue,
  ].join('\n');
}
