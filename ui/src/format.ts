import { t } from './strings';
import type { HackAction, HackCurrency, HackOverview, Risk } from './types';
import type { Tone } from './components/ui';

/** 12.4 -> "12 m", 1450 -> "1.5 km". */
export function metres(value: number): string {
    if (value < 1000) return `${Math.round(value)} m`;
    return `${(value / 1000).toFixed(1)} km`;
}

/** 0 -> "Instant", 1.5 -> "1.5 s", 20 -> "20 s", 90 -> "1 min 30 s". */
export function effectLength(seconds: number): string {
    if (seconds <= 0) return t('instant');
    if (seconds < 60) return t('seconds', { n: Number.isInteger(seconds) ? seconds : seconds.toFixed(1) });
    const m = Math.floor(seconds / 60);
    const s = Math.round(seconds % 60);
    return s === 0 ? t('minutes', { n: m }) : t('min_sec', { m, s });
}

/** An amount in the currency's own form: "$150", "150 SCR", "0.25 SCR". */
export function amountLabel(value: number, currency: HackCurrency): string {
    const text = value.toLocaleString('en-US', { minimumFractionDigits: currency.decimals, maximumFractionDigits: currency.decimals });
    return currency.symbolFirst ? `${currency.symbol}${text}` : `${text} ${currency.symbol}`;
}

/** What an action costs, or "Free" when the server runs free mode. */
export function costLabel(cost: number, overview: Pick<HackOverview, 'freeMode' | 'currency'>): string {
    if (overview.freeMode || cost <= 0) return t('free');
    return amountLabel(cost, overview.currency);
}

/** The wallet balance, or a dash when the framework does not track the currency for this player. */
export function balanceLabel(overview: Pick<HackOverview, 'balance' | 'currency' | 'walletOk'>): string {
    return overview.walletOk ? amountLabel(overview.balance, overview.currency) : '--';
}

/** The Speed Bomb text names its real threshold, which only the server's config knows. */
export function describe(action: HackAction, overview: Pick<HackOverview, 'speedUnit' | 'speedBomb'>): string {
    if (action.id !== 'speed_bomb') return action.description;
    return t('speed_bomb', {
        n: overview.speedBomb.threshold,
        unit: overview.speedUnit.toUpperCase(),
        delay: Math.round(overview.speedBomb.armDelayMs / 1000),
    });
}

export const RISK_TONE: Record<Risk, Tone> = { low: 'ok', medium: 'warn', high: 'bad' };

export function riskLabel(risk: Risk): string {
    return t(`risk_${risk}`);
}
