create or replace function public.create_order_v3(p_store_id uuid,p_channel public.order_channel,p_payment_method text,p_discount numeric,p_items jsonb,p_notes text default null,p_customer_id uuid default null,p_table_id uuid default null,p_customer_name text default null,p_customer_phone text default null,p_delivery_address text default null,p_delivery_fee numeric default 0)
returns uuid language plpgsql security invoker set search_path=''
as $$
declare v_order_id uuid;v_item jsonb;v_addon_item jsonb;v_order_item_id uuid;v_addon public.addons%rowtype;v_product_qty numeric;v_addon_qty numeric;v_required numeric;v_addon_total numeric(12,2):=0;
begin
  v_order_id:=public.create_order_v2(p_store_id,p_channel,p_payment_method,p_discount,p_items,p_notes,p_customer_id,p_table_id,p_customer_name,p_customer_phone,p_delivery_address,p_delivery_fee);
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_product_qty:=coalesce(nullif(v_item->>'quantity','')::numeric,0);
    select id into v_order_item_id from public.order_items where order_id=v_order_id and product_id=(v_item->>'product_id')::uuid limit 1;
    if v_order_item_id is null or jsonb_typeof(v_item->'addons')<>'array' then continue;end if;
    for v_addon_item in select value from jsonb_array_elements(v_item->'addons') loop
      v_addon_qty:=coalesce(nullif(v_addon_item->>'quantity','')::numeric,0);
      if v_addon_qty<=0 then continue;end if;
      select a.* into v_addon from public.addons a join public.product_addons pa on pa.addon_id=a.id where a.id=(v_addon_item->>'addon_id')::uuid and a.store_id=p_store_id and a.is_available and pa.product_id=(v_item->>'product_id')::uuid for share of a;
      if not found then raise exception 'ADICIONAL_INDISPONIVEL';end if;
      insert into public.order_item_addons(order_item_id,addon_id,addon_name,quantity,unit_price) values(v_order_item_id,v_addon.id,v_addon.name,v_addon_qty*v_product_qty,v_addon.price);
      v_addon_total:=v_addon_total+(v_addon.price*v_addon_qty*v_product_qty);
      if v_addon.ingredient_id is not null then
        v_required:=v_addon_qty*v_product_qty;
        update public.ingredients set current_stock=current_stock-v_required where id=v_addon.ingredient_id and store_id=p_store_id and current_stock>=v_required;
        if not found then raise exception 'ESTOQUE_INSUFICIENTE: %',v_addon.name;end if;
        insert into public.stock_movements(store_id,ingredient_id,order_id,created_by,movement_type,quantity,notes) values(p_store_id,v_addon.ingredient_id,v_order_id,auth.uid(),'sale',-v_required,'Baixa automática de adicional');
      end if;
    end loop;
  end loop;
  if v_addon_total>0 then update public.orders set subtotal=subtotal+v_addon_total where id=v_order_id;end if;
  update public.cash_movements cm set amount=o.total from public.orders o where cm.order_id=o.id and o.id=v_order_id and cm.movement_type='sale';
  return v_order_id;
end;$$;

revoke all on function public.create_order_v3(uuid,public.order_channel,text,numeric,jsonb,text,uuid,uuid,text,text,text,numeric) from public,anon;
grant execute on function public.create_order_v3(uuid,public.order_channel,text,numeric,jsonb,text,uuid,uuid,text,text,text,numeric) to authenticated;
