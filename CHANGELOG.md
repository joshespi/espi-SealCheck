# Changelog

## 1.0.1

- Removed: Judgement no longer clears the tracked seal (on Forever it doesn't consume your seal), fixing a false NO SEAL after judging.

## 1.0.0

Initial release.

- In-combat "NO SEAL" warning for Paladins, with an optional sound alert.
- Icon shows your last-used Seal and remembers it between sessions.
- Casting Judgement clears the tracked seal, so NO SEAL fires right after you judge.
- "SEAL EXPIRING" cue with a countdown when a seal is about to drop (default 5s, configurable, 0 = off).
- Optional repeating warning sound while unsealed.
- Combat-start grace period (default 1s) so the alert doesn't flash while you cast your opening seal.
- Reloading mid-fight doesn't trigger a false NO SEAL; warnings pause until that fight ends.
- Optional hiding while mounted or in a vehicle.
- Draggable icon; warning text scales with icon size. Unlocked mode shows a green "DRAG ME" frame so it can't be mistaken for an alert.
- Options panel (`/seal config`) and slash commands (`warn`, `repeat`, `grace`, `mounted`, `vehicle`, `config`, and more). Every change is confirmed in chat.
