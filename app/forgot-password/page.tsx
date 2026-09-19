import { PasswordForm } from '@/components/password-form';
import { hasSupabaseConfig } from '@/lib/env';
import SetupPage from '@/app/setup/page';
export default function Page(){return hasSupabaseConfig()?<PasswordForm/>:<SetupPage/>;}
