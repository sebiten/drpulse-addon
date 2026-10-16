-- Offline lifecycle/UI smoke tests. This mock does not emulate WoW's secure execution.
local frames, clock, units, auras, ns
local methods = {}
local function frame(name)
    local object = setmetatable({ shown = true, scripts = {}, calls = {}, name = name }, { __index = methods })
    if name then frames[name] = object end
    return object
end
for _, method in ipairs({ "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetTexCoord",
    "SetAllPoints", "SetReverse", "SetDrawEdge", "SetHideCountdownNumbers", "SetShadowOffset", "SetSize",
    "SetHeight", "SetWidth", "SetVertexColor", "SetFrameStrata", "SetClampedToScreen", "SetMovable",
    "EnableMouse", "StartMoving", "StopMovingOrSizing", "ClearAllPoints", "SetTextColor", "SetJustifyH",
    "RegisterForDrag", "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag", "SetAutoFocus", "SetFocus",
    "HighlightText", "ClearFocus", "EnableMouseWheel", "RegisterForClicks", "SetHighlightTexture" }) do
    methods[method] = function(self) self.calls[method] = (self.calls[method] or 0) + 1 end
end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:GetWidth() return self.width or 160 end
function methods:GetHeight() return self.height or 160 end
function methods:GetCenter() return self.centerX or 100, self.centerY or 100 end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:SetFrameLevel(level) self.level = level end
function methods:GetFrameLevel() return self.level or 1 end
function methods:SetFrameStrata(strata) self.strata = strata end
function methods:EnableMouse(enabled) self.mouseEnabled = enabled end
function methods:SetBackdropColor(...) self.backdropColor = { ... } end
function methods:HookScript(event, callback)
    local previous = self.scripts[event]
    self.scripts[event] = function(...)
        if previous then previous(...) end
        callback(...)
    end
end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:RegisterEvent(event) self.calls[event] = true end
function methods:SetPoint(...) self.point = { ... } end
function methods:GetPoint() return table.unpack(self.point) end
function methods:CreateTexture() return frame() end
function methods:CreateFontString() return frame() end
function methods:SetText(text) self.text = text end
function methods:SetTexture(texture) self.textureValue = texture end
function methods:SetParent(parent) self.parent = parent end
function methods:SetCooldown(start, duration)
    self.start, self.duration = start, duration
    self.calls.SetCooldown = (self.calls.SetCooldown or 0) + 1
end
function methods:IsShown() return self.shown end
function methods:SetShown(value)
    local changed = self.shown ~= not not value
    self.shown = not not value
    local callback = self.scripts[self.shown and "OnShow" or "OnHide"]
    if changed and callback then callback(self) end
end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false) end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetValue(value)
    self.value = value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end

local function setup(saved)
    frames, clock, units, auras, ns = {}, 100, { target = "A", focus = "B" }, {}, {}
    GetTime = function() return clock end
    UnitExists = function(unit) return units[unit] ~= nil end
    UnitGUID = function(unit) return units[unit] end
    UnitName = function() return "Enemy" end
    UnitCanAttack = function() return true end
    date = function() return "12:00:00" end
    strtrim = function(value) return value:match("^%s*(.-)%s*$") end
    issecretvalue = function() return false end
    C_Secrets, issecrettable = nil, nil
    C_UnitAuras = { GetAuraDataByIndex = function(unit, index) return (auras[unit] or {})[index] end }
    C_Spell = { GetSpellTexture = function() return nil end }
    C_NamePlate = { GetNamePlates = function() return {} end }
    C_Timer = { NewTicker = function(_, callback) return { callback = callback, Cancel = function() end } end }
    DEFAULT_CHAT_FRAME = { AddMessage = function() end }
    UISpecialFrames, SlashCmdList, DrpulseDB, DRiftDB = {}, {}, saved, nil
    CreateFrame = function(_, name, parent, template)
        local object = frame(name)
        object.parent = parent
        if template == "UICheckButtonTemplate" then object.Text = frame() end
        if template == "OptionsSliderTemplate" then object.Text, object.Low, object.High = frame(), frame(), frame() end
        return object
    end
    UIParent = frame()
    Minimap = frame()
    GetMinimapShape = function() return "ROUND" end
    GetCursorPosition = function() return 200, 100 end
    for _, file in ipairs({ "Bootstrap", "Data", "Core", "UI", "Options", "Minimap" }) do
        assert(loadfile("Drpulse/" .. file .. ".lua"))("Drpulse", ns)
    end
