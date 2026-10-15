// Fake data sources and test records for the widget tests. The app itself
// ships no sample content; everything it shows comes from Supabase.
import 'dart:async';

import 'package:ccc_app/models/admin_drafts.dart';
import 'package:ccc_app/models/church_branch.dart';
import 'package:ccc_app/models/event.dart';
import 'package:ccc_app/models/live_stream.dart';
import 'package:ccc_app/models/ministry.dart';
import 'package:ccc_app/models/news.dart';
import 'package:ccc_app/models/sermon.dart';
import 'package:ccc_app/services/admin_service.dart';
import 'package:ccc_app/services/auth_service.dart';
import 'package:ccc_app/services/content_service.dart';
import 'package:ccc_app/services/event_service.dart';
import 'package:ccc_app/services/sermon_service.dart';
import 'package:ccc_app/state/ccc_state.dart';
import 'package:ccc_app/state/event_reminders.dart';
import 'package:ccc_app/state/sermon_library.dart';
import 'package:ccc_app/state/sermon_player.dart';
import 'package:ccc_app/theme/ccc_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Branches and members -------------------------------------------------------

const botwe = ChurchBranch(id: 'b-botwe', name: 'CCC Botwe');
const westland = ChurchBranch(id: 'b-westland', name: 'CCC Westland');

/// A member of CCC Botwe.
const ama = Member(firstName: 'Ama', email: 'ama@example.com', branch: botwe);

/// A member who hasn't chosen a branch yet.
const jessica = Member(firstName: 'Jessica', email: 'jessica@example.com');

final now = DateTime.now();

// Sermons --------------------------------------------------------------------

Sermon sermon(
  String id,
  String? branchId,
  String title,
  DateTime day, {
  String preacher = 'Rev. Kofi Mensah',
  int minutes = 48,
}) => Sermon(
  id: id,
  branchId: branchId,
  title: title,
  preacher: preacher,
  preachedOn: day,
  audioUrl: 'https://example.com/$id.mp3',
  description: 'Notes for $title.',
  duration: Duration(minutes: minutes),
);

final botweSermons = [
  sermon('s2', botwe.id, 'Walking in Faith', DateTime(2026, 10, 12)),
  sermon(
    's1',
    botwe.id,
    'The Good Shepherd',
    DateTime(2026, 10, 5),
    preacher: 'Pastor Ama Owusu',
    minutes: 65,
  ),
];
final westlandSermons = [
  sermon('w1', westland.id, 'Grace Abounds', DateTime(2026, 10, 12)),
];

class FakeSermons implements SermonSource {
  FakeSermons({this.failure, this.forEveryBranch = const []});

  final ChurchDataException? failure;

  /// Sermons without a branch, heard on every branch's tab.
  final List<Sermon> forEveryBranch;
  final requested = <String>[];

  @override
  Future<List<ChurchBranch>> branches() async => [botwe, westland];

  @override
  Future<List<Sermon>> sermons(String branchId) async {
    requested.add(branchId);
    if (failure != null) throw failure!;
    return [
      ...forEveryBranch,
      ...branchId == botwe.id ? botweSermons : westlandSermons,
    ];
  }
}

class MemoryGuestStore extends GuestBranchStore {
  MemoryGuestStore([this.saved]);

  ChurchBranch? saved;

  @override
  Future<ChurchBranch?> read() async => saved;

  @override
  Future<void> write(ChurchBranch branch) async => saved = branch;
}

/// Records what the screens ask the player to do, without playing audio.
class FakePlayer extends SermonPlayer {
  final calls = <String>[];
  Sermon? _sermon;
  String _branchName = '';
  bool _playing = false;
  double _speed = 1;
  final _position = ValueNotifier(Duration.zero);

  @override
  Sermon? get sermon => _sermon;
  @override
  String get branchName => _branchName;
  @override
  bool get playing => _playing;
  @override
  bool get buffering => false;
  @override
  String? get error => null;
  @override
  Duration get duration => _sermon?.duration ?? Duration.zero;
  @override
  ValueListenable<Duration> get position => _position;
  @override
  double get speed => _speed;

  @override
  Future<void> play(Sermon sermon, {required String branchName}) async {
    calls.add('play ${sermon.id}');
    _sermon = sermon;
    _branchName = branchName;
    _playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _playing = false;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration to) async {
    calls.add('seek ${to.inSeconds}');
    _position.value = to;
  }

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    notifyListeners();
  }

  @override
  Future<void> close() async {
    calls.add('close');
    _sermon = null;
    _playing = false;
    notifyListeners();
  }
}

// Events ---------------------------------------------------------------------

