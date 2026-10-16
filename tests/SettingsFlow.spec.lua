-- Functional settings flows with native widgets mocked (no pixel/layout claim).
local methods, object = {}, nil
object = function()
    return setmetatable({ scripts = {}, shown = true, text = "" }, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if key:match("^Set") or key:match("^Enable") or key:match("^Register") then return function() end end
    end })
end
function methods:CreateTexture() return object() end
function methods:CreateFontString() return object() end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:HookScript(event, fn)
    local previous = self.scripts[event]
    self.scripts[event] = function(...) if previous then previous(...) end; fn(...) end
end
function methods:SetText(value) self.text = value end
function methods:GetText() return self.text end
function methods:GetStringHeight() return 12 end
function methods:GetWidth() return 1920 end
function methods:GetHeight() return 1080 end
function methods:GetThumbTexture() return object() end
function methods:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown end
function methods:SetShown(value) self.shown = value end
function methods:SetValue(value) if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end end
function methods:ClearFocus() end
function methods:ClearAllPoints() end
function methods:HighlightText() end
function methods:StartMoving() end
function methods:StopMovingOrSizing() end
CreateFrame = function() return object() end
UIParent, UISpecialFrames = object(), {}
C_Texture = { GetAtlasInfo = function() return false end }
issecretvalue = function() return false end
canaccesstable = function() return true end
UnitFullName = function() return "SettingsTester", "Realm" end
UnitName = UnitFullName
InCombatLockdown = function() return false end
C_EventUtils = { IsEventValid = function() return true end }
local ns = {}
for _, module in ipairs({ "State", "Integration", "Profiles", "ProfileTransfer", "Settings" }) do
    assert(loadfile("Drpulse/Runtime/" .. module .. ".lua"))("Drpulse", ns)
end
ns.db = assert(ns.LoadDrpulseSettings(nil))
ns.mine, ns.nativeStatus, ns.nativeMode, ns.stats = {}, "test", "test", {}
for _, key in ipairs({ "confirmed", "assumed", "notLanded", "native", "nativePublic", "auraApplied", "casts", "groupCasts" }) do ns.stats[key] = 0 end
ns.CVAR_ENABLED, ns.CVAR_ONLY_MINE = "enabled", "onlyMine"
ns.GetBlizzardOption = function() return true end
ns.ShouldShow = function() return true end
ns.CategoryIcon = function() return 123 end
ns.Minimap = { Refresh = function() end }
for _, name in ipairs({ "ClearTracking", "RefreshMine", "RescanAll", "KeepBlizzardOn", "PositionTarget", "RefreshSettings" }) do ns[name] = function() end end
ns.StartProfiles()
ns.BuildSettings()
ns.OpenSettings()
local page = ns.SettingsPages.Drpulse
local function click(label, index)
    local control = assert(page.rows[label].controls[index or 1])
    assert(control.scripts.OnClick)(control, "LeftButton")
end
page.tabs.tools.scripts.OnClick()
page.rows["New profile name"].controls[1]:SetText("UI copy")
click("Create profile", 1)
assert(ns.ActiveProfile() == "UI copy")
page.tabs.appearance.scripts.OnClick()
click("Reset timer text", 2)
assert(ns.db.timer and not ns.db.plateTimer)
click("Stacks", 2)
assert(ns.db.stackStyle == "pips" and ns.db.plateStackStyle == "number")
page.tabs.general.scripts.OnClick()
click("Only in combat")
assert(ns.db.combatOnly)
page.tabs.tools.scripts.OnClick()
click("Share profile", 1)
local code = page.rows["Profile code"].controls[1]:GetText()
assert(code:match("^DRPULSE1;"))
page.rows["New profile name"].controls[1]:SetText("UI imported")
click("Share profile", 2)
assert(ns.ActiveProfile() == "UI imported" and not ns.db.plateTimer and ns.db.combatOnly)
assert(page.support:IsShown())
page.panel:Hide()
ns.OpenSettings()
assert(ns.ActiveProfile() == "UI imported")
print("PASS settings navigation, profile creation, independent controls, visibility toggle and export/import buttons")
