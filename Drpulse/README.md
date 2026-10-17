# Drpulse — WoW: Forever

Version 2.0.0-beta.9. Adaptation of Forever DR 0.8.0 (reference ZIP), licensed under MIT with attribution to Tarolg. Drpulse integration and blue theme by Joaqoz.

Icons use a dark navy frame, cyan accent, and a bottom status rail. The `~` prefix marks an estimated time until DR resets; it does not represent the remaining CC duration. This visual update keeps the beta.1 tracking engine unchanged.

## Features

- Complete reference engine: per-spell auras, public/partial/opaque native feed, your own casts, pets and group members, failure feedback, and estimates when no observable confirmation is available.
- Target and nameplate displays, filters for your own categories, bag items, Auto/Always/Never category modes, and custom spells.
- Learned durations, reset after CC ends, percentages/pips/count display, previews, context menu, and diagnostics.
- Estimated indicators are grey and may represent a cast without confirmed impact. Disable them under Tracking sources → Show unconfirmed casts.
- If the native feed is reported as unsupported, the remaining sources continue to work as in the reference addon.
- Settings open in a standalone movable Drpulse window with fixed navigation, blue/cyan accents, and a selectable PayPal support link. The Drpulse minimap button remains available.

## Profiles, appearance and visibility

- **Tools → Profiles:** choose a shared account profile, copy it under a new name, or create one with defaults. Each character remembers its selection. Existing settings become the Default profile.
- **Switch with specialization:** optionally bind a selection to the current specialization (or talent group when supported). Unassigned specializations use the character's main profile. Automatic switches wait until combat ends. Shared profiles share edits; use Copy current for an independent copy.
- **Appearance → Icon style:** the Target and Nameplates columns independently control fonts, stacks, icon sources, timer text and swipes. Older settings retain the same appearance on both surfaces.
- **General → Displays:** optionally show icons only in combat, only in battlegrounds/arenas, or only on the current target's nameplate. Combat and instance conditions combine. Hidden displays continue tracking DR; unlocked target displays and previews remain available for setup.
- **Tools → Share profile:** Export current selects a code for Ctrl+C. Paste a code into Profile code, enter a unique New profile name, and choose Import as new. Import never overwrites a profile. Codes include settings and custom spells, not character bindings or learned timing data.

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

Migration, data preservation, execution of both TOC module sets, and startup/command wiring are also checked. Startup tests replace visual constructors, so they do not validate pixels, taint, or the real client. This beta still requires in-game validation.

`Core.spec.lua` and `UI.spec.lua` cover the historical 1.x implementation, which remains in the repository but is not loaded or distributed with this beta.

## License

MIT. `THIRD-PARTY-LICENSE.txt` preserves Tarolg's complete notice. Adapted modules include attribution. Reproducible import logic is in `scripts/import-reference.mts`; Drpulse-specific integrations are in `Runtime/Integration.lua`.
