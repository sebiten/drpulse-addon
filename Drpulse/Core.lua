local _, ns = ...

local Core = {}
ns.Core = Core

Core.units = {}
Core.visibleUnits = {}
Core.history = {}
Core.preview = false
Core.unitKeys = {}
Core.pendingCasts, Core.sentCasts = {}, {}
Core.diagnostics = { nativeEvents = 0, nativeRestricted = 0, nativeApplied = 0, auraRestricted = 0,
    auraEvents = 0, auraPayloads = 0, auraErrors = 0, auraUnreadable = 0, auraReadable = 0, auraSkipped = 0 }

local function now()
    return GetTime()
end

local function read(value)
    return ns:Readable(value)
end

function Core:AuraError(unit, method, message)
    self.diagnostics.auraErrors = self.diagnostics.auraErrors + 1
    local detail = read(message)
    if type(detail) ~= "string" then detail = "Unreadable API error" end
    self.diagnostics.lastAuraError = method .. " [" .. unit .. "]: " .. detail:sub(1, 400)
    ns.db.lastAuraError = self.diagnostics.lastAuraError
end

local function restrictedIndex(unit, index)
    if not C_Secrets or not C_Secrets.ShouldUnitAuraIndexBeSecret then return false end
    local ok, restricted = pcall(C_Secrets.ShouldUnitAuraIndexBeSecret, unit, index, "HARMFUL")
    return ok and (ns:IsSecret(restricted) or restricted == true)
end

local function auraReadable(spellID)
    if not C_Secrets or not C_Secrets.ShouldSpellAuraBeSecret then return true end
    local ok, secret = pcall(C_Secrets.ShouldSpellAuraBeSecret, spellID)
    return ok and not ns:IsSecret(secret) and type(secret) == "boolean" and not secret
end

