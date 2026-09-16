import type {LucideIcon} from "lucide-react";
export function StatCard({label,value,hint,icon:Icon,tone="orange"}:{label:string;value:string;hint:string;icon:LucideIcon;tone?:string}){return <article className="stat-card"><div className={`stat-icon ${tone}`}><Icon size={20}/></div><div><p>{label}</p><strong>{value}</strong><small>{hint}</small></div></article>}
