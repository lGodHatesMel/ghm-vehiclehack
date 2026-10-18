import { call, callData } from './nui';
import type { AppConfig, Envelope, HackOverview, HackPick, HackRun, HackScan } from './types';

// What the app asks of the game. The server decides everything; these only send intents.

export const fetchConfig = () => callData<AppConfig>('getConfig');
export const fetchOverview = () => callData<HackOverview>('overview');
/** The vehicles within reach right now. Read from the game world, so cheap enough to poll. */
export const fetchScan = () => callData<HackScan>('scan');
/** Starts aiming. In sd-phone the camera opens; standalone, the screen goes away for a crosshair. */
export const startAim = () => call('aim');
/** The aim's result, handed over once: null when nothing is waiting. */
export const takePick = () => callData<HackPick>('takePick');
export const runAction = (netId: number, action: string): Promise<Envelope<HackRun>> => call<HackRun>('execute', { netId, action });
export const removeTag = (netId: number) => call('untag', { netId });
export const removeAllTags = () => call('untag', { all: true });
export const closeScreen = () => call('closeUI');
