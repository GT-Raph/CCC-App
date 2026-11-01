# Calvary Charismatic Centre

Flutter app with branch-based accounts, church news, events, ministries,
Google Maps branch locations, YouTube live streams and audio sermons.

## Real content only

The app ships **no sample news, events, sermons, ministries, member counts
or preselected memberships**. Content is read from Supabase; an empty table
shows an empty state, and an unavailable backend shows an error with retry.
Test fixtures live only in `test/support/` and are not app assets.
The bundled welcome photo and logo are design assets, not news. The app
follows the phone's light or dark appearance; the splash and welcome screens
are always dark.

- **Home:** published news for the chosen branch and church-wide news.
- **Events:** the chosen branch's events plus `for_all_branches` events.
- **Church:** branch addresses, photos and directions from Google Maps.
- **Ministries:** real ministry records and memberships saved on the member's account.
- **Sermons:** recordings for the chosen branch and for every branch, with
  background playback.

Members choose their branch at registration or on first login, and can change
it in their account. Guests can choose a branch; the device remembers it.
Guests must sign in to join a ministry or set a reminder.

## Backend setup

Copy `.env.example` to `.env` and enter the Supabase project URL and its
**publishable** key. Never bundle database passwords, service-role keys,
YouTube keys or the live-checker secret in the app. `.env` is packaged inside
the app, so its values are readable by anyone with the app binary.

For a new database, run [schema.sql](supabase/schema.sql), then review and run
[branches.sql](supabase/branches.sql). For the existing CCC database, run
[content.sql](supabase/content.sql) to add news, ministries, memberships and
their storage buckets. Then run [staff.sql](supabase/staff.sql) so staff can
post from the app, [ministry_matching.sql](supabase/ministry_matching.sql)
so members are added to the ministries that are for them, and
[ministry_approval.sql](supabase/ministry_approval.sql) so ministries such as
Media or Choir approve their new members. Run them in that order, and again
in that order after updating the app. These scripts add no example content.

`branches.sql` contains Google listing IDs collected for the church. Church
staff must verify branch names and duplicates before release. Renaming a row
preserves its relationships; do not delete branches used by members or content
without reviewing the consequences.

Row-level security allows public reading of published church content, while
members can read and change only their own ministry memberships and profiles.
The details members give for ministry matching (`member_details`) can be read
only by that member; staff never see them, and the matching runs inside the
database. Only people listed in the `staff` table can publish content or
upload media.
Check the deployed policies, including storage policies, before release.

## Posting from the app

Church staff publish news, events, sermons and ministries inside the app, with
no SQL. There are three levels of access:

| Level | `staff` row | Can manage |
| --- | --- | --- |
| Super admin | `branch_id` empty, `super_admin` ticked | Everything an HQ admin can, and the staff list: who is staff, for which branch, and who else is a super admin |
| HQ admin | `branch_id` empty | Church-wide news, sermons and ministries, events shown to every branch, and any single branch's content |
| Branch staff | their branch | Only their own branch's news, events, sermons and ministries |

Branch staff can never post for another branch or for every branch. The
database enforces this; hiding buttons in the app is only a convenience, so
someone who edits the app still cannot get round it. Staff of the
Headquarters branch who should only post for the HQ congregation are branch
staff with that branch; give HQ admin (empty branch) only to people who
publish for the whole church.

**One-time setup**

1. Run [staff.sql](supabase/staff.sql) after `schema.sql` or `content.sql`.
2. The first admin signs up in the app and confirms their email.
3. In **Table Editor → staff** (schema `public`), insert one row: their
   sign-in email in lower case, with `branch_id` left empty and
   `super_admin` ticked. This makes them the first super admin, and it is the
   only dashboard step.

To update a database set up before super admins existed, run `staff.sql`
again. If it has HQ admins but no super admin, the HQ admin added first
becomes the super admin and can appoint others from the app.

**Day to day**

- Staff see **New story / New event / New ministry / New sermon** above each
  tab's list, and **Edit** on details screens for content they manage.
- **Account → Manage church content** lists everything they can edit,
  including scheduled news, and opens the same forms.
- Super admins add, change or remove staff in **Manage church content →
  Staff** by entering the person's sign-in email and choosing their branch,
  or "Every branch (HQ admin)" for an HQ admin, with **Super admin** switched
  on for another super admin. Adding someone already on the list changes
  their access. Access starts when they next open the app.