Event event(
  String id,
  String title, {
  required ChurchBranch branch,
  required DateTime start,
  bool forAll = false,
  String phone = '',
  String email = '',
  String website = '',
}) => Event(
  id: id,
  title: title,
  church: branch.name,
  branchId: branch.id,
  forAllBranches: forAll,
  startsAt: start,
  endsAt: start.add(const Duration(hours: 2)),
  dateLabel: eventDateLabel(start),
  host: 'Rev. Kofi Mensah',
  address: 'Accra',
  description: 'About $title.',
  images: const [],
  phone: phone,
  email: email,
  website: website,
  contactAddress: 'Ashaley Botwe, Accra',
);

LiveStream live(ChurchBranch branch, {DateTime? checkedAt}) => LiveStream(
  branchId: branch.id,
  status: 'live',
  videoId: 'video-${branch.id}',
  title: '${branch.name} Sunday Service',
  checkedAt: checkedAt ?? DateTime.now(),
);

List<Event> testEvents(String? branchId) => [
  event(
    'prayers',
    'Intercessory Prayers',
    branch: botwe,
    start: now.add(const Duration(days: 2)),
    phone: '+233 20 000 0000',
    email: 'events@example.org',
    website: 'example.org',
  ),
  event(
    'sunday',
    'Sunday Service',
    branch: botwe,
    start: now.add(const Duration(days: 4)),
  ),
];

class FakeEvents implements EventSource {
  FakeEvents([this.results = testEvents]);

  final List<Event> Function(String? branchId) results;
  final requests = <String?>[];
  final streams = StreamController<List<LiveStream>>.broadcast();

  @override
  Future<List<Event>> upcoming({String? branchId}) async {
    requests.add(branchId);
    return results(branchId);
  }

  @override
  Stream<List<LiveStream>> liveStreams() => streams.stream;
}

/// Records the reminders the app schedules instead of notifying.
class FakeScheduler implements ReminderScheduler {
  bool granted = true;
  final scheduled = <int, ({DateTime at, String title, String body})>{};
  final cancelled = <int>[];

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async => scheduled[id] = (at: at, title: title, body: body);

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }
}

class MemoryReminderStore extends ReminderStore {
  MemoryReminderStore([Set<String>? saved]) : saved = saved ?? {};

  Set<String> saved;

  @override
  Future<Set<String>> read() async => {...saved};

  @override
  Future<void> write(Set<String> eventIds) async => saved = {...eventIds};
}

// News and ministries --------------------------------------------------------

NewsItem newsItem(
  String id,
  String title, {
  String church = NewsItem.churchName,
  String subtitle = '',
  String summary = '',
}) => NewsItem(
  id: id,
  title: title,
  subtitle: subtitle,
  church: church,
  summary: summary,
  body: 'The full story of $title.',
  images: const [],
);

/// Church-wide news, plus Botwe's own for Botwe listeners.
List<NewsItem> testNews(String? branchId) => [
  if (branchId == botwe.id)
    newsItem(
      'youth-day',
      'Botwe Youth Day',
      church: botwe.name,
      summary: 'Games, worship and lunch for the young people of Botwe.',
    ),
  newsItem(
    'harvest',
    'Harvest Thanksgiving',
    subtitle: 'All branches give thanks together',
    summary: 'A day of thanksgiving for the whole church family.',
  ),
];

class FakeNews implements NewsSource {
  FakeNews([this.results = testNews]);

  final List<NewsItem> Function(String? branchId) results;
  final requests = <String?>[];

  @override
  Future<List<NewsItem>> latest({String? branchId}) async {
    requests.add(branchId);
    return results(branchId);
  }
}

Ministry ministry(
  String id,
  String name, {
  String focus = '',
  String meets = '',
  String venue = '',
  String members = '',
  String about = '',
}) => Ministry(
  id: id,
  name: name,
  focus: focus,
  meets: meets,
  venue: venue,
  members: members,
  about: about,
);

List<Ministry> testMinistries(String? branchId) => [
  ministry(
    'kharis',
    'Kharis Ladies',
    focus: "Women's fellowship",
    meets: 'Saturdays, 4:00 PM',
    venue: 'Main Auditorium',
    members: '50+',
    about: 'A fellowship for the women of the church.',
  ),
  ministry(
    'youth',
    'Youth Ministry',
    focus: 'Ages 18 to 35',
    meets: 'Fridays, 6:30 PM',
    venue: 'Youth Centre',
  ),
  ministry(
    'prayer',
    'Prayer Ministry',
    focus: 'Intercessory prayer',
    venue: 'Prayer Room',
  ),
];

