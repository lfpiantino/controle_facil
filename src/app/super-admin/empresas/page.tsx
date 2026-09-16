import { AlertTriangle, Building2, CheckCircle2, Clock3, ShieldCheck } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { createCompany, updateCompany } from "./actions";

type Company = {
  store_id: string; name: string; slug: string; owner_email: string | null;
  legal_name: string | null; document: string | null; contact_email: string | null;
  plan: string | null; billing_status: string | null; due_date: string | null;
  grace_until: string | null; blocked_at: string | null; block_reason: string | null;
};
const statusLabel: Record<string,string> = {trial:"Período de teste",active:"Em dia",past_due:"Em atraso",suspended:"Suspensa",cancelled:"Cancelada"};
const dateValue = (value: string | null) => value ? value.slice(0, 10) : "";

export default async function CompaniesPage({searchParams}:{searchParams:Promise<{erro?:string;sucesso?:string}>}) {
  const params = await searchParams;
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_list_companies");
  const companies = (data ?? []) as Company[];
  const active = companies.filter((company) => ["active","trial"].includes(company.billing_status ?? "active")).length;
  const late = companies.filter((company) => company.billing_status === "past_due").length;
  const blocked = companies.filter((company) => ["suspended","cancelled"].includes(company.billing_status ?? "")).length;

  return <div className="page admin-companies">
    <header className="page-head"><div><span>SUPER ADMIN</span><h1>Empresas</h1><p>Cadastre clientes e controle planos, vencimentos e acesso ao sistema.</p></div><div className="admin-badge"><ShieldCheck size={18}/> Acesso global</div></header>
    {params.erro || error ? <div className="alert">{params.erro ?? error?.message}</div> : null}
    {params.sucesso ? <div className="notice-success"><CheckCircle2 size={18}/>{params.sucesso}</div> : null}
    <section className="stats">
      <article className="stat-card"><div className="stat-icon blue"><Building2 size={20}/></div><div><p>Empresas</p><strong>{companies.length}</strong><small>cadastradas na plataforma</small></div></article>
      <article className="stat-card"><div className="stat-icon green"><CheckCircle2 size={20}/></div><div><p>Em operação</p><strong>{active}</strong><small>ativas ou em teste</small></div></article>
      <article className="stat-card"><div className="stat-icon"><Clock3 size={20}/></div><div><p>Em atraso</p><strong>{late}</strong><small>com carência configurável</small></div></article>
      <article className="stat-card"><div className="stat-icon red"><AlertTriangle size={20}/></div><div><p>Bloqueadas</p><strong>{blocked}</strong><small>sem novas operações</small></div></article>
    </section>
    <details className="surface company-create">
      <summary>+ Cadastrar nova empresa</summary>
      <form action={createCompany} className="company-form">
        <label>Nome fantasia<input name="name" required placeholder="Lanches da Praça"/></label><label>Endereço do cardápio<input name="slug" required placeholder="lanches-da-praca"/></label><label>E-mail do proprietário<input name="owner_email" type="email" required placeholder="dono@empresa.com"/></label>
        <label>Razão social<input name="legal_name"/></label><label>CPF/CNPJ<input name="document"/></label><label>E-mail financeiro<input name="contact_email" type="email"/></label>
        <label>Plano<select name="plan" defaultValue="free"><option value="free">Gratuito</option><option value="starter">Starter</option><option value="pro">Pro</option></select></label><label>Vencimento<input name="due_date" type="date"/></label>
        <div className="form-wide"><button className="button primary">Cadastrar empresa</button></div>
      </form>
      <p className="form-help">O proprietário precisa ter criado uma conta no sistema antes do vínculo.</p>
    </details>
    <section className="company-list">
      {companies.map((company) => <details className="surface company-card" key={company.store_id}>
        <summary><div className="company-avatar"><Building2 size={20}/></div><div><strong>{company.name}</strong><span>{company.owner_email ?? "Sem proprietário"} · /cardapio/{company.slug}</span></div><span className={`status-pill status-${company.billing_status ?? "active"}`}>{statusLabel[company.billing_status ?? "active"]}</span></summary>
        <form action={updateCompany} className="company-form">
          <input type="hidden" name="store_id" value={company.store_id}/>
          <label>Nome fantasia<input name="name" required defaultValue={company.name}/></label><label>Endereço do cardápio<input name="slug" required defaultValue={company.slug}/></label><label>Proprietário<input disabled value={company.owner_email ?? "Não informado"}/></label>
          <label>Razão social<input name="legal_name" defaultValue={company.legal_name ?? ""}/></label><label>CPF/CNPJ<input name="document" defaultValue={company.document ?? ""}/></label><label>E-mail financeiro<input name="contact_email" type="email" defaultValue={company.contact_email ?? ""}/></label>
          <label>Plano<select name="plan" defaultValue={company.plan ?? "free"}><option value="free">Gratuito</option><option value="starter">Starter</option><option value="pro">Pro</option></select></label>
          <label>Situação<select name="billing_status" defaultValue={company.billing_status ?? "active"}><option value="trial">Período de teste</option><option value="active">Em dia</option><option value="past_due">Em atraso</option><option value="suspended">Suspensa</option><option value="cancelled">Cancelada</option></select></label>
          <label>Vencimento<input name="due_date" type="date" defaultValue={dateValue(company.due_date)}/></label><label>Carência até<input name="grace_until" type="date" defaultValue={dateValue(company.grace_until)}/></label>
          <label className="form-wide">Motivo do bloqueio<input name="block_reason" defaultValue={company.block_reason ?? ""} placeholder="Ex.: mensalidade vencida"/></label>
          <div className="form-wide company-actions"><button className="button primary">Salvar alterações</button><a className="button ghost" href={`/cardapio/${company.slug}`} target="_blank" rel="noreferrer">Abrir cardápio</a></div>
        </form>
      </details>)}
      {companies.length === 0 ? <div className="surface empty"><Building2 size={32}/><h3>Nenhuma empresa cadastrada</h3><p>Use o formulário acima para cadastrar a primeira.</p></div> : null}
    </section>
  </div>;
}
