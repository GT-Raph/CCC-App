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
  all-branch events but cannot see the Staff screen; a super admin can add,
  change and remove staff, and the last super admin can't be removed; removed
  staff are refused at once and lose the staff buttons after reopening the
  app. Upload a real photo and a real sermon file.
- Review branch names, Google Place IDs and duplicate listings with church staff.
- Upload genuine news, events, ministry details and sermon recordings. Verify
  branch-specific and church-wide visibility on actual accounts.
- Set up custom SMTP in Supabase (Supabase's own sender only reaches your
  team) and register `io.supabase.cccapp://login-callback/` as a redirect URL
  (README, "Authentication"). Then test on a phone: sign-up confirmation;
  **Forgot password?** emails a link that opens the app on **Choose a new
  password**, the new password works and the old one doesn't; **Cancel** there
  signs out; and sign-out. Do not enable untested OAuth providers.
- Run `account_deletion.sql`, then delete a throwaway member account and a
  throwaway staff account from the app. Check in the dashboard that the user,
  profile, member details, memberships, requests and staff/leader rows are
  gone, posted content remains, and the only super admin is refused.
- Run `stream_settings.sql` after schema and staff setup, then deploy and
  authenticate the updated live-check function and Vault-backed schedule.
  In the app, appoint branch media leaders and connect real channel links.
  Verify confirmed leaders can change only their own branches' channels, that
  revocation takes effect, and that changing/disconnecting clears the old stream.
  Test live, upcoming, ended, invalid handles, quota-error and embedding
  restrictions against each branch channel. Playlist-based discovery is a known
  reliability limitation and needs channel-specific verification.
- Protect the Maps REST key with supported restrictions or a server proxy;
  verify billing, quotas, Google attribution and allowed content caching.
  An "Android apps" restriction would block the app, because its REST calls
  don't send the Android package and certificate headers; restrict the key to
  Places API (New) and Routes API and set daily quotas instead.
- Configure the church-owned Android upload keystore and store signing. Release
  builds intentionally refuse debug signing. Prepare store metadata and a
  church-approved privacy policy/contact channel (drafts in `docs/`; see
  "Google Play submission" below). (The launcher icons are already generated
  from the church logo; see README.)
- Build and test the signed Android release. On a real phone, test notification
  permission denied/allowed, background delivery, reboot, time changes and
  offline mode. Test audio with the screen off and after interruptions.
- Build and test iOS on macOS with valid signing; verify notifications, audio,
  Maps directions and authentication deep links there too.
- Complete store privacy disclosures for the actual features and data
  collection before submission (see "Google Play submission" below).
- The privacy policy and store disclosures must cover the details members give
  for ministry matching (date of birth, gender, marital status, student): why
  they're asked, that only the member can see them, and that they're deleted
  with the account. Check the church's data-protection obligations (in Ghana,
  the Data Protection Act, 2012) before collecting them.
- Run `ministry_matching.sql` on the live project, then test with real
  accounts: a member who qualifies is added when they save their details; one
  who leaves isn't added back; staff saving a ministry's rules adds existing
  members; and no staff account can read `member_details`.
- Run `ministry_approval.sql` on the live project, then test with real
  accounts: a member can only ask to join a ministry that approves its
  members; its leader (who isn't staff) sees the request and approves or
  declines it; the member sees the answer; and a leader of one ministry sees
  nothing of another's requests.

- Run `ministry_rules.sql` after `ministry_approval.sql`, then check with real
  accounts that a confirmed leader can load and save existing requirements
  for their own ministry (including automatic ministries), cannot save another
  ministry's requirements or change its content, and loses access when removed.

## Google Play submission

Do these after the checks above pass.

1. **Developer account.** Register the account in the church's name. An
   organisation account needs a D-U-N-S number but can publish straight away.
   A personal account created after November 2023 must first run a closed test
   with at least 12 testers opted in for 14 days in a row before it can apply
   for production.
2. **Web pages.** In `docs/privacy.html` and `docs/delete-account.html`,
   replace every `[church email address]`, have church leadership approve the
   privacy policy, and host both pages at public addresses (the church website
   or GitHub Pages). Play asks for both addresses.
3. **Upload key.** A church officer creates it on a church computer and keeps
   it; losing it or its password blocks future updates until Google resets it.

   ```sh
   keytool -genkey -v -keystore <safe folder>/ccc-upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   Copy `android/key.properties.example` to `android/key.properties`, fill in
   the path, both passwords and `keyAlias=upload`, and back up the `.jks` file
   and passwords somewhere other than that computer. Neither belongs in git.
4. **Build.** Raise the build number after `+` in `pubspec.yaml` for every
   upload (`1.0.0+1`, then `1.0.0+2`, ...), then run
   `flutter build appbundle --release`. Upload
   `build/app/outputs/bundle/release/app-release.aab` and accept Play App
   Signing, which keeps the key that signs what members install.
5. **App content** (Play Console > Policy > App content):
   - Privacy policy: the hosted `privacy.html` address.
   - Ads: none.
   - App access: the app needs an account for some features, so give reviewers
     a test member login (an ordinary member, not staff).
   - Target audience: choose ages that match the privacy policy's "Children"
     section; don't select under-13 groups unless the church means to.
   - Content rating: fill in the questionnaire.
   - Foreground service: declare **Media playback**, explain that sermons keep
     playing with the screen off and on the lock screen, and link a short
     screen recording of that.
   - Location is used only while the app is open, so no background-location
     declaration is needed.
6. **Data safety.** Suggested answers, to check against the approved privacy
   policy:
   - Collected: name, email address, user IDs; "Other info" (date of birth,
     gender, marital status, student; optional); approximate and precise
     location (optional, processed ephemerally, sent to Google Maps for
     routes); photos and audio files (staff uploads only). Branch and ministry
     membership can reveal religious belief; declaring "Religious or political
     beliefs" is the safer answer.
   - Purpose: app functionality and account management. Not shared with third
     parties; not used for ads or analytics.
   - Encrypted in transit: yes. Members can delete their account in the app
     and at the hosted `delete-account.html` address.
7. **Store listing.** App name, short description (up to 80 characters), full
   description, 512 x 512 icon, 1024 x 500 feature graphic, and at least two
   phone screenshots.
8. **Release.** Upload to **Internal testing** first and install it from Play
   on real phones before closed testing or production.

Automated tests use isolated fixtures in `test/` and mocked network/device
services. They cannot verify deployed database policies, real push delivery,
Google billing, app-store approval or church ownership of media.
