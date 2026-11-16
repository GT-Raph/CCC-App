// Runs every script up to account_deletion.sql in PGlite, then checks that a
// member can delete their own account and everything tied to it, and only
// theirs. See README.md in this folder.
import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import { actAs, readSql, supabaseDb } from './supabase_stub.mjs';

const db = await supabaseDb(
  'schema.sql',
  'staff.sql',
  'ministry_matching.sql',
  'ministry_approval.sql',
  'ministry_rules.sql',
  'stream_settings.sql',
  'account_deletion.sql',
);
after(() => db.close());
// Running twice must be safe.
await db.exec(readSql('account_deletion.sql'));

const ids = {
  admin: '00000000-0000-0000-0000-000000000001',
  secondAdmin: '00000000-0000-0000-0000-000000000002',
  staff: '00000000-0000-0000-0000-000000000003',
  ama: '00000000-0000-0000-0000-000000000004',
  kofi: '00000000-0000-0000-0000-000000000005',
};
const botwe = '10000000-0000-0000-0000-000000000001';
const choir = '30000000-0000-0000-0000-000000000001';
const ushers = '30000000-0000-0000-0000-000000000002';

await db.exec(`
  insert into public.branches (id, name) values ('${botwe}', 'CCC Botwe');
  insert into auth.users (id, email, email_confirmed_at) values
    ${Object.entries(ids).map(([name, id]) => `('${id}', '${name}@church.org', now())`).join(',')};
  insert into public.staff (email, branch_id, super_admin) values
    ('admin@church.org', null, true), ('staff@church.org', '${botwe}', false);
  insert into public.ministries (id, name, branch_id, needs_approval, sort_order) values
    ('${choir}', 'Choir', '${botwe}', true, 1), ('${ushers}', 'Ushers', '${botwe}', false, 2);
  insert into public.ministry_leaders (ministry_id, email) values
    ('${choir}', 'staff@church.org'), ('${choir}', 'ama@church.org');
  insert into public.branch_media_leaders (branch_id, email) values ('${botwe}', 'staff@church.org');
  insert into public.member_details (user_id, birth_date, gender) values
    ('${ids.ama}', '1990-04-01', 'female'), ('${ids.kofi}', '1985-02-11', 'male');
  insert into public.ministry_members (ministry_id, user_id) values
    ('${ushers}', '${ids.ama}'), ('${ushers}', '${ids.kofi}');
  insert into public.ministry_requests (ministry_id, user_id) values ('${choir}', '${ids.kofi}');
`);

const as = actAs(db, ids);
const ok = (result) => assert.equal(result.error, undefined, result.error);
const count = (table, where) => `select count(*)::int as n from ${table} where ${where}`;
const remove = 'select public.delete_my_account()';

/** Deletes [who]'s account as them, then counts as the database owner. */
const deleteAs = (who, checks) => as('owner', [
  `set local role authenticated`,
  `select set_config('request.jwt.claim.sub', '${ids[who]}', true)`,
  remove,
  `reset role`,
  ...checks,
]);
const counts = (result, n) => result.all.slice(-n).map((rows) => rows[0].n);

test('a member deletes their account and everything tied to it', async () => {
  const result = await deleteAs('ama', [
    count('auth.users', `id = '${ids.ama}'`),
    count('public.profiles', `id = '${ids.ama}'`),
    count('public.member_details', `user_id = '${ids.ama}'`),
    count('public.ministry_members', `user_id = '${ids.ama}'`),
    count('public.ministry_opt_outs', `user_id = '${ids.ama}'`),
    count('public.ministry_leaders', `email = 'ama@church.org'`),
  ]);
  ok(result);
  assert.deepEqual(counts(result, 6), [0, 0, 0, 0, 0, 0]);
});

test("another member's data is left alone", async () => {
  const result = await deleteAs('ama', [
    count('auth.users', `id = '${ids.kofi}'`),
    count('public.member_details', `user_id = '${ids.kofi}'`),
    count('public.ministry_members', `user_id = '${ids.kofi}'`),
    count('public.ministry_requests', `user_id = '${ids.kofi}'`),
  ]);
  ok(result);
  assert.deepEqual(counts(result, 4), [1, 1, 1, 1]);
});

test('staff lose their appointments with their account; church content stays', async () => {
  const result = await deleteAs('staff', [
    count('public.staff', `email = 'staff@church.org'`),
    count('public.ministry_leaders', `email = 'staff@church.org'`),
    count('public.branch_media_leaders', `email = 'staff@church.org'`),
    count('public.ministries', `branch_id = '${botwe}'`),
  ]);
  ok(result);
  assert.deepEqual(counts(result, 4), [0, 0, 0, 2]);
});

test('the only super admin is asked to appoint another first', async () => {
  const refused = await as('admin', remove);
  assert.match(refused.error ?? '', /only super admin/);

  const allowed = await as('owner', [
    `insert into public.staff (email, branch_id, super_admin) values ('secondadmin@church.org', null, true)`,
    `set local role authenticated`,
    `select set_config('request.jwt.claim.sub', '${ids.admin}', true)`,
    remove,
    `reset role`,
    count('auth.users', `id = '${ids.admin}'`),
    count('public.staff', `super_admin`),
  ]);
  ok(allowed);
  assert.deepEqual(counts(allowed, 2), [0, 1]);
});

test('guests cannot call it', async () => {
  const result = await as('anon', remove);
  assert.match(result.error ?? '', /permission denied/);
});
