export type Risk = 'low' | 'medium' | 'high';

export interface HackAction {
    id: string;
    category: string;
    label: string;
    description: string;
    /** Seconds the effect lasts; 0 is instant. */
    duration: number;
    risk: Risk;
    cost: number;
}

export interface HackCategory {
    id: string;
    label: string;
    description: string;
    actions: HackAction[];
}

/** The one money type actions are paid in: its name, short form and how an amount of it is written. */
export interface HackCurrency {
    id: string;
    label: string;
    symbol: string;
    /** True: "$150". False: "150 SCR". */
    symbolFirst: boolean;
    decimals: number;
}

export interface HackOverview {
    targeting: { tagged: boolean; aim: boolean };
    tag: { item: string; range: number };
    /** Metres a vehicle can be from the player and still be hacked. */
    scanRadius: number;
    /** Metres the crosshair can reach. */
    aimRange: number;
    cooldownMs: number;
    freeMode: boolean;
    currency: HackCurrency;
    /** The player's balance of `currency`, whether or not free mode is on. */
    balance: number;
    /** False when the framework does not track the currency for this player. */
    walletOk: boolean;
    speedUnit: 'mph' | 'kmh';
    speedBomb: { threshold: number; armDelayMs: number; maxArmedMs: number };
    categories: HackCategory[];
    tags: number[];
}

export interface HackVehicle {
    netId: number;
    via: 'tag' | 'aim';
    model: string;
    plate: string;
    distance: number;
    inRange: boolean;
    occupants: number;
    driver: boolean;
    locked: boolean;
}

export interface HackScan {
    vehicles: HackVehicle[];
    aimed?: HackVehicle;
}

/** What an aim came back with. `ok` false with no message means the player cancelled it. */
export interface HackPick {
    ok: boolean;
    netId?: number;
    message?: string;
}

export interface HackRun {
    id: string;
    label: string;
    /** Seconds the effect lasts. */
    duration: number;
    cost: number;
    balance: number;
}

/** The shape every server answer takes. */
export interface Envelope<T = void> {
    success: boolean;
    message?: string;
    code?: string;
    data?: T;
}

export interface AppConfig {
    /** True when this page is the resource's own screen rather than a page inside sd-phone. */
    standalone: boolean;
    strings: Record<string, string>;
}
