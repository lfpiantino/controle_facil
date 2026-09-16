-- Operações administrativas do MVP multiempresa.
create or replace function public.admin_list_companies()
returns table (store_id uuid,name text,slug text,owner_email text,legal_name text,document text,contact_email text,plan text,billing_status text,due_date date,grace_until timestamptz,blocked_at timestamptz,block_reason text,created_at timestamptz)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not private.is_super_admin() then raise exception using errcode='42501',message='ACESSO_NEGADO_SUPER_ADMIN'; end if;
  return query select s.id,s.name,s.slug,u.email::text,ca.legal_name,ca.document,ca.contact_email,ca.plan,ca.billing_status,ca.due_date,ca.grace_until,ca.blocked_at,ca.block_reason,s.created_at
  from public.stores s left join auth.users u on u.id=s.owner_id left join public.company_accounts ca on ca.store_id=s.id order by s.created_at desc;
end; $$;

create or replace function public.admin_create_company(p_name text,p_slug text,p_owner_email text,p_legal_name text default null,p_document text default null,p_contact_email text default null,p_plan text default 'free',p_billing_status text default 'active',p_due_date date default null,p_grace_until timestamptz default null)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare owner_user_id uuid; new_store_id uuid; clean_slug text;
begin
  if not private.is_super_admin() then raise exception using errcode='42501',message='ACESSO_NEGADO_SUPER_ADMIN'; end if;
  if nullif(btrim(p_name),'') is null then raise exception 'NOME_DA_EMPRESA_OBRIGATORIO'; end if;
  clean_slug:=trim(both '-' from regexp_replace(lower(coalesce(p_slug,'')),'[^a-z0-9]+','-','g'));
  if clean_slug='' then raise exception 'SLUG_DA_EMPRESA_OBRIGATORIO'; end if;
  select id into owner_user_id from auth.users where lower(email)=lower(btrim(p_owner_email)) limit 1;
  if owner_user_id is null then raise exception 'PROPRIETARIO_NAO_ENCONTRADO'; end if;
  insert into public.stores(owner_id,name,slug) values(owner_user_id,btrim(p_name),clean_slug) returning id into new_store_id;
  insert into public.company_accounts(store_id,legal_name,document,contact_email,plan,billing_status,due_date,grace_until,blocked_at)
  values(new_store_id,nullif(btrim(p_legal_name),''),nullif(btrim(p_document),''),nullif(btrim(p_contact_email),''),p_plan,p_billing_status,p_due_date,p_grace_until,case when p_billing_status in ('suspended','cancelled') then now() else null end);
  return new_store_id;
end; $$;

create or replace function public.admin_update_company(p_store_id uuid,p_name text,p_slug text,p_legal_name text,p_document text,p_contact_email text,p_plan text,p_billing_status text,p_due_date date,p_grace_until timestamptz,p_block_reason text)
returns void language plpgsql security definer set search_path = ''
as $$
declare clean_slug text;
begin
  if not private.is_super_admin() then raise exception using errcode='42501',message='ACESSO_NEGADO_SUPER_ADMIN'; end if;
  clean_slug:=trim(both '-' from regexp_replace(lower(coalesce(p_slug,'')),'[^a-z0-9]+','-','g'));
  update public.stores set name=btrim(p_name),slug=clean_slug where id=p_store_id;
  if not found then raise exception 'EMPRESA_NAO_ENCONTRADA'; end if;
  insert into public.company_accounts(store_id,legal_name,document,contact_email,plan,billing_status,due_date,grace_until,blocked_at,block_reason)
  values(p_store_id,nullif(btrim(p_legal_name),''),nullif(btrim(p_document),''),nullif(btrim(p_contact_email),''),p_plan,p_billing_status,p_due_date,p_grace_until,case when p_billing_status in ('suspended','cancelled') then now() else null end,nullif(btrim(p_block_reason),''))
  on conflict(store_id) do update set legal_name=excluded.legal_name,document=excluded.document,contact_email=excluded.contact_email,plan=excluded.plan,billing_status=excluded.billing_status,due_date=excluded.due_date,grace_until=excluded.grace_until,blocked_at=excluded.blocked_at,block_reason=excluded.block_reason;
end; $$;

revoke all on function public.admin_list_companies() from public,anon;
revoke all on function public.admin_create_company(text,text,text,text,text,text,text,text,date,timestamptz) from public,anon;
revoke all on function public.admin_update_company(uuid,text,text,text,text,text,text,text,date,timestamptz,text) from public,anon;
grant execute on function public.admin_list_companies() to authenticated;
grant execute on function public.admin_create_company(text,text,text,text,text,text,text,text,date,timestamptz) to authenticated;
grant execute on function public.admin_update_company(uuid,text,text,text,text,text,text,text,date,timestamptz,text) to authenticated;

do $$
declare luiz_id uuid; new_store_id uuid;
begin
  select id into luiz_id from auth.users where lower(email)=lower('luiz.piantino@gmail.com') limit 1;
  if luiz_id is not null and not exists(select 1 from public.store_members where user_id=luiz_id) then
    alter table public.stores disable trigger on_store_created;
    insert into public.stores(owner_id,name,slug) values(luiz_id,'Loja do Luiz','loja-do-luiz') returning id into new_store_id;
    alter table public.stores enable trigger on_store_created;
    insert into public.store_members(store_id,user_id,role) values(new_store_id,luiz_id,'owner');
    insert into public.company_accounts(store_id,legal_name,contact_email,plan,billing_status) values(new_store_id,'Loja do Luiz','luiz.piantino@gmail.com','free','active');
  end if;
exception when others then alter table public.stores enable trigger on_store_created; raise;
end $$;
