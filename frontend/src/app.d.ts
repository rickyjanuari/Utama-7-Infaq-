// See https://svelte.dev/docs/kit/types#app.d.ts
// for information about these interfaces
declare global {
    namespace App {
        // interface Error {}
        interface Locals {
            user?: {
                id: string;
                email: string;
                name: string;
                role: 'admin' | 'guru' | 'kepala_sekolah';
                can_view_penyisihan: boolean;
            };
        }
        // interface PageData {}
        // interface PageState {}
        // interface Platform {}
    }
}

export { };
