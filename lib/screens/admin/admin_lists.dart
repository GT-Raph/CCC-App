import 'package:flutter/material.dart';

import '../../models/admin_drafts.dart';
import '../../models/event.dart' show eventDateLabel;
import '../../services/church_query.dart';
import '../../state/ccc_state.dart';
import '../../theme/ccc_theme.dart';
import '../../widgets/admin_form.dart';
import '../../widgets/ccc_widgets.dart';
import 'content_editor.dart';
import 'editors.dart';

/// Opens the editor for [kind]: a new item, or the one with [id].
Future<EditorResult?> openEditor(
  BuildContext context,
  ContentKind kind, {
  String? id,
}) {
  return Navigator.of(context).push<EditorResult>(
    MaterialPageRoute(
      builder: (_) => switch (kind) {
        ContentKind.news => NewsEditor(id: id),
        ContentKind.events => EventEditor(id: id),
        ContentKind.sermons => SermonEditor(id: id),
        ContentKind.ministries => MinistryEditor(id: id),
      },
    ),
  );
}

/// The staff hub: every kind of content, and staff for church-wide admins.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  static const _descriptions = {
    ContentKind.news: 'Stories on the Home tab',
    ContentKind.events: 'Services and gatherings, with live streams',
    ContentKind.sermons: 'Recordings on the Sermons tab',
    ContentKind.ministries: 'Ministries members can join',
  };

  static const _icons = {
    ContentKind.news: Icons.article_outlined,
    ContentKind.events: Icons.calendar_month_outlined,
    ContentKind.sermons: Icons.headphones_outlined,
    ContentKind.ministries: Icons.people_outline,
  };

  @override
  Widget build(BuildContext context) {
    final state = CccScope.of(context);
    final role = state.staff.role;
    final p = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;
    String scope() {
      if (role == null) return '';
      if (role.churchWide) return 'HQ admin: every branch';
      for (final branch in state.sermons.branchList) {
        if (branch.id == role.branchId) return '${branch.name} staff';
      }
      return 'Branch staff';
    }

    return Scaffold(
      body: Column(
        children: [
          const DetailsHeader(title: 'Church content'),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
              children: [
                if (role != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      scope(),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: p.textMuted,
                      ),
                    ),
                  ),
                for (final kind in ContentKind.values) ...[
                  _HubTile(
                    icon: _icons[kind]!,
                    title: kind.title,
                    subtitle: _descriptions[kind]!,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AdminListScreen(kind: kind),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (role?.churchWide ?? false)
                  _HubTile(
                    icon: Icons.badge_outlined,
                    title: 'Staff',
                    subtitle: 'Who can post, and for which branch',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const StaffScreen(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CccCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.accentTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: p.accentText),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, color: p.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: p.textMuted),
        ],
      ),
    );
  }
}

/// Everything of one kind the staff member manages, with New and Edit.
class AdminListScreen extends StatefulWidget {
  const AdminListScreen({required this.kind, super.key});

  final ContentKind kind;

  @override
  State<AdminListScreen> createState() => _AdminListScreenState();
}

