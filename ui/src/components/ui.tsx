// The few interface pieces the app needs, drawn from the palette in styles/app.css.
import { useState, type ReactNode } from 'react';
import { t } from '../strings';

export type Tone = 'ok' | 'warn' | 'bad' | 'info' | 'gray';

const TONES: Record<Tone, string> = {
    ok: 'bg-ok/20 text-ok',
    warn: 'bg-warn/20 text-warn',
    bad: 'bg-bad/20 text-bad',
    info: 'bg-info/20 text-info',
    gray: 'bg-gray/20 text-gray',
};

export function Pill({ tone, small = false, children }: { tone: Tone; small?: boolean; children: ReactNode }) {
    return (
        <span
            className={`inline-flex shrink-0 items-center gap-1 rounded-pill font-bold uppercase tracking-wide ${TONES[tone]} ${
                small ? 'px-1.5 py-0 text-[10px]' : 'px-2.5 py-[3px] text-[12px]'
            }`}
        >
            {children}
        </span>
    );
}

export function Hairline() {
    return <span className="pointer-events-none absolute inset-x-0 bottom-0 bg-hairline/25" style={{ height: '0.5px' }} />;
}

export function Group({ children, header, className = '' }: { children: ReactNode; header?: string; className?: string }) {
    return (
        <div className={className}>
            {header && <div className="px-3 pb-1.5 pt-1 text-[13px] uppercase tracking-wider text-gray">{header}</div>}
            <div className="overflow-hidden rounded-row bg-surface">{children}</div>
        </div>
    );
}

export function Segmented<T extends string>({ value, onChange, options }: {
    value: T;
    onChange: (value: T) => void;
    options: readonly { value: T; label: string }[];
}) {
    return (
        <div className="flex rounded-row bg-label/[0.07] p-[2px]">
            {options.map(option => (
                <button
                    key={option.value}
                    type="button"
                    onClick={() => onChange(option.value)}
                    className={`flex-1 rounded-row py-1.5 text-[15px] font-medium transition-colors ${
                        value === option.value ? 'bg-elevated text-label shadow-sm' : 'text-label/70'
                    }`}
                >
                    {option.label}
                </button>
            ))}
        </div>
    );
}

export function Spinner() {
    return (
        <span
            role="status"
            className="inline-block h-7 w-7 animate-spin rounded-full border-[3px] border-label/15 border-t-label/60"
        />
    );
}

export function EmptyState({ icon, title, subtitle, action, center = false }: {
    icon: ReactNode;
    title: string;
    subtitle?: string;
    action?: ReactNode;
    center?: boolean;
}) {
    return (
        <div className={`flex flex-col items-center text-center ${center ? 'h-full justify-center' : 'pt-20'}`}>
            <div className="flex h-16 w-16 items-center justify-center rounded-pill bg-surface text-gray">{icon}</div>
            <div className="mt-4 text-[21px] font-bold text-label">{title}</div>
            {subtitle && <p className="mt-2 max-w-[290px] text-[16px] leading-snug text-label/60">{subtitle}</p>}
            {action && <div className="mt-5">{action}</div>}
        </div>
    );
}

/** A destructive text link that asks for a second tap before it does anything. */
export function ConfirmLink({ label, armedLabel, onConfirm, icon, className = '' }: {
    label: string;
    armedLabel: string;
    onConfirm: () => void;
    icon?: ReactNode;
    className?: string;
}) {
    const [armed, setArmed] = useState(false);
    return (
        <button
            type="button"
            onClick={() => {
                if (!armed) {
                    setArmed(true);
                    window.setTimeout(() => setArmed(false), 3000);
                    return;
                }
                setArmed(false);
                onConfirm();
            }}
            className={`flex items-center justify-center gap-1 text-[15px] font-medium active:opacity-60 ${armed ? 'text-bad' : 'text-gray'} ${className}`}
        >
            {icon}
            {armed ? armedLabel : label}
        </button>
    );
}

/** A bottom sheet inside the app's own frame. `children` gets a `close` that plays the exit. */
export function Sheet({ onClose, children }: { onClose: () => void; children: (api: { close: () => void }) => ReactNode }) {
    const [exiting, setExiting] = useState(false);
    const close = () => {
        if (exiting) return;
        setExiting(true);
        window.setTimeout(onClose, 240);
    };
    return (
        <div className="absolute inset-0 z-50">
            <div
                onClick={close}
                className="absolute inset-0 bg-black/45"
                style={{ animation: `${exiting ? 'fade-out' : 'fade-in'} 0.24s ease forwards` }}
            />
            <div
                className="absolute inset-x-0 bottom-0 max-h-[88%] overflow-y-auto rounded-t-sheet bg-base"
                style={{ animation: `${exiting ? 'sheet-down 0.24s cubic-bezier(0.32,0,0.68,1)' : 'sheet-up 0.32s cubic-bezier(0.32,0.72,0,1)'} forwards` }}
            >
                <div className="mx-auto mt-2 h-1 w-10 rounded-pill bg-label/25" />
                {children({ close })}
            </div>
        </div>
    );
}

export function SheetHeader({ onCancel }: { onCancel: () => void }) {
    return (
        <div className="flex h-11 items-center px-4">
            <button type="button" onClick={onCancel} className="text-[17px] text-info active:opacity-60">
                {t('cancel')}
            </button>
        </div>
    );
}

export interface ToastState { id: number; text: string; tone: 'ok' | 'error' }

export function Toast({ toast }: { toast: ToastState }) {
    return (
        <div key={toast.id} className="anim-toast pointer-events-none absolute inset-x-0 bottom-8 z-[70] flex justify-center px-4">
            <div className="flex max-w-full items-center gap-2 rounded-pill bg-elevated px-4 py-2.5 text-[14px] font-semibold text-label ring-1 ring-label/15">
                <span className={`h-2 w-2 shrink-0 rounded-pill ${toast.tone === 'ok' ? 'bg-ok' : 'bg-bad'}`} />
                <span className="truncate">{toast.text}</span>
            </div>
        </div>
    );
}