class FakeMinistries implements MinistrySource {
  FakeMinistries({
    this.results = testMinistries,
    Set<String>? joinedIds,
    this.failWrites = false,
  }) : joinedIds = joinedIds ?? {};

  final List<Ministry> Function(String? branchId) results;
  final Set<String> joinedIds;
  bool failWrites;

  @override
  Future<List<Ministry>> list({String? branchId}) async => results(branchId);

  @override
  Future<Set<String>> joined() async => {...joinedIds};

  @override
  Future<void> join(String ministryId) async {
    if (failWrites) throw const ChurchDataException('Offline');
    joinedIds.add(ministryId);
  }

  @override
  Future<void> leave(String ministryId) async {
    if (failWrites) throw const ChurchDataException('Offline');
    joinedIds.remove(ministryId);
  }
}

// Staff ----------------------------------------------------------------------

/// Records what staff screens ask the backend to do.
class FakeAdmin implements AdminSource {
  FakeAdmin({this.role, Map<ContentKind, List<Map<String, dynamic>>>? rows})
    : rowsByKind = rows ?? {};

  StaffRole? role;
  final Map<ContentKind, List<Map<String, dynamic>>> rowsByKind;
  final saved =
      <({ContentKind kind, String? id, Map<String, Object?> values})>[];
  final deleted = <({ContentKind kind, String id})>[];
  final uploads = <String>[];
  final removed = <String>[];
  final staffList = <StaffMember>[];
  final added = <({String email, String? branchId})>[];
  List<Signup> signupList = [];

  @override
  Future<StaffRole?> myRole() async => role;

  @override
  Future<List<Map<String, dynamic>>> rows(ContentKind kind) async =>
      rowsByKind[kind] ?? [];

  @override
  Future<Map<String, dynamic>?> row(ContentKind kind, String id) async {
    for (final row in rowsByKind[kind] ?? const <Map<String, dynamic>>[]) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  @override
  Future<String> save(
    ContentKind kind,
    String? id,
    Map<String, Object?> values,
  ) async {
    saved.add((kind: kind, id: id, values: values));
    return id ?? 'new-${saved.length}';
  }

  @override
  Future<void> delete(ContentKind kind, String id) async =>
      deleted.add((kind: kind, id: id));

  @override
  Future<String> upload(
    String bucket,
    String name,
    Uint8List bytes,
    String contentType,
  ) async {
    uploads.add('$bucket/$name');
    return 'uploads/$name';
  }

  @override
  Future<void> removeFiles(String bucket, List<String> paths) async =>
      removed.addAll(paths);

  @override
  String publicUrl(String bucket, String path) =>
      'https://cdn.test/$bucket/$path';

  @override
  Future<List<Signup>> signups(String ministryId) async => signupList;

  @override
  Future<List<StaffMember>> staff() async => [...staffList];

  @override
  Future<void> addStaff(String email, String? branchId) async {
    added.add((email: email, branchId: branchId));
    staffList.add(StaffMember(email: email, branchId: branchId));
  }

  @override
  Future<void> removeStaff(String email) async =>
      staffList.removeWhere((member) => member.email == email);
}

// The app wired to fakes -----------------------------------------------------

class Harness {
  Harness({
    FakeSermons? source,
    ChurchBranch? guestBranch,
    FakeEvents? events,
    FakeNews? news,
    FakeMinistries? ministries,
    FakeScheduler? scheduler,
    MemoryReminderStore? reminderStore,
    this.admin,
  }) : source = source ?? FakeSermons(),
       guestStore = MemoryGuestStore(guestBranch),
       events = events ?? FakeEvents(),
       news = news ?? FakeNews(),
       ministries = ministries ?? FakeMinistries(),
       scheduler = scheduler ?? FakeScheduler(),
       reminderStore = reminderStore ?? MemoryReminderStore();

  final FakeSermons source;
  final MemoryGuestStore guestStore;
  final FakeEvents events;
  final FakeNews news;
  final FakeMinistries ministries;
  final FakeScheduler scheduler;
  final MemoryReminderStore reminderStore;
  final FakeAdmin? admin;
  final player = FakePlayer();
  final savedForMember = <ChurchBranch>[];

  late final state = CccState(
    sermons: SermonLibrary(
      source: source,
      guestStore: guestStore,
      saveMemberBranch: (branch) async => savedForMember.add(branch),
    ),
    player: player,
    eventSource: events,
    newsSource: news,
    ministrySource: ministries,
    reminders: EventReminders(scheduler: scheduler, store: reminderStore),
    adminSource: admin,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(430, 1100),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    addTearDown(events.streams.close);
    await tester.pumpWidget(
      CccScope(
        state: state,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildCccTheme(),
          darkTheme: buildCccTheme(Brightness.dark),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}
