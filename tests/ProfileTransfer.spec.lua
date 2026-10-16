-- Reuse profile lifecycle coverage, then exercise untrusted text as data.
assert(loadfile("tests/Profiles.spec.lua"))()
local ns = {}
for _, module in ipairs({ "State", "Integration", "Profiles", "ProfileTransfer" }) do
    assert(loadfile("Drpulse/Runtime/" .. module .. ".lua"))("Drpulse", ns)
end
ns.db = assert(ns.LoadDrpulseSettings(DrpulseV2DB))
for _, name in ipairs({ "ClearTracking", "RefreshMine", "RescanAll", "KeepBlizzardOn", "PositionTarget", "RefreshSettings" }) do ns[name] = function() end end
ns.Minimap = { Refresh = function() end }
ns.StartProfiles()
ns.Set("timer", false)
ns.Set("plateFont", "morpheus")
ns.Set("plateX", -175)
ns.Set("combatOnly", true)
ns.db.categories.Stun = "always"
ns.db.custom[123456] = "Disorient"
local code = assert(ns.ExportProfile())
local copy = assert(ns.DecodeProfile(code))
assert(not copy.timer and copy.plateFont == "morpheus" and copy.plateX == -175 and copy.combatOnly)
assert(copy.custom[123456] == "Disorient" and copy.categories.Stun == "always")
assert(next(copy.learned) == nil and copy.profile.minimap.angle == ns.db.profile.minimap.angle)
local before, count = ns.db, #ns.ProfileNames()
for _, bad in ipairs({ "", "DRPULSE2;schema=n1", code .. ";timer=b1", code .. ";unknown=n1",
    "DRPULSE1;schema=n999", "DRPULSE1;schema=n1;iconSize=n999", "DRPULSE1;schema=n1;font=s%QQ",
    "DRPULSE1;schema=n1;custom.0=sStun", "DRPULSE1;schema=n1;custom.001=sStun",
    "DRPULSE1;schema=n1;custom.123=sInvalid", "DRPULSE1;schema=n1;timer=sfalse",
    "DRPULSE1;schema=n1;x=nNaN", "DRPULSE1;schema=n1;;timer=b1",
    "DRPULSE1;schema=n1;loadstring=sprint", string.rep("a", 32769) }) do
    assert(not ns.ImportProfile("Invalid import", bad), bad)
    assert(ns.db == before and #ns.ProfileNames() == count)
end
assert(ns.ImportProfile("Imported", code))
assert(ns.db ~= before and ns.ActiveProfile() == "Imported" and not ns.db.timer)
assert(not ns.ImportProfile("Imported", code))
assert(ns.ExportProfile() == code, "Export should be deterministic and round-trip exactly")
print("PASS portable profile round-trip, independent import, malformed/oversized input and no overwrite")
