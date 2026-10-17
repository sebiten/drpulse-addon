local _, ns = ...

local Options = {}
ns.Options = Options
local PAYPAL_URL = "https://www.paypal.com/paypalme/sebiten"
local PAYPAL_BLUE = { 0.00, 0.44, 0.76 }
local PAYPAL_BLUE_HOVER = { 0.04, 0.55, 0.92 }
local PAYPAL_GOLD = { 1.00, 0.75, 0.14 }

local function makeButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, 24)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function makeSupportButton(parent, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(164, 28)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    button:SetBackdropColor(PAYPAL_BLUE[1], PAYPAL_BLUE[2], PAYPAL_BLUE[3], 0.92)
    button:SetBackdropBorderColor(PAYPAL_GOLD[1], PAYPAL_GOLD[2], PAYPAL_GOLD[3], 0.85)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 10, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", icon, "RIGHT", 7, 0)
    label:SetPoint("RIGHT", button, "RIGHT", -10, 0)
    label:SetJustifyH("CENTER")
    label:SetText("Support Drpulse")
    label:SetTextColor(1, 1, 1)
    button.label = label

    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(PAYPAL_BLUE_HOVER[1], PAYPAL_BLUE_HOVER[2], PAYPAL_BLUE_HOVER[3], 1)
        self:SetBackdropBorderColor(PAYPAL_GOLD[1], PAYPAL_GOLD[2], PAYPAL_GOLD[3], 1)
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(PAYPAL_BLUE[1], PAYPAL_BLUE[2], PAYPAL_BLUE[3], 0.92)
        self:SetBackdropBorderColor(PAYPAL_GOLD[1], PAYPAL_GOLD[2], PAYPAL_GOLD[3], 0.85)
    end)
    button:SetScript("OnClick", onClick)
    return button
end

local function makeCheckbox(parent, label, getter, setter)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check.Text:SetText(label)
    check:SetScript("OnClick", function(self)
        setter(self:GetChecked() == true)
        ns.UI:Refresh()
    end)
    check.Refresh = function(self) self:SetChecked(getter()) end
    return check
end

local function makeSlider(parent, label, minValue, maxValue, step, getter, setter)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider.Text:SetText(label)
    slider.Low:SetText(tostring(minValue))
    slider.High:SetText(tostring(maxValue))
    slider:SetScript("OnValueChanged", function(_, value)
        setter(value)
        ns.UI:Refresh()
    end)
    slider.Refresh = function(self) self:SetValue(getter()) end
    return slider
end

