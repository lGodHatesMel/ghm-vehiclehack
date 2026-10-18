import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
    plugins: [react()],
    base: './',
    // The English locale file (../locales/en.json) is the default text of the app, so the dev server
    // has to be allowed to read one folder up.
    server: { fs: { allow: ['..'] } },
    build: { outDir: 'dist' },
});
