// The app's text. The server sends the locale file's `ui` section when the app starts, so a language
// is a locales/<code>.json file and needs no rebuild. English is bundled as the fallback (and is what
// the dev server shows); a key missing from both is shown as itself.
import en from '../../locales/en.json';

type Vars = Record<string, string | number>;

const fallback: Record<string, string> = en.ui;
let live: Record<string, string> = {};

export function setStrings(strings: Record<string, string> | undefined): void {
    live = strings ?? {};
}

export function t(key: string, vars?: Vars): string {
    const raw = live[key] ?? fallback[key] ?? key;
    return vars ? raw.replace(/\{(\w+)\}/g, (_, name: string) => String(vars[name] ?? `{${name}}`)) : raw;
}