class _AdminListScreenState extends State<AdminListScreen> {
  List<Map<String, dynamic>>? rows;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = CccScope.of(context);
    final admin = state.staff.source;
    final role = state.staff.role;
    if (admin == null || role == null) return;
    setState(() => error = null);
    try {
      final found = await admin.rows(widget.kind);
      if (!mounted) return;
      setState(() {
        rows = [
          for (final row in found)
            if (role.canManage(row['branch_id'] as String?) &&
                (row['for_all_branches'] != true || role.churchWide))
              row,
        ];
      });
    } on ChurchDataException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> _open({String? id}) async {
    final result = await openEditor(context, widget.kind, id: id);
    if (result != null && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final rows = this.rows;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottom > 0 ? 0 : 8),
        child: FloatingActionButton.extended(
          onPressed: () => _open(),
          backgroundColor: CccColors.primary,
          foregroundColor: CccColors.onPrimary,
          elevation: 2,
          shape: const StadiumBorder(),
          icon: const Icon(Icons.add),
          label: Text(
            'New ${kind.noun}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      body: Column(
        children: [
          DetailsHeader(title: kind.title),
          Expanded(
            child: RefreshIndicator(
              color: CccColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 96 + bottom),
                children: [
                  if (error != null)
                    _Message(text: error!, action: 'Try again', onTap: _load)
                  else if (rows == null)
                    const SkeletonList(label: 'Loading', count: 3)
                  else if (rows.isEmpty)
                    _Message(
                      text: 'Nothing here yet. Add the first ${kind.noun}.',
                    )
                  else
                    for (final row in rows) ...[
                      _ContentRow(
                        kind: kind,
                        row: row,
                        onTap: () => _open(id: row['id'] as String),
                      ),
                      const SizedBox(height: 10),
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

class _ContentRow extends StatelessWidget {
  const _ContentRow({
    required this.kind,
    required this.row,
    required this.onTap,
  });

  final ContentKind kind;
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title =
        (row[kind == ContentKind.ministries ? 'name' : 'title'] as String?) ??
        '';
    final branch = (row['branches'] as Map?)?['name'] as String?;
    final now = DateTime.now();
    DateTime? time(String column) {
      final value = row[column] as String?;
      return value == null ? null : DateTime.parse(value).toLocal();
    }

    final (detail, status) = switch (kind) {
      ContentKind.news => (
        eventDateLabel(time('published_at')!),
        time('published_at')!.isAfter(now) ? 'Scheduled' : null,
      ),
      ContentKind.events => (
        eventDateLabel(time('starts_at')!),
        (time('ends_at') ?? time('starts_at')!.add(const Duration(hours: 3)))
                .isBefore(now)
            ? 'Past'
            : null,
      ),
      ContentKind.sermons => ((row['preacher'] as String?) ?? '', null),
      ContentKind.ministries => ((row['focus'] as String?) ?? '', null),
    };
    final p = context.palette;
    final where = row['for_all_branches'] == true
        ? '${branch ?? ''}, for all branches'
        : branch ??
              (kind == ContentKind.ministries ? 'Church-wide' : 'All branches');

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
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: p.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [where, if (detail.isNotEmpty) detail].join('\n'),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (status != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status == 'Scheduled' ? p.accentTint : p.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: status == 'Scheduled'
                        ? p.accentText
                        : p.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined, size: 20, color: p.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action, this.onTap});

  final String text;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: context.palette.textSecondary,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            CccButton(
              label: action!,
              variant: CccButtonVariant.outlined,
              width: 160,
              height: 44,
              fontSize: 14,
              onPressed: onTap,
            ),
          ],
        ],
      ),
    );
  }
}

/// Who joined a ministry: names and branches, newest first.
class SignupsScreen extends StatefulWidget {
  const SignupsScreen({
    required this.ministryId,
    required this.ministryName,
    super.key,
  });

  final String ministryId;
  final String ministryName;

  @override
  State<SignupsScreen> createState() => _SignupsScreenState();
}

class _SignupsScreenState extends State<SignupsScreen> {
  List<Signup>? signups;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final admin = CccScope.of(context).staff.source;
    if (admin == null) return;
    setState(() => error = null);
    try {
      final found = await admin.signups(widget.ministryId);
      if (mounted) setState(() => signups = found);
    } on ChurchDataException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signups = this.signups;
    final p = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: Column(
        children: [
          const DetailsHeader(title: 'Who has joined'),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
              children: [
                Text(
                  widget.ministryName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: p.text,
                  ),
                ),
                if (signups != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    child: Text(
                      signups.length == 1
                          ? '1 member'
                          : '${signups.length} members',
                      style: TextStyle(fontSize: 15, color: p.textSecondary),
                    ),
                  ),
                if (error != null)
                  _Message(text: error!, action: 'Try again', onTap: _load)
                else if (signups == null)
                  const SkeletonList(label: 'Loading', count: 2)
                else if (signups.isEmpty)
                  const _Message(text: 'No one has joined from the app yet.')
                else
                  CccCard(
                    child: Column(
                      children: [
                        for (final (index, signup) in signups.indexed) ...[
                          if (index > 0) const Divider(height: 1),
                          ListTile(
                            title: Text(
                              signup.member,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: p.text,
                              ),
                            ),
                            subtitle: Text(
                              [
                                ?signup.branch,
                                'Joined ${eventDateLabel(signup.joinedAt).split(',').first}',
                              ].join('\n'),
                              style: TextStyle(
                                fontSize: 13,
                                color: p.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// HQ admins add and remove staff here.
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<StaffMember>? staff;
  String? error;
  final email = TextEditingController();
  String? branchId;
  String? emailError;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CccScope.of(context).sermons.loadBranches();
      _load();
    });
  }

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final admin = CccScope.of(context).staff.source;
    if (admin == null) return;
    setState(() => error = null);
    try {
      final found = await admin.staff();
      if (mounted) setState(() => staff = found);
    } on ChurchDataException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> _add() async {
    final address = email.text.trim().toLowerCase();
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address);
    setState(() => emailError = valid ? null : 'Enter their sign-in email.');
    if (!valid) return;
    final admin = CccScope.of(context).staff.source!;
    setState(() => busy = true);
    try {
      await admin.addStaff(address, branchId);
      email.clear();
      if (mounted) showCccMessage(context, '$address can now post.');
      await _load();
    } on ChurchDataException catch (e) {
      if (mounted) showCccMessage(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _remove(StaffMember member) async {
    final confirmed = await confirmAction(
      context,
      title: 'Remove ${member.email}?',
      message:
          "They'll keep their member account but can no longer post or "
          'edit church content.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final admin = CccScope.of(context).staff.source!;
    try {
      await admin.removeStaff(member.email);
      await _load();
    } on ChurchDataException catch (e) {
      if (mounted) showCccMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = CccScope.of(context);
    final me = state.staff.email?.toLowerCase();
    final staff = this.staff;
    final p = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: Column(
        children: [
          const DetailsHeader(title: 'Staff'),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
              children: [
                FormSection(
                  title: 'Give someone access',
                  children: [
                    LabeledField(
                      label: 'Email they sign in with',
                      controller: email,
                      required: true,
                      error: emailError,
                      keyboardType: TextInputType.emailAddress,
                      capitalization: TextCapitalization.none,
                      helper:
                          'They need a CCC account with this email, and must '
                          'have confirmed it.',
                    ),
                    ListenableBuilder(
                      listenable: state.sermons,
                      builder: (context, _) => BranchChooser(
                        label: 'Can post for',
                        branches: state.sermons.branchList,
                        value: branchId,
                        lockedTo: null,
                        allBranchesLabel: 'Every branch (HQ admin)',
                        onChanged: (value) => setState(() => branchId = value),
                      ),
                    ),
                    CccButton(
                      label: 'Add staff',
                      isLoading: busy,
                      onPressed: _add,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const SectionTitle('Current staff'),
                const SizedBox(height: 12),
                if (error != null)
                  _Message(text: error!, action: 'Try again', onTap: _load)
                else if (staff == null)
                  const SkeletonList(label: 'Loading', count: 2)
                else
                  CccCard(
                    child: Column(
                      children: [
                        for (final (index, member) in staff.indexed) ...[
                          if (index > 0) const Divider(height: 1),
                          ListTile(
                            title: Text(
                              member.email,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: p.text,
                              ),
                            ),
                            subtitle: Text(
                              member.branchId == null
                                  ? 'HQ admin, every branch'
                                  : '${member.branchName ?? 'Branch'} staff',
                              style: TextStyle(
                                fontSize: 13,
                                color: p.textSecondary,
                              ),
                            ),
                            // Removing yourself would lock you out.
                            trailing: member.email == me
                                ? Text(
                                    'You',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: p.textMuted,
                                    ),
                                  )
                                : IconButton(
                                    tooltip: 'Remove ${member.email}',
                                    onPressed: () => _remove(member),
                                    icon: Icon(
                                      Icons.person_remove_outlined,
                                      color: p.error,
                                    ),
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Edit …" on a details screen, for staff who manage that item. After the
/// item is saved or deleted, the details screen closes so the refreshed list
/// shows.
class StaffEditButton extends StatelessWidget {
  const StaffEditButton({
    required this.kind,
    required this.id,
    required this.branchId,
    this.forAllBranches = false,
    super.key,
  });

  final ContentKind kind;
  final String id;
  final String? branchId;

  /// All-branch events are church-wide admins' to edit.
  final bool forAllBranches;

  @override
  Widget build(BuildContext context) {
    final role = CccScope.of(context).staff.role;
    if (role == null ||
        !role.canManage(branchId) ||
        (forAllBranches && !role.churchWide)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: CccButton(
        label: 'Edit ${kind.noun}',
        variant: CccButtonVariant.tonal,
        icon: const Icon(Icons.edit_outlined),
        onPressed: () async {
          final result = await openEditor(context, kind, id: id);
          if (result != null && context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }
}
