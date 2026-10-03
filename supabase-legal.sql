-- Lets people delete their own account and files from inside the app.
-- Run in Supabase > SQL Editor AFTER the other two SQL files.

create function public.delete_my_account() returns void language plpgsql security definer set search_path = public, auth as
$$ begin delete from auth.users where id = auth.uid(); end $$;   -- cascades to user_data, songs
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- artists can delete the files in their own folder (used when deleting a song or an account)
create policy "artist deletes own files" on storage.objects for delete to authenticated
  using (bucket_id = 'songs' and (storage.foldername(name))[1] = auth.uid()::text);
