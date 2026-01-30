import { createClient } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

export const supabase = createClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY);

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
