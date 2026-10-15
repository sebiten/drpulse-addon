local _, ns = ...

local UI = {}
ns.UI = UI

UI.bars = {}
UI.nameplates = {}

local BORDER = {
    [1] = { 0.35, 0.95, 0.65 },
    [2] = { 1.00, 0.72, 0.20 },
    [3] = { 1.00, 0.25, 0.25 },
}

local function remaining(entry)
    return math.max(0, entry.resetAt - GetTime())
end

local function formatTime(value)
    if value >= 10 then return tostring(math.ceil(value)) end
    return ("%.1f"):format(value)
end

local function createIcon(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
    })
    frame:SetBackdropColor(0.04, 0.05, 0.07, 0.94)

    frame.texture = frame:CreateTexture(nil, "ARTWORK")
    frame.texture:SetPoint("TOPLEFT", 3, -3)
    frame.texture:SetPoint("BOTTOMRIGHT", -3, 3)
    frame.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints(frame.texture)
    frame.cooldown:SetReverse(true)
    frame.cooldown:SetDrawEdge(false)
    frame.cooldown:SetHideCountdownNumbers(true)

    frame.timer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.timer:SetPoint("CENTER", 0, 0)
    frame.timer:SetShadowOffset(1, -1)

    frame.stage = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.stage:SetPoint("BOTTOMRIGHT", -3, 2)
    frame.stage:SetShadowOffset(1, -1)

    frame.confidence = frame:CreateTexture(nil, "OVERLAY")
    frame.confidence:SetSize(5, 5)
    frame.confidence:SetPoint("TOPRIGHT", -3, -3)
    frame.confidence:SetTexture("Interface\\Buttons\\WHITE8X8")

    return frame
end

local function createBar(id, title, parent)
    local frame = CreateFrame("Frame", "Drpulse" .. id .. "Bar", parent or UIParent, "BackdropTemplate")
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(false)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    frame:SetBackdropColor(0.02, 0.025, 0.04, 0.78)
    frame.icons = {}
    frame.unit = id:lower()

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.title:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 2, 3)
    frame.title:SetText(title)
    frame.title:SetTextColor(0.38, 0.85, 1)

    frame.grip = frame:CreateTexture(nil, "OVERLAY")
    frame.grip:SetHeight(3)
    frame.grip:SetPoint("TOPLEFT")
    frame.grip:SetPoint("TOPRIGHT")
    frame.grip:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.grip:SetVertexColor(0.38, 0.85, 1, 0.9)

    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not ns.db.profile.locked then self:StartMoving() end
    end)
    frame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        if not ns.db.profile.locked and self.anchorKey then
            local point, _, relativePoint, x, y = self:GetPoint()
            ns.db.profile.anchors[self.anchorKey] = { point = point, relativePoint = relativePoint, x = x, y = y }
        end
    end)
    return frame
end

function UI:LayoutBar(bar)
    local size = bar.compact and math.max(22, ns.db.profile.iconSize - 8) or ns.db.profile.iconSize
    local spacing = ns.db.profile.iconSpacing
    local count = 0
    for _, category in ipairs(ns.CATEGORY_ORDER) do
        local icon = bar.icons[category]
        if icon and icon:IsShown() then
            icon:SetSize(size, size)
            icon:ClearAllPoints()
            icon:SetPoint("LEFT", 5 + count * (size + spacing), 0)
            count = count + 1
        end
    end
    bar:SetSize(math.max(1, count) * (size + spacing) - spacing + 10, size + 10)
    bar:SetShown(count > 0 or ns.Core.preview)
end

