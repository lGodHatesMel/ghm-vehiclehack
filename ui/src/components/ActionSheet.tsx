import { useState, type ReactNode } from 'react';

import { iconFor } from '../actionIcons';
import { RISK_TONE, balanceLabel, costLabel, describe, effectLength, riskLabel } from '../format';
import { t } from '../strings';
import type { HackAction, HackOverview, HackVehicle } from '../types';
import { Group, Hairline, Pill, Sheet, SheetHeader } from './ui';
import { Plate } from './VehicleBits';

function Line({ label, children, divider = true }: { label: string; children: ReactNode; divider?: boolean }) {
    return (
        <div className="relative flex items-center justify-between px-4 py-3">
            <span className="text-[16px] text-label/70">{label}</span>
            <span className="flex items-center text-[16px] font-medium text-label">{children}</span>
            {divider && <Hairline />}
        </div>
    );
}

/** The last look before an action runs: what it does, how long, what it costs, on which vehicle. */
export function ActionSheet({ action, vehicle, overview, onClose, onRun }: {
    action: HackAction;
    vehicle: HackVehicle;
    overview: HackOverview;
    onClose: () => void;
    /** Resolves when the server has answered; the sheet closes either way. */
    onRun: () => Promise<void>;
}) {
    const [running, setRunning] = useState(false);
    const Icon = iconFor(action.id);
    const paying = !overview.freeMode && action.cost > 0;
    const short = paying && (!overview.walletOk || overview.balance < action.cost);

    return (
        <Sheet onClose={onClose}>
            {({ close }) => (
                <div className="pb-4 text-label">
                    <SheetHeader onCancel={close} />

                    <div className="px-5 pb-4 text-center">
                        <span className="mx-auto flex h-16 w-16 items-center justify-center rounded-pill bg-accent/20 text-accent">
                            <Icon className="h-8 w-8" strokeWidth={2} />
                        </span>
                        <div className="mt-3 text-[24px] font-bold">{action.label}</div>
                        <p className="mx-auto mt-1 max-w-[300px] text-[15px] leading-snug text-label/60">{describe(action, overview)}</p>
                    </div>

                    <Group className="mx-4">
                        <Line label={t('target')}>
                            <span className="mr-2 max-w-[130px] truncate">{vehicle.model}</span>
                            <Plate>{vehicle.plate}</Plate>
                        </Line>
                        <Line label={t('effect')}><span className="font-mono">{effectLength(action.duration)}</span></Line>
                        <Line label={t('risk')}><Pill tone={RISK_TONE[action.risk]}>{riskLabel(action.risk)}</Pill></Line>
                        <Line label={t('cost')} divider={paying}><span className="font-mono">{costLabel(action.cost, overview)}</span></Line>
                        {paying && (
                            <Line label={t('balance')} divider={false}>
                                <span className={`font-mono ${short ? 'text-bad' : ''}`}>{balanceLabel(overview)}</span>
                            </Line>
                        )}
                    </Group>

                    <div className="px-4 pt-5">
                        <button
                            type="button"
                            disabled={running || short}
                            onClick={async () => {
                                setRunning(true);
                                await onRun();
                                close();
                            }}
                            className="w-full rounded-btn bg-accent py-3.5 text-[17px] font-semibold text-white active:opacity-80 disabled:opacity-40"
                        >
                            {short
                                ? t('not_enough', { currency: overview.currency.label })
                                : running
                                    ? t('running')
                                    : paying
                                        ? t('run_for', { cost: costLabel(action.cost, overview) })
                                        : t('run')}
                        </button>
                    </div>
                </div>
            )}
        </Sheet>
    );
}
