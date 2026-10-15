import 'package:flutter/material.dart';

import '../models/admin_drafts.dart';
import '../models/ministry.dart';
import '../services/auth_service.dart';
import '../services/external_actions.dart';
import '../state/ccc_state.dart';
import '../widgets/cards.dart';
import '../widgets/ccc_widgets.dart';
import '../widgets/details_scaffold.dart';
import 'admin/admin_lists.dart';

/// Joins or leaves [ministry] for a member, saved to their account; guests
/// are asked to log in.
Future<void> joinOrLeaveMinistry(
  BuildContext context,
  Ministry ministry, {
  Member? member,
}) async {
  if (member == null) {
    showLoginPrompt(context);
    return;
  }
  final String message;
  try {
    final joined = await CccScope.of(context).ministries.toggle(ministry);
    message = joined
        ? 'You joined ${ministry.name}.'
        : 'You left ${ministry.name}.';
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
        final joined = directory.hasJoined(ministry.id);
        final facts = [
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
                label: joined ? 'Joined' : 'Join ministry',
                variant: joined
                    ? CccButtonVariant.tonal
                    : CccButtonVariant.filled,
                icon: joined ? const Icon(Icons.check_rounded) : null,
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
