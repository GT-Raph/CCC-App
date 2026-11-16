import 'package:flutter/material.dart';

import '../../models/stream_settings.dart';
import '../../services/admin_service.dart';
import '../../services/church_query.dart';
import '../../services/external_actions.dart';
import '../../state/ccc_state.dart';
import '../../theme/ccc_theme.dart';
import '../../widgets/admin_form.dart';
import '../../widgets/ccc_widgets.dart';
import '../../widgets/media.dart';

class StreamSettingsScreen extends StatefulWidget {
  const StreamSettingsScreen({super.key});

  @override
  State<StreamSettingsScreen> createState() => _StreamSettingsScreenState();
}

class _StreamSettingsScreenState extends State<StreamSettingsScreen> {
  List<StreamSettings>? _branches;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Keeps the current list on screen while it reloads.
  Future<void> _load() async {
    final source = CccScope.of(context).staff.source;
    if (source == null) {
      setState(() => _error = 'Live stream settings are not set up yet.');
      return;
    }
    setState(() => _error = null);
    try {
      final found = await source.streamSettings();
      if (mounted) setState(() => _branches = found);
    } on ChurchDataException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Live stream settings could not load.');
      }
    }
  }

  Future<void> _open(StreamSettings branch) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StreamChannelEditor(settings: branch),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final branches = _branches;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final side = readableGutter(context);
    return Scaffold(
      body: Column(
        children: [
          const DetailsHeader(title: 'Live stream settings'),
          Expanded(
            child: RefreshIndicator(
              color: CccColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(side, 8, side, 32 + bottom),
                children: [
                  if (_error != null)
                    _Message(text: _error!, retry: _load)
                  else if (branches == null)
                    const SkeletonList(
                      label: 'Loading live stream settings',
                      count: 3,
                    )
                  else if (branches.isEmpty)
                    const _Message(
                      text: 'Ask your branch staff to add you as a media leader.',
                    )
                  else ...[
                    Text(
                      'Tap a branch to connect the YouTube channel it streams services on.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final branch in branches) ...[
                      _BranchRow(branch: branch, onTap: () => _open(branch)),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A branch, its channel, and a pill when it is live or needs attention.
class _BranchRow extends StatelessWidget {
  const _BranchRow({required this.branch, required this.onTap});

  final StreamSettings branch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final connected = branch.channel.isNotEmpty;
    return CccCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: p.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Under the name, so a pill never squeezes a long branch
                  // name on a narrow phone; wraps below the channel if needed.
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        connected ? branch.channel : 'Not connected',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: connected ? p.textSecondary : p.textMuted,
                        ),
                      ),
                      if (branch.isLive)
                        const LiveBadge()
                      else if (branch.needsAttention)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: p.surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Needs attention',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: p.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: p.textMuted),
          ],
        ),
      ),
    );
  }
}

class StreamChannelEditor extends StatefulWidget {
  const StreamChannelEditor({required this.settings, super.key});
  final StreamSettings settings;

  @override
  State<StreamChannelEditor> createState() => _StreamChannelEditorState();
}

class _StreamChannelEditorState extends State<StreamChannelEditor> {
  late StreamSettings _saved = widget.settings;
  late final _channel = TextEditingController(text: _saved.channelUrl);
  bool _busy = false;
  bool _dirty = false;
  String? _error;
  String? _notice;

  AdminSource get _source => CccScope.of(context).staff.source!;

  @override
  void dispose() {
    _channel.dispose();
    super.dispose();
  }

  Future<void> _save({bool disconnect = false}) async {
    if (_busy) return;
    final channel = disconnect ? null : parseYouTubeChannel(_channel.text);
    if (!disconnect && channel == null) {
      setState(
        () => _error =
            'Enter a YouTube channel link, @handle or channel ID. Video links cannot be used.',
      );
      return;
    }
    if (disconnect ||
        (_saved.channel.isNotEmpty && channel != _saved.channel)) {
      final confirmed = await confirmAction(
        context,
        title: disconnect ? 'Disconnect YouTube?' : 'Change YouTube channel?',
        message:
            '${_saved.name} will ${disconnect ? 'stop showing YouTube live streams' : 'show live services from the new channel'}.',
        confirmLabel: disconnect ? 'Disconnect' : 'Change channel',
        destructive: disconnect,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await _source.saveStreamChannel(_saved.id, channel);
      if (!mounted) return;
      setState(() {
        if ((channel ?? '') != _saved.channel) {
          _saved = StreamSettings(
            id: _saved.id,
            name: _saved.name,
            channelId: channel != null && channel.startsWith('UC')
                ? channel
                : null,
            handle: channel != null && channel.startsWith('@') ? channel : null,
          );
        }
        _channel.text = _saved.channelUrl;
        _dirty = false;
        _notice = disconnect ? 'YouTube disconnected.' : 'Channel saved.';
      });
    } on ChurchDataException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save the channel. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshStatus() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final branches = await _source.streamSettings();
      final matches = branches.where((branch) => branch.id == _saved.id);
      if (matches.isEmpty) {
        throw const ChurchDataException(
          'You no longer have access to this branch.',
        );
      }
      if (!mounted) return;
      setState(() {
        _saved = matches.first;
        if (!_dirty) _channel.text = _saved.channelUrl;
      });
    } on ChurchDataException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not refresh the channel status. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final note = TextStyle(fontSize: 14, height: 1.45, color: p.textSecondary);
    return AdminFormScaffold(
      title: 'YouTube channel',
      saveLabel: 'Save channel',
      onSave: _save,
      busy: _busy,
      dirty: _dirty,
      onDelete: _saved.channel.isEmpty ? null : () => _save(disconnect: true),
      deleteLabel: 'Disconnect YouTube',
      children: [
        FormSection(
          title: _saved.name,
          children: [
            _StreamStatus(settings: _saved),
            if (_saved.channel.isNotEmpty)
              Wrap(
                spacing: 12,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        ExternalActions.website(context, _saved.channelUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open channel'),
                  ),
                  TextButton.icon(
                    onPressed: _refreshStatus,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh status'),
                  ),
                ],
              ),
            LabeledField(
              label: 'YouTube channel',
              controller: _channel,
              hint: 'youtube.com/@YourChurch',
              helper: 'Channel link, @handle or UC… channel ID',
              keyboardType: TextInputType.url,
              capitalization: TextCapitalization.none,
              onChanged: (_) => setState(() {
                _dirty = true;
                _notice = null;
              }),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(fontSize: 14, color: p.error)),
            if (_notice != null)
              Text(
                _notice!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: p.accentText,
                ),
              ),
            Text(
              'Public broadcasts that allow embedding play in the app. Checks run more often around scheduled services. Unscheduled broadcasts can take up to 30 minutes to appear.',
              style: note,
            ),
          ],
        ),
        if (CccScope.of(context).staff.canManage(_saved.id))
          FormSection(
            title: 'Media leaders',
            children: [
              Text(
                'Let someone change this channel without giving them staff access.',
                style: note,
              ),
              CccButton(
                label: 'Manage media leaders',
                variant: CccButtonVariant.tonal,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MediaLeadersScreen(
                      branchId: _saved.id,
                      branchName: _saved.name,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// What the last automatic check found, set apart from the instructions.
class _StreamStatus extends StatelessWidget {
  const _StreamStatus({required this.settings});

  final StreamSettings settings;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (icon, color) = settings.channel.isEmpty
        ? (Icons.link_off, p.textMuted)
        : settings.needsAttention
        ? (Icons.error_outline, p.error)
        : settings.isLive
        ? (Icons.sensors, LiveBadge.red)
        : settings.checkedAt == null
        ? (Icons.schedule, p.textSecondary)
        : (Icons.check_circle_outline, p.textSecondary);
    return CccCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              settings.checkMessage,
              style: TextStyle(fontSize: 15, height: 1.4, color: p.text),
            ),
          ),
        ],
      ),
    );
  }
}

class MediaLeadersScreen extends StatefulWidget {
  const MediaLeadersScreen({
    required this.branchId,
    required this.branchName,
    super.key,
  });
  final String branchId;
  final String branchName;

  @override
  State<MediaLeadersScreen> createState() => _MediaLeadersScreenState();
}

class _MediaLeadersScreenState extends State<MediaLeadersScreen> {
  final _email = TextEditingController();
  List<String>? _leaders;
  String? _error;
  bool _busy = false;
  bool _started = false;
  AdminSource get _source => CccScope.of(context).staff.source!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ChurchDataException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not update media leaders. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _perform(() async {
    final found = await _source.mediaLeaders(widget.branchId);
    if (mounted) setState(() => _leaders = found);
  });

  Future<void> _add() async {
    final email = _email.text.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter their sign-in email address.');
      return;
    }
    await _perform(() async {
      await _source.addMediaLeader(widget.branchId, email);
      if (mounted) {
        setState(() {
          _leaders = {...?_leaders, email}.toList()..sort();
          _email.clear();
        });
      }
    });
  }

  Future<void> _remove(String email) async {
    final confirmed = await confirmAction(
      context,
      title: 'Remove media leader?',
      message:
          '$email will no longer manage this branch’s channel unless they also have staff access.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _perform(() async {
      await _source.removeMediaLeader(widget.branchId, email);
      if (mounted) setState(() => _leaders?.remove(email));
    });
  }

  @override
  Widget build(BuildContext context) {
    final allowed = CccScope.of(context).staff.canManage(widget.branchId);
    return Scaffold(
      body: Column(
        children: [
          const DetailsHeader(title: 'Media leaders'),
          Expanded(
            child: AbsorbPointer(
              absorbing: _busy,
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: readableGutter(context),
                  vertical: 20,
                ),
                children: [
                  if (!allowed)
                    const Text('Only branch staff can appoint media leaders.')
                  else ...[
                    SectionTitle(widget.branchName),
                    const SizedBox(height: 16),
                    const Text(
                      'Media leaders can change this branch’s YouTube channel. They cannot publish other content or appoint leaders. They must confirm their email and reopen the app after being added.',
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.palette.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_busy) const LinearProgressIndicator(),
                    if (_leaders == null && !_busy)
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    if (_leaders != null) ...[
                      for (final email in _leaders!)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(email),
                          trailing: IconButton(
                            tooltip: 'Remove $email',
                            onPressed: () => _remove(email),
                            icon: const Icon(Icons.person_remove_outlined),
                          ),
                        ),
                      if (_leaders!.isEmpty)
                        const Text('No media leaders added yet.'),
                      const SizedBox(height: 20),
                      LabeledField(
                        label: 'Leader’s sign-in email',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        capitalization: TextCapitalization.none,
                      ),
                      const SizedBox(height: 16),
                      CccButton(label: 'Add media leader', onPressed: _add),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An error or empty list, worded and styled like the other admin lists.
class _Message extends StatelessWidget {
  const _Message({required this.text, this.retry});

  final String text;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: context.palette.textSecondary),
        ),
        if (retry != null) ...[
          const SizedBox(height: 16),
          CccButton(
            label: 'Try again',
            variant: CccButtonVariant.outlined,
            width: 160,
            height: 44,
            fontSize: 14,
            onPressed: retry,
          ),
        ],
      ],
    ),
  );
}
