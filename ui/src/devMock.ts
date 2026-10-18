// Dev-only stand-in for the game, so `npm run dev` has something to talk to. It is imported from
// main.tsx behind `import.meta.env.DEV`, so the production build never contains it.
//
// Address bar (e.g. http://localhost:5173/?mode=standalone#paid):
//   ?mode=phone | standalone   which frame to preview (default phone)
//   #default  free, both targeting modes      #paid  free mode off, 800.00 SCR (two places)
//   #cash     free mode off, dollars ("$150")  #nowallet  the framework does not track the currency
//   #empty    nothing tagged                  #aimonly / #taggedonly  one targeting mode
//   #offline  the server does not answer
// Every action sent is recorded on window.__vhLog; window.__vhDev has dropTag(netId), setBalance(n).
import type { Envelope, HackCategory, HackOverview, HackPick, HackRun, HackScan, HackVehicle } from './types';

type Scenario = 'default' | 'paid' | 'cash' | 'empty' | 'aimonly' | 'taggedonly' | 'offline' | 'nowallet';

const params = new URLSearchParams(window.location.search);
const standalone = params.get('mode') === 'standalone';
const hash = window.location.hash.replace('#', '');
const scenario: Scenario = (['paid', 'cash', 'empty', 'aimonly', 'taggedonly', 'offline', 'nowallet'] as const).find(s => s === hash) ?? 'default';

const CATEGORIES: HackCategory[] = [
    {
        id: 'sabotage', label: 'Sabotage', description: 'Disable and damage vehicle systems',
        actions: [
            { id: 'engine_kill', category: 'sabotage', label: 'Kill Engine', description: 'Shuts the engine down for good.', duration: 0, risk: 'high', cost: 150 },
            { id: 'brake_lock', category: 'sabotage', label: 'Lock Brakes', description: 'Forces the handbrake on.', duration: 8, risk: 'high', cost: 120 },
            { id: 'disable_brakes', category: 'sabotage', label: 'Disable Brakes', description: "The driver's brake and handbrake stop responding.", duration: 10, risk: 'high', cost: 140 },
            { id: 'tire_burst', category: 'sabotage', label: 'Burst Tires', description: 'Blows out all four tires.', duration: 0, risk: 'medium', cost: 60 },
            { id: 'fuel_leak', category: 'sabotage', label: 'Fuel Leak', description: 'Drains the tank until it is empty.', duration: 15, risk: 'medium', cost: 80 },
        ],
    },
    {
        id: 'control', label: 'Control', description: 'Take over steering, doors and seats',
        actions: [
            { id: 'steer_left', category: 'control', label: 'Force Left', description: 'Pulls the wheel hard to the left.', duration: 1.5, risk: 'medium', cost: 40 },
            { id: 'steer_right', category: 'control', label: 'Force Right', description: 'Pulls the wheel hard to the right.', duration: 1.5, risk: 'medium', cost: 40 },
            { id: 'lock_steering', category: 'control', label: 'Lock Steering', description: 'The driver can no longer turn the wheel.', duration: 5, risk: 'high', cost: 90 },
            { id: 'open_doors', category: 'control', label: 'Force Doors', description: 'Unlocks the vehicle and swings every door open.', duration: 0, risk: 'low', cost: 20 },
            { id: 'eject_occupants', category: 'control', label: 'Eject Occupants', description: 'Throws everyone out of the vehicle.', duration: 0, risk: 'medium', cost: 100 },
            { id: 'lock_doors', category: 'control', label: 'Lock Doors', description: 'Locks the doors and traps everyone inside.', duration: 20, risk: 'high', cost: 130 },
        ],
    },
    {
        id: 'chaos', label: 'Chaos', description: 'Unpredictable vehicle effects',
        actions: [
            { id: 'random_spin', category: 'chaos', label: 'Spin Out', description: 'Spins the vehicle around.', duration: 2, risk: 'high', cost: 100 },
            { id: 'boost_launch', category: 'chaos', label: 'Boost Launch', description: 'Launches the vehicle forward.', duration: 0, risk: 'high', cost: 130 },
            { id: 'flip_vehicle', category: 'chaos', label: 'Flip Vehicle', description: 'Tips the vehicle onto its side.', duration: 0, risk: 'high', cost: 150 },
            { id: 'horn_spam', category: 'chaos', label: 'Horn Spam', description: 'Leans on the horn.', duration: 5, risk: 'low', cost: 15 },
            { id: 'speed_bomb', category: 'chaos', label: 'Speed Bomb', description: 'Explodes the vehicle when it slows down.', duration: 0, risk: 'high', cost: 250 },
        ],
    },
];

const COOLDOWN_MS = 2000;
const BASE: Omit<HackVehicle, 'distance'>[] = [
    { netId: 101, via: 'tag', model: 'Sultan RS', plate: '42ABC123', inRange: true, occupants: 0, driver: false, locked: true },
    { netId: 102, via: 'tag', model: 'Buffalo STX', plate: 'KQ7ZN904', inRange: true, occupants: 2, driver: true, locked: false },
    { netId: 103, via: 'tag', model: 'Granger', plate: 'LSPD 071', inRange: false, occupants: 0, driver: false, locked: false },
];
const AIMED: Omit<HackVehicle, 'distance'> = { netId: 201, via: 'aim', model: 'Kuruma', plate: 'ZX81 QRT', inRange: true, occupants: 1, driver: true, locked: false };
const DISTANCE: Record<number, number> = { 101: 12, 102: 34, 103: 142, 201: 27 };