function Core:GetReadableAuraSpells()
    local timestamp = now()
    if self.readableAuraSpells and timestamp - self.readableAuraSpellsAt < 1 then
        return self.readableAuraSpells
    end
    local list, set = {}, {}
    local function add(spellID)
        if not set[spellID] and auraReadable(spellID) then
            set[spellID] = true
            list[#list + 1] = spellID
        end
    end
    for spellID in pairs(ns.SPELLS) do add(spellID) end
    for spellID in pairs(ns.db.profile.customSpells) do add(spellID) end
    self.readableAuraSpells = { list = list, set = set }
    self.readableAuraSpellsAt = timestamp
    return self.readableAuraSpells
end

function Core:GetUnitKey(unit)
    if ns:IsSecret(unit) or type(unit) ~= "string" then return nil end
    local exists = UnitExists(unit)
    if not ns:IsSecret(exists) and exists ~= true then return nil end
    if UnitCanAttack then
        local attackable = UnitCanAttack("player", unit)
        if not ns:IsSecret(attackable) and attackable ~= true then return nil end
    end
    local guid = read(UnitGUID(unit))
    if type(guid) == "string" and guid ~= "" then return "guid:" .. guid end
    -- Forever can hide hostile GUIDs while leaving player names public. Use the
    -- full player name so target, focus and nameplate still share one DR state.
    if UnitIsPlayer and read(UnitIsPlayer(unit)) == true and UnitName then
        local name, realm = UnitName(unit)
        name, realm = read(name), read(realm)
        if type(name) == "string" and name ~= "" and name ~= _G.UNKNOWNOBJECT
            and (realm == nil or type(realm) == "string") then
            return "name:" .. name .. (realm and realm ~= "" and ("-" .. realm) or "")
        end
    end
    -- A restricted GUID can still be tracked for the lifetime of this visible token.
    if unit == "target" or unit == "focus" or self.visibleUnits[unit] then
        return "unit:" .. unit
    end
    return nil
end

function Core:ReleaseUnit(unit)
    if ns:IsSecret(unit) or type(unit) ~= "string" then return end
    local key = self.unitKeys[unit]
    self.unitKeys[unit] = nil
    if not key then return end
    for _, observedKey in pairs(self.unitKeys) do
        if observedKey == key then return end
    end
    local state = self.units[key]
    if not state then return end
    if key:sub(1, 5) == "unit:" then
        self.units[key] = nil
        return
    end
    -- Losing visibility is not evidence that a CC ended.
    state.auras = {}
    for category, entry in pairs(state.categories) do
        if entry.active then state.categories[category] = nil end
    end
end

function Core:GetUnitState(unit, create)
    local key = self:GetUnitKey(unit)
    if ns:IsSecret(unit) or type(unit) ~= "string" then return nil end
    if self.unitKeys[unit] ~= key then self:ReleaseUnit(unit) end
    if not key then return nil end
    self.unitKeys[unit] = key
    local state = self.units[key]
    if not state and create then
        state = { key = key, categories = {}, auras = {}, lastSeen = now() }
        self.units[key] = state
    end
    if state then
        state.unit = unit
        state.lastSeen = now()
    end
    return state
end

function Core:Record(unit, category, spellID, source, exact)
    local state = self:GetUnitState(unit, true)
    if not state or not ns.CATEGORIES[category] then return end
    local timestamp = now()
    local entry = state.categories[category]
    if entry and entry.source == "Blizzard" and (entry.active or (entry.resetAt and entry.resetAt > timestamp)) then
        entry.spellID = spellID or entry.spellID
        return
    end
    if not entry or (not entry.active and entry.resetAt and entry.resetAt <= timestamp) then
        entry = { applications = 0 }
        state.categories[category] = entry
    end
    entry.applications = math.min(entry.applications + 1, ns.db.profile.applicationsToImmune)
    entry.spellID = spellID or entry.spellID
    entry.source = source
    entry.exact = exact == true
    entry.active = true
    entry.timerUnknown = nil
    entry.updatedAt = timestamp
    entry.resetAt = nil
    self:AddHistory(unit, category, entry.applications, source, spellID)
    ns:Emit("STATE_CHANGED", unit, state)
end

function Core:EndCategory(unit, category, exactResetAt, observedEnd)
    local state = self:GetUnitState(unit, false)
    if not state then return end
    local entry = state.categories[category]
    if not entry or entry.source == "Blizzard" then return end
    for _, aura in pairs(state.auras) do
        if aura.category == category then return end
    end
    entry.active = false
    entry.timerUnknown = entry.auraUncertain == true and not observedEnd and exactResetAt == nil
    entry.resetAt = exactResetAt or (now() + ns.db.profile.resetSeconds)
    entry.exact = exactResetAt ~= nil or entry.exact
    ns:Emit("STATE_CHANGED", unit, state)
end

function Core:CastSent(unit, castGUID)
    if read(unit) ~= "player" or type(read(castGUID)) ~= "string" then return end
    for id, cast in pairs(self.sentCasts) do
        if now() - cast.at > 10 then self.sentCasts[id] = nil end
    end
    self.sentCasts[castGUID] = { key = self:GetUnitKey("target"), at = now() }
end

function Core:CastSucceeded(unit, castGUID, spellID)
    if read(unit) ~= "player" or not ns:IsFinite(spellID) or not ns.DIRECT_CC[spellID]
        or type(read(castGUID)) ~= "string" then return end
    local cast = self.sentCasts[castGUID]
    self.sentCasts[castGUID] = nil
    if not cast or not cast.key or now() - cast.at > 10 then return end
    self.pendingCasts[#self.pendingCasts + 1] = {
        key = cast.key, spellID = spellID, category = ns:GetSpellCategory(spellID), at = now(),
    }
    if #self.pendingCasts > 32 then table.remove(self.pendingCasts, 1) end
end

function Core:ConfirmOpaqueCast(unit)
    local key, match = self:GetUnitKey(unit), nil
    if not key then return false end
    for _, cast in ipairs(self.pendingCasts) do
        if not cast.done and cast.key == key and now() - cast.at <= 1.5 then
            if match then return false end -- Ambiguous evidence cannot identify a spell.
            match = cast
        end
    end
    if not match then return false end
    match.done = true
    local state = self:GetUnitState(unit, true)
    local entry = state.categories[match.category]
    if entry and entry.updatedAt and entry.updatedAt >= match.at - 1 then return true end
    self:Record(unit, match.category, match.spellID, "Cast+native", false)
    entry = state.categories[match.category]
    if entry and entry.source == "Cast+native" then
        -- Correlation is estimated evidence, never a readable landing or timer.
        entry.active, entry.timerUnknown, entry.countUnknown = false, true, true
        entry.resetAt = now() + ns.db.profile.resetSeconds
        ns:Emit("STATE_CHANGED", unit, state)
    end
    return true
end

function Core:ApplyNative(unit, trackerInfo)
    if not ns.db.profile.nativeFeed then return false end
    if ns:IsSecret(unit) or ns:IsSecret(trackerInfo) then
        self.diagnostics.nativeRestricted = self.diagnostics.nativeRestricted + 1
        if not ns:IsSecret(unit) then return self:ConfirmOpaqueCast(unit) end
        return false
    end
    if type(trackerInfo) ~= "table" then return false end
    local category = read(trackerInfo.category)
    local startTime = read(trackerInfo.startTime)
    local duration = read(trackerInfo.duration)
    local isImmune = read(trackerInfo.isImmune)
    local showCountdown = read(trackerInfo.showCountdown)
    if not ns:IsFinite(category) or not ns.CATEGORIES[category] then
        if ns:IsSecret(trackerInfo.category) then
            self.diagnostics.nativeRestricted = self.diagnostics.nativeRestricted + 1
            return self:ConfirmOpaqueCast(unit)
        end
        return false
    end

    -- The timer can still be shown when only immunity is restricted.
    local immunityRestricted = ns:IsSecret(trackerInfo.isImmune)
    if immunityRestricted then
        self.diagnostics.nativeRestricted = self.diagnostics.nativeRestricted + 1
    end
    if not ns:IsFinite(startTime) or not ns:IsFinite(duration) or startTime < 0 or duration < 0
        or type(showCountdown) ~= "boolean" or (type(isImmune) ~= "boolean" and not immunityRestricted) then
        if ns:IsSecret(trackerInfo.startTime) or ns:IsSecret(trackerInfo.duration)
            or ns:IsSecret(trackerInfo.showCountdown) then
            self.diagnostics.nativeRestricted = self.diagnostics.nativeRestricted + 1
        end
        -- Only restricted timing permits this fallback; malformed public data does not.
        if (ns:IsSecret(trackerInfo.startTime) or ns:IsSecret(trackerInfo.duration))
            and type(showCountdown) == "boolean" then
            local state = self:GetUnitState(unit, true)
            if not state then return false end
            local entry = state.categories[category]
            local timestamp = now()
            -- Keep an authoritative running timer when a poorer update arrives.
            if entry and entry.source == "Blizzard" and not entry.nativePartial
                and entry.resetAt and entry.resetAt > timestamp then return true end
            if entry and entry.resetAt and entry.resetAt <= timestamp then entry = nil end
            if not entry then
                entry = { countUnknown = true }
                state.categories[category] = entry
            end
            local duplicate = entry.nativePartial and entry.active == (not showCountdown)
            entry.source, entry.nativePartial, entry.exact = "Blizzard", true, false
            entry.nativeStart, entry.nativeDuration = nil, nil
            entry.updatedAt = timestamp
            entry.active = not showCountdown
            if showCountdown then
                if not duplicate then entry.resetAt = timestamp + ns.db.profile.resetSeconds end
                entry.auraUncertain, entry.uncertainUntil, entry.timerUnknown = nil, nil, nil
            else
                entry.resetAt = nil
                entry.auraUncertain, entry.timerUnknown = true, true
                entry.uncertainUntil = entry.uncertainUntil or (timestamp + ns.db.profile.resetSeconds)
            end
            if isImmune == true then
                entry.applications, entry.countUnknown = ns.db.profile.applicationsToImmune, nil
            elseif isImmune == false then
                entry.applications, entry.countUnknown = nil, true
            end
            ns:Emit("STATE_CHANGED", unit, state)
            self.diagnostics.nativeApplied = self.diagnostics.nativeApplied + 1
            return true
        end
        return false
    end
    local state = self:GetUnitState(unit, true)
    if not state then return false end
    local entry = state.categories[category]
    if entry and entry.nativeStart and startTime < entry.nativeStart then return false end
    if duration and duration <= 0 then
        state.categories[category] = nil
        ns:Emit("STATE_CHANGED", unit, state)
        self.diagnostics.nativeApplied = self.diagnostics.nativeApplied + 1
        return true
    end
    if showCountdown and startTime + duration <= now() then return false end
    local duplicate = entry and entry.source == "Blizzard"
        and entry.nativeStart == startTime and entry.nativeDuration == duration
        and entry.active == (not showCountdown) and entry.isImmune == isImmune
    if duplicate then return true end
    local hadEntry = entry ~= nil and (entry.active or (entry.resetAt and entry.resetAt > now()))
    entry = entry or {}
    state.categories[category] = entry
    entry.source = "Blizzard"
    entry.nativePartial = nil
    entry.auraUncertain, entry.countUnknown, entry.uncertainUntil, entry.timerUnknown = nil, nil, nil, nil
    entry.exact = not immunityRestricted
    entry.active = not showCountdown
    entry.updatedAt = now()
    entry.nativeStart = startTime
    entry.nativeDuration = duration
    entry.isImmune = isImmune
    -- The native payload reports immunity, not the number of applications.
    entry.applications = isImmune == true and ns.db.profile.applicationsToImmune or nil
    entry.resetAt = showCountdown and (startTime + duration) or nil
    if not hadEntry then
        self:AddHistory(unit, category, entry.applications, "Blizzard", nil)
    end
    ns:Emit("STATE_CHANGED", unit, state)
    self.diagnostics.nativeApplied = self.diagnostics.nativeApplied + 1
    return true
end

function Core:ScanAuras(unit, updateInfo)
    if not C_UnitAuras or not (C_UnitAuras.GetUnitAuraBySpellID or C_UnitAuras.GetAuraDataByIndex) then return end
    local state = self:GetUnitState(unit, true)
    if not state then return end
    if UnitIsDeadOrGhost and read(UnitIsDeadOrGhost(unit)) == true then
        state.categories, state.auras = {}, {}
        ns:Emit("STATE_CHANGED", unit, state)
        return
    end
    local current, removed, observed, absentSpells = {}, {}, {}, {}
    local incomplete = false
    local function collect(aura, fromEvent, queriedSpellID)
        if ns:IsSecret(aura) or type(aura) ~= "table" then
            incomplete = true
            self.diagnostics.auraUnreadable = self.diagnostics.auraUnreadable + 1
            return
        end
        -- UNIT_AURA payloads also include buffs; indexed scans are HARMFUL only.
        if fromEvent and read(aura.isHarmful) ~= true then return end
        local instanceID = read(aura.auraInstanceID)
        local spellID = queriedSpellID or read(aura.spellId)
        if not ns:IsFinite(spellID) then
            incomplete = true
            self.diagnostics.auraUnreadable = self.diagnostics.auraUnreadable + 1
            return
        end
        local category = ns:GetSpellCategory(spellID)
        if category ~= nil then
            local key = ns:IsFinite(instanceID) and instanceID or ("spell:" .. spellID)
            if type(key) == "number" then current["spell:" .. spellID] = nil end
            local expiration = read(aura.expirationTime)
            local duration = read(aura.duration)
            local appliedAt
            if ns:IsFinite(expiration) and ns:IsFinite(duration) and expiration > 0 and duration > 0 then
                appliedAt = expiration - duration
            end
            current[key] = { category = category, spellID = spellID, appliedAt = appliedAt }
            observed[category] = true
            self.diagnostics.auraReadable = self.diagnostics.auraReadable + 1
            if fromEvent then self.diagnostics.auraPayloads = self.diagnostics.auraPayloads + 1 end
        elseif ns.db.profile.discovery then
            ns:Emit("DISCOVERY", spellID, read(aura.name))
        end
    end

    local readableSpells
    if C_UnitAuras.GetUnitAuraBySpellID then
        readableSpells = self:GetReadableAuraSpells()
        for _, spellID in ipairs(readableSpells.list) do
            local ok, aura = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, spellID)
            if not ok then
                incomplete = true
                self:AuraError(unit, "GetUnitAuraBySpellID", aura)
                state.retryAuraAt = now() + 1
                break
            end
            if ns:IsSecret(aura) then
                incomplete = true
                self.diagnostics.auraUnreadable = self.diagnostics.auraUnreadable + 1
            elseif type(aura) == "table" then
                collect(aura, false, spellID)
            elseif aura == nil then
                absentSpells[spellID] = true
            end
        end
        -- An aura that became secret is unknown, not evidence that it ended.
        for _, aura in pairs(state.auras) do
            if not readableSpells.set[aura.spellID] then incomplete = true end
        end
    else
        -- Compatibility fallback for clients without the per-spell API.
        for index = 1, 255 do
            if restrictedIndex(unit, index) then
                incomplete = true
                self.diagnostics.auraSkipped = self.diagnostics.auraSkipped + 1
            else
                local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HARMFUL")
                if not ok then
                    incomplete = true
                    self:AuraError(unit, "GetAuraDataByIndex", aura)
                    state.retryAuraAt = now() + 1
                    break
                end
                if not ns:IsSecret(aura) and aura == nil then break end
                if index == 255 then
                    current, observed, incomplete = {}, {}, true
                    break
                end
                collect(aura, false)
            end
        end
    end

    -- Use readable event data immediately, even if indexed enumeration is partial.
    if not ns:IsSecret(updateInfo) and type(updateInfo) == "table" then
        local added = read(updateInfo.addedAuras)
        if type(added) == "table" then
            for _, aura in ipairs(added) do collect(aura, true) end
        end
        local updated = read(updateInfo.updatedAuraInstanceIDs)
        if type(updated) == "table" and C_UnitAuras.GetAuraDataByAuraInstanceID then
            for _, id in ipairs(updated) do
                if ns:IsFinite(id) then
                    local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, id)
                    if ok and not ns:IsSecret(aura) and type(aura) == "table" then
                        collect(aura, true)
                    elseif not ok then
                        self:AuraError(unit, "GetAuraDataByAuraInstanceID", aura)
                    end
                end
            end
        end
        local deleted = read(updateInfo.removedAuraInstanceIDs)
        if type(deleted) == "table" then
            for _, id in ipairs(deleted) do
                if ns:IsFinite(id) then removed[id] = true; current[id] = nil end
            end
        end
    end

    state.auraRestricted = incomplete or nil
    if incomplete then self.diagnostics.auraRestricted = self.diagnostics.auraRestricted + 1 end
    local previousAuras = state.auras
    -- Losing/gaining a readable instance ID does not create a new application.
    -- Only merge when one side lacks an ID, never merge two distinct readable IDs.
    for id, aura in pairs(current) do
        if not previousAuras[id] then
            local match, matches
            matches = 0
            for oldID, previous in pairs(previousAuras) do
                if previous.spellID == aura.spellID and previous.category == aura.category
                    and not removed[oldID] and not current[oldID]
                    and (type(id) == "string" or type(oldID) == "string") then
                    match, matches = oldID, matches + 1
                end
            end
            if matches == 1 then
                previousAuras[id], previousAuras[match] = previousAuras[match], nil
            end
        end
    end
    local seen = {}
    observed = {}
    for id, aura in pairs(current) do
        seen[id] = true
        observed[aura.category] = true
    end
    if incomplete then
        -- Keep identities for deduplication; never interpret missing secret data as removal.
        for id, aura in pairs(previousAuras) do
            if not current[id] and not removed[id] and not absentSpells[aura.spellID] then current[id] = aura end
        end
    end
    state.auras = current
    for instanceID, aura in pairs(current) do
        if seen[instanceID] then
            local previous = previousAuras[instanceID]
            -- Timing edits alone cannot prove another CC application.
            local refreshed = previous and previous.appliedAt and aura.appliedAt
                and aura.appliedAt > previous.appliedAt + 0.05
            local entry = state.categories[aura.category]
            if not previous or previous.category ~= aura.category or previous.spellID ~= aura.spellID
                or not entry or (not entry.active and entry.resetAt and entry.resetAt <= now()) then
                self:Record(unit, aura.category, aura.spellID, "Aura", false)
            end
            entry = state.categories[aura.category]
            if refreshed and entry and entry.source ~= "Blizzard" then entry.countUnknown = true end
        end
    end
    local ended, observedEnds = {}, {}
    for instanceID, previous in pairs(previousAuras) do
        if not current[instanceID] or current[instanceID].category ~= previous.category then
            ended[previous.category] = true
            if removed[instanceID] or absentSpells[previous.spellID] then observedEnds[previous.category] = true end
        end
    end
    for category in pairs(ended) do
        self:EndCategory(unit, category, nil, observedEnds[category])
        local entry = state.categories[category]
        if entry and not entry.active then observed[category] = true end
    end
    for category, entry in pairs(state.categories) do
        if entry.source ~= "Blizzard" then
            entry.auraUncertain = incomplete and not observed[category] or nil
            if entry.auraUncertain then
                entry.countUnknown = true
                -- Retain a bounded, explicitly unknown indication, not a false active CC.
                entry.uncertainUntil = entry.uncertainUntil or (now() + ns.db.profile.resetSeconds)
            else
                entry.uncertainUntil = nil
            end
        end
    end
    ns:Emit("STATE_CHANGED", unit, state)
