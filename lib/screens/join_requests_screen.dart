import 'package:flutter/material.dart';

import '../models/admin_drafts.dart';
import '../services/church_query.dart';
import '../state/ccc_state.dart';
import '../theme/ccc_theme.dart';
import '../widgets/admin_form.dart' show confirmAction;
import '../widgets/ccc_widgets.dart';

/// Where ministry leaders, and staff who manage ministries, answer requests
/// to join ministries that approve their members.
class JoinRequestsScreen extends StatefulWidget {
  const JoinRequestsScreen({super.key});

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  /// Each ministry with the requests waiting for it.
  List<(ApprovalMinistry, List<JoinRequest>)>? groups;
  String? error;

  /// Requests being answered, so their buttons can't be pressed twice.
  final answering = <String>{};

  static const _months = 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec';

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
      final ministries = await admin.ministriesToApprove();
      final requests = await Future.wait([
        for (final ministry in ministries)
          ministry.waiting == 0
              ? Future.value(const <JoinRequest>[])
              : admin.joinRequests(ministry.id),
      ]);
      if (!mounted) return;
      setState(() {
        groups = [
          for (final (index, ministry) in ministries.indexed)
            (ministry, requests[index]),
        ];
      });
    } on ChurchDataException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> _answer(
    ApprovalMinistry ministry,
    JoinRequest request, {
    required bool approve,
  }) async {
    if (!approve) {
      final confirmed = await confirmAction(
        context,
        title: "Decline ${request.member}'s request?",
        message:
            "They'll see it wasn't approved and can ask to join "
            '${ministry.name} again later.',
        confirmLabel: 'Decline',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    final state = CccScope.of(context);
    final key = '${ministry.id}/${request.memberId}';
    setState(() => answering.add(key));
    try {
      await state.staff.source!.answerRequest(
        ministry.id,
        request.memberId,
        approve: approve,
      );
      if (!mounted) return;
      setState(() {
        groups = [
          for (final (each, requests)
              in groups ?? const <(ApprovalMinistry, List<JoinRequest>)>[])
            (
              each,
              each.id == ministry.id
                  ? [
                      for (final other in requests)
                        if (other.memberId != request.memberId) other,
                    ]
                  : requests,
            ),
        ];
      });
      showCccMessage(
        context,
        approve
            ? '${request.member} is now in ${ministry.name}.'
            : 'Request declined.',
      );
      await state.staff.refreshApprovals();
    } on ChurchDataException catch (e) {
      if (mounted) showCccMessage(context, e.message);
    } finally {
      if (mounted) setState(() => answering.remove(key));
    }
  }

  Widget _card(ApprovalMinistry ministry, JoinRequest request) {
    final p = context.palette;
    final busy = answering.contains('${ministry.id}/${request.memberId}');
    final asked = request.requestedAt;
    final month = _months.split(' ')[asked.month - 1];
    return CccCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            request.member,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            [?request.branch, 'Asked ${asked.day} $month'].join(' · '),
            style: TextStyle(fontSize: 13.5, color: p.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CccButton(
                  label: 'Decline',
                  variant: CccButtonVariant.outlined,
                  height: 44,
                  fontSize: 15,
                  onPressed: busy
                      ? null
                      : () => _answer(ministry, request, approve: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CccButton(
                  label: 'Approve',
                  height: 44,
                  fontSize: 15,
                  isLoading: busy,
                  onPressed: () => _answer(ministry, request, approve: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final groups = this.groups;
    final waiting = [
      for (final group in groups ?? const <(ApprovalMinistry, List<JoinRequest>)>[])
        if (group.$2.isNotEmpty) group,
    ];
    return Scaffold(
      body: Column(
        children: [
          const DetailsHeader(title: 'Join requests'),
          Expanded(
            child: RefreshIndicator(
              color: CccColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
                children: [
                  if (error != null)
                    _Notice(text: error!, action: 'Try again', onTap: _load)
                  else if (groups == null)
                    const SkeletonList(label: 'Loading requests', count: 2)
                  else if (waiting.isEmpty)
                    const _Notice(
                      text:
                          'No one is waiting. New requests to join your '
                          'ministries appear here.',
                    )
                  else
                    for (final (ministry, requests) in waiting) ...[
                      SectionTitle(ministry.name),
                      const SizedBox(height: 12),
                      for (final request in requests) ...[
                        _card(ministry, request),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 12),
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

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.action, this.onTap});

  final String text;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15.5, height: 1.45, color: p.textSecondary),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            CccButton(
              label: action!,
              variant: CccButtonVariant.outlined,
              width: 180,
              height: 44,
              fontSize: 15,
              onPressed: onTap,
            ),
          ],
        ],
      ),
    );
  }
}
