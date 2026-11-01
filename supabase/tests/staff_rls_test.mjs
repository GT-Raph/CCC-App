// Runs supabase/schema.sql + staff.sql in PGlite (real Postgres in WASM) with
// stand-ins for Supabase's auth/storage schemas, then checks what each kind
// of account may do. See README.md in this folder.
import assert from 'node:assert/strict';
import { actAs, readSql, supabaseDb } from './supabase_stub.mjs';

const db = await supabaseDb('schema.sql', 'staff.sql');
// Running twice must be safe.
await db.exec(readSql('staff.sql'));

// --- Test data (as the database owner) ---------------------------------------
const ids = {
  admin: '00000000-0000-0000-0000-00000000000a',
  botweStaff: '00000000-0000-0000-0000-00000000000b',
  unconfirmed: '00000000-0000-0000-0000-00000000000c',
  member: '00000000-0000-0000-0000-00000000000d',
  hq: '00000000-0000-0000-0000-00000000000e',
};
const botwe = '10000000-0000-0000-0000-000000000001';
const westland = '10000000-0000-0000-0000-000000000002';
await db.exec(`
  insert into public.branches (id, name) values
    ('${botwe}', 'CCC Botwe'), ('${westland}', 'CCC Westland');
  insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data) values
    ('${ids.admin}', 'Admin@Church.org', now(), '{"full_name":"Grace Admin"}'),
    ('${ids.botweStaff}', 'media@botwe.org', now(), '{"full_name":"Kofi Media","branch_id":"${botwe}"}'),
    ('${ids.unconfirmed}', 'new@botwe.org', null, '{}'),
    ('${ids.member}', 'ama@example.org', now(), '{"full_name":"Ama Owusu","branch_id":"${botwe}"}'),
    ('${ids.hq}', 'hq@church.org', now(), '{"full_name":"Esi Mensah"}');
  insert into public.staff (email, branch_id, added_at) values
    ('admin@church.org', null, '2026-01-01'),
    ('hq@church.org', null, '2026-02-01'),
    ('media@botwe.org', '${botwe}', '2026-03-01'),
    ('new@botwe.org', '${botwe}', '2026-03-01');
  insert into public.news (id, title, branch_id) values
    ('20000000-0000-0000-0000-000000000001', 'Westland news', '${westland}');
  insert into public.ministries (id, name, branch_id) values
    ('30000000-0000-0000-0000-000000000001', 'Botwe Choir', '${botwe}'),
    ('30000000-0000-0000-0000-000000000002', 'Westland Choir', '${westland}');
  insert into public.ministry_members (ministry_id, user_id) values
    ('30000000-0000-0000-0000-000000000001', '${ids.member}'),
    ('30000000-0000-0000-0000-000000000002', '${ids.member}');
`);
// The staff above predate super admins; running staff.sql again upgrades them.
await db.exec(readSql('staff.sql'));

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

const news = (branch) =>
  `insert into public.news (title, branch_id) values ('Hello', ${branch ? `'${branch}'` : 'null'})`;

await check('an older database makes its first HQ admin the super admin', async () => {
  const admins = await db.query(
    `select email, super_admin from public.staff where branch_id is null order by email`);
  assert.deepEqual(admins.rows, [
    { email: 'admin@church.org', super_admin: true },
    { email: 'hq@church.org', super_admin: false },
  ]);
});

await check('the app can tell super admins from HQ admins', async () => {
  const admin = await as('admin', 'select * from public.staff_role()');
  assert.deepEqual(admin.rows, [{ branch_id: null, super_admin: true }]);
  const hq = await as('hq', 'select * from public.staff_role()');
  assert.deepEqual(hq.rows, [{ branch_id: null, super_admin: false }]);
  // App versions from before super admins still read staff_scope.
  const scope = await as('hq', 'select * from public.staff_scope()');
  assert.deepEqual(scope.rows, [{ branch_id: null }]);
  const member = await as('member', 'select * from public.staff_role()');
  assert.equal(member.rows.length, 0);
});

await check('church-wide admin can post church-wide and any-branch news', async () => {
  ok(await as('admin', news(null)), 'admin church-wide');
  ok(await as('admin', news(westland)), 'admin westland');
});

await check('branch staff can post only their own branch', async () => {
  ok(await as('botweStaff', news(botwe)), 'botwe staff own branch');
  denied(await as('botweStaff', news(westland)), 'botwe staff other branch');
  denied(await as('botweStaff', news(null)), 'botwe staff church-wide');
});

await check('members, guests and unconfirmed staff cannot post', async () => {
  denied(await as('member', news(botwe)), 'member');
  denied(await as('unconfirmed', news(botwe)), 'unconfirmed staff');
  denied(await as('anon', news(null)), 'guest');
});

