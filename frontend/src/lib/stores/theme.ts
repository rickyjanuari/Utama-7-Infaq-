import { browser } from '$app/environment';
import { writable } from 'svelte/store';

type Theme = 'light' | 'dark';

function createThemeStore() {
    const storedTheme = browser ? (localStorage.getItem('theme') as Theme) : null;
    const prefersDark = browser ? window.matchMedia('(prefers-color-scheme: dark)').matches : false;
    const initialTheme: Theme = storedTheme || (prefersDark ? 'dark' : 'light');

    const store = writable<Theme>(initialTheme);

    if (browser) {
        // Apply initial theme
        document.documentElement.setAttribute('data-theme', initialTheme);
    }

    return {
        subscribe: store.subscribe,

        toggle: () => {
            store.update((current) => {
                const newTheme: Theme = current === 'light' ? 'dark' : 'light';
                if (browser) {
                    localStorage.setItem('theme', newTheme);
                    document.documentElement.setAttribute('data-theme', newTheme);
                }
                return newTheme;
            });
        },

        set: (theme: Theme) => {
            store.set(theme);
            if (browser) {
                localStorage.setItem('theme', theme);
                document.documentElement.setAttribute('data-theme', theme);
            }
        }
    };
}

export const theme = createThemeStore();
