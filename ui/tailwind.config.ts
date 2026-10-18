import type { Config } from 'tailwindcss';

// Colours come from CSS variables (src/styles/app.css) so the same markup is light or dark with the
// phone's theme, and a flat dark panel when it runs standalone.
export default {
    content: ['./index.html', './src/**/*.{ts,tsx}'],
    darkMode: ['class'],
    theme: {
        extend: {
            colors: {
                label: 'rgb(var(--label) / <alpha-value>)',
                base: 'rgb(var(--base) / <alpha-value>)',
                surface: 'rgb(var(--surface) / <alpha-value>)',
                elevated: 'rgb(var(--elevated) / <alpha-value>)',
                control: 'rgb(var(--control) / <alpha-value>)',
                hairline: 'rgb(var(--hairline) / <alpha-value>)',
                gray: 'rgb(var(--gray) / <alpha-value>)',
                accent: 'rgb(var(--accent) / <alpha-value>)',
                ok: 'rgb(var(--ok) / <alpha-value>)',
                warn: 'rgb(var(--warn) / <alpha-value>)',
                bad: 'rgb(var(--bad) / <alpha-value>)',
                info: 'rgb(var(--info) / <alpha-value>)',
            },
            borderRadius: {
                card: 'var(--r-card)',
                row: 'var(--r-row)',
                btn: 'var(--r-btn)',
                pill: 'var(--r-pill)',
                sheet: 'var(--r-sheet)',
            },
            fontFamily: {
                mono: ['ui-monospace', 'SFMono-Regular', 'Menlo', 'Consolas', 'monospace'],
            },
        },
    },
    plugins: [],
} satisfies Config;
