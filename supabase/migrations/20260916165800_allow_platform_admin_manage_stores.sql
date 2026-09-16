-- Permite ao super_admin administrar o cadastro da empresa sem acesso operacional.

create or replace function public.handle_store_owner()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.owner_id <> (select auth.uid()) and not private.is_super_admin() then
    raise exception 'invalid store owner';
  end if;

  insert into public.store_members(store_id, user_id, role)
  values (new.id, new.owner_id, 'owner')
  on conflict (store_id, user_id) do update set role = 'owner';

  return new;
end;
$$;

revoke all on function public.handle_store_owner() from public;

create policy stores_super_admin_select
on public.stores for select to authenticated
using (private.is_super_admin());

create policy stores_super_admin_insert
on public.stores for insert to authenticated
with check (private.is_super_admin());

create policy stores_super_admin_update
on public.stores for update to authenticated
using (private.is_super_admin())
with check (private.is_super_admin());
