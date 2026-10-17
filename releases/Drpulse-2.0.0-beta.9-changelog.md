# Drpulse 2.0.0-beta.9

October 16, 2026

## Added

- **Profiles:** Account-wide named profiles with per-character selection, independent copies and optional specialization/talent-group switching. Automatic switches wait until combat ends. Find them under Tools.
- **Independent appearance:** Configure fonts, stack styles, timer text, cooldown swipes and icon sources separately for the target and nameplates under Appearance.
- **Context visibility:** Show icons only in combat, only inside battlegrounds/arenas, or only on your current target's nameplate. Tracking continues while icons are hidden. Configure these under General.
- **Profile sharing:** Export a configuration code or import one as a new profile under Tools. Invalid codes are rejected without overwriting existing settings.

## Compatibility

- Existing settings become the Default profile.
- Existing shared styles are preserved on both the target and nameplates.
- Profile codes exclude character bindings and learned timing data.

## Validation

Tracking regression scenarios and automated profile, display, visibility and settings-flow checks passed. These new features still need in-game validation.