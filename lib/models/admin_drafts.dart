import 'member_details.dart';

/// The four kinds of church content staff manage, with where each lives in
/// Supabase.
enum ContentKind {
  news('news', 'news', 'published_at', 'News', 'story'),
  events('events', 'events', 'starts_at', 'Events', 'event'),
  sermons('sermons', 'sermons', 'preached_on', 'Sermons', 'sermon'),
  ministries(
    'ministries',
    'ministries',
    'sort_order',
    'Ministries',
    'ministry',
  );

  const ContentKind(
    this.table,
    this.bucket,
    this.orderBy,
    this.title,
    this.noun,
  );

  final String table;
  final String bucket;
  final String orderBy;

  /// "News", "Events"…
  final String title;

  /// "news story", "event"… for buttons and messages.
  final String noun;
}

/// A staff member's reach: a church-wide admin, or one branch's staff.
class StaffRole {
  const StaffRole({this.branchId, this.superAdmin = false});

  /// Null for church-wide admins.
  final String? branchId;

  /// Decides who is staff (`public.is_super_admin` in supabase/staff.sql).
  /// Super admins are always church-wide.
  final bool superAdmin;

  bool get churchWide => branchId == null;

  /// Mirrors `public.can_manage` in supabase/staff.sql: church-wide admins
  /// manage everything; branch staff only their branch (never church-wide).
  bool canManage(String? branch) =>
      churchWide || (branch != null && branch == branchId);
}

/// A row in the `staff` table.
class StaffMember {
  const StaffMember({
    required this.email,
    this.branchId,
    this.branchName,
    this.superAdmin = false,
  });

  factory StaffMember.fromRow(Map<String, dynamic> row) => StaffMember(
    email: row['email'] as String,
    branchId: row['branch_id'] as String?,
    branchName: (row['branches'] as Map?)?['name'] as String?,
    superAdmin: row['super_admin'] as bool? ?? false,
  );

  final String email;
  final String? branchId;
  final String? branchName;
  final bool superAdmin;
}

/// Someone who joined a ministry, as staff see them.
class Signup {
  const Signup({required this.member, this.branch, required this.joinedAt});

  factory Signup.fromRow(Map<String, dynamic> row) => Signup(
    member: row['member'] as String? ?? 'Member',
    branch: row['member_branch'] as String?,
    joinedAt: DateTime.parse(row['joined_at'] as String).toLocal(),
  );

  final String member;
  final String? branch;
  final DateTime joinedAt;
}

String _text(Map<String, dynamic> row, String column) =>
    ((row[column] as String?) ?? '').trim();

List<String> _paths(Map<String, dynamic> row) => [
  for (final path in (row['image_paths'] as List?) ?? const []) path as String,
];

DateTime? _time(Map<String, dynamic> row, String column) {
  final value = row[column] as String?;
  return value == null ? null : DateTime.parse(value).toLocal();
}

String _utc(DateTime time) => time.toUtc().toIso8601String();

/// A news story being written or edited.
class NewsDraft {
  NewsDraft({
    this.id,
    this.branchId,
    this.title = '',
    this.subtitle = '',
    this.summary = '',
    this.body = '',
    List<String>? imagePaths,
    DateTime? publishedAt,
  }) : imagePaths = imagePaths ?? [],
       publishedAt = publishedAt ?? DateTime.now();

  factory NewsDraft.fromRow(Map<String, dynamic> row) => NewsDraft(
    id: row['id'] as String,
    branchId: row['branch_id'] as String?,
    title: _text(row, 'title'),
    subtitle: _text(row, 'subtitle'),
    summary: _text(row, 'summary'),
    body: _text(row, 'body'),
    imagePaths: _paths(row),
    publishedAt: _time(row, 'published_at'),
  );

  String? id;
  String? branchId;
  String title;
  String subtitle;
  String summary;
  String body;
  List<String> imagePaths;
  DateTime publishedAt;

