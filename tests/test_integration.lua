-- Isolated integration tests. These model the public Settings and frame APIs,
-- plus the minimap collector contract, without loading another addon's code.
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function boot(hasSettings)
    local frames, globals, calls = {}, {}, {}
    local methods = {}
    local function object(kind, name, parent)
        local value = setmetatable({ kind = kind, name = name, parent = nil, children = {},
            points = {}, scripts = {}, events = {}, shown = true }, { __index = methods })
        frames[#frames + 1] = value
        if name then globals[name] = value end
        value:SetParent(parent)
        return value
    end
    function methods:SetParent(parent)
        if self.parent then
            for i, child in ipairs(self.parent.children) do
                if child == self then table.remove(self.parent.children, i); break end
            end
        end
        self.parent = parent
        if parent then parent.children[#parent.children + 1] = self end
    end
    function methods:GetParent() return self.parent end
    function methods:GetChildren() return unpack(self.children) end
    function methods:GetName() return self.name end
    function methods:IsObjectType(kind) return self.kind == kind end
    function methods:SetSize(width, height) self.width, self.height = width, height end
    function methods:GetWidth() return self.width or 0 end
    function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function methods:GetPoint() return unpack(self.points[1] or {}) end
    function methods:ClearAllPoints() self.points = {} end
    function methods:SetScript(event, callback) self.scripts[event] = callback end
    function methods:GetScript(event) return self.scripts[event] end
    function methods:RegisterEvent(event) self.events[event] = true end
    function methods:UnregisterEvent(event) self.events[event] = nil end
    function methods:RegisterForClicks(...) self.clicks = { ... } end
    function methods:SetFrameStrata(strata) self.strata = strata end
    function methods:SetTexture(texture) self.texture = texture end
    function methods:SetHighlightTexture(texture) self.highlight = texture end
    function methods:SetText(text) self.text = text end
    function methods:SetTexCoord(...) self.texCoord = { ... } end
    function methods:SetJustifyH(justify) self.justify = justify end
    function methods:CreateTexture(name) return object("Texture", name, self) end
    function methods:CreateFontString(name) return object("FontString", name, self) end
    function methods:IsShown() return self.shown end
    function methods:Show()
        local wasShown = self.shown
        self.shown = true
        if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function methods:Hide()
        local wasShown = self.shown
        self.shown = false
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    local env = setmetatable({}, { __index = _G })
    env.UIParent = object("Frame", "UIParent")
    env.Minimap = object("Frame", "Minimap", env.UIParent)
    env.SettingsPanel = object("Frame", "SettingsPanel", env.UIParent)
    env.SettingsPanel:Hide()
    env.GameTooltip = {
        SetOwner = function(self, owner) self.owner = owner end,
        SetText = function(self, text) self.title, self.lines = text, {} end,
        AddLine = function(self, text) self.lines[#self.lines + 1] = text end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
    }
    env.CreateFrame = object
    env.HideUIPanel = function(panel)
        equal(panel, env.SettingsPanel)
        calls[#calls + 1] = "hide native settings"
        panel:Hide()
    end
    local state = { frames = frames, globals = globals, env = env, calls = calls, registrations = {}, categories = {} }
    state.app = {
        db = {},
        ShowSettings = function() calls[#calls + 1] = "settings" end,
        ShowFormats = function() calls[#calls + 1] = "formats" end,
    }
    function state:installSettingsAPI()
        env.Settings = {
            RegisterCanvasLayoutCategory = function(panel, name)
                local category = { panel = panel, name = name }
                self.categories[#self.categories + 1] = category
                return category
            end,
            RegisterAddOnCategory = function(category)
                equal(category, self.categories[#self.categories], "registered canvas category")
                self.registrations[#self.registrations + 1] = category
            end,
        }
    end
    if hasSettings then state:installSettingsAPI() end
    state.ns = {}
    local chunk = assert(loadstring(INTEGRATION_SOURCE, "@Integration.lua"))
    setfenv(chunk, env)
    chunk("PartyTargetWatch", state.ns)
    function state:initialize() self.ns.InitializeIntegration(self.app) end
    function state:event(event, ...)
        for _, frame in ipairs(frames) do
            if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
        end
    end
    function state:canvasButton(text)
        for _, child in ipairs(self.registrations[1].panel.children) do
            if child.kind == "Button" and child.text == text then return child end
        end
        error("missing canvas button: " .. text)
    end
    function state:click(button, mouseButton) button.scripts.OnClick(button, mouseButton or "LeftButton") end
    return state
end

local tests = {}

tests["registration waits for initialized settings and is idempotent"] = function()
    local a = boot(true)
    a.app.db = nil; a:initialize()
    equal(a.globals.PartyTargetWatchMinimapButton, nil); equal(#a.registrations, 0)
    a.app.db = {}; a:initialize()
    local button, canvas = a.globals.PartyTargetWatchMinimapButton, a.registrations[1].panel
    a:initialize(); a:event("ADDON_LOADED", "Blizzard_Settings")
    equal(a.globals.PartyTargetWatchMinimapButton, button)
    equal(#a.categories, 1); equal(#a.registrations, 1)
    equal(a.registrations[1].panel, canvas)
    equal(a.registrations[1].name, "PartyTargetWatch 队友目标")
end

tests["minimap clicks open the two existing windows and tooltip explains controls"] = function()
    local a = boot(true); a:initialize()
    local button = a.globals.PartyTargetWatchMinimapButton
    equal(button.clicks[1], "LeftButtonUp"); equal(button.clicks[2], "RightButtonUp")
    a:click(button, "LeftButton"); a:click(button, "RightButton"); a:click(button, "MiddleButton")
    equal(#a.calls, 2); equal(a.calls[1], "settings"); equal(a.calls[2], "formats")
    button.scripts.OnEnter(button)
    equal(a.env.GameTooltip.owner, button); equal(a.env.GameTooltip.shown, true)
    assert(a.env.GameTooltip.lines[1]:find("左键", 1, true))
    assert(a.env.GameTooltip.lines[2]:find("右键", 1, true))
    button.scripts.OnLeave(button); equal(a.env.GameTooltip.shown, false)
end

tests["native Settings category buttons close native settings before opening addon windows"] = function()
    local a = boot(true); a:initialize()
    a.env.SettingsPanel:Show()
    a:click(a:canvasButton("打开设置"))
    equal(a.calls[1], "hide native settings"); equal(a.calls[2], "settings")
    equal(a.env.SettingsPanel:IsShown(), false)
    a.env.SettingsPanel:Show()
    a:click(a:canvasButton("编辑接收格式"))
    equal(a.calls[3], "hide native settings"); equal(a.calls[4], "formats")
    a.env.SettingsPanel = nil
    a:click(a:canvasButton("打开设置")); equal(a.calls[5], "settings")
end

tests["unavailable Settings APIs preserve access and register once after their addon loads"] = function()
    local a = boot(false); a:initialize(); a:initialize()
    equal(#a.registrations, 0)
    a:click(a.globals.PartyTargetWatchMinimapButton, "LeftButton")
    equal(a.calls[1], "settings")
    a:installSettingsAPI()
    local registerAddOnCategory = a.env.Settings.RegisterAddOnCategory
    a.env.Settings.RegisterAddOnCategory = nil
    a:event("ADDON_LOADED", "Blizzard_Settings_Shared")
    equal(#a.categories, 0, "partial API must not create an orphan category")
    a.env.Settings.RegisterAddOnCategory = registerAddOnCategory
    a:event("ADDON_LOADED", "UnrelatedAddon"); equal(#a.registrations, 0)
    a:event("ADDON_LOADED", "Blizzard_Settings")
    equal(#a.registrations, 1)
    a:event("ADDON_LOADED", "Blizzard_Settings_Shared"); a:initialize()
    equal(#a.categories, 1); equal(#a.registrations, 1)
    for _, frame in ipairs(a.frames) do equal(frame.events.ADDON_LOADED, nil, "registration retry should stop") end
end

tests["minimap collector can discover reparent resize and show the button without losing its layout"] = function()
    local a = boot(true); a:initialize()
    local button = a.globals.PartyTargetWatchMinimapButton
    local found = false
    for _, child in ipairs({ a.env.Minimap:GetChildren() }) do
        local name = child:GetName()
        if child:IsObjectType("Button") and name and not name:match("%d+$") and child:GetWidth() >= 20 then
            if child == button then found = true end
        end
    end
    equal(found, true, "minimap collector discovery contract")
    equal(button.icon.texture, "Interface\\Icons\\Ability_Hunter_SniperShot")
    equal(button:GetScript("OnShow"), nil); equal(button:GetScript("OnUpdate"), nil)
    local flyout = a.env.CreateFrame("Frame", "CollectorFlyout", a.env.UIParent)
    button:SetParent(flyout); button:ClearAllPoints(); button:SetPoint("TOPLEFT", flyout, "TOPLEFT", 8, -8)
    button:SetSize(24, 24)
    button.icon:ClearAllPoints(); button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    button:Hide(); button:Show(); a:initialize()
    equal(button:GetParent(), flyout); equal(button:GetWidth(), 24)
    equal(#button.points, 1); equal(button.points[1][2], flyout); equal(button.points[1][4], 8)
    equal(button.icon.points[1][1], "TOPLEFT", "icon collector layout was overwritten")
    a:click(button, "RightButton"); equal(a.calls[1], "formats")
end

local names = {}
for name in pairs(tests) do names[#names + 1] = name end
table.sort(names)
for _, name in ipairs(names) do
    tests[name]()
    print("PASS entry integration: " .. name)
end
print("Entry integration tests passed: " .. #names)
