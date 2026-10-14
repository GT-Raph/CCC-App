// Runs supabase/functions/check-live-streams/index.ts under Node (24+, which
// runs TypeScript directly) with fake Supabase and YouTube services.
//   node --test test/check_live_streams_test.mjs
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import assert from 'node:assert/strict';
import { after, before, beforeEach, test } from 'node:test';

const MINUTE = 60_000;
const now = Date.now();
const iso = (t) => new Date(t).toISOString();
const channel = (letter) => 'UC' + letter.repeat(22);

// The function as a module: its Supabase import replaced by the fake below.
const source = readFileSync(
  fileURLToPath(
    new URL('../supabase/functions/check-live-streams/index.ts', import.meta.url),
  ),
  'utf8',
).replace(
  'import { createClient } from "npm:@supabase/supabase-js@2";',
  'const { createClient } = globalThis.__fakeSupabase;',
);
const workDir = mkdtempSync(join(tmpdir(), 'check-live-streams-'));
writeFileSync(join(workDir, 'fn.ts'), source);

let tables;
let upserts;
let youtubeCalls;
let env;
let handler;

function query(table) {
  const result = { data: tables[table], error: null };
  const builder = {
    select: () => builder,
    not: () => builder,
    gte: () => builder,
    lte: () => builder,
    upsert: (rows, options) => {
      upserts.push({ rows, options });
      return Promise.resolve({ data: null, error: null });
    },
    then: (resolve, reject) => Promise.resolve(result).then(resolve, reject),
  };
  return builder;
}

// Channel letter -> the videos YouTube reports for it.
const videos = {
  a: [
    {
      id: 'a-live',
      snippet: { title: 'Sunday Service', liveBroadcastContent: 'live' },
      liveStreamingDetails: { actualStartTime: iso(now - 20 * MINUTE) },
    },
    { id: 'a-old', snippet: { title: 'Last week', liveBroadcastContent: 'none' } },
  ],
  b: [{ id: 'b-upload', snippet: { title: 'An upload', liveBroadcastContent: 'none' } }],
  e: [{
    id: 'e-soon',
    snippet: { title: 'Starting soon', liveBroadcastContent: 'upcoming' },
    liveStreamingDetails: { scheduledStartTime: iso(now + 10 * MINUTE) },
  }],
  f: [{
    id: 'f-later',
    snippet: { title: 'This evening', liveBroadcastContent: 'upcoming' },
    liveStreamingDetails: { scheduledStartTime: iso(now + 50 * MINUTE) },
  }],
  g: [{
    id: 'g-stale',
    snippet: { title: 'Never started', liveBroadcastContent: 'upcoming' },
    liveStreamingDetails: { scheduledStartTime: iso(now - 3 * 24 * 60 * MINUTE) },
  }],
};

before(async () => {
  globalThis.__fakeSupabase = { createClient: () => ({ from: query }) };
  globalThis.fetch = async (input) => {
    const url = new URL(input);
    const resource = url.pathname.split('/').pop();
    youtubeCalls.push(
      `${resource} ${url.searchParams.get('playlistId') ?? url.searchParams.get('id')}`,
    );
    assert.equal(url.searchParams.get('key'), 'yt-key');
    if (resource === 'playlistItems') {
      const id = url.searchParams.get('playlistId');
      const letter = id.slice(-1);
      // Channel b has never streamed, so it has no Live playlist.
      if (letter === 'b' && id.startsWith('UULV')) {
        return new Response('{}', { status: 404 });
      }
      const items = (videos[letter] ?? []).map((v) => ({ contentDetails: { videoId: v.id } }));
      return Response.json({ items });
    }
    const ids = url.searchParams.get('id').split(',');
    return Response.json({ items: Object.values(videos).flat().filter((v) => ids.includes(v.id)) });
  };
  globalThis.Deno = {
    env: { get: (name) => env[name] },
    serve: (fn) => {
      handler = fn;
    },
  };
  await import(pathToFileURL(join(workDir, 'fn.ts')).href);
});

after(() => rmSync(workDir, { recursive: true, force: true }));

beforeEach(() => {
  env = { YOUTUBE_API_KEY: 'yt-key', CRON_SECRET: 'cron-secret' };
  upserts = [];
  youtubeCalls = [];
  tables = {
    branches: [
      { id: 'live', youtube_channel_id: channel('a') },
      { id: 'never-streamed', youtube_channel_id: channel('b') },
      { id: 'typo', youtube_channel_id: 'youtube.com/@ccc' },
      { id: 'not-due', youtube_channel_id: channel('d') },
      { id: 'soon', youtube_channel_id: channel('e') },
      { id: 'later', youtube_channel_id: channel('f') },
      { id: 'stale', youtube_channel_id: channel('g') },
    ],
    live_streams: [
      { branch_id: 'not-due', next_check_at: iso(now + 10 * MINUTE) },
      { branch_id: 'live', next_check_at: iso(now - MINUTE) },
    ],
    events: [
      { branch_id: 'never-streamed', starts_at: iso(now + 10 * MINUTE), ends_at: null },
    ],
  };
});

const call = (headers = { 'x-cron-secret': 'cron-secret' }, method = 'POST') =>
  handler(new Request('http://localhost/check', { method, headers }));
const inMinutes = (row) => Math.round((Date.parse(row.next_check_at) - now) / MINUTE);

test('only scheduled POSTs with the cron secret reach YouTube', async () => {
  assert.equal((await call({}, 'GET')).status, 405);
  assert.equal((await call({})).status, 403);
  assert.equal((await call({ 'x-cron-secret': 'wrong' })).status, 403);
  delete env.CRON_SECRET;
  assert.equal((await call()).status, 503);
  assert.deepEqual(youtubeCalls, []);
  assert.deepEqual(upserts, []);
});

test('records live, upcoming and offline branches and when to look again', async () => {
  const response = await call();
  const body = await response.json();
  assert.equal(response.status, 200, JSON.stringify(body));

  const readings = Object.fromEntries(upserts[0].rows.map((r) => [r.branch_id, r]));
  const problems = Object.fromEntries((upserts[1]?.rows ?? []).map((r) => [r.branch_id, r]));
  assert.deepEqual(upserts[0].options, { onConflict: 'branch_id', defaultToNull: false });

  assert.equal(body.checked, 6, 'branches not yet due are skipped');
  assert.ok(!('not-due' in readings) && !('not-due' in problems));

  assert.equal(readings.live.status, 'live');
  assert.equal(readings.live.video_id, 'a-live');
  assert.equal(readings.live.title, 'Sunday Service');
  assert.equal(inMinutes(readings.live), 2, 'live: every 2 minutes');
  assert.deepEqual(body.live, ['live']);

  assert.equal(readings['never-streamed'].status, 'offline');
  assert.ok(
    youtubeCalls.includes(`playlistItems UU${'b'.repeat(22)}`),
    'a channel without a Live playlist falls back to its uploads',
  );
  assert.equal(inMinutes(readings['never-streamed']), 1, 'event soon: every minute');

  assert.match(problems.typo.error, /channel ID starting with UC/);
  assert.equal(inMinutes(problems.typo), 5);
  assert.equal(problems.typo.status, undefined, 'a failure keeps the last status');

  assert.equal(readings.soon.status, 'upcoming');
  assert.equal(inMinutes(readings.soon), 1, 'stream in 10 minutes: every minute');
  assert.equal(inMinutes(readings.later), 20, 'stream in 50 minutes: wake 30 minutes before');
  assert.equal(readings.stale.status, 'upcoming');
  assert.equal(inMinutes(readings.stale), 30, 'an old schedule: back to every 30 minutes');
});