await check('branch staff cannot edit or delete another branch\'s news', async () => {
  denied(
    await as('botweStaff', `update public.news set title = 'x' where title = 'Westland news'`),
    'update other branch',
  );
  denied(
    await as('botweStaff', `delete from public.news where title = 'Westland news'`),
    'delete other branch',
  );
  denied(
    await as('botweStaff', `update public.news set branch_id = '${botwe}' where title = 'Westland news'`),
    'move other branch news into own branch',
  );
  const moved = await as('admin', `update public.news set title = 'Edited' where title = 'Westland news'`);
  ok(moved, 'admin edits any branch');
  assert.equal(moved.affected, 1);
});

await check('staff see scheduled news; members do not', async () => {
  await db.exec(`insert into public.news (title, branch_id, published_at)
    values ('Next week', '${botwe}', now() + interval '7 days')`);
  const staff = await as('botweStaff', `select title from public.news where title = 'Next week'`);
  assert.equal(staff.rows.length, 1);
  const member = await as('member', `select title from public.news where title = 'Next week'`);
  assert.equal(member.rows.length, 0);
  const guest = await as('anon', `select title from public.news where title = 'Next week'`);
  assert.equal(guest.rows.length, 0);
});

await check('only church-wide admins post events for all branches', async () => {
  const event = (who, branch, all) =>
    as(who, `insert into public.events (title, branch_id, starts_at, for_all_branches)
      values ('Service', '${branch}', now() + interval '1 day', ${all})`);
  ok(await event('botweStaff', botwe, false), 'botwe staff own event');
  denied(await event('botweStaff', botwe, true), 'botwe staff all-branch event');
  denied(await event('botweStaff', westland, false), 'botwe staff other branch event');
  ok(await event('admin', westland, true), 'admin all-branch event');
});

await check('sermons follow the same branch rules', async () => {
  const sermon = (who, branch) =>
    as(who, `insert into public.sermons (title, branch_id, audio_path)
      values ('Faith', ${branch ? `'${branch}'` : 'null'}, 'botwe/faith.mp3')`);
  ok(await sermon('botweStaff', botwe), 'own branch sermon');
  denied(await sermon('botweStaff', westland), 'other branch sermon');
  denied(await sermon('member', botwe), 'member sermon');
  // Sermons for every branch are HQ admins' only.
  denied(await sermon('botweStaff', null), 'church-wide sermon by branch staff');
  ok(await sermon('admin', null), 'church-wide sermon by admin');
  await db.exec(`insert into public.sermons (id, title, branch_id, audio_path) values
    ('40000000-0000-0000-0000-000000000001', 'For every branch', null, 'all/one.mp3'),
    ('40000000-0000-0000-0000-000000000002', 'Botwe Sunday', '${botwe}', 'botwe/sun.mp3')`);
  const own = await as('botweStaff', `update public.sermons set title = 'x' where branch_id = '${botwe}'`);
  ok(own, 'branch staff edits own sermon');
  assert.equal(own.affected, 1);
  denied(
    await as('botweStaff', `update public.sermons set title = 'x' where branch_id is null`),
    'branch staff edits church-wide sermon',
  );
  denied(
    await as('botweStaff', `delete from public.sermons where branch_id is null`),
    'branch staff deletes church-wide sermon',
  );
  const everyone = await as('anon', `select title from public.sermons where branch_id is null`);
  assert.deepEqual(everyone.rows.map((r) => r.title), ['For every branch']);
  denied(
    await as('botweStaff', `update public.sermons set branch_id = null where branch_id = '${botwe}'`),
    'branch staff moves a sermon to every branch',
  );
});

await check('ministries: church-wide only for admins, branch for its staff', async () => {
  const add = (who, branch) =>
    as(who, `insert into public.ministries (name, branch_id) values ('Ushers', ${branch ? `'${branch}'` : 'null'})`);
  ok(await add('botweStaff', botwe), 'own branch ministry');
  denied(await add('botweStaff', null), 'church-wide ministry by branch staff');
  ok(await add('admin', null), 'church-wide ministry by admin');
});

await check('HQ admins who are not super admins still post church-wide', async () => {
  ok(await as('hq', news(null)), 'hq church-wide');
  ok(await as('hq', news(westland)), 'hq westland');
});

