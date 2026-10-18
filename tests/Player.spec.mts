import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const runtime = process.argv[2];
if (!runtime) throw new Error('Usage: node tests/Player.spec.mts fengari-module-path');
const require = createRequire(import.meta.url);
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(runtime);
const state = lauxlib.luaL_newstate();
lualib.luaL_openlibs(state);
const setup = readFileSync('tests/SettingsFlow.spec.lua', 'utf8');
const checks = `
assert(loadfile("Drpulse/Runtime/Tracker.lua"))("Drpulse", ns)
assert(loadfile("Drpulse/Runtime/Player.lua"))("Drpulse", ns)
local clock, tasks, frames, auras, secretSpells = 100, {}, {}, {}, {}
local secret = {}
issecretvalue = function(value) return rawequal(value, secret) end
canaccesstable = function(value) return not rawequal(value, secret) end
GetTime = function() return clock end
local dead, visible, combat = false, true, false
UnitIsDeadOrGhost = function() return dead end
InCombatLockdown = function() return combat end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:GetWidth() return self.width or 100 end
function methods:GetHeight() return self.height or 30 end
function methods:GetCenter() return self.cx or 0, self.cy or 0 end
function methods:SetPoint(...) self.point = { ... } end
function methods:RegisterUnitEvent(event, unit) self.events[event] = unit end
function methods:RegisterEvent(event) self.events[event] = true end
CreateFrame = function() local f = object(); f.events = {}; frames[#frames + 1] = f; return f end
local queries = 0
C_UnitAuras = { GetUnitAuraBySpellID = function(unit, id)
    assert(unit == "player", "Personal scans must never query enemies")
    assert(not secretSpells[id], "Secret spells must not be queried")
    queries = queries + 1
    return auras[id]
end }
C_Secrets = { ShouldSpellAuraBeSecret = function(id) return secretSpells[id] or false end }
C_SpellDiminish = { IsSystemSupported = function() return true end }
Enum = { SpellDiminishCategory = { Stun = 2, Incapacitate = 4, Root = 0 } }
C_Timer = { After = function(delay, run) tasks[#tasks + 1] = { at = clock + delay, run = run } end }
local function advance(delta)
    clock = clock + delta
    for i = #tasks, 1, -1 do
        if tasks[i].at <= clock then local task = table.remove(tasks, i); task.run() end
    end
end
ns.TrackedIDs = function() return { [408] = true, [118] = true } end
ns.CategoryOf = function(id) return id == 408 and "Stun" or "Incapacitate" end
ns.VisibilityAllowed = function() return visible end
ns.RequestRefresh = function() end
ns.tracker = ns.NewTracker(function() return 18 end)
ns.tracker:Apply("enemy", "Root", clock, { confirmed = true, expires = clock + 6 })
local drawn
ns.LayoutRow = function(row, entries, size)
    drawn = entries
    row:SetSize(math.max(1, (entries and #entries or 0) * size), size)
    return entries and #entries or 0
end
ns.SettingsSamples = function() return { { category = "Stun", count = 1, sample = true } } end
ns.StartPlayerTracking()
local watcher = frames[#frames]
assert(watcher.events.UNIT_AURA == "player")
assert(watcher.events.UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED == "player")
ns.CreatePlayerDisplay()
local function event(name, payload) watcher.scripts.OnEvent(watcher, name, "player", payload) end
local function scan() event("UNIT_AURA"); advance(0.21) end
local function render() ns.RefreshPlayerDisplay(clock); return drawn and drawn[1] end
assert(not ns.db.player and ns.db.playerLocked)
scan(); assert(queries == 0 and not ns.RefreshPlayerDisplay(clock), "Disabled by default and no aura work")
ns.Set("player", true)
auras[118] = { auraInstanceID = 10, duration = 6, expirationTime = clock + 6 }
-- Enemy filters and group/cast sources must not hide incoming CC.
ns.db.categories.Incapacitate, ns.db.filter, ns.db.sources.group = "never", "mine", false
advance(0.21)
local first = assert(render())
assert(first.category == "Incapacitate" and first.count == 1 and first.confirmed)
assert(ns.tracker:Snapshot("enemy", clock)[1].category == "Root")
scan(); assert(render().count == 1, "Repeated aura snapshots must not increment DR")
auras[118] = nil; scan()
local ended = render()
assert(not ended.active and math.abs(ended.remaining - ns.db.resetTime) < 0.01)
advance(2)
auras[118] = { auraInstanceID = 11, duration = 3, expirationTime = clock + 3 }
scan(); assert(render().count == 2)
advance(1.1)
auras[118] = { auraInstanceID = 12, duration = 1.5, expirationTime = clock + 1.5 }
scan(); assert(render().count == 3 and render().immune)
auras[118] = nil; scan(); advance(19)
assert(not ns.RefreshPlayerDisplay(clock), "Personal driver demand ends after reset")
-- Public native data works independently and never leaks into the enemy tracker.
local payload = { category = 2, startTime = clock, duration = 6, showCountdown = false, isImmune = false }
event("UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", payload)
assert(render().category == "Stun" and render().count == 1)
advance(2); event("UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", payload)
assert(render().count == 1, "Duplicate native starts must not increment")
event("UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", secret)
event("UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", { category = secret, startTime = secret })
assert(render().count == 1)
assert(ns.tracker:State("Drpulse:player", "Stun", clock, false) == nil)
-- Aura and native can arrive more than the engine merge window apart.
ns.ClearPlayerTracking()
local appliedAt = clock
auras[408] = { auraInstanceID = 18, duration = 6, expirationTime = appliedAt + 6 }
scan(); advance(2)
event("UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", { category = 2, startTime = appliedAt, duration = 6, showCountdown = false, isImmune = false })
assert(render().count == 1, "Delayed native confirmation must not double-count an aura")
ns.ClearPlayerTracking(); auras = {}
appliedAt = clock
event("UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", { category = 2, startTime = appliedAt, duration = 6, showCountdown = false, isImmune = false })
advance(2)
auras[408] = { auraInstanceID = 19, duration = 6, expirationTime = appliedAt + 6 }
scan(); assert(render().count == 1, "Delayed aura must merge with the native application")
auras[408] = nil; scan(); assert(not render().active)
ns.ClearPlayerTracking()
auras[408] = { auraInstanceID = 20, duration = 6, expirationTime = clock + 6 }
scan(); local resetAt = render().resetAt
secretSpells[408] = true
auras[408] = nil; scan()
assert(render().resetAt == resetAt, "Restricted aura disappearance is not an early break")
secretSpells[408] = nil
scan(); assert(not render().active)
-- A public aura with restricted timing may count, but it must remain estimated.
advance(2)
auras[408] = { auraInstanceID = 21, duration = secret, expirationTime = secret }
scan(); assert(render().estimated)
-- Death clears state and cannot repopulate it from lingering debuffs.
dead = true; event("PLAYER_DEAD"); advance(0.21)
assert(not ns.RefreshPlayerDisplay(clock))
dead = false; auras = {}; event("PLAYER_ALIVE"); advance(0.21)
ns.PreviewPlayer(); assert(render().sample)
assert(ns.tracker:Snapshot("Drpulse:player", clock) == nil)
advance(21); assert(not ns.RefreshPlayerDisplay(clock))
-- Visibility only hides the bar; it does not disable personal evidence.
visible = false
auras[118] = { auraInstanceID = 30, duration = 6, expirationTime = clock + 6 }
scan(); assert(not ns.RefreshPlayerDisplay(clock))
visible = true; assert(render().category == "Incapacitate")
ns.Set("playerLocked", false); visible = false
assert(ns.RefreshPlayerDisplay(clock) and ns.playerDisplay.handle:IsShown())
ns.playerDisplay.cx, ns.playerDisplay.cy = 123, -234
ns.playerDisplay.handle.scripts.OnDragStart()
assert(ns.playerDisplay.moving)
ns.playerDisplay.handle.scripts.OnDragStop()
assert(ns.db.playerX == 123 and ns.db.playerY == -234)
assert(ns.db.x == 0 and ns.db.y == -150, "Moving your bar must not move target")
combat = true; ns.playerDisplay.handle.scripts.OnDragStart(); assert(not ns.playerDisplay.moving)
combat = false; ns.playerDisplay.handle.scripts.OnClick()
assert(ns.db.playerLocked and ns.db.locked)
ns.ResetPlayerPosition(); assert(ns.db.playerY == -220)
ns.Set("playerSize", 44)
local copied = assert(ns.DecodeProfile(assert(ns.ExportProfile())))
assert(copied.player and copied.playerSize == 44 and copied.playerY == -220)
ns.Set("enabled", false); assert(not ns.RefreshPlayerDisplay(clock))
ns.Set("enabled", true); ns.Set("player", false); advance(0.21)
local before = queries; scan(); assert(queries == before)
print("PASS personal aura/native DR, deduplication, expiry, secrets, death, isolation, visibility, preview, dragging, profiles and opt-in")
`;
const result = lauxlib.luaL_dostring(state, to_luastring(setup + checks));
if (result !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(state, -1)));
