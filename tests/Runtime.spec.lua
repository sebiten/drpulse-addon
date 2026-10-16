-- Runs both the ZIP's evidence adapters and the Drpulse adapters against
-- the same observable scenarios. No WoW installation or network required.
local secret = {}
local clock, tasks, units, auraByID, spellSecret, frames
local function environment(supported)
    clock, tasks, frames = 100, {}, {}
    units = { target = "enemy", focus = "enemy", nameplate1 = "enemy", pettarget = "enemy", party1target = "enemy" }
    auraByID, spellSecret = {}, true
    GetTime = function() return clock end
    issecretvalue = function(value) return rawequal(value, secret) end
    canaccesstable = function(value) return not rawequal(value, secret) end
    UnitExists = function(unit) return units[unit] ~= nil end
    UnitCanAttack = function() return true end
    UnitIsPlayer = function() return true end
    UnitGUID = function(unit) return units[unit] end
    UnitName = function() return "Enemy", "Realm" end
    InCombatLockdown = function() return false end
    C_Timer = { After = function(delay, callback) tasks[#tasks + 1] = { at = clock + delay, run = callback } end }
    C_Secrets = { ShouldSpellAuraBeSecret = function() return spellSecret end }
    C_UnitAuras = { GetUnitAuraBySpellID = function(_, id) return auraByID[id] end }
    C_EventUtils = { IsEventValid = function() return true end }
    C_SpellDiminish = { IsSystemSupported = function() return supported end, GetAllSpellDiminishCategories = function() return {} end }
    Enum = { SpellDiminishCategory = { Root = 0, Taunt = 1, Stun = 2, AoEKnockback = 3, Incapacitate = 4, Disorient = 5, Silence = 6, Disarm = 7 },
        SpellDiminishRuleset = { PvP = 1 }, SpellBookSpellBank = { Pet = 1 } }
    C_SpellBook = { IsSpellKnown = function() return true end }
    C_Item = { GetItemCount = function() return 0 end }
    C_CVar = { GetCVar = function() return "1" end, SetCVar = function() return true end }
    C_NamePlate = { GetNamePlates = function() return {} end }
    CreateFrame = function()
        local frame = { events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:RegisterUnitEvent(event, unit) self.events[event] = unit end
        function frame:UnregisterEvent(event) self.events[event] = nil end
        function frame:UnregisterAllEvents() self.events = {} end
        function frame:SetScript(event, callback) self[event] = callback end
        frames[#frames + 1] = frame
        return frame
    end
end
local function advance(seconds)
    clock = clock + seconds
    local again = true
    while again do
        again = false
        for i = #tasks, 1, -1 do
            if tasks[i].at <= clock then
                local task = table.remove(tasks, i); task.run(); again = true
            end
        end
    end
end
local function setup(reference, supported)
    environment(supported)
    local ns = {}
    local names = { { "Store", "State" }, { "Catalog", "SpellCatalog" }, { "Engine", "Tracker" }, { "Sources", "Tracking" } }
    for _, pair in ipairs(names) do
        local chunk = reference and assert(load(ReferenceModules[pair[1]])) or assert(loadfile("Drpulse/Runtime/" .. pair[2] .. ".lua"))
        chunk("Drpulse", ns)
    end
    ns.db = ns.LoadSettings(nil)
    ns.db.filter = "all"
    ns.RequestRefresh = function() end
    ns.tracker = ns.NewTracker(function() return ns.db.resetTime end, ns.Learned)
    ns.StartSources()
    return ns
end
local function state(ns, category) return ns.tracker:State("enemy", category or "Stun", clock, false) end
local function cast(ns, id, unit, guid)
    unit, guid = unit or "player", guid or "cast-1"
    ns._test.OnSent(unit, guid)
    ns._test.OnSucceeded(unit, guid, id)
end
local cases = {
    { "native unsupported still estimates a successful cast", function(ns)
        cast(ns, 408); advance(0.6)
        local st = assert(state(ns)); assert(st.count == 1 and not st.confirmed and st.resetAt == 124)
        assert(ns.stats.assumed == 1)
    end },
    { "repeat casts progress through all DR stages", function(ns)
        for i = 1, 3 do cast(ns, 408, "player", "cast-" .. i); advance(2) end
        assert(state(ns).count == 3 and state(ns).immune)
    end },
    { "miss feedback prevents an estimated landing", function(ns)
        cast(ns, 408); ns._test.OnCombatFeedback("target", "RESIST"); advance(0.6)
        assert(not state(ns) and ns.stats.notLanded == 1)
    end },
    { "readable aura silence rejects an unconfirmed cast", function(ns)
        spellSecret = false; cast(ns, 408); advance(0.6)
        assert(not state(ns) and ns.stats.notLanded == 1)
    end },
    { "pet and group casts use their own target", function(ns)
        cast(ns, 6358, "pet", "pet-1"); advance(0.6)
        cast(ns, 408, "party1", "party-1"); advance(0.6)
        assert(state(ns, "Disorient").count == 1 and state(ns).count == 1)
    end },
    { "unconfirmed area casts are not assigned to the selected enemy", function(ns)
        cast(ns, 122); advance(0.6); assert(not state(ns, "Root"))
    end },
    { "opaque native event confirms a recent own cast", function(ns)
        cast(ns, 408); ns._test.OnNative("target", secret); advance(0.6)
        assert(state(ns).confirmed and state(ns).count == 1 and ns.stats.confirmed == 1)
    end },
    { "readable aura identity comes from the requested spell", function(ns)
        spellSecret = false
        auraByID[408] = { spellId = secret, auraInstanceID = 8, duration = 6, expirationTime = 106 }
        ns.RescanAll(); advance(0.3)
        assert(state(ns).count == 1 and state(ns).spellID == 408)
        auraByID[408] = nil; ns.RescanAll(); advance(0.3)
        assert(not state(ns).active and math.abs(state(ns).resetAt - 118.6) < 0.01)
    end },
    { "full player name joins restricted GUID tokens", function(ns)
        units.target, units.focus = secret, secret
        assert(ns.ReadEnemy("target") == "Name:Enemy-Realm")
        assert(ns.ReadEnemy("target") == ns.ReadEnemy("focus"))
    end },
    { "expired estimates disappear", function(ns)
        cast(ns, 408); advance(25)
        assert(ns.tracker:Snapshot("enemy", clock) == nil)
    end },
    { "native countdown and duplicate observers share one timer", function(ns)
        local payload = { category = 2, startTime = 100, duration = 18, showCountdown = true, isImmune = false }
        ns._test.OnNative("target", payload); ns._test.OnNative("focus", payload)
        assert(state(ns).count == 1 and state(ns).resetAt == 118)
    end, true },
    { "secret timing with readable category retains evidence", function(ns)
        ns._test.OnNative("target", { category = 2, startTime = secret, duration = secret, showCountdown = false, isImmune = false })
        assert(state(ns).count == 1)
    end, true },
}
local passed = 0
for _, case in ipairs(cases) do
    for _, reference in ipairs({ true, false }) do case[2](setup(reference, case[3] == true)) end
    passed = passed + 1; print("PASS reference + Drpulse: " .. case[1])
end
local ns = setup(false, false)
assert(loadfile("Drpulse/Runtime/Integration.lua"))("Drpulse", ns)
DrpulseDB = { profile = { iconSize = 38, resetSeconds = 20, customSpells = { [123456] = 2 },
    categories = { [2] = true, [1] = false }, minimap = { angle = 90, hide = true } } }
local old = DrpulseDB
local migrated = assert(ns.LoadDrpulseSettings(nil))
assert(migrated.iconSize == 38 and migrated.custom[123456] == "Stun" and migrated.sources.assume)
assert(migrated.categories.Stun == "always" and migrated.categories.Taunt == "never")
assert(migrated.profile.minimap.hide and migrated.profile.minimap.angle == 90 and DrpulseDB == old)
assert(ns.LoadDrpulseSettings(migrated) == migrated)
assert(ns.LoadDrpulseSettings({ schema = 999 }) == nil)
print("PASS legacy migration, reload, and unsupported schema preservation")
for _, file in ipairs(TocModules) do assert(loadfile(file)) end
environment(false)
SlashCmdList, DrpulseV2DB, Minimap = {}, nil, nil
local product, loaded = {}, {}
for _, file in ipairs(TocModules) do
    if not loaded[file] then
        assert(loadfile(file))("Drpulse", product)
        loaded[file] = true
    end
end
local lifecycle = frames[#frames]
local displayStarted, settingsStarted = false, false
product.StartDisplay = function() displayStarted = true end
product.BuildSettings = function() settingsStarted = true end
product.RequestRefresh = function() end
lifecycle.OnEvent(lifecycle, "ADDON_LOADED", "Drpulse")
lifecycle.OnEvent(lifecycle, "PLAYER_LOGIN")
assert(displayStarted and settingsStarted and DrpulseV2DB == product.db)
assert(SLASH_DRPULSE1 == "/drpulse" and SLASH_DRPULSE2 == nil and type(SlashCmdList.DRPULSE) == "function")
assert(product.WatchedUnits().target and product.WatchedUnits().focus)
print("PASS actual TOC execution, startup wiring, Drpulse commands and isolated saved data (UI builders stubbed)")
print(passed .. " parity scenarios passed on both implementations; migration and all TOC modules parsed")
