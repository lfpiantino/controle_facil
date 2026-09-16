drop policy if exists public_categories on public.categories;
drop policy if exists public_products on public.products;
drop policy if exists categories_staff_write on public.categories;
drop policy if exists products_staff_write on public.products;

create policy public_categories on public.categories for select to anon
using (is_active and exists (select 1 from public.stores s where s.id = store_id and s.is_active));
create policy public_products on public.products for select to anon
using (is_available and exists (select 1 from public.stores s where s.id = store_id and s.is_active));
create policy categories_staff_select on public.categories for select to authenticated using (private.is_store_member(store_id));
create policy categories_staff_insert on public.categories for insert to authenticated with check (private.is_store_member(store_id));
create policy categories_staff_update on public.categories for update to authenticated using (private.is_store_member(store_id)) with check (private.is_store_member(store_id));
create policy categories_staff_delete on public.categories for delete to authenticated using (private.is_store_member(store_id));
create policy products_staff_select on public.products for select to authenticated using (private.is_store_member(store_id));
create policy products_staff_insert on public.products for insert to authenticated with check (private.is_store_member(store_id));
create policy products_staff_update on public.products for update to authenticated using (private.is_store_member(store_id)) with check (private.is_store_member(store_id));
create policy products_staff_delete on public.products for delete to authenticated using (private.is_store_member(store_id));

create index if not exists stores_owner_idx on public.stores(owner_id);
create index if not exists store_members_user_idx on public.store_members(user_id);
create index if not exists addons_store_idx on public.addons(store_id);
create index if not exists addons_ingredient_idx on public.addons(ingredient_id);
create index if not exists product_ingredients_ingredient_idx on public.product_ingredients(ingredient_id);
create index if not exists product_addons_addon_idx on public.product_addons(addon_id);
create index if not exists products_category_idx on public.products(category_id);
create index if not exists customers_store_idx on public.customers(store_id);
create index if not exists cash_sessions_opened_by_idx on public.cash_sessions(opened_by);
create index if not exists cash_sessions_closed_by_idx on public.cash_sessions(closed_by);
create index if not exists orders_cash_idx on public.orders(cash_session_id);
create index if not exists orders_customer_idx on public.orders(customer_id);
create index if not exists orders_table_idx on public.orders(table_id);
create index if not exists orders_created_by_idx on public.orders(created_by);
create index if not exists order_items_order_idx on public.order_items(order_id);
create index if not exists order_items_product_idx on public.order_items(product_id);
create index if not exists order_item_addons_item_idx on public.order_item_addons(order_item_id);
create index if not exists order_item_addons_addon_idx on public.order_item_addons(addon_id);
create index if not exists cash_movements_store_idx on public.cash_movements(store_id);
create index if not exists cash_movements_session_idx on public.cash_movements(cash_session_id);
create index if not exists cash_movements_order_idx on public.cash_movements(order_id);
create index if not exists cash_movements_created_by_idx on public.cash_movements(created_by);
create index if not exists stock_movements_store_idx on public.stock_movements(store_id);
create index if not exists stock_movements_order_idx on public.stock_movements(order_id);
create index if not exists stock_movements_created_by_idx on public.stock_movements(created_by);