end

function Core:AddHistory(unit, category, applications, source, spellID)
    local name = read(UnitName(unit)) or unit or "?"
    table.insert(self.history, 1, {
        time = date("%H:%M:%S"),
        name = name,
        category = category,
        applications = applications,
        source = source,
        spellID = spellID,
    })
    while #self.history > ns.db.profile.historySize do
        table.remove(self.history)
    end
    ns:Emit("HISTORY_CHANGED")
end

function Core:GetDisplayState(unit)
    if self.preview then return self.previewState end
    return self:GetUnitState(unit, false)
end

function Core:ResetTracking()
    self.units, self.unitKeys = {}, {}
    self.pendingCasts, self.sentCasts = {}, {}
    self.nextAuraScan = nil
    self.readableAuraSpells, self.readableAuraSpellsAt = nil, nil
    self:ScanAuras("target")
    self:ScanAuras("focus")
    for unit in pairs(self.visibleUnits) do self:ScanAuras(unit) end
    ns:Emit("STATE_CHANGED")
end

function Core:PollVisibleAuras()
    local timestamp = now()
    if self.nextAuraScan and timestamp < self.nextAuraScan then return end
    self.nextAuraScan = timestamp + 0.25
    -- A plate may become attackable after it was added (e.g. a duel starts).
    -- Read it even without an existing DR state or a UNIT_AURA notification.
    local scanned = {}
    local function scan(unit)
        local state = self:GetUnitState(unit, true)
        if state and not scanned[state.key] then
            if state.retryAuraAt and timestamp < state.retryAuraAt then return end
            self:ScanAuras(unit)
            if not state.auraRestricted then scanned[state.key] = true end
        end
    end
    scan("target")
    scan("focus")
    for unit in pairs(self.visibleUnits) do scan(unit) end
