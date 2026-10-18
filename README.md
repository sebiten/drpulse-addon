# Drpulse — WoW: Forever

Version 2.1.0. Adaptation of Forever DR 0.8.0 (reference ZIP), licensed under MIT with attribution to Tarolg. Drpulse integration and blue theme by Joaqoz.

Icons use a dark navy frame, cyan accent, and a bottom status rail. The `~` prefix marks an estimated time until DR resets; it does not represent the remaining CC duration. This release adds optional personal DR tracking while preserving enemy tracking behavior, settings refinements, and four-way nameplate placement.

## Features

- Complete reference engine: per-spell auras, public/partial/opaque native feed, your own casts, pets and group members, failure feedback, and estimates when no observable confirmation is available.
- Target and nameplate displays, filters for your own categories, bag items, Auto/Always/Never category modes, and custom spells.
- Optional personal DR display for incoming CC on your character, with independent positioning, size, lock, and preview.
- Learned durations, reset after CC ends, percentages/pips/count display, previews, context menu, and diagnostics.
- Estimated indicators are grey and may represent a cast without confirmed impact. Disable them under Tracking sources → Show unconfirmed casts.
- If the native feed is reported as unsupported, the remaining sources continue to work as in the reference addon.
- Settings open in a standalone movable Drpulse window with fixed navigation, blue/cyan accents, and a selectable PayPal support link. The Drpulse minimap button remains available.
- Settings navigation separates configuration from management and help, with Profiles last. Appearance starts with size and placement, then icon style, then categories. Wider columns, clearer contrast, visible input focus, and larger slider/reset hit areas improve readability and control. Hover styling reuses each button's existing border without allocating an extra frame.

## Profiles, appearance and visibility

- **General → On yourself:** enables the personal bar (off by default). **Appearance → Your DR display** controls its size, lock, horizontal/vertical position, reset, and preview. Unlock it and drag the Your DR header outside combat; right-click to lock. It uses the Target column's fonts, stack style, icon source, timer text, and swipe.
- **Personal evidence:** tracks readable CC auras on `player` and fully readable native player DR events. Its state is separate from enemies; enemy category filters, your spellbook, and enemy source toggles do not hide incoming CC. Combat/PvP visibility still applies, with previews and unlocked placement available for setup. Hidden/secret effects and applications before enabling or reloading cannot be reconstructed. PvP DR rules are used, including when incoming CC comes from NPCs. Taunts are excluded from personal tracking.
- **Profiles:** choose a shared account profile, copy it under a new name, or create one with defaults. Each character remembers its selection. Existing settings become the Default profile.
- **Switch with specialization:** optionally bind a selection to the current specialization (or talent group when supported). Unassigned specializations use the character's main profile. Automatic switches wait until combat ends. Shared profiles share edits; choose Current settings under Start from, then click Create profile for an independent copy.
- **Appearance → Icon style:** the Target and Nameplates columns independently control fonts, stacks, icon sources, timer text and swipes. Older settings retain the same appearance on both surfaces.
- **Appearance → Size and placement:** Nameplate icons offers Above, Below, Left, and Right. Nameplate offset controls separation from the selected edge; horizontal and vertical offsets fine-tune the position. Previews and shared profiles include all four positions.
- **General → Displays:** optionally show icons only in combat, only in battlegrounds/arenas, or only on the current target's nameplate. Combat and instance conditions combine. Hidden displays continue tracking DR; unlocked target displays and previews remain available for setup.
- **Profiles → Share profiles:** Export current selects a code for Ctrl+C. Paste a code into Profile code, enter a unique Imported profile name, and choose Import as new. Import never overwrites a profile. Codes include settings and custom spells, not character bindings or learned timing data.

## Installation and migration

Close WoW completely. Replace the `Drpulse` folder under `Interface/AddOns` with the folder from the ZIP, then launch the game again. Test each addon separately when comparing results.

The new runtime uses `DrpulseV2DB`. Existing `DrpulseDB` and `DRiftDB` data remains untouched. Compatible settings are migrated: size, reset window, visibility, categories, custom spells, center position, and minimap preferences. New tracking sources start with the reference defaults. The old standalone focus bar and history are not part of this runtime; focus remains a tracking source.

## Commands

- `/drpulse`: open settings and list commands.
- `/drpulse status`: print sources, counters, native data, and Blizzard options.
- `/drpulse unlock` and `/drpulse lock`: move or lock the target display.
- `/drpulse preview`: show a temporary preview.
- `/drpulse clear`: clear current tracking data.
- `/drpulse all` and `/drpulse mine`: switch the global category filter.
- `/drpulse reset`: restore the target display position.
- Minimap: left-click for settings, right-click to lock, drag to reposition.

## Validation

Twelve scenarios run against both the original ZIP and this adaptation: unsupported feed, repeated events, resistances, observable auras, pets/group, unconfirmed area effects, opaque events, secret identity, full names, expiry, duplicates, and restricted timing data.

The 2.1.0 checks compare 12 enemy scenarios with the packaged 2.0.0 runtime, execute both TOC module sets, and cover startup, rendering, profile sharing, visibility, and four-way nameplate placement. Personal checks cover aura/native deduplication, delayed confirmations, early ends, reset expiry, restricted fields, death, enemy isolation, visibility, preview, dragging, profile persistence, and disabled-state work. Package contents are verified byte-for-byte. Native frames are mocked, so these checks do not validate pixels, taint, or real-client event availability. In-game validation remains pending.

Run `node scripts/verify-release.mts releases/Drpulse-2.0.0-Forever.zip <fengari-module-path>` to repeat the checks. The personal aura adapter respects the access restrictions documented in Blizzard's [generated UnitAuras API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua).

`Core.spec.lua` and `UI.spec.lua` cover the historical 1.x implementation, which remains in the repository but is not loaded or distributed with this release.

## License

MIT. `THIRD-PARTY-LICENSE.txt` preserves Tarolg's complete notice. Adapted modules include attribution. Reproducible import logic is in `scripts/import-reference.mts`; Drpulse-specific integrations are in `Runtime/Integration.lua`.
