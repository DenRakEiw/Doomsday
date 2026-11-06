-- Doomsday leaderboard submissions (docs/specs/benchmark.md §20). Run once in the SQL editor.
-- The tables are in a schema the Data API does not expose; the only doors are the three
-- functions at the bottom, each granted to exactly one role.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- One row. The owner edits it in the Table Editor: open = false closes submissions.
create table private.submit_config (
	id boolean primary key default true check (id),
	open boolean not null default true,
	max_per_hour integer not null default 60,
	max_pending integer not null default 300
);
insert into private.submit_config default values;

create table private.submissions (
	id bigint generated always as identity primary key,
	created_at timestamptz not null default now(),
	group_sha text not null unique,
	file_count integer not null,
	total_bytes integer not null,
	files jsonb not null,
	status text not null default 'new'
		check (status in ('new', 'held', 'approved', 'accepted', 'rejected')),
	reason text not null default '',
	checked_at timestamptz
);
create index submissions_status_id on private.submissions (status, id);
create index submissions_created on private.submissions (created_at);

alter table private.submit_config enable row level security;
alter table private.submissions enable row level security;
revoke all on all tables in schema private from public, anon, authenticated;

-- The game's door (publishable key → anon). One group of run files per call.
-- p_files: [{"name": "<§10.2 file name>", "body": "<the file's text>"}, …]
-- Returns {"status": "received" | "already", "id": <row id>}; refuses with 'submit:<reason>'.
create or replace function public.submit_runs(p_files jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
	cfg private.submit_config;
	f jsonb;
	body text;
	parsed jsonb;
	names text[] := '{}';
	hashes text[] := '{}';
	content text := null;
	total integer := 0;
	g text;
	found_id bigint;
	new_id bigint;
begin
	select * into cfg from private.submit_config where id;
	if cfg is null or not cfg.open then
		raise exception 'submit:closed';
	end if;
	if jsonb_typeof(p_files) is distinct from 'array' then
		raise exception 'submit:bad_request';
	end if;
	if jsonb_array_length(p_files) < 1 or jsonb_array_length(p_files) > 10 then
		raise exception 'submit:too_many_files';
	end if;
	for f in select value from jsonb_array_elements(p_files) loop
		if jsonb_typeof(f) is distinct from 'object'
				or jsonb_typeof(f -> 'name') is distinct from 'string'
				or jsonb_typeof(f -> 'body') is distinct from 'string' then
			raise exception 'submit:bad_request';
		end if;
		if (f ->> 'name') !~ '^[a-z0-9._-]{1,200}\.json$' or (f ->> 'name') = any(names) then
			raise exception 'submit:bad_name';
		end if;
		body := f ->> 'body';
		if octet_length(body) > 1000000 then
			raise exception 'submit:too_large';
		end if;
		total := total + octet_length(body);
		begin
			parsed := body::jsonb;
		exception when others then
			raise exception 'submit:bad_json';
		end;
		if jsonb_typeof(parsed) is distinct from 'object'
				or jsonb_typeof(parsed -> 'content_hash') is distinct from 'string' then
			raise exception 'submit:bad_json';
		end if;
		if content is null then
			content := parsed ->> 'content_hash';
		elsif content <> parsed ->> 'content_hash' then
			raise exception 'submit:mixed';
		end if;
		names := names || (f ->> 'name');
		hashes := hashes || encode(sha256(convert_to(body, 'UTF8')), 'hex');
	end loop;
	if total > 3000000 then
		raise exception 'submit:too_large';
	end if;
	select encode(sha256(convert_to(string_agg(u.h, E'\n' order by u.h), 'UTF8')), 'hex')
		into g from unnest(hashes) as u(h);
	select s.id into found_id from private.submissions s where s.group_sha = g;
	if found_id is not null then
		return jsonb_build_object('status', 'already', 'id', found_id);
	end if;
	if (select count(*) from private.submissions s
			where s.created_at > now() - interval '1 hour') >= cfg.max_per_hour then
		raise exception 'submit:busy';
	end if;
	if (select count(*) from private.submissions s
			where s.status in ('new', 'held', 'approved')) >= cfg.max_pending then
		raise exception 'submit:full';
	end if;
	insert into private.submissions (group_sha, file_count, total_bytes, files)
		values (g, jsonb_array_length(p_files), total, p_files)
		on conflict (group_sha) do nothing
		returning id into new_id;
	if new_id is null then
		select s.id into found_id from private.submissions s where s.group_sha = g;
		return jsonb_build_object('status', 'already', 'id', found_id);
	end if;
	return jsonb_build_object('status', 'received', 'id', new_id);
end;
$$;

-- The workflow's doors (secret key → service_role).
create or replace function public.take_submissions(p_limit integer)
returns table (id bigint, status text, files jsonb)
language sql
security definer
set search_path = ''
as $$
	select s.id, s.status, s.files from private.submissions s
	where s.status in ('new', 'approved')
	order by s.id
	limit greatest(p_limit, 0);
$$;

-- Accepted and rejected rows keep their hash (a resend answers 'already') but drop the files.
create or replace function public.mark_submission(p_id bigint, p_status text, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
	if p_status not in ('held', 'accepted', 'rejected') then
		raise exception 'mark:bad_status';
	end if;
	update private.submissions s
		set status = p_status,
			reason = left(coalesce(p_reason, ''), 200),
			checked_at = now(),
			files = case when p_status = 'held' then s.files else '[]'::jsonb end
		where s.id = p_id;
end;
$$;

-- Functions are executable by PUBLIC by default, and Supabase may grant new ones to anon and
-- authenticated as well: take everything away, then give each door to its one role.
revoke execute on function public.submit_runs(jsonb) from public, anon, authenticated;
revoke execute on function public.take_submissions(integer) from public, anon, authenticated;
revoke execute on function public.mark_submission(bigint, text, text) from public, anon, authenticated;
grant execute on function public.submit_runs(jsonb) to anon;
grant execute on function public.take_submissions(integer) to service_role;
grant execute on function public.mark_submission(bigint, text, text) to service_role;

notify pgrst, 'reload schema';
