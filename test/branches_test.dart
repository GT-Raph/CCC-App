import 'dart:convert';

import 'package:ccc_app/data/church_branches.dart';
import 'package:ccc_app/models/branch.dart';
import 'package:ccc_app/models/church_branch.dart';
import 'package:ccc_app/screens/main_screen.dart';
import 'package:ccc_app/services/auth_service.dart';
import 'package:ccc_app/services/location_service.dart';
import 'package:ccc_app/services/places_service.dart';
import 'package:ccc_app/services/sermon_service.dart';
import 'package:ccc_app/state/branch_directory.dart';
import 'package:ccc_app/state/ccc_state.dart';
import 'package:ccc_app/theme/ccc_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> place(String id, String name, double lat, double lng) => {
  'id': id,
  'displayName': {'text': name, 'languageCode': 'en'},
  'formattedAddress': '$name, Accra, Ghana',
  'location': {'latitude': lat, 'longitude': lng},
  'googleMapsUri': 'https://maps.google.com/?cid=$id',
  'photos': [
    {
      'name': 'places/$id/photos/p1',
      'authorAttributions': [
        {'displayName': 'Ama Mensah'},
      ],
    },
  ],
};

final headquarters = place(
  'hq',
  'Calvary Charismatic Centre (Headquarters)',
  5.62,
  -0.20,
);
final botwe = place('botwe', 'CCC Botwe', 5.70, -0.15);
final otherChurch = place('other', 'Calvary Worship Centre - Ghana', 5.6, -0.1);

/// Fake Google APIs: every search returns the same three places, lookups by
/// id know the headquarters and Botwe, and the route matrix returns times
/// for the first two destinations.
MockClient fakeGoogle({
  List<String>? searches,
  List<String>? lookups,
}) => MockClient((request) async {
  if (request.method == 'GET') {
    final id = request.url.pathSegments.last;
    lookups?.add(id);
    expect(request.headers['X-Goog-Api-Key'], 'test-key');
    expect(request.headers['X-Goog-FieldMask'], contains('location'));
    final place = {'hq': headquarters, 'botwe': botwe}[id];
    return place == null
        ? http.Response('{"error": {"message": "Not found"}}', 404)
        : http.Response(jsonEncode(place), 200);
  }
  final body = jsonDecode(request.body) as Map<String, dynamic>;
  if (request.url.path.endsWith('places:searchText')) {
    searches?.add(body['textQuery'] as String);
    expect(request.headers['X-Goog-Api-Key'], 'test-key');
    expect(request.headers['X-Goog-FieldMask'], contains('places.location'));
    return http.Response(
      jsonEncode({
        'places': [headquarters, botwe, otherChurch],
      }),
      200,
    );
  }
  return http.Response(
    jsonEncode([
      // Proto3 JSON leaves out destinationIndex 0.
      {'distanceMeters': 2900, 'duration': '660s', 'condition': 'ROUTE_EXISTS'},
      {
        'destinationIndex': 1,
        'distanceMeters': 13000,
        'duration': '1800s',
        'condition': 'ROUTE_EXISTS',
      },
    ]),
    200,
  );
});

class FakeLocation extends LocationService {
  const FakeLocation(this.fix);

  final LocationFix fix;

  @override
  Future<LocationFix> current() async => fix;
}

class NoCache extends BranchCache {
  const NoCache();

  @override
  Future<List<Branch>?> read() async => null;

  @override
  Future<void> write(List<Branch> branches) async {}
}

const nearAccra = LocationFix(LocationAccess.granted, LatLng(5.60, -0.19));

