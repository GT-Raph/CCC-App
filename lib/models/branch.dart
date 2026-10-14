class BranchPhoto {
  const BranchPhoto({required this.name, this.author});

  factory BranchPhoto.fromJson(Map<String, dynamic> json) => BranchPhoto(
    name: json['name'] as String,
    author: json['author'] as String?,
  );

  /// Google Places photo resource name ("places/…/photos/…").
  final String name;

  /// Photographer credit Google requires next to the photo.
  final String? author;

  Map<String, Object?> toJson() => {'name': name, 'author': author};
}

/// A church branch as listed on Google Maps.
class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.mapsUri,
    this.photos = const [],
    this.straightMeters,
    this.routeMeters,
    this.routeSeconds,
  });

  /// Builds a branch from a Places API (New) place, or null if it lacks the
  /// fields the app needs.
  static Branch? fromPlace(Map<String, dynamic> place) {
    final id = place['id'] as String?;
    final name = (place['displayName'] as Map?)?['text'] as String?;
    final location = place['location'] as Map?;
    if (id == null || name == null || location == null) return null;
    final photos = (place['photos'] as List?) ?? const [];
    return Branch(
      id: id,
      name: name.trim(),
      address: (place['formattedAddress'] as String?) ?? '',
      latitude: (location['latitude'] as num).toDouble(),
      longitude: (location['longitude'] as num).toDouble(),
      mapsUri:
          (place['googleMapsUri'] as String?) ??
          'https://www.google.com/maps/place/?q=place_id:$id',
      photos: [
        for (final photo in photos.take(4).cast<Map<String, dynamic>>())
          BranchPhoto(
            name: photo['name'] as String,
            author:
                ((photo['authorAttributions'] as List?)?.firstOrNull
                        as Map?)?['displayName']
                    as String?,
          ),
      ],
    );
  }

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    mapsUri: json['mapsUri'] as String,
    photos: [
      for (final photo in (json['photos'] as List).cast<Map<String, dynamic>>())
        BranchPhoto.fromJson(photo),
    ],
  );

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String mapsUri;
  final List<BranchPhoto> photos;

  /// As the crow flies from the member, when their location is known.
  final double? straightMeters;

  /// Driving distance and time from the member (nearest branches only).
  final int? routeMeters;
  final int? routeSeconds;

  /// "2.9 Km, 11 min" when a driving route is known, "12.4 Km away" when
  /// only the straight-line distance is.
  String? get distanceLabel {
    final meters = routeMeters ?? straightMeters;
    if (meters == null) return null;
    final km = '${(meters / 1000).toStringAsFixed(1)} Km';
    final seconds = routeSeconds;
    if (seconds == null) return '$km away';
    final minutes = (seconds / 60).round();
    final time = minutes < 60
        ? '$minutes min'
        : '${minutes ~/ 60} h ${minutes % 60} min';
    return '$km, $time';
  }

  /// The same listing under the name the church gives the branch.
  Branch withName(String name) => Branch(
    id: id,
    name: name,
    address: address,
    latitude: latitude,
    longitude: longitude,
    mapsUri: mapsUri,
    photos: photos,
    straightMeters: straightMeters,
    routeMeters: routeMeters,
    routeSeconds: routeSeconds,
  );

  Branch withDistance({double? straightMeters}) => Branch(
    id: id,
    name: name,
    address: address,
    latitude: latitude,
    longitude: longitude,
    mapsUri: mapsUri,
    photos: photos,
    straightMeters: straightMeters,
  );

  Branch withRoute({required int meters, required int seconds}) => Branch(
    id: id,
    name: name,
    address: address,
    latitude: latitude,
    longitude: longitude,
    mapsUri: mapsUri,
    photos: photos,
    straightMeters: straightMeters,
    routeMeters: meters,
    routeSeconds: seconds,
  );

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) || address.toLowerCase().contains(q);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'mapsUri': mapsUri,
    'photos': [for (final photo in photos) photo.toJson()],
  };
}
