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
    C_Secrets, issecrettable = nil, nil
    C_UnitAuras.GetUnitAuraBySpellID = nil
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

test("partial native countdown ends CC without extending on duplicate updates", function(core)
    auras.target = { aura(1) }; core:ScanAuras("target")
    local payload = native(100, 18); payload.duration = secret
    assert(core:ApplyNative("target", payload))
    assert(entry(core).source == "Blizzard" and not entry(core).active)
    assert(entry(core).resetAt == 118 and not entry(core).exact)
    clock = 105; core:ApplyNative("focus", payload)
    assert(entry(core).resetAt == 118)
end)

test("per-spell lookup retains known identity when payload spell ID is secret", function(core)
    C_UnitAuras.GetUnitAuraBySpellID = function(_, id)
        if id == 408 then return { spellId = secret, auraInstanceID = 1 } end
    end
    core:ScanAuras("target")
    assert(entry(core).active and entry(core).spellID == 408)
    core:ScanAuras("target")
    assert(entry(core).applications == 1)
end)

test("a restricted root does not prevent a readable stun from ending", function(core)
    local stunPresent, rootSecret = true, false
    C_Secrets = { ShouldSpellAuraBeSecret = function(id) return id == 339 and rootSecret end }
    C_UnitAuras.GetUnitAuraBySpellID = function(_, id)
        if id == 408 and stunPresent then return aura(1) end
        if id == 339 then return { spellId = 339, auraInstanceID = 2 } end
    end
    core:ScanAuras("target")
    clock, stunPresent, rootSecret = 102, false, true
    core:ScanAuras("target")
    assert(not entry(core).active and entry(core).resetAt == 120)
    assert(core:GetUnitState("target", false).categories[0].auraUncertain)
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
    assert(not entry(core).active and entry(core).countUnknown)
    auras.target = { aura(3) }; core:ScanAuras("target")
    assert(entry(core).countUnknown)
    auras.target = {}; core:ScanAuras("target")
    clock = 119; core:CleanExpired()
    auras.target = { aura(4) }; core:ScanAuras("target")
    assert(entry(core).applications == 1 and not entry(core).countUnknown)
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

test("timing changes with the same ID make the percentage unknown without adding applications", function(core)
    auras.target = { { auraInstanceID = 7, spellId = 12826, duration = 10, expirationTime = 110 } }
    core:ScanAuras("target")
    clock = 102
    auras.target[1].duration, auras.target[1].expirationTime = 5, 107
    core:ScanAuras("target")
    local poly = core:GetUnitState("target", false).categories[4]
    assert(poly.active and poly.applications == 1 and poly.countUnknown)
    core:ScanAuras("target")
    assert(poly.applications == 1 and #core.history == 1)
    auras.target = {}; core:ScanAuras("target")
    assert(not poly.active and poly.resetAt == 120)
end)

test("secret refresh timestamps are never compared or counted", function(core)
    auras.target = { { auraInstanceID = 7, spellId = 12826, duration = secret, expirationTime = secret } }
    core:ScanAuras("target"); core:ScanAuras("target")
    assert(core:GetUnitState("target", false).categories[4].applications == 1)
end)

test("readable active aura recovers after native state is cleared", function(core)
    core:ApplyNative("target", native(100, 18))
    auras.target = { aura(1) }; core:ScanAuras("target")
    core:ApplyNative("target", native(101, 0))
    clock = 102; core:PollVisibleAuras()
    assert(entry(core).active and entry(core).source == "Aura")
    auras.target = {}; clock = 103; core:PollVisibleAuras()
    assert(entry(core).resetAt == 121)
end)

test("polling shares readable GUIDs and retries a restricted observer", function(core)
    auras.target = { secret }; auras.focus = { aura(1) }
    units.nameplate1 = "A"; core.visibleUnits.nameplate1 = true
    auras.nameplate1 = { aura(1) }
    core:PollVisibleAuras()
    assert(entry(core).active and entry(core).applications == 1)
    assert(core.unitKeys.nameplate1 == core.unitKeys.focus and #core.history == 1)
end)

test("instance ID secrecy transitions do not count the same CC twice", function(core)
    local cc = { auraInstanceID = secret, spellId = 408, duration = 6, expirationTime = 106 }
    auras.target = { cc }; core:ScanAuras("target")
    cc.auraInstanceID = 11; core:ScanAuras("target")
    assert(entry(core).applications == 1 and #core.history == 1)
    cc.auraInstanceID = secret; core:ScanAuras("target")
    assert(entry(core).applications == 1 and #core.history == 1)
    auras.target = {}; core:ScanAuras("target")
    auras.target = { aura(12) }; core:ScanAuras("target")
    assert(entry(core).applications == 2)
end)

test("two different readable instance IDs still count separate applications", function(core)
    auras.target = { aura(1) }; core:ScanAuras("target")
    auras.target = { aura(2) }; core:ScanAuras("target")
    assert(entry(core).applications == 2)
end)

test("client-marked secret indexes are skipped and later public CC remains readable", function(core)
    C_Secrets = { ShouldUnitAuraIndexBeSecret = function(unit, index, filter)
        assert(unit == "target" and filter == "HARMFUL")
        return index == 1
    end }
    C_UnitAuras.GetAuraDataByIndex = function(_, index)
        assert(index ~= 1, "must not request a known restricted aura")
        if index == 2 then return aura(2) end
    end
    core:ScanAuras("target")
    assert(entry(core).active and not entry(core).auraUncertain)
    assert(core.diagnostics.auraSkipped == 1 and core.diagnostics.auraErrors == 0)
end)

test("API errors retain the actual message and polling backs off", function(core)
    local calls = 0
    C_UnitAuras.GetAuraDataByIndex = function()
        calls = calls + 1; error("Auras cannot be accessed while restricted")
    end
    core:ScanAuras("target")
    assert(core.diagnostics.lastAuraError:find("Auras cannot be accessed"))
    assert(ns.db.lastAuraError == core.diagnostics.lastAuraError)
    clock = 100.3; core:PollVisibleAuras(); assert(calls == 1)
    clock = 101.1; core:PollVisibleAuras(); assert(calls == 2)
end)

test("failed polls retain bounded unknown data without extending its lifetime", function(core)
    core:ScanAuras("target", { addedAuras = { { auraInstanceID = 1, spellId = 408, isHarmful = true } } })
    C_UnitAuras.GetAuraDataByIndex = function() error("blocked") end
    clock = 100.3; core:PollVisibleAuras()
    local deadline = entry(core).uncertainUntil
    assert(entry(core).auraUncertain and entry(core).countUnknown)
    clock = 105; core:PollVisibleAuras()
    assert(entry(core).uncertainUntil == deadline)
    clock = deadline; core:CleanExpired()
    assert(entry(core) == nil and next(core:GetUnitState("target", false).auras) == nil)
end)

test("late removal after a gap does not claim a precise countdown", function(core)
    auras.target = { aura(1) }; core:ScanAuras("target")
    clock = 105; auras.target = { secret }; core:ScanAuras("target")
    clock = 108; auras.target = {}; core:ScanAuras("target")
    assert(entry(core).timerUnknown and entry(core).countUnknown)
end)

test("secret event tables are rejected before iteration", function(core)
    local secretList = setmetatable({}, { __index = function() error("must not iterate") end })
    issecrettable = function(value) return rawequal(value, secretList) end
    core:ScanAuras("target", { addedAuras = secretList, updatedAuraInstanceIDs = secretList, removedAuraInstanceIDs = secretList })
    assert(entry(core) == nil)
end)

test("opaque native evidence correlates only a recent cast on the same enemy", function(core)
    core:CastSent("player", "cast-1")
    core:CastSucceeded("player", "cast-1", 408)
    assert(core:ApplyNative("target", secret))
    assert(entry(core).source == "Cast+native" and entry(core).timerUnknown and entry(core).countUnknown)
    local resetAt = entry(core).resetAt
    clock = 101; assert(not core:ApplyNative("focus", secret))
    assert(entry(core).resetAt == resetAt)
    clock = 119; core:CleanExpired(); assert(entry(core) == nil)
end)

test("casts alone and casts on another target do not create DR", function(core)
    core:CastSent("player", "cast-1")
    units.target = "B"
    core:CastSucceeded("player", "cast-1", 408)
    assert(not core:ApplyNative("target", secret))
    clock = 102; core:CleanExpired()
    assert(not core:ApplyNative("focus", secret))
end)

test("native option waits until combat ends and avoids redundant writes", function(core)
    local inCombat, value, writes = true, "0", 0
    InCombatLockdown = function() return inCombat end
    C_SpellDiminish = { IsSystemSupported = function() return true end }
    C_CVar = { GetCVar = function() return value end,
        SetCVar = function(_, newValue) value = newValue; writes = writes + 1; return true end }
    core:EnsureNativeFeed(); assert(writes == 0)
    inCombat = false; core:EnsureNativeFeed(); core:EnsureNativeFeed()
    assert(writes == 1 and value == "1")
    InCombatLockdown = nil
end)

for _, file in ipairs({ "Bootstrap", "Data", "Core", "UI", "Options", "Minimap" }) do
    assert(loadfile("Drpulse/" .. file .. ".lua"))
end
print(passed .. " tests passed; all addon Lua files parsed")
