import ClientPage from "./client-page";
import { hasSupabaseConfig } from "@/lib/env";
import SetupPage from "@/app/setup/page";
export default function Page(){return hasSupabaseConfig()?<ClientPage/>:<SetupPage/>;}
