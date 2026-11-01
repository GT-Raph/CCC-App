// Runs schema.sql, staff.sql and ministry_matching.sql in PGlite, then checks
// that members' details stay private and that members are added to (and
// taken out of) the right ministries. See README.md in this folder.
import assert from 'node:assert/strict';
import { actAs, readSql, supabaseDb } from './supabase_stub.mjs';

const db = await supabaseDb('schema.sql', 'staff.sql', 'ministry_matching.sql');
// Running twice must be safe.
await db.exec(readSql('ministry_matching.sql'));

// --- Test data (as the database owner) ---------------------------------------
const ids = {
  admin: '00000000-0000-0000-0000-00000000000a',
  ama: '00000000-0000-0000-0000-00000000000b',
  kofi: '00000000-0000-0000-0000-00000000000c',
  esi: '00000000-0000-0000-0000-00000000000d',
};
const botwe = '10000000-0000-0000-0000-000000000001';
const westland = '10000000-0000-0000-0000-000000000002';
const ministry = {
  youth: '30000000-0000-0000-0000-000000000001',
  women: '30000000-0000-0000-0000-000000000002',
  couples: '30000000-0000-0000-0000-000000000003',
  students: '30000000-0000-0000-0000-000000000004',
  choir: '30000000-0000-0000-0000-000000000005',
};

/** The date of birth of someone who turned [years] a few days ago. */
const bornYearsAgo = (years) => {
  const day = new Date();
  day.setUTCFullYear(day.getUTCFullYear() - years);
  day.setUTCDate(day.getUTCDate() - 10);
  return day.toISOString().slice(0, 10);
};

await db.exec(`
  insert into public.branches (id, name) values
    ('${botwe}', 'CCC Botwe'), ('${westland}', 'CCC Westland');
  insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data) values
    ('${ids.admin}', 'admin@church.org', now(), '{"full_name":"Grace Admin"}'),
    ('${ids.ama}', 'ama@example.org', now(), '{"full_name":"Ama Owusu","branch_id":"${botwe}"}'),
    ('${ids.kofi}', 'kofi@example.org', now(), '{"full_name":"Kofi Mensah","branch_id":"${botwe}"}'),
    ('${ids.esi}', 'esi@example.org', now(), '{"full_name":"Esi Boateng","branch_id":"${westland}"}');
  insert into public.staff (email, branch_id, super_admin) values ('admin@church.org', null, true);
  insert into public.ministries
    (id, name, branch_id, auto_assign, min_age, max_age, for_gender, for_marital_statuses, for_students)
  values
    ('${ministry.youth}', 'Youth', null, true, 18, 35, null, '{}', null),
    ('${ministry.women}', 'Women', null, true, null, null, 'female', '{}', null),
    ('${ministry.couples}', 'Couples', '${botwe}', true, null, null, null, '{married}', null),
    ('${ministry.students}', 'Students', '${westland}', true, null, null, null, '{}', true),
    ('${ministry.choir}', 'Choir', null, false, null, null, null, '{}', null);
  insert into public.member_details (user_id, birth_date, gender, marital_status, student) values
    ('${ids.kofi}', '${bornYearsAgo(40)}', 'male', 'married', false),
    ('${ids.esi}', '${bornYearsAgo(30)}', 'female', 'married', true);
`);

const as = actAs(db, ids);
const ok = (r, label) => assert.ok(!r.error, `${label}: expected success, got ${r.error}`);
const denied = (r, label) =>
  assert.ok(r.error || r.affected === 0, `${label}: expected refusal, got ${JSON.stringify(r)}`);
let checks = 0;
const check = async (label, fn) => {
  await fn();
  checks++;
  console.log('ok -', label);
};

const amaDetails = (years = 25, marital = 'single') =>
  `insert into public.member_details (birth_date, gender, marital_status, student)
   values ('${bornYearsAgo(years)}', 'female', '${marital}', true)`;
const match = 'select name from public.match_my_ministries()';
const names = (rows) => rows.map((r) => r.name);
const myMinistries = `select m.name, mm.added_automatically
  from public.ministry_members mm join public.ministries m on m.id = mm.ministry_id
  order by m.name`;

await check('members keep their details to themselves', async () => {
  const own = await as('ama', [amaDetails(), 'select gender from public.member_details']);
  ok(own, 'ama saves her details');
  assert.deepEqual(own.rows, [{ gender: 'female' }]);
  denied(
    await as('ama', `insert into public.member_details (user_id, gender) values ('${ids.kofi}', 'female')`),
    'ama writes kofi\'s details',
  );
  denied(await as('ama', `update public.member_details set gender = 'female' where user_id = '${ids.kofi}'`), 'ama changes kofi\'s');
  // Not even a super admin can read them.
  assert.equal((await as('admin', 'select * from public.member_details')).rows.length, 0);
  denied(await as('anon', 'select * from public.member_details'), 'guest reads details');
});

