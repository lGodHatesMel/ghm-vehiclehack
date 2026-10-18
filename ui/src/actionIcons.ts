import {
    Bomb, CircleOff, CornerUpLeft, CornerUpRight, DoorOpen, Disc, FlipVertical2, Fuel, Hand, LockKeyhole,
    Lock, LogOut, Megaphone, PowerOff, Rocket, RotateCw, Zap,
    type LucideIcon,
} from 'lucide-react';

/** One glyph per action id. An action added to the config that is not listed here gets a bolt. */
const ICONS: Record<string, LucideIcon> = {
    engine_kill: PowerOff,
    brake_lock: Hand,
    disable_brakes: CircleOff,
    tire_burst: Disc,
    fuel_leak: Fuel,
    steer_left: CornerUpLeft,
    steer_right: CornerUpRight,
    lock_steering: LockKeyhole,
    open_doors: DoorOpen,
    eject_occupants: LogOut,
    lock_doors: Lock,
    random_spin: RotateCw,
    boost_launch: Rocket,
    flip_vehicle: FlipVertical2,
    horn_spam: Megaphone,
    speed_bomb: Bomb,
};

export function iconFor(actionId: string): LucideIcon {
    return ICONS[actionId] ?? Zap;
}
