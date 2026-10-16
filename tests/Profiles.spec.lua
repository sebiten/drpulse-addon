local character, spec, combat = "Alice", 1, false
issecretvalue = function() return false end
canaccesstable = function() return true end
UnitFullName = function() return character, "Realm" end
UnitName = UnitFullName
GetSpecialization = function() return spec end
GetSpecializationInfo = function(index) return index + 100 end
InCombatLockdown = function() return combat end
C_EventUtils = { IsEventValid = function() return true end }
local events
CreateFrame = function()
    events = { RegisterEvent = function() end, SetScript = function(self, _, callback) self.event = callback end }
    return events
end
local function loadProduct()
    local ns = {}
    for _, file in ipairs({ "State", "Integration", "Profiles" }) do
        assert(loadfile("Drpulse/Runtime/" .. file .. ".lua"))("Drpulse", ns)
    end
    ns.db = assert(ns.LoadDrpulseSettings(DrpulseV2DB))
    for _, name in ipairs({ "ClearTracking", "RefreshMine", "RescanAll", "KeepBlizzardOn", "PositionTarget", "RefreshSettings" }) do ns[name] = function() end end
    ns.Minimap = { Refresh = function() end }
    ns.StartProfiles()
    return ns
end
local ns = loadProduct()
assert(ns.ActiveProfile() == "Default")
ns.Set("iconSize", 37)
assert(ns.CreateProfile("Alice PvP"))
ns.Set("iconSize", 45)
assert(ns.SelectProfile("Default") and ns.db.iconSize == 37)
assert(ns.SelectProfile("Alice PvP") and ns.db.iconSize == 45)
assert(ns.SetAutoSpecProfiles(true))
assert(ns.CreateProfile("Spec one"))
ns.Set("iconSize", 50)
spec = 2; events.event(nil, "PLAYER_SPECIALIZATION_CHANGED", "player")
assert(ns.ActiveProfile() == "Alice PvP")
assert(ns.CreateProfile("Spec two"))
spec = 1; combat = true; events.event(nil, "PLAYER_SPECIALIZATION_CHANGED", "player")
assert(ns.ActiveProfile() == "Spec two" and not ns.SelectProfile("Default"))
combat = false; events.event(nil, "PLAYER_REGEN_ENABLED")
assert(ns.ActiveProfile() == "Spec one" and ns.db.iconSize == 50)
ns = loadProduct()
assert(ns.ActiveProfile() == "Spec one" and ns.db.iconSize == 50)
character = "Bob"; ns = loadProduct()
assert(ns.ActiveProfile() == "Default" and ns.db.iconSize == 37)
assert(ns.SelectProfile("Alice PvP") and ns.CreateProfile("Bob copy"))
ns.Set("iconSize", 20)
assert(ns.SelectProfile("Alice PvP") and ns.db.iconSize == 45)
assert(not ns.CreateProfile("Alice PvP") and not ns.CreateProfile("|bad"))
print("PASS profile migration, isolated copies, character selection, specialization switching, combat deferral and reload")
