local _, ns = ...
local PREFIX, MAX_BYTES, MAX_FIELDS = "DRPULSE1;", 32768, 512

local function Encode(value)
    if type(value) == "boolean" then return value and "b1" or "b0" end
    if type(value) == "number" then return "n" .. string.format("%.17g", value) end
    return "s" .. value:gsub("([^%w_%-%.])", function(c) return string.format("%%%02X", string.byte(c)) end)
end

local function Flatten(data, prefix, out)
    for key, value in pairs(data) do
        local path = prefix == "" and tostring(key) or (prefix .. "." .. tostring(key))
        if type(value) == "table" then Flatten(value, path, out)
        else out[path] = value end
    end
end

function ns.ExportProfile()
    if not ns.db then return nil, "Settings are not loaded." end
    local flat, paths, parts = {}, {}, {}
    Flatten(ns.ProfileData(ns.db), "", flat)
    for path in pairs(flat) do paths[#paths + 1] = path end
    table.sort(paths)
    for _, path in ipairs(paths) do parts[#parts + 1] = path .. "=" .. Encode(flat[path]) end
    local encoded = PREFIX .. table.concat(parts, ";")
    if #encoded > MAX_BYTES or #parts > MAX_FIELDS then return nil, "This profile is too large to export." end
    return encoded
end

local function Decode(value)
    if value == "b1" then return true end
    if value == "b0" then return false end
    if value:sub(1, 1) == "n" then
        local number = tonumber(value:sub(2))
        if number and number == number and number > -math.huge and number < math.huge then return number end
    elseif value:sub(1, 1) == "s" then
        local raw = value:sub(2)
        if raw:gsub("%%[0-9a-fA-F][0-9a-fA-F]", ""):find("[^%w_%-%.]") then return nil end
        return (raw:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
    end
    return nil
end

function ns.DecodeProfile(text)
    if type(text) ~= "string" or #text > MAX_BYTES then return nil, "Invalid or oversized profile code (maximum 32 KB)." end
    text = text:match("^%s*(.-)%s*$")
    if text:sub(1, #PREFIX) ~= PREFIX then return nil, "Unsupported profile code. Expected DRPULSE1." end
    local data = ns.ProfileData(ns.LoadDrpulseSettings(ns.LoadSettings(nil)))
    local allowed = {}
    Flatten(data, "", allowed)
    data.categories, data.custom = {}, {}
    local seen, count, customCount = {}, 0, 0
    local payload = text:sub(#PREFIX + 1)
    if payload == "" or payload:find(";;", 1, true) or payload:sub(-1) == ";" then return nil, "Incomplete profile code." end
    for field in payload:gmatch("[^;]+") do
        count = count + 1
        if count > MAX_FIELDS then return nil, "Too many profile fields." end
        local path, encoded = field:match("^([%w_%.]+)=(.+)$")
        if not path or seen[path] or #encoded > 256 then return nil, "Invalid or duplicate profile field." end
        seen[path] = true
        local value = Decode(encoded)
        if value == nil then return nil, "Invalid value for " .. path end
        local category = path:match("^categories%.([%w_]+)$")
        local spell = path:match("^custom%.(%d+)$")
        if category then
            if not ns.IsCategory(category) or (value ~= "always" and value ~= "never") then return nil, "Invalid category rule." end
            data.categories[category] = value
        elseif spell then
            local id = tonumber(spell)
            customCount = customCount + 1
            if not id or id < 1 or id > 10000000 or id % 1 ~= 0 or tostring(id) ~= spell
                or not ns.IsCategory(value) or customCount > 128 then return nil, "Invalid custom spell or too many spells." end
            data.custom[id] = value
        else
            if allowed[path] == nil or type(value) ~= type(allowed[path]) then return nil, "Unknown or invalid field: " .. path end
            local source = path:match("^sources%.([%w_]+)$")
            local minimap = path:match("^profile%.minimap%.([%w_]+)$")
            if source then data.sources[source] = value
            elseif minimap then
                if minimap == "angle" and (value < 0 or value >= 360) then return nil, "Invalid minimap angle." end
                data.profile.minimap[minimap] = value
            else data[path] = value end
        end
    end
    if not seen.schema or data.schema ~= ns.SCHEMA then return nil, "Unsupported or missing settings schema." end
    return ns.LoadDrpulseSettings(data)
end

function ns.ImportProfile(name, text)
    local data, problem = ns.DecodeProfile(text)
    if not data then return false, problem end
    return ns.CreateProfile(name, data)
end
