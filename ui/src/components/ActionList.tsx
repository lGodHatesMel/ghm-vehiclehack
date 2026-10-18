import { ChevronRight } from 'lucide-react';

import { iconFor } from '../actionIcons';
import { RISK_TONE, costLabel, describe, effectLength, riskLabel } from '../format';
import { t } from '../strings';
import type { HackAction, HackCategory, HackOverview } from '../types';
import { Group, Hairline, Pill } from './ui';

export function ActionList({ category, overview, disabled, activeUntil, now, onPick }: {
    category: HackCategory;
    overview: HackOverview;
    /** Cooldown or a vehicle out of reach: the rows are shown but cannot be tapped. */
    disabled: boolean;
    /** Action id -> ms timestamp its effect ends, for the actions still running on this vehicle. */
    activeUntil: Record<string, number>;
    now: number;
    onPick: (action: HackAction) => void;
}) {
    return (
        <div className="space-y-2">
            <p className="px-7 text-[14px] text-gray">{category.description}</p>
            <Group className="mx-4">
                {category.actions.map((action, i) => {
                    const Icon = iconFor(action.id);
                    const left = Math.max(0, Math.ceil(((activeUntil[action.id] ?? 0) - now) / 1000));
                    return (
                        <button
                            key={action.id}
                            type="button"
                            disabled={disabled}
                            onClick={() => onPick(action)}
                            className={`relative flex w-full items-center gap-3 px-4 py-3 text-left ${disabled ? 'opacity-50' : 'active:bg-label/5'}`}
                        >
                            <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-pill bg-accent/20 text-accent">
                                <Icon className="h-5 w-5" strokeWidth={2.2} />
                            </span>
                            <span className="min-w-0 flex-1">
                                <span className="flex items-center justify-between gap-2">
                                    <span className="truncate text-[17px] font-semibold text-label">{action.label}</span>
                                    <Pill tone={RISK_TONE[action.risk]} small>{riskLabel(action.risk)}</Pill>
                                </span>
                                <span className="mt-0.5 block text-[14px] leading-snug text-label/60">
                                    {left > 0 ? t('active_for', { n: left }) : describe(action, overview)}
                                </span>
                                <span className="mt-1 block font-mono text-[12px] uppercase tracking-wide text-gray">
                                    {effectLength(action.duration)} &middot; {costLabel(action.cost, overview)}
                                </span>
                            </span>
                            <ChevronRight className="h-[17px] w-[17px] shrink-0 text-gray" strokeWidth={2.5} />
                            {i < category.actions.length - 1 && <Hairline />}
                        </button>
                    );
                })}
            </Group>
        </div>
    );
}