  Map<String, Object?> toRow() => {
    'branch_id': branchId,
    'title': title.trim(),
    'subtitle': subtitle.trim(),
    'summary': summary.trim(),
    'body': body.trim(),
    'image_paths': imagePaths,
    'published_at': _utc(publishedAt),
  };
}

/// An event being created or edited.
class EventDraft {
  EventDraft({
    this.id,
    this.branchId,
    this.forAllBranches = false,
    this.title = '',
    DateTime? startsAt,
    this.endsAt,
    this.host = '',
    this.address = '',
    this.description = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    List<String>? imagePaths,
  }) : startsAt = startsAt ?? _nextHour(),
       imagePaths = imagePaths ?? [];

  factory EventDraft.fromRow(Map<String, dynamic> row) => EventDraft(
    id: row['id'] as String,
    branchId: row['branch_id'] as String?,
    forAllBranches: row['for_all_branches'] as bool? ?? false,
    title: _text(row, 'title'),
    startsAt: _time(row, 'starts_at'),
    endsAt: _time(row, 'ends_at'),
    host: _text(row, 'host'),
    address: _text(row, 'address'),
    description: _text(row, 'description'),
    phone: _text(row, 'phone'),
    email: _text(row, 'email'),
    website: _text(row, 'website'),
    imagePaths: _paths(row),
  );

  static DateTime _nextHour() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour + 1);
  }

  String? id;

  /// The host branch; its live stream is the event's.
  String? branchId;
  bool forAllBranches;
  String title;
  DateTime startsAt;
  DateTime? endsAt;
  String host;
  String address;
  String description;
  String phone;
  String email;
  String website;
  List<String> imagePaths;

  Map<String, Object?> toRow() => {
    'branch_id': branchId,
    'for_all_branches': forAllBranches,
    'title': title.trim(),
    'starts_at': _utc(startsAt),
    'ends_at': endsAt == null ? null : _utc(endsAt!),
    'host': host.trim(),
    'address': address.trim(),
    'description': description.trim(),
    'phone': phone.trim(),
    'email': email.trim(),
    'website': website.trim(),
    'image_paths': imagePaths,
  };
}

/// A sermon recording being uploaded or edited.
class SermonDraft {
  SermonDraft({
    this.id,
    this.branchId,
    this.title = '',
    this.preacher = '',
    DateTime? preachedOn,
    this.description = '',
    this.audioPath = '',
    this.durationMinutes,
  }) : preachedOn = preachedOn ?? DateTime.now();

  factory SermonDraft.fromRow(Map<String, dynamic> row) {
    final seconds = row['duration_seconds'] as int?;
    return SermonDraft(
      id: row['id'] as String,
      branchId: row['branch_id'] as String?,
      title: _text(row, 'title'),
      preacher: _text(row, 'preacher'),
      preachedOn: DateTime.parse(row['preached_on'] as String),
      description: _text(row, 'description'),
      audioPath: _text(row, 'audio_path'),
      durationMinutes: seconds == null ? null : (seconds / 60).round(),
    );
  }

  String? id;
  String? branchId;
  String title;
  String preacher;
  DateTime preachedOn;
  String description;

  /// The recording in the sermons bucket, or a full https link.
  String audioPath;
  int? durationMinutes;

  Map<String, Object?> toRow() {
    String two(int value) => value.toString().padLeft(2, '0');
    return {
      'branch_id': branchId,
      'title': title.trim(),
      'preacher': preacher.trim(),
      'preached_on':
          '${preachedOn.year}-${two(preachedOn.month)}-${two(preachedOn.day)}',
      'description': description.trim(),
      'audio_path': audioPath,
      'duration_seconds': durationMinutes == null || durationMinutes! <= 0
          ? null
          : durationMinutes! * 60,
    };
  }
}

/// A ministry being added or edited.
class MinistryDraft {
  MinistryDraft({
    this.id,
    this.branchId,
    this.name = '',
    this.focus = '',
    this.meets = '',
    this.venue = '',
    this.membersLabel = '',
    this.about = '',
    List<String>? imagePaths,
    this.sortOrder = 0,
    this.addsMembers = false,
    this.minAge,
    this.maxAge,
    this.forGender,
    Set<MaritalStatus>? forMaritalStatuses,
    this.forStudents,
    this.needsApproval = false,
  }) : imagePaths = imagePaths ?? [],
       forMaritalStatuses = forMaritalStatuses ?? {};

