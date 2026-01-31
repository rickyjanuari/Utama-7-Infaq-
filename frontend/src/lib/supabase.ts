import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/public';

// Lazy initialization - create client only when first accessed
let _supabase: SupabaseClient | null = null;

export function getSupabase(): SupabaseClient {
    if (!_supabase) {
        const supabaseUrl = env.PUBLIC_SUPABASE_URL || '';
        const supabaseAnonKey = env.PUBLIC_SUPABASE_ANON_KEY || '';

        if (!supabaseUrl || !supabaseAnonKey) {
            console.error('Supabase env vars missing:', { supabaseUrl: !!supabaseUrl, supabaseAnonKey: !!supabaseAnonKey });
        }

        _supabase = createClient(supabaseUrl, supabaseAnonKey);
    }
    return _supabase;
}

export function getSupabaseConfig() {
    return {
        url: env.PUBLIC_SUPABASE_URL,
        key: env.PUBLIC_SUPABASE_ANON_KEY
    };
}

// For backward compatibility - getter that lazily initializes
export const supabase = new Proxy({} as SupabaseClient, {
    get(_, prop) {
        return Reflect.get(getSupabase(), prop);
    }
});

export type Role = 'admin' | 'guru' | 'kepala_sekolah';

export interface Profile {
    id: string;
    email: string;
    name: string;
    role: Role;
    can_view_penyisihan: boolean;
    created_at: string;
    updated_at: string;
}

export interface Transaction {
    id: string;
    user_id: string;
    user_name?: string;
    type: 'infaq_masuk' | 'pengeluaran';
    amount: number;
    description: string;
    category?: string;
    transaction_date: string;
    is_penyisihan: boolean;
    created_at: string;
    metadata?: any;
}

export interface TransactionSummary {
    total_infaq: number;
    total_pengeluaran: number;
    saldo: number;
    total_penyisihan?: number;
}

export interface MonthlyReport {
    month: string;
    total_infaq: number;
    total_pengeluaran: number;
    saldo: number;
}
