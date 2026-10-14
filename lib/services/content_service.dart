import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Where ministries and the member's memberships come from.
abstract interface class MinistrySource {
  /// The ministries of [branchId] and the church-wide ones. Without a
  /// branch, only church-wide ministries.
  Future<List<Ministry>> list({String? branchId});

  /// Ids of the ministries the signed-in member has joined.
  Future<Set<String>> joined();

  Future<void> join(String ministryId);

  Future<void> leave(String ministryId);
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
      final query = _client
          .from('ministries')
          .select(
            'id, branch_id, name, focus, meets, venue, members_label, about, '
            'image_paths',
          );
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
