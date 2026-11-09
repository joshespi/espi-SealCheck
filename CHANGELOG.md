# Changelog

## Unreleased
- Casting Judgement now clears the tracked seal, so NO SEAL fires right after you judge.
- Reloading mid-fight no longer shows a false NO SEAL; warnings pause until that fight ends.
- Expiring countdown rounds up (no more "0" with time left).
- Slash-command values snap to the same steps as the options sliders.
- Options panel checkbox labels are clickable.

## 1.1.0
- Icon now shows your actual last-used Seal (remembered between sessions).
- New "SEAL EXPIRING" cue with a countdown when a seal is about to drop (default 5s, configurable, 0 = off).
- Optional repeating warning sound while unsealed.
- Warning text scales with icon size.
- Unlocked mode shows a green "DRAG ME" frame so it can't be mistaken for an alert.
- Slash commands now confirm every change; new `warn`, `repeat`, `grace`, `mounted`, `vehicle`, `config` commands.
- New options panel (`/seal config`).
- Optional hiding while mounted or in a vehicle.
- Combat-start grace period (default 1s) so the alert doesn't flash while you cast your opening seal.

## 1.0.0
- Initial release: in-combat "NO SEAL" warning for Paladins, draggable icon, sound alert.
