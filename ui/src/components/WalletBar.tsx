import { Wallet } from 'lucide-react';

import { balanceLabel } from '../format';
import { t } from '../strings';
import type { HackOverview } from '../types';

/** The player's balance of the one currency actions are paid in, and what that currency is called. */
export function WalletBar({ overview }: { overview: HackOverview }) {
    return (
        <div className="mx-4 mb-3 flex items-center gap-3 rounded-row bg-surface px-4 py-2.5">
            <Wallet className="h-[18px] w-[18px] shrink-0 text-gray" strokeWidth={2.2} />
            <span className="min-w-0 flex-1 truncate text-[15px] text-label/70">{overview.currency.label}</span>
            <span
                className={`font-mono text-[16px] font-semibold ${overview.walletOk ? 'text-label' : 'text-bad'}`}
                title={overview.walletOk ? undefined : t('wallet_unavailable')}
            >
                {balanceLabel(overview)}
            </span>
        </div>
    );
}
