local ns, combat, kind, same = {}, false, "none", false
local secret = {}
issecretvalue = function(value) return value == secret end
canaccesstable = function() return true end
InCombatLockdown = function() return combat end
IsInInstance = function() return kind ~= "none", kind end
UnitIsUnit = function() return same end
C_EventUtils = { IsEventValid = function() return true end }
local events
CreateFrame = function()
    events = { RegisterEvent = function() end, SetScript = function(self, _, callback) self.event = callback end }
    return events
end
assert(loadfile("Drpulse/Runtime/State.lua"))("Drpulse", ns)
ns.db = ns.LoadSettings(nil)
ns.RequestRefresh = function() end
assert(loadfile("Drpulse/Runtime/Visibility.lua"))("Drpulse", ns)
ns.StartVisibility()
assert(ns.VisibilityAllowed() and ns.NameplateAllowed("nameplate1"))
ns.db.combatOnly = true
assert(not ns.VisibilityAllowed())
events.event(nil, "PLAYER_REGEN_DISABLED")
assert(ns.VisibilityAllowed())
ns.db.pvpOnly = true
assert(not ns.VisibilityAllowed())
combat, kind = true, "pvp"; events.event(nil, "PLAYER_ENTERING_WORLD")
assert(ns.VisibilityAllowed())
kind = "arena"; ns.RefreshVisibilityContext(); assert(ns.VisibilityAllowed())
kind = "party"; ns.RefreshVisibilityContext(); assert(not ns.VisibilityAllowed())
events.event(nil, "PLAYER_REGEN_ENABLED"); ns.db.pvpOnly = false
assert(not ns.VisibilityAllowed())
ns.db.plateTargetOnly = true
assert(not ns.NameplateAllowed("nameplate1"))
same = true; assert(ns.NameplateAllowed("nameplate1"))
same = secret; assert(not ns.NameplateAllowed("nameplate1"))
print("PASS combat/instance visibility, combined filters, target-only nameplates and restricted identity")
