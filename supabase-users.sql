-- Cadence user accounts + synced library + listening stats.
-- Run AFTER supabase-setup.sql (it uses is_admin() from that file). Paste into Supabase > SQL Editor > Run.

create table public.user_data (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text,
  liked jsonb not null default '{}'::jsonb,       -- liked songs
  playlists jsonb not null default '[]'::jsonb,
  recent jsonb not null default '[]'::jsonb,
  liked_count int not null default 0,
  playlist_count int not null default 0,
  total_seconds bigint not null default 0,        -- time listened, added by add_listen()
  created_at timestamptz not null default now(),
  last_active_at timestamptz not null default now()
);
alter table public.user_data enable row level security;

create policy "user reads own"   on public.user_data for select to authenticated using (user_id = auth.uid());
create policy "user inserts own" on public.user_data for insert to authenticated with check (user_id = auth.uid());
create policy "user updates own" on public.user_data for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "admin reads all"  on public.user_data for select to authenticated using (public.is_admin());
create policy "admin deletes"    on public.user_data for delete to authenticated using (public.is_admin());

create function public.touch_user_data() returns trigger language plpgsql as
$$ begin new.last_active_at = now(); return new; end $$;
create trigger user_data_touch before update on public.user_data for each row execute function public.touch_user_data();

-- the app calls this every minute while music plays (max 1 hour per call)
create function public.add_listen(secs int) returns void language sql security definer set search_path = public as
$$ update public.user_data set total_seconds = total_seconds + least(greatest(secs, 0), 3600) where user_id = auth.uid() $$;
revoke all on function public.add_listen(int) from public, anon;
grant execute on function public.add_listen(int) to authenticated;
