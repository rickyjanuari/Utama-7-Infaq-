import { browser } from '$app/environment';
import { writable, derived, get } from 'svelte/store';
import { supabase, type Profile } from '$lib/supabase';

interface AuthState {
    user: Profile | null;
    loading: boolean;
    initialized: boolean;
}

function createAuthStore() {
    const store = writable<AuthState>({
        user: null,
        loading: true,
        initialized: false
    });

    return {
        subscribe: store.subscribe,

        init: async () => {
            if (!browser) return;

            const { data: { session } } = await supabase.auth.getSession();

            if (session?.user) {
                const { data: profile } = await supabase
                    .from('profiles')
                    .select('*')
                    .eq('id', session.user.id)
                    .maybeSingle();

                if (profile) {
                    store.update(s => ({ ...s, user: profile, loading: false, initialized: true }));
                    return;
                }
            }

            store.update(s => ({ ...s, user: null, loading: false, initialized: true }));

            // Listen for auth changes
            supabase.auth.onAuthStateChange(async (event, session) => {
                if (session?.user) {
                    const { data: profile } = await supabase
                        .from('profiles')
                        .select('*')
                        .eq('id', session.user.id)
                        .maybeSingle();

                    store.update(s => ({ ...s, user: profile || null }));
                } else {
                    store.update(s => ({ ...s, user: null }));
                }
            });
        },

        login: async (email: string, password: string) => {
            const { data, error } = await supabase.auth.signInWithPassword({
                email,
                password
            });

            if (error) throw error;

            if (data.user) {
                const { data: profile } = await supabase
                    .from('profiles')
                    .select('*')
                    .eq('id', data.user.id)
                    .maybeSingle();

                if (profile) {
                    store.update(s => ({ ...s, user: profile }));
                }
            }

            return data;
        },

        logout: async () => {
            await supabase.auth.signOut();
            store.update(s => ({ ...s, user: null }));
        },

        setUser: (user: Profile | null) => {
            store.update(s => ({ ...s, user }));
        },

        getUser: () => get(store).user
    };
}

export const auth = createAuthStore();

export const isAuthenticated = derived(auth, $auth => $auth.user !== null);
export const isAdmin = derived(auth, $auth => $auth.user?.role === 'admin');
export const isGuru = derived(auth, $auth => $auth.user?.role === 'guru');
export const isKepalaSekolah = derived(auth, $auth => $auth.user?.role === 'kepala_sekolah');
export const canViewPenyisihan = derived(auth, $auth =>
    $auth.user?.can_view_penyisihan || $auth.user?.role === 'admin'
);
export const canCreateTransaction = derived(auth, $auth =>
    $auth.user?.role === 'admin' || $auth.user?.role === 'guru'
);
