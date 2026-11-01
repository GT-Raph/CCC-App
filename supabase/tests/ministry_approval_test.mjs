// Runs the scripts up to ministry_approval.sql in PGlite, then checks that
// ministries which approve their members can only be joined through a
// leader's yes. See README.md in this folder.
import assert from 'node:assert/strict';
import { actAs, readSql, supabaseDb } from './supabase_stub.mjs';

const db = await supabaseDb(
  'schema.sql',
  'staff.sql',
  'ministry_matching.sql',
  'ministry_approval.sql',
);
// Running twice must be safe.
await db.exec(readSql('ministry_approval.sql'));

// --- Test data (as the database owner) ---------------------------------------
const ids = {
  admin: '00000000-0000-0000-0000-00000000000a',
  botweStaff: '00000000-0000-0000-0000-00000000000b',
  westlandStaff: '00000000-0000-0000-0000-00000000000c',
  leader: '00000000-0000-0000-0000-00000000000d',
  unconfirmedLeader: '00000000-0000-0000-0000-00000000000e',
  ama: '00000000-0000-0000-0000-00000000000f',
  kofi: '00000000-0000-0000-0000-000000000010',
};
const botwe = '10000000-0000-0000-0000-000000000001';
const westland = '10000000-0000-0000-0000-000000000002';
const choir = '30000000-0000-0000-0000-000000000001';
const media = '30000000-0000-0000-0000-000000000002';
const ushers = '30000000-0000-0000-0000-000000000003';

await db.exec(`
  insert into public.branches (id, name) values
    ('${botwe}', 'CCC Botwe'), ('${westland}', 'CCC Westland');
  insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data) values
    ('${ids.admin}', 'admin@church.org', now(), '{"full_name":"Grace Admin"}'),
    ('${ids.botweStaff}', 'media@botwe.org', now(), '{"full_name":"Kwame Media"}'),
    ('${ids.westlandStaff}', 'office@westland.org', now(), '{"full_name":"Efua Office"}'),
    ('${ids.leader}', 'choir@example.org', now(), '{"full_name":"Yaw Choir","branch_id":"${botwe}"}'),
    ('${ids.unconfirmedLeader}', 'new@example.org', null, '{}'),
    ('${ids.ama}', 'ama@example.org', now(), '{"full_name":"Ama Owusu","branch_id":"${botwe}"}'),
    ('${ids.kofi}', 'kofi@example.org', now(), '{"full_name":"Kofi Mensah","branch_id":"${westland}"}');
  insert into public.staff (email, branch_id, super_admin) values
    ('admin@church.org', null, true),
    ('media@botwe.org', '${botwe}', false),
    ('office@westland.org', '${westland}', false);
  insert into public.ministries (id, name, branch_id, needs_approval, sort_order) values
    ('${choir}', 'Choir', '${botwe}', true, 1),
    ('${media}', 'Media', null, true, 2),
    ('${ushers}', 'Ushers', '${botwe}', false, 3);
  insert into public.ministry_leaders (ministry_id, email) values
    ('${choir}', 'choir@example.org'),
    ('${choir}', 'new@example.org');
  insert into public.ministry_requests (ministry_id, user_id) values
    ('${choir}', '${ids.ama}'),
    ('${media}', '${ids.kofi}');
`);

const as = actAs(db, ids);
const signedIn = (who) => [
  'set local role authenticated',
  `select set_config('request.jwt.claim.sub', '${ids[who]}', true)`,
];
const ok = (r, label) => assert.ok(!r.error, `${label}: expected success, got ${r.error}`);
const denied = (r, label) =>
  assert.ok(r.error || r.affected === 0, `${label}: expected refusal, got ${JSON.stringify(r)}`);
let checks = 0;
const check = async (label, fn) => {
  await fn();
  checks++;
  console.log('ok -', label);
};

const requestsFor = (ministry) =>
  `select member, member_branch from public.ministry_requests_for('${ministry}')`;
const answer = (ministry, member, approve) =>
  `select public.answer_ministry_request('${ministry}', '${ids[member]}', ${approve})`;

await check('members cannot join a ministry that approves its members by themselves', async () => {
  denied(await as('ama', `insert into public.ministry_members (ministry_id) values ('${choir}')`), 'join Choir');
  ok(await as('ama', `insert into public.ministry_members (ministry_id) values ('${ushers}')`), 'join Ushers');
  denied(await as('ama', [
    `insert into public.ministry_members (ministry_id) values ('${ushers}')`,
    `update public.ministry_members set ministry_id = '${choir}' where ministry_id = '${ushers}'`,
  ]), 'move an Ushers membership into Choir');
});

