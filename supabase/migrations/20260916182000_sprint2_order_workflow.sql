create or replace function public.create_order_v2(p_store_id uuid,p_channel public.order_channel,p_payment_method text,p_discount numeric,p_items jsonb,p_notes text default null,p_customer_id uuid default null,p_table_id uuid default null,p_customer_name text default null,p_customer_phone text default null,p_delivery_address text default null,p_delivery_fee numeric default 0)
returns uuid language plpgsql security invoker set search_path=''
as $$
declare v_order_id uuid;
begin
  if p_channel='table' and p_table_id is null then raise exception 'MESA_OBRIGATORIA';end if;
  if p_channel='delivery' and nullif(btrim(p_delivery_address),'') is null then raise exception 'ENDERECO_OBRIGATORIO';end if;
  if p_customer_id is not null and not exists(select 1 from public.customers where id=p_customer_id and store_id=p_store_id) then raise exception 'CLIENTE_INVALIDO';end if;
  if p_table_id is not null and not exists(select 1 from public.dining_tables where id=p_table_id and store_id=p_store_id and is_active) then raise exception 'MESA_INVALIDA';end if;
  v_order_id:=public.create_sale(p_store_id,p_channel,p_payment_method,p_discount,p_items,p_notes);
  update public.orders set customer_id=p_customer_id,table_id=case when p_channel='table' then p_table_id else null end,customer_name=nullif(btrim(p_customer_name),''),customer_phone=nullif(btrim(p_customer_phone),''),delivery_address=case when p_channel='delivery' then nullif(btrim(p_delivery_address),'') else null end,delivery_fee=case when p_channel='delivery' then greatest(coalesce(p_delivery_fee,0),0) else 0 end where id=v_order_id and store_id=p_store_id;
  update public.cash_movements cm set amount=o.total from public.orders o where cm.order_id=o.id and o.id=v_order_id and cm.movement_type='sale';
  return v_order_id;
end;$$;

create or replace function public.update_order_status(p_store_id uuid,p_order_id uuid,p_status public.order_status)
returns public.order_status language plpgsql security invoker set search_path=''
as $$
declare v_current public.order_status;
begin
  if auth.uid() is null or not private.is_store_member(p_store_id) then raise exception using errcode='42501',message='ACESSO_NEGADO_LOJA';end if;
  if not private.is_store_operational(p_store_id) then raise exception 'EMPRESA_BLOQUEADA_INADIMPLENCIA';end if;
  select status into v_current from public.orders where id=p_order_id and store_id=p_store_id for update;
  if v_current is null then raise exception 'PEDIDO_NAO_ENCONTRADO';end if;
  if p_status='cancelled' then raise exception 'USE_CANCEL_ORDER';end if;
  if not ((v_current='confirmed' and p_status in ('preparing','ready')) or (v_current='preparing' and p_status='ready') or (v_current='ready' and p_status in ('out_for_delivery','completed')) or (v_current='out_for_delivery' and p_status='completed')) then raise exception 'TRANSICAO_STATUS_INVALIDA';end if;
  update public.orders set status=p_status where id=p_order_id;
  return p_status;
end;$$;

create or replace function public.cancel_order(p_store_id uuid,p_order_id uuid)
returns boolean language plpgsql security invoker set search_path=''
as $$
declare v_order public.orders%rowtype;v_move record;
begin
  if auth.uid() is null or not private.is_store_member(p_store_id) then raise exception using errcode='42501',message='ACESSO_NEGADO_LOJA';end if;
  if not private.is_store_operational(p_store_id) then raise exception 'EMPRESA_BLOQUEADA_INADIMPLENCIA';end if;
  select * into v_order from public.orders where id=p_order_id and store_id=p_store_id for update;
  if not found then raise exception 'PEDIDO_NAO_ENCONTRADO';end if;
  if v_order.status='cancelled' then return false;end if;
  if v_order.status='completed' then raise exception 'PEDIDO_FINALIZADO';end if;
  if not exists(select 1 from public.cash_sessions where id=v_order.cash_session_id and status='open') then raise exception 'CAIXA_DA_VENDA_FECHADO';end if;
  for v_move in select ingredient_id,-quantity as restore_qty from public.stock_movements where order_id=p_order_id and movement_type='sale' loop
    update public.ingredients set current_stock=current_stock+v_move.restore_qty where id=v_move.ingredient_id and store_id=p_store_id;
    insert into public.stock_movements(store_id,ingredient_id,order_id,created_by,movement_type,quantity,notes) values(p_store_id,v_move.ingredient_id,p_order_id,auth.uid(),'cancellation',v_move.restore_qty,'Estorno automático do cancelamento');
  end loop;
  insert into public.cash_movements(store_id,cash_session_id,order_id,created_by,movement_type,payment_method,amount,description) values(p_store_id,v_order.cash_session_id,p_order_id,auth.uid(),'refund',v_order.payment_method,v_order.total,'Cancelamento do pedido #'||v_order.order_number);
  update public.orders set status='cancelled' where id=p_order_id;
  return true;
end;$$;

create index if not exists orders_kitchen_queue_idx on public.orders(store_id,status,created_at) where status in ('confirmed','preparing','ready','out_for_delivery');
create index if not exists orders_open_table_idx on public.orders(store_id,table_id,status) where table_id is not null and status not in ('completed','cancelled');

revoke all on function public.create_order_v2(uuid,public.order_channel,text,numeric,jsonb,text,uuid,uuid,text,text,text,numeric) from public,anon;
revoke all on function public.update_order_status(uuid,uuid,public.order_status) from public,anon;
revoke all on function public.cancel_order(uuid,uuid) from public,anon;
grant execute on function public.create_order_v2(uuid,public.order_channel,text,numeric,jsonb,text,uuid,uuid,text,text,text,numeric) to authenticated;
grant execute on function public.update_order_status(uuid,uuid,public.order_status) to authenticated;
grant execute on function public.cancel_order(uuid,uuid) to authenticated;
