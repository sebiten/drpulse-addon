import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const runtime = process.argv[2];
if (!runtime) throw new Error('Usage: node tests/NameplatePlacement.spec.mts fengari-module-path');
const require = createRequire(import.meta.url);
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(runtime);
const state = lauxlib.luaL_newstate();
lualib.luaL_openlibs(state);

// Reuse native-widget mocks and profile setup; exercise the real placement and preview code.
const setup = readFileSync('tests/SettingsFlow.spec.lua', 'utf8').replace('ns.BuildSettings()', `
function methods:SetPoint(...) self.point = { ... } end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetScale(scale) self.scale = scale end
function methods:ClearAllPoints() self.clears = (self.clears or 0) + 1 end
GetTime = function() return 100 end
assert(loadfile("Drpulse/Runtime/Display.lua"))("Drpulse", ns)
ns.LayoutRow = function() end
ns.SettingsSamples = function() return {} end
ns.PreviewKit = {
    Scale = function(width, scale, notes, room) return math.min(scale, room / width) end,
    New = function(frame, options)
        local preview = { holder = object(), text = object(), parts = {}, loops = {},
            top = 0, left = 0, width = options.width, Caption = object,
            SetLabel = function() end, Settle = function() end }
        preview.Fit = function(bottom) preview.bottom = bottom end
        return preview
    end,
}
ns.BuildSettings()
`);
const checks = `
local cases = {
    { "TOP", "BOTTOM", "TOP", 28, -12 },
    { "BOTTOM", "TOP", "BOTTOM", 28, -20 },
    { "LEFT", "RIGHT", "LEFT", 24, -16 },
    { "RIGHT", "LEFT", "RIGHT", 32, -16 },
}
local row, plate = object(), object()
for _, case in ipairs(cases) do
    assert(ns.Set("plateAnchor", case[1]))
    ns.db.plateX, ns.db.plateY, ns.db.plateOffset = 28, -16, 4
    ns.PlaceRow(row, plate)
    assert(row.point[1] == case[2] and row.point[2] == plate and row.point[3] == case[3])
    assert(row.point[4] == case[4] and row.point[5] == case[5])
    local clears = row.clears
    ns.PlaceRow(row, plate)
    assert(row.clears == clears, "Unchanged anchors must retain the placement cache")
    local saved = assert(ns.LoadSettings(ns.ProfileData(ns.db)))
    assert(saved.plateAnchor == case[1], "Position must survive reload")
    local decoded = assert(ns.DecodeProfile(assert(ns.ExportProfile())))
    assert(decoded.plateAnchor == case[1], "Position must survive profile sharing")
    -- Check bounds at default, extreme and overlapping offsets for both previews.
    for _, offsets in ipairs({ {0, 0, 4}, {-300, 300, 60}, {300, -300, -40} }) do
        ns.db.plateX, ns.db.plateY, ns.db.plateOffset = offsets[1], offsets[2], offsets[3]
        page.Refresh()
        for _, key in ipairs({ "size", "style" }) do
            local preview = page.previews[key]
            local standIn = preview.plate
            local column = standIn.point[2]
            local px, py = standIn.point[4], -standIn.point[5]
            local width = 3 * ns.db.plateSize + 2 * ns.ICON_SPACING
            local height = ns.db.plateSize
            local x, y = px + (110 - width) / 2 + offsets[1], py - offsets[2]
            if case[1] == "TOP" then y = y - offsets[3] - height
            elseif case[1] == "BOTTOM" then y = y + 22 + offsets[3]
            elseif case[1] == "LEFT" then x, y = px - offsets[3] - width + offsets[1], y + (22 - height) / 2
            else x, y = px + 110 + offsets[3] + offsets[1], y + (22 - height) / 2 end
            assert(x >= 0 and y >= 0 and x + width <= column.width and y + height <= column.height,
                "Icons must fit the preview bounds: " .. case[1])
            assert(px >= 0 and py >= 0 and px + 110 <= column.width and py + 22 <= column.height)
            assert(column.scale > 0 and column.scale <= 1)
            assert(preview.plateRow.point[1] == case[2] and preview.plateRow.point[3] == case[3])
        end
    end
end
assert(not ns.Set("plateAnchor", "INVALID"))
-- With the menu available, four positions are presented as selectable options.
local choices = {}
ns.FlatMenu = {
    DownArrow = function() end,
    Open = function(owner, generator)
        generator(nil, { CreateRadio = function(_, label, selected, action)
            choices[#choices + 1] = { label = label, action = action }
        end })
    end,
}
ns.BuildSettings()
local menuPage = ns.SettingsPages.Drpulse
menuPage.tabs.appearance.scripts.OnClick()
local selector = menuPage.rows["Nameplate icons"].controls[1]
assert(selector.dropdown)
selector.scripts.OnClick(selector, "LeftButton")
assert(#choices == 4 and choices[3].label == "Left" and choices[4].label == "Right")
choices[3].action()
assert(ns.db.plateAnchor == "LEFT")
choices[4].action()
assert(ns.db.plateAnchor == "RIGHT")
print("PASS four nameplate positions, offsets, cached anchors, saved profiles, preview bounds and dropdown")
`;

const result = lauxlib.luaL_dostring(state, to_luastring(setup + checks));
if (result !== lua.LUA_OK) {
    throw new Error(to_jsstring(lua.lua_tostring(state, -1)));
}