await check('members ask to join, see their request, and can withdraw it', async () => {
  const asked = await as('kofi', [
    `select public.request_to_join('${choir}')`,
    `select public.request_to_join('${choir}')`,
    `select ministry_id, status from public.ministry_requests order by ministry_id`,
  ]);
  ok(asked, 'kofi asks twice');
  assert.deepEqual(asked.rows, [
    { ministry_id: choir, status: 'pending' },
    { ministry_id: media, status: 'pending' },
  ]);
  const withdrawn = await as('kofi', `delete from public.ministry_requests where ministry_id = '${media}'`);
  ok(withdrawn, 'kofi withdraws');
  assert.equal(withdrawn.affected, 1);
  denied(await as('kofi', `insert into public.ministry_requests (ministry_id) values ('${choir}')`), 'insert a request');
  denied(await as('kofi', `update public.ministry_requests set status = 'declined'`), 'change a request');
  assert.match((await as('kofi', `select public.request_to_join('${ushers}')`)).error ?? '', /doesn't take requests/);
  denied(await as('anon', `select public.request_to_join('${choir}')`), 'guest asks');
});

await check('leaders see who is asking, by name, for their own ministry only', async () => {
  assert.deepEqual((await as('leader', requestsFor(choir))).rows, [
    { member: 'Ama Owusu', member_branch: 'CCC Botwe' },
  ]);
  assert.equal((await as('leader', requestsFor(media))).rows.length, 0);
  assert.equal((await as('unconfirmedLeader', requestsFor(choir))).rows.length, 0);
  assert.equal((await as('kofi', requestsFor(choir))).rows.length, 0);
  // The table itself shows members only their own requests.
  assert.equal((await as('leader', 'select * from public.ministry_requests')).rows.length, 0);
});

await check('a leader\'s yes adds the member and closes the request', async () => {
  const r = await as('owner', [
    ...signedIn('leader'),
    answer(choir, 'ama', true),
    requestsFor(choir),
    'reset role',
    `select user_id from public.ministry_members where ministry_id = '${choir}'`,
  ]);
  ok(r, 'leader approves Ama');
  assert.deepEqual(r.all[3], []);
  assert.deepEqual(r.rows, [{ user_id: ids.ama }]);
  assert.match(
    (await as('leader', [answer(choir, 'ama', true), answer(choir, 'ama', true)])).error ?? '',
    /already been answered/,
  );
});

await check('a no is kept for the member, who can ask again', async () => {
  const r = await as('owner', [
    ...signedIn('leader'),
    answer(choir, 'ama', false),
    'reset role',
    ...signedIn('ama'),
    `select status from public.ministry_requests where ministry_id = '${choir}'`,
    // A declined request can't be withdrawn, only asked again.
    `delete from public.ministry_requests where ministry_id = '${choir}'`,
    `select public.request_to_join('${choir}')`,
    `select status from public.ministry_requests where ministry_id = '${choir}'`,
  ]);
  ok(r, 'leader declines, Ama asks again');
  assert.deepEqual(r.all[6], [{ status: 'declined' }]);
  assert.deepEqual(r.rows, [{ status: 'pending' }]);
});

await check('staff who manage a ministry can answer for it; other staff and members cannot', async () => {
  assert.equal((await as('botweStaff', requestsFor(choir))).rows.length, 1);
  ok(await as('botweStaff', answer(choir, 'ama', true)), 'Botwe staff approves');
  assert.equal((await as('westlandStaff', requestsFor(choir))).rows.length, 0);
  assert.match((await as('westlandStaff', answer(choir, 'ama', true))).error ?? '', /Only the ministry's leaders/);
  assert.match((await as('kofi', answer(choir, 'ama', true))).error ?? '', /Only the ministry's leaders/);
  // Media is church-wide: HQ admins answer it, branch staff don't.
  assert.equal((await as('admin', requestsFor(media))).rows.length, 1);
  assert.equal((await as('botweStaff', requestsFor(media))).rows.length, 0);
});

await check('those who answer requests see their ministries and how many are waiting', async () => {
  const counts = (rows) => rows.map((r) => [r.name, r.waiting]);
  assert.deepEqual(counts((await as('leader', 'select * from public.ministries_to_approve()')).rows), [['Choir', 1]]);
  assert.deepEqual(counts((await as('admin', 'select * from public.ministries_to_approve()')).rows), [['Choir', 1], ['Media', 1]]);
  assert.deepEqual(counts((await as('westlandStaff', 'select * from public.ministries_to_approve()')).rows), []);
  assert.deepEqual(counts((await as('kofi', 'select * from public.ministries_to_approve()')).rows), []);
});

await check('staff who manage a ministry choose its leaders; leaders and members cannot', async () => {
  const addLeader = (ministry, email) =>
    `insert into public.ministry_leaders (ministry_id, email) values ('${ministry}', '${email}')`;
  ok(await as('botweStaff', addLeader(choir, 'alto@example.org')), 'Botwe staff adds a Choir leader');
  denied(await as('botweStaff', addLeader(media, 'cam@example.org')), 'Botwe staff adds a Media leader');
  ok(await as('admin', addLeader(media, 'cam@example.org')), 'HQ admin adds a Media leader');
  denied(await as('leader', addLeader(choir, 'friend@example.org')), 'leader adds a leader');
  denied(await as('kofi', addLeader(choir, 'kofi@example.org')), 'member makes self leader');
  denied(await as('admin', addLeader(choir, 'Mixed@Example.org')), 'mixed-case email');
  assert.equal((await as('botweStaff', `select email from public.ministry_leaders where ministry_id = '${choir}'`)).rows.length, 2);
  assert.equal((await as('kofi', 'select email from public.ministry_leaders')).rows.length, 0);
  denied(await as('leader', `delete from public.ministry_leaders where ministry_id = '${choir}'`), 'leader removes leaders');
});

await check('a ministry approves its members or adds them automatically, not both', async () => {
  denied(
    await as('admin', `update public.ministries set auto_assign = true, for_gender = 'female' where id = '${media}'`),
    'approval and automatic',
  );
});

await check('ministries with requests and leaders can still be deleted', async () => {
  ok(await as('owner', `delete from public.ministries where id = '${choir}'`), 'delete Choir');
});

console.log(`\n${checks} checks passed`);
