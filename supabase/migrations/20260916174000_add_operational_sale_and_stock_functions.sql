create or replace function public.create_sale(p_store_id uuid,p_channel public.order_channel,p_payment_method text,p_discount numeric,p_items jsonb,p_notes text default null)
returns uuid language plpgsql security invoker set search_path=''
as $$
declare v_user uuid:=auth.uid();v_cash_id uuid;v_order_id uuid;v_subtotal numeric(12,2):=0;v_total numeric(12,2);v_item jsonb;v_product public.products%rowtype;v_order_item_id uuid;v_qty numeric(12,3);v_required numeric(14,3);v_recipe record;
begin
  if v_user is null or not private.is_store_member(p_store_id) then raise exception using errcode='42501',message='ACESSO_NEGADO_LOJA';end if;
  if not private.is_store_operational(p_store_id) then raise exception 'EMPRESA_BLOQUEADA_INADIMPLENCIA';end if;
  if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'PEDIDO_SEM_ITENS';end if;
  select id into v_cash_id from public.cash_sessions where store_id=p_store_id and status='open' order by opened_at desc limit 1 for update;
  if v_cash_id is null then raise exception 'CAIXA_FECHADO';end if;
  insert into public.orders(store_id,cash_session_id,created_by,channel,status,discount,payment_method,notes) values(p_store_id,v_cash_id,v_user,p_channel,'confirmed',greatest(coalesce(p_discount,0),0),p_payment_method,nullif(btrim(p_notes),'')) returning id into v_order_id;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_qty:=nullif(v_item->>'quantity','')::numeric;if v_qty is null or v_qty<=0 then continue;end if;
    select * into v_product from public.products where id=(v_item->>'product_id')::uuid and store_id=p_store_id and is_available for share;
    if not found then raise exception 'PRODUTO_INDISPONIVEL';end if;
    insert into public.order_items(order_id,product_id,product_name,quantity,unit_price) values(v_order_id,v_product.id,v_product.name,v_qty,v_product.price) returning id into v_order_item_id;
    v_subtotal:=v_subtotal+(v_product.price*v_qty);
    for v_recipe in select pi.ingredient_id,pi.quantity,i.name from public.product_ingredients pi join public.ingredients i on i.id=pi.ingredient_id where pi.product_id=v_product.id order by pi.ingredient_id loop
      v_required:=v_recipe.quantity*v_qty;
      update public.ingredients set current_stock=current_stock-v_required where id=v_recipe.ingredient_id and store_id=p_store_id and current_stock>=v_required;
      if not found then raise exception 'ESTOQUE_INSUFICIENTE: %',v_recipe.name;end if;
      insert into public.stock_movements(store_id,ingredient_id,order_id,created_by,movement_type,quantity,notes) values(p_store_id,v_recipe.ingredient_id,v_order_id,v_user,'sale',-v_required,'Baixa automática da venda');
    end loop;
  end loop;
  if v_subtotal<=0 then raise exception 'PEDIDO_SEM_ITENS_VALIDOS';end if;
  v_total:=greatest(v_subtotal-greatest(coalesce(p_discount,0),0),0);
  update public.orders set subtotal=v_subtotal,discount=least(greatest(coalesce(p_discount,0),0),v_subtotal) where id=v_order_id;
  insert into public.cash_movements(store_id,cash_session_id,order_id,created_by,movement_type,payment_method,amount,description) values(p_store_id,v_cash_id,v_order_id,v_user,'sale',p_payment_method,v_total,'Venda #'||v_order_id::text);
  return v_order_id;
end;$$;

create or replace function public.adjust_stock(p_store_id uuid,p_ingredient_id uuid,p_quantity numeric,p_movement_type public.stock_movement_type,p_notes text default null)
returns numeric language plpgsql security invoker set search_path=''
as $$
declare v_new_stock numeric(14,3);
begin
  if auth.uid() is null or not private.is_store_member(p_store_id) then raise exception using errcode='42501',message='ACESSO_NEGADO_LOJA';end if;
  if not private.is_store_operational(p_store_id) then raise exception 'EMPRESA_BLOQUEADA_INADIMPLENCIA';end if;
  if p_quantity=0 then raise exception 'QUANTIDADE_INVALIDA';end if;
  update public.ingredients set current_stock=current_stock+p_quantity where id=p_ingredient_id and store_id=p_store_id and current_stock+p_quantity>=0 returning current_stock into v_new_stock;
  if v_new_stock is null then raise exception 'ESTOQUE_NEGATIVO_NAO_PERMITIDO';end if;
  insert into public.stock_movements(store_id,ingredient_id,created_by,movement_type,quantity,notes) values(p_store_id,p_ingredient_id,auth.uid(),p_movement_type,p_quantity,nullif(btrim(p_notes),''));
  return v_new_stock;
end;$$;

revoke all on function public.create_sale(uuid,public.order_channel,text,numeric,jsonb,text) from public,anon;
revoke all on function public.adjust_stock(uuid,uuid,numeric,public.stock_movement_type,text) from public,anon;
grant execute on function public.create_sale(uuid,public.order_channel,text,numeric,jsonb,text) to authenticated;
grant execute on function public.adjust_stock(uuid,uuid,numeric,public.stock_movement_type,text) to authenticated;
