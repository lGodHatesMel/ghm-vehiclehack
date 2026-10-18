import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Radar, X } from 'lucide-react';

import { fetchOverview, fetchScan, removeAllTags, removeTag, runAction, startAim, takePick } from './api';
import { ActionList } from './components/ActionList';
import { ActionSheet } from './components/ActionSheet';
import { TargetCard } from './components/TargetCard';
import { TargetPicker, type PickMode } from './components/TargetPicker';
import { WalletBar } from './components/WalletBar';
import { EmptyState, Segmented, Spinner, Toast, type ToastState } from './components/ui';
import { onMessage } from './nui';
import { t } from './strings';
import type { HackAction, HackOverview, HackPick, HackScan, HackVehicle } from './types';

/** How often the vehicles in reach are re-read while the app is up. */
const SCAN_MS = 1000;
/** Scans in a row that must miss the linked vehicle before the link is declared lost. */
const LOST_AFTER = 3;

const EMPTY_SCAN: HackScan = { vehicles: [] };

export default function Hacker({ standalone, active, openSignal, onClose }: {
    standalone: boolean;
    /** False while the app is in the background: nothing is polled. */
    active: boolean;
    /** Goes up by one each time the app comes to the front, to collect an aim and refresh the balance. */
    openSignal: number;
    onClose: () => void;
}) {
    const [overview, setOverview] = useState<HackOverview | null>(null);
    const [loaded, setLoaded] = useState(false);

    const [mode, setMode] = useState<PickMode>('tagged');
    const [targetId, setTargetId] = useState<number | null>(null);
    const [categoryId, setCategoryId] = useState('');
    const [scan, setScan] = useState<HackScan>(EMPTY_SCAN);
    const [scanned, setScanned] = useState(false);
    const [sheet, setSheet] = useState<HackAction | null>(null);

    // ms timestamp each running effect ends at, keyed "<netId>:<action>", and the cooldown's end.
    const [effects, setEffects] = useState<Record<string, number>>({});
    const [cooldownUntil, setCooldownUntil] = useState(0);
    const [now, setNow] = useState(Date.now());

    const [toast, setToast] = useState<ToastState | null>(null);
    const toastTimer = useRef<number | undefined>(undefined);
    const misses = useRef(0);

    const notify = useCallback((text: string, tone: 'ok' | 'error' = 'ok') => {
        window.clearTimeout(toastTimer.current);
        setToast({ id: Date.now(), text, tone });
        toastTimer.current = window.setTimeout(() => setToast(null), 3200);
    }, []);
    useEffect(() => () => window.clearTimeout(toastTimer.current), []);

    const loadOverview = useCallback(async () => {
        const next = await fetchOverview();
        if (next) setOverview(next);
        setLoaded(true);
    }, []);

    const applyPick = useCallback((pick: HackPick | null | undefined) => {
        if (!pick) return;
        if (pick.ok && typeof pick.netId === 'number') {
            setMode('aim');
            setTargetId(pick.netId);
            misses.current = 0;
        } else if (pick.message) {
            notify(pick.message, 'error');
        }
    }, [notify]);

    // An aim ends with the app coming back (or the camera closing); the result is pushed when the app
    // was on screen and held for collection when it was not.
    useEffect(() => onMessage<HackPick>('picked', applyPick), [applyPick]);

    useEffect(() => {
        void loadOverview();
        void takePick().then(applyPick);
    }, [openSignal, loadOverview, applyPick]);

    // Poll the world while the app is up; the server only has to hear about it when something changes.
    const ready = !!overview;
    useEffect(() => {
        if (!active || !ready) return;
        let cancelled = false;
        async function tick() {
            const next = await fetchScan();
            if (cancelled || !next) return;
            setScan(next);
            setScanned(true);
        }
        void tick();
        const id = window.setInterval(tick, SCAN_MS);
        return () => { cancelled = true; window.clearInterval(id); };
    }, [active, ready]);

    const target: HackVehicle | null = useMemo(() => {
        if (targetId == null) return null;
        return [...scan.vehicles, ...(scan.aimed ? [scan.aimed] : [])].find(v => v.netId === targetId) ?? null;
    }, [scan, targetId]);

    // The linked vehicle can vanish: driven out of range, despawned, untagged elsewhere. A few misses
    // in a row, not one, so a scan that races the aim's pick does not throw the link away.
    useEffect(() => {
        if (targetId == null || !scanned) { misses.current = 0; return; }
        if (target) { misses.current = 0; return; }
        misses.current += 1;
        if (misses.current >= LOST_AFTER) {
            misses.current = 0;
            setTargetId(null);
            notify(t('lost'), 'error');
        }
    }, [scan, scanned, target, targetId, notify]);

    // Tick the clock only while something is counting down.
    const counting = cooldownUntil > now || Object.values(effects).some(end => end > now);
    useEffect(() => {
        if (!counting) return;
        const id = window.setInterval(() => setNow(Date.now()), 250);
        return () => window.clearInterval(id);
    }, [counting]);

    const activeUntil = useMemo(() => {
        const out: Record<string, number> = {};
        for (const [key, end] of Object.entries(effects)) {
            const [net, action] = key.split(':');
            if (Number(net) === targetId && end > now) out[action] = end;
        }
        return out;
    }, [effects, targetId, now]);

    const categories = overview?.categories ?? [];
    const category = categories.find(c => c.id === categoryId) ?? categories[0];
    const onCooldown = cooldownUntil > now;

    async function run(action: HackAction) {
        if (!target || !overview) return;
        const res = await runAction(target.netId, action.id);
        if (res.success && res.data) {
            const result = res.data;
            setOverview({ ...overview, balance: result.balance });
            const startedAt = Date.now();
            setCooldownUntil(startedAt + overview.cooldownMs);
            setNow(startedAt);
            if (result.duration > 0) {
                setEffects(prev => ({ ...prev, [`${target.netId}:${action.id}`]: startedAt + result.duration * 1000 }));
            }
            notify(t('sent', { action: action.label }));
        } else {
            notify(res.message ?? t('failed'), 'error');
        }
    }

    async function aim() {
        const res = await startAim();
        if (!res.success) { notify(res.message ?? t('failed'), 'error'); return; }
        // Where nothing closes (the dev server) the result is ready at once; in the game it arrives
        // by message or when the app is opened again.
        window.setTimeout(() => void takePick().then(applyPick), 700);
    }

    async function untag(netId: number) {
        const res = await removeTag(netId);
        if (res.success) { setTargetId(null); notify(t('tag_removed')); void loadOverview(); }
        else notify(res.message ?? t('failed'), 'error');
    }

    async function untagAll() {
        const res = await removeAllTags();
        if (res.success) { setTargetId(null); notify(t('tags_removed')); void loadOverview(); }
        else notify(res.message ?? t('failed'), 'error');
    }

    return (
        <div className="relative flex h-full min-h-0 flex-col bg-base font-sans text-label">
            {standalone ? (
                <div className="flex h-12 shrink-0 items-center justify-between border-b border-hairline/30 px-4">
                    <span className="font-mono text-[14px] font-semibold uppercase tracking-[0.18em]">{t('title')}</span>
                    <button type="button" onClick={onClose} aria-label={t('close')} className="text-gray hover:text-label">
                        <X className="h-5 w-5" strokeWidth={2.2} />
                    </button>
                </div>
            ) : (
                // sd-phone draws its status bar over every app, so the app reserves the space itself.
                <div className="h-[54px] shrink-0" aria-hidden />
            )}

            {!overview ? (
                <div className="flex min-h-0 flex-1 items-center justify-center px-8">
                    {!loaded
                        ? <Spinner />
                        : (
                            <EmptyState
                                center
                                icon={<Radar className="h-8 w-8" strokeWidth={2} />}
                                title={t('unavailable')}
                                subtitle={t('unavailable_hint')}
                                action={
                                    <button type="button" onClick={() => { setLoaded(false); void loadOverview(); }} className="rounded-pill bg-accent px-5 py-2 text-[16px] font-semibold text-white active:opacity-70">
                                        {t('retry')}
                                    </button>
                                }
                            />
                        )}
                </div>
            ) : (
                <>
                    <div className="shrink-0 px-5 pb-2 pt-1">
                        {!standalone && <h1 className="text-[34px] font-bold tracking-tight">{t('title')}</h1>}
                        <div className="mt-1 flex items-center gap-2 text-[13px] font-semibold uppercase tracking-wider">
                            <span className={target ? 'text-gray' : 'text-accent'}>{t('step_target')}</span>
                            <span className="text-gray">/</span>
                            <span className={target ? 'text-accent' : 'text-gray'}>{t('step_action')}</span>
                        </div>
                    </div>

                    <WalletBar overview={overview} />

                    <div className="min-h-0 flex-1 overflow-y-auto">
                        {!target ? (
                            <TargetPicker
                                overview={overview}
                                scan={scan}
                                mode={mode}
                                onMode={setMode}
                                standalone={standalone}
                                onPick={v => { misses.current = 0; setTargetId(v.netId); }}
                                onAim={() => void aim()}
                                onRemoveAllTags={() => void untagAll()}
                            />
                        ) : (
                            <div className="space-y-4 pb-8">
                                <TargetCard vehicle={target} onBack={() => setTargetId(null)} onRemoveTag={() => void untag(target.netId)} />

                                <div className="px-4">
                                    <Segmented
                                        value={category?.id ?? ''}
                                        onChange={setCategoryId}
                                        options={categories.map(c => ({ value: c.id, label: c.label }))}
                                    />
                                    <div className={`mt-3 h-[3px] overflow-hidden rounded-pill ${onCooldown ? 'bg-label/10' : 'bg-transparent'}`} aria-hidden>
                                        <div
                                            className="h-full origin-left rounded-pill bg-accent"
                                            style={{
                                                transform: `scaleX(${onCooldown ? Math.max(0, (cooldownUntil - now) / overview.cooldownMs) : 0})`,
                                                transition: 'transform 0.25s linear',
                                            }}
                                        />
                                    </div>
                                </div>

                                {category && (
                                    <ActionList
                                        category={category}
                                        overview={overview}
                                        disabled={onCooldown || !target.inRange}
                                        activeUntil={activeUntil}
                                        now={now}
                                        onPick={setSheet}
                                    />
                                )}
                            </div>
                        )}
                    </div>
                </>
            )}

            {sheet && target && overview && (
                <ActionSheet
                    action={sheet}
                    vehicle={target}
                    overview={overview}
                    onClose={() => setSheet(null)}
                    onRun={() => run(sheet)}
                />
            )}

            {toast && <Toast toast={toast} />}
        </div>
    );
}