await check('saving details joins the ministries a member qualifies for', async () => {
  const r = await as('ama', [amaDetails(), match, myMinistries]);
  ok(r, 'ama matches');
  // 25, female, single, a student at Botwe: not Couples (married), not
  // Students (Westland's), never Choir (doesn't add members).
  assert.deepEqual(names(r.all[1]), ['Women', 'Youth']);
  assert.deepEqual(r.rows, [
    { name: 'Women', added_automatically: true },
    { name: 'Youth', added_automatically: true },
  ]);
  // Nothing new the second time.
  const again = await as('ama', [amaDetails(), match, match]);
  assert.deepEqual(names(again.rows), []);
});

await check('a ministry for one branch matches only its members', async () => {
  // Both married; only Kofi attends Botwe, where Couples meets.
  assert.deepEqual(names((await as('kofi', match)).rows), ['Couples']);
  assert.deepEqual(names((await as('esi', match)).rows), ['Students', 'Women', 'Youth']);
});

await check('skipped details match nothing', async () => {
  const r = await as('ama', ['insert into public.member_details default values', match]);
  assert.deepEqual(names(r.rows), []);
});

await check('leaving is remembered, and joining again forgets it', async () => {
  const r = await as('ama', [
    amaDetails(),
    match,
    `delete from public.ministry_members where ministry_id = '${ministry.youth}'`,
    match,
    myMinistries,
    `insert into public.ministry_members (ministry_id) values ('${ministry.youth}')`,
    myMinistries,
  ]);
  ok(r, 'leave and rejoin');
  assert.deepEqual(names(r.all[3]), [], 'not added back after leaving');
  assert.deepEqual(names(r.all[4]), ['Women']);
  assert.deepEqual(r.rows, [
    { name: 'Women', added_automatically: true },
    { name: 'Youth', added_automatically: false },
  ]);
});

await check('no longer qualifying removes only automatic memberships', async () => {
  const r = await as('ama', [
    amaDetails(),
    match,
    // Joined by herself: one that adds members, one that doesn't.
    `insert into public.ministry_members (ministry_id) values ('${ministry.couples}'), ('${ministry.choir}')`,
    `update public.member_details set birth_date = '${bornYearsAgo(50)}'`,
    match,
    myMinistries,
  ]);
  ok(r, 'ama turns 50');
  assert.deepEqual(r.rows.map((row) => row.name), ['Choir', 'Couples', 'Women']);
});

await check('changing branch takes a member out of the old branch\'s ministries', async () => {
  // The app saves the branch in the account's details, and schema.sql's
  // trigger copies it to the profile.
  const asKofi = [
    'set local role authenticated',
    `select set_config('request.jwt.claim.sub', '${ids.kofi}', true)`,
  ];
  const r = await as('owner', [
    ...asKofi,
    match,
    'reset role',
    `update auth.users set raw_user_meta_data = '{"full_name":"Kofi Mensah","branch_id":"${westland}"}'
     where id = '${ids.kofi}'`,
    ...asKofi,
    match,
    myMinistries,
  ]);
  ok(r, 'kofi moves to Westland');
  assert.deepEqual(names(r.all[2]), ['Couples']);
  assert.deepEqual(r.rows, []);
});

await check('staff changing who a ministry is for adds members at once, without seeing details', async () => {
  const r = await as('admin', [
    `update public.ministries set auto_assign = true, for_gender = 'male' where id = '${ministry.choir}'`,
    `select member from public.signups_for_ministry('${ministry.choir}')`,
    'select * from public.member_details',
  ]);
  ok(r, 'admin edits Choir');
  assert.deepEqual(r.all[1], [{ member: 'Kofi Mensah' }]);
  assert.equal(r.rows.length, 0);
});

await check('a ministry that adds members needs at least one rule', async () => {
  denied(
    await as('admin', `update public.ministries set auto_assign = true where id = '${ministry.choir}'`),
    'auto_assign with no rules',
  );
  denied(
    await as('admin', `update public.ministries set min_age = 40, max_age = 30 where id = '${ministry.youth}'`),
    'ages the wrong way round',
  );
  denied(
    await as('admin', `update public.ministries set for_marital_statuses = '{engaged}' where id = '${ministry.couples}'`),
    'unknown marital status',
  );
});

await check('ministries and accounts with memberships can still be deleted', async () => {
  ok(await as('owner', [
    `insert into public.ministry_members (ministry_id, user_id) values ('${ministry.choir}', '${ids.esi}')`,
    `delete from public.ministries where id = '${ministry.choir}'`,
  ]), 'delete a ministry');
  ok(await as('owner', [
    `insert into public.ministry_members (ministry_id, user_id) values ('${ministry.choir}', '${ids.esi}')`,
    `delete from auth.users where id = '${ids.esi}'`,
  ]), 'delete an account');
});

await check('only the database matches everyone; guests match nothing', async () => {
  denied(await as('ama', 'select * from public.sync_ministry_members(null, null)'), 'member syncs everyone');
  denied(await as('anon', match), 'guest matches');
  denied(await as('ama', 'select * from public.ministry_opt_outs'), 'member reads opt-outs');
});

console.log(`\n${checks} checks passed`);
