## Drpulse 2.1.0 - October 17, 2026

### Your own diminishing returns

- Enable **General → On yourself** to see incoming CC on a separate personal DR bar. Off by default, preserving existing layouts.
- Configure **Appearance → Your DR display**: icon size, lock, horizontal/vertical position, reset, and a 20-second preview. Unlock and drag the header outside combat; right-click to lock.
- Personal icons use the Target column's style, with independent size and position.
- Incoming CC is independent of enemy filters and your spellbook. Combat/PvP visibility still applies; previews and unlocked setup remain available.
- Personal tracking uses readable player auras and fully readable native events. Duplicate/delayed confirmations do not count the same CC twice. It does not infer CC from opaque events or enemy casts.
- Personal settings are saved in profiles. The existing target and nameplate behavior is preserved, including four-way nameplate placement and the refined settings UI.

### Installation

Close WoW completely. Replace the `Drpulse` folder in `Interface/AddOns` with the folder from `Drpulse-2.1.0-Forever.zip`, then relaunch. Keep SavedVariables to preserve settings and profiles.

### Validation and limits

Automated checks passed for 12 enemy scenarios against 2.0.0, both TOC module sets, startup, rendering, profiles, visibility, nameplate positions, and personal tracking/display interactions. The ZIP is verified byte-for-byte. In-game visual, taint, and event-availability validation remains pending.

Client-restricted effects and applications before enabling/reloading cannot be reconstructed. Personal tracking uses PvP DR rules, including incoming NPC CC, and excludes taunts.
