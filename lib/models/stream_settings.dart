/// A branch whose YouTube channel the signed-in member can manage.
class StreamSettings {
  const StreamSettings({
    required this.id,
    required this.name,
    this.channelId,
    this.handle,
    this.status,
    this.checkedAt,
    this.error,
  });

  factory StreamSettings.fromRow(Map<String, dynamic> row) => StreamSettings(
    id: row['id'] as String,
    name: row['name'] as String,
    channelId: row['youtube_channel_id'] as String?,
    handle: row['youtube_channel_handle'] as String?,
    status: row['status'] as String?,
    checkedAt: DateTime.tryParse(row['checked_at'] as String? ?? ''),
    error: row['error'] as String?,
  );

  final String id;
  final String name;
  final String? channelId;
  final String? handle;
  final String? status;
  final DateTime? checkedAt;
  final String? error;

  String get channel => handle ?? channelId ?? '';
  String get channelUrl => handle != null
      ? 'https://www.youtube.com/$handle'
      : channelId != null
      ? 'https://www.youtube.com/channel/$channelId'
      : '';

  bool get checkOverdue =>
      checkedAt != null &&
      DateTime.now().difference(checkedAt!) > const Duration(minutes: 35);

  /// Connected, but the last check failed or is overdue.
  bool get needsAttention =>
      channel.isNotEmpty && (error != null || checkOverdue);

  /// Live at a check that is still current.
  bool get isLive =>
      channel.isNotEmpty &&
      error == null &&
      checkedAt != null &&
      !checkOverdue &&
      status == 'live';

  String get checkMessage {
    if (channel.isEmpty) return 'No YouTube channel connected.';
    if (error != null) {
      return 'The channel could not be checked. Check the link, or ask church staff to check the live stream setup.';
    }
    if (checkedAt == null) {
      return 'Channel saved. Waiting for the automatic channel check.';
    }
    if (checkOverdue) {
      return 'The channel check is overdue. Ask church staff to check the live stream setup.';
    }
    return switch (status) {
      'live' => 'Live at the last check.',
      'upcoming' => 'A scheduled broadcast was found.',
      _ => 'No live broadcast found at the last check.',
    };
  }
}

/// Only channel links, never video links or lookalike hosts. The server
/// validates the normalized value again and resolves handles with YouTube.
String? parseYouTubeChannel(String input) {
  var value = input.trim();
  if (value.isEmpty) return null;
  final id = RegExp(r'^UC[A-Za-z0-9_-]{22}$');
  final handle = RegExp(r'^@[^\s/?#@]+$');
  bool valid(String text) =>
      id.hasMatch(text) ||
      (text.length >= 2 && text.length <= 101 && handle.hasMatch(text));
  if (valid(value)) return value;
  if (!value.contains('://')) value = 'https://$value';
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !['https', 'http'].contains(uri.scheme) ||
      !['youtube.com', 'www.youtube.com', 'm.youtube.com'].contains(uri.host) ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort) {
    return null;
  }
  final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
  final String candidate;
  final int used;
  if (parts.isNotEmpty && parts.first.startsWith('@')) {
    candidate = parts.first;
    used = 1;
  } else if (parts.length >= 2 && parts.first == 'channel') {
    candidate = parts[1];
    used = 2;
    if (!id.hasMatch(candidate)) return null;
  } else {
    return null;
  }
  if (parts.length > used &&
      !(parts.length == used + 1 &&
          [
            'streams',
            'live',
            'videos',
            'featured',
            'about',
            'shorts',
          ].contains(parts.last))) {
    return null;
  }
  return valid(candidate) ? candidate : null;
}