const dev = { tags: [101, 102, 103], aimed: false, pick: null as HackPick | null, balance: 800, lastRunAt: 0 };

interface DevLogEntry { action: string; netId: number; cost: number; at: number }
declare global { interface Window { __vhLog?: DevLogEntry[]; __vhDev?: { dropTag: (netId: number) => void; setBalance: (n: number) => void } } }
window.__vhDev = {
    dropTag: netId => { dev.tags = dev.tags.filter(id => id !== netId); },
    setBalance: amount => { dev.balance = amount; },
};

const delay = (ms: number) => new Promise(resolve => window.setTimeout(resolve, ms));
const vehicle = (base: Omit<HackVehicle, 'distance'>): HackVehicle =>
    ({ ...base, distance: Math.max(1, DISTANCE[base.netId] + Math.sin(Date.now() / 1700 + base.netId) * 1.5) });
const hasTags = () => scenario !== 'empty' && scenario !== 'aimonly';

function overview(): HackOverview {
    return {
        targeting: { tagged: scenario !== 'aimonly', aim: scenario !== 'taggedonly' },
        tag: { item: 'vehicle_tag', range: 3 },
        scanRadius: 100,
        aimRange: 50,
        cooldownMs: COOLDOWN_MS,
        freeMode: scenario !== 'paid' && scenario !== 'cash',
        currency: scenario === 'cash'
            ? { id: 'cash', label: 'Cash', symbol: '$', symbolFirst: true, decimals: 0 }
            : { id: 'script', label: 'Script', symbol: 'SCR', symbolFirst: false, decimals: scenario === 'paid' ? 2 : 0 },
        balance: dev.balance,
        walletOk: scenario !== 'nowallet',
        speedUnit: 'mph',
        speedBomb: { threshold: 20, armDelayMs: 3000, maxArmedMs: 60_000 },
        categories: CATEGORIES,
        tags: hasTags() ? dev.tags : [],
    };
}

function scan(): HackScan {
    return {
        vehicles: hasTags() ? BASE.filter(v => dev.tags.includes(v.netId)).map(vehicle) : [],
        aimed: dev.aimed ? vehicle(AIMED) : undefined,
    };
}

async function execute(payload: { netId: number; action: string }): Promise<Envelope<HackRun>> {
    await delay(180);
    const def = CATEGORIES.flatMap(c => c.actions).find(a => a.id === payload.action);
    if (!def) return { success: false, code: 'unknown_action', message: 'Unknown action.' };
    if (Date.now() - dev.lastRunAt < COOLDOWN_MS) return { success: false, code: 'cooldown', message: 'Wait a moment before the next action.' };
    if (![...dev.tags, AIMED.netId].includes(payload.netId)) return { success: false, code: 'not_linked', message: 'That vehicle is no longer linked.' };
    const paid = scenario === 'paid' || scenario === 'cash';
    if (paid && dev.balance < def.cost) return { success: false, code: 'insufficient_funds', message: "You can't afford that." };
    dev.lastRunAt = Date.now();
    if (paid) dev.balance -= def.cost;
    (window.__vhLog ??= []).push({ action: payload.action, netId: payload.netId, cost: paid ? def.cost : 0, at: Date.now() });
    return {
        success: true,
        data: { id: def.id, label: def.label, duration: def.id === 'speed_bomb' ? 63 : def.duration, cost: paid ? def.cost : 0, balance: dev.balance },
    };
}

window.fetchNui = (async (event: string, data?: unknown) => {
    switch (event) {
        case 'getConfig': return { success: true, data: { standalone, strings: {} } };
        case 'overview':
            await delay(120);
            return scenario === 'offline' ? { success: false } : { success: true, data: overview() };
        case 'scan': return { success: true, data: scan() };
        case 'aim': dev.aimed = true; dev.pick = { ok: true, netId: AIMED.netId }; return { success: true };
        case 'takePick': { const pick = dev.pick; dev.pick = null; return { success: true, data: pick } }
        case 'execute': return execute(data as { netId: number; action: string });
        case 'untag': {
            const payload = data as { netId?: number; all?: boolean };
            dev.tags = payload.all ? [] : dev.tags.filter(id => id !== payload.netId);
            return { success: true };
        }
        case 'closeUI': window.postMessage({ action: 'standaloneClose' }, '*'); return { success: true };
        default: return { success: false };
    }
}) as unknown as typeof window.fetchNui;

declare global { interface Window { fetchNui?: <T = unknown>(event: string, data?: unknown, scriptName?: string) => Promise<T> } }

if (standalone) {
    // The standalone screen waits for the game to open it; in the browser, do that after a beat.
    window.setTimeout(() => window.postMessage({ action: 'standaloneOpen' }, '*'), 400);
}
