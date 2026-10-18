# DRPulse | Diminishing Returns Tracker for WoW: Forever

**Track crowd control. Read the next DR stage. Make better PvP decisions.**

DRPulse is a lightweight and customizable diminishing returns tracker built specifically for **World of Warcraft: Forever**.

It tracks crowd-control diminishing returns on your current target, enemy nameplates, and optionally your own character, showing reset timers, immunity, and the expected duration of the next crowd-control effect.

DRPulse combines Blizzard's native DR feed with readable auras, your casts, pet and group casts, and combat feedback. When the game does not expose enough information to confirm an effect, DRPulse marks the result as estimated instead of presenting it as certain.

## Official Website

**[drpulse.dev](https://drpulse.dev/)**

---

## Version 2.1.0

Adds an optional personal DR bar to the stable Drpulse 2.x series for WoW: Forever.

Enable **General → On yourself**, then configure **Appearance → Your DR display**. The personal bar has its own size, lock, drag position, and preview; its icon style follows the Target column. It tracks readable incoming CC independently of enemy filters. Client-restricted effects and applications before enabling or reloading may be unavailable.

- Standalone movable settings window.
- Refined settings organized into General, Appearance, Detection, Tools, Guide, and Profiles.
- Clearer navigation groups, wider control columns, improved contrast, and visible input focus.
- Appearance opens with size and placement, followed by icon style and categories.
- Lightweight hover feedback using existing button borders, with no added animation loops.
- Target and enemy nameplate DR displays.
- Five icon font options with live previews.
- Above, below, left, or right nameplate icon placement, with edge separation and horizontal/vertical offsets.
- Native, aura, cast, pet, group, and combat-feedback tracking sources.
- Optional PayPal support link available directly in settings.
- All commands and documentation standardized on `/drpulse`.

Forever DR is not required. If you are comparing both addons, disable the reference addon while testing DRPulse.

---

## Features

### Diminishing Returns Tracking

- **Target display:** Track DR on your current enemy target.
- **Enemy nameplates:** Show DR icons above or below visible enemy nameplates.
- **Eight DR categories:** Stun, Incapacitate, Disorient/Fear, Root, Silence, Disarm, Taunt, and Knockback.
- **Reset timers:** See the remaining time before each category resets.
- **Next-stage indicators:** See whether the next CC is expected to last 50%, 25%, or have no effect due to immunity.
- **Last-spell or category icons:** Choose how each DR category is represented.
- **Countdown swipe and timer text:** Configure both independently.

### Smart Evidence Handling

- Blizzard native diminishing-returns updates when available.
- Readable enemy CC auras.
- Your own and your pet's successful casts.
- Party and raid member CC.
- Immune, miss, and resist feedback.
- Optional unconfirmed-cast estimates when no confirming source is available.
- Learned CC durations and configurable DR reset time.

### Customization

- Movable and resizable target display.
- Adjustable target and nameplate icon sizes.
- Configurable nameplate position and offset.
- Auto, Always, or Never visibility for every DR category.
- Filter categories to effects your character can apply.
- Optional detection of CC items in your bags.
- Custom spell-to-category overrides.
- Live previews and a 20-second on-screen sample mode.
- Built-in diagnostics and status reporting.
- Minimap and AddOn Compartment access.

### Standalone Settings

`/drpulse` opens a standalone window that can be moved anywhere on screen. Settings are separated into five focused areas:

- **General:** Enable DRPulse, choose display surfaces, lock the target display, and configure category filtering.
- **Appearance:** Category visibility, previews, icon sizes, placement, timers, and icon style.
- **Detection:** Tracking sources, reset timing, and Blizzard DR data.
- **Tools:** Custom spells, maintenance actions, and diagnostics.
- **Guide:** Mouse controls and complete command reference.

The bottom of the window includes an optional PayPal support link. Select it and press `Ctrl+C` to copy it.

---

## Data Confidence

WoW: Forever may restrict enemy combat information in some PvP situations. DRPulse respects those restrictions and never attempts to bypass Blizzard's addon API.

- **Confirmed data:** Supported by Blizzard's native feed or a readable aura.
- **Estimated data:** Derived from observable casts when no confirmation is available. Estimated timers are displayed in grey and prefixed with `~`.
- **Unknown data:** DRPulse avoids inventing precise timing or stages when the client does not expose enough evidence.

Blizzard's native DR system remains authoritative whenever readable native data is available.

---

## Slash Commands

- `/drpulse`: Open settings and print the command list.
- `/drpulse options` or `/drpulse config`: Open settings without printing the command list.
- `/drpulse unlock`: Show the target display controls so it can be moved and resized.
- `/drpulse lock`: Lock the target display in place.
- `/drpulse reset`: Restore the target display to its default position.
- `/drpulse preview` or `/drpulse test`: Show sample icons for 20 seconds.
- `/drpulse clear`: Forget all currently tracked DR states.
- `/drpulse all`: Show every DR category.
- `/drpulse mine`: Show only categories your character can apply.
- `/drpulse status`: Print the version, build, evidence counters, and Blizzard DR status.

---

## Installation

1. Download and extract DRPulse.
2. Copy the `Drpulse` folder into your WoW: Forever AddOns directory: `_classic_beta_/Interface/AddOns/`.
3. Restart World of Warcraft.
4. Type `/drpulse` in chat to open the settings window.

---

## Compatibility

- **Game:** World of Warcraft: Forever
- **Game version:** 1.60.1
- **Interface:** 16001
- **Game flavor:** Camelot
- **Release stage:** Functional Beta

---

## Privacy and Performance

- No telemetry or analytics.
- No advertisements.
- No collection or transmission of personal information.
- No required external addon dependencies.

---

## Support DRPulse

DRPulse is free and will remain free. If it helps you in PvP and you would like to support future updates, you can make an optional one-time donation.

**[Support DRPulse on PayPal](https://paypal.me/sebiten)**

The same link is available inside the DRPulse settings window.

---

## License and Attribution

DRPulse 2.x includes an MIT-licensed adaptation of the Forever DR 0.8.0 tracking foundation, with attribution to Tarolg. Drpulse-specific integration, interface, migration, and visual design are maintained by Joaqoz.

---

**DRPulse: Track smarter. Control better.**
