import 'package:flutter/material.dart';

import '../models/admin_drafts.dart';
import '../models/ministry.dart';
import '../services/auth_service.dart';
import '../services/external_actions.dart';
import '../state/ccc_state.dart';
import '../widgets/admin_form.dart' show confirmAction;
import '../widgets/cards.dart';
import '../widgets/ccc_widgets.dart';
import '../widgets/details_scaffold.dart';
import 'admin/admin_lists.dart';

/// Joins or leaves [ministry] for a member, saved to their account; for a
/// ministry that approves its members, asks to join or withdraws the
/// request. Guests are asked to log in.
Future<void> joinOrLeaveMinistry(
  BuildContext context,
  Ministry ministry, {
  Member? member,
}) async {
  if (member == null) {
    showLoginPrompt(context);
    return;
  }
  final directory = CccScope.of(context).ministries;
  final name = ministry.name;
  // Undoing these needs a leader, so check first.
  final standing = directory.standing(ministry.id);
  final withdrawing = standing == MinistryStanding.asked;
  if (withdrawing ||
      (standing == MinistryStanding.joined && ministry.needsApproval)) {
    final confirmed = await confirmAction(
      context,
      title: withdrawing ? 'Withdraw your request?' : 'Leave $name?',
      message: withdrawing
          ? "A leader of $name hasn't answered it yet. You can ask again "
                'later.'
          : "To come back, you'll need to ask a leader again.",
      confirmLabel: withdrawing ? 'Withdraw' : 'Leave',
      destructive: !withdrawing,
    );
    if (!confirmed || !context.mounted) return;
  }
  final String message;
  try {
    message = switch (await directory.toggle(ministry)) {
      MembershipChange.joined => 'You joined $name.',
      MembershipChange.left when ministry.addsMembers =>
        "You left $name. You won't be added to it again.",
      MembershipChange.left => 'You left $name.',
      MembershipChange.asked =>
        'Request sent. A leader of $name will answer it.',
      MembershipChange.withdrew => 'Your request to join $name is withdrawn.',
    };
  } catch (_) {
    if (context.mounted) {
      showCccMessage(
        context,
        "Couldn't update ${ministry.name}. Check your connection and try "
        'again.',
      );
    }
    return;
  }
  if (context.mounted) showCccMessage(context, message);
}

class MinistryDetailsScreen extends StatelessWidget {
  const MinistryDetailsScreen({required this.ministry, this.member, super.key});

  final Ministry ministry;
  final Member? member;

  @override
  Widget build(BuildContext context) {
    final directory = CccScope.of(context).ministries;
    return ListenableBuilder(
      listenable: directory,
      builder: (context, _) {
        final standing = directory.standing(ministry.id);
        final facts = [
          if (standing == MinistryStanding.declined)
            const InfoRow(
              icon: Icons.info_outline,
              text: "Your last request wasn't approved. You can ask again.",
            ),
          if (ministry.needsApproval)
            const InfoRow(
              icon: Icons.how_to_reg_outlined,
              text: 'A leader approves new members.',
            ),
          if (ministry.meets.isNotEmpty)
            InfoRow(icon: Icons.schedule, label: 'Meets', text: ministry.meets),
          if (ministry.venue.isNotEmpty)
            InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Where',
              text: ministry.venue,
            ),
          if (ministry.members.isNotEmpty)
            InfoRow(
              icon: Icons.groups_outlined,
              text: '${ministry.members} members',
            ),
        ];
        return DetailsScaffold(
          images: ministry.images,
          actions: [
            Expanded(
              child: CccButton(
                label: switch (standing) {
                  MinistryStanding.joined => 'Joined',
                  MinistryStanding.asked => 'Requested',
                  _ when ministry.needsApproval => 'Ask to join',
                  _ => 'Join ministry',
                },
                variant: switch (standing) {
                  MinistryStanding.joined ||
                  MinistryStanding.asked => CccButtonVariant.tonal,
                  _ => CccButtonVariant.filled,
                },
                icon: switch (standing) {
                  MinistryStanding.joined => const Icon(Icons.check_rounded),
                  MinistryStanding.asked => const Icon(Icons.schedule),
                  _ => null,
                },
                onPressed: () =>
                    joinOrLeaveMinistry(context, ministry, member: member),
              ),
            ),
            const SizedBox(width: 10),
            Builder(
              builder: (buttonContext) => ShareButton(
                onPressed: () =>
                    ExternalActions.share(buttonContext, ministry.shareText),
              ),
            ),
          ],
          children: [
            if (ministry.focus.isNotEmpty) ...[
              DetailsEyebrow(ministry.focus),
              const SizedBox(height: 6),
            ],
            DetailsTitle(ministry.name),
            if (facts.isNotEmpty) ...[
              const SizedBox(height: 20),
              InfoGroup(rows: facts),
            ],
            if (ministry.about.isNotEmpty)
              DetailsSection(
                title: 'About',
                child: DetailsBody(ministry.about),
              ),
            StaffEditButton(
              kind: ContentKind.ministries,
              id: ministry.id,
              branchId: ministry.branchId,
            ),
          ],
        );
      },
    );
  }
}
