import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/member_details.dart';
import '../models/ministry.dart';
import '../models/news.dart';
import 'auth_service.dart';
import 'church_query.dart';

/// Where news comes from.
abstract interface class NewsSource {
  /// The latest news for members of [branchId] (its own and the church-wide
  /// news), newest first. Without a branch, only church-wide news.
  Future<List<NewsItem>> latest({String? branchId});
}

/// Where ministries, the member's memberships, and the details that match
/// them with ministries come from.
abstract interface class MinistrySource {
  /// The ministries of [branchId] and the church-wide ones. Without a
  /// branch, only church-wide ministries.
  Future<List<Ministry>> list({String? branchId});

  /// Ids of the ministries the signed-in member has joined.
  Future<Set<String>> joined();

  Future<void> join(String ministryId);

  Future<void> leave(String ministryId);

  /// The signed-in member's requests to join ministries that approve their
  /// members, by ministry id.
  Future<Map<String, RequestState>> requests();

  /// Asks to join a ministry that approves its members, or asks again.
  Future<void> requestToJoin(String ministryId);

  /// Withdraws a request that hasn't been answered.
  Future<void> withdrawRequest(String ministryId);

  /// The signed-in member's details, or null if they haven't been asked.
  Future<MemberDetails?> myDetails();

  Future<void> saveDetails(MemberDetails details);

  /// Brings the member's automatic ministries up to date: joins the ones
  /// they qualify for and leaves automatic ones they no longer do. Returns
  /// the names of the ministries just joined.
  Future<List<String>> matchMinistries();
}

/// Reads and writes the `news`, `ministries` and `ministry_members` tables
/// created by `supabase/schema.sql`.
class ContentService implements NewsSource, MinistrySource {
  ContentService(this._client);

  static ContentService? configured() => AuthService.isConfigured
      ? ContentService(Supabase.instance.client)
      : null;

  final SupabaseClient _client;

  @override
  Future<List<NewsItem>> latest({String? branchId}) async {
    final rows = await churchQuery('News', () {
      final query = _client
          .from('news')
          .select(
            'id, branch_id, title, subtitle, summary, body, image_paths, '
            'branches(name)',
          )
          .lte('published_at', DateTime.now().toUtc().toIso8601String());
      return _forBranch(
        query,
        branchId,
      ).order('published_at', ascending: false).limit(50);
    });
    return [
      for (final row in rows)
        NewsItem.fromRow(row, imageUrl: (path) => _publicUrl('news', path)),
    ];
  }

  @override
  Future<List<Ministry>> list({String? branchId}) async {
    final rows = await churchQuery('Ministries', () {
      // Every column, so the list still loads on a database where
      // ministry_matching.sql (auto_assign) hasn't been run yet.
      final query = _client.from('ministries').select();
      return _forBranch(query, branchId).order('sort_order').order('name');
    });
    return [
      for (final row in rows)
        Ministry.fromRow(
          row,
          imageUrl: (path) => _publicUrl('ministries', path),
        ),
    ];
  }

  @override
  Future<Set<String>> joined() async {
    // Row-level security returns only the signed-in member's rows.
    final rows = await churchQuery(
      'Ministries',
      () => _client.from('ministry_members').select('ministry_id'),
    );
    return {for (final row in rows) row['ministry_id'] as String};
  }

  @override
  Future<void> join(String ministryId) => _write(
    () => _client.from('ministry_members').upsert({
      'ministry_id': ministryId,
      'user_id': _client.auth.currentUser!.id,
    }),
  );

  @override
  Future<void> leave(String ministryId) => _write(
    () => _client
        .from('ministry_members')
        .delete()
        .eq('ministry_id', ministryId)
        .eq('user_id', _client.auth.currentUser!.id),
  );

  @override
  Future<Map<String, RequestState>> requests() async {
    // Row-level security returns only the signed-in member's requests.
    final rows = await churchQuery(
      'Ministries',
      () => _client.from('ministry_requests').select('ministry_id, status'),
    );
    return {
      for (final row in rows)
        row['ministry_id'] as String: row['status'] == 'declined'
            ? RequestState.declined
            : RequestState.pending,
    };
  }

  @override
  Future<void> requestToJoin(String ministryId) => _write(
    () => _client.rpc('request_to_join', params: {'target': ministryId}),
  );

  @override
  Future<void> withdrawRequest(String ministryId) => _write(
    () => _client
        .from('ministry_requests')
        .delete()
        .eq('ministry_id', ministryId)
        .eq('user_id', _client.auth.currentUser!.id),
  );

  @override
  Future<MemberDetails?> myDetails() async {
    // Row-level security returns only the signed-in member's row.
    final rows = await churchQuery(
      'Your details',
      () => _client
          .from('member_details')
          .select('birth_date, gender, marital_status, student')
          .limit(1),
    );
    return rows.isEmpty ? null : MemberDetails.fromRow(rows.first);
  }

  @override
  Future<void> saveDetails(MemberDetails details) async {
    await churchQuery('Your details', () async {
      await _client.from('member_details').upsert({
        'user_id': _client.auth.currentUser!.id,
        ...details.toRow(),
      });
      return const <Map<String, dynamic>>[];
    }, saving: true);
  }

  @override
  Future<List<String>> matchMinistries() async {
    final rows = await churchQuery('Ministries', () async {
      final result = await _client.rpc<List<dynamic>>('match_my_ministries');
      return result.cast<Map<String, dynamic>>();
    });
    return [for (final row in rows) row['name'] as String];
  }

  /// Rows for everyone (branch_id empty) plus, with a branch, its own.
  PostgrestFilterBuilder<T> _forBranch<T>(
    PostgrestFilterBuilder<T> query,
    String? branchId,
  ) => branchId == null
      ? query.isFilter('branch_id', null)
      : query.or('branch_id.is.null,branch_id.eq.$branchId');

  String _publicUrl(String bucket, String path) => path.startsWith('http')
      ? path
      : _client.storage.from(bucket).getPublicUrl(path);

  Future<void> _write(Future<Object?> Function() run) async {
    await churchQuery('Ministries', () async {
      await run();
      return const <Map<String, dynamic>>[];
    });
  }
}
