import { redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { createClient } from "@/lib/supabase/server";

export default async function SuperAdminLayout({children}:{children:React.ReactNode}) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  const { data: admin } = await supabase.from("platform_admins").select("user_id").eq("user_id", user.id).eq("is_active", true).maybeSingle();
  if (!admin) redirect("/dashboard");
  return <AppShell isSuperAdmin>{children}</AppShell>;
}
