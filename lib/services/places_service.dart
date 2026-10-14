import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/branch.dart';

class LatLng {
  const LatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  Map<String, double> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };
}

class PlacesException implements Exception {
  const PlacesException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef DrivingTime = ({int meters, int seconds});

/// Google Places API (New) text search and place details, and the Routes API
/// distance matrix.
class PlacesService {
  PlacesService({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const _searchUrl =
      'https://places.googleapis.com/v1/places:searchText';
  static const _matrixUrl =
      'https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix';
  static const _placeFields =
      'places.id,places.displayName,places.formattedAddress,places.location,'
      'places.googleMapsUri,places.photos,nextPageToken';
  static const _detailFields =
      'id,displayName,formattedAddress,location,googleMapsUri,photos';

  /// Runs every query, following up to three pages of results each, and
  /// returns the unique places whose name passes [keep].
  Future<List<Branch>> searchBranches({
    required List<String> queries,
    required bool Function(String name) keep,
  }) async {
    final found = <String, Branch>{};
    for (final query in queries) {
      String? pageToken;
      var pages = 0;
      do {
        final json =
            await _post(_searchUrl, _placeFields, {
                  'textQuery': query,
                  'pageSize': 20,
                  'languageCode': 'en',
                  'regionCode': 'GH',
                  'pageToken': ?pageToken,
                })
                as Map<String, dynamic>;
        for (final place in (json['places'] as List?) ?? const []) {
          final branch = Branch.fromPlace(place as Map<String, dynamic>);
          if (branch != null && keep(branch.name)) {
            found.putIfAbsent(branch.id, () => branch);
          }
        }
        pageToken = json['nextPageToken'] as String?;
        pages++;
      } while (pageToken != null && pages < 3);
    }
    return found.values.toList();
  }

  /// The listing with [placeId], or null when Google no longer has it.
  Future<Branch?> branchById(String placeId) async {
    final response = await _client.get(
      Uri.https('places.googleapis.com', '/v1/places/$placeId', {
        'languageCode': 'en',
        'regionCode': 'GH',
      }),
      headers: {'X-Goog-Api-Key': apiKey, 'X-Goog-FieldMask': _detailFields},
    );
    if (response.statusCode == 404) return null;
    return Branch.fromPlace(_decode(response) as Map<String, dynamic>);
  }

  /// Driving distance and time from [origin] to each branch, keyed by id.
  Future<Map<String, DrivingTime>> drivingTimes(
    LatLng origin,
    List<Branch> branches,
  ) async {
    if (branches.isEmpty) return const {};
    final json =
        await _post(
              _matrixUrl,
              'originIndex,destinationIndex,distanceMeters,duration,condition',
              {
                'origins': [
                  {
                    'waypoint': {
                      'location': {'latLng': origin.toJson()},
                    },
                  },
                ],
                'destinations': [
                  for (final branch in branches)
                    {
                      'waypoint': {
                        'location': {
                          'latLng': LatLng(
                            branch.latitude,
                            branch.longitude,
                          ).toJson(),
                        },
                      },
                    },
                ],
                'travelMode': 'DRIVE',
              },
            )
            as List;
    final times = <String, DrivingTime>{};
    for (final element in json.cast<Map<String, dynamic>>()) {
      if (element['condition'] != 'ROUTE_EXISTS') continue;
      // Proto3 JSON leaves out zero values, so a missing index means 0.
      final index = (element['destinationIndex'] as num?)?.toInt() ?? 0;
      final meters = (element['distanceMeters'] as num?)?.toInt() ?? 0;
      final seconds = int.tryParse(
        (element['duration'] as String? ?? '').replaceAll('s', ''),
      );
      if (index < branches.length && seconds != null) {
        times[branches[index].id] = (meters: meters, seconds: seconds);
      }
    }
    return times;
  }

  String photoUrl(String photoName, {int maxWidth = 300}) =>
      'https://places.googleapis.com/v1/$photoName/media'
      '?maxWidthPx=$maxWidth&key=$apiKey';

  Future<Object?> _post(
    String url,
    String fieldMask,
    Map<String, Object?> body,
  ) async {
    final response = await _client.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': fieldMask,
      },
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Object? _decode(http.Response response) {
    if (response.statusCode != 200) {
      var message = 'Google Maps request failed (${response.statusCode}).';
      try {
        final error = (jsonDecode(response.body) as Map)['error'] as Map;
        message = error['message'] as String? ?? message;
      } catch (_) {}
      throw PlacesException(message);
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}
