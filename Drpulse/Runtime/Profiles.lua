local _, ns = ...
local store, character, active, ready
local MAX_PROFILES = 50

local function CharacterKey()
    local name, realm
    if UnitFullName then name, realm = UnitFullName("player") end
    if not ns.Text(name) then name = UnitName("player") end
    if not ns.Text(name) then return nil end
    if not ns.Text(realm) then realm = GetRealmName and GetRealmName() end
    return name .. "-" .. (ns.Text(realm) and realm or "UnknownRealm")
end

function ns.ProfileSpecKey()
    local index = GetSpecialization and GetSpecialization()
    local id = index and GetSpecializationInfo and GetSpecializationInfo(index)
    if ns.Number(id, 1) then return "spec:" .. id end
    local group = GetActiveTalentGroup and GetActiveTalentGroup()
    if ns.Number(group, 1) then return "talents:" .. group end
end

local function Binding()
    return store and character and store.characters[character]
end

function ns.ProfileNames()
    local names = {}
    for name in pairs(store and store.profiles or {}) do names[#names + 1] = name end
    table.sort(names)
    return names
end
function ns.ActiveProfile() return active or "Default" end
function ns.AutoSpecProfiles() local binding = Binding(); return binding and binding.autoSpec == true or false end

local function Activate(name)
    if not store or type(store.profiles[name]) ~= "table" then return false, "Profile not found." end
    if active == name then return true end
    local db, problem = ns.LoadDrpulseSettings(store.profiles[name])
    if not db then return false, problem end
    if ready and ns.FinishDisplayInteraction then ns.FinishDisplayInteraction() end
    active, ns.db, DrpulseV2DB = name, db, db
    if ready then
        ns.ClearTracking()
        ns.RefreshMine()
        ns.RescanAll()
        ns.KeepBlizzardOn()
        ns.PositionTarget()
        ns.Minimap:Refresh()
        ns.NotifySettingsChanged("profile")
    end
    return true
end

function ns.SelectProfile(name)
    if InCombatLockdown() then return false, "Profiles can be changed after combat." end
    local binding = Binding()
    if not binding then return false, "Profiles are not available yet." end
    local ok, problem = Activate(name)
    if not ok then return false, problem end
    local spec = binding.autoSpec and ns.ProfileSpecKey()
    if spec then binding.specs[spec] = name else binding.profile = name end
    return true
end

function ns.CreateProfile(name, data)
    if not store then return false, "Profiles are not available yet." end
    if InCombatLockdown() then return false, "Profiles can be created after combat." end
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if #name < 1 or #name > 48 or name:find("[%c|]") then return false, "Use a name of 1 to 48 characters without control characters or |." end
    if store.profiles[name] then return false, "That profile already exists. Choose another name." end
    if #ns.ProfileNames() >= MAX_PROFILES then return false, "Profile limit reached (50)." end
    local copy, problem = ns.LoadDrpulseSettings(ns.ProfileData(data or ns.db))
    if not copy then return false, problem end
    store.profiles[name] = copy
    return ns.SelectProfile(name)
end

local function ApplyBinding()
    local binding = Binding()
    if not binding or InCombatLockdown() then return end
    local spec = binding.autoSpec and ns.ProfileSpecKey()
    local name = (spec and binding.specs[spec]) or binding.profile
    local ok, problem = Activate(name)
    if not ok then ns.Print("Profile unchanged: " .. tostring(problem)) end
end

function ns.SetAutoSpecProfiles(value)
    if InCombatLockdown() then return false, "Change specialization profiles after combat." end
    local binding = Binding()
    if not binding then return false, "Profiles are not available yet." end
    binding.autoSpec = value == true
    ApplyBinding()
    if ns.RefreshSettings then ns.RefreshSettings() end
    return true
end

function ns.StartProfiles()
    character = CharacterKey()
    if not character then ns.Print("Profiles unavailable until character identity is readable."); return end
    local saved = DrpulseProfilesDB
    if saved ~= nil and (type(saved) ~= "table" or saved.schema ~= 1 or type(saved.profiles) ~= "table"
        or type(saved.characters) ~= "table") then
        ns.Print("Profile storage is invalid or newer. Original data preserved."); return
    end
    store = saved or { schema = 1, profiles = { Default = ns.db }, characters = {} }
    DrpulseProfilesDB = store
    local binding = store.characters[character]
    if binding == nil then
        binding = { profile = "Default", specs = {}, autoSpec = false }
        store.characters[character] = binding
    end
    if type(binding) ~= "table" or type(binding.specs) ~= "table" or type(binding.profile) ~= "string" then
        store = nil; ns.Print("Invalid character profile binding. Original data preserved."); return
    end
    ApplyBinding()
    ready = true
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "PLAYER_REGEN_ENABLED" }) do
        if C_EventUtils.IsEventValid(event) then events:RegisterEvent(event) end
    end
    events:SetScript("OnEvent", function(_, event, unit)
        if event ~= "PLAYER_SPECIALIZATION_CHANGED" or unit == "player" then ApplyBinding() end
    end)
end
