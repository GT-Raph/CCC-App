// User-role journeys against an isolated PostgreSQL database. No live accounts.
// Run independently: node --test supabase/tests/user_journeys_test.mjs
import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import { actAs, supabaseDb } from './supabase_stub.mjs';

const db = await supabaseDb(
  'schema.sql', 'staff.sql', 'ministry_matching.sql',
  'ministry_approval.sql', 'ministry_rules.sql',
);
after(() => db.close());

const ids = {
  staff: '00000000-0000-0000-0000-000000000001',
  leader: '00000000-0000-0000-0000-000000000002',
  member: '00000000-0000-0000-0000-000000000003',
  other: '00000000-0000-0000-0000-000000000004',
};
const branch = '10000000-0000-0000-0000-000000000001';
const choir = '20000000-0000-0000-0000-000000000001';
const youth = '20000000-0000-0000-0000-000000000002';
const otherMinistry = '20000000-0000-0000-0000-000000000003';

await db.exec(`
  insert into public.branches (id, name) values ('${branch}', 'Test branch');
  insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data) values
    ('${ids.staff}', 'staff@example.org', now(), '{}'),
    ('${ids.leader}', 'leader@example.org', now(), '{}'),
    ('${ids.member}', 'member@example.org', now(), '{"branch_id":"${branch}"}'),
    ('${ids.other}', 'other@example.org', now(), '{}');
  insert into public.staff (email, branch_id) values ('staff@example.org', '${branch}');
  insert into public.ministries (id, branch_id, name, needs_approval) values
    ('${choir}', '${branch}', 'Test choir', true),
    ('${youth}', '${branch}', 'Test youth', false),
    ('${otherMinistry}', '${branch}', 'Other ministry', true);
  insert into public.ministry_leaders (ministry_id, email) values
    ('${choir}', 'leader@example.org'), ('${youth}', 'leader@example.org'),
    ('${otherMinistry}', 'other@example.org');
  insert into public.member_details (user_id, birth_date, gender, student) values
    ('${ids.member}', (current_date - interval '22 years')::date, 'female', true);
`);

const as = actAs(db, ids);
// Switch roles within one rolled-back transaction to exercise a whole journey.
const signIn = who => [
  'reset role',
  'set local role authenticated',
  `select set_config('request.jwt.claim.sub', '${ids[who]}', true)`,
];
const expectSuccess = result => assert.equal(result.error, undefined);

test('staff can add a new leader using the app service upsert', async () => {
  // AdminService.addLeader uses default .upsert (merge duplicates), not insert.
  const result = await as('staff', `
    insert into public.ministry_leaders (ministry_id, email)
    values ('${choir}', 'newleader@example.org')
    on conflict (ministry_id, email) do update
      set ministry_id = excluded.ministry_id, email = excluded.email
    returning email
  `);
  expectSuccess(result);
  assert.equal(result.rows[0].email, 'newleader@example.org');
});

test('staff can safely add an existing leader again using the app service upsert', async () => {
  const result = await as('staff', `
    insert into public.ministry_leaders (ministry_id, email)
    values ('${choir}', 'leader@example.org')
    on conflict (ministry_id, email) do update
      set ministry_id = excluded.ministry_id, email = excluded.email
    returning email
  `);
  expectSuccess(result);
  assert.equal(result.rows[0].email, 'leader@example.org');
});

test('control: responsible staff can insert a leader without requesting update access', async () => {
  const result = await as('staff', `
    insert into public.ministry_leaders (ministry_id, email)
    values ('${choir}', 'newleader@example.org') returning email
  `);
  expectSuccess(result);
  assert.equal(result.rows[0].email, 'newleader@example.org');
});

test('control: ignoring duplicates permits adding a leader twice without update access', async () => {
  const add = `insert into public.ministry_leaders (ministry_id, email)
    values ('${choir}', 'newleader@example.org')
    on conflict (ministry_id, email) do nothing`;
  const result = await as('staff', [
    add,
    add,
    `select email from public.ministry_leaders
      where ministry_id = '${choir}' and email = 'newleader@example.org'`,
  ]);
  expectSuccess(result);
  assert.deepEqual(result.rows, [{ email: 'newleader@example.org' }]);
});

test('member asks, leader approves, member sees membership and leaves', async () => {
  const result = await as('member', [
    `select public.request_to_join('${choir}')`,
    ...signIn('leader'),
    `select user_id from public.ministry_requests_for('${choir}')`,
    `select public.answer_ministry_request('${choir}', '${ids.member}', true)`,
    ...signIn('member'),
    `select ministry_id from public.ministry_members where ministry_id = '${choir}'`,
    `delete from public.ministry_members where ministry_id = '${choir}'`,
    `select ministry_id from public.ministry_members where ministry_id = '${choir}'`,
  ]);
  expectSuccess(result);
  assert.deepEqual(result.all[4], [{ user_id: ids.member }]);
  assert.deepEqual(result.all[9], [{ ministry_id: choir }]);
  assert.deepEqual(result.rows, []);
});

test('non-staff leader sets requirements, member is matched, leaving is remembered', async () => {
  const result = await as('leader', [
    'select * from public.staff_role()',
    'select id from public.ministries_for_rules() order by id',
    `select public.save_ministry_rules('${youth}', true, 18, 35, 'female', '{}', true, false)`,
    ...signIn('member'),
    `select ministry_id from public.ministry_members where ministry_id = '${youth}'`,
    `delete from public.ministry_members where ministry_id = '${youth}'`,
    'select * from public.match_my_ministries()',
    `select ministry_id from public.ministry_members where ministry_id = '${youth}'`,
  ]);
  expectSuccess(result);
  assert.deepEqual(result.all[0], [], 'Leader has no staff role.');
  assert.deepEqual(result.all[1], [{ id: choir }, { id: youth }]);
  assert.deepEqual(result.all[6], [{ ministry_id: youth }]);
  assert.deepEqual(result.rows, [], 'Leaving must not be undone by matching.');
});

test('a leader of another ministry cannot approve this member request', async () => {
  const result = await as('member', [
    `select public.request_to_join('${choir}')`,
    ...signIn('other'),
    `select public.answer_ministry_request('${choir}', '${ids.member}', true)`,
  ]);
  assert.match(result.error, /Only the ministry's leaders/);
});
