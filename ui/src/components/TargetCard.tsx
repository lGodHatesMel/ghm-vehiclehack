import { ChevronLeft, Link2Off } from 'lucide-react';

import { metres } from '../format';
import { t } from '../strings';
import type { HackVehicle } from '../types';
import { ConfirmLink } from './ui';
import { Plate, VehicleChips, VehicleGlyph } from './VehicleBits';

/** The linked vehicle, kept at the top of the action screen with its live distance and state. */
export function TargetCard({ vehicle, onBack, onRemoveTag }: {
    vehicle: HackVehicle;
    onBack: () => void;
    /** Only offered for a tagged vehicle: an aimed one has no tag to remove. */
    onRemoveTag: () => void;
}) {
    return (
        <div className="px-4">
            <button type="button" onClick={onBack} className="-ml-1 mb-2 flex items-center gap-0.5 text-[17px] text-accent active:opacity-60">
                <ChevronLeft className="h-[22px] w-[22px]" strokeWidth={2.5} />
                {t('targets')}
            </button>

            <div className="rounded-card bg-surface p-4">
                <div className="flex items-center gap-3">
                    <VehicleGlyph size={52} muted={!vehicle.inRange} />
                    <div className="min-w-0 flex-1">
                        <div className="truncate text-[21px] font-bold leading-tight text-label">{vehicle.model}</div>
                        <div className="mt-1"><Plate>{vehicle.plate}</Plate></div>
                    </div>
                    <div className="text-right">
                        <div className="font-mono text-[20px] font-semibold leading-none text-label">{metres(vehicle.distance)}</div>
                        <div className="mt-1 text-[12px] font-medium uppercase tracking-wider text-gray">{t('away')}</div>
                    </div>
                </div>

                <div className="mt-3 flex items-center justify-between gap-2">
                    <VehicleChips vehicle={vehicle} />
                    {vehicle.via === 'tag' && (
                        <ConfirmLink
                            className="ml-auto shrink-0"
                            icon={<Link2Off className="h-4 w-4" strokeWidth={2.2} />}
                            label={t('remove_tag')}
                            armedLabel={t('tap_to_remove')}
                            onConfirm={onRemoveTag}
                        />
                    )}
                </div>
            </div>
        </div>
    );
}
