-- Personal DR: isolated evidence and state, sharing only the engine and renderer.
-- Copyright 2026 Joaqoz. MIT.
local _, ns = ...
local KEY, DR_EVENT = "Drpulse:player", "UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED"
local tracker, events, display
local instances, nativeSeen, ids = {}, {}, nil
local queued, lastScan, previewUntil, previewStart = false, -1, 0, 0
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function Enabled() return ns.db and ns.db.enabled and ns.db.player end

local function Scan()
    queued = false
    if not tracker or not Enabled() then return end
    local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
    if ns.Bool(dead) and dead then return end
    if not C_UnitAuras or type(C_UnitAuras.GetUnitAuraBySpellID) ~= "function" then return end
    if not C_Secrets or type(C_Secrets.ShouldSpellAuraBeSecret) ~= "function" then return end
    local now, current, readable = GetTime(), {}, {}
    lastScan = now
    ids = ids or ns.TrackedIDs()
    for id in pairs(ids) do
        local hidden = C_Secrets.ShouldSpellAuraBeSecret(id)
        if ns.Bool(hidden) and not hidden then
            local aura = C_UnitAuras.GetUnitAuraBySpellID("player", id)
            if ns.Public(aura) then
                -- A restricted spell or table disappearing is not evidence of removal.
                readable[id] = true
                local category = ns.CategoryOf(id)
                if category and category ~= "Taunt" and type(aura) == "table" then
                    local instance = aura.auraInstanceID
                    local key = ns.Number(instance, 1) and ("i:" .. instance) or ("s:" .. id)
                    local duration, expires, start
                    if ns.Number(aura.duration, 0.01, 3600) then duration = aura.duration end
                    if duration and ns.Number(aura.expirationTime, 0) then
                        expires = aura.expirationTime
                        start = expires - duration
                        if start > now + 0.1 or start < now - 3600 then start, expires = nil, nil end
                    end
                    current[key] = { id = id, category = category, start = start, expires = expires }
                end
            end
        end
    end
    for key, old in pairs(instances) do
        if not current[key] and readable[old.id] then
            tracker:End(KEY, old.category, math.min(now, old.expires or now), key)
            instances[key] = nil
        end
    end
    for key, aura in pairs(current) do
        local old = instances[key]
        local refreshed = old and old.start and aura.start and aura.start > old.start + 0.25
        if not old or refreshed then
            local state = tracker:State(KEY, aura.category, now, false)
            if state and state.active and state.nativeStart and aura.start
                and math.abs(state.nativeStart - aura.start) <= 0.25 then
                -- A delayed scan of the same native application is still one CC.
                state.spellID, state.lastKey = aura.id, key
                if aura.expires then
                    state.activeUntil, state.endKnown = aura.expires, true
                    if not state.nativeTimed then state.resetAt = aura.expires + ns.db.resetTime end
                end
            else
                tracker:Apply(KEY, aura.category, math.min(aura.start or now, now), {
                    source = "player aura", confirmed = true, spellID = aura.id, expires = aura.expires, key = key,
                })
            end
        elseif aura.expires and aura.expires ~= old.expires then
            local state = tracker:State(KEY, aura.category, now, false)
            if state and state.lastKey == key then
                state.activeUntil, state.endKnown = aura.expires, true
                if not state.nativeTimed then state.resetAt = aura.expires + ns.db.resetTime end
            end
        end
        instances[key] = aura
    end
    ns.RequestRefresh()
end

local function QueueScan()
    if queued or not Enabled() then return end
    queued = true
    C_Timer.After(math.max(0.05, 0.2 - (GetTime() - lastScan)), Scan)
end

local function Native(info)
    if not Enabled() or not tracker or not ns.Public(info) or type(info) ~= "table" then return end
    local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
    if ns.Bool(dead) and dead then return end
    local category, start, duration = info.category, info.startTime, info.duration
    local countdown, immune = info.showCountdown, info.isImmune
    -- Never infer a personal application from opaque/secret events or enemy casts.
    if not ns.Number(category) or not ns.Number(start, 0) or not ns.Number(duration, 0, 3600)
        or not ns.Bool(countdown) or not ns.Bool(immune) then return end
    local values = Enum and Enum.SpellDiminishCategory
    if type(values) ~= "table" then return end
    local name
    for _, candidate in ipairs(ns.CATEGORIES) do
        if values[candidate] == category then name = candidate; break end
    end
    if not name or name == "Taunt" then return end
    local previous = nativeSeen[name]
    if previous and previous.start == start and previous.duration == duration
        and previous.countdown == countdown and previous.immune == immune then return end
    local data = { start = start, duration = duration, countdown = countdown, immune = immune }
    nativeSeen[name] = data
    local state = tracker:State(KEY, name, GetTime(), false)
    if not countdown and state and state.active and state.appliedAt and state.source == "player aura"
        and math.abs(state.appliedAt - start) <= 0.25 then
        state.nativeStart = start
        if immune then state.immune, state.count = true, math.max(state.count, ns.IMMUNE_STACKS) end
    else
        tracker:Native(KEY, name, GetTime(), data)
    end
    ns.RequestRefresh()
end

function ns.ClearPlayerTracking()
    if tracker then tracker:Clear() end
    instances, nativeSeen, ids = {}, {}, nil
    QueueScan()
end

function ns.PositionPlayer()
    if not display then return end
    display:ClearAllPoints()
    display:SetPoint("CENTER", UIParent, "CENTER", ns.db.playerX, ns.db.playerY)
end

