-- Behavioral integration tests against a small, explicit WoW API mock.
-- This cannot reproduce engine secret values, protection/taint, or rendering.
local source = ADDON_SOURCE
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function boot(saved)
    local objects, globals = {}, {}
    local state = { group = false, raid = false, count = 0,
        names = { player = "自己", target = "训练假人" }, offline = {}, errors = {}, secrets = {} }
    local methods = {}
    local function object(kind, name, parent)
        local value = { kind = kind, name = name, parent = parent, shown = true,
            scripts = {}, events = {}, points = {}, children = {}, scale = 1 }
        setmetatable(value, { __index = methods })
        objects[#objects + 1] = value
        if parent then parent.children[#parent.children + 1] = value end
        if name then globals[name] = value end
        return value
    end
    function methods:SetScript(event, fn) self.scripts[event] = fn end
    function methods:RegisterEvent(event) self.events[event] = true end
    function methods:UnregisterEvent(event) self.events[event] = nil end
    function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function methods:ClearAllPoints() self.points = {} end
    function methods:GetPoint() return unpack(self.points[1]) end
    function methods:SetSize(w, h) self.width, self.height = w, h end
    function methods:SetWidth(w) self.width = w end
    function methods:SetHeight(h) self.height = h end
    function methods:SetScale(scale) self.scale = scale end
    function methods:SetText(text) self.text = text end
    function methods:GetText() return self.text end
    function methods:SetTextColor(...) self.color = { ... } end
    function methods:Show()
        local changed = not self.shown
        self.shown = true
        if changed and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function methods:Hide() self.shown = false end
    function methods:IsShown() return self.shown end
    function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function methods:StartMoving() self.moving = true end
    function methods:StopMovingOrSizing() self.moving = false end
    function methods:CreateFontString(name) return object("FontString", name, self) end
    function methods:CreateTexture(name) return object("Texture", name, self) end
    function methods:SetThumbTexture() self.thumb = object("Texture", nil, self) end
    function methods:GetThumbTexture() return self.thumb end
    function methods:SetValue(v)
        self.value = v
        if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
    end
    function methods:GetValue() return self.value end
    for _, name in ipairs({ "SetClampedToScreen", "SetMovable", "SetFrameStrata", "SetJustifyH", "SetWordWrap",
        "SetAllPoints", "SetColorTexture", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
        "EnableMouse", "RegisterForDrag", "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag", "SetOrientation",
        "SetAutoFocus", "SetMaxLetters", "ClearFocus" }) do methods[name] = function() end end

    local env = setmetatable({ PartyTargetWatchDB = saved, SlashCmdList = {}, UISpecialFrames = {}, print = function() end }, { __index = _G })
    env._G = env
    env.UIParent = object("Frame", "UIParent")
    env.UIParent.SetScale = function() error("must not scale UIParent") end
    env.CreateFrame = function(kind, name, parent, template)
        local value = object(kind, name, parent)
        if template == "OptionsSliderTemplate" then
            value.Low, value.High, value.Text = object("FontString"), object("FontString"), object("FontString")
        end
        if name then env[name] = value end
        return value
    end
    env.IsInRaid = function() return state.raid end
    env.IsInGroup = function() return state.group or state.raid end
    env.GetNumGroupMembers = function() return state.count end
    env.GetNumSubgroupMembers = function() return state.count end
    env.UnitName = function(unit)
        if state.errors[unit] then error("simulated unavailable unit") end
        return state.names[unit]
    end
    env.UnitExists = function(unit)
        if state.errors[unit] then error("simulated unavailable unit") end
        return state.names[unit] ~= nil
    end
    env.UnitIsConnected = function(unit) return not state.offline[unit] end
    env.issecretvalue = function(value) return type(value) == "table" and state.secrets[value] == true end
    env.SetCVar = function() error("must not change CVars") end
    env.SetBinding = function() error("must not change keybindings") end
    local chunk = assert(loadstring(source, "@PartyTargetWatch.lua"))
    setfenv(chunk, env)
    chunk("PartyTargetWatch", {})
    local app = { state = state, env = env, globals = globals, objects = objects, frame = globals.PartyTargetWatchFrame }
    function app:event(event, arg)
        if self.frame.events[event] then self.frame.scripts.OnEvent(self.frame, event, arg) end
    end
    function app:tick(elapsed)
        if self.frame:IsVisible() then self.frame.scripts.OnUpdate(self.frame, elapsed) end
    end
    function app:command(command) self.env.SlashCmdList.PARTYTARGETWATCH(command) end
    function app:rows()
        local result = {}
        for _, child in ipairs(self.frame.children) do
            if child.member and child.shown then result[#result + 1] = child end
        end
        return result
    end
    function app:button(label)
        for _, value in ipairs(objects) do
            if value.kind == "Button" and value.text == label then return value end
        end
        error("missing button: " .. label)
    end
    function app:click(label)
        local button = self:button(label)
        button.scripts.OnClick(button)
    end
    function app:load() self:event("ADDON_LOADED", "PartyTargetWatch") end
    return app
end

local tests = {}
tests["initialization ignores unrelated addons, solo monitor is visible"] = function()
    local a = boot()
    a:event("ADDON_LOADED", "UnrelatedAddon")
    equal(a.frame.shown, false)
    equal(a.env.PartyTargetWatchDB, nil)
    a:load()
    equal(a.frame.shown, true)
    equal(#a:rows(), 1)
    equal(a:rows()[1].target.text, "训练假人")
end
tests["party target changes and clears via events, missed events poll"] = function()
    local a = boot(); a:load()
    a.state.group, a.state.count = true, 2
    a.state.names.party1, a.state.names.party2 = "队员一", "队员二"
    a.state.names.party1target, a.state.names.party2target = "怪物甲", "怪物乙"
    a:event("GROUP_ROSTER_UPDATE")
    equal(#a:rows(), 3)
    equal(a:rows()[2].target.text, "怪物甲")
    a.state.names.party1target = "新目标"
    a:event("UNIT_TARGET", "party1"); a:tick(0.01)
    equal(a:rows()[2].target.text, "新目标")
    a.state.names.party1target = nil
    a:tick(0.21)
    equal(a:rows()[2].target.text, "无目标 / 不可见")
    a.state.names.target = "自己的新目标"
    a:event("PLAYER_TARGET_CHANGED"); a:tick(0.01)
    equal(a:rows()[1].target.text, "自己的新目标")
end
tests["offline and unavailable targets cannot leave stale text"] = function()
    local a = boot(); a:load()
    a.state.offline.player = true; a:tick(0.21)
    equal(a:rows()[1].target.text, "离线")
    a.state.offline.player = false; a.state.errors.target = true; a:tick(0.21)
    equal(a:rows()[1].target.text, "不可用")
end
tests["40-member raid has two columns without extra player; leaving shrinks"] = function()
    local a = boot(); a:load()
    a.state.raid, a.state.count = true, 40
    for i = 1, 40 do a.state.names["raid" .. i] = "R" .. i; a.state.names["raid" .. i .. "target"] = "T" .. i end
    a:event("GROUP_ROSTER_UPDATE")
    equal(#a:rows(), 40)
    equal(a:rows()[40].target.text, "T40")
    equal(a.frame.width, 780)
    assert(a:rows()[21].points[1][2] > a:rows()[20].points[1][2])
    a.state.raid, a.state.count = false, 0; a:event("GROUP_ROSTER_UPDATE")
    equal(#a:rows(), 1); equal(a.frame.width, 390)
end
tests["preview is explicit, exits to real data, and never persists"] = function()
    local a = boot(); a:load(); a:command("test")
    equal(#a:rows(), 5)
    assert(a:rows()[1].member.text:find("示例"))
    a.state.names.target = "实时目标"
    a:command("test")
    equal(#a:rows(), 1); equal(a:rows()[1].target.text, "实时目标")
    a:command("test")
    local b = boot(a.env.PartyTargetWatchDB); b:load()
    equal(#b:rows(), 1)
end
tests["hidden monitor stops polling and show refreshes immediately"] = function()
    local a = boot(); a:load(); a:command("hide")
    a.state.names.target = "更新目标"; a:tick(1)
    equal(a:rows()[1].target.text, "训练假人")
    a:command("show")
    equal(a.frame.shown, true); equal(a:rows()[1].target.text, "更新目标")
    a:command("hide")
    local b = boot(a.env.PartyTargetWatchDB); b:load(); equal(b.frame.shown, false)
    b:command("show"); equal(b.frame.shown, true)
end
tests["position, scale and lock persist without modifying global UI"] = function()
    local a = boot(); a:load()
    a.frame:ClearAllPoints(); a.frame:SetPoint("TOPLEFT", a.env.UIParent, "TOPLEFT", 200, -100)
    a:command("lock"); a:command("scale 1.25")
    local b = boot(a.env.PartyTargetWatchDB); b:load()
    equal(b.env.PartyTargetWatchDB.x, 200); equal(b.env.PartyTargetWatchDB.y, -100)
    equal(b.env.PartyTargetWatchDB.locked, true); equal(b.frame.scale, 1.25)
    b:command("scale 900"); equal(b.frame.scale, 1.25)
    b:command("reset"); equal(b.frame.scale, 1); equal(b.env.PartyTargetWatchDB.locked, false)
end
tests["corrupt saved settings are normalized"] = function()
    for _, saved in ipairs({ 1, "broken", { point = "INVALID", relativePoint = false, x = 0/0,
        y = math.huge, scale = -100, hidden = "bad", locked = {} } }) do
        local a = boot(saved); a:load()
        equal(a.frame.shown, true); equal(a.frame.scale, 1)
        equal(a.env.PartyTargetWatchDB.point, "CENTER")
    end
end
tests["secret name objects reach SetText unchanged"] = function()
    local a = boot()
    local secret = setmetatable({}, { __concat = function() error("secret concatenation") end,
        __tostring = function() error("secret conversion") end, __lt = function() error("secret comparison") end })
    a.state.secrets[secret] = true
    a.state.names.player, a.state.names.target = secret, secret
    a:load()
    assert(rawequal(a:rows()[1].member.text, secret))
    assert(rawequal(a:rows()[1].target.text, secret))
end
tests["settings opens while hidden, scale and numeric position apply"] = function()
    local a = boot(); a:load(); a:command("hide"); a:command("settings")
    local panel = a.globals.PartyTargetWatchSettings
    equal(panel.shown, true)
    a.globals.PartyTargetWatchScaleSlider:SetValue(1.4)
    equal(a.frame.scale, 1.4); equal(a.env.PartyTargetWatchDB.scale, 1.4)
    local boxes = {}
    for _, child in ipairs(panel.children) do if child.kind == "EditBox" then boxes[#boxes + 1] = child end end
    equal(#boxes, 2)
    boxes[1]:SetText("125"); boxes[2]:SetText("-50"); a:click("应用位置")
    equal(a.env.PartyTargetWatchDB.x, 125); equal(a.env.PartyTargetWatchDB.y, -50)
    boxes[1]:SetText("invalid"); boxes[2]:SetText("80"); a:click("应用位置")
    equal(a.env.PartyTargetWatchDB.x, 125); equal(a.env.PartyTargetWatchDB.y, -50)
    a:click("窗口居中")
    equal(a.frame.shown, true); equal(a.env.PartyTargetWatchDB.x, 0)
    a:click("显示示例预览"); equal(#a:rows(), 5)
    a:click("恢复默认"); equal(#a:rows(), 1); equal(a.frame.scale, 1)
end
local count = 0
for name, test in pairs(tests) do test(); count = count + 1; print("PASS " .. name) end
print(string.format("%d Lua 5.1 integration scenarios passed", count))
