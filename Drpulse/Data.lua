local _, ns = ...

ns.CATEGORY = {
    ROOT = 0,
    TAUNT = 1,
    STUN = 2,
    KNOCKBACK = 3,
    INCAPACITATE = 4,
    DISORIENT = 5,
    SILENCE = 6,
    DISARM = 7,
}

ns.CATEGORY_ORDER = { 2, 4, 5, 0, 6, 7, 1, 3 }

ns.CATEGORIES = {
    [0] = { key = "root", label = "Root", short = "ROOT", icon = 135848, color = { 0.35, 0.72, 1.00 } },
    [1] = { key = "taunt", label = "Taunt", short = "TAUNT", icon = 132270, color = { 0.75, 0.55, 0.32 } },
    [2] = { key = "stun", label = "Stun", short = "STUN", icon = 135963, color = { 1.00, 0.72, 0.20 } },
    [3] = { key = "knockback", label = "Knockback", short = "PUSH", icon = 132154, color = { 0.55, 0.86, 0.92 } },
    [4] = { key = "incapacitate", label = "Incapacitate", short = "INCAP", icon = 136071, color = { 0.95, 0.55, 0.82 } },
    [5] = { key = "disorient", label = "Disorient", short = "FEAR", icon = 136183, color = { 0.64, 0.48, 0.95 } },
    [6] = { key = "silence", label = "Silence", short = "SIL", icon = 136164, color = { 0.42, 0.82, 0.88 } },
    [7] = { key = "disarm", label = "Disarm", short = "DISARM", icon = 132343, color = { 0.92, 0.42, 0.30 } },
}

-- Factual spell data for the level 60 ruleset. Not derived from Diminish code.
-- Unknown IDs can be added through SavedVariables without modifying the addon.
ns.SPELLS = {
    -- Stun
    [408] = 2, [8643] = 2, [853] = 2, [5588] = 2, [5589] = 2, [10308] = 2,
    [1833] = 2, [5211] = 2, [7922] = 2,
    [20549] = 2, [20253] = 2, [12355] = 2, [12798] = 2,
    [19410] = 2, [20170] = 2, [22570] = 2, [24394] = 2,
    -- Incapacitate
    [118] = 4, [12824] = 4, [12825] = 4, [12826] = 4,
    [6770] = 4, [1776] = 4, [20066] = 4, [3355] = 4, [14310] = 4, [14311] = 4,
    [2637] = 4, [1513] = 4, [19386] = 4, [28271] = 4, [28272] = 4,
    -- Disorient / fear
    [5782] = 5, [6213] = 5, [6215] = 5, [5484] = 5,
    [8122] = 5, [5246] = 5, [2094] = 5,
    [6789] = 5, [19503] = 5, [6358] = 5,
    -- Root
    [122] = 0, [865] = 0, [6131] = 0, [10230] = 0,
    [339] = 0, [1062] = 0, [5195] = 0, [5196] = 0, [9852] = 0, [9853] = 0,
    [19229] = 0, [23694] = 0,
    -- Silence
    [1330] = 6, [15487] = 6, [18469] = 6, [19647] = 6,
    -- Disarm
    [676] = 7, [14251] = 7,
    -- Taunt
    [355] = 1, [6795] = 1, [62124] = 1,
}

ns.DEFAULTS = {
    profile = {
        enabled = true,
        locked = true,
        minimap = { hide = false, angle = 225 },
        resetSeconds = 18,
        applicationsToImmune = 3,
        iconSize = 34,
        iconSpacing = 4,
        showText = true,
        showSwipe = true,
        showOnlyActive = true,
        surfaces = {
            target = true,
            focus = true,
            nameplates = true,
        },
        categories = {
            [0] = true, [1] = false, [2] = true, [3] = false,
            [4] = true, [5] = true, [6] = true, [7] = true,
        },
        anchors = {
            target = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -185 },
            focus = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -235 },
        },
        customSpells = {},
        historySize = 40,
        nativeFeed = true,
        discovery = false,
    },
}

function ns:GetCategoryInfo(category)
    local info = self.CATEGORIES[category]
    if not info then return nil end
    if not info.nativeLoaded and C_SpellDiminish and C_SpellDiminish.GetSpellDiminishCategoryInfo then
        local ok, native = pcall(C_SpellDiminish.GetSpellDiminishCategoryInfo, category)
        if ok and not self:IsSecret(native) and type(native) == "table" then
            info.nativeName = self:Readable(native.name)
            local icon = self:Readable(native.icon)
            if icon then
                info.icon = icon
            end
            info.nativeLoaded = true
        end
    end
    return info
end

function ns:GetSpellCategory(spellID)
    if not self:IsFinite(spellID) then return nil end
    local custom = self.db and self.db.profile.customSpells[spellID]
    return custom ~= nil and custom or self.SPELLS[spellID]
end

