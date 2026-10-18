import { useEffect, useState } from 'react';

import { fetchConfig, closeScreen } from './api';
import Hacker from './Hacker';
import { onMessage, phone, phoneApp, sdkReady } from './nui';
import { setStrings } from './strings';
import type { AppConfig } from './types';

/** sd-phone loads this page in an iframe; the standalone screen is the page itself. */
function inPhoneFrame(): boolean {
    // Dev server preview: ?mode=phone / ?mode=standalone
    const override = new URLSearchParams(window.location.search).get('mode');
    if (override === 'phone') return true;
    if (override === 'standalone') return false;
    return window.self !== window.top;
}

function isDark(settings?: { display?: { theme?: string }; theme?: string }): boolean {
    return (settings?.display?.theme ?? settings?.theme) === 'dark';
}

export default function App() {
    const isPhone = inPhoneFrame();
    const [config, setConfig] = useState<AppConfig | null>(null);
    const [dark, setDark] = useState(!isPhone || (window.matchMedia?.('(prefers-color-scheme: dark)').matches ?? false));
    // Standalone: shown only between the open and close messages. Phone: always mounted, and told
    // when it comes to the front.
    // Phone: shown only while sd-phone has its app in front (`appOpen`); the page is mounted before that.
    // The dev preview (?mode=phone) has no sd-phone, so it starts shown.
    const previewPhone = new URLSearchParams(window.location.search).get('mode') === 'phone';
    const [visible, setVisible] = useState(isPhone ? (phoneApp.open ?? previewPhone) : false);
    const [active, setActive] = useState(isPhone ? (phoneApp.open ?? previewPhone) : false);
    const [openSignal, setOpenSignal] = useState(0);

    useEffect(() => {
        void fetchConfig().then(res => {
            setStrings(res?.strings);
            setConfig(res ?? { standalone: !isPhone, strings: {} });
        });
    }, [isPhone]);

    // The phone's theme, and its app lifecycle: the iframe stays alive in the background.
    useEffect(() => {
        if (!isPhone) return;
        let cancelled = false;
        // The SDK arrives after this page, so subscribe once it is there; a subscription made before is never called.
        void sdkReady().then(() => {
            if (cancelled) return;
            if (typeof phone.GetSettings === 'function') {
                void Promise.resolve(phone.GetSettings()).then(s => setDark(isDark(s))).catch(() => undefined);
            }
            phone.OnSettingsChange?.(s => setDark(isDark(s)));
        });
        const onApp = (open: boolean) => {
            setVisible(open);
            setActive(open);
            if (open) setOpenSignal(n => n + 1);
        };
        phoneApp.listeners.add(onApp);
        return () => { cancelled = true; phoneApp.listeners.delete(onApp); };
    }, [isPhone]);

    useEffect(() => {
        if (isPhone) return;
        const offOpen = onMessage('standaloneOpen', () => { setVisible(true); setActive(true); setOpenSignal(n => n + 1); });
        const offClose = onMessage('standaloneClose', () => { setVisible(false); setActive(false); });
        return () => { offOpen(); offClose(); };
    }, [isPhone]);

    const close = () => {
        if (isPhone) {
            try { window.parent?.postMessage({ type: 'sdphoneCloseApp' }, '*'); } catch { /* cross-origin */ }
        } else {
            void closeScreen();
        }
    };

    // Escape closes the screen (standalone) or the app (phone).
    useEffect(() => {
        const onKey = (event: KeyboardEvent) => { if (event.key === 'Escape') close(); };
        window.addEventListener('keydown', onKey);
        return () => window.removeEventListener('keydown', onKey);
    });

    if (!config || !visible) return null;

    return isPhone ? (
        <div className={`frame-phone absolute inset-0 ${dark ? 'dark' : ''}`}>
            <Hacker standalone={false} active={active} openSignal={openSignal} onClose={close} />
        </div>
    ) : (
        <div className="frame-standalone dark fixed inset-0 flex items-center justify-center">
            <div className="h-[min(780px,92vh)] w-[min(470px,96vw)] overflow-hidden rounded-card border border-hairline/40 bg-base">
                <Hacker standalone active={active} openSignal={openSignal} onClose={close} />
            </div>
        </div>
    );
}
