-- Behavioral integration tests against a small, explicit WoW API mock.
-- This cannot reproduce engine secret values, protection/taint, or rendering.
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function boot(saved)
    local objects, globals = {}, {}
    local state = { group = false, raid = false, count = 0, instanceType = "none", resting = false,
        names = { player = "自己", target = "训练假人" }, offline = {}, errors = {}, secrets = {},
        markers = {}, nameCalls = 0, secretTypes = {}, existsResults = {}, messages = {} }
    local methods = {}
    local function object(kind, name, parent)
        local value = { kind = kind, name = name, parent = parent, shown = true,
            scripts = {}, events = {}, points = {}, children = {}, scale = 1, alpha = 1 }
        setmetatable(value, { __index = methods })
        objects[#objects + 1] = value
        if parent then parent.children[#parent.children + 1] = value end
        if name then globals[name] = value end
        return value
    end
    function methods:SetScript(event, fn) self.scripts[event] = fn end
    function methods:GetScript(event) return self.scripts[event] end
    function methods:HookScript(event, fn)
        local previous = self.scripts[event]
        self.scripts[event] = function(...) if previous then previous(...) end; fn(...) end
    end
    function methods:RegisterEvent(event) self.events[event] = true end
    function methods:RegisterUnitEvent(event) self.events[event] = true end
    function methods:UnregisterEvent(event) self.events[event] = nil end
    function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function methods:ClearAllPoints() self.points = {} end
    function methods:GetPoint() return unpack(self.points[1] or {}) end
    function methods:SetSize(w, h) self.width, self.height = w, h end
    function methods:SetWidth(w) self.width = w end
    function methods:SetHeight(h) self.height = h end
    function methods:GetWidth() return self.width or 0 end
    function methods:GetHeight() return self.height or 0 end
    function methods:SetScale(scale) self.scale = scale end
    function methods:GetScale() return self.scale end
    function methods:GetEffectiveScale() return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
    function methods:SetAlpha(alpha) self.alpha = alpha end
    function methods:GetAlpha() return self.alpha end
    function methods:SetText(text)
        self.text = text
        if self.kind == "EditBox" and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
    end
    function methods:GetText() return self.text end
    function methods:GetName() return self.name end
    function methods:GetParent() return self.parent end
    function methods:SetTexture(texture) self.texture = texture end
    function methods:GetTexture() return self.texture end
    function methods:SetTexCoord(...) self.texCoord = { ... } end
    function methods:SetAtlas(atlas) self.atlas = atlas end
    function methods:SetSpriteSheetCell(index, columns, rows)
        self.spriteIndex, self.spriteColumns, self.spriteRows = index, columns, rows
    end
    function methods:SetTextColor(...) self.color = { ... } end
    function methods:SetColorTexture(...) self.color = { ... } end
    function methods:SetBackdropColor(...) self.backdropColor = { ... } end
    function methods:SetBackdropBorderColor(...) self.borderColor = { ... } end
    function methods:Show()
        local changed = not self.shown
        self.shown = true
        if changed and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function methods:Hide()
        local changed = self.shown
        self.shown = false
        if changed and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function methods:SetShown(shown) if shown then self:Show() else self:Hide() end end
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
    function methods:SetChecked(value) self.checked = not not value end
    function methods:GetChecked() return self.checked end
    function methods:SetEnabled(value) self.enabled = not not value end
    function methods:Enable() self.enabled = true end
    function methods:Disable() self.enabled = false end
    function methods:SetMaxLetters(value) self.maxLetters = value end
    function methods:ClearFocus() self.focused = false end
    function methods:EnableMouse(value) self.mouseEnabled = not not value end
    for _, name in ipairs({ "SetClampedToScreen", "SetMovable", "SetFrameStrata", "SetJustifyH", "SetWordWrap",
        "SetAllPoints", "SetBackdrop",
        "RegisterForDrag", "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag", "SetOrientation",
        "SetAutoFocus", "SetFrameLevel", "SetJustifyV", "RegisterForClicks",
        "SetNormalTexture", "SetPushedTexture", "SetHighlightTexture", "SetDisabledTexture", "SetFontObject",
        "SetTextInsets", "SetNumeric" }) do methods[name] = function() end end

    local env = setmetatable({ PartyTargetWatchDB = saved, SlashCmdList = {}, UISpecialFrames = {},
        print = function(message) state.messages[#state.messages + 1] = message end }, { __index = _G })
    env._G = env
    env.UIParent = object("Frame", "UIParent")
    env.UIParent:SetSize(1920, 1080)
    env.UIParent.SetScale = function() error("must not scale UIParent") end
    env.CreateFrame = function(kind, name, parent, template)
        local value = object(kind, name, parent)
        if template == "OptionsSliderTemplate" then
            value.Low, value.High, value.Text = object("FontString"), object("FontString"), object("FontString")
        elseif kind == "CheckButton" then
            value.Text = object("FontString", nil, value)
            value.text = value.Text
        end
        if name then env[name] = value end
        return value
    end
    env.IsInRaid = function() return state.raid end
    env.IsInGroup = function() return state.group or state.raid end
    env.GetNumGroupMembers = function() return state.count end
    env.GetNumSubgroupMembers = function() return state.count end
    env.IsInInstance = function() return state.instanceType ~= "none", state.instanceType end
    env.IsResting = function() return state.resting end
    env.UnitName = function(unit)
        state.nameCalls = state.nameCalls + 1
        if state.errors[unit] then error("simulated unavailable unit") end
        return state.names[unit]
    end
    env.UnitExists = function(unit)
        if state.errors[unit] then error("simulated unavailable unit") end
        if state.existsResults[unit] ~= nil then return state.existsResults[unit] end
        return state.names[unit] ~= nil
    end
    env.UnitIsConnected = function(unit) return not state.offline[unit] end
    env.issecretvalue = function(value) return type(value) == "table" and state.secrets[value] == true end
    -- A table can stand in for an engine secret number only at the mocked type
    -- boundary. Arithmetic metamethods then detect Lua operations on that value.
    env.type = function(value) return state.secretTypes[value] or type(value) end
    env.GetRaidTargetIndex = function(unit) return state.markers[unit] end
    env.SetRaidTargetIconTexture = function(texture, index)
        assert(type(index) == "number" and index >= 1 and index <= 8, "unsafe marker arithmetic")
        texture.marker = index
    end
    env.SetCVar = function() error("must not change CVars") end
    env.SetBinding = function() error("must not change keybindings") end
    env.SaveBindings = function() error("must not save keybindings") end
    local namespace = {}
    for _, module in ipairs(ADDON_SOURCES) do
        local chunk = assert(loadstring(module.source, "@" .. module.name))
        setfenv(chunk, env)
        chunk("PartyTargetWatch", namespace)
    end
    local app = { state = state, env = env, globals = globals, objects = objects,
        frame = globals.PartyTargetWatchFrame, namespace = namespace }
    function app:event(event, ...)
        for _, value in ipairs(objects) do
            if value.events[event] and value.scripts.OnEvent then value.scripts.OnEvent(value, event, ...) end
        end
    end
    function app:tick(elapsed)
        for _, value in ipairs(objects) do
            if value:IsVisible() and value.scripts.OnUpdate then value.scripts.OnUpdate(value, elapsed) end
        end
    end
    function app:command(command) self.env.SlashCmdList.PARTYTARGETWATCH(command) end
    function app:rows()
        local result = {}
        for _, child in ipairs(objects) do
            if child.member and child.shown then result[#result + 1] = child end
        end
        return result
    end
    function app:button(label)
        for _, value in ipairs(objects) do
            if value.kind == "Button" or value.kind == "CheckButton" then
                if value.text == label or (type(value.text) == "table" and value.text.text == label)
                    or (value.Text and value.Text.text == label) then return value end
                for _, child in ipairs(value.children) do
                    if child.kind == "FontString" and child.text == label then return value end
                end
            end
        end
        error("missing button: " .. label)
    end
    function app:click(label)
        local button = self:button(label)
        assert(button:IsVisible(), "control is not visible: " .. label)
        if button.kind == "CheckButton" then button.checked = not button.checked end
        button.scripts.OnClick(button, "LeftButton")
    end
    function app:load() self:event("ADDON_LOADED", "PartyTargetWatch") end
    function app:scenario(kind, resting, event)
        self.state.instanceType, self.state.resting = kind, not not resting
        self:event(event or "PLAYER_ENTERING_WORLD"); self:tick(0.21)
    end
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
    local count = #a.objects; a:load(); equal(#a.objects, count)
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
    a:event("UNIT_TARGET", "party1"); a:tick(0.21)
    equal(a:rows()[2].target.text, "新目标")
    a.state.names.party1target = nil
    a:tick(0.21)
    equal(a:rows()[2].target.text, "无目标 / 不可见")
    a.state.names.target = "自己的新目标"
    a:event("PLAYER_TARGET_CHANGED"); a:tick(0.21)
    equal(a:rows()[1].target.text, "自己的新目标")
end
tests["offline and unavailable targets cannot leave stale text"] = function()
    local a = boot(); a.state.markers.target = 8; a:load()
    a.state.offline.player = true; a:tick(0.21)
    equal(a:rows()[1].target.text, "离线")
    assert(not a:rows()[1].targetMarker.shown or a:rows()[1].targetMarker.texture == nil,
        "offline member left stale target marker")
    a.state.offline.player = false; a.state.errors.target = true; a:tick(0.21)
    equal(a:rows()[1].target.text, "不可用")
end
tests["40-member raid has two columns without extra player; leaving shrinks"] = function()
    local a = boot({ showFocus = true }); a:load()
    a.state.raid, a.state.count = true, 40
    for i = 1, 40 do a.state.names["raid" .. i] = "R" .. i; a.state.names["raid" .. i .. "target"] = "T" .. i end
    a:event("GROUP_ROSTER_UPDATE")
    equal(#a:rows(), 40)
    for i, row in ipairs(a:rows()) do equal(row.member.text, "R" .. i); equal(row.target.text, "T" .. i) end
    local raidWidth = a.frame.width
    equal(raidWidth, 860, "retired focus setting must not widen the raid layout")
    a.state.raid, a.state.count = false, 0; a:event("GROUP_ROSTER_UPDATE")
    equal(#a:rows(), 1); equal(a:rows()[1].member.text, "自己")
    assert(a.frame.width < raidWidth, "solo layout did not collapse raid columns")
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
tests["saved settings normalize corruption and remove retired focus settings without losing preferences"] = function()
    local retired = { "showFocus", "shareFocus", "acceptFocusCalls", "declarationFormats" }
    for _, saved in ipairs({ 1, "broken", { point = "INVALID", relativePoint = false, x = 0/0,
        y = math.huge, scale = -100, hidden = "bad", locked = {},
        showFocus = "yes", shareFocus = {}, showWorld = "no", acceptFocusCalls = 1, declarationFormats = {} } }) do
        local a = boot(saved); a:load()
        equal(a.frame.shown, true); equal(a.frame.scale, 1)
        equal(a.env.PartyTargetWatchDB.point, "CENTER")
        for _, key in ipairs(retired) do equal(a.env.PartyTargetWatchDB[key], nil, key) end
        for _, key in ipairs({ "showWorld", "showResting", "showDungeon", "showRaid", "showScenario", "showBattleground", "showArena" }) do
            equal(a.env.PartyTargetWatchDB[key], true, key)
        end
    end
    local a = boot({ shareFocus = true, showFocus = true, acceptFocusCalls = true,
        declarationFormats = "我的焦点打断是 {rt%mark} %name", backgroundAlpha = 0.3,
        scale = 1.25, locked = true, x = 150, y = -80, showRaid = false })
    a:load()
    for _, key in ipairs(retired) do equal(a.env.PartyTargetWatchDB[key], nil, key) end
    equal(a.env.PartyTargetWatchDB.backgroundAlpha, 0.3)
    equal(a.frame.scale, 1.25); equal(a.env.PartyTargetWatchDB.locked, true)
    equal(a.env.PartyTargetWatchDB.x, 150); equal(a.env.PartyTargetWatchDB.y, -80)
    equal(a.env.PartyTargetWatchDB.showRaid, false)
    a:command("reset")
    for _, key in ipairs(retired) do equal(a.env.PartyTargetWatchDB[key], nil, key) end
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
tests["defensive secret existence result clears stale target and marker"] = function()
    -- 12.1.0 does not document UnitExists as returning secrets. This is a
    -- defensive failure simulation, not a claim about observed game behavior.
    local a = boot(); a.state.markers.target = 8; a:load()
    local secret = {}; a.state.secrets[secret] = true
    a.state.existsResults.target = secret
    a:tick(0.21)
    equal(a:rows()[1].target.text, "不可用")
    equal(a:rows()[1].targetMarker.shown, false)
end
tests["settings opens while hidden, scale and numeric position apply"] = function()
    local a = boot(); a:load(); a:command("hide"); a:command("settings")
    local panel = a.globals.PartyTargetWatchSettings
    equal(panel.shown, true)
    a.globals.PartyTargetWatchScaleSlider:SetValue(1.4)
    equal(a.frame.scale, 1.4); equal(a.env.PartyTargetWatchDB.scale, 1.4)
    local boxes = {}
    for _, child in ipairs(a.objects) do if child.kind == "EditBox" then boxes[#boxes + 1] = child end end
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
tests["event bursts cannot exceed five target refreshes per second"] = function()
    local a = boot(); a:load(); a:tick(0.21)
    a.state.names.target = "限频后目标"
    local calls = a.state.nameCalls
    for i = 1, 10 do a:event("UNIT_TARGET", "player"); a:tick(0.01) end
    equal(a.state.nameCalls, calls, "events bypassed refresh interval")
    equal(a:rows()[1].target.text, "训练假人")
    a:tick(0.11); equal(a:rows()[1].target.text, "限频后目标")
end
tests["each scene filter is independent and hidden frames recover on events"] = function()
    local cases = {
        { "none", false, "showWorld" }, { "none", true, "showResting" },
        { "party", false, "showDungeon" }, { "raid", false, "showRaid" },
        { "scenario", false, "showScenario" }, { "pvp", false, "showBattleground" }, { "arena", false, "showArena" },
    }
    for _, case in ipairs(cases) do
        local saved = {}; saved[case[3]] = false
        local a = boot(saved); a:load(); a:scenario(case[1], case[2])
        equal(a.frame.shown, false, case[3] .. " disabled")
        if case[3] == "showWorld" then a:scenario("party", false)
        else a:scenario("none", false) end
        equal(a.frame.shown, true, "recover from " .. case[3])
        a:command("hide"); a:scenario("raid", false)
        equal(a.frame.shown, false, "explicit hide overrides scene display")
    end
end
tests["instance wins over resting and resting events recover display"] = function()
    local a = boot({ showWorld = false, showResting = false, showDungeon = true }); a:load()
    equal(a.frame.shown, false)
    a:scenario("party", true); equal(a.frame.shown, true)
    a:scenario("none", true, "PLAYER_UPDATE_RESTING"); equal(a.frame.shown, false)
    local b = boot({ showWorld = false, showResting = true }); b:load(); equal(b.frame.shown, false)
    b:scenario("none", true, "PLAYER_UPDATE_RESTING"); equal(b.frame.shown, true)
end
tests["preview bypasses scene filters and explicit hide still wins"] = function()
    local a = boot({ showWorld = false }); a:load(); equal(a.frame.shown, false)
    a:command("test"); equal(a.frame.shown, true); equal(#a:rows(), 5)
    a:command("hide"); a:event("ZONE_CHANGED_NEW_AREA"); a:tick(0.21); equal(a.frame.shown, false)
    a:command("show"); equal(a.frame.shown, false)
    a:scenario("party", false); equal(a.frame.shown, true); equal(#a:rows(), 1)
end
tests["public target markers update through eight values and clear"] = function()
    local a = boot(); a.state.markers.target = 1; a:load()
    local icon = a:rows()[1].targetMarker
    for marker = 1, 8 do
        a.state.markers.target = marker; a:event("RAID_TARGET_UPDATE"); a:tick(0.21)
        equal(icon.shown, true)
        equal(icon.spriteIndex, marker, "native marker cell must use the one-based index")
    end
    a.state.markers.target = nil; a:tick(0.21)
    assert(not icon.shown or icon.texture == nil, "cleared marker left stale icon")
    a.state.markers.target = 8; a:tick(0.21); a.state.names.target = nil; a:tick(0.21)
    assert(not icon.shown or icon.texture == nil, "missing target left stale marker")
end
tests["secret marker sentinel is passed to native setter without Lua arithmetic"] = function()
    local a = boot(); a.state.markers.target = 1; a:load()
    local secret = setmetatable({}, { __concat = function() error("secret concatenation") end,
        __tostring = function() error("secret conversion") end, __lt = function() error("secret comparison") end,
        __le = function() error("secret comparison") end, __add = function() error("secret arithmetic") end,
        __sub = function() error("secret arithmetic") end, __mod = function() error("secret arithmetic") end,
        __div = function() error("secret arithmetic") end, __mul = function() error("secret arithmetic") end })
    a.state.secrets[secret], a.state.secretTypes[secret], a.state.markers.target = true, "number", secret
    a:tick(0.21)
    local icon = a:rows()[1].targetMarker
    assert(not icon.shown or rawequal(icon.spriteIndex, secret), "secret marker changed before native setter")
    icon.SetSpriteSheetCell = function() error("simulated native rendering refusal") end
    a:tick(0.21)
    equal(icon.shown, false, "native rendering refusal left stale icon")
end
tests["scene checkboxes immediately hide recover and stay synchronized after reset"] = function()
    local a = boot(); a:load(); a:command("settings")
    local panel = a.globals.PartyTargetWatchSettings
    a:click("野外")
    equal(a.env.PartyTargetWatchDB.showWorld, false); equal(a.frame.shown, false)
    equal(panel.shown, true, "filter must leave its settings reachable")
    a:click("野外"); equal(a.env.PartyTargetWatchDB.showWorld, true); equal(a.frame.shown, true)
    local cases = {
        { "none", true, "主城/旅店（休息区）", "showResting" },
        { "party", false, "地下城（含大秘境）", "showDungeon" },
        { "raid", false, "团队副本", "showRaid" },
        { "scenario", false, "场景战役", "showScenario" },
        { "pvp", false, "战场", "showBattleground" }, { "arena", false, "竞技场", "showArena" },
    }
    for _, case in ipairs(cases) do
        a:scenario(case[1], case[2]); equal(a.frame.shown, true)
        a:click(case[3]); equal(a.env.PartyTargetWatchDB[case[4]], false); equal(a.frame.shown, false)
    end
    a:click("恢复默认"); equal(a.frame.shown, true)
    for _, case in ipairs(cases) do equal(a:button(case[3]):GetChecked(), true) end
end
tests["title drag saves position and lock prevents movement"] = function()
    local a = boot(); a:load()
    local handle
    for _, object in ipairs(a.objects) do
        if object.parent == a.frame and object.scripts.OnDragStart then handle = object; break end
    end
    assert(handle, "missing drag handle")
    handle.scripts.OnDragStart(handle); equal(a.frame.moving, true)
    a.frame:ClearAllPoints(); a.frame:SetPoint("CENTER", a.env.UIParent, "CENTER", 123, 456)
    handle.scripts.OnDragStop(handle)
    equal(a.frame.moving, false); equal(a.env.PartyTargetWatchDB.x, 123); equal(a.env.PartyTargetWatchDB.y, 456)
    a:command("lock"); handle.scripts.OnDragStart(handle); equal(a.frame.moving, false)
    a:command("unlock"); handle.scripts.OnDragStart(handle); equal(a.frame.moving, true)
end
tests["background alpha zero persists and only affects background layers"] = function()
    local a = boot({ backgroundAlpha = 0 }); a:load(); a:command("settings")
    equal(a.env.PartyTargetWatchDB.backgroundAlpha, 0); equal(a.frame.backdropColor[4], 0)
    equal(a.frame.borderColor[4], 0); equal(a.frame.alpha, 1)
    a.state.group, a.state.count, a.state.names.party1 = true, 1, "透明队员"
    a:event("GROUP_ROSTER_UPDATE")
    for _, row in ipairs(a:rows()) do
        equal((row.background.color[4] or 1) * row.background.alpha, 0)
        equal(row.member.alpha, 1); equal(row.target.alpha, 1); equal(row.targetMarker.alpha, 1)
        equal(row.member.color[4] or 1, 1); equal(row.target.color[4] or 1, 1)
    end
    a.globals.PartyTargetWatchBackgroundAlphaSlider:SetValue(1)
    equal(a.env.PartyTargetWatchDB.backgroundAlpha, 1); equal(a.frame.backdropColor[4], 1)
    assert(a.frame.borderColor[4] > 0)
    assert(a:rows()[2].background.color[4] * a:rows()[2].background.alpha > 0)
    equal(a.frame.alpha, 1); equal(a:rows()[2].target.alpha, 1)
    a.globals.PartyTargetWatchBackgroundAlphaSlider:SetValue(0)
    a:scenario("party", false); equal(a.frame.backdropColor[4], 0); equal(a.frame.borderColor[4], 0)
    local b = boot(a.env.PartyTargetWatchDB); b:load()
    equal(b.env.PartyTargetWatchDB.backgroundAlpha, 0); equal(b.frame.backdropColor[4], 0)
end
tests["background alpha invalid values and global reset restore default"] = function()
    for _, value in ipairs({ -0.1, 1.1, 0/0, math.huge, "0.5", {} }) do
        local a = boot({ backgroundAlpha = value }); a:load()
        equal(a.env.PartyTargetWatchDB.backgroundAlpha, 0.88); equal(a.frame.backdropColor[4], 0.88)
    end
    local a = boot({ backgroundAlpha = 0.4 }); a:load(); a:command("settings")
    equal(a.globals.PartyTargetWatchBackgroundAlphaSlider:GetValue(), 0.4)
    a:click("恢复默认")
    equal(a.env.PartyTargetWatchDB.backgroundAlpha, 0.88); equal(a.frame.backdropColor[4], 0.88)
    equal(a.globals.PartyTargetWatchBackgroundAlphaSlider:GetValue(), 0.88)
end
tests["monitor has no focus chat listener format editor or announcement entry point"] = function()
    local a = boot(); a:load()
    a.state.group, a.state.count, a.state.names.party1 = true, 1, "Member"
    a:event("GROUP_ROSTER_UPDATE")
    equal(a.env.PartyTargetWatch_AnnounceTarget, nil)
    equal(a.env.BINDING_NAME_PARTYTARGETWATCH_ANNOUNCE, nil)
    equal(a.namespace.App.Announce, nil)
    equal(a.namespace.Communication, nil)
    equal(a.namespace.App.ShowFormats, nil)
    for _, object in ipairs(a.objects) do
        for event in pairs(object.events) do
            assert(not event:find("CHAT_MSG", 1, true), "retired chat listener: " .. event)
            assert(not event:find("FOCUS", 1, true), "retired focus listener: " .. event)
        end
    end
    for _, row in ipairs(a:rows()) do
        equal(row.scripts.OnClick, nil, "member row must not announce on click")
        equal(row.focus, nil); equal(row.focusMarker, nil)
    end
    local found = pcall(function() return a:button("通报目标") end)
    equal(found, false, "removed announcement control is still present")
    for _, command in ipairs({ "announce", "call", "status", "formats" }) do a:command(command) end
    equal(a.globals.PartyTargetWatchFormatSettings, nil)
    a:command("settings")
    equal(a.globals.PartyTargetWatchFormatSettings, nil)
    a:command("test")
    for _, row in ipairs(a:rows()) do
        equal(row.scripts.OnClick, nil); equal(row.focus, nil); equal(row.focusMarker, nil)
    end
end
local count, names, failures = 0, {}, {}
for name in pairs(tests) do names[#names + 1] = name end
table.sort(names)
for _, name in ipairs(names) do
    local ok, failure = pcall(tests[name])
    if ok then count = count + 1; print("PASS " .. name)
    else failures[#failures + 1] = name .. ": " .. tostring(failure); print("FAIL " .. failures[#failures]) end
end
print(string.format("%d Lua 5.1 integration scenarios passed", count))
assert(#failures == 0, table.concat(failures, "\n"))
