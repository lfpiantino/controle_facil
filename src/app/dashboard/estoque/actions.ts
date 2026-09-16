"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { formText, friendlyError, requireStore } from "@/lib/current-store";

export async function createIngredient(formData:FormData){
  const {supabase,store}=await requireStore();
  const {error}=await supabase.from("ingredients").insert({store_id:store.id,name:formText(formData,"name"),unit:formText(formData,"unit"),current_stock:Number(formText(formData,"current_stock")||0),minimum_stock:Number(formText(formData,"minimum_stock")||0),average_cost:Number(formText(formData,"average_cost")||0)});
  if(error)redirect(`/dashboard/estoque?erro=${encodeURIComponent(friendlyError(error.message))}`);
  revalidatePath("/dashboard/estoque");redirect("/dashboard/estoque?sucesso=Ingrediente cadastrado.");
}

export async function adjustStock(formData:FormData){
  const {supabase,store}=await requireStore();
  const kind=formText(formData,"movement_type");
  const raw=Number(formText(formData,"quantity"));
  const quantity=["waste","internal_use"].includes(kind)?-Math.abs(raw):Math.abs(raw);
  const {error}=await supabase.rpc("adjust_stock",{p_store_id:store.id,p_ingredient_id:formText(formData,"ingredient_id"),p_quantity:quantity,p_movement_type:kind,p_notes:formText(formData,"notes")||null});
  if(error)redirect(`/dashboard/estoque?erro=${encodeURIComponent(friendlyError(error.message))}`);
  revalidatePath("/dashboard/estoque");redirect("/dashboard/estoque?sucesso=Estoque atualizado.");
}
