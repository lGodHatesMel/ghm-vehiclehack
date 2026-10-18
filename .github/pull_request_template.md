## What this changes

<!-- What and why, in a few lines. Link the issue if there is one. -->

## Type

- [ ] Bug fix
- [ ] New action or option
- [ ] New inventory / fuel / framework support
- [ ] UI change
- [ ] Docs only

## Checklist

- [ ] Branched from the latest `main`, and the PR does one thing.
- [ ] Anything that matters is decided on the **server**. The client only sends intent (a `netId` and an action), never prices, durations or results.
- [ ] Server callbacks and events validate their arguments (types, ranges, ids).
- [ ] New config values are in `config.lua` with a comment, and documented in the README.
- [ ] Player-facing text goes in `locales/en.json`, not hard-coded in Lua or the UI.
- [ ] New natives were checked against the [native reference](https://github.com/citizenfx/natives), and the parameters and any "call every tick" notes are respected.
- [ ] A new inventory or fuel script is added to `bridge/inventory.lua` / `bridge/fuel.lua`, with the export names taken from that script's docs or source.
- [ ] No `backdrop-filter`, no emojis as icons, no debug commands left in.
- [ ] If `ui/src` changed: `npm run build` was run in `ui/` and `ui/dist` is included.
- [ ] `CHANGELOG.md` is updated.

## How you tested it

<!-- On a real server, not only by reading the code. Say what you tried: framework, inventory, fuel script, with a player driver and with an NPC driver where it matters. -->

- [ ] Tested in game
- [ ] Tested with sd-phone
- [ ] Tested standalone

## Screenshots / clips

<!-- For UI changes. Delete this section if not needed. -->