function Options:Create()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "DrpulseOptionsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(720, 570)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.025, 0.03, 0.045, 1)
    frame:SetBackdropBorderColor(0.18, 0.25, 0.32, 1)
    frame:Hide()
    table.insert(UISpecialFrames, "DrpulseOptionsFrame")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 24, -22)
    title:SetText("Drpulse")
    title:SetTextColor(0.38, 0.85, 1)
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", 24, -50)
    subtitle:SetText("Diminishing Returns for Forever  •  v" .. ns.version)

    local close = makeButton(frame, "Close", 80, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", -18, -18)

    local description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", 24, -78)
    description:SetWidth(672)
    description:SetJustifyH("LEFT")
    description:SetText("Blue = confirmed. Gray = estimated or unknown percentage (?). CC = active effect; the reset timer has not started. Restricted GUIDs are tracked only while the unit stays visible.")
    description:SetTextColor(0.68, 0.73, 0.80)

    local displayTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    displayTitle:SetPoint("TOPLEFT", 24, -120)
    displayTitle:SetText("Display")
    displayTitle:SetTextColor(0.38, 0.85, 1)
    local checks = {
        makeCheckbox(frame, "Show on Target", function() return ns.db.profile.surfaces.target end, function(v) ns.db.profile.surfaces.target = v end),
        makeCheckbox(frame, "Show on Focus", function() return ns.db.profile.surfaces.focus end, function(v) ns.db.profile.surfaces.focus = v end),
        makeCheckbox(frame, "Show on Nameplates", function() return ns.db.profile.surfaces.nameplates end, function(v) ns.db.profile.surfaces.nameplates = v end),
        makeCheckbox(frame, "Show Timer Text", function() return ns.db.profile.showText end, function(v) ns.db.profile.showText = v end),
        makeCheckbox(frame, "Cooldown Swipe", function() return ns.db.profile.showSwipe end, function(v) ns.db.profile.showSwipe = v end),
        makeCheckbox(frame, "Blizzard Native Feed", function() return ns.db.profile.nativeFeed end, function(v)
            ns.Core:SetNativeFeed(v)
        end),
    }
    for index, check in ipairs(checks) do
        local column = index > 3 and 1 or 0
        local row = (index - 1) % 3
        check:SetPoint("TOPLEFT", 24 + column * 336, -144 - row * 34)
    end
    frame.checks = checks

    local categoryTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    categoryTitle:SetPoint("TOPLEFT", 24, -265)
    categoryTitle:SetText("Categories")
    categoryTitle:SetTextColor(0.38, 0.85, 1)
    frame.categoryChecks = {}
    for index, category in ipairs(ns.CATEGORY_ORDER) do
        local info = ns.CATEGORIES[category]
        local check = makeCheckbox(frame, info.label, function() return ns.db.profile.categories[category] end, function(v) ns.db.profile.categories[category] = v end)
        check:SetPoint("TOPLEFT", 24 + ((index - 1) % 4) * 168, -291 - math.floor((index - 1) / 4) * 34)
        frame.categoryChecks[#frame.categoryChecks + 1] = check
    end

    local sizeSlider = makeSlider(frame, "Icon Size", 24, 56, 1, function() return ns.db.profile.iconSize end, function(v) ns.db.profile.iconSize = math.floor(v + 0.5) end)
    sizeSlider:SetPoint("TOPLEFT", 36, -397)
    sizeSlider:SetWidth(288)
    local resetSlider = makeSlider(frame, "DR Reset Window (seconds)", 15, 22, 1, function() return ns.db.profile.resetSeconds end, function(v) ns.db.profile.resetSeconds = math.floor(v + 0.5) end)
    resetSlider:SetPoint("TOPLEFT", 372, -397)
    resetSlider:SetWidth(288)
    frame.sliders = { sizeSlider, resetSlider }

    local minimapCheck = makeCheckbox(frame, "Show Minimap Button",
        function() return not ns.db.profile.minimap.hide end,
        function(value)
            ns.db.profile.minimap.hide = not value
            ns.Minimap:Refresh()
        end)
    minimapCheck:SetPoint("TOPLEFT", 24, -446)
    frame.checks[#frame.checks + 1] = minimapCheck

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\Buttons\\WHITE8X8")
    divider:SetVertexColor(0.18, 0.25, 0.32, 1)
    divider:SetHeight(1)
    divider:SetPoint("BOTTOMLEFT", 24, 72)
    divider:SetPoint("BOTTOMRIGHT", -24, 72)

    local unlock = makeButton(frame, "Unlock & Preview", 176, function()
        ns.UI:SetLocked(not ns.db.profile.locked)
        frame:Refresh()
    end)
    unlock:SetPoint("BOTTOMLEFT", 24, 28)
    frame.unlock = unlock

    local history = makeButton(frame, "History", 96, function() Options:ToggleHistory() end)
    history:SetPoint("LEFT", unlock, "RIGHT", 12, 0)
    local reset = makeButton(frame, "Reset", 88, function()
        ns.Core:ResetProfile()
    end)
    reset:SetPoint("LEFT", history, "RIGHT", 12, 0)
    local donate = makeSupportButton(frame, function() Options:ToggleDonate() end)
    donate:SetPoint("BOTTOMRIGHT", -24, 28)
    frame.donateButton = donate

    frame.Refresh = function(self)
        for _, check in ipairs(self.checks) do check:Refresh() end
        for _, check in ipairs(self.categoryChecks) do check:Refresh() end
        for _, slider in ipairs(self.sliders) do slider:Refresh() end
        self.unlock:SetText(ns.db.profile.locked and "Unlock & Preview" or "Lock")
    end
    frame:SetScript("OnShow", frame.Refresh)
    self.frame = frame
    return frame
end

function Options:RegisterSettings()
    if self.settingsRegistered or not Settings or not Settings.RegisterCanvasLayoutCategory then return end
    local panel = CreateFrame("Frame")
    panel.name = "Drpulse"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Drpulse")
    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    description:SetWidth(560)
    description:SetJustifyH("LEFT")
    description:SetText("Diminishing Returns tracker for WoW: Forever. Configure display surfaces, categories, icon size, preview, and history.")
    local open = makeButton(panel, "Open Drpulse Settings", 220, function() Options:Toggle() end)
    open:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -20)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "Drpulse")
    Settings.RegisterAddOnCategory(category)
    self.settingsCategory = category
    self.settingsRegistered = true
end

function Options:Toggle()
    local frame = self:Create()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

function Options:ToggleDonate()
    if not self.donateFrame then
        -- A separate stratum keeps every settings child below the modal.
        local overlay = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        overlay:SetAllPoints(UIParent)
        overlay:SetFrameStrata("FULLSCREEN_DIALOG")
        overlay:SetFrameLevel(100)
        overlay:EnableMouse(true)
        overlay:EnableMouseWheel(true)
        overlay:SetScript("OnMouseWheel", function() end)
        overlay:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        overlay:SetBackdropColor(0.01, 0.015, 0.025, 0.65)
        overlay:Hide()
        self.donateOverlay = overlay

        local popup = CreateFrame("Frame", "DrpulseDonateFrame", overlay, "BackdropTemplate")
        popup:SetSize(500, 262)
        popup:SetPoint("CENTER")
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetFrameLevel(overlay:GetFrameLevel() + 1)
        popup:SetClampedToScreen(true)
        popup:EnableMouse(true)
        popup:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
        popup:SetBackdropColor(0.035, 0.045, 0.065, 1)
        popup:SetBackdropBorderColor(0.18, 0.32, 0.46, 1)
        popup:Hide()
        table.insert(UISpecialFrames, "DrpulseDonateFrame")

        local accent = popup:CreateTexture(nil, "ARTWORK")
        accent:SetHeight(2)
        accent:SetPoint("TOPLEFT", 2, -2)
        accent:SetPoint("TOPRIGHT", -2, -2)
        accent:SetTexture("Interface\\Buttons\\WHITE8X8")
        accent:SetVertexColor(PAYPAL_GOLD[1], PAYPAL_GOLD[2], PAYPAL_GOLD[3], 1)

        local icon = popup:CreateTexture(nil, "ARTWORK")
        icon:SetSize(42, 42)
        icon:SetPoint("TOPLEFT", 22, -24)
        icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 78, -25)
        title:SetText("Support Drpulse")
        title:SetTextColor(0.38, 0.85, 1)
        local description = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
        description:SetWidth(398)
        description:SetJustifyH("LEFT")
        description:SetText("Drpulse is free and always will be. If it helps you in PvP, you can support future updates with a one-time PayPal donation.")
        description:SetTextColor(0.75, 0.79, 0.85)

        local editBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
        editBox:SetSize(446, 28)
        editBox:SetPoint("TOPLEFT", 28, -121)
        editBox:SetAutoFocus(false)
        editBox:SetText(PAYPAL_URL)
        editBox:SetScript("OnEscapePressed", function() popup:Hide() end)
        editBox:SetScript("OnMouseUp", function(self) self:HighlightText() end)
        editBox:SetScript("OnEnterPressed", function(self) self:HighlightText() end)
        popup.editBox = editBox

        local hint = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 2, -5)
        hint:SetWidth(446)
        hint:SetJustifyH("LEFT")
        hint:SetText("Press Ctrl+C and paste the link into your browser.\nDonations are optional.")
        hint:SetTextColor(0.55, 0.60, 0.68)

        popup:SetScript("OnShow", function()
            overlay:Show()
            editBox:SetText(PAYPAL_URL)
            editBox:SetFocus()
            editBox:HighlightText()
        end)
        popup:SetScript("OnHide", function()
            editBox:ClearFocus()
            overlay:Hide()
        end)

        local selectLink = makeSupportButton(popup, function()
            editBox:SetFocus()
            editBox:HighlightText()
        end)
        selectLink.label:SetText("Select link")
        selectLink:SetPoint("BOTTOMLEFT", 24, 18)

        local close = makeButton(popup, "Done", 82, function() popup:Hide() end)
        close:SetPoint("BOTTOMRIGHT", -24, 20)
        self.donateFrame = popup
    end
    if self.donateFrame:IsShown() then
        self.donateFrame:Hide()
    else
        self.donateOverlay:Show()
        self.donateFrame:Show()
    end
