/// One of the church's branches as the church lists them in Supabase. A
/// member belongs to one, and sermons are filed under one.
///
/// Not to be confused with `Branch`, a branch's Google Maps listing.
class ChurchBranch {
  const ChurchBranch({
    required this.id,
    required this.name,
    this.googlePlaceId,
  });

  factory ChurchBranch.fromJson(Map<String, dynamic> json) => ChurchBranch(
    id: json['id'] as String,
    name: (json['name'] as String).trim(),
    googlePlaceId: json['google_place_id'] as String?,
  );

  final String id;
  final String name;

  /// The branch's Google Maps listing, which the Church tab shows.
  final String? googlePlaceId;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'google_place_id': googlePlaceId,
  };

  bool matches(String query) =>
      name.toLowerCase().contains(query.trim().toLowerCase());

  @override
  bool operator ==(Object other) => other is ChurchBranch && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
