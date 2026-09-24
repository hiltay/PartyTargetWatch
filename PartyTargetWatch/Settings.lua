local _, ns = ...

function ns.CreateSettings(app)
    local db = app.db
    local panel = CreateFrame("Frame", "PartyTargetWatchSettings", UIParent, "BackdropTemplate")
    panel:SetSize(540, 650)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    panel:SetBackdropColor(0.035, 0.055, 0.075, 0.98)
    panel:SetBackdropBorderColor(0.25, 0.7, 0.65, 1)
    UISpecialFrames[#UISpecialFrames + 1] = "PartyTargetWatchSettings"
    local function Text(text, x, y, font)
        local label = app.NewText(panel, font or "GameFontHighlight")
        label:SetPoint("TOPLEFT", x, y)
        label:SetText(text)
        return label
    end
    Text("队友目标 · 设置", 20, -18, "GameFontNormalLarge")
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() panel:Hide() end)
    local function Button(text, x, y, width, callback)
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(width, 25)
        button:SetPoint("TOPLEFT", x, y)
        button:SetText(text)
        button:SetScript("OnClick", callback)
        return button
    end
    local checks = {}
    local function Check(key, text, x, y, changed)
        local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        check:SetSize(26, 26)
        check:SetPoint("TOPLEFT", x, y)
        check.Text = check.Text or app.NewText(check, "GameFontHighlight")
        check.Text:ClearAllPoints()
        check.Text:SetPoint("LEFT", check, "RIGHT", 2, 0)
        check.Text:SetText(text)
        check:SetScript("OnClick", function(self)
            local value = not not self:GetChecked()
            -- Stateful setters must observe the previous saved value.
            if changed then changed(value) else db[key] = value end
            app.RebuildRoster()
        end)
        checks[key] = check
    end
    Text("显示场景", 22, -54, "GameFontNormal")
    Check("showWorld", "野外", 20, -78)
    Check("showResting", "主城/旅店（休息区）", 258, -78)
    Check("showDungeon", "地下城（含大秘境）", 20, -108)
    Check("showRaid", "团队副本", 258, -108)
    Check("showScenario", "场景战役", 20, -138)
    Check("showBattleground", "战场", 258, -138)
    Check("showArena", "竞技场", 20, -168)
    local scene = Text("", 258, -175, "GameFontDisableSmall")
    scene:SetWidth(260)
    Text("副本类型优先；示例预览忽略场景筛选。", 22, -207, "GameFontDisableSmall")
    Text("焦点信息", 22, -238, "GameFontNormal")
    Check("showFocus", "显示队友焦点列", 20, -260)
    Check("shareFocus", "启用焦点共享（需队友也启用）", 20, -290, ns.Communication.SetEnabled)
    Check("acceptFocusCalls", "记录聊天中的打断声明", 20, -320, ns.Communication.SetAcceptCalls)
    local info = Text("共享仅传输可读焦点；秘密值和受限通信无法绕过。\n队伍中说“我打断星星”会记录为约定；说“取消打断”清除。\n约定 5 分钟后失效，不能证明队友当前真的设置了该焦点。", 22, -354, "GameFontDisableSmall")
    info:SetWidth(496)
    info:SetWordWrap(true)
    info:SetHeight(48)
    local scaleLabel = Text("", 22, -418)
    local scale = CreateFrame("Slider", "PartyTargetWatchScaleSlider", panel)
    scale:SetPoint("TOPLEFT", 24, -445)
    scale:SetSize(490, 16)
    scale:SetOrientation("HORIZONTAL")
    scale:EnableMouse(true)
    scale:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    scale:GetThumbTexture():SetSize(24, 24)
    local track = scale:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", 0, 0)
    track:SetPoint("RIGHT", 0, 0)
    track:SetHeight(4)
    track:SetColorTexture(0.2, 0.4, 0.42, 1)
    scale:SetMinMaxValues(0.6, 2)
    scale:SetValueStep(0.05)
    scale:SetObeyStepOnDrag(true)
    Text("60%", 22, -467, "GameFontDisableSmall")
    Text("200%", 477, -467, "GameFontDisableSmall")
    Text("位置偏移 X / Y", 22, -494)
    local function Input(x)
        local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        box:SetSize(75, 24)
        box:SetPoint("TOPLEFT", x, -490)
        box:SetAutoFocus(false)
        box:SetMaxLetters(9)
        box:SetScript("OnEscapePressed", box.ClearFocus)
        return box
    end
    local xInput, yInput = Input(145), Input(235)
    local status = Text("正值向右 / 向上；也可以解锁后拖动窗口标题。", 22, -526, "GameFontDisableSmall")
    status:SetWidth(500)
    local function ApplyPosition()
        local x, y = tonumber(xInput:GetText()), tonumber(yInput:GetText())
        if not app.ValidNumber(x, -10000, 10000) or not app.ValidNumber(y, -10000, 10000) then
            status:SetText("请输入 -10000 到 10000 之间的位置数值。") return
        end
        db.x, db.y = x, y
        app.RestorePosition()
        xInput:ClearFocus() yInput:ClearFocus()
        status:SetText("位置已保存。")
    end
    Button("应用位置", 333, -490, 92, ApplyPosition)
    xInput:SetScript("OnEnterPressed", ApplyPosition)
    yInput:SetScript("OnEnterPressed", ApplyPosition)
    local visibility = Button("", 22, -556, 154, function() db.hidden = not db.hidden app.RebuildRoster() end)
    local lock = Button("", 193, -556, 154, function()
        app.SavePosition() db.locked = not db.locked app.RebuildRoster()
    end)
    local test = Button("", 364, -556, 154, app.TogglePreview)
    Button("窗口居中", 22, -605, 154, function()
        db.point, db.relativePoint, db.x, db.y = "CENTER", "CENTER", 0, 0
        db.hidden = false app.RestorePosition() app.RebuildRoster()
    end)
    Button("恢复默认", 193, -605, 154, app.Reset)
    Button("完成", 364, -605, 154, function() panel:Hide() end)
    local syncing = false
    panel.Sync = function()
        if not panel:IsShown() then return end
        syncing = true
        for key, check in pairs(checks) do check:SetChecked(db[key]) end
        scale:SetValue(db.scale)
        scaleLabel:SetText("整体大小：" .. math.floor(db.scale * 100 + 0.5) .. "%")
        xInput:SetText(string.format("%.1f", db.x))
        yInput:SetText(string.format("%.1f", db.y))
        scene:SetText("当前：" .. (app.sceneLabel or "野外"))
        visibility:SetText(db.hidden and "显示监控窗口" or "隐藏监控窗口")
        lock:SetText(db.locked and "解锁位置" or "锁定位置")
        test:SetText(app.preview and "结束示例预览" or "显示示例预览")
        syncing = false
    end
    scale:SetScript("OnValueChanged", function(_, value)
        if syncing or not app.ValidNumber(value, 0.6, 2) then return end
        db.scale = math.floor(value * 100 + 0.5) / 100
        app.RestorePosition()
        scaleLabel:SetText("整体大小：" .. math.floor(db.scale * 100 + 0.5) .. "%")
    end)
    panel:SetScript("OnShow", panel.Sync)
    return panel
end