  factory MinistryDraft.fromRow(Map<String, dynamic> row) => MinistryDraft(
    id: row['id'] as String,
    branchId: row['branch_id'] as String?,
    name: _text(row, 'name'),
    focus: _text(row, 'focus'),
    meets: _text(row, 'meets'),
    venue: _text(row, 'venue'),
    membersLabel: _text(row, 'members_label'),
    about: _text(row, 'about'),
    imagePaths: _paths(row),
    sortOrder: row['sort_order'] as int? ?? 0,
    addsMembers: row['auto_assign'] as bool? ?? false,
    minAge: row['min_age'] as int?,
    maxAge: row['max_age'] as int?,
    forGender: Gender.fromName(row['for_gender']),
    forMaritalStatuses: {
      for (final value in (row['for_marital_statuses'] as List?) ?? const [])
        ?MaritalStatus.fromName(value),
    },
    forStudents: row['for_students'] as bool?,
    needsApproval: row['needs_approval'] as bool? ?? false,
  );

  String? id;
  String? branchId;
  String name;
  String focus;
  String meets;
  String venue;
  String membersLabel;
  String about;
  List<String> imagePaths;
  int sortOrder;

  /// Adds members who meet every rule below (supabase/ministry_matching.sql).
  /// Unset rules don't restrict; at least one must be set.
  bool addsMembers;
  int? minAge;
  int? maxAge;
  Gender? forGender;
  Set<MaritalStatus> forMaritalStatuses;

  /// True for students only, false for those who aren't, null for anyone.
  bool? forStudents;

  /// Members ask to join and a leader approves them
  /// (supabase/ministry_approval.sql). Never with [addsMembers].
  bool needsApproval;

  bool get hasRule =>
      minAge != null ||
      maxAge != null ||
      forGender != null ||
      forMaritalStatuses.isNotEmpty ||
      forStudents != null;

  Map<String, Object?> toRow() => {
    'branch_id': branchId,
    'name': name.trim(),
    'focus': focus.trim(),
    'meets': meets.trim(),
    'venue': venue.trim(),
    'members_label': membersLabel.trim(),
    'about': about.trim(),
    'image_paths': imagePaths,
    'sort_order': sortOrder,
    'auto_assign': addsMembers,
    'min_age': minAge,
    'max_age': maxAge,
    'for_gender': forGender?.name,
    'for_marital_statuses': [
      for (final status in MaritalStatus.values)
        if (forMaritalStatuses.contains(status)) status.name,
    ],
    'for_students': forStudents,
    'needs_approval': needsApproval,
  };
}

/// A ministry whose requests to join the signed-in member answers, as its
/// leader or as staff who manage it.
class ApprovalMinistry {
  const ApprovalMinistry({
    required this.id,
    required this.name,
    required this.waiting,
  });

  factory ApprovalMinistry.fromRow(Map<String, dynamic> row) =>
      ApprovalMinistry(
        id: row['id'] as String,
        name: row['name'] as String,
        waiting: row['waiting'] as int? ?? 0,
      );

  final String id;
  final String name;

  /// Requests not answered yet.
  final int waiting;
}

/// Someone asking to join a ministry, as its leaders see them.
class JoinRequest {
  const JoinRequest({
    required this.memberId,
    required this.member,
    this.branch,
    required this.requestedAt,
  });

  factory JoinRequest.fromRow(Map<String, dynamic> row) => JoinRequest(
    memberId: row['user_id'] as String,
    member: row['member'] as String? ?? 'Member',
    branch: row['member_branch'] as String?,
    requestedAt: DateTime.parse(row['requested_at'] as String).toLocal(),
  );

  final String memberId;
  final String member;
  final String? branch;
  final DateTime requestedAt;
}