- The church always keeps a super admin: the last one can't be removed or
  demoted, in the app or the dashboard, until someone else is appointed.
- HQ admins choose **All branches** on news and sermons, **Show to every
  branch** on events, or **Church-wide** on ministries. Branch staff's forms
  are fixed to their own branch.
- Ministry staff can open a ministry's form and tap **See who has joined**.

Only confirmed email addresses count as staff, so keep email confirmation
switched on in Supabase Auth. Uploads accept JPEG, PNG, WebP or HEIC photos up
to 10 MB (resized on the phone first), and MP3, M4A, AAC, WAV or OGG audio up
to 50 MB. Storage is public: anything uploaded can be opened by its link.

The sections below describe the same fields for anyone working in the
Supabase dashboard instead.

### Publish news

Add the approved story to **Table Editor → news**:

- `title`, `subtitle`, `summary` and `body`: the church's actual copy.
- `branch_id`: one branch, or empty for all branches.
- `published_at`: publication time; future-dated stories stay hidden.
- `image_paths`: paths uploaded to **Storage → news**, or HTTPS image URLs.

The feed shows the newest 50 published stories. Optional fields may be empty;
the app does not invent content to fill them.

### Publish ministries

In **Table Editor → ministries**, enter `name`, `focus`, `about`, `meets`,
`venue`, optional `image_paths` from **Storage → ministries**, and `sort_order`.
Set `branch_id` for a branch ministry, or leave it empty for a church-wide one.
`members_label` is an optional staff-maintained figure, not a calculated count.
Leave it empty unless the church has supplied a verified figure.

Memberships are stored in `ministry_members`; dashboard staff can review the
`ministry_signups` view. The app changes its Joined status after a successful
save. Failed reads or writes do not create a successful membership in the UI.

### Add members to ministries automatically

After signing in, members are asked once for their date of birth, gender,
marital status and whether they're a student. Every answer is optional, they
can skip, and they can change them later under **Account → About you**.

In a ministry's form, staff switch on **Add members who qualify** and set at
least one rule: an age range, men or women, the marital statuses that
qualify, or students or not. Members who meet every rule (in the ministry's
branch, or any branch for a church-wide one) are added straight away, and
again whenever their details, branch or age change; the app checks each time
it opens. Members added this way who stop qualifying are taken out, but
memberships people chose themselves are never removed. A member who leaves a
ministry isn't added back unless they join it again themselves.

In the dashboard, the rules are the `ministries` columns `auto_assign`,
`min_age`, `max_age`, `for_gender`, `for_marital_statuses` and
`for_students`; `ministry_members.added_automatically` marks automatic
memberships.

### Ministries that approve their members

For ministries such as Media or Choir, staff switch on **Leader approves new
members** in the ministry's form and add its leaders by the email they sign in
with. Leaders needn't be staff: they answer requests to join that ministry and
nothing else. Until a ministry has leaders, the staff who manage it answer.
A ministry that approves its members can't also add them automatically.

Members tap **Ask to join** and see **Requested** until a leader answers; they
can withdraw a request that hasn't been answered. Leaders are told when they
open the app that requests are waiting, and answer them under **Account →
Join requests**, seeing each person's name and branch only. Approving adds
the member; declining is shown to the member, who can ask again later.
Members can't add themselves to these ministries any other way: the database
refuses it.

In the dashboard, the switch is `ministries.needs_approval`; leaders are in
`ministry_leaders` and requests in `ministry_requests`.

### Publish events

In **Table Editor → events**, set the host `branch_id`, `title`, `starts_at`,
and preferably `ends_at`. Tick `for_all_branches` for an event every branch
should see. Optional fields are `host`, `address`, `description`, `phone`,
`email`, `website` and `image_paths` from **Storage → events**. Enter real UTC
timestamps (Ghana uses UTC). An event without an end time is assumed to last
three hours. A live badge comes only from the host branch's checked stream.

**Remind Me** schedules a notification one hour before an event, or at its
start if less than an hour remains. Permission is requested on first use.
Reminders are local to that device, survive app restarts, and are capped at 60.
Android uses inexact scheduling; delivery depends on device notification and
battery settings. Opening or refreshing Events reconciles saved reminders with
the backend, including changed times and deleted events. Offline devices keep
their previous schedule until a successful refresh. This is not server push.
See the notification plugin's [platform limitations](https://pub.dev/packages/flutter_local_notifications/versions/22.3.2).

