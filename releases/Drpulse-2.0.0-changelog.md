## Drpulse 2.0.0 - October 17, 2026

First stable-channel release of the 2.x series, with refined settings and four-way nameplate placement.

- Clearer navigation groups, section descriptions, and selected states. Profiles remains last.
- Appearance starts with size and placement, then icon style, then categories.
- Nameplate icons now offers Above, Below, Left, and Right. Edge separation, horizontal/vertical offsets, previews, and saved/shared profiles support every position.
- More readable text, wider columns, consistent controls, and clearer Target / Nameplates labels.
- Visible input focus, native checkbox marks, and larger slider/reset hit areas.
- Distinct primary actions and warm-colored reset/remove actions.
- Compact tracking status and support footer, preserving the donation link.
- Fewer UI frames: hover feedback uses existing borders. No new animation loops or dependencies.
- Tracking and profile operations are unchanged; existing settings remain compatible.

### Installation

Close WoW completely. Replace the `Drpulse` folder in `Interface/AddOns` with the folder from `Drpulse-2.0.0-Forever.zip`, then relaunch. Keep your SavedVariables to retain settings and profiles.

### Verification

Source changes reviewed and package contents verified byte-for-byte. Focused checks passed for four-way placement, offset extremes, cached anchors, preview bounds, profile round-trips, and selector actions. No build or lint was run. The settings layout still needs visual validation in the WoW client.
