import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event.dart';
import '../models/live_stream.dart';
import 'auth_service.dart';
import 'church_query.dart';

/// Where events and branch live streams come from.
abstract interface class EventSource {
  /// Upcoming and current events for members of [branchId] (its own and the
  /// all-branch ones), soonest first. Without a branch, only all-branch
  /// events.
  Future<List<Event>> upcoming({String? branchId});

  /// Every branch's stream status, updated as the checker records changes.
  Stream<List<LiveStream>> liveStreams();
}

/// Reads the `events` and `live_streams` tables and the `events` storage
/// bucket created by `supabase/schema.sql`.
abstract interface class ReminderEventSource {
  Future<List<Event>> reminderEvents(Set<String> ids);
}

class EventService implements EventSource, ReminderEventSource {
  EventService(this._client);

  static EventService? configured() =>
      AuthService.isConfigured ? EventService(Supabase.instance.client) : null;

  static const bucket = 'events';

  final SupabaseClient _client;

  @override
  Future<List<Event>> upcoming({String? branchId}) async {
    // Started up to half a day ago, so events in progress still show.
    final since = DateTime.now()
        .subtract(const Duration(hours: 12))
        .toUtc()
        .toIso8601String();
    final rows = await churchQuery('Events', () {
      final query = _client
          .from('events')
          .select(
            'id, branch_id, for_all_branches, title, starts_at, ends_at, '
            'host, address, description, image_paths, phone, email, '
            'website, branches(name)',
          )
          .gte('starts_at', since);
      final forListener = branchId == null
          ? query.eq('for_all_branches', true)
          : query.or('for_all_branches.eq.true,branch_id.eq.$branchId');
      return forListener.order('starts_at').limit(100);
    });
    return [for (final row in rows) Event.fromRow(row, imageUrl: imageUrl)];
  }

  @override
  Future<List<Event>> reminderEvents(Set<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await churchQuery(
      'Events',
      () => _client
          .from('events')
          .select('*, branches(name)')
          .inFilter('id', ids.toList()),
    );
    return [for (final row in rows) Event.fromRow(row, imageUrl: imageUrl)];
  }

  @override
  Stream<List<LiveStream>> liveStreams() => _client
      .from('live_streams')
      .stream(primaryKey: ['branch_id'])
      .map((rows) => [for (final row in rows) LiveStream.fromRow(row)]);

  /// A file in the events bucket, or a full link.
  String imageUrl(String path) => path.startsWith('http')
      ? path
      : _client.storage.from(bucket).getPublicUrl(path);
}
