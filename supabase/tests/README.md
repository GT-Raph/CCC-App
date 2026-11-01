# Database permission tests

`staff_rls_test.mjs` runs `../schema.sql` and `../staff.sql` in PGlite, a real
PostgreSQL build that runs inside Node, with small stand-ins for Supabase's
`auth` and `storage` schemas. It then signs in as a church-wide admin, branch
staff, an unconfirmed staff email, a member and a guest, and checks what each
may read, publish, upload and manage.

`ministry_matching_test.mjs` adds `../ministry_matching.sql` and checks that
members' details stay private, that members are added to the ministries whose
rules they meet (and only their branch's), that leaving is remembered, and
that automatic memberships, and only those, go when a member stops
qualifying.

`ministry_approval_test.mjs` adds `../ministry_approval.sql` and checks that
members can't join a ministry that approves its members by themselves, that
only its leaders and the staff who manage it see and answer its requests, and
that only those staff choose its leaders.

All three share the stand-ins in `supabase_stub.mjs`.

```sh
cd supabase/tests
npm install
npm test
```

It needs Node 20 or newer and touches no real Supabase project. Passing here
does not prove the deployed project matches; check that with real accounts
(see PRODUCTION.md).