function UI:RenderBar(bar, unit)
    if not ns.db or not ns.db.profile.enabled then bar:Hide() return end
    local state = ns.Core:GetDisplayState(unit)
    local timestamp = GetTime()
    for _, category in ipairs(ns.CATEGORY_ORDER) do
        local entry = state and state.categories[category]
        local enabled = ns.db.profile.categories[category]
        local show = enabled and entry and not (state.auraRestricted and entry.source ~= "Blizzard")
            and (entry.active or (entry.resetAt and entry.resetAt > timestamp))
        local icon = bar.icons[category]
        if show then
            if not icon then
                icon = createIcon(bar)
                bar.icons[category] = icon
            end
            local info = ns:GetCategoryInfo(category)
            local stage = entry.applications and math.min(entry.applications, ns.db.profile.applicationsToImmune)
            local color = stage and (BORDER[stage] or BORDER[3]) or { 0.58, 0.62, 0.68 }
            icon:SetBackdropBorderColor(color[1], color[2], color[3], 1)
            local texture
            if entry.spellID and C_Spell and C_Spell.GetSpellTexture then
                texture = ns:Readable(C_Spell.GetSpellTexture(entry.spellID))
            end
            icon.texture:SetTexture(texture or info.icon)
            icon.timer:SetText(ns.db.profile.showText and (entry.active and "CC" or formatTime(remaining(entry))) or "")
            icon.stage:SetText(not stage and "?" or (stage >= ns.db.profile.applicationsToImmune and "IMM" or (stage == 1 and "50" or "25")))
            icon.confidence:SetVertexColor(entry.exact and 0.20 or 0.58, entry.exact and 0.92 or 0.62, entry.exact and 1.00 or 0.68, 1)
            if ns.db.profile.showSwipe and entry.resetAt then
                local duration = entry.nativeDuration or ns.db.profile.resetSeconds
                if icon.cooldownStart ~= entry.resetAt - duration or icon.cooldownDuration ~= duration then
                    icon.cooldown:SetCooldown(entry.resetAt - duration, duration)
                    icon.cooldownStart, icon.cooldownDuration = entry.resetAt - duration, duration
                end
                icon.cooldown:Show()
            else
                icon.cooldown:Hide()
                icon.cooldownStart, icon.cooldownDuration = nil, nil
            end
            icon:Show()
        elseif icon then
            icon:Hide()
            icon.cooldownStart, icon.cooldownDuration = nil, nil
        end
    end
    self:LayoutBar(bar)
end

function UI:CreatePrimaryBars()
    local target = createBar("Target", "TARGET")
    target.anchorKey = "target"
    self.bars.target = target
    local focus = createBar("Focus", "FOCUS")
    focus.anchorKey = "focus"
    self.bars.focus = focus
    self:RestoreAnchors()
end

function UI:RestoreAnchors()
    for key, bar in pairs(self.bars) do
        if bar.anchorKey then
            local anchor = ns.db.profile.anchors[bar.anchorKey]
            bar:ClearAllPoints()
            bar:SetPoint(anchor.point, UIParent, anchor.relativePoint, anchor.x, anchor.y)
        end
    end
end

function UI:SetLocked(locked)
    ns.db.profile.locked = locked
    for _, bar in pairs(self.bars) do
        if bar.anchorKey then
            bar:EnableMouse(not locked)
            bar.title:SetShown(not locked)
            bar.grip:SetShown(not locked)
        end
    end
    ns.Core:SetPreview(not locked)
end

function UI:AddNameplate(unit)
    if not ns.db.profile.surfaces.nameplates then return end
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end
    local bar = self.nameplates[unit]
    if not bar then
        bar = createBar("Plate" .. unit:gsub("%D", ""), "", plate)
        bar.compact = true
        bar.title:Hide()
        bar.grip:Hide()
        self.nameplates[unit] = bar
    end
    bar:SetParent(plate)
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOM", plate, "TOP", 0, 10)
    self:RenderBar(bar, unit)
end

function UI:RemoveNameplate(unit)
    local bar = self.nameplates[unit]
    if bar then bar:Hide() end
end

function UI:Refresh()
    if self.bars.target then
        self.bars.target:SetShown(ns.db.profile.surfaces.target)
        if ns.db.profile.surfaces.target then self:RenderBar(self.bars.target, "target") end
    end
    if self.bars.focus then
        self.bars.focus:SetShown(ns.db.profile.surfaces.focus)
        if ns.db.profile.surfaces.focus then self:RenderBar(self.bars.focus, "focus") end
    end
    if ns.db.profile.surfaces.nameplates then
        for unit in pairs(ns.Core.visibleUnits) do
            local key = ns.Core.unitKeys[unit]
            local state = key and ns.Core.units[key]
            if ns.Core.preview or (state and next(state.categories)) then
                self:AddNameplate(unit)
            else
                self:RemoveNameplate(unit)
            end
        end
    else
        for _, bar in pairs(self.nameplates) do bar:Hide() end
    end
end

ns:On("DB_READY", function() UI:CreatePrimaryBars() end)
ns:On("READY", function() UI:SetLocked(ns.db.profile.locked) UI:Refresh() end)
ns:On("TICK", function() UI:Refresh() end)
ns:On("STATE_CHANGED", function() UI:Refresh() end)
ns:On("UNIT_CHANGED", function() UI:Refresh() end)
ns:On("NAMEPLATE_ADDED", function(unit) UI:AddNameplate(unit) end)
ns:On("NAMEPLATE_REMOVED", function(unit) UI:RemoveNameplate(unit) end)
ns:On("PREVIEW_CHANGED", function() UI:Refresh() end)

