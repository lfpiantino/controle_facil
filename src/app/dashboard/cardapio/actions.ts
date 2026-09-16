"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { formText, friendlyError, requireStore } from "@/lib/current-store";

export async function createCategory(formData: FormData) {
  const { supabase, store } = await requireStore();
  const { error } = await supabase.from("categories").insert({store_id:store.id,name:formText(formData,"name")});
  if (error) redirect(`/dashboard/cardapio?erro=${encodeURIComponent(friendlyError(error.message))}`);
  revalidatePath("/dashboard/cardapio");
  redirect("/dashboard/cardapio?sucesso=Categoria criada.");
}

export async function createProduct(formData: FormData) {
  const { supabase, store } = await requireStore();
  const { data: product, error } = await supabase.from("products").insert({
    store_id:store.id, category_id:formText(formData,"category_id")||null,
    name:formText(formData,"name"), description:formText(formData,"description")||null,
    price:Number(formText(formData,"price").replace(",",".")), is_available:true,
  }).select("id").single();
  if (error || !product) redirect(`/dashboard/cardapio?erro=${encodeURIComponent(friendlyError(error?.message??"Não foi possível criar o produto."))}`);
  const recipes:Array<{product_id:string;ingredient_id:string;quantity:number}> = [];
  for (const [key,value] of formData.entries()) if (key.startsWith("recipe_") && Number(value)>0) recipes.push({product_id:product.id,ingredient_id:key.slice(7),quantity:Number(value)});
  if (recipes.length) {
    const { error: recipeError } = await supabase.from("product_ingredients").insert(recipes);
    if (recipeError) redirect(`/dashboard/cardapio?erro=${encodeURIComponent(friendlyError(recipeError.message))}`);
  }
  revalidatePath("/dashboard/cardapio");
  redirect("/dashboard/cardapio?sucesso=Produto e receita cadastrados.");
}

export async function toggleProduct(formData: FormData) {
  const { supabase, store } = await requireStore();
  const id=formText(formData,"id"), available=formText(formData,"available")==="true";
  await supabase.from("products").update({is_available:!available}).eq("id",id).eq("store_id",store.id);
  revalidatePath("/dashboard/cardapio");
}
