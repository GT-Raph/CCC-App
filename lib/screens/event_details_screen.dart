import 'package:flutter/material.dart';

import '../models/admin_drafts.dart';
import '../models/event.dart';
import '../models/live_stream.dart';
import '../navigation.dart';
import '../services/auth_service.dart';
import '../services/external_actions.dart';
import '../state/ccc_state.dart';
import '../state/event_reminders.dart';
import '../widgets/cards.dart';
import '../widgets/ccc_widgets.dart';
import '../widgets/details_scaffold.dart';
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
      listenable: Listenable.merge([state.events, state.reminders]),
      builder: (context, _) =>
          _build(context, state, state.events.liveFor(event)),
    );
  }

  Widget _build(BuildContext context, CccState state, LiveStream? live) {
    final contact = [
      if (event.phone.isNotEmpty)
        InfoRow(
          icon: Icons.phone_outlined,
          text: event.phone,
          onTap: () => ExternalActions.call(context, event.phone),
        ),
      if (event.email.isNotEmpty)
        InfoRow(
          icon: Icons.mail_outline,
          text: event.email,
          onTap: () => ExternalActions.email(context, event.email),
        ),
      if (event.website.isNotEmpty)
        InfoRow(
          icon: Icons.language,
          text: event.website,
          onTap: () => ExternalActions.website(context, event.website),
        ),
      if (event.contactAddress.isNotEmpty)
        InfoRow(
          icon: Icons.location_on_outlined,
          text: event.contactAddress,
          onTap: () =>
              ExternalActions.directions(context, event.contactAddress),
        ),
    ];
    return DetailsScaffold(
      images: event.images,
      isLive: live != null,
      actions: [
        Expanded(
          child: EventActionButton(
            event: event,
            reminded: state.reminders.isSet(event.id),
            live: live != null,
            prominent: true,
            onPressed: () => _action(context, live),
          ),
        ),
        const SizedBox(width: 10),
        Builder(
          builder: (buttonContext) => ShareButton(
            onPressed: () =>
                ExternalActions.share(buttonContext, event.shareText),
          ),
        ),
      ],
      children: [
        DetailsEyebrow(event.churchLabel),
        const SizedBox(height: 6),
        DetailsTitle(event.title),
        const SizedBox(height: 20),
        EventFacts(
          event: event,
          onAddress: () => ExternalActions.directions(context, event.address),
        ),
        if (event.description.isNotEmpty)
          DetailsSection(title: 'About', child: DetailsBody(event.description)),
        if (contact.isNotEmpty)
          DetailsSection(
            title: 'Contact',
            child: InfoGroup(rows: contact),
          ),
        StaffEditButton(
          kind: ContentKind.events,
          id: event.id,
          branchId: event.branchId,
          forAllBranches: event.forAllBranches,
        ),
      ],
    );
  }
}
