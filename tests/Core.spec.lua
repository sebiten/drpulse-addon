-- Run from the repository root with Lua 5.3+ or fengari.
local clock, units, auras, ns
local secret = {}
GetTime = function() return clock end
UnitGUID = function(unit) return units[unit] end
UnitExists = function(unit) return units[unit] ~= nil end
UnitName = function() return "Same name" end
issecretvalue = function(value) return rawequal(value, secret) end
date = function() return "12:00:00" end
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function() end }
end
C_UnitAuras = { GetAuraDataByIndex = function(unit, index) return (auras[unit] or {})[index] end }

local function setup()
    clock, units, auras, ns = 100, { target = "A", focus = "A" }, {}, {}
    UnitCanAttack, UnitIsDeadOrGhost, C_SpellDiminish, C_CVar = nil, nil, nil, nil
    C_UnitAuras.GetAuraDataByIndex = function(unit, index) return (auras[unit] or {})[index] end
    assert(loadfile("Drpulse/Bootstrap.lua"))("Drpulse", ns)
    assert(loadfile("Drpulse/Data.lua"))("Drpulse", ns)
    ns.db = ns:Copy(ns.DEFAULTS)
    assert(loadfile("Drpulse/Core.lua"))("Drpulse", ns)
    return ns.Core
end
local function aura(id) return { auraInstanceID = id, spellId = 408 } end
local function entry(core) return core:GetUnitState("target", false).categories[2] end
local function native(start, duration, immune, countdown)
    return { category = 2, startTime = start, duration = duration, isImmune = immune == true, showCountdown = countdown ~= false }
end
local passed = 0
local function test(name, body)
    body(setup())
    passed = passed + 1
    print("PASS " .. name)
end

test("same names and reused tokens never share another GUID's state", function(core)
    auras.target = { aura(1) }; core:ScanAuras("target")
    units.target = "B"; auras.target = {}; core:ScanAuras("target")
    assert(entry(core) == nil)
    units.target = secret
    assert(core:GetUnitState("target", true).key == "unit:target")
    assert(core:ApplyNative("target", native(100, 18)))
    assert(entry(core).source == "Blizzard")
end)

test("restricted GUID and reaction retain token-scoped DR", function(core)
    units.target = secret
    UnitCanAttack = function() return secret end
    auras.target = { aura(1) }
    core:ScanAuras("target")
    assert(entry(core).active and entry(core).applications == 1)
    core:ReleaseUnit("target")
    assert(core.units["unit:target"] == nil)
    auras.target = {}
    assert(core:GetUnitState("target", false) == nil)
end)

