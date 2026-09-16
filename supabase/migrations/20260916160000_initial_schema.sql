create extension if not exists pgcrypto;

create type public.user_role as enum ('owner', 'manager', 'cashier', 'kitchen', 'stock');
create type public.order_channel as enum ('counter', 'table', 'delivery');
create type public.order_status as enum ('open', 'confirmed', 'preparing', 'ready', 'out_for_delivery', 'completed', 'cancelled');
create type public.cash_status as enum ('open', 'closed');
create type public.stock_movement_type as enum ('purchase', 'sale', 'waste', 'internal_use', 'inventory', 'cancellation');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  created_at timestamptz not null default now()
);

create table public.stores (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id),
  name text not null,
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  description text,
  logo_url text,
  primary_color text not null default '#f97316',
  phone text,
  whatsapp text,
  address text,
  opening_hours text,
  delivery_fee numeric(12,2) not null default 0 check (delivery_fee >= 0),
  is_open boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.store_members (
  store_id uuid not null references public.stores(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.user_role not null default 'cashier',
  created_at timestamptz not null default now(),
  primary key (store_id, user_id)
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  name text not null,
  description text,
  price numeric(12,2) not null check (price >= 0),
  image_url text,
  is_available boolean not null default true,
  is_featured boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.ingredients (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  unit text not null check (unit in ('unit', 'g', 'kg', 'ml', 'l', 'package')),
  current_stock numeric(14,3) not null default 0,
  minimum_stock numeric(14,3) not null default 0,
  average_cost numeric(12,4) not null default 0,
  created_at timestamptz not null default now(),
  unique (store_id, name)
);

create table public.product_ingredients (
  product_id uuid not null references public.products(id) on delete cascade,
  ingredient_id uuid not null references public.ingredients(id) on delete cascade,
  quantity numeric(14,3) not null check (quantity > 0),
  primary key (product_id, ingredient_id)
);

create table public.addons (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  ingredient_id uuid references public.ingredients(id) on delete set null,
  name text not null,
  price numeric(12,2) not null default 0 check (price >= 0),
  stock_quantity numeric(14,3) not null default 0,
  is_available boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.product_addons (
  product_id uuid not null references public.products(id) on delete cascade,
  addon_id uuid not null references public.addons(id) on delete cascade,
  primary key (product_id, addon_id)
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  phone text,
  address text,
  reference text,
  created_at timestamptz not null default now()
);

create table public.dining_tables (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  is_active boolean not null default true,
  unique (store_id, name)
);

create table public.cash_sessions (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  opened_by uuid not null references auth.users(id),
  closed_by uuid references auth.users(id),
  status public.cash_status not null default 'open',
  opening_amount numeric(12,2) not null default 0,
  expected_amount numeric(12,2),
  counted_amount numeric(12,2),
  difference_amount numeric(12,2),
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  notes text
);

create unique index one_open_cash_per_store on public.cash_sessions(store_id) where status = 'open';

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  cash_session_id uuid references public.cash_sessions(id),
  customer_id uuid references public.customers(id),
  table_id uuid references public.dining_tables(id),
  created_by uuid references auth.users(id),
  order_number bigint generated always as identity,
  channel public.order_channel not null,
  status public.order_status not null default 'open',
  customer_name text,
  customer_phone text,
  delivery_address text,
  subtotal numeric(12,2) not null default 0,
  discount numeric(12,2) not null default 0,
  delivery_fee numeric(12,2) not null default 0,
  total numeric(12,2) generated always as (subtotal - discount + delivery_fee) stored,
  payment_method text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id),
  product_name text not null,
  quantity numeric(12,3) not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  notes text,
  line_total numeric(12,2) generated always as (quantity * unit_price) stored
);

create table public.order_item_addons (
  id uuid primary key default gen_random_uuid(),
  order_item_id uuid not null references public.order_items(id) on delete cascade,
  addon_id uuid references public.addons(id),
  addon_name text not null,
  quantity numeric(12,3) not null default 1 check (quantity > 0),
  unit_price numeric(12,2) not null default 0,
  line_total numeric(12,2) generated always as (quantity * unit_price) stored
);

create table public.cash_movements (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  cash_session_id uuid not null references public.cash_sessions(id) on delete cascade,
  order_id uuid references public.orders(id),
  created_by uuid not null references auth.users(id),
  movement_type text not null check (movement_type in ('sale', 'supply', 'withdrawal', 'expense', 'refund')),
  payment_method text,
  amount numeric(12,2) not null check (amount >= 0),
  description text,
  created_at timestamptz not null default now()
);

create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  ingredient_id uuid not null references public.ingredients(id),
  order_id uuid references public.orders(id),
  created_by uuid references auth.users(id),
  movement_type public.stock_movement_type not null,
  quantity numeric(14,3) not null,
  notes text,
  created_at timestamptz not null default now()
);

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create function private.is_store_member(target_store uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.store_members sm
    where sm.store_id = target_store and sm.user_id = (select auth.uid())
  );
$$;
revoke all on function private.is_store_member(uuid) from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.is_store_member(uuid) to authenticated;

create function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)));
  return new;
end;
$$;
revoke all on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

create function public.handle_store_owner()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.owner_id <> (select auth.uid()) then raise exception 'invalid store owner'; end if;
  insert into public.store_members(store_id, user_id, role) values (new.id, new.owner_id, 'owner');
  return new;
