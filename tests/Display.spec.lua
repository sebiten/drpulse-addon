-- Display regression checks with instrumented WoW frame calls.
-- Optional first argument: a previous release's Display.lua for comparison.
local function suite(path, optimized)
    local calls = 0
    local methods = {}
    local function frame()
        return setmetatable({ shown = true, counts = {} }, { __index = methods })
    end
    local function record(self, name, ...)
        calls = calls + 1
        self.counts[name] = (self.counts[name] or 0) + 1
        self[name .. "Args"] = { ... }
    end
    for _, name in ipairs({ "SetPoint", "ClearAllPoints", "SetSize", "SetHeight", "SetAllPoints",
        "SetColorTexture", "SetTexCoord", "SetHideCountdownNumbers", "SetDrawEdge", "SetReverse",
        "SetSwipeColor", "SetFrameLevel", "SetShadowColor", "SetShadowOffset", "EnableMouse",
        "SetMouseClickEnabled", "SetScript", "SetTexture", "SetVertexColor", "SetDesaturated",
        "SetText", "SetTextColor", "SetCooldown", "Clear", "Pause", "Resume", "SetVertexColorFromBoolean" }) do
        methods[name] = function(self, ...) record(self, name, ...) end
    end
    function methods:CreateTexture() return frame() end
    function methods:CreateFontString() return frame() end
    function methods:GetFrameLevel() return 1 end
    function methods:GetFont() return self.font or "default.ttf" end
    function methods:SetFont(font, size, flags)
        record(self, "SetFont", font, size, flags); self.font = font; return true
    end
    function methods:SetShown(value) record(self, "SetShown", value); self.shown = value end
    function methods:Show() record(self, "Show"); self.shown = true end
    function methods:Hide() record(self, "Hide"); self.shown = false end
    CreateFrame = frame
    local ns = {}
    assert(loadfile("Drpulse/Runtime/State.lua"))("Drpulse", ns)
    ns.db = ns.LoadSettings(nil)
    ns.SpellIcon = function(id) return id end
    ns.CategoryIcon = function() return 999 end
    ns.secretImmune = {}
    assert(loadfile(path))("Drpulse", ns)
    -- StartDisplay normally creates these WoW Color objects. Seed only that
    -- dependency so the renderer can be exercised without the target window.
    for index = 1, 30 do
        local name, update = debug.getupvalue(ns.LayoutRow, index)
        if name == "UpdateIcon" then
            for slot = 1, 30 do
                local key = debug.getupvalue(update, slot)
                if key == "stageColors" then debug.setupvalue(update, slot, { {}, {}, {} }) end
                if key == "redColor" then debug.setupvalue(update, slot, {}) end
            end
        end
    end
    local row, plate = frame(), frame()
    local e = { category = "Stun", spellID = 853, count = 1, immune = false,
        estimated = false, remaining = 18, active = false, windowStart = 100, windowLength = 18, resetAt = 118 }
    local function draw(size) ns.LayoutRow(row, { e }, size or 30, nil, false) end
    draw()
    ns.PlaceRow(row, plate)
    local initial = calls
    for tick = 1, 100 do
        e.remaining = 18 - tick * 0.01
        draw()
        ns.PlaceRow(row, plate)
    end
    local steady = calls - initial
    local icon = row.icons[1]
    assert(icon.time.SetTextArgs[1] == "17")
    assert(icon.next.SetTextArgs[1] == "50%" and icon.pips[1].shown and not icon.pips[2].shown)
    if optimized then
        assert(icon.texture.counts.SetTexture == 1, "unchanged texture must not be reassigned")
        assert(icon.counts.ClearAllPoints == 1, "unchanged icon must not be reanchored")
        assert(row.counts.ClearAllPoints == 1, "unchanged plate must not be reanchored")
    end
    ns.db.stackStyle, e.count, e.immune = "number", 3, true
    draw()
    assert(icon.count.shown and icon.count.SetTextArgs[1] == "!")
    assert(not icon.pips[1].shown and icon.texture.SetDesaturatedArgs[1])
    ns.db.stackStyle, e.estimated, e.immune, e.count = "next", true, false, 2
    e.remaining = 3.2
    draw()
    assert(icon.next.shown and icon.next.SetTextArgs[1] == "25%")
    assert(icon.time.SetTextArgs[1] == "~3.2")
    ns.db.timer, ns.db.swipe = false, false
    draw()
    assert(not icon.time.shown and icon.swipeStart == nil)
    ns.db.timer, ns.db.swipe, ns.db.font = true, true, "arial"
    draw(40)
    assert(icon.time.shown and icon.time.font == ns.FONT_PATHS.arial and icon.swipeStart == 100)
    assert(icon.SetSizeArgs[1] == 40)
    ns.LayoutRow(row, nil, 40, nil, false)
    assert(not icon.shown and icon.entry == nil)
    e.spellID, e.estimated, e.count = 118, false, 1
    draw(40)
    assert(icon.shown and icon.texture.SetTextureArgs[1] == 118 and icon.next.SetTextArgs[1] == "50%")
    ns.LayoutRow(row, { e, e, e }, 40, nil, false)
    local second, third = row.icons[2], row.icons[3]
    draw(40)
    assert(not second.shown and not third.shown and second.entry == nil)
    ns.LayoutRow(row, { e, e, e }, 24, nil, false)
    assert(row.icons[2] == second and row.icons[3] == third and second.shown and third.shown)
    assert(second.SetPointArgs[4] == 29 and third.SetPointArgs[4] == 58)
    ns.db.plateAnchor, ns.db.plateX, ns.db.plateY = "BOTTOM", 28, -16
    ns.PlaceRow(row, plate)
    assert(row.SetPointArgs[1] == "TOP" and row.SetPointArgs[4] == 28 and row.SetPointArgs[5] == -20)
    local replacement = frame()
    ns.PlaceRow(row, replacement)
    assert(row.SetPointArgs[2] == replacement)
    -- Secret values stay at the display sink, then the public color is restored.
    ns.secretImmune["enemy:Stun"] = { resetAt = 118, box = { value = {} } }
    ns.LayoutRow(row, { e }, 40, "enemy", false)
    local before = icon.border.counts.SetVertexColor or 0
    ns.secretImmune = {}
    draw(40)
    assert(icon.border.counts.SetVertexColor == before + 1)
    ns.LayoutRow(row, { e }, 40, nil, false, true)
    assert(icon.cooldown.counts.Pause == 1)
    draw(40)
    assert(icon.cooldown.counts.Resume == 1)
    if optimized then
        ns.db.plateTimer, ns.db.plateSwipe, ns.db.plateFont = false, false, "skurri"
        ns.db.plateStackStyle, ns.db.plateIconSource = "number", "category"
        local plateIcons = frame()
        ns.LayoutRow(plateIcons, { e }, 20, nil, false, false, "nameplates")
        local plateIcon = plateIcons.icons[1]
        assert(not plateIcon.time.shown and plateIcon.swipeStart == nil)
        assert(plateIcon.count.shown and plateIcon.time.font == ns.FONT_PATHS.skurri)
        assert(plateIcon.texture.SetTextureArgs[1] == 999)
        draw(40)
        assert(icon.time.shown and icon.time.font == ns.FONT_PATHS.arial and icon.next.shown)
        ns.ResetDisplaySettings()
        assert(ns.db.plateTimer and ns.db.plateSwipe and ns.db.plateFont == "default")
        local migrated = assert(ns.LoadSettings({ schema = 1, font = "arial", timer = false, swipe = false, stackStyle = "next" }))
        assert(migrated.plateFont == "arial" and not migrated.plateTimer and not migrated.plateSwipe and migrated.plateStackStyle == "next")
    end
    print("PASS display transitions, pooling, fonts, offsets, secret border and preview: " .. path)
    return steady
end
local current = suite("Drpulse/Runtime/Display.lua", true)
if arg[1] then
    local previous = suite(arg[1], false)
    assert(current < previous)
    print(string.format("100 timer ticks: %d -> %d mocked UI mutations (%.1f%% fewer)", previous, current, 100 * (1 - current / previous)))
end
