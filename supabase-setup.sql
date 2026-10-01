-- Cadence community songs. Paste this whole file into Supabase > SQL Editor > Run.

create table public.songs (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  artist text not null check (char_length(artist) between 1 and 120),
  language text not null check (language in ('Punjabi','Hindi','Other')),
  genre text check (char_length(genre) <= 40),
  audio_url text not null,
  art_url text,
  duration int default 0,
  rights_ok boolean not null check (rights_ok),            -- artist confirmed they own the song
  status text not null default 'pending' check (status in ('pending','approved','rejected','removed')),
  created_at timestamptz not null default now()
);
create table public.admins (user_id uuid primary key references auth.users(id) on delete cascade);
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  song_id uuid not null references public.songs(id) on delete cascade,
  reason text check (char_length(reason) <= 500),
  created_at timestamptz not null default now()
);
alter table public.songs enable row level security;
alter table public.admins enable row level security;
alter table public.reports enable row level security;

create function public.is_admin() returns boolean language sql security definer stable set search_path = public
as $$ select exists (select 1 from public.admins where user_id = auth.uid()) $$;

-- songs: everyone sees approved ones; artists see their own; admins see and change all
create policy "public reads approved" on public.songs for select using (status = 'approved');
create policy "artist reads own"      on public.songs for select to authenticated using (owner = auth.uid());
create policy "admin reads all"       on public.songs for select to authenticated using (public.is_admin());
create policy "artist uploads"        on public.songs for insert to authenticated with check (owner = auth.uid() and status = 'pending' and rights_ok);
create policy "artist deletes own"    on public.songs for delete to authenticated using (owner = auth.uid());
create policy "admin updates"         on public.songs for update to authenticated using (public.is_admin()) with check (public.is_admin());
-- reports: anyone can file one, only admins can read or clear them
create policy "anyone reports"        on public.reports for insert to anon, authenticated with check (true);
create policy "admin reads reports"   on public.reports for select to authenticated using (public.is_admin());
create policy "admin clears reports"  on public.reports for delete to authenticated using (public.is_admin());
create policy "see own admin row"     on public.admins for select to authenticated using (user_id = auth.uid());

-- file storage: public bucket, 15 MB per file, artists can only write inside their own folder
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('songs','songs',true,15728640, array['audio/mpeg','audio/mp4','audio/x-m4a','audio/ogg','audio/wav','audio/x-wav','image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;
create policy "artist uploads files" on storage.objects for insert to authenticated
  with check (bucket_id = 'songs' and (storage.foldername(name))[1] = auth.uid()::text);

-- AFTER you sign up in studio.html, make yourself the admin (copy your id from Authentication > Users):
-- insert into public.admins (user_id) values ('PASTE-YOUR-USER-ID-HERE');
