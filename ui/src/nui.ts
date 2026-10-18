// Calls into this resource's Lua. Inside sd-phone the SDK injects `window.fetchNui`; the standalone
// screen is the resource's own NUI page, so it posts to the resource directly, which is the same
// request the SDK helper makes. In the dev server `devMock.ts` supplies `window.fetchNui`.
import type { Envelope } from './types';

export interface SdPhoneGlobals {
    fetchNui?: <T = unknown>(event: string, data?: unknown, scriptName?: string) => Promise<T>;
    onNuiEvent?: <T = unknown>(action: string, cb: (data: T) => void) => () => void;
    OnAppOpen?: (cb: (data: { id: string }) => void) => () => void;
    OnAppClose?: (cb: (data: { id: string }) => void) => () => void;
    GetSettings?: () => Promise<{ display?: { theme?: string }; theme?: string }>;
    OnSettingsChange?: (cb: (settings: { display?: { theme?: string }; theme?: string }) => void) => void;
}

export const phone = window as unknown as Window & SdPhoneGlobals;

/** How long a call or subscription waits for sd-phone's SDK. sd-phone loads this page first and injects the
 *  SDK after, which can take a while on a busy server. */
const SDK_WAIT_MS = 15000;
const SDK_POLL_MS = 50;

/** Whether the game can be reached from this page: sd-phone's SDK, or the resource's own NUI bridge. */
function reachable(): boolean {
    return typeof phone.fetchNui === 'function'
        || typeof (window as { GetParentResourceName?: unknown }).GetParentResourceName === 'function';
}

/**
 * sd-phone tells the page when its app comes to the front (`appOpen`) or leaves it (`appClose`), and it does so
 * once the page has loaded, before the SDK is there. Listening from module load means that message is never
 * missed; the app reads the last state when it mounts. `null` until sd-phone has said anything.
 */
export const phoneApp: { open: boolean | null; listeners: Set<(open: boolean) => void> } = { open: null, listeners: new Set() };

if (typeof window !== 'undefined') {
    window.addEventListener('message', (event: MessageEvent) => {
        const type = (event.data as { type?: unknown } | null)?.type;
        if (type !== 'appOpen' && type !== 'appClose') return;
        phoneApp.open = type === 'appOpen';
        phoneApp.listeners.forEach(listener => listener(phoneApp.open === true));
    });
}

let waiting: Promise<void> | null = null;

/**
 * Resolves once the game can be reached. Inside sd-phone a call made at mount would find no SDK and fail
 * for good, so it waits here instead. After SDK_WAIT_MS it gives up and the caller fails as before; the
 * next call waits again, so "Try again" works once the SDK is there.
 */
export function sdkReady(): Promise<void> {
    if (reachable() || window.self === window.top) return Promise.resolve();
    if (!waiting) {
        waiting = new Promise<void>(resolve => {
            const started = Date.now();
            const timer = window.setInterval(() => {
                if (reachable() || Date.now() - started >= SDK_WAIT_MS) {
                    window.clearInterval(timer);
                    waiting = null;
                    resolve();
                }
            }, SDK_POLL_MS);
        });
    }
    return waiting;
}

export async function fetchNui<T = unknown>(event: string, data?: unknown): Promise<T | null> {
    await sdkReady();
    if (typeof phone.fetchNui === 'function') {
        // No script name: the SDK addresses the resource that registered the app, whatever it is called.
        return Promise.resolve(phone.fetchNui<T>(event, data ?? {})).catch(() => null);
    }
    if (typeof (window as { GetParentResourceName?: unknown }).GetParentResourceName === 'function') {
        const resource = (window as unknown as { GetParentResourceName: () => string }).GetParentResourceName();
        return fetch(`https://${resource}/${event}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data ?? {}),
        })
            .then(res => res.json() as Promise<T>)
            .catch(() => null);
    }
    return null;
}

/** Calls an event and returns its envelope, or a failure when nothing answered. */
export async function call<T = void>(event: string, data?: unknown): Promise<Envelope<T>> {
    const res = await fetchNui<Envelope<T>>(event, data);
    return res && typeof res.success === 'boolean' ? res : { success: false };
}

/** The payload of a successful call, or null. */
export async function callData<T>(event: string, data?: unknown): Promise<T | null> {
    const res = await call<T>(event, data);
    return res.success ? (res.data ?? null) : null;
}

/** Subscribes to a message the Lua side pushes to the page. Returns the unsubscribe. Inside sd-phone the
 *  subscription is made once the SDK is there, so no message sent in the meantime is lost. */
export function onMessage<T = unknown>(action: string, cb: (data: T) => void): () => void {
    let detach: (() => void) | undefined;
    let cancelled = false;
    const attach = (): (() => void) => {
        if (typeof phone.onNuiEvent === 'function') return phone.onNuiEvent<T>(action, cb);
        const handler = (event: MessageEvent) => {
            const msg = event.data as { action?: string; data?: T } | null;
            if (msg && msg.action === action) cb(msg.data as T);
        };
        window.addEventListener('message', handler);
        return () => window.removeEventListener('message', handler);
    };
    void sdkReady().then(() => { if (!cancelled) detach = attach(); });
    return () => { cancelled = true; detach?.(); };
}
