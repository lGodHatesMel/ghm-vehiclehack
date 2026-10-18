import type { ReactNode } from 'react';
import { Car, Lock, Users } from 'lucide-react';

import { t } from '../strings';
import type { HackVehicle } from '../types';
import { Pill } from './ui';

/** A licence plate: mono, letter-spaced, on a tinted plate so it reads as one on every theme. */
export function Plate({ children }: { children: ReactNode }) {
    return (
        <span className="inline-block rounded-btn bg-label/10 px-1.5 py-[1px] font-mono text-[13px] font-semibold uppercase tracking-[0.14em] text-label">
            {children || '--------'}
        </span>
    );
}

/** The round car glyph every vehicle wears. */
export function VehicleGlyph({ size = 44, muted = false }: { size?: number; muted?: boolean }) {
    return (
        <span
            className={`flex shrink-0 items-center justify-center rounded-pill ${muted ? 'bg-gray/20 text-gray' : 'bg-accent/20 text-accent'}`}
            style={{ width: size, height: size }}
        >
            <Car style={{ width: size * 0.5, height: size * 0.5 }} strokeWidth={2.1} />
        </span>
    );
}

/** What is going on with a vehicle: who is inside, whether it is locked, whether it is out of reach. */
export function VehicleChips({ vehicle }: { vehicle: HackVehicle }) {
    return (
        <span className="flex flex-wrap items-center gap-1.5">
            {!vehicle.inRange && <Pill tone="bad">{t('out_of_range')}</Pill>}
            {vehicle.occupants > 0 && (
                <Pill tone="info">
                    <Users className="h-3 w-3" strokeWidth={2.6} />
                    {vehicle.occupants}
                </Pill>
            )}
            {vehicle.locked && (
                <Pill tone="warn">
                    <Lock className="h-3 w-3" strokeWidth={2.6} />
                    {t('locked')}
                </Pill>
            )}
        </span>
    );
}
