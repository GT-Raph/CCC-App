# Release verification

## Connected backend, checked 14 October 2026

Read-only REST checks using the configured publishable key found:

| Table | State |
| --- | --- |
| branches | Accessible, 16 rows |
| news | Missing (`PGRST205`) |
| ministries | Missing (`PGRST205`) |
| ministry_members | Missing (`PGRST205`) |
| events | Accessible, 0 public rows |
| sermons | Accessible, 0 public rows |
| live_streams | Accessible, 0 public rows |

These checks did not modify backend data or inspect private member records.
Run `supabase/content.sql`, then `supabase/staff.sql`, on the connected project
and add the first church-wide admin (README, "Posting from the app"). The app
intentionally displays no fabricated content while empty.

`staff.sql` was tested locally against PostgreSQL (PGlite) with stand-ins for
Supabase's `auth` and `storage` schemas: branch staff limited to their branch,
church-wide-only actions, unconfirmed emails, and members and guests denied.
That is not a test of the deployed project.

## Required before public release

- Apply the content and staff migrations; test RLS using two different member
  accounts. Confirm neither account can read or change the other's
  memberships/profile, and neither guests nor ordinary members can publish
  content or upload media.
- Test staff access with real accounts: a branch staff member can post and
  upload only for their branch, never for every branch, and cannot see the
  Staff screen; an HQ admin can post church-wide news, sermons, ministries and
  all-branch events and add or remove staff; removed staff are
  refused at once and lose the staff buttons after reopening the app. Upload a
  real photo and a real sermon file.
- Review branch names, Google Place IDs and duplicate listings with church staff.
- Upload genuine news, events, ministry details and sermon recordings. Verify
  branch-specific and church-wide visibility on actual accounts.
- Configure and test email confirmation, password recovery and sign-out on
  devices. The current recovery email action still needs a verified destination
  where members can set a new password. Do not enable untested OAuth providers.
- Deploy and authenticate the live-check function and Vault-backed schedule.
  Add real channel IDs; test live, upcoming, ended, quota-error and embedding
  restrictions against each branch channel. Playlist-based discovery is a known
  reliability limitation and needs channel-specific verification.
- Protect the Maps REST key with supported restrictions or a server proxy;
  verify billing, quotas, Google attribution and allowed content caching.
- Configure the church-owned Android upload keystore and store signing. Release
  builds intentionally refuse debug signing. Prepare store metadata and a
  church-approved privacy policy/contact channel. (The launcher icons are
  already generated from the church logo; see README.)
- Build and test the signed Android release. On a real phone, test notification
  permission denied/allowed, background delivery, reboot, time changes and
  offline mode. Test audio with the screen off and after interruptions.
- Build and test iOS on macOS with valid signing; verify notifications, audio,
  Maps directions and authentication deep links there too.
- Complete store privacy disclosures and account deletion requirements for the
  actual features and data collection before submission.

Automated tests use isolated fixtures in `test/` and mocked network/device
services. They cannot verify deployed database policies, real push delivery,
Google billing, app-store approval or church ownership of media.
