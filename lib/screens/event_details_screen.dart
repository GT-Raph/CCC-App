import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/admin_drafts.dart';
import '../models/event.dart';
import '../models/live_stream.dart';
import '../navigation.dart';
import '../services/auth_service.dart';
import '../services/external_actions.dart';
import '../state/ccc_state.dart';
import '../state/event_reminders.dart';
import '../theme/ccc_theme.dart';
import '../widgets/cards.dart';
import '../widgets/ccc_widgets.dart';
import '../widgets/media.dart';
import 'admin/admin_lists.dart';

/// Join Now (online events) or Remind Me / Reminded; guests are asked to
/// log in first.
Future<void> remindOrJoin(
  BuildContext context,
  Event event, {
  Member? member,
}) async {
  if (member == null) {
    showLoginPrompt(context);
    return;
  }
  if (event.joinable) {
    await ExternalActions.website(context, event.website);
    return;
  }
  final String message;
  try {
    final outcome = await CccScope.of(context).reminders.toggle(event);
    message = switch (outcome) {
      ReminderOutcome.hourBefore =>
        "We'll remind you an hour before ${event.title}.",
      ReminderOutcome.atStart => "We'll remind you when ${event.title} starts.",
      ReminderOutcome.removed => 'Reminder removed.',
      ReminderOutcome.started => '${event.title} has already started.',
      ReminderOutcome.denied =>
        "Turn on notifications for CCC in your phone's settings to get "
            'reminders.',
      ReminderOutcome.limit =>
        'Remove an existing reminder before adding another.',
      ReminderOutcome.noTime => "This event doesn't have a start time yet.",
    };
  } catch (_) {
    if (context.mounted) {
      showCccMessage(context, "Couldn't set the reminder. Try again.");
    }
    return;
  }
  if (context.mounted) showCccMessage(context, message);
}

class EventDetailsScreen extends StatelessWidget {
  const EventDetailsScreen({required this.event, this.member, super.key});

  final Event event;
  final Member? member;

  void _action(BuildContext context, LiveStream? live) {
    if (live != null) {
      CccNavigation.openLiveStream(
        context,
        live,
        branchName: event.church,
        event: event,
      );
      return;
    }
    remindOrJoin(context, event, member: member);
  }

  @override
  Widget build(BuildContext context) {
    final state = CccScope.of(context);
    return ListenableBuilder(
      listenable: state.events,
      builder: (context, _) =>
          _build(context, state, state.events.liveFor(event)),
    );
  }

  Widget _build(BuildContext context, CccState state, LiveStream? live) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final hasContact = [
      event.phone,
      event.email,
      event.website,
      event.contactAddress,
    ].any((value) => value.isNotEmpty);
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
                    ImageCarousel(
                      images: event.images,
                      height: 200,
                      isLive: live != null,
                      badgeWidth: 54,
                      badgeInset: 20,
                      dotsBottom: 20,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          EventInfo(event: event),
                          const SizedBox(height: 32),
                          if (hasContact) ...[
                            _ContactCard(event: event),
                            const SizedBox(height: 24),
                          ],
                          Builder(
                            builder: (buttonContext) => CccButton(
                              label: 'Share',
                              variant: CccButtonVariant.outlined,
                              iconGap: 19,
                              icon: const Icon(Icons.share, size: 31),
                              onPressed: () => ExternalActions.share(
                                buttonContext,
                                event.shareText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          EventActionButton(
                            event: event,
                            reminded: state.reminders.isSet(event.id),
                            live: live != null,
                            joinVariant: CccButtonVariant.filled,
                            onPressed: () => _action(context, live),
                          ),
                          StaffEditButton(
                            kind: ContentKind.events,
                            id: event.id,
                            branchId: event.branchId,
                            forAllBranches: event.forAllBranches,
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

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    // (gap above, row): the design spaces the website row 1px further.
    final rows = <(double, Widget)>[
      if (event.phone.isNotEmpty)
        (
          15,
          _ContactRow(
            icon: Icons.phone_iphone_outlined,
            text: event.phone,
            onTap: () => ExternalActions.call(context, event.phone),
          ),
        ),
      if (event.email.isNotEmpty)
        (
          15,
          _ContactRow(
            icon: Icons.mail_outline,
            text: event.email,
            onTap: () => ExternalActions.email(context, event.email),
          ),
        ),
      if (event.website.isNotEmpty)
        (
          16,
          _ContactRow(
            icon: Icons.language,
            text: event.website,
            onTap: () => ExternalActions.website(context, event.website),
          ),
        ),
      if (event.contactAddress.isNotEmpty)
        (
          15,
          _ContactRow(
            icon: Icons.location_on_outlined,
            text: event.contactAddress,
            onTap: () =>
                ExternalActions.directions(context, event.contactAddress),
          ),
        ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: CccColors.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CccColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, (gap, row)) in rows.indexed) ...[
            if (index > 0) SizedBox(height: gap),
            row,
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Icon(icon, size: 23, color: CccColors.ink),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: CccFonts.contact,
                  fontWeight: FontWeight.w300,
                  fontSize: 14,
                  height: 22 / 14,
                  color: CccColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
