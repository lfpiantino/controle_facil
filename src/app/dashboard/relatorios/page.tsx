import {Banknote,ChartNoAxesColumn,ShoppingBag,TicketCheck} from "lucide-react";
import {StatCard} from "@/components/stat-card";
import {requireStore} from "@/lib/current-store";

const money=(value:number)=>value.toLocaleString("pt-BR",{style:"currency",currency:"BRL"});

export default async function Page({searchParams}:{searchParams:Promise<{periodo?:string}>}){
  const params=await searchParams;
  const days=[7,30,90].includes(Number(params.periodo))?Number(params.periodo):30;
  const start=new Date();start.setDate(start.getDate()-days);
  const {supabase,store}=await requireStore();
  const [{data:orders},{data:items},{data:ingredients}]=await Promise.all([
    supabase.from("orders").select("id,total,channel,payment_method,status,created_at").eq("store_id",store.id).gte("created_at",start.toISOString()).neq("status","cancelled"),
    supabase.from("order_items").select("product_name,quantity,line_total,orders!inner(store_id,status,created_at)").eq("orders.store_id",store.id).neq("orders.status","cancelled").gte("orders.created_at",start.toISOString()),
    supabase.from("ingredients").select("name,current_stock,minimum_stock,unit").eq("store_id",store.id).order("current_stock"),
  ]);
  const sales=(orders??[]).reduce((sum,order)=>sum+Number(order.total),0),count=orders?.length??0,ticket=count?sales/count:0,delivery=(orders??[]).filter(order=>order.channel==="delivery").length;
  const productTotals=new Map<string,{qty:number;total:number}>();
  for(const item of items??[]){const value=productTotals.get(item.product_name)??{qty:0,total:0};value.qty+=Number(item.quantity);value.total+=Number(item.line_total);productTotals.set(item.product_name,value);}
  const ranking=[...productTotals.entries()].sort((a,b)=>b[1].qty-a[1].qty).slice(0,10);
  const payments=new Map<string,number>();
  for(const order of orders??[]){const method=order.payment_method??"Não informado";payments.set(method,(payments.get(method)??0)+Number(order.total));}
  const low=(ingredients??[]).filter(item=>Number(item.current_stock)<=Number(item.minimum_stock));
  return <div className="page"><header className="page-head"><div><span>GESTÃO</span><h1>Relatórios</h1><p>Resultado comercial dos últimos {days} dias.</p></div><form><select name="periodo" defaultValue={String(days)}><option value="7">7 dias</option><option value="30">30 dias</option><option value="90">90 dias</option></select><button className="button">Atualizar</button></form></header><section className="stats"><StatCard label="Faturamento" value={money(sales)} hint={`${count} pedidos`} icon={Banknote} tone="green"/><StatCard label="Ticket médio" value={money(ticket)} hint="por pedido" icon={TicketCheck}/><StatCard label="Pedidos" value={String(count)} hint="não cancelados" icon={ShoppingBag} tone="blue"/><StatCard label="Delivery" value={String(delivery)} hint={`${count?Math.round(delivery/count*100):0}% dos pedidos`} icon={ChartNoAxesColumn}/></section><section className="report-grid"><article className="surface"><h2>Produtos mais vendidos</h2><table className="data-table"><thead><tr><th>Produto</th><th>Qtd.</th><th>Receita base</th></tr></thead><tbody>{ranking.map(([name,value])=><tr key={name}><td><strong>{name}</strong></td><td>{value.qty}</td><td>{money(value.total)}</td></tr>)}</tbody></table>{!ranking.length?<p className="muted">Ainda não há vendas no período.</p>:null}</article><article className="surface"><h2>Por pagamento</h2><div className="metric-list">{[...payments.entries()].sort((a,b)=>b[1]-a[1]).map(([name,value])=><div key={name}><span>{name}</span><strong>{money(value)}</strong></div>)}</div><hr className="soft-rule"/><h2>Estoque crítico</h2><div className="metric-list">{low.slice(0,8).map(item=><div key={item.name}><span>{item.name}</span><strong className="stock-low">{Number(item.current_stock)} {item.unit}</strong></div>)}</div>{!low.length?<p className="stock-ok">Estoque saudável.</p>:null}</article></section></div>;
}