end

function Core:ResetProfile()
    ns.db.profile = ns:Copy(ns.DEFAULTS.profile)
    self:SetNativeFeed(ns.db.profile.nativeFeed)
    self:ResetTracking()
    ns.UI:RestoreAnchors()
    ns.UI:SetLocked(true)
    if ns.Minimap then ns.Minimap:Refresh() end
    if ns.Options.frame then ns.Options.frame:Refresh() end
end

function Core:CleanExpired()
    local timestamp = now()
    for i = #self.pendingCasts, 1, -1 do
        if self.pendingCasts[i].done or timestamp - self.pendingCasts[i].at > 1.5 then
            table.remove(self.pendingCasts, i)
        end
    end
    for key, state in pairs(self.units) do
        local hasState = false
        for category, entry in pairs(state.categories) do
            if (entry.auraUncertain and entry.uncertainUntil and entry.uncertainUntil <= timestamp)
                or (not entry.active and entry.resetAt and entry.resetAt <= timestamp) then
                state.categories[category] = nil
                for id, aura in pairs(state.auras) do
                    if aura.category == category then state.auras[id] = nil end
                end
            else
                hasState = true
            end
        end
        if not hasState and timestamp - state.lastSeen > 30 then
            self.units[key] = nil
        end
    end
    ns:Emit("TICK", timestamp)
