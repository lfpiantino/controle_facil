"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

const text = (formData: FormData, field: string) => String(formData.get(field) ?? "").trim();
const nullable = (value: string) => value || null;

function errorMessage(message: string) {
  if (message.includes("PROPRIETARIO_NAO_ENCONTRADO")) return "O proprietário precisa criar a conta antes de ser vinculado.";
  if (message.includes("duplicate key") && message.includes("slug")) return "Este endereço de cardápio já está em uso.";
  if (message.includes("duplicate key") && message.includes("document")) return "Este CPF/CNPJ já está cadastrado.";
  if (message.includes("ACESSO_NEGADO")) return "Acesso permitido somente ao super administrador.";
  return message;
}

export async function createCompany(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_create_company", {
    p_name: text(formData, "name"), p_slug: text(formData, "slug"),
    p_owner_email: text(formData, "owner_email"), p_legal_name: nullable(text(formData, "legal_name")),
    p_document: nullable(text(formData, "document")), p_contact_email: nullable(text(formData, "contact_email")),
    p_plan: text(formData, "plan") || "free", p_billing_status: "active",
    p_due_date: nullable(text(formData, "due_date")), p_grace_until: null,
  });
  if (error) redirect(`/super-admin/empresas?erro=${encodeURIComponent(errorMessage(error.message))}`);
  revalidatePath("/super-admin/empresas");
  redirect("/super-admin/empresas?sucesso=Empresa cadastrada com sucesso.");
}

export async function updateCompany(formData: FormData) {
  const supabase = await createClient();
  const status = text(formData, "billing_status");
  const graceDate = text(formData, "grace_until");
  const { error } = await supabase.rpc("admin_update_company", {
    p_store_id: text(formData, "store_id"), p_name: text(formData, "name"), p_slug: text(formData, "slug"),
    p_legal_name: nullable(text(formData, "legal_name")), p_document: nullable(text(formData, "document")),
    p_contact_email: nullable(text(formData, "contact_email")), p_plan: text(formData, "plan"),
    p_billing_status: status, p_due_date: nullable(text(formData, "due_date")),
    p_grace_until: status === "past_due" && graceDate ? new Date(`${graceDate}T23:59:59`).toISOString() : null,
    p_block_reason: nullable(text(formData, "block_reason")),
  });
  if (error) redirect(`/super-admin/empresas?erro=${encodeURIComponent(errorMessage(error.message))}`);
  revalidatePath("/super-admin/empresas");
  redirect("/super-admin/empresas?sucesso=Empresa atualizada.");
}