Future<void> pumpChurchTab(WidgetTester tester, LocationFix fix) async {
  tester.view.physicalSize = const Size(430 * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final state = CccState(
    branches: BranchDirectory(
      places: PlacesService(apiKey: 'test-key', client: fakeGoogle()),
      location: FakeLocation(fix),
      cache: const NoCache(),
    ),
  );
  await tester.pumpWidget(
    CccScope(
      state: state,
      child: MaterialApp(
        theme: buildCccTheme(),
        home: const MainScreen(
          member: Member(firstName: 'Jessica', email: 'j@example.com'),
          initialTab: 2,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('branch filter keeps only Calvary Charismatic Centre listings', () {
    expect(isChurchBranch('Calvary Charismatic Centre (Headquarters)'), isTrue);
    expect(isChurchBranch('CCC Westland (Calvary Charismatic Center)'), isTrue);
    expect(isChurchBranch('CALVARY CHARISMATIC CENTRE(CCC) Afienya'), isTrue);
    expect(isChurchBranch('CCC Botwe'), isTrue);
    expect(isChurchBranch('Calvary Worship Centre - Ghana'), isFalse);
    expect(isChurchBranch('ICGC Calvary Temple Lashibi'), isFalse);
    expect(isChurchBranch('Ultimate Charismatic Centre - East Legon'), isFalse);
    expect(isChurchBranch('CCC Mount Zion Parish'), isFalse);
  });

  test('search runs every query and merges duplicate places', () async {
    final searches = <String>[];
    final places = PlacesService(
      apiKey: 'test-key',
      client: fakeGoogle(searches: searches),
    );

    final branches = await places.searchBranches(
      queries: branchSearchQueries,
      keep: isChurchBranch,
    );

    expect(searches, branchSearchQueries);
    expect(branches.map((b) => b.name), [
      'Calvary Charismatic Centre (Headquarters)',
      'CCC Botwe',
    ]);
    expect(branches.first.photos.single.author, 'Ama Mensah');
    expect(places.photoUrl('places/hq/photos/p1'), contains('key=test-key'));
  });

  test('driving times map back to branches', () async {
    final places = PlacesService(apiKey: 'test-key', client: fakeGoogle());
    final branches = [
      Branch.fromPlace(headquarters)!,
      Branch.fromPlace(botwe)!,
    ];

    final times = await places.drivingTimes(const LatLng(5.6, -0.19), branches);

    expect(times['hq'], (meters: 2900, seconds: 660));
    expect(times['botwe'], (meters: 13000, seconds: 1800));
    expect(
      branches.first.withRoute(meters: 2900, seconds: 660).distanceLabel,
      '2.9 Km, 11 min',
    );
  });

  test('the branch list follows the branches listed in Supabase', () async {
    final searches = <String>[];
    final lookups = <String>[];
    final directory = BranchDirectory(
      places: PlacesService(
        apiKey: 'test-key',
        client: fakeGoogle(searches: searches, lookups: lookups),
      ),
      listedBranches: () async => const [
        ChurchBranch(id: 'b1', name: 'CCC Headquarters', googlePlaceId: 'hq'),
        ChurchBranch(id: 'b2', name: 'CCC Botwe', googlePlaceId: 'botwe'),
        // Google no longer has this listing.
        ChurchBranch(id: 'b3', name: 'CCC Old Site', googlePlaceId: 'gone'),
        // No Google Maps listing yet.
        ChurchBranch(id: 'b4', name: 'CCC New Branch'),
      ],
      location: const FakeLocation(nearAccra),
      cache: const NoCache(),
    );

    await directory.ensureLoaded();

    expect(searches, isEmpty);
    expect(lookups, unorderedEquals(['hq', 'botwe', 'gone']));
    expect(directory.status, BranchStatus.ready);
    // The church's names, nearest first, with Google's details.
    expect(directory.branches.map((b) => b.name), [
      'CCC Headquarters',
      'CCC Botwe',
    ]);
    expect(directory.branches.first.address, contains('Accra'));
  });

  test('without the Supabase list it searches Google Maps instead', () async {
    final searches = <String>[];
    final directory = BranchDirectory(
      places: PlacesService(
        apiKey: 'test-key',
        client: fakeGoogle(searches: searches),
      ),
      listedBranches: () async => throw const ChurchDataException(
        'Branches are not set up yet.',
        setupMissing: true,
      ),
      location: const FakeLocation(nearAccra),
      cache: const NoCache(),
    );

    await directory.ensureLoaded();

    expect(searches, branchSearchQueries);
    expect(directory.branches, hasLength(2));
  });

  testWidgets('Church tab lists branches nearest first with travel times', (
    tester,
  ) async {
    await pumpChurchTab(tester, nearAccra);

    expect(find.text('Branches'), findsOneWidget);
    expect(find.text('Calvary Worship Centre - Ghana'), findsNothing);
    final hq = find.text('Calvary Charismatic Centre (Headquarters)');
    final ccBotwe = find.text('CCC Botwe');
    expect(hq, findsOneWidget);
    expect(ccBotwe, findsOneWidget);
    expect(tester.getTopLeft(hq).dy, lessThan(tester.getTopLeft(ccBotwe).dy));
    expect(find.text('2.9 Km, 11 min'), findsOneWidget);
    expect(find.text('13.0 Km, 30 min'), findsOneWidget);
    expect(
      find.text('Branch details and photos from Google Maps'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'botwe');
    await tester.pump();
    expect(hq, findsNothing);
    expect(ccBotwe, findsOneWidget);
  });

  testWidgets('without location the tab asks for it and hides distances', (
    tester,
  ) async {
    await pumpChurchTab(tester, const LocationFix(LocationAccess.denied));

    expect(
      find.text(
        'Share your location to see the nearest branches and travel times.',
      ),
      findsOneWidget,
    );
    expect(find.text('Allow'), findsOneWidget);
    expect(find.text('CCC Botwe'), findsOneWidget);
    expect(find.textContaining('Km'), findsNothing);
  });
}