test("target and focus deduplicate by GUID and aura instance", function(core)
    auras.target = { aura(1) }; auras.focus = { aura(1) }
    core:ScanAuras("target"); clock = 102; core:ScanAuras("focus")
    assert(entry(core).applications == 1 and #core.history == 1)
    core:ReleaseUnit("focus")
    assert(entry(core).active)
end)

test("long CC survives cleanup and starts reset only on removal", function(core)
    auras.target = { aura(1) }; core:ScanAuras("target")
    clock = 140; core:CleanExpired()
    assert(entry(core).active and entry(core).resetAt == nil)
    auras.target = {}; core:ScanAuras("target")
    assert(not entry(core).active and entry(core).resetAt == 158)
    clock = 158; core:CleanExpired(); assert(entry(core) == nil)
end)

test("overlapping CC ends only when the last aura disappears", function(core)
    auras.target = { aura(1), aura(2) }; core:ScanAuras("target")
    assert(entry(core).applications == 2)
    clock = 105; auras.target = { aura(2) }; core:ScanAuras("target")
    assert(entry(core).active and entry(core).resetAt == nil)
    clock = 110; auras.target = {}; core:ScanAuras("target")
    assert(entry(core).resetAt == 128)
end)

test("replacement aura in the same snapshot does not start reset", function(core)
    auras.target = { aura(1) }; core:ScanAuras("target")
    auras.target = { aura(2) }; core:ScanAuras("target")
    assert(entry(core).active and entry(core).applications == 2)
end)

test("secret or truncated snapshots do not imply aura removal", function(core)
    auras.target = { aura(1) }; core:ScanAuras("target")
    auras.target = { { auraInstanceID = 2, spellId = secret } }; core:ScanAuras("target")
    assert(entry(core).active and entry(core).applications == 1)
    auras.target = {}; for i = 1, 255 do auras.target[i] = aura(i + 1) end
    core:ScanAuras("target"); assert(entry(core).applications == 1)
end)

test("delayed native takeover and repeats never add inferred applications", function(core)
    auras.target = { aura(1) }; core:ScanAuras("target")
    clock = 105; assert(core:ApplyNative("target", native(105, 20)))
    assert(entry(core).applications == nil and entry(core).resetAt == 125)
    clock = 107; core:ApplyNative("focus", native(105, 20))
    assert(#core.history == 1)
    auras.target = {}; core:ScanAuras("target")
    assert(entry(core).source == "Blizzard" and entry(core).resetAt == 125)
    assert(not core:ApplyNative("target", native(104, 20)))
    assert(entry(core).resetAt == 125)
end)

test("native first stays authoritative over delayed fallback", function(core)
    core:ApplyNative("target", native(100, 18, true))
    clock = 106; auras.target = { aura(1) }; core:ScanAuras("target")
    assert(entry(core).applications == 3 and entry(core).exact)
    assert(entry(core).resetAt == 118 and #core.history == 1)
end)

test("partial native payload preserves fallback", function(core)
    auras.target = { aura(1) }; core:ScanAuras("target")
    local payload = native(100, 18); payload.duration = secret
    assert(not core:ApplyNative("target", payload))
    assert(entry(core).source == "Aura" and entry(core).active)
end)

test("native timer survives restricted immunity flag", function(core)
    local payload = native(100, 18)
    payload.isImmune = secret
    assert(core:ApplyNative("target", payload))
    assert(entry(core).source == "Blizzard" and entry(core).resetAt == 118)
    assert(entry(core).applications == nil and not entry(core).exact)
end)

test("readable spell remains trackable without an aura instance ID", function(core)
    auras.target = { { auraInstanceID = secret, spellId = 408 } }
    core:ScanAuras("target")
    assert(entry(core).active and entry(core).applications == 1)
    core:ScanAuras("target")
    assert(entry(core).applications == 1)
    auras.target = {}
    core:ScanAuras("target")
    assert(entry(core).resetAt == 118)
end)

test("native active phase waits for native countdown", function(core)
    core:ApplyNative("target", native(100, 18, false, false))
    clock = 130; core:CleanExpired(); assert(entry(core).active)
    core:ApplyNative("target", native(130, 20))
    assert(not entry(core).active and entry(core).resetAt == 150)
    core:ApplyNative("target", native(130, 0)); assert(entry(core) == nil)
end)

test("losing last observer discards active CC without guessing its end", function(core)
    auras.target = { aura(1) }; core:ScanAuras("target")
    core:ReleaseUnit("target"); assert(entry(core) == nil)
end)

test("disabling native feed resumes visible aura fallback", function(core)
    core:ApplyNative("target", native(100, 18, true))
    auras.target = { aura(1) }; core:ScanAuras("target")
    core:SetNativeFeed(false)
    assert(entry(core).source == "Aura" and entry(core).applications == 1)
    assert(not core:ApplyNative("target", native(100, 18, true)))
end)

test("corrupt saved variables recover types and numeric bounds", function()
    local db = { profile = { surfaces = false, categories = "bad", anchors = { target = 3 },
        iconSize = 0 / 0, resetSeconds = -2, historySize = math.huge, applicationsToImmune = 99,
        customSpells = { [408] = 0, [118] = false, bad = 2, [-1] = 2 } } }
    ns:ValidateDB(db)
    assert(db.profile.iconSize == 34 and db.profile.resetSeconds == 15 and db.profile.historySize == 40)
    assert(db.profile.surfaces.target and db.profile.categories[0])
    assert(db.profile.anchors.target.point == "CENTER" and db.profile.applicationsToImmune == 3)
    assert(db.profile.customSpells[408] == 0 and db.profile.customSpells[118] == nil)
    assert(db.profile.customSpells.bad == nil and db.profile.customSpells[-1] == nil)
end)

test("invalid anchor strings and coordinates recover", function()
    local db = ns:Copy(ns.DEFAULTS)
    db.profile.anchors.target.point = "INVALID"
    db.profile.anchors.focus.x = math.huge
    ns:ValidateDB(db)
    assert(db.profile.anchors.target.point == "CENTER" and db.profile.anchors.focus.x == 0)
end)

test("old native removal cannot erase a newer countdown", function(core)
    core:ApplyNative("target", native(100, 18))
    assert(not core:ApplyNative("target", native(99, 0)))
    assert(entry(core).resetAt == 118)
end)

test("malformed native payloads preserve current state", function(core)
    core:ApplyNative("target", native(100, 18))
    for _, payload in ipairs({ true, 1, "bad", secret }) do
        assert(not core:ApplyNative("target", payload))
    end
    for _, value in ipairs({ 0 / 0, math.huge, -1 }) do
        assert(not core:ApplyNative("target", native(100, value)))
    end
    assert(entry(core).resetAt == 118)
end)

test("secret aura tables and API errors are unavailable snapshots", function(core)
    auras.target = { aura(1) }; core:ScanAuras("target")
    auras.target = { secret }; core:ScanAuras("target")
    assert(core:GetUnitState("target", false).auraRestricted)
    C_UnitAuras.GetAuraDataByIndex = function() error("restricted") end
    core:ScanAuras("target")
    assert(entry(core).active and entry(core).resetAt == nil)
end)

test("observation gaps invalidate estimated applications", function(core)
    auras.target = { aura(1), aura(2) }; core:ScanAuras("target")
    auras.target = { secret }; core:ScanAuras("target")
    auras.target = {}; core:ScanAuras("target")
    assert(entry(core) == nil)
    auras.target = { aura(3) }; core:ScanAuras("target")
    assert(entry(core).applications == 1)
end)

test("observation gaps preserve native authority", function(core)
    core:ApplyNative("target", native(100, 18))
    auras.target = { secret }; core:ScanAuras("target")
    auras.target = {}; core:ScanAuras("target")
    assert(entry(core).resetAt == 118 and entry(core).source == "Blizzard")
end)

test("friendly units are not tracked; restricted reactions can use visible tokens", function(core)
    UnitCanAttack = function() return false end
    assert(core:GetUnitState("target", true) == nil)
    UnitCanAttack = function() return secret end
    assert(core:GetUnitState("target", true))
    UnitCanAttack = function() return true end
    assert(core:GetUnitState("target", true))
end)

test("death removes active effects and countdowns", function(core)
    auras.target = { aura(1) }; core:ScanAuras("target")
    UnitIsDeadOrGhost = function() return true end
    core:ScanAuras("target")
    assert(entry(core) == nil)
end)

test("disabling local native tracking does not disable Blizzard UI", function(core)
    C_CVar = { SetCVar = function() error("must not change global preference") end }
    core:SetNativeFeed(false)
end)

test("category overrides handle existing aura identities", function(core)
    auras.target = { aura(1) }; core:ScanAuras("target")
    ns.db.profile.customSpells[408] = 0
    core:ScanAuras("target")
    local state = core:GetUnitState("target", false)
    assert(state.categories[0].active and not state.categories[2].active)
end)

test("native category metadata rejects secret tables and retries unavailable data", function()
    C_SpellDiminish = { GetSpellDiminishCategoryInfo = function() return secret end }
    assert(ns:GetCategoryInfo(2).icon == 135963)
    C_SpellDiminish.GetSpellDiminishCategoryInfo = function() return { name = secret, icon = secret } end
    assert(ns:GetCategoryInfo(2).icon == 135963)
    assert(ns:GetCategoryInfo(99) == nil)
    assert(ns:GetSpellCategory(secret) == nil)
end)

test("common higher-rank CC spells retain their categories", function()
    assert(ns:GetSpellCategory(12826) == 4)
    assert(ns:GetSpellCategory(10308) == 2)
    assert(ns:GetSpellCategory(6215) == 5)
    assert(ns:GetSpellCategory(10230) == 0)
end)

for _, file in ipairs({ "Bootstrap", "Data", "Core", "UI", "Options", "Minimap" }) do
    assert(loadfile("Drpulse/" .. file .. ".lua"))
end
print(passed .. " tests passed; all addon Lua files parsed")
