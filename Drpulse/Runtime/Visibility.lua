local _, ns = ...
local inCombat, inPvP = false, false

function ns.RefreshVisibilityContext()
    local combat = InCombatLockdown()
    inCombat = ns.Bool(combat) and combat or false
    local inside, kind = IsInInstance()
    inPvP = ns.Bool(inside) and inside and ns.Text(kind) and (kind == "pvp" or kind == "arena") or false
    ns.RequestRefresh()
end

function ns.VisibilityAllowed()
    return (not ns.db.combatOnly or inCombat) and (not ns.db.pvpOnly or inPvP)
end

function ns.NameplateAllowed(unit)
    if not ns.db.plateTargetOnly then return true end
    local same = UnitIsUnit(unit, "target")
    return ns.Bool(same) and same == true
end

function ns.StartVisibility()
    ns.RefreshVisibilityContext()
    local frame = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED" }) do
        if C_EventUtils.IsEventValid(event) then frame:RegisterEvent(event) end
    end
    frame:SetScript("OnEvent", function(_, event)
        -- Combat events are authoritative, including the transition frame.
        if event == "PLAYER_REGEN_DISABLED" then inCombat = true; ns.RequestRefresh()
        elseif event == "PLAYER_REGEN_ENABLED" then inCombat = false; ns.RequestRefresh()
        elseif event == "PLAYER_TARGET_CHANGED" then ns.RequestRefresh()
        else ns.RefreshVisibilityContext() end
    end)
end