end
local function event(name, ...) ns.events.scripts.OnEvent(ns.events, name, ...) end
local function login()
    event("ADDON_LOADED", "Drpulse")
    event("PLAYER_LOGIN")
    event("PLAYER_ENTERING_WORLD")
end
local function aura() return { auraInstanceID = 1, spellId = 408 } end
local passed = 0
local function test(name, callback)
    setup()
    callback()
    passed = passed + 1
    print("PASS " .. name)
end

test("all TOC modules load and initialize with malformed saved settings", function()
    DrpulseDB = { profile = { surfaces = false, anchors = 5, iconSize = -1 } }
    login()
    assert(ns.UI.bars.target and ns.db.profile.iconSize == 24)
    SlashCmdList.DRPULSE("")
    assert(ns.Options.frame:IsShown())
end)

test("player-facing addon labels are in English", function()
    login()
    assert(ns.UI.bars.target.title.text == "TARGET")
    assert(ns.UI.bars.focus.title.text == "FOCUS")
    assert(ns.CATEGORIES[0].label == "Root")
    assert(ns.CATEGORIES[1].label == "Taunt")
    SlashCmdList.DRPULSE("")
    assert(ns.Options.frame.checks[1].Text.text == "Show on Target")
    assert(ns.Options.frame.checks[2].Text.text == "Show on Focus")
    assert(ns.Options.frame.categoryChecks[1].Text.text == "Stun")
    ns.Core:SetPreview(true)
    assert(ns.Core.previewState.categories[2].source == "Preview")
end)

test("donate button and command show the selected PayPal link", function()
    login()
    SlashCmdList.DRPULSE("")
    assert(ns.Options.frame.donateButton.label.text == "Support Drpulse")
    ns.Options.frame.donateButton.scripts.OnClick()
    local donateFrame = ns.Options.donateFrame
    assert(donateFrame:IsShown())
    assert(donateFrame.editBox.text == "https://www.paypal.com/paypalme/sebiten")
    assert(donateFrame.editBox.calls.SetFocus == 1)
    assert(donateFrame.editBox.calls.HighlightText == 1)
    donateFrame:Hide()
    SlashCmdList.DRPULSE("donate")
    assert(donateFrame:IsShown())
end)

test("legacy saved variables migrate to DrpulseDB", function()
    local legacyDB = { profile = { iconSize = 40 } }
    DRiftDB = legacyDB
    login()
    assert(ns.db == DrpulseDB and ns.db.profile.iconSize == 40)
    assert(DRiftDB == nil)
end)

test("pre-initialization events are ignored", function()
    event("UNIT_AURA", "target")
    event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    assert(next(ns.Core.units) == nil)
end)

test("world entry scans already-selected targets", function()
    auras.target = { aura() }
    login()
    assert(ns.UI.bars.target:IsShown())
    assert(ns.UI.bars.target.icons[2].timer.text == "CC")
    assert(ns.UI.bars.target.icons[2].texture.textureValue == ns.CATEGORIES[2].icon)
end)

