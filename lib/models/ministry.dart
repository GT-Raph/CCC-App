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
    this.addsMembers = false,
    this.needsApproval = false,
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
      addsMembers: row['auto_assign'] as bool? ?? false,
      needsApproval: row['needs_approval'] as bool? ?? false,
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

  /// Members who qualify are added automatically; one who leaves isn't
  /// added again.
  final bool addsMembers;

  /// Members ask to join, and one of its leaders approves them.
  final bool needsApproval;

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

/// Where the signed-in member stands with a ministry.
enum MinistryStanding {
  out,

  /// Asked to join a ministry that approves its members; not answered yet.
  asked,

  /// Their last request wasn't approved. They can ask again.
  declined,
  joined,
}

/// A member's request to join a ministry, as they see it.
enum RequestState { pending, declined }

/// What tapping Join, Ask to join, Joined or Requested did.
enum MembershipChange { joined, left, asked, withdrew }