end

function Core:SetPreview(enabled)
    self.preview = enabled
    if enabled then
        local timestamp = now()
        self.previewState = { categories = {
            [2] = { applications = 1, resetAt = timestamp + 15.4, source = "Preview", exact = true },
            [4] = { applications = 2, resetAt = timestamp + 10.2, source = "Preview", exact = false },
            [5] = { applications = 3, resetAt = timestamp + 6.8, source = "Preview", exact = true },
        }}
    end
    ns:Emit("PREVIEW_CHANGED", enabled)
end

function Core:Initialize()
    self:SetNativeFeed(ns.db.profile.nativeFeed)
    self:WatchUnit("target")
    self:WatchUnit("focus")
    if self.ticker then self.ticker:Cancel() end
    self.ticker = C_Timer.NewTicker(0.1, function()
        self:PollVisibleAuras()
        self:CleanExpired()
    end)
end

function Core:EnsureNativeFeed()
    if InCombatLockdown and InCombatLockdown() then return end
    if ns.db.profile.nativeFeed and self.nativeEventRegistered and C_SpellDiminish and C_SpellDiminish.IsSystemSupported
        and C_CVar and C_CVar.SetCVar then
        local ok, supported = pcall(C_SpellDiminish.IsSystemSupported)
        if ok and read(supported) == true then
            if C_CVar.GetCVar then
                local got, value = pcall(C_CVar.GetCVar, "spellDiminishPVPEnemiesEnabled")
                if got and read(value) == "1" then return end
            end
            local written, result = pcall(C_CVar.SetCVar, "spellDiminishPVPEnemiesEnabled", "1")
            self.diagnostics.nativeEnableFailed = not written or read(result) == false
        end
    end
