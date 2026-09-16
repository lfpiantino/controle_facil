import {Banknote,Boxes,CircleAlert,ShoppingBag} from "lucide-react";
import {StatCard} from "@/components/stat-card";
import {requireStore} from "@/lib/current-store";

export default async function Dashboard(){
  const {supabase,store}=await requireStore();
  const start=new Date();start.setHours(0,0,0,0);
  const [{data:orders},{data:ingredients},{data:cash}]=await Promise.all([
    supabase.from("orders").select("id,order_number,total,status,channel,created_at").eq("store_id",store.id).gte("created_at",start.toISOString()).neq("status","cancelled").order("created_at",{ascending:false}),
    supabase.from("ingredients").select("current_stock,minimum_stock").eq("store_id",store.id),
    supabase.from("cash_sessions").select("id,status").eq("store_id",store.id).eq("status","open").maybeSingle(),
  ]);
  const sales=(orders??[]).reduce((sum,o)=>sum+Number(o.total),0);
  const lowStock=(ingredients??[]).filter(i=>Number(i.current_stock)<=Number(i.minimum_stock)).length;
  return <div className="page"><header className="page-head"><div><span>PAINEL</span><h1>Visão geral</h1><p>Acompanhe a operação da {store.name} em tempo real.</p></div><a className="button primary" href="/dashboard/vendas">+ Nova venda</a></header><section className="stats"><StatCard label="Pedidos de hoje" value={String(orders?.length??0)} hint="pedidos não cancelados" icon={ShoppingBag}/><StatCard label="Vendas do dia" value={sales.toLocaleString("pt-BR",{style:"currency",currency:"BRL"})} hint="vendas registradas" icon={Banknote} tone="green"/><StatCard label="Estoque baixo" value={String(lowStock)} hint="itens no mínimo ou abaixo" icon={CircleAlert} tone="red"/><StatCard label="Situação do caixa" value={cash?"Aberto":"Fechado"} hint={cash?"pronto para vender":"abra para iniciar vendas"} icon={Boxes} tone="blue"/></section><section className="dashboard-grid"><article className="surface"><div className="surface-title"><h2>Pedidos de hoje</h2><a href="/dashboard/vendas">Ver todos</a></div>{orders?.length?<table className="data-table"><thead><tr><th>Pedido</th><th>Canal</th><th>Status</th><th>Total</th></tr></thead><tbody>{orders.slice(0,8).map(o=><tr key={o.id}><td>#{o.order_number}</td><td>{o.channel}</td><td>{o.status}</td><td>{Number(o.total).toLocaleString("pt-BR",{style:"currency",currency:"BRL"})}</td></tr>)}</tbody></table>:<div className="empty"><ShoppingBag size={32}/><h3>Nenhum pedido registrado</h3><p>Quando uma venda for criada, ela aparecerá aqui.</p></div>}</article><article className="surface quick"><h2>Ações rápidas</h2><a href="/dashboard/caixa"><b>{cash?"Gerenciar caixa":"Abrir o caixa"}</b><span>Movimentos e fechamento do turno</span></a><a href="/dashboard/cardapio"><b>Cadastrar produto</b><span>Monte seu cardápio e receitas</span></a><a href="/dashboard/estoque"><b>Atualizar estoque</b><span>Entradas, perdas e inventário</span></a></article></section></div>;
}
