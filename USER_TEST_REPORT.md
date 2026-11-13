# User-journey test report

13 November 2026. Local checks only; no live accounts or production data changed.

Three agents were assigned guest/member, ministry-leader, and staff/admin
personas. All three stopped with an account usage-limit error before doing
their testing. The parent continued independently with local PostgreSQL
journeys, existing backend tests, and Dart analysis. This is not a completed
agent-driven UI test run.

## Confirmed finding

**High: staff cannot add ministry leaders through the current service request.**

The app's `AdminService.addLeader` (`lib/services/admin_service.dart:287`)
uses `.upsert()` with the default merge-duplicates behavior. The installed
PostgREST client confirms that default. The repository's schema explicitly
revokes UPDATE on `ministry_leaders` from authenticated users and grants
SELECT, INSERT, and DELETE (`supabase/ministry_approval.sql:32`).

An equivalent `INSERT ... ON CONFLICT DO UPDATE` fails with
`permission denied for table ministry_leaders`, even when the leader is new
and the staff member manages the correct branch. Adding the same leader again
also fails. A plain INSERT succeeds for that same user and ministry, isolating
the problem to the write shape rather than the assigned staff role.

User impact: the staff flow **Edit ministry → Leaders → Add leader** cannot
assign the leaders needed to manage membership requirements or join requests
against the checked schema. The live deployment has not been inspected.

Suggested fix: use `.upsert(..., ignoreDuplicates: true)` to preserve
idempotent assignment without granting UPDATE access. The equivalent
`ON CONFLICT DO NOTHING` control successfully adds the leader twice and keeps
one assignment. This report does not change the app implementation.

The existing tests missed this because widget tests fake `addLeader`, while
the existing SQL permission tests use plain INSERT rather than the service's
upsert. The new reproduction retains the two failing expectations.

## Results

| Check | Result |
| --- | --- |
| Existing staff, ministry matching, and approval/requirements database checks | 47 passed |
| Existing live-stream function tests | 2 passed |
| New user-role database journeys and controls | 5 passed; 2 failed for the single defect above |
| Dart analysis | No issues found |
| New agent-driven Flutter UI journeys | Blocked before execution |
| Full Flutter baseline rerun | Not executed; automatic approval review could not complete because of the account usage limit |

The new passing journeys cover a member requesting to join, a leader approving,
the member seeing their membership and leaving; a leader with no staff role
setting requirements, the member being matched, and leaving remaining respected;
and another ministry's leader being refused when trying to approve the request.
Two additional controls verify permitted leader inserts and duplicate handling.

## Reproduce

From the project root:

```sh
node --test supabase/tests/user_journeys_test.mjs
node --test test/check_live_streams_test.mjs
```

The first command currently exits with two failures. It uses an isolated
PostgreSQL instance and rolls back each journey. It is separate from the
existing `supabase/tests` npm test command so the new known failures are explicit.

## Remaining user testing

Once agent execution and Flutter approval review are available, run the three
personas through actual widget navigation on a small phone viewport: guest
login prompts and branch choice; member join/leave and failure recovery;
leader rules save/retry/discard and request decisions; staff form validation,
leader assignment, and branch boundaries. Rerun the full Flutter suite.

Live Supabase role accounts, device notifications, real audio playback,
authentication delivery, and native builds remain unverified by this run.