function ns.FinishPlayerInteraction()
    if not display or not display.moving then return end
    display:StopMovingOrSizing()
    display.moving = false
    local x, y = display:GetCenter()
    local centerX, centerY = UIParent:GetCenter()
    if ns.Number(x) and ns.Number(y) and ns.Number(centerX) and ns.Number(centerY) then
        ns.Set("playerX", math.max(-3000, math.min(3000, math.floor(x - centerX + 0.5))))
        ns.Set("playerY", math.max(-3000, math.min(3000, math.floor(y - centerY + 0.5))))
    end
    ns.PositionPlayer()
end

function ns.ResetPlayerPosition()
    ns.FinishPlayerInteraction()
    ns.Set("playerX", ns.Default("playerX"))
    ns.Set("playerY", ns.Default("playerY"))
end

function ns.PreviewPlayer()
    previewStart, previewUntil = GetTime(), GetTime() + 20
    ns.RequestRefresh()
end

function ns.CreatePlayerDisplay()
    display = CreateFrame("Frame", nil, UIParent)
    display:SetFrameStrata("MEDIUM")
    display:SetClampedToScreen(true)
    display:SetMovable(true)
    display:SetSize(100, ns.db.playerSize)
    display.row = CreateFrame("Frame", nil, display)
    display.row:SetPoint("LEFT")
    local handle = CreateFrame("Button", nil, display, "BackdropTemplate")
    handle:SetPoint("BOTTOMLEFT", display, "TOPLEFT", 0, 4)
    handle:SetPoint("BOTTOMRIGHT", display, "TOPRIGHT", 0, 4)
    handle:SetHeight(22)
    handle:SetBackdrop({ bgFile = WHITE })
    handle:SetBackdropColor(0.04, 0.14, 0.19, 1)
    handle:RegisterForDrag("LeftButton")
    handle:RegisterForClicks("RightButtonUp")
    local label = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER")
    label:SetText("Your DR · drag to move")
    handle:SetScript("OnDragStart", function()
        if ns.db.playerLocked or InCombatLockdown() then return end
        display.moving = true
        display:StartMoving()
    end)
    handle:SetScript("OnDragStop", ns.FinishPlayerInteraction)
    handle:SetScript("OnClick", function()
        ns.FinishPlayerInteraction()
        ns.Set("playerLocked", true)
    end)
    handle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Your diminishing returns")
        GameTooltip:AddLine("Drag outside combat. Right-click to lock. Appearance > Your DR display has size and position controls.", 0.8, 0.85, 0.9, true)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local caption = display:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    caption:SetPoint("BOTTOMLEFT", display, "TOPLEFT", 0, 4)
    caption:SetText("Your DR")
    caption:SetTextColor(0.62, 0.80, 0.88)
    display.handle, display.caption = handle, caption
    display:SetScript("OnHide", ns.FinishPlayerInteraction)
    display:Hide()
    ns.playerDisplay = display
    ns.PositionPlayer()
end

function ns.RefreshPlayerDisplay(now)
    if not display then return false end
    local db = ns.db
    local unlocked = db.player and not db.playerLocked
    local preview = now < previewUntil
    if not db.enabled or (not db.player and not preview) or (not ns.VisibilityAllowed() and not unlocked and not preview) then
        display:Hide()
        return false
    end
    local entries = db.player and tracker and tracker:Snapshot(KEY, now) or nil
    if preview then entries = ns.SettingsSamples(now, previewStart)
    elseif not entries and unlocked then entries = ns.SettingsSamples(now) end
    -- Incoming CC is independent of enemy category filters and the player's spellbook.
    local count = ns.LayoutRow(display.row, entries, db.playerSize, nil, true)
    local width = math.max(display.row:GetWidth(), 150)
    if display.width ~= width or display.size ~= db.playerSize then
        display:SetSize(width, db.playerSize)
        display.width, display.size = width, db.playerSize
    end
    display.handle:SetShown(unlocked)
    display.caption:SetShown(not unlocked)
    if display.preview ~= preview then
        display.caption:SetText(preview and "Your DR · preview" or "Your DR")
        display.preview = preview
    end
    display:SetShown(count > 0 or unlocked)
    return count > 0 or unlocked or preview
end

function ns.StartPlayerTracking()
    tracker = ns.NewTracker(function() return ns.db.resetTime end)
    events = CreateFrame("Frame")
    events:RegisterUnitEvent("UNIT_AURA", "player")
    local supported = C_SpellDiminish and C_SpellDiminish.IsSystemSupported and C_SpellDiminish.IsSystemSupported()
    if ns.Bool(supported) and supported and C_EventUtils.IsEventValid(DR_EVENT) then
        events:RegisterUnitEvent(DR_EVENT, "player")
    end
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_DEAD", "PLAYER_ALIVE",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED" }) do
        if C_EventUtils.IsEventValid(event) then events:RegisterEvent(event) end
    end
    events:SetScript("OnEvent", function(_, event, _, info)
        if not Enabled() and GetTime() >= previewUntil then return end
        if event == DR_EVENT then Native(info)
        elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_DEAD" then
            ns.ClearPlayerTracking()
            previewUntil = 0
        elseif event == "PLAYER_LEAVING_WORLD" then
            ns.FinishPlayerInteraction()
            ns.ClearPlayerTracking()
            previewUntil = 0
        else
            if event == "PLAYER_REGEN_DISABLED" then ns.FinishPlayerInteraction() end
            QueueScan()
        end
        ns.RequestRefresh()
    end)
    ns.OnSettingChanged(function(key)
        if key == "playerX" or key == "playerY" or key == "profile" then ns.PositionPlayer() end
        if key == "playerLocked" and ns.db.playerLocked then ns.FinishPlayerInteraction() end
        if key == "profile" or key == "enabled" or key == "player" or key == "custom" or key == "resetTime" then
            ns.ClearPlayerTracking()
            previewUntil = 0
        end
        ns.RequestRefresh()
    end)
    QueueScan()
end
