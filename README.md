# Espi SealCheck

Espi SealCheck is a lightweight Paladin addon that warns you when you're in combat with **no Seal active**.

Buffs are hidden ("secret") in combat, so it tracks your seal by watching your own seal casts and the seal duration it learned out of combat. Nothing to configure to get started.

## Features
- Pulsing **NO SEAL** alert with sound when you're in combat without a seal
- Icon shows your actual last-used Seal
- **SEAL EXPIRING** cue with countdown (default 5s before it drops)
- Optional repeating sound while unsealed
- **NO AUTO ATTACK** warning when you're in combat but not auto-attacking
- Combat-start grace period so it doesn't nag while you cast your opening seal
- Optional hiding while mounted or in a vehicle
- Draggable, resizable icon; options panel via `/seal config`
- Does nothing on non-Paladin characters

## Commands
`/seal` or `/sealcheck`

| Command | Effect |
|---|---|
| `config` | Open the options panel |
| `unlock` / `lock` | Move the icon |
| `test` | Preview the alert for 3 seconds |
| `toggle` | Enable / disable the addon |
| `sound` | Toggle the warning sound |
| `attack` | Toggle the "NO AUTO ATTACK" warning |
| `mounted` / `vehicle` | Toggle hiding while mounted / in a vehicle |
| `size <16-256>` | Icon size in pixels |
| `warn <sec>` | Expiring-warning time (0 = off) |
| `repeat <sec>` | Repeat the sound every N seconds (0 = off) |
| `grace <sec>` | Delay after combat starts before alerting |
| `reset` | Reset position and size |
| `status` | Show tracked seal state and learned durations |

## Installation
Extract the `SealCheck` folder into your `Interface/AddOns` directory.

## Known limitations
- In combat the addon can't read your buffs, so it estimates seal time from your casts. If a seal is dispelled mid-fight, SealCheck won't know until combat ends.
- If your own spell cast is hidden from addons during a fight, or you `/reload` mid-fight, warnings are paused for the rest of that fight.
- Seal detection currently matches English spell names ("Seal of ...").

## License
MIT
