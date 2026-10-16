# Drpulse 2.0.0-beta.8

October 16, 2026

## Performance

- Avoid reapplying unchanged icon textures, text, colors, sizes and positions during display updates.
- Reuse snapshot lists when filtering categories and avoid repeatedly hiding unused pooled icons.
- Update nameplate anchors and the display update handler only when necessary.
- Preserve timer frequency, tracking behavior and restricted-value handling.

Includes the settings redesign and font/position controls from previous beta releases.

## Validation

- All 12 tracking regression scenarios passed against beta.7.
- Display regression checks passed for timer and style changes, fonts, pooled icons, offsets, secret borders and previews.
- An isolated 100-update test recorded 92.3% fewer mocked UI mutation calls. This is not an in-game FPS measurement; in-game validation remains pending.