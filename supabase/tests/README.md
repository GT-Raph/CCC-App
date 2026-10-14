# Database permission tests

`staff_rls_test.mjs` runs `../schema.sql` and `../staff.sql` in PGlite, a real
PostgreSQL build that runs inside Node, with small stand-ins for Supabase's
`auth` and `storage` schemas. It then signs in as a church-wide admin, branch
staff, an unconfirmed staff email, a member and a guest, and checks what each
may read, publish, upload and manage.

```sh
cd supabase/tests
npm install
npm test
```

It needs Node 20 or newer and touches no real Supabase project. Passing here
does not prove the deployed project matches; check that with real accounts
(see PRODUCTION.md).
