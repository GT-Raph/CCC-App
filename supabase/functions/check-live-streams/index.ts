// Watches each branch's YouTube channel and records in public.live_streams
// whether it is streaming. The app reads that table (and hears about changes
// through Realtime), so no one has to paste stream links.
//
// Supabase Cron calls this every minute (supabase/live_streams_cron.sql),
// but it only asks YouTube about branches that are due:
//   - every minute from 30 minutes before one of the branch's events until
//     the event ends, and in the half hour before a scheduled stream,
//   - every 2 minutes while the branch is live,
//   - every 30 minutes otherwise.
// Each check costs 2 of the YouTube Data API's 10,000 free daily units (the
// channel's Live playlist, then the videos), so a few dozen branches fit
// comfortably.
//
// Secrets: YOUTUBE_API_KEY and CRON_SECRET (required;
// callers must send it in an x-cron-secret header). SUPABASE_URL and
// SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.

import { createClient } from "npm:@supabase/supabase-js@2";

const MINUTE = 60_000;
const YOUTUBE = "https://www.googleapis.com/youtube/v3";

type Branch = { id: string; youtube_channel_id: string };
type EventRow = { branch_id: string; starts_at: string; ends_at: string | null };
type Video = {
  id: string;
  snippet?: { title?: string; liveBroadcastContent?: string };
  liveStreamingDetails?: {
    scheduledStartTime?: string;
    actualStartTime?: string;
  };
};
type Reading = { status: "live" | "upcoming" | "offline"; video?: Video };

class NotFound extends Error {}

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const secret = Deno.env.get("CRON_SECRET");
  if (!secret) return json({ error: "CRON_SECRET is not configured." }, 503);
  if (request.headers.get("x-cron-secret") !== secret) {
    return new Response("Forbidden", { status: 403 });
  }
  const key = Deno.env.get("YOUTUBE_API_KEY");
  if (!key) return json({ error: "Add the YOUTUBE_API_KEY secret." }, 500);

  const db = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const now = Date.now();

  const [branches, states, events] = await Promise.all([
    db.from("branches")
      .select("id, youtube_channel_id")
      .not("youtube_channel_id", "is", null),
    db.from("live_streams").select("branch_id, next_check_at"),
    db.from("events")
      .select("branch_id, starts_at, ends_at")
      .gte("starts_at", iso(now - 12 * 60 * MINUTE))
      .lte("starts_at", iso(now + 24 * 60 * MINUTE)),
  ]);
  const failure = branches.error ?? states.error ?? events.error;
  if (failure) return json({ error: failure.message }, 500);

  const nextCheck = new Map(
    (states.data ?? []).map((row) => [row.branch_id, Date.parse(row.next_check_at)]),
  );
  const due = (branches.data as Branch[]).filter((branch) => {
    const next = nextCheck.get(branch.id);
    return next === undefined || next <= now;
  });
  const upcomingEvents = (events.data ?? []) as EventRow[];

  const readings = [];
  const problems = [];
  await Promise.all(due.map(async (branch) => {
    try {
      const reading = await check(branch.youtube_channel_id, key);
      const details = reading.video?.liveStreamingDetails;
      readings.push({
        branch_id: branch.id,
        status: reading.status,
        video_id: reading.video?.id ?? null,
        title: reading.video?.snippet?.title ?? null,
        scheduled_start_at: details?.scheduledStartTime ?? null,
        actual_start_at: details?.actualStartTime ?? null,
        checked_at: iso(now),
        next_check_at: iso(nextCheckAt(branch.id, reading, upcomingEvents, now)),
        error: null,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      // Keep the last reading; it stops counting as live once it is 20
      // minutes old. Back off longer when the daily quota is used up.
      problems.push({
        branch_id: branch.id,
        error: message,
        next_check_at: iso(now + (/quota/i.test(message) ? 30 : 5) * MINUTE),
      });
    }
  }));

  const options = { onConflict: "branch_id", defaultToNull: false };
  for (const rows of [readings, problems]) {
    if (rows.length === 0) continue;
    const { error } = await db.from("live_streams").upsert(rows, options);
    if (error) return json({ error: error.message }, 500);
  }

  return json({
    checked: due.length,
    live: readings.filter((row) => row.status === "live").map((row) => row.branch_id),
    problems,
  });
});