test("repeated target events do not double count the same CC", function()
    auras.target = { aura() }; login()
    event("PLAYER_TARGET_CHANGED")
    assert(#ns.Core.history == 1)
    assert(ns.Core:GetUnitState("target", false).categories[2].applications == 1)
end)

test("restricted GUID keeps native DR and target changes clear token state", function()
    local restricted = {}
    issecretvalue = function(value) return rawequal(value, restricted) end
    units.target = restricted
    login()
    event("UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", "target",
        { category = 2, startTime = 100, duration = 18, isImmune = false, showCountdown = true })
    assert(ns.UI.bars.target:IsShown())
    assert(ns.Core.units["unit:target"].categories[2].source == "Blizzard")
    event("PLAYER_TARGET_CHANGED")
    assert(ns.Core.units["unit:target"].categories[2] == nil)
    assert(not ns.UI.bars.target:IsShown())
end)

test("status command reports observation limits", function()
    login()
    local messages = {}
    DEFAULT_CHAT_FRAME.AddMessage = function(_, message) messages[#messages + 1] = message end
    SlashCmdList.DRPULSE("status")
    assert(#messages == 3 and messages[1]:find("Auras:") and messages[2]:find("Native:"))
    assert(messages[3]:find("target GUID"))
end)

test("history opens on the first click and toggles", function()
    login(); SlashCmdList.DRPULSE("history")
    assert(ns.Options.history:IsShown())
    assert(ns.Options.history.lines[1].text ~= "")
    SlashCmdList.DRPULSE("history"); assert(not ns.Options.history:IsShown())
end)

test("cooldown swipe is not restarted by every UI tick", function()
    auras.target = { aura() }; login()
    auras.target = {}; event("UNIT_AURA", "target")
    local icon = ns.UI.bars.target.icons[2]
    for index = 1, 10 do clock = clock + 0.1; ns.Core:CleanExpired() end
    assert(icon.cooldown.calls.SetCooldown == 1)
    clock = 119; ns.Core:CleanExpired()
    assert(not ns.UI.bars.target:IsShown())
end)

test("aura restrictions retain a bounded unknown indication and native data restores certainty", function()
    auras.target = { aura() }; login()
    C_UnitAuras.GetAuraDataByIndex = function() error("restricted") end
    event("UNIT_AURA", "target"); ns.UI:Refresh()
    assert(ns.UI.bars.target:IsShown() and ns.UI.bars.target.icons[2].timer.text == "?")
    ns.Core:ApplyNative("target", { category = 2, startTime = 100, duration = 18, isImmune = true, showCountdown = true })
    assert(ns.UI.bars.target:IsShown() and ns.UI.bars.target.icons[2].stage.text == "IMM")
end)

test("profile reset synchronizes an already-open settings window", function()
    login(); SlashCmdList.DRPULSE(""); SlashCmdList.DRPULSE("unlock")
    ns.db.profile.surfaces.target = false
    ns.Core:ApplyNative("focus", { category = 2, startTime = 100, duration = 18, isImmune = true, showCountdown = true })
    SlashCmdList.DRPULSE("reset")
    assert(ns.db.profile.locked and not ns.Core.preview)
    assert(ns.Options.frame.checks[1]:GetChecked())
    assert(ns.Core:GetUnitState("focus", false).categories[2] == nil)
end)

test("world transition discards previous encounter states", function()
    auras.target = { aura() }; login()
    auras.target = {}; event("PLAYER_ENTERING_WORLD")
    assert(not ns.UI.bars.target:IsShown())
end)

test("native arena aliases update observed GUID without leaking tokens", function()
    login(); units.arena1 = "A"
    event("UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", "arena1",
        { category = 2, startTime = 100, duration = 18, isImmune = true, showCountdown = true })
    assert(ns.UI.bars.target.icons[2].stage.text == "IMM")
    assert(ns.Core.unitKeys.arena1 == nil)
    units.arena2 = "unobserved"
    event("UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", "arena2",
        { category = 2, startTime = 100, duration = 18, isImmune = true, showCountdown = true })
    assert(ns.Core.units["guid:unobserved"] == nil)
end)

test("spell commands reject invalid IDs and apply category changes immediately", function()
    auras.target = { aura() }; login()
    SlashCmdList.DRPULSE("add 0 stun")
    assert(ns.db.profile.customSpells[0] == nil)
    SlashCmdList.DRPULSE("add 408 root")
    assert(ns.Core:GetUnitState("target", false).categories[0].active)
    SlashCmdList.DRPULSE("remove 408")
    assert(ns.Core:GetUnitState("target", false).categories[2].active)
end)

-- Cover every category with a built-in aura fallback. Knockbacks have no
-- spell mapping here and are covered through native events below.
for _, case in ipairs({
    { "root", 10230, 0 }, { "taunt", 355, 1 }, { "stun", 10308, 2 },
    { "incapacitate", 12826, 4 }, { "disorient", 6215, 5 },
    { "silence", 15487, 6 }, { "disarm", 676, 7 },
}) do
test(case[1] .. " appears and repeats without selecting the nameplate or aura events", function()
    local spellID, category = case[2], case[3]
    local plate = frame()
    C_NamePlate.GetNamePlateForUnit = function() return plate end
    units.target, units.focus, units.nameplate1 = nil, nil, "C"
    local hostile = false
    UnitCanAttack = function() return hostile end
    login()
    ns.db.profile.categories[category] = true
    event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    assert(not ns.UI.nameplates.nameplate1:IsShown())
    hostile = true
    auras.nameplate1 = { { auraInstanceID = 7, spellId = spellID, duration = 10, expirationTime = 110 } }
    ns.Core.ticker.callback()
    local bar = ns.UI.nameplates.nameplate1
    assert(bar:IsShown() and bar.icons[category].timer.text == "CC")
    assert(bar.point[1] == "BOTTOM" and bar.point[3] == "TOP" and bar.point[5] == 10)
    clock = 102
    auras.nameplate1[1].auraInstanceID = 10
    auras.nameplate1[1].duration, auras.nameplate1[1].expirationTime = 5, 107
    ns.Core.ticker.callback()
    assert(bar:IsShown() and bar.icons[category].stage.text == "25")
    clock = 107; auras.nameplate1 = {}; ns.Core.ticker.callback()
    assert(bar.icons[category].timer.text == "18")
    clock = 108
    auras.nameplate1 = { { auraInstanceID = 8, spellId = spellID } }
    ns.Core.ticker.callback()
    assert(bar:IsShown() and bar.icons[category].stage.text == "IMM")
    clock = 110; auras.nameplate1 = {}; ns.Core.ticker.callback()
    clock = 129; ns.Core.ticker.callback()
    assert(not bar:IsShown())
    clock = 130; auras.nameplate1 = { { auraInstanceID = 9, spellId = spellID } }
    ns.Core.ticker.callback()
    assert(bar:IsShown() and bar.icons[category].stage.text == "50")
    event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    clock = 131; ns.Core.ticker.callback()
    assert(not bar:IsShown())
end)
end

for category = 0, 7 do
test("native category " .. category .. " updates and reappears on an unselected plate", function()
    local plate = frame()
    C_NamePlate.GetNamePlateForUnit = function() return plate end
    units.target, units.focus, units.nameplate1 = nil, nil, "C"
    login()
    ns.db.profile.categories[category] = true
    event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local function update(start, immune)
        event("UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", "nameplate1",
            { category = category, startTime = start, duration = 18, isImmune = immune, showCountdown = true })
    end
    update(100, false)
    local bar = ns.UI.nameplates.nameplate1
    assert(bar:IsShown() and bar.icons[category].timer.text == "18")
    clock = 105; update(105, true)
    assert(bar.icons[category].stage.text == "IMM" and bar.icons[category].timer.text == "18")
    clock = 124; ns.Core.ticker.callback()
    assert(not bar:IsShown())
    clock = 125; update(125, false)
    assert(bar:IsShown() and bar.icons[category].stage.text == "?")
end)
end

test("simultaneous DR categories refresh and expire independently", function()
    local plate = frame()
    C_NamePlate.GetNamePlateForUnit = function() return plate end
    units.target, units.focus, units.nameplate1 = nil, nil, "C"
    login(); event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local root = { auraInstanceID = 1, spellId = 10230, duration = 10, expirationTime = 110 }
    local stun = { auraInstanceID = 2, spellId = 10308, duration = 6, expirationTime = 106 }
    auras.nameplate1 = { root, stun }; ns.Core.ticker.callback()
    local bar = ns.UI.nameplates.nameplate1
    assert(bar.icons[0]:IsShown() and bar.icons[2]:IsShown())
    clock = 102; root.duration, root.expirationTime = 5, 107
    root.auraInstanceID = 10
    ns.Core.ticker.callback()
    assert(bar.icons[0].stage.text == "25" and bar.icons[2].stage.text == "50")
    clock = 106; auras.nameplate1 = { root }; ns.Core.ticker.callback()
    assert(bar.icons[0].timer.text == "CC" and bar.icons[2].timer.text == "18")
    clock = 107; auras.nameplate1 = {}; ns.Core.ticker.callback()
    clock = 124; ns.Core.ticker.callback()
    assert(bar.icons[0]:IsShown() and not bar.icons[2]:IsShown())
    clock = 125; ns.Core.ticker.callback()
    assert(not bar:IsShown())
end)

test("nameplates attach, disappear and reuse safely", function()
    local plate = frame()
    C_NamePlate.GetNamePlateForUnit = function() return plate end
    login(); units.nameplate1 = "C"; auras.nameplate1 = { aura() }
    event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local bar = ns.UI.nameplates.nameplate1
    assert(bar:IsShown() and bar.parent == plate)
    event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    assert(not bar:IsShown())
    units.nameplate1 = "D"; auras.nameplate1 = {}
    event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    assert(not bar:IsShown())
end)

test("PayPal modal sits above settings and releases the input blocker on escape", function()
    login(); SlashCmdList.DRPULSE(""); SlashCmdList.DRPULSE("donate")
    local popup, overlay = ns.Options.donateFrame, ns.Options.donateOverlay
    assert(ns.Options.frame.strata == "DIALOG")
    assert(popup.strata == "FULLSCREEN_DIALOG" and overlay.strata == "FULLSCREEN_DIALOG")
    assert(popup.parent == overlay and popup:GetFrameLevel() > overlay:GetFrameLevel())
    assert(overlay:IsShown() and overlay.mouseEnabled and popup.backdropColor[4] == 1)
    popup.editBox.scripts.OnEscapePressed()
    assert(not popup:IsShown() and not overlay:IsShown())
    assert(popup.editBox.calls.ClearFocus == 1)
    SlashCmdList.DRPULSE("donate")
    assert(popup:IsShown() and overlay:IsShown())
end)

test("minimap clicks open settings and toggle bar locking", function()
    login()
    local button = ns.Minimap.button
    assert(button:IsShown() and button.parent == Minimap)
    button.scripts.OnClick(button, "LeftButton")
    assert(ns.Options.frame:IsShown())
    button.scripts.OnClick(button, "LeftButton")
    assert(not ns.Options.frame:IsShown())
    button.scripts.OnClick(button, "RightButton")
    assert(not ns.db.profile.locked and ns.Core.preview)
end)

test("minimap drag accounts for scale, persists the angle and avoids click-through", function()
    login()
    local button = ns.Minimap.button
    Minimap.scale = 2
    GetCursorPosition = function() return 200, 400 end
    button.scripts.OnDragStart(button)
    button.scripts.OnUpdate(button)
    assert(math.abs(ns.db.profile.minimap.angle - 90) < 0.001)
    button.scripts.OnDragStop(button)
    assert(button.scripts.OnUpdate == nil)
    button.scripts.OnClick(button, "LeftButton")
    assert(ns.Options.frame == nil)
    assert(math.abs(button.point[4]) < 0.001 and math.abs(button.point[5] - 88) < 0.001)
    local saved = ns:Copy(ns.db)
    setup(saved); login()
    assert(math.abs(ns.db.profile.minimap.angle - 90) < 0.001)
end)

test("minimap visibility survives reload and reset restores defaults", function()
    login(); SlashCmdList.DRPULSE("minimap")
    assert(ns.db.profile.minimap.hide and not ns.Minimap.button:IsShown())
    local saved = ns:Copy(ns.db)
    setup(saved); login()
    assert(not ns.Minimap.button:IsShown())
    SlashCmdList.DRPULSE("reset")
    assert(ns.Minimap.button:IsShown() and ns.db.profile.minimap.angle == 225)
end)

test("minimap dimensions and square layouts update positioning", function()
    login(); ns.db.profile.minimap.angle = 45
    GetMinimapShape = function() return "SQUARE" end
    Minimap.width, Minimap.height = 200, 180
    Minimap.scripts.OnSizeChanged()
    assert(math.abs(ns.Minimap.button.point[4] - 108) < 0.001)
    assert(math.abs(ns.Minimap.button.point[5] - 98) < 0.001)
end)

test("missing minimap and invalid saved angles do not break addon loading", function()
    Minimap = nil
    DrpulseDB = { profile = { minimap = { angle = 0 / 0, hide = "invalid" } } }
    login()
    assert(ns.Minimap.button == nil and ns.db.profile.minimap.angle == 225)
    assert(ns.db.profile.minimap.hide == false)
    SlashCmdList.DRPULSE("")
    assert(ns.Options.frame:IsShown())
end)

for _, case in ipairs({ { 10230, 0 }, { 355, 1 }, { 10308, 2 }, { 12826, 4 },
    { 6215, 5 }, { 15487, 6 }, { 676, 7 } }) do
test("category " .. case[2] .. " remains visible beside a secret aura and updates directly from events", function()
    local spellID, category = case[1], case[2]
    local secret = {}
    issecretvalue = function(value) return rawequal(value, secret) end
    local plate = frame()
    C_NamePlate.GetNamePlateForUnit = function() return plate end
    units.target, units.focus, units.nameplate1 = nil, nil, "C"
    login(); ns.db.profile.categories[category] = true
    event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local cc = { auraInstanceID = 7, spellId = spellID, duration = 10, expirationTime = 110, isHarmful = true }
    auras.nameplate1 = { { spellId = secret }, cc }
    event("UNIT_AURA", "nameplate1")
    local bar = ns.UI.nameplates.nameplate1
    assert(bar:IsShown() and bar.icons[category].timer.text == "CC")
    assert(bar.icons[category].stage.text == "50")
    clock = 102; cc.duration, cc.expirationTime = 5, 107
    cc.auraInstanceID = 10
    event("UNIT_AURA", "nameplate1", { removedAuraInstanceIDs = { 7 } })
    assert(bar:IsShown() and bar.icons[category].stage.text == "25")
    -- The next readable application arrives in the event, not the indexed snapshot.
    auras.nameplate1 = { secret }
    clock = 104
    local nextCC = { auraInstanceID = 8, spellId = spellID, isHarmful = true }
    event("UNIT_AURA", "nameplate1", { addedAuras = { nextCC }, removedAuraInstanceIDs = { 10 } })
    assert(bar:IsShown() and bar.icons[category].stage.text == "IMM")
    assert(ns.Core.diagnostics.auraPayloads == 1)
    clock = 106
    event("UNIT_AURA", "nameplate1", { removedAuraInstanceIDs = { 8 } })
    assert(bar:IsShown() and bar.icons[category].timer.text == "18")
end)
end

test("a restricted category does not hide a readable category or reset its count", function()
    local secret = {}
    issecretvalue = function(value) return rawequal(value, secret) end
    auras.target = { { auraInstanceID = 1, spellId = 10230 }, { auraInstanceID = 2, spellId = 10308 } }
    login()
    auras.target = { secret, { auraInstanceID = 2, spellId = 10308 } }
    event("UNIT_AURA", "target")
    local bar = ns.UI.bars.target
    assert(bar.icons[0]:IsShown() and bar.icons[0].timer.text == "?" and bar.icons[2]:IsShown())
    auras.target = { { auraInstanceID = 1, spellId = 10230 }, { auraInstanceID = 2, spellId = 10308 } }
    event("UNIT_AURA", "target")
    assert(bar.icons[0]:IsShown() and bar.icons[0].stage.text == "?")
    assert(bar.icons[2].stage.text == "50")
end)

test("updated aura payloads work during scan errors and ignore buffs and secret IDs", function()
    local secret = {}
    issecretvalue = function(value) return rawequal(value, secret) end
    login()
    C_UnitAuras.GetAuraDataByIndex = function() error("unavailable") end
    C_UnitAuras.GetAuraDataByAuraInstanceID = function(_, id)
        assert(id == 9)
        return { auraInstanceID = 9, spellId = 12826, isHarmful = true }
    end
    event("UNIT_AURA", "target", {
        addedAuras = { { auraInstanceID = 1, spellId = 10308, isHarmful = false }, secret },
        updatedAuraInstanceIDs = { secret, 9 }, removedAuraInstanceIDs = { secret },
    })
    assert(ns.UI.bars.target.icons[4]:IsShown())
    assert(not ns.UI.bars.target.icons[2])
    assert(ns.Core.diagnostics.auraErrors > 0 and ns.Core.diagnostics.auraPayloads == 1)
    event("UNIT_AURA", "target", secret)
    assert(ns.UI.bars.target:IsShown() and ns.UI.bars.target.icons[4].timer.text == "?")
end)

test("a readable event survives failed polling as unknown and then expires", function()
    login()
    C_UnitAuras.GetAuraDataByIndex = function() error("blocked by client") end
    event("UNIT_AURA", "target", { addedAuras = {
        { auraInstanceID = 1, spellId = 12826, isHarmful = true },
    } })
    local bar = ns.UI.bars.target
    assert(bar:IsShown() and bar.icons[4].timer.text == "CC")
    clock = 101.1; ns.Core.ticker.callback()
    assert(bar:IsShown() and bar.icons[4].timer.text == "?" and bar.icons[4].stage.text == "?")
    assert(not bar.icons[4].cooldown:IsShown())
    clock = 120; ns.Core.ticker.callback()
    assert(not bar:IsShown())
end)

test("status exposes the actual error instead of silently reporting only a counter", function()
    login()
    C_UnitAuras.GetAuraDataByIndex = function() error("test error: aura access denied") end
    event("UNIT_AURA", "target")
    local messages = {}
    DEFAULT_CHAT_FRAME.AddMessage = function(_, message) messages[#messages + 1] = message end
    SlashCmdList.DRPULSE("status")
    local found = false
    for _, message in ipairs(messages) do
        if message:find("test error: aura access denied", 1, true) then found = true end
    end
    assert(found and ns.db.lastAuraError:find("GetAuraDataByIndex", 1, true))
end)

test("unit watchers accept secret payload tokens and unregister removed plates", function()
    C_NamePlate.GetNamePlateForUnit = function() return frame() end
    local restricted = {}
    issecretvalue = function(value) return rawequal(value, restricted) end
    methods.RegisterUnitEvent = function(self, name, unit) self.calls[name] = unit end
    methods.UnregisterAllEvents = function(self) self.calls = {} end
    ns.Core.unitEventsSupported = true
    login()
    local watcher = ns.Core.watchers.target
    assert(watcher.calls.UNIT_AURA == "target")
    watcher.scripts.OnEvent(watcher, "UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", restricted,
        { category = 2, startTime = 100, duration = 18, isImmune = true, showCountdown = true })
    assert(ns.UI.bars.target.icons[2].stage.text == "IMM")
    units.nameplate1 = "C"; event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local plateWatcher = ns.Core.watchers.nameplate1
    event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    assert(ns.Core.watchers.nameplate1 == nil and next(plateWatcher.calls) == nil)
    methods.RegisterUnitEvent, methods.UnregisterAllEvents = nil, nil
end)

print(passed .. " lifecycle/UI tests passed")
