class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.church,
    required this.summary,
    required this.body,
    required this.images,
    this.branchId,
  });

  /// A `news` row; [imageUrl] turns stored image paths into links.
  factory NewsItem.fromRow(
    Map<String, dynamic> row, {
    required String Function(String path) imageUrl,
  }) {
    String text(String column) => ((row[column] as String?) ?? '').trim();
    final branch = (row['branches'] as Map?)?['name'] as String?;
    return NewsItem(
      id: row['id'] as String,
      title: text('title'),
      subtitle: text('subtitle'),
      church: branch?.trim() ?? churchName,
      branchId: row['branch_id'] as String?,
      summary: text('summary'),
      body: text('body'),
      images: [
        for (final path in (row['image_paths'] as List?) ?? const [])
          imageUrl(path as String),
      ],
    );
  }

  /// Shown on news for every branch.
  static const churchName = 'Calvary Charismatic Centre';

  final String id;
  final String title;
  final String subtitle;

  /// The branch the news is from, or the whole church.
  final String church;

  /// The branch it's for; null for church-wide news.
  final String? branchId;
  final String summary;
  final String body;

  /// Https links to the photos (may be empty).
  final List<String> images;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      title,
      subtitle,
      church,
      summary,
    ].any((value) => value.toLowerCase().contains(q));
  }

  String get shareText => [
    title,
    if (subtitle.isNotEmpty) subtitle,
    church,
    '',
    summary,
  ].join('\n');
}
