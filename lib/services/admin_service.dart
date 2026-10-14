import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_drafts.dart';
import 'auth_service.dart';
import 'church_query.dart';

/// What staff screens need from the backend. The database decides what each
/// staff member may actually do (supabase/staff.sql); this only asks.
abstract interface class AdminSource {
  /// The signed-in member's staff role, or null if they aren't staff.
  Future<StaffRole?> myRole();

  /// Everything of [kind] the signed-in staff member can see, including
  /// scheduled news, newest or soonest first.
  Future<List<Map<String, dynamic>>> rows(ContentKind kind);

  Future<Map<String, dynamic>?> row(ContentKind kind, String id);

  /// Inserts (no id) or updates [values]; returns the row's id.
  Future<String> save(
    ContentKind kind,
    String? id,
    Map<String, Object?> values,
  );

  Future<void> delete(ContentKind kind, String id);

  /// Stores a file in [bucket] and returns its path there.
  Future<String> upload(
    String bucket,
    String name,
    Uint8List bytes,
    String contentType,
  );

  /// Best effort; a file that can't be removed is left behind.
  Future<void> removeFiles(String bucket, List<String> paths);

  String publicUrl(String bucket, String path);

  Future<List<Signup>> signups(String ministryId);

  Future<List<StaffMember>> staff();

  Future<void> addStaff(String email, String? branchId);

  Future<void> removeStaff(String email);
}

/// [AdminSource] on Supabase.
class AdminService implements AdminSource {
  AdminService(this._client);

  static AdminService? configured() =>
      AuthService.isConfigured ? AdminService(Supabase.instance.client) : null;

  final SupabaseClient _client;

  @override
  Future<StaffRole?> myRole() async {
    if (_client.auth.currentUser == null) return null;
    final rows = await churchQuery('Staff', () async {
      final result = await _client.rpc<List<dynamic>>('staff_scope');
      return result.cast<Map<String, dynamic>>();
    });
    if (rows.isEmpty) return null;
    return StaffRole(branchId: rows.first['branch_id'] as String?);
  }

  @override
  Future<List<Map<String, dynamic>>> rows(ContentKind kind) => churchQuery(
    kind.title,
    () => _client
        .from(kind.table)
        .select('*, branches(name)')
        .order(kind.orderBy, ascending: kind == ContentKind.ministries)
        .limit(200),
  );

  @override
  Future<Map<String, dynamic>?> row(ContentKind kind, String id) async {
    final rows = await churchQuery(
      kind.title,
      () => _client.from(kind.table).select().eq('id', id).limit(1),
    );
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<String> save(
    ContentKind kind,
    String? id,
    Map<String, Object?> values,
  ) async {
    final rows = await churchQuery(
      kind.title,
      () => id == null
          ? _client.from(kind.table).insert(values).select('id')
          : _client.from(kind.table).update(values).eq('id', id).select('id'),
      saving: true,
    );
    // Row-level security turns a refused write into "no rows".
    if (rows.isEmpty) {
      throw const ChurchDataException(
        "You don't have permission to change this. Ask an HQ admin.",
      );
    }
    return rows.first['id'] as String;
  }

  @override
  Future<void> delete(ContentKind kind, String id) async {
    final rows = await churchQuery(
      kind.title,
      () => _client.from(kind.table).delete().eq('id', id).select('id'),
      saving: true,
    );
    if (rows.isEmpty) {
      throw const ChurchDataException(
        "You don't have permission to delete this.",
      );
    }
  }

  @override
  Future<String> upload(
    String bucket,
    String name,
    Uint8List bytes,
    String contentType,
  ) async {
    final now = DateTime.now();
    final safe = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9.]+'), '-');
    final path =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/'
        '${now.microsecondsSinceEpoch}-$safe';
    try {
      await _client.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );
    } on StorageException catch (error) {
      throw ChurchDataException(_uploadMessage(error));
    } catch (_) {
      throw const ChurchDataException(
        "The upload didn't finish. Check your connection and try again.",
      );
    }
    return path;
  }

  static String _uploadMessage(StorageException error) {
    final message = error.message.toLowerCase();
    if (message.contains('size') || error.statusCode == '413') {
      return 'That file is too large to upload.';
    }
    if (message.contains('mime') || message.contains('type')) {
      return "That kind of file can't be uploaded here.";
    }
    if (error.statusCode == '403' || message.contains('policy')) {
      return "You don't have permission to upload files.";
    }
    return "The upload didn't finish. Check your connection and try again.";
  }

  @override
  Future<void> removeFiles(String bucket, List<String> paths) async {
    final stored = [
      for (final path in paths)
        if (!path.startsWith('http')) path,
    ];
    if (stored.isEmpty) return;
    try {
      await _client.storage.from(bucket).remove(stored);
    } catch (_) {}
  }

  @override
  String publicUrl(String bucket, String path) => path.startsWith('http')
      ? path
      : _client.storage.from(bucket).getPublicUrl(path);

  @override
  Future<List<Signup>> signups(String ministryId) async {
    final rows = await churchQuery('Sign-ups', () async {
      final result = await _client.rpc<List<dynamic>>(
        'signups_for_ministry',
        params: {'target': ministryId},
      );
      return result.cast<Map<String, dynamic>>();
    });
    return [for (final row in rows) Signup.fromRow(row)];
  }

  @override
  Future<List<StaffMember>> staff() async {
    final rows = await churchQuery(
      'Staff',
      () => _client
          .from('staff')
          .select('email, branch_id, branches(name)')
          .order('email'),
    );
    return [for (final row in rows) StaffMember.fromRow(row)];
  }

  @override
  Future<void> addStaff(String email, String? branchId) async {
    await churchQuery('Staff', () async {
      await _client.from('staff').upsert({
        'email': email.trim().toLowerCase(),
        'branch_id': branchId,
      });
      return const <Map<String, dynamic>>[];
    }, saving: true);
  }

  @override
  Future<void> removeStaff(String email) async {
    await churchQuery('Staff', () async {
      await _client.from('staff').delete().eq('email', email);
      return const <Map<String, dynamic>>[];
    }, saving: true);
  }
}
