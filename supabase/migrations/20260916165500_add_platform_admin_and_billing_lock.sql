-- Multiempresa: administração da plataforma e bloqueio por inadimplência.
-- O super_admin administra contratos, sem acesso automático aos dados operacionais.

create table public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'super_admin' check (role = 'super_admin'),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.platform_admins enable row level security;

create or replace function private.is_super_admin()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.platform_admins
    where user_id = (select auth.uid())
      and role = 'super_admin'
      and is_active
  );
$$;

revoke all on function private.is_super_admin() from public;
grant usage on schema private to authenticated;
grant execute on function private.is_super_admin() to authenticated;

create policy platform_admins_self_select
on public.platform_admins for select to authenticated
using (user_id = (select auth.uid()));

create table public.company_accounts (
  store_id uuid primary key references public.stores(id) on delete cascade,
  legal_name text,
  document text,
  contact_email text,
  plan text not null default 'free' check (plan in ('free','starter','pro')),
  billing_status text not null default 'active'
    check (billing_status in ('trial','active','past_due','suspended','cancelled')),
  due_date date,
  grace_until timestamptz,
  blocked_at timestamptz,
  block_reason text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint company_block_consistency check (
    (billing_status in ('suspended','cancelled') and blocked_at is not null)
    or billing_status not in ('suspended','cancelled')
  )
);

create unique index company_accounts_document_unique
on public.company_accounts(document)
where document is not null and btrim(document) <> '';

create index company_accounts_billing_status_idx
on public.company_accounts(billing_status, due_date);

alter table public.company_accounts enable row level security;

create policy company_accounts_super_select
on public.company_accounts for select to authenticated
using (private.is_super_admin());

create policy company_accounts_super_insert
on public.company_accounts for insert to authenticated
with check (private.is_super_admin());

create policy company_accounts_super_update
on public.company_accounts for update to authenticated
using (private.is_super_admin())
with check (private.is_super_admin());

create or replace function private.is_store_operational(target_store uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select coalesce((
    select
      ca.billing_status in ('active','trial')
      or (ca.billing_status = 'past_due' and ca.grace_until is not null and ca.grace_until >= now())
    from public.company_accounts ca
    where ca.store_id = target_store
  ), true);
$$;

revoke all on function private.is_store_operational(uuid) from public;
grant execute on function private.is_store_operational(uuid) to authenticated;

create or replace function public.get_my_store_access_status(target_store uuid)
returns table (
  store_id uuid,
  billing_status text,
  due_date date,
  grace_until timestamptz,
  is_operational boolean,
  block_reason text
)
language sql stable security definer set search_path = ''
as $$
  select ca.store_id, ca.billing_status, ca.due_date, ca.grace_until,
         private.is_store_operational(ca.store_id), ca.block_reason
  from public.company_accounts ca
  where ca.store_id = target_store
    and exists (
      select 1 from public.store_members sm
      where sm.store_id = ca.store_id
        and sm.user_id = (select auth.uid())
    );
$$;

revoke all on function public.get_my_store_access_status(uuid) from public;
revoke execute on function public.get_my_store_access_status(uuid) from anon;
grant execute on function public.get_my_store_access_status(uuid) to authenticated;

create or replace function private.enforce_company_operational()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  row_data jsonb;
  target_store uuid;
begin
  row_data := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;

  if row_data ? 'store_id' then
    target_store := (row_data ->> 'store_id')::uuid;
  elsif tg_table_name = 'order_items' then
    select o.store_id into target_store from public.orders o
    where o.id = (row_data ->> 'order_id')::uuid;
  elsif tg_table_name = 'order_item_addons' then
    select o.store_id into target_store
    from public.order_items oi join public.orders o on o.id = oi.order_id
    where oi.id = (row_data ->> 'order_item_id')::uuid;
  elsif tg_table_name in ('product_ingredients','product_addons') then
    select p.store_id into target_store from public.products p
    where p.id = (row_data ->> 'product_id')::uuid;
  end if;

  if target_store is not null and not private.is_store_operational(target_store) then
    raise exception using
      errcode = 'P0001',
      message = 'EMPRESA_BLOQUEADA_INADIMPLENCIA',
      detail = 'Regularize a assinatura para realizar novas operações.';
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

revoke all on function private.enforce_company_operational() from public;

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'categories','products','addons','ingredients','customers','dining_tables',
    'cash_sessions','orders','cash_movements','stock_movements',
    'order_items','order_item_addons','product_ingredients','product_addons'
  ] loop
    execute format(
      'create trigger enforce_company_operational before insert or update or delete on public.%I for each row execute function private.enforce_company_operational()',
      table_name
    );
  end loop;
end $$;

create trigger company_accounts_updated
before update on public.company_accounts
for each row execute function public.touch_updated_at();

grant select on public.platform_admins to authenticated;
grant select, insert, update on public.company_accounts to authenticated;

insert into public.platform_admins(user_id, role, is_active)
select id, 'super_admin', true
from auth.users
where lower(email) = lower('luiz.piantino@gmail.com')
on conflict (user_id) do update
set role = excluded.role, is_active = true;