await check('only super admins manage staff', async () => {
  denied(await as('botweStaff', `insert into public.staff (email, branch_id) values ('x@y.org', '${botwe}')`), 'branch staff adds staff');
  denied(await as('member', `insert into public.staff (email) values ('me@example.org')`), 'member makes self admin');
  denied(await as('botweStaff', `update public.staff set branch_id = null where email = 'media@botwe.org'`), 'branch staff promotes self');
  denied(await as('hq', `insert into public.staff (email, branch_id) values ('x@westland.org', '${westland}')`), 'HQ admin adds staff');
  denied(await as('hq', `update public.staff set super_admin = true where email = 'hq@church.org'`), 'HQ admin makes self super admin');
  denied(await as('hq', `delete from public.staff where email = 'media@botwe.org'`), 'HQ admin removes staff');
  ok(await as('admin', `insert into public.staff (email, branch_id) values ('choir@westland.org', '${westland}')`), 'super admin adds staff');
  ok(await as('admin', `update public.staff set super_admin = true where email = 'hq@church.org'`), 'super admin appoints another');
  const list = await as('admin', `select email from public.staff order by email`);
  assert.equal(list.rows.length, 4);
  assert.equal((await as('hq', `select email from public.staff`)).rows.length, 0);
  assert.equal((await as('member', `select email from public.staff`)).rows.length, 0);
});

await check('the church always keeps a super admin', async () => {
  const lastOne = /at least one super admin/;
  assert.match((await as('admin', `delete from public.staff where email = 'admin@church.org'`)).error ?? '', lastOne);
  assert.match(
    (await as('admin', `update public.staff set super_admin = false where email = 'admin@church.org'`)).error ?? '',
    lastOne,
  );
  // Not even from the dashboard.
  assert.match((await as('owner', `delete from public.staff where email = 'admin@church.org'`)).error ?? '', lastOne);
  // Once someone else is a super admin, the first can step down.
  ok(await as('admin', [
    `update public.staff set super_admin = true where email = 'hq@church.org'`,
    `delete from public.staff where email = 'admin@church.org'`,
  ]), 'hand over to another super admin');
  // Removing branch staff is unaffected.
  ok(await as('admin', `delete from public.staff where email = 'media@botwe.org'`), 'remove branch staff');
});

await check('super admins are always church-wide', async () => {
  denied(
    await as('admin', `insert into public.staff (email, branch_id, super_admin) values ('x@botwe.org', '${botwe}', true)`),
    'branch super admin',
  );
});

await check('staff emails must be lower case', async () => {
  denied(await as('admin', `insert into public.staff (email) values ('Mixed@Church.org')`), 'mixed case email');
});

await check('ministry sign-ups: names for the staff who manage the ministry only', async () => {
  const botweList = await as('botweStaff',
    `select * from public.signups_for_ministry('30000000-0000-0000-0000-000000000001')`);
  ok(botweList, 'botwe signups');
  assert.deepEqual(botweList.rows.map((r) => r.member), ['Ama Owusu']);
  assert.equal(botweList.rows[0].member_branch, 'CCC Botwe');
  const westlandList = await as('botweStaff',
    `select * from public.signups_for_ministry('30000000-0000-0000-0000-000000000002')`);
  assert.equal(westlandList.rows.length, 0);
  const asMember = await as('member',
    `select * from public.signups_for_ministry('30000000-0000-0000-0000-000000000001')`);
  assert.equal(asMember.rows?.length ?? 0, 0);
  denied(await as('anon',
    `select * from public.signups_for_ministry('30000000-0000-0000-0000-000000000001')`), 'guest signups');
});

await check('uploads: staff into the church buckets only', async () => {
  const upload = (who, bucket) =>
    as(who, `insert into storage.objects (bucket_id, name) values ('${bucket}', 'a/b.jpg')`);
  ok(await upload('botweStaff', 'news'), 'staff news photo');
  ok(await upload('botweStaff', 'sermons'), 'staff sermon audio');
  denied(await upload('member', 'news'), 'member upload');
  denied(await upload('unconfirmed', 'events'), 'unconfirmed upload');
  await db.exec(`insert into storage.buckets (id, name, public) values ('avatars', 'avatars', false)`);
  denied(await upload('botweStaff', 'avatars'), 'staff into another bucket');
});

await check('bucket limits: photos and recordings only', async () => {
  const buckets = await db.query(`select id, allowed_mime_types, file_size_limit from storage.buckets order by id`);
  const byId = Object.fromEntries(buckets.rows.map((b) => [b.id, b]));
  assert.ok(byId.news.allowed_mime_types.includes('image/jpeg'));
  assert.equal(Number(byId.news.file_size_limit), 10 * 1024 * 1024);
  assert.ok(byId.sermons.allowed_mime_types.includes('audio/mpeg'));
  assert.ok(!byId.sermons.allowed_mime_types.some((t) => t.startsWith('image/')));
});

await check('members still read published content and manage their own joins', async () => {
  const read = await as('member', `select title from public.news where published_at <= now()`);
  ok(read, 'member reads news');
  ok(await as('member', `delete from public.ministry_members where user_id = '${ids.member}'`), 'member leaves');
});

console.log(`\n${checks} checks passed`);