end

function Options:ToggleHistory()
    if not self.history then
        local history = CreateFrame("Frame", "DrpulseHistoryFrame", UIParent, "BackdropTemplate")
        history:SetSize(520, 410)
        history:SetPoint("CENTER", 350, 0)
        history:SetFrameStrata("DIALOG")
        history:Hide()
        history:EnableMouse(true)
        history:SetClampedToScreen(true)
        local close = makeButton(history, "Close", 70, function() history:Hide() end)
        close:SetPoint("TOPRIGHT", -12, -12)
        history:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        history:SetBackdropColor(0.025, 0.03, 0.045, 0.98)
        history:SetBackdropBorderColor(0.18, 0.25, 0.32, 1)
        table.insert(UISpecialFrames, "DrpulseHistoryFrame")
        history.title = history:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        history.title:SetPoint("TOPLEFT", 18, -18)
        history.title:SetText("DR History")
        history.lines = {}
        self.history = history
    end
    self.history:SetShown(not self.history:IsShown())
    self:RefreshHistory()
end

function Options:RefreshHistory()
    if not self.history or not self.history:IsShown() then return end
    for index = 1, 16 do
        local line = self.history.lines[index]
        if not line then
            line = self.history:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            line:SetPoint("TOPLEFT", 18, -48 - (index - 1) * 21)
            line:SetWidth(480)
            line:SetJustifyH("LEFT")
            self.history.lines[index] = line
        end
        local event = ns.Core.history[index]
        if event then
            local info = ns.CATEGORIES[event.category]
            line:SetText(("%s  |cff61dafb%-16s|r  %-18s  x%s  |cff8b929e%s|r"):format(event.time, event.name, info.label, tostring(event.applications or "?"), event.source))
        else
            line:SetText(index == 1 and "No events in this session yet." or "")
        end
    end
