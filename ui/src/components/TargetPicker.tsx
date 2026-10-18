import { ChevronRight, Crosshair, Tag } from 'lucide-react';

import { metres } from '../format';
import { t } from '../strings';
import type { HackOverview, HackScan, HackVehicle } from '../types';
import { ConfirmLink, EmptyState, Group, Hairline, Segmented } from './ui';
import { Plate, VehicleChips, VehicleGlyph } from './VehicleBits';

export type PickMode = 'tagged' | 'aim';

function VehicleRow({ vehicle, divider, onPress }: { vehicle: HackVehicle; divider: boolean; onPress: () => void }) {
    return (
        <button
            type="button"
            disabled={!vehicle.inRange}
            onClick={onPress}
            className={`relative flex w-full items-center gap-3 px-4 py-3 text-left ${vehicle.inRange ? 'active:bg-label/5' : 'opacity-50'}`}
        >
            <VehicleGlyph muted={!vehicle.inRange} />
            <span className="min-w-0 flex-1">
                <span className="block truncate text-[17px] font-semibold text-label">{vehicle.model}</span>
                <span className="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1">
                    <Plate>{vehicle.plate}</Plate>
                    <VehicleChips vehicle={vehicle} />
                </span>
            </span>
            <span className="font-mono text-[15px] text-gray">{metres(vehicle.distance)}</span>
            {vehicle.inRange && <ChevronRight className="h-[17px] w-[17px] shrink-0 text-gray" strokeWidth={2.5} />}
            {divider && <Hairline />}
        </button>
    );
}

export function TargetPicker({ overview, scan, mode, onMode, standalone, onPick, onAim, onRemoveAllTags }: {
    overview: HackOverview;
    scan: HackScan;
    mode: PickMode;
    onMode: (mode: PickMode) => void;
    standalone: boolean;
    onPick: (vehicle: HackVehicle) => void;
    onAim: () => void;
    onRemoveAllTags: () => void;
}) {
    const { tagged: hasTagged, aim: hasAim } = overview.targeting;
    const both = hasTagged && hasAim;
    const active: PickMode = both ? mode : hasTagged ? 'tagged' : 'aim';

    return (
        <div className="space-y-4 px-4 pb-8">
            {both && (
                <Segmented<PickMode>
                    value={active}
                    onChange={onMode}
                    options={[
                        { value: 'tagged', label: scan.vehicles.length > 0 ? t('tagged_count', { n: scan.vehicles.length }) : t('tagged') },
                        { value: 'aim', label: t('aim') },
                    ]}
                />
            )}

            {active === 'tagged' && (
                scan.vehicles.length === 0 ? (
                    <EmptyState
                        icon={<Tag className="h-8 w-8" strokeWidth={2} />}
                        title={t('no_tags')}
                        subtitle={t('no_tags_hint', { n: Math.round(overview.scanRadius) })}
                    />
                ) : (
                    <>
                        <Group>
                            {scan.vehicles.map((vehicle, i) => (
                                <VehicleRow key={vehicle.netId} vehicle={vehicle} divider={i < scan.vehicles.length - 1} onPress={() => onPick(vehicle)} />
                            ))}
                        </Group>
                        <ConfirmLink
                            className="w-full py-2.5"
                            label={t('remove_all')}
                            armedLabel={t('remove_all_confirm')}
                            onConfirm={onRemoveAllTags}
                        />
                    </>
                )
            )}

            {active === 'aim' && (
                <div className="space-y-4">
                    <div className="rounded-card bg-surface p-5 text-center">
                        <span className="mx-auto flex h-16 w-16 items-center justify-center rounded-pill bg-accent/20 text-accent">
                            <Crosshair className="h-8 w-8" strokeWidth={2} />
                        </span>
                        <div className="mt-3 text-[19px] font-bold text-label">{t('aim_title')}</div>
                        <p className="mx-auto mt-1.5 max-w-[290px] text-[15px] leading-snug text-label/60">
                            {t(standalone ? 'aim_hint_standalone' : 'aim_hint_phone', { n: Math.round(overview.aimRange) })}
                        </p>
                        <button
                            type="button"
                            onClick={onAim}
                            className="mt-4 w-full rounded-btn bg-accent py-3.5 text-[17px] font-semibold text-white active:opacity-80"
                        >
                            {t('start_aim')}
                        </button>
                    </div>

                    {scan.aimed && (
                        <Group header={t('last_aimed')}>
                            <VehicleRow vehicle={scan.aimed} divider={false} onPress={() => onPick(scan.aimed as HackVehicle)} />
                        </Group>
                    )}
                </div>
            )}
        </div>
    );
}
