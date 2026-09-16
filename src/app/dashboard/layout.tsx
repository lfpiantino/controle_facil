import {redirect} from "next/navigation";import {AppShell} from "@/components/app-shell";import {createClient} from "@/lib/supabase/server";
export default async function DashboardLayout({children}:{children:React.ReactNode}){const s=await createClient();const {data:{user}}=await s.auth.getUser();if(!user)redirect("/login");return <AppShell>{children}</AppShell>}
