import { QRCode } from "@/components/qr-code";
import { requireStore } from "@/lib/current-store";
import { createAddon, createCategory, createProduct, linkAddon, toggleProduct } from "./actions";

export default async function Page({searchParams}:{searchParams:Promise<{erro?:string;sucesso?:string}>}) {
  const params=await searchParams;
  const {supabase,store}=await requireStore();
  const [{data:categories},{data:ingredients},{data:products},{data:addons}]=await Promise.all([
    supabase.from("categories").select("id,name").eq("store_id",store.id).order("sort_order"),
    supabase.from("ingredients").select("id,name,unit").eq("store_id",store.id).order("name"),
    supabase.from("products").select("id,name,description,price,is_available,categories(name),product_ingredients(quantity,ingredients(name,unit)),product_addons(addons(id,name,price))").eq("store_id",store.id).order("sort_order"),
    supabase.from("addons").select("id,name,price,ingredient_id,is_available").eq("store_id",store.id).order("name"),
  ]);
  const base=process.env.NEXT_PUBLIC_APP_URL??"http://localhost:3000";
  return <div className="page">
    <header className="page-head"><div><span>CARDÁPIO DIGITAL</span><h1>Produtos e receitas</h1><p>O cadastro alimenta o PDV, a baixa de estoque e o menu público.</p></div></header>
    {params.erro?<div className="flash error">{params.erro}</div>:null}{params.sucesso?<div className="flash">{params.sucesso}</div>:null}
    <section className="ops-grid">
      <div className="ops-stack">
        <article className="surface"><div className="section-head"><h2>Produtos</h2><span className="muted">{products?.length??0} cadastrados</span></div><div className="product-list">
          {products?.map((p)=><div className="product-row" key={p.id}><div><strong>{p.name}</strong><p>{p.description||"Sem descrição"}</p><small>{p.product_ingredients?.length?`${p.product_ingredients.length} ingrediente(s) na receita`:"Receita sem ingredientes"}</small><div className="tag-list">{p.product_addons?.map(pa=><span key={(pa.addons as unknown as {id:string}).id}>{(pa.addons as unknown as {name:string}).name}</span>)}</div></div><div><b>{Number(p.price).toLocaleString("pt-BR",{style:"currency",currency:"BRL"})}</b><form action={toggleProduct}><input type="hidden" name="id" value={p.id}/><input type="hidden" name="available" value={String(p.is_available)}/><button className="button ghost">{p.is_available?"Pausar":"Ativar"}</button></form></div></div>)}
          {!products?.length?<p className="muted">Cadastre o primeiro produto ao lado.</p>:null}
        </div></article>
        <article className="surface"><h2>Novo produto</h2><form action={createProduct} className="compact-form two">
          <label>Nome<input name="name" required placeholder="Cachorro-quente completo"/></label><label>Preço<input name="price" required type="number" step="0.01" min="0"/></label>
          <label>Categoria<select name="category_id"><option value="">Sem categoria</option>{categories?.map(c=><option value={c.id} key={c.id}>{c.name}</option>)}</select></label><label>Descrição<input name="description"/></label>
          <div className="form-span"><b>Receita por unidade</b><p className="muted">Informe quanto de cada ingrediente será descontado em uma venda.</p><div className="recipe-list">{ingredients?.map(i=><label className="recipe-item" key={i.id}><span>{i.name} ({i.unit})</span><input name={`recipe_${i.id}`} type="number" step="0.001" min="0" placeholder="0"/></label>)}</div></div>
          <div className="form-span"><button className="button primary">Salvar produto</button></div>
        </form></article>
      </div>
      <aside className="ops-stack">
        <article className="surface"><h2>Nova categoria</h2><form action={createCategory} className="compact-form"><label>Nome<input name="name" required placeholder="Cachorros-quentes"/></label><button className="button primary">Criar categoria</button></form></article>
        <article className="surface"><h2>Adicionais</h2><form action={createAddon} className="compact-form"><label>Nome<input name="name" required placeholder="Bacon extra"/></label><label>Preço<input name="price" required type="number" min="0" step="0.01"/></label><label>Ingrediente baixado<select name="ingredient_id"><option value="">Sem baixa</option>{ingredients?.map(i=><option key={i.id} value={i.id}>{i.name}</option>)}</select></label><button className="button primary">Criar adicional</button></form><hr className="soft-rule"/><form action={linkAddon} className="compact-form"><label>Produto<select name="product_id" required><option value="">Selecione</option>{products?.map(p=><option key={p.id} value={p.id}>{p.name}</option>)}</select></label><label>Adicional<select name="addon_id" required><option value="">Selecione</option>{addons?.map(a=><option key={a.id} value={a.id}>{a.name}</option>)}</select></label><button className="button">Vincular</button></form></article>
        <article className="surface qr-card"><h2>QR Code permanente</h2><QRCode value={`${base}/cardapio/${store.slug}`}/><a href={`/cardapio/${store.slug}`} target="_blank">Abrir cardápio público</a></article>
      </aside>
    </section>
  </div>;
}