end

ns:On("HISTORY_CHANGED", function() Options:RefreshHistory() end)
ns:On("READY", function() Options:RegisterSettings() end)

SLASH_DRPULSE1 = "/drpulse"
SLASH_DRPULSE2 = "/rdr"
SlashCmdList.DRPULSE = function(message)
    if not ns.db then return end
    local input = strtrim(message or "")
    local command, rest = input:match("^(%S+)%s*(.-)$")
    command = (command or ""):lower()
    if command == "unlock" then
        ns.UI:SetLocked(false)
    elseif command == "lock" then
        ns.UI:SetLocked(true)
    elseif command == "preview" then
        ns.Core:SetPreview(not ns.Core.preview)
    elseif command == "history" then
        Options:ToggleHistory()
    elseif command == "donate" or command == "support" then
        Options:ToggleDonate()
    elseif command == "minimap" then
        ns.db.profile.minimap.hide = not ns.db.profile.minimap.hide
        ns.Minimap:Refresh()
        if Options.frame then Options.frame:Refresh() end
    elseif command == "status" then
        local supported = "unknown"
        if C_SpellDiminish and C_SpellDiminish.IsSystemSupported then
            local ok, value = pcall(C_SpellDiminish.IsSystemSupported)
            if ok and not ns:IsSecret(value) then supported = value and "yes" or "no" end
        end
        local diagnostics = ns.Core.diagnostics
        ns:Print(("v%s | Auras: events %d, event CC reads %d, scan errors %d, unreadable entries %d, readable CC reads %d."):format(
            ns.version, diagnostics.auraEvents, diagnostics.auraPayloads, diagnostics.auraErrors,
            diagnostics.auraUnreadable, diagnostics.auraReadable))
        ns:Print(("Native: supported %s, event %s, received %d, applied %d, restricted %d."):format(
            supported, ns.Core.nativeEventRegistered and "yes" or "no",
            diagnostics.nativeEvents, diagnostics.nativeApplied, diagnostics.nativeRestricted))
        local targetKey = ns.Core:GetUnitKey("target")
        local focusKey = ns.Core:GetUnitKey("focus")
        local plates = 0
        for _ in pairs(ns.Core.visibleUnits) do plates = plates + 1 end
        local surfaces = ns.db.profile.surfaces
        ns:Print(("Display %s (T:%s F:%s N:%s); target %s, focus %s, plates %d; restricted aura scans %d."):format(
            ns.db.profile.enabled and "on" or "off",
            surfaces.target and "on" or "off", surfaces.focus and "on" or "off",
            surfaces.nameplates and "on" or "off",
            targetKey and (targetKey:sub(1, 5) == "unit:" and "token" or "GUID") or "none",
            focusKey and (focusKey:sub(1, 5) == "unit:" and "token" or "GUID") or "none",
            plates, diagnostics.auraRestricted))
    elseif command == "reset" then
        ns.Core:ResetProfile()
        ns:Print("Settings reset.")
    elseif command == "add" then
        local spellID, categoryName = rest:match("^(%d+)%s+(%S+)$")
        local wanted
        for category, info in pairs(ns.CATEGORIES) do
            if info.key == (categoryName or ""):lower() then wanted = category break end
        end
        if spellID and ns:IsFinite(tonumber(spellID)) and tonumber(spellID) > 0 and wanted ~= nil then
            ns.db.profile.customSpells[tonumber(spellID)] = wanted
            ns.Core:ResetTracking()
            ns:Print(("Spell %s added to %s."):format(spellID, ns.CATEGORIES[wanted].label))
        else
            ns:Print("Usage: /drpulse add <spellID> <root|taunt|stun|knockback|incapacitate|disorient|silence|disarm>")
        end
    elseif command == "remove" then
        local spellID = tonumber(rest)
        if ns:IsFinite(spellID) and spellID > 0 and spellID % 1 == 0 then
            ns.db.profile.customSpells[spellID] = nil
            ns.Core:ResetTracking()
            ns:Print(("Spell %d removed."):format(spellID))
        else
            ns:Print("Usage: /drpulse remove <spellID>")
        end
    elseif command == "help" then
        ns:Print("/drpulse — options | unlock | lock | preview | history | donate | minimap | status | add | remove | reset")
    else
        Options:Toggle()
    end
end

function Drpulse_OnCompartmentClick(_, button)
    if button == "RightButton" then
        ns.UI:SetLocked(not ns.db.profile.locked)
    else
        Options:Toggle()
    end
end

