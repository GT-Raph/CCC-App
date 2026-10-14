import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/event.dart';

enum ReminderOutcome {
  hourBefore,
  atStart,
  removed,
  started,
  denied,
  noTime,
  limit,
}

/// Device-local reminders backed by the phone's notification scheduler.
class EventReminders extends ChangeNotifier {
  EventReminders({
    ReminderScheduler? scheduler,
    this.store = const ReminderStore(),
    DateTime Function()? clock,
  }) : scheduler = scheduler ?? LocalReminderScheduler(),
       _clock = clock ?? DateTime.now;

  final ReminderScheduler scheduler;
  final ReminderStore store;
  final DateTime Function() _clock;
  static const lead = Duration(hours: 1);
  // Leave room below iOS's 64 pending-notification limit.
  static const maxReminders = 60;
  Set<String> _eventIds = {};
  Future<void>? _restored;
  Future<void> _queue = Future.value();
  final _pending = <String, Future<ReminderOutcome>>{};
  bool _disposed = false;

  bool isSet(String id) => _eventIds.contains(id);

  Future<void> restore() => _restored ??= () async {
    _eventIds = await store.read();
    _changed();
  }();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  // The cleanup must not return `remove`'s value: that is this very future,
  // and whenComplete would wait on it forever.
  Future<ReminderOutcome> toggle(Event event) =>
      _pending[event.id] ??= _serial(() => _toggle(event)).whenComplete(() {
        _pending.remove(event.id);
      });

  Future<ReminderOutcome> _toggle(Event event) async {
    await restore();
    if (_eventIds.contains(event.id)) {
      await scheduler.cancel(notificationId(event.id));
      await _save(_eventIds.difference({event.id}));
      return ReminderOutcome.removed;
    }
    final start = event.startsAt;
    if (start == null) return ReminderOutcome.noTime;
    if (!start.isAfter(_clock())) return ReminderOutcome.started;
    if (_eventIds.length >= maxReminders) return ReminderOutcome.limit;
    if (!await scheduler.requestPermission()) return ReminderOutcome.denied;
    // The permission dialog may have remained open past the start time.
    if (!start.isAfter(_clock())) return ReminderOutcome.started;
    final outcome = await _schedule(event, start);
    try {
      await _save({..._eventIds, event.id});
    } catch (_) {
      await scheduler.cancel(notificationId(event.id));
      rethrow;
    }
    return outcome;
  }

  /// Reconcile with a complete lookup of saved IDs when available. A filtered
  /// branch feed alone must never cancel another branch's reminders.
  Future<void> resync(
    List<Event> events, {
    Future<List<Event>> Function(Set<String> ids)? lookup,
    bool complete = false,
  }) => _serial(() async {
    await restore();
    if (_eventIds.isEmpty) return;
    try {
      final current = lookup == null ? events : await lookup({..._eventIds});
      final byId = {for (final event in current) event.id: event};
      final kept = {..._eventIds};
      for (final id in _eventIds) {
        final event = byId[id];
        if (event == null && lookup == null && !complete) continue;
        final start = event?.startsAt;
        if (start == null || !start.isAfter(_clock())) {
          await scheduler.cancel(notificationId(id));
          kept.remove(id);
        } else {
          await _schedule(event!, start);
        }
      }
      if (!setEquals(kept, _eventIds)) await _save(kept);
    } catch (_) {
      // Preserve saved IDs when offline or scheduling fails; retry next load.
    }
  });

  Future<ReminderOutcome> _schedule(Event event, DateTime start) async {
    final before = start.subtract(lead);
    final early = before.isAfter(_clock());
    await scheduler.schedule(
      id: notificationId(event.id),
      at: early ? before : start,
      title: event.title,
      body: [
        early ? 'Starts in an hour' : 'Starting now',
        if (event.church.isNotEmpty) event.church,
      ].join(', '),
    );
    return early ? ReminderOutcome.hourBefore : ReminderOutcome.atStart;
  }

  Future<void> _save(Set<String> ids) async {
    await store.write(ids);
    _eventIds = ids;
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Stable 31-bit notification ID (FNV-1a).
  static int notificationId(String eventId) {
    var hash = 0x811c9dc5;
    for (final unit in eventId.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}

/// Schedules and cancels the notifications.
abstract interface class ReminderScheduler {
  /// Asks to show notifications; false if the member says no.
  Future<bool> requestPermission();

  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  });

  Future<void> cancel(int id);
}

/// [ReminderScheduler] on flutter_local_notifications.
class LocalReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'event_reminders',
      'Event reminders',
      channelDescription: 'Reminders for events you asked to be reminded of.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> _init() => _ready ??= _plugin
      .initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          // Permission is asked for on the first Remind Me, not at launch.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      )
      .then((_) {});

  @override
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return false;
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    await _init();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      // An exact moment, so UTC avoids needing the device's time zone.
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      notificationDetails: _details,
      // Within a few minutes is fine for a reminder, and needs no special
      // exact-alarm permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _init();
    await _plugin.cancel(id: id);
  }
}

/// The event ids with reminders, saved on the phone.
class ReminderStore {
  const ReminderStore();

  static const _key = 'event_reminders_v1';

  Future<Set<String>> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {...?prefs.getStringList(_key)};
    } catch (_) {
      return {};
    }
  }

  Future<void> write(Set<String> eventIds) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setStringList(_key, eventIds.toList())) {
      throw StateError('Could not save reminders on this device.');
    }
  }
}
