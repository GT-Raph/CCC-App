import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/church_branch.dart';
import '../models/sermon.dart';
import 'auth_service.dart';
import 'church_query.dart';

export 'church_query.dart' show ChurchDataException;

/// Where the branch list and sermons come from.
abstract interface class SermonSource {
  Future<List<ChurchBranch>> branches();

  /// The branch's sermons and those for every branch, newest first.
  Future<List<Sermon>> sermons(String branchId);
}

/// Reads the `branches` and `sermons` tables and the `sermons` storage bucket
/// created by `supabase/schema.sql`.
class SermonService implements SermonSource {
  SermonService(this._client);

  /// The service for the app's Supabase project, or null when Supabase isn't
  /// set up (tests, or a missing .env).
  static SermonService? configured() =>
      AuthService.isConfigured ? SermonService(Supabase.instance.client) : null;

  static const bucket = 'sermons';

  final SupabaseClient _client;

  @override
  Future<List<ChurchBranch>> branches() async {
    final rows = await churchQuery(
      'Branches',
      () => _client
          .from('branches')
          .select('id, name, google_place_id')
          .order('name'),
    );
    return [for (final row in rows) ChurchBranch.fromJson(row)];
  }

  @override
  Future<List<Sermon>> sermons(String branchId) async {
    final rows = await churchQuery(
      'Sermons',
      () => _client
          .from('sermons')
          .select(
            'id, branch_id, title, preacher, preached_on, description, '
            'audio_path, duration_seconds',
          )
          .or('branch_id.is.null,branch_id.eq.$branchId')
          .order('preached_on', ascending: false)
          .order('created_at', ascending: false)
          .limit(200),
    );
    return [for (final row in rows) Sermon.fromRow(row, audioUrl: audioUrl)];
  }

  /// A file in the sermons bucket, or a full link pasted into `audio_path`.
  String audioUrl(String path) => path.startsWith('http')
      ? path
      : _client.storage.from(bucket).getPublicUrl(path);
}