/** The channel's live stream, or else its next scheduled one. */
async function check(channelId: string, key: string): Promise<Reading> {
  if (!/^UC[\w-]{22}$/.test(channelId)) {
    throw new Error("youtube_channel_id must be a channel ID starting with UC.");
  }
  const ids = await recentVideoIds(channelId, key);
  if (ids.length === 0) return { status: "offline" };
  const body = await youtube("videos", {
    part: "snippet,liveStreamingDetails",
    id: ids.join(","),
  }, key);
  const videos = (body.items ?? []) as Video[];

  const live = videos.find((video) => video.snippet?.liveBroadcastContent === "live");
  if (live) return { status: "live", video: live };

  const startOf = (video: Video) =>
    Date.parse(video.liveStreamingDetails?.scheduledStartTime ?? "");
  const upcoming = videos
    .filter((video) =>
      video.snippet?.liveBroadcastContent === "upcoming" && !isNaN(startOf(video))
    )
    .sort((a, b) => startOf(a) - startOf(b))[0];
  return upcoming ? { status: "upcoming", video: upcoming } : { status: "offline" };
}

/**
 * The newest videos on the channel's Live tab, or its newest uploads for a
 * channel that has never streamed (it has no Live tab yet).
 */
async function recentVideoIds(channelId: string, key: string): Promise<string[]> {
  for (const prefix of ["UULV", "UU"]) {
    try {
      const body = await youtube("playlistItems", {
        part: "contentDetails",
        maxResults: "5",
        playlistId: prefix + channelId.slice(2),
      }, key);
      return (body.items ?? []).map(
        (item: { contentDetails: { videoId: string } }) => item.contentDetails.videoId,
      );
    } catch (error) {
      if (error instanceof NotFound) continue;
      throw error;
    }
  }
  return [];
}

function nextCheckAt(
  branchId: string,
  reading: Reading,
  events: EventRow[],
  now: number,
): number {
  if (reading.status === "live") return now + 2 * MINUTE;

  const ownEvents = events.filter((event) => event.branch_id === branchId);
  const eventIsOn = ownEvents.some((event) => {
    const start = Date.parse(event.starts_at);
    const end = event.ends_at ? Date.parse(event.ends_at) : start + 3 * 60 * MINUTE;
    return start - 30 * MINUTE <= now && now <= end;
  });
  if (eventIsOn) return now + MINUTE;

  // A scheduled stream: every minute from half an hour before its start
  // until two hours after (channels often keep old schedules that never
  // started, which mustn't be checked every minute forever).
  const scheduled = reading.status === "upcoming"
    ? Date.parse(reading.video?.liveStreamingDetails?.scheduledStartTime ?? "")
    : NaN;
  if (scheduled - 30 * MINUTE <= now && now <= scheduled + 2 * 60 * MINUTE) {
    return now + MINUTE;
  }

  // Otherwise wake up for whatever comes first: half an hour before the next
  // event or scheduled stream, or the regular half-hourly check.
  const wakeUps = [
    ...ownEvents.map((event) => Date.parse(event.starts_at)),
    scheduled,
  ].map((start) => start - 30 * MINUTE).filter((time) => time > now);
  return Math.max(Math.min(now + 30 * MINUTE, ...wakeUps), now + MINUTE);
}

async function youtube(
  resource: string,
  params: Record<string, string>,
  key: string,
) {
  const url = new URL(`${YOUTUBE}/${resource}`);
  for (const [name, value] of Object.entries({ ...params, key })) {
    url.searchParams.set(name, value);
  }
  const response = await fetch(url, { signal: AbortSignal.timeout(15_000) });
  if (response.status === 404) throw new NotFound(resource);
  const body = await response.json();
  if (!response.ok) {
    throw new Error(body?.error?.message ?? `YouTube ${resource} failed (${response.status}).`);
  }
  return body;
}

function iso(time: number): string {
  return new Date(time).toISOString();
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