end

function Core:SetNativeFeed(enabled)
    ns.db.profile.nativeFeed = enabled
    self:EnsureNativeFeed()
    if enabled then return end
    for _, state in pairs(self.units) do
        for category, entry in pairs(state.categories) do
            if entry.source == "Blizzard" then
                state.categories[category] = nil
                for instanceID, aura in pairs(state.auras) do
                    if aura.category == category then state.auras[instanceID] = nil end
                end
            end
        end
    end
    local units = {}
    for unit in pairs(self.unitKeys) do units[#units + 1] = unit end
    for _, unit in ipairs(units) do self:ScanAuras(unit) end
end

local events = ns.events
Core.watchers = {}
Core.unitEventsSupported = type(events.RegisterUnitEvent) == "function"

local nativeEventValid = true
if C_EventUtils and C_EventUtils.IsEventValid then
    local ok, valid = pcall(C_EventUtils.IsEventValid, "UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED")
    nativeEventValid = ok and valid == true
end
Core.nativeEventRegistered = nativeEventValid

function Core:WatchUnit(unit)
    if not self.unitEventsSupported or self.watchers[unit] then return end
    local watcher = CreateFrame("Frame")
    watcher.unit = unit
    watcher:SetScript("OnEvent", function(frame, event, _, updateInfo)
        if not ns.db then return end
        if event == "UNIT_AURA" then
            Core.diagnostics.auraEvents = Core.diagnostics.auraEvents + 1
            Core:ScanAuras(frame.unit, updateInfo)
        elseif event == "UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED" then
            Core.diagnostics.nativeEvents = Core.diagnostics.nativeEvents + 1
            Core:ApplyNative(frame.unit, updateInfo)
        end
    end)
    pcall(watcher.RegisterUnitEvent, watcher, "UNIT_AURA", unit)
    if self.nativeEventRegistered then
        pcall(watcher.RegisterUnitEvent, watcher, "UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", unit)
    end
    self.watchers[unit] = watcher
end

function Core:UnwatchUnit(unit)
    local watcher = self.watchers[unit]
    if not watcher then return end
    if watcher.UnregisterAllEvents then watcher:UnregisterAllEvents() end
    self.watchers[unit] = nil
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PLAYER_FOCUS_CHANGED")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
for _, event in ipairs({ "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_REGEN_ENABLED", "CVAR_UPDATE" }) do
    pcall(events.RegisterEvent, events, event)
end
if not Core.unitEventsSupported then
    events:RegisterEvent("UNIT_AURA")
    Core.nativeEventRegistered = nativeEventValid
        and pcall(events.RegisterEvent, events, "UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED")
end

events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= ns.addonName then return end
        local legacyDB = type(DRiftDB) == "table" and DRiftDB or nil
        DrpulseDB = type(DrpulseDB) == "table" and DrpulseDB or legacyDB or {}
        DRiftDB = nil
        ns:ValidateDB(DrpulseDB)
        ns.db = DrpulseDB
        ns:Emit("DB_READY")
    elseif not ns.db then
        return
    elseif event == "UNIT_SPELLCAST_SENT" then
        local unit, _, castGUID = ...
        Core:CastSent(unit, castGUID)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        Core:CastSucceeded(...)
    elseif event == "PLAYER_REGEN_ENABLED" then
        Core.readableAuraSpells = nil
        Core:EnsureNativeFeed()
    elseif event == "CVAR_UPDATE" then
        local name = read((...))
        if type(name) == "string" and name:lower() == "spelldiminishpvpenemiesenabled"
            and C_Timer and C_Timer.After and not Core.nativeEnableQueued then
            Core.nativeEnableQueued = true
            C_Timer.After(0.2, function()
                Core.nativeEnableQueued = nil
                Core:EnsureNativeFeed()
            end)
        end
    elseif event == "PLAYER_LOGIN" then
        Core:Initialize()
        ns:Emit("READY")
        ns:Print(("|cff8b929ev%s|r  |cff92e6bbReady to track DR|r  |cff8b929e•|r  Type |cff61dafb/drpulse|r for settings."):format(ns.version))
    elseif event == "PLAYER_ENTERING_WORLD" then
        for unit in pairs(Core.visibleUnits) do
            Core:UnwatchUnit(unit)
            ns:Emit("NAMEPLATE_REMOVED", unit)
        end
        Core.visibleUnits = {}
        if C_NamePlate and C_NamePlate.GetNamePlates then
            for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
                local unit = read(plate.namePlateUnitToken) or read(plate.unitToken)
                if type(unit) == "string" then
                    Core.visibleUnits[unit] = true
                    Core:WatchUnit(unit)
                end
            end
        end
        Core:ResetTracking()
    elseif event == "PLAYER_TARGET_CHANGED" then
        if Core.unitKeys.target == "unit:target" then Core:ReleaseUnit("target") end
        Core:ScanAuras("target")
        ns:Emit("UNIT_CHANGED", "target")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        if Core.unitKeys.focus == "unit:focus" then Core:ReleaseUnit("focus") end
        Core:ScanAuras("focus")
        ns:Emit("UNIT_CHANGED", "focus")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        if ns:IsSecret(unit) or type(unit) ~= "string" then return end
        Core:ReleaseUnit(unit)
        Core.visibleUnits[unit] = true
        Core:WatchUnit(unit)
        Core:ScanAuras(unit)
        ns:Emit("NAMEPLATE_ADDED", unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        if ns:IsSecret(unit) or type(unit) ~= "string" then return end
        Core:UnwatchUnit(unit)
        Core:ReleaseUnit(unit)
        Core.visibleUnits[unit] = nil
        ns:Emit("NAMEPLATE_REMOVED", unit)
    elseif event == "UNIT_AURA" then
        local unit, updateInfo = ...
        if ns:IsSecret(unit) or type(unit) ~= "string" then return end
        if unit == "target" or unit == "focus" or Core.visibleUnits[unit] then
            Core.diagnostics.auraEvents = Core.diagnostics.auraEvents + 1
            Core:ScanAuras(unit, updateInfo)
        end
    elseif event == "UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED" then
        Core.diagnostics.nativeEvents = Core.diagnostics.nativeEvents + 1
        local unit = ...
        if ns:IsSecret(unit) then
            Core.diagnostics.nativeRestricted = Core.diagnostics.nativeRestricted + 1
            return
        end
        if type(unit) ~= "string" then return end
        if unit == "target" or unit == "focus" or Core.visibleUnits[unit] then
            Core:ApplyNative(...)
        else
            -- Native events may use arena tokens for an observed target/focus.
            local key = Core:GetUnitKey(unit)
            if not key then return end
            local _, trackerInfo = ...
            for observedUnit, observedKey in pairs(Core.unitKeys) do
                if observedKey == key and Core:GetUnitKey(observedUnit) == key then
                    Core:ApplyNative(observedUnit, trackerInfo)
                    break
                end
            end
        end
    end
end)

