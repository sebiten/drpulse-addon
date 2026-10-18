# Audit 2.1.0 - October 17, 2026

Personal DR is implemented in `Runtime/Player.lua`, with its own tracker and player-only event subscriptions. It never submits evidence to the enemy tracker or uses enemy pending casts. It follows public-value checks before consuming aura/native metadata and skips restricted spells. The display reuses the existing renderer and timer; it has independent positioning, size and locking and is disabled by default.

Validation: 12 enemy scenarios compared with the packaged 2.0.0 runtime; both TOC sets parsed and startup exercised with visual constructors stubbed; rendering, profiles, visibility, four-way nameplate placement, and personal tracking/display interaction checks passed. Personal cases cover duplicates and delayed confirmations, reset/expiry, secret values, death, enemy isolation, visibility, preview, drag/lock, profile round-trip, and disabled-state work.

Pending: real WoW rendering, taint and event availability. Hidden CC and earlier applications cannot be reconstructed. Personal aura counts start from observed evidence; incoming NPC CC uses PvP rules. No claim of complete visibility under restricted client APIs.

## Original foundation audit: 2.0.0-beta.1

The active foundation is replaced by the nine modules from the Forever DR 0.8.0 ZIP, adapted under MIT. The TOC files load Runtime and the minimap integration; they do not load the 1.x Bootstrap/Core/UI/Options/Data modules.

Import transformations affect product names, commands, globals, module names, visual accents, and integration points. The engine and evidence adapters preserve the reference algorithms. `Integration.lua` adds non-destructive migration and the minimap bridge.

Verification: 12 functional scenarios executed against both implementations (24 runs), plus migration, reload, incompatible schema handling, parsing of every TOC module, and startup with visual constructors replaced. No Fengari errors.

Pending: validation of settings, previews, rendering, and real WoW restrictions. Cast estimates are enabled as in the reference addon and do not represent confirmed impacts. Accuracy cannot be guaranteed when the client provides no public evidence.

The design uses cyan accents and dark navy surfaces while preserving semantic DR colors. The 1.x focus bar and history are not part of the reference runtime. Existing data is preserved, and the previous ZIP can restore 1.x.
