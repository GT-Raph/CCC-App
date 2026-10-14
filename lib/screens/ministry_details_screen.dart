import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/admin_drafts.dart';
import '../models/ministry.dart';
import '../services/auth_service.dart';
import '../services/external_actions.dart';
import '../state/ccc_state.dart';
import '../theme/ccc_theme.dart';
import '../widgets/cards.dart';
import '../widgets/ccc_widgets.dart';
import '../widgets/media.dart';
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
    final joined = CccScope.of(context).ministries.hasJoined(ministry.id);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkStatusBar,
      child: Scaffold(
        backgroundColor: CccColors.background,
        body: Column(
          children: [
            const DetailsHeader(title: 'Details'),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 14 + bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (ministry.images.isNotEmpty)
                      ImageCarousel(
                        images: ministry.images,
                        height: 200,
                        dotsBottom: 20,
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MinistryInfo(ministry: ministry),
                          const SizedBox(height: 32),
                          Builder(
                            builder: (buttonContext) => CccButton(
                              label: 'Share',
                              variant: CccButtonVariant.outlined,
                              iconGap: 19,
                              icon: const Icon(Icons.share, size: 31),
                              onPressed: () => ExternalActions.share(
                                buttonContext,
                                ministry.shareText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          CccButton(
                            label: joined ? 'Joined' : 'Join Ministry',
                            variant: joined
                                ? CccButtonVariant.outlined
                                : CccButtonVariant.filled,
                            iconGap: 8,
                            icon: joined
                                ? const Icon(Icons.check_rounded, size: 26)
                                : null,
                            onPressed: () => joinOrLeaveMinistry(
                              context,
                              ministry,
                              member: member,
                            ),
                          ),
                          StaffEditButton(
                            kind: ContentKind.ministries,
                            id: ministry.id,
                            branchId: ministry.branchId,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
