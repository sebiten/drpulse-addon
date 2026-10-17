local addonName, ns = ...

ns.addonName = addonName
ns.version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version") or "1.0.9"
ns.prefix = "|cff61dafbDrpulse|r"
ns.events = CreateFrame("Frame")
ns.callbacks = {}

function ns:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(('%s  %s'):format(self.prefix, tostring(message)))
end

function ns:IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

function ns:Readable(value)
    if self:IsSecret(value) or value == nil then
        return nil
    end
    return value
end

function ns:On(name, callback)
    self.callbacks[name] = self.callbacks[name] or {}
    self.callbacks[name][#self.callbacks[name] + 1] = callback
end

function ns:Emit(name, ...)
    local callbacks = self.callbacks[name]
    if not callbacks then return end
    for index = 1, #callbacks do
        callbacks[index](...)
    end
end

function ns:Copy(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = type(value) == "table" and self:Copy(value) or value
    end
    return result
end

function ns:MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(target[key]) ~= type(value) then
            target[key] = type(value) == "table" and self:Copy(value) or value
        elseif type(value) == "table" and type(target[key]) == "table" then
            self:MergeDefaults(target[key], value)
        end
    end
end

function ns:IsFinite(value)
    return not self:IsSecret(value) and type(value) == "number"
        and value == value and value > -math.huge and value < math.huge
end

function ns:ValidateDB(db)
    self:MergeDefaults(db, self.DEFAULTS)
    local profile = db.profile
    local limits = { resetSeconds = { 15, 22 }, iconSize = { 24, 56 },
        iconSpacing = { 0, 20 }, historySize = { 1, 200 } }
    for key, range in pairs(limits) do
        local value = profile[key]
        profile[key] = self:IsFinite(value) and math.floor(math.max(range[1], math.min(range[2], value)))
            or self.DEFAULTS.profile[key]
    end
    -- The displayed 50/25/IMM progression only supports three applications.
    profile.applicationsToImmune = 3
    profile.minimap.angle = self:IsFinite(profile.minimap.angle) and (profile.minimap.angle % 360) or 225
    local points = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true,
        CENTER = true, RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }
    for key, anchor in pairs(profile.anchors) do
        if self.DEFAULTS.profile.anchors[key] then
            if not points[anchor.point] or not points[anchor.relativePoint]
                or not self:IsFinite(anchor.x) or not self:IsFinite(anchor.y) then
                profile.anchors[key] = self:Copy(self.DEFAULTS.profile.anchors[key])
            end
        end
    end
    for spellID, category in pairs(profile.customSpells) do
        if not self:IsFinite(spellID) or spellID <= 0 or spellID % 1 ~= 0
            or not self:IsFinite(category) or not self.CATEGORIES[category] then
            profile.customSpells[spellID] = nil
        end
    end
end

