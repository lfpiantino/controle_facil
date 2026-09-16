import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function requireStore() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  const { data: membership } = await supabase.from("store_members").select("store_id,role").eq("user_id", user.id).limit(1).maybeSingle();
  if (!membership) redirect("/dashboard/configuracoes");
  const { data: store } = await supabase.from("stores").select("id,name,slug").eq("id", membership.store_id).single();
  if (!store) redirect("/dashboard/configuracoes");
  return { supabase, user, store, role: membership.role };
}

export function formText(formData: FormData, name: string) {
  return String(formData.get(name) ?? "").trim();
}

export function friendlyError(message: string) {
  const known: Record<string,string> = {
    CAIXA_FECHADO: "Abra o caixa antes de registrar vendas.",
    PEDIDO_SEM_ITENS: "Informe ao menos um produto.",
    PEDIDO_SEM_ITENS_VALIDOS: "Informe uma quantidade válida.",
    PRODUTO_INDISPONIVEL: "Um dos produtos não está disponível.",
    EMPRESA_BLOQUEADA_INADIMPLENCIA: "A empresa está bloqueada. Regularize a assinatura.",
    ESTOQUE_NEGATIVO_NAO_PERMITIDO: "A movimentação deixaria o estoque negativo.",
    MESA_OBRIGATORIA: "Selecione uma mesa para a comanda.",
    ENDERECO_OBRIGATORIO: "Informe o endereço para o delivery.",
    CLIENTE_INVALIDO: "O cliente selecionado não pertence a esta loja.",
    MESA_INVALIDA: "A mesa selecionada não está disponível.",
    TRANSICAO_STATUS_INVALIDA: "Esse avanço de status não é permitido.",
    PEDIDO_FINALIZADO: "Um pedido finalizado não pode ser cancelado.",
    CAIXA_DA_VENDA_FECHADO: "O caixa desta venda já foi fechado.",
  };
  const stock = message.match(/ESTOQUE_INSUFICIENTE:\s*(.+)/);
  if (stock) return `Estoque insuficiente: ${stock[1]}.`;
  const key = Object.keys(known).find((item) => message.includes(item));
  return key ? known[key] : message;
}
