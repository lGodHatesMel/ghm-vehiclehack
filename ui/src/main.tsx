import { createRoot } from 'react-dom/client';

import App from './App';
import './styles/app.css';

function render(): void {
    const root = document.getElementById('root');
    if (root) createRoot(root).render(<App />);
}

if (import.meta.env.DEV && !(window as { invokeNative?: unknown }).invokeNative) {
    // The dev server has no game: supply the NUI bridge the app calls.
    void import('./devMock').then(render);
} else if (window.self === window.top) {
    // Standalone page: the resource's own NUI, mounted straight away.
    render();
} else {
    // Inside sd-phone: the SDK is injected after the page loads, so wait for it.
    let rendered = false;
    const mountOnce = (): void => {
        if (rendered) return;
        rendered = true;
        render();
    };
    window.addEventListener('message', (event: MessageEvent) => {
        if (event.data === 'componentsLoaded') mountOnce();
    });
    if ((globalThis as { componentsLoaded?: boolean }).componentsLoaded) mountOnce();
    window.setTimeout(mountOnce, 1500);
}
