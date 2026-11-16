import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import { actAs, readSql, supabaseDb } from './supabase_stub.mjs';

const db = await supabaseDb('schema.sql', 'staff.sql', 'stream_settings.sql');
after(() => db.close());
const ids = {
  admin: '00000000-0000-0000-0000-000000000001',
  staff: '00000000-0000-0000-0000-000000000002',
  leader: '00000000-0000-0000-0000-000000000003',
  unconfirmed: '00000000-0000-0000-0000-000000000004',
  member: '00000000-0000-0000-0000-000000000005',
};
const branch = '10000000-0000-0000-0000-000000000001';
const other = '10000000-0000-0000-0000-000000000002';
const channel = `UC${'a'.repeat(22)}`;
await db.exec(`
  insert into public.branches (id, name, youtube_channel_id) values
    ('${branch}', 'First branch', '${channel}'), ('${other}', 'Other branch', null);
  insert into auth.users (id, email, email_confirmed_at) values
    ${Object.entries(ids).map(([name, id]) => `('${id}', '${name}@church.org', ${name === 'unconfirmed' ? 'null' : 'now()'})`).join(',')};
  insert into public.staff (email, branch_id, super_admin) values
    ('admin@church.org', null, true), ('staff@church.org', '${branch}', false);
  insert into public.branch_media_leaders (branch_id, email) values
    ('${branch}', 'leader@church.org'), ('${branch}', 'unconfirmed@church.org');
  insert into public.live_streams (branch_id, status, video_id, checked_at) values
    ('${branch}', 'live', 'old-stream', now());
`);
const as = actAs(db, ids);
const ok = (result) => assert.equal(result.error, undefined, result.error);
const denied = (result) => assert.ok(result.error || result.affected === 0, JSON.stringify(result));
const save = (target, value) => `select public.save_stream_channel('${target}', ${value === null ? 'null' : `'${value}'`})`;
const reading = JSON.stringify({ status: 'live', video_id: 'new-stream', checked_at: new Date().toISOString(), next_check_at: new Date().toISOString() });
const record = (revision) => `select public.record_stream_reading('${branch}', ${revision}, '${reading}'::jsonb) as saved`;

test('only confirmed assigned leaders and scoped staff can list and save channels', async () => {
  for (const who of ['leader', 'staff']) {
    const result = await as(who, 'select id from public.stream_settings_for_me()');
    ok(result);
    assert.deepEqual(result.rows, [{ id: branch }]);
    ok(await as(who, save(branch, '@church')));
    denied(await as(who, save(other, '@other')));
  }
  assert.equal((await as('admin', 'select id from public.stream_settings_for_me()')).rows.length, 2);
  ok(await as('admin', save(other, '@other')));
  for (const who of ['member', 'unconfirmed']) {
    assert.deepEqual((await as(who, 'select id from public.stream_settings_for_me()')).rows, []);
    denied(await as(who, save(branch, '@church')));
  }
  denied(await as('anon', save(branch, '@church')));
  denied(await as('anon', 'select * from public.stream_settings_for_me()'));
});

test('only branch staff can appoint or remove media leaders; repeated adds are safe', async () => {
  const add = (target) => `insert into public.branch_media_leaders values ('${target}', 'member@church.org') on conflict do nothing`;
  ok(await as('staff', [add(branch), add(branch)]));
  denied(await as('staff', add(other)));
  for (const who of ['leader', 'member', 'unconfirmed', 'anon']) {
    denied(await as(who, add(branch)));
    denied(await as(who, 'delete from public.branch_media_leaders'));
  }
  ok(await as('admin', add(other)));
  const removed = await as('staff', `delete from public.branch_media_leaders where email = 'leader@church.org'`);
  ok(removed);
  assert.equal(removed.affected, 1);
  assert.deepEqual((await as('leader', 'select * from public.branch_media_leaders')).rows, []);
});

test('the channel RPC grants no branch, content, staff or live-status editing rights', async () => {
  for (const statement of [
    `update public.branches set name = 'Hijacked' where id = '${branch}'`,
    `update public.branches set youtube_channel_id = '${channel}' where id = '${other}'`,
    `update public.live_streams set status = 'live'`,
    `insert into public.news (title, branch_id) values ('Forged', '${branch}')`,
    `insert into public.staff (email) values ('leader@church.org')`,
    record(0),
  ]) denied(await as('leader', statement));
});

test('invalid channel values cannot bypass the server validation', async () => {
  for (const value of ['https://evil.test/@church', 'youtube.com/watch?v=abc', 'UCbad', '@', '@has space', '@x/y']) {
    assert.match((await as('leader', save(branch, value))).error, /channel link/);
  }
});

test('changing or disconnecting clears old streams and increments the revision', async () => {
  for (const value of ['@church', null]) {
    const result = await as('leader', [save(branch, value), `select b.youtube_channel_id, b.youtube_channel_handle, b.youtube_channel_revision, s.status, s.video_id, s.checked_at, s.error from public.branches b join public.live_streams s on b.id=s.branch_id where b.id='${branch}'`]);
    ok(result);
    assert.deepEqual(result.rows[0], { youtube_channel_id: null, youtube_channel_handle: value, youtube_channel_revision: 1, status: 'offline', video_id: null, checked_at: null, error: null });
  }
  const same = await as('leader', [save(branch, channel), `select video_id from public.live_streams where branch_id='${branch}'`]);
  assert.equal(same.rows[0].video_id, 'old-stream');
});

test('only the service role can record readings, and stale channel revisions are discarded', async () => {
  const result = await as('owner', [
    save(branch, '@church'), // owner has no auth identity, set one first below
  ]);
  assert.ok(result.error);
  const changed = await as('leader', [
    save(branch, '@church'),
    'set local role service_role', record(0), record(1),
    'reset role', `select video_id from public.live_streams where branch_id='${branch}'`,
  ]);
  ok(changed);
  assert.equal(changed.all[2][0].saved, false);
  assert.equal(changed.all[3][0].saved, true);
  assert.equal(changed.rows[0].video_id, 'new-stream');
  const disconnected = await as('leader', [save(branch, null), 'set local role service_role', record(0), record(1)]);
  ok(disconnected);
  assert.equal(disconnected.rows[0].saved, false);
});

test('revoked access applies immediately and rerunning the migration preserves settings', async () => {
  const revoked = await as('owner', [
    `delete from public.branch_media_leaders where email='leader@church.org'`,
    'set local role authenticated',
    `select set_config('request.jwt.claim.sub', '${ids.leader}', true)`,
    save(branch, '@church'),
  ]);
  denied(revoked);
  await db.exec(readSql('stream_settings.sql'));
  assert.equal((await db.query(`select youtube_channel_id from public.branches where id='${branch}'`)).rows[0].youtube_channel_id, channel);
});
