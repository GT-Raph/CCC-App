// Stand-ins for the parts of Supabase that the scripts in supabase/ rely on
// (the auth and storage schemas and the anon and authenticated roles), in
// PGlite: a real PostgreSQL build that runs inside Node.
import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const project = fileURLToPath(new URL('../..', import.meta.url));

export const readSql = (name) => readFileSync(join(project, 'supabase', name), 'utf8');

/** A database with Supabase's stand-ins, then [scripts] from supabase/ in order. */
export async function supabaseDb(...scripts) {
  const db = new PGlite();
  await db.exec(`
    create role anon nologin;
    create role authenticated nologin;
    create schema auth;
    create table auth.users (
      id uuid primary key,
      email text,
      email_confirmed_at timestamptz,
      raw_user_meta_data jsonb default '{}'::jsonb
    );
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
    $$;
    grant usage on schema auth to anon, authenticated;
    grant execute on function auth.uid() to anon, authenticated;
    create schema storage;
    create table storage.buckets (
      id text primary key, name text, public boolean,
      file_size_limit bigint, allowed_mime_types text[]
    );
    create table storage.objects (
      id uuid primary key default gen_random_uuid(),
      bucket_id text references storage.buckets(id),
      name text
    );
    alter table storage.objects enable row level security;
    grant usage on schema storage to anon, authenticated;
    grant select, insert, update, delete on storage.objects to authenticated;
    create publication supabase_realtime;
    grant usage on schema public to anon, authenticated;
  `);
  for (const name of scripts) await db.exec(readSql(name));
  return db;
}

/**
 * Returns as(who, sql), which runs SQL (one statement, or several in order)
 * as the signed-in user ids[who], as 'anon', or as 'owner' (the database
 * owner, like the dashboard), inside a transaction that is rolled back. It
 * returns the last statement's rows and affected count, every statement's
 * rows in `all`, or the error message.
 */
export function actAs(db, ids) {
  return async function as(who, sql) {
    await db.exec('begin');
    try {
      if (who === 'anon') {
        await db.exec(`set local role anon; select set_config('request.jwt.claim.sub', '', true);`);
      } else if (who !== 'owner') {
        await db.exec(`set local role authenticated; select set_config('request.jwt.claim.sub', '${ids[who]}', true);`);
      }
      const all = [];
      let result;
      for (const statement of [sql].flat()) {
        result = await db.query(statement);
        all.push(result.rows);
      }
      return { rows: result.rows, affected: result.affectedRows, all };
    } catch (error) {
      return { error: error.message };
    } finally {
      await db.exec('rollback');
    }
  };
}