end;
$$;
revoke all on function public.handle_store_owner() from public, anon, authenticated;

create trigger on_store_created after insert on public.stores
for each row execute function public.handle_store_owner();

create function public.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end;
$$;

create trigger stores_updated before update on public.stores for each row execute function public.touch_updated_at();
create trigger products_updated before update on public.products for each row execute function public.touch_updated_at();
create trigger orders_updated before update on public.orders for each row execute function public.touch_updated_at();

alter table public.profiles enable row level security;
alter table public.stores enable row level security;
alter table public.store_members enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.ingredients enable row level security;
alter table public.product_ingredients enable row level security;
alter table public.addons enable row level security;
alter table public.product_addons enable row level security;
alter table public.customers enable row level security;
alter table public.dining_tables enable row level security;
alter table public.cash_sessions enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_item_addons enable row level security;
alter table public.cash_movements enable row level security;
alter table public.stock_movements enable row level security;

create policy profiles_self on public.profiles for all to authenticated
using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy public_active_stores on public.stores for select to anon, authenticated using (is_active);
create policy stores_insert on public.stores for insert to authenticated with check (owner_id = (select auth.uid()));
create policy stores_member_update on public.stores for update to authenticated
using (private.is_store_member(id)) with check (private.is_store_member(id));
create policy members_store_access on public.store_members for select to authenticated using (private.is_store_member(store_id));
create policy public_categories on public.categories for select to anon, authenticated
using (is_active and exists (select 1 from public.stores s where s.id = store_id and s.is_active));
create policy public_products on public.products for select to anon, authenticated
using (is_available and exists (select 1 from public.stores s where s.id = store_id and s.is_active));

create policy categories_staff_write on public.categories for all to authenticated
using (private.is_store_member(store_id)) with check (private.is_store_member(store_id));
create policy products_staff_write on public.products for all to authenticated
using (private.is_store_member(store_id)) with check (private.is_store_member(store_id));

create policy ingredients_staff on public.ingredients for all to authenticated
using (private.is_store_member(store_id)) with check (private.is_store_member(store_id));
create policy addons_staff on public.addons for all to authenticated
using (private.is_store_member(store_id)) with check (private.is_store_member(store_id));
create policy customers_staff on public.customers for all to authenticated
using (private.is_store_member(store_id)) with check (private.is_store_member(store_id));
create policy tables_staff on public.dining_tables for all to authenticated
using (private.is_store_member(store_id)) with check (private.is_store_member(store_id));
create policy cash_sessions_staff on public.cash_sessions for all to authenticated
using (private.is_store_member(store_id)) with check (private.is_store_member(store_id));
create policy orders_staff on public.orders for all to authenticated
using (private.is_store_member(store_id)) with check (private.is_store_member(store_id));
create policy cash_movements_staff on public.cash_movements for all to authenticated
using (private.is_store_member(store_id)) with check (private.is_store_member(store_id));
create policy stock_movements_staff on public.stock_movements for all to authenticated
using (private.is_store_member(store_id)) with check (private.is_store_member(store_id));

create policy recipes_staff on public.product_ingredients for all to authenticated
using (exists (select 1 from public.products p where p.id = product_id and private.is_store_member(p.store_id)))
with check (exists (select 1 from public.products p where p.id = product_id and private.is_store_member(p.store_id)));
create policy product_addons_staff on public.product_addons for all to authenticated
using (exists (select 1 from public.products p where p.id = product_id and private.is_store_member(p.store_id)))
with check (exists (select 1 from public.products p where p.id = product_id and private.is_store_member(p.store_id)));
create policy order_items_staff on public.order_items for all to authenticated
using (exists (select 1 from public.orders o where o.id = order_id and private.is_store_member(o.store_id)))
with check (exists (select 1 from public.orders o where o.id = order_id and private.is_store_member(o.store_id)));
create policy order_addons_staff on public.order_item_addons for all to authenticated
using (exists (select 1 from public.order_items oi join public.orders o on o.id = oi.order_id where oi.id = order_item_id and private.is_store_member(o.store_id)))
with check (exists (select 1 from public.order_items oi join public.orders o on o.id = oi.order_id where oi.id = order_item_id and private.is_store_member(o.store_id)));

grant usage on schema public to anon, authenticated;
grant select on public.stores, public.categories, public.products to anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('store-assets', 'store-assets', true, 5242880, array['image/png','image/jpeg','image/webp'])
on conflict (id) do nothing;

create policy store_assets_public_read on storage.objects for select to anon, authenticated
using (bucket_id = 'store-assets');
create policy store_assets_auth_insert on storage.objects for insert to authenticated
with check (bucket_id = 'store-assets');
create policy store_assets_auth_update on storage.objects for update to authenticated
using (bucket_id = 'store-assets' and owner_id = (select auth.uid()::text))
with check (bucket_id = 'store-assets' and owner_id = (select auth.uid()::text));
create policy store_assets_auth_delete on storage.objects for delete to authenticated
using (bucket_id = 'store-assets' and owner_id = (select auth.uid()::text));

create index categories_store_idx on public.categories(store_id, sort_order);
create index products_store_idx on public.products(store_id, category_id, sort_order);
create index ingredients_store_idx on public.ingredients(store_id, name);
create index orders_store_created_idx on public.orders(store_id, created_at desc);
create index stock_movements_ingredient_idx on public.stock_movements(ingredient_id, created_at desc);