### Publish sermons

Upload actual recordings to **Storage → sermons**. Add rows to `sermons` with
`branch_id` (empty for a sermon every branch hears), `title`, `preacher`,
`preached_on`, `audio_path`, and optional
`description` and `duration_seconds`. `audio_path` accepts a bucket path or an
HTTPS audio URL. Storage is public; do not upload private material there.
Confirm storage and bandwidth limits in your Supabase project.

## Live streams

Each streaming branch needs its actual YouTube `UC...` channel ID in
`branches.youtube_channel_id`. The function discovers public streams from that
channel; no event-specific video link is needed. Public videos must permit
embedding. Channel discovery uses a live-playlist convention with an uploads
fallback; it is not a guarantee of discovery for every channel. Verify each
branch during a real broadcast before enabling it in production.

1. Enable YouTube Data API v3 in Google Cloud; create an API-restricted key.
2. Deploy [check-live-streams](supabase/functions/check-live-streams/index.ts)
   to Supabase with JWT verification disabled **only for this function**.
   It independently requires the `x-cron-secret` header.
3. Set Edge Function secrets `YOUTUBE_API_KEY` and a strong random `CRON_SECRET`.
   Missing or incorrect cron credentials reject requests before any API calls.
4. In **Supabase Vault**, set `project_url` to your project's HTTPS URL and
   `live_stream_cron_secret` to the exact same value as `CRON_SECRET`.
5. Run [live_streams_cron.sql](supabase/live_streams_cron.sql). It reads Vault,
   not a credential hardcoded in the scheduled SQL. See
   [Supabase's scheduling guide](https://supabase.com/docs/guides/functions/schedule-functions).

Check `live_streams.error` and the function logs. Quota consumption depends on
channel count, frequency and fallback calls; monitor it in Google Cloud.
Unscheduled streams may take up to 30 minutes to be discovered. Around listed
events the checker polls more often. Readings older than 20 minutes are no
longer displayed as live. Private and unlisted streams are not supported.

## Authentication

Email sign-in uses Supabase Auth. Configure production email delivery,
confirmation URLs and the recovery flow before release. Register
`io.supabase.cccapp://login-callback/` under **Authentication → URL Configuration**.

Social buttons are hidden by default. Enable and test each provider in
Supabase, then set `SOCIAL_SIGN_IN=google,apple` (or `facebook`) in `.env` to
show only the providers you actually support. This flag does not configure
providers in Supabase. A full app rebuild picks up environment changes.

## Google Maps

Enable Places API (New), Routes API and billing, then set
`GOOGLE_MAPS_API_KEY` in `.env`. Limit the key to those APIs. The current app
calls REST endpoints directly; API restrictions alone do not make a bundled
key secret. Resolve application restrictions or deploy an authenticated proxy
with rate limits before public distribution. Verify the chosen restrictions
against the app's requests, and configure quotas and billing alerts.

The official `branches` table supplies Google Place IDs. Branches without a
Place ID appear in the picker but cannot show a Maps card. Photos retain
credits; Maps attribution must stay visible. Routes failure falls back to
straight-line distance. Review current Google display and caching requirements
before release; the present directory caches results on the phone for 24 hours.

## Development and verification

```sh
flutter pub get
flutter analyze
flutter test
node --test test/check_live_streams_test.mjs
(cd supabase/tests && npm install && npm test)
flutter build apk --debug
```

The last test checks the staff permissions in `staff.sql`, the ministry
matching in `ministry_matching.sql` and the approvals in
`ministry_approval.sql` against a local PostgreSQL; see
[supabase/tests](supabase/tests/README.md).

The app icons are generated from the church logo in `assets/launcher/`
(on the welcome screen's warm night, adaptive on Android 8+). The logo's
lettering is white, so it needs a dark background there; inside the app,
light screens use `assets/images/church_logo_light.png`, whose lettering is
dark. After changing the icons, run
`dart run flutter_launcher_icons`.

A hot restart cannot register new native plugins. Stop the app and rebuild it
after changing audio, notifications or other native dependencies.

For Android release, copy `android/key.properties.example` to
`android/key.properties` and configure the church-owned upload keystore.
Missing signing settings now fail the release build instead of using a debug
key. Do not commit keystores or passwords. Then build with
`flutter build appbundle --release`.

See [PRODUCTION.md](PRODUCTION.md) for release gates and the verified backend
state. A successful debug build is not proof that a store release is ready.
