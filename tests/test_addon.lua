-- Behavioral integration tests against a small, explicit WoW API mock.
-- This cannot reproduce engine secret values, protection/taint, or rendering.
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function boot(saved)
    local objects, globals = {}, {}
    local state = { group = false, raid = false, count = 0, instanceType = "none", resting = false,
        names = { player = "自己", target = "训练假人" }, offline = {}, errors = {}, secrets = {},
        markers = {}, focuses = {}, announcements = {}, nameCalls = 0, now = 0, secretTypes = {}, existsResults = {},
        rosterRebuilds = 0, enabledCalls = {}, acceptCalls = {}, transmitted = {} }
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
    function methods:SetText(text) self.text = text end
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
    function methods:SetScrollChild(value) self.scrollChild = value end
    for _, name in ipairs({ "SetClampedToScreen", "SetMovable", "SetFrameStrata", "SetJustifyH", "SetWordWrap",
        "SetAllPoints", "SetColorTexture", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
        "EnableMouse", "RegisterForDrag", "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag", "SetOrientation",
        "SetAutoFocus", "SetMaxLetters", "ClearFocus", "SetFrameLevel", "SetJustifyV", "RegisterForClicks",
        "SetNormalTexture", "SetPushedTexture", "SetHighlightTexture", "SetDisabledTexture", "SetFontObject",
        "SetTextInsets", "SetNumeric", "EnableMouseWheel", "SetResizable", "SetResizeBounds" }) do methods[name] = function() end end

    local env = setmetatable({ PartyTargetWatchDB = saved, SlashCmdList = {}, UISpecialFrames = {}, print = function() end }, { __index = _G })
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
    env.GetTime = function() return state.now end
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
    env.UnitFullName = env.UnitName
    env.UnitIsUnit = function(left, right) return left == right end
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
    env.SendChatMessage = function(...) state.transmitted[#state.transmitted + 1] = { ... } end
    env.C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end,
        SendAddonMessage = function(...) state.transmitted[#state.transmitted + 1] = { ... } end }
    local namespace = {}
    local communication = {
        Init = function(db, notify, onChanged) state.commDB, state.notify, state.onChanged = db, notify, onChanged end,
        RebuildRoster = function() state.rosterRebuilds = state.rosterRebuilds + 1 end,
        GetFocus = function(unit) return state.focuses[unit] or { state = "pending" } end,
        SetEnabled = function(value)
            -- The real module ignores unchanged settings; the UI must let the
            -- setter observe the previous value so handshake/cache work runs.
            if state.commDB.shareFocus == value then return end
            state.enabledCalls[#state.enabledCalls + 1] = value
            state.commDB.shareFocus = value
        end,
        SetAcceptCalls = function(value)
            if state.commDB.acceptFocusCalls == value then return end
            state.acceptCalls[#state.acceptCalls + 1] = value
            state.commDB.acceptFocusCalls = value
        end,
        Announce = function(unit) state.announcements[#state.announcements + 1] = unit; return true end,
    }
    for _, module in ipairs(ADDON_SOURCES) do
        local chunk = assert(loadstring(module.source, "@" .. module.name))
        setfenv(chunk, env)
        chunk("PartyTargetWatch", namespace)
        if module.name == "Communication.lua" then namespace.Communication = communication end
    end
    local app = { state = state, env = env, globals = globals, objects = objects,
        frame = globals.PartyTargetWatchFrame, namespace = namespace }
    function app:event(event, ...)
        for _, value in ipairs(objects) do
            if value.events[event] and value.scripts.OnEvent then value.scripts.OnEvent(value, event, ...) end
        end
    end
    function app:tick(elapsed)
        state.now = state.now + elapsed
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
    assert(a.state.commDB == a.env.PartyTargetWatchDB, "shared DB not passed to communication")
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
    local a = boot(); a:load()
    a.state.raid, a.state.count = true, 40
    for i = 1, 40 do a.state.names["raid" .. i] = "R" .. i; a.state.names["raid" .. i .. "target"] = "T" .. i end
    a:event("GROUP_ROSTER_UPDATE")
    equal(#a:rows(), 40)
    for i, row in ipairs(a:rows()) do equal(row.member.text, "R" .. i); equal(row.target.text, "T" .. i) end
    local raidWidth = a.frame.width
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
tests["corrupt saved settings are normalized"] = function()
    for _, saved in ipairs({ 1, "broken", { point = "INVALID", relativePoint = false, x = 0/0,
        y = math.huge, scale = -100, hidden = "bad", locked = {},
        showFocus = "yes", shareFocus = {}, showWorld = "no", acceptFocusCalls = 1 } }) do
        local a = boot(saved); a:load()
        equal(a.frame.shown, true); equal(a.frame.scale, 1)
        equal(a.env.PartyTargetWatchDB.point, "CENTER")
        equal(a.env.PartyTargetWatchDB.showFocus, false)
        equal(a.env.PartyTargetWatchDB.shareFocus, false)
        equal(a.env.PartyTargetWatchDB.acceptFocusCalls, false)
        for _, key in ipairs({ "showWorld", "showResting", "showDungeon", "showRaid", "showScenario", "showBattleground", "showArena" }) do
            equal(a.env.PartyTargetWatchDB[key], true, key)
        end
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
tests["focus column sharing and declaration options use settings callbacks"] = function()
    local a = boot(); a.state.focuses.player = { state = "ok", name = "真实焦点", marker = 4 }
    a:load(); equal(a:rows()[1].focus.shown, false)
    a:command("settings"); a:click("显示队友焦点列"); a:tick(0.21)
    equal(a.env.PartyTargetWatchDB.showFocus, true); equal(a:rows()[1].focus.shown, true)
    equal(a:rows()[1].focus.text, "真实焦点")
    a:click("启用焦点共享（需队友也启用）")
    equal(a.env.PartyTargetWatchDB.shareFocus, true); equal(a.state.enabledCalls[#a.state.enabledCalls], true)
    a:click("记录聊天中的打断声明"); equal(a.env.PartyTargetWatchDB.acceptFocusCalls, true)
    equal(a.state.acceptCalls[#a.state.acceptCalls], true)
    a:click("记录聊天中的打断声明"); equal(a.env.PartyTargetWatchDB.acceptFocusCalls, false)
    equal(a.state.acceptCalls[#a.state.acceptCalls], false)
    a:click("显示队友焦点列"); equal(a:rows()[1].focus.shown, false)
    a:click("启用焦点共享（需队友也启用）")
    equal(a.env.PartyTargetWatchDB.shareFocus, false); equal(a.state.enabledCalls[#a.state.enabledCalls], false)
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
tests["focus status changes cannot leave old names or marker icons"] = function()
    local a = boot({ showFocus = true }); a:load()
    for _, state in ipairs({ "none", "pending", "restricted", "unavailable", "stale", "disabled" }) do
        a.state.focuses.player = { state = "ok", name = "之前的焦点", marker = 8 }; a:tick(0.21)
        equal(a:rows()[1].focus.text, "之前的焦点")
        a.state.focuses.player = { state = state }; a:tick(0.21)
        assert(a:rows()[1].focus.text ~= "之前的焦点", "stale focus name for " .. state)
        local icon = a:rows()[1].focusMarker
        assert(not icon.shown or icon.texture == nil, "stale focus icon for " .. state)
    end
end
tests["reset lets communication setters observe active settings before defaulting"] = function()
    local a = boot({ shareFocus = true, acceptFocusCalls = true }); a:load()
    a:command("settings"); a:click("恢复默认")
    equal(a.env.PartyTargetWatchDB.shareFocus, false)
    equal(a.env.PartyTargetWatchDB.acceptFocusCalls, false)
    equal(a.state.enabledCalls[#a.state.enabledCalls], false, "reset skipped sharing transition")
    equal(a.state.acceptCalls[#a.state.acceptCalls], false, "reset skipped declaration transition")
    equal(a:button("启用焦点共享（需队友也启用）"):GetChecked(), false)
    equal(a:button("记录聊天中的打断声明"):GetChecked(), false)
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
tests["party focus comes from communication for the matching member token"] = function()
    local a = boot({ showFocus = true, shareFocus = true }); a:load()
    a.state.group, a.state.count = true, 2
    a.state.names.party1, a.state.names.party2 = "共享队员", "声明队员"
    a.state.focuses.player = { state = "ok", name = "本地焦点", marker = 8 }
    a.state.focuses.party1 = { state = "ok", name = "队友共享焦点", marker = 4 }
    a.state.focuses.party2 = { state = "declared", name = "星星", marker = 1 }
    a:event("GROUP_ROSTER_UPDATE"); a:tick(0.21)
    equal(a:rows()[1].focus.text, "本地焦点")
    equal(a:rows()[2].focus.text, "队友共享焦点")
    local declaration = a:rows()[3].focus.text
    assert(type(declaration) == "string" and declaration:find("星星", 1, true), "missing declared focus marker")
    assert(declaration:find("约定", 1, true) or declaration:find("声明", 1, true),
        "declaration is not distinguished from a real focus")
end
tests["announcements require explicit button slash or key actions"] = function()
    local a = boot(); a:load()
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED", "UNIT_TARGET", "RAID_TARGET_UPDATE" }) do
        a:event(event, "player"); a:tick(0.21)
    end
    equal(#a.state.announcements, 0); equal(#a.state.transmitted, 0)
    a:click("通报目标"); equal(#a.state.announcements, 1)
    a:command("announce"); equal(#a.state.announcements, 2)
    a.env.PartyTargetWatch_AnnounceTarget(); equal(#a.state.announcements, 3)
    for _, unit in ipairs(a.state.announcements) do equal(unit, "player") end
    a.state.group, a.state.count, a.state.names.party1 = true, 1, "点击队员"
    a:event("GROUP_ROSTER_UPDATE")
    local row = a:rows()[2]; row.scripts.OnClick(row, "LeftButton")
    equal(#a.state.announcements, 4); equal(a.state.announcements[4], "party1")
    a:command("test")
    a:click("通报目标"); a:command("announce"); a.env.PartyTargetWatch_AnnounceTarget()
    local demoRow = a:rows()[1]; demoRow.scripts.OnClick(demoRow, "LeftButton")
    equal(#a.state.announcements, 4, "preview must never announce fabricated targets")
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
