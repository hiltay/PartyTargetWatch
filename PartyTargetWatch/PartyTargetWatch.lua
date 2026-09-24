-- PartyTargetWatch: an independent, display-only group target monitor.
local addonName = ...
local frame = CreateFrame("Frame", "PartyTargetWatchFrame", UIParent, "BackdropTemplate")
frame:Hide()
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:SetFrameStrata("MEDIUM")

local db, title, footer, lockButton, testButton
local rows, units = {}, {}
local initialized, preview = false, false
local settingsPanel
local SyncSettings = function() end
local elapsedSinceRefresh = 0
local COLUMN_WIDTH, ROW_HEIGHT, TOP, BOTTOM = 390, 24, 38, 28
local validPoints = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
    RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}
local defaults = { point = "CENTER", relativePoint = "CENTER", x = -320, y = 100,
    scale = 1, locked = false, hidden = false }

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function ValidNumber(value, low, high)
    return type(value) == "number" and value == value and value >= low and value <= high
end

local function InitializeDB()
    if type(PartyTargetWatchDB) ~= "table" then PartyTargetWatchDB = {} end
    db = PartyTargetWatchDB
    for key, value in pairs(defaults) do
        if type(db[key]) ~= type(value) then db[key] = value end
    end
    if not validPoints[db.point] then db.point = defaults.point end
    if not validPoints[db.relativePoint] then db.relativePoint = defaults.relativePoint end
    if not ValidNumber(db.x, -10000, 10000) then db.x = defaults.x end
    if not ValidNumber(db.y, -10000, 10000) then db.y = defaults.y end
    if not ValidNumber(db.scale, 0.6, 2) then db.scale = defaults.scale end
end

local function RestorePosition()
    frame:ClearAllPoints()
    frame:SetScale(db.scale)
    frame:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
end

local function SavePosition()
    frame:StopMovingOrSizing()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if validPoints[point] and validPoints[relativePoint]
        and ValidNumber(x, -10000, 10000) and ValidNumber(y, -10000, 10000) then
        db.point, db.relativePoint, db.x, db.y = point, relativePoint, x, y
    end
    SyncSettings()
end

local function NewText(parent, font)
    local text = parent:CreateFontString(nil, "OVERLAY", font)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end

-- nil means unavailable, rather than turning an API failure into "no target".
local function PublicBoolean(api, unit)
    local ok, value = pcall(api, unit)
    if not ok or IsSecret(value) then return nil end
    return not not value
end

local function SetUnitName(label, unit, fallback)
    local ok, name = pcall(UnitName, unit)
    if not ok then
        label:SetText("不可用")
    elseif IsSecret(name) then
        -- Secret names can be rendered but must not be inspected or concatenated.
        label:SetText(name)
    elseif name == nil or name == "" then
        label:SetText(fallback)
    else
        label:SetText(name)
    end
end

local function UpdateRow(row, unit)
    SetUnitName(row.member, unit, unit)
    row.member:SetTextColor(0.86, 0.92, 1)
    row.target:SetTextColor(1, 1, 1)

    if PublicBoolean(UnitIsConnected, unit) == false then
        row.target:SetText("离线")
        row.target:SetTextColor(0.55, 0.58, 0.62)
        return
    end

    -- Tokens are addon-owned strings; names and GUIDs are never used as keys.
    local targetUnit = unit == "player" and "target" or unit .. "target"
    if PublicBoolean(UnitExists, targetUnit) == false then
        row.target:SetText("无目标 / 不可见")
        row.target:SetTextColor(0.55, 0.58, 0.62)
    else
        SetUnitName(row.target, targetUnit, "无目标 / 不可见")
    end
end

local demo = {
    { "战士（示例）", "训练假人" },
    { "牧师（示例）", "战士（示例）" },
    { "法师（示例）", "训练假人" },
    { "猎人（示例）", "另一个目标" },
    { "你（示例）", "无目标 / 不可见" },
}

local function RefreshTargets()
    if not initialized or db.hidden then return end
    if preview then
        for i, entry in ipairs(demo) do
            rows[i].member:SetText(entry[1])
            rows[i].member:SetTextColor(0.65, 0.75, 0.85)
            rows[i].target:SetText(entry[2])
            rows[i].target:SetTextColor(0.95, 0.8, 0.4)
        end
    else
        for i, unit in ipairs(units) do UpdateRow(rows[i], unit) end
    end
end

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, frame)
    row:SetSize(COLUMN_WIDTH - 20, ROW_HEIGHT)
    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.background:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.045 or 0)
    row.member = NewText(row, "GameFontHighlight")
    row.member:SetPoint("LEFT", 6, 0)
    row.member:SetWidth(126)
    row.arrow = NewText(row, "GameFontNormal")
    row.arrow:SetPoint("LEFT", 136, 0)
    row.arrow:SetText("→")
    row.arrow:SetTextColor(0.25, 0.75, 0.7)
    row.target = NewText(row, "GameFontHighlight")
    row.target:SetPoint("LEFT", 156, 0)
    row.target:SetWidth(COLUMN_WIDTH - 184)
    rows[index] = row
    return row
end

local function RebuildRoster()
    if not initialized then return end
    units = {}
    if IsInRaid() then
        for i = 1, math.min(40, GetNumGroupMembers()) do units[#units + 1] = "raid" .. i end
    else
        units[1] = "player"
        if IsInGroup() then
            for i = 1, math.min(4, GetNumSubgroupMembers()) do units[#units + 1] = "party" .. i end
        end
    end

    local count = preview and #demo or #units
    local columns = count > 20 and 2 or 1
    local perColumn = math.max(1, math.ceil(count / columns))
    frame:SetSize(COLUMN_WIDTH * columns, TOP + perColumn * ROW_HEIGHT + BOTTOM)
    for i = 1, count do
        local row = rows[i] or CreateRow(i)
        local column = math.floor((i - 1) / perColumn)
        local rowIndex = (i - 1) % perColumn
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 10 + column * COLUMN_WIDTH, -TOP - rowIndex * ROW_HEIGHT)
        row:Show()
    end
    for i = count + 1, #rows do rows[i]:Hide() end

    title:SetText(preview and "队友目标 · 示例预览" or "队友目标")
    testButton:SetText(preview and "结束预览" or "预览")
    lockButton:SetText(db.locked and "解锁" or "锁定")
    if preview then
        footer:SetText("示例数据 · 点击“结束预览”恢复实时监控")
    elseif not IsInGroup() then
        footer:SetText("未组队 · 当前显示自己的目标")
    else
        footer:SetText(#units .. " 名成员 · 当前选中的目标")
    end
    if db.hidden then frame:Hide() else frame:Show() end
    RefreshTargets()
    SyncSettings()
end

local function TogglePreview()
    preview = not preview
    db.hidden = false
    RebuildRoster()
end

local function NewButton(text, width, rightOffset, callback)
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(width, 23)
    button:SetPoint("TOPRIGHT", rightOffset, -7)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

local function ShowSettings()
    if not settingsPanel then
        local panel = CreateFrame("Frame", "PartyTargetWatchSettings", UIParent, "BackdropTemplate")
        panel:SetSize(440, 350)
        panel:SetPoint("CENTER")
        panel:SetFrameStrata("DIALOG")
        panel:SetClampedToScreen(true)
        panel:EnableMouse(true)
        panel:SetMovable(true)
        panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", panel.StartMoving)
        panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
        panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        panel:SetBackdropColor(0.035, 0.055, 0.075, 0.98)
        panel:SetBackdropBorderColor(0.25, 0.7, 0.65, 1)
        local heading = NewText(panel, "GameFontNormalLarge")
        heading:SetPoint("TOPLEFT", 20, -18)
        heading:SetText("队友目标 · 设置")
        local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        close:SetScript("OnClick", function() panel:Hide() end)
        UISpecialFrames[#UISpecialFrames + 1] = "PartyTargetWatchSettings"

        local scaleLabel = NewText(panel, "GameFontHighlight")
        scaleLabel:SetPoint("TOPLEFT", 22, -60)
        local scale = CreateFrame("Slider", "PartyTargetWatchScaleSlider", panel)
        scale:SetPoint("TOPLEFT", 24, -87)
        scale:SetSize(388, 16)
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
        scale.Low = NewText(scale, "GameFontDisableSmall")
        scale.High = NewText(scale, "GameFontDisableSmall")
        scale.Low:SetPoint("TOPLEFT", scale, "BOTTOMLEFT", 0, -4)
        scale.High:SetPoint("TOPRIGHT", scale, "BOTTOMRIGHT", 0, -4)
        scale.Low:SetText("60%")
        scale.High:SetText("200%")

        local positionLabel = NewText(panel, "GameFontHighlight")
        positionLabel:SetPoint("TOPLEFT", 22, -135)
        positionLabel:SetText("位置偏移：横向 X / 纵向 Y")
        local function PositionInput(x)
            local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
            box:SetSize(80, 24)
            box:SetPoint("TOPLEFT", x, -161)
            box:SetAutoFocus(false)
            box:SetMaxLetters(9)
            box:SetScript("OnEscapePressed", box.ClearFocus)
            return box
        end
        local xInput, yInput = PositionInput(28), PositionInput(132)
        local hint = NewText(panel, "GameFontDisableSmall")
        hint:SetPoint("TOPLEFT", 22, -195)
        hint:SetWidth(400)
        local status = NewText(panel, "GameFontNormalSmall")
        status:SetPoint("TOPLEFT", 22, -215)
        status:SetWidth(400)

        local function Button(text, x, y, width, callback)
            local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
            button:SetSize(width, 25)
            button:SetPoint("TOPLEFT", x, y)
            button:SetText(text)
            button:SetScript("OnClick", callback)
            return button
        end
        local function ApplyPosition()
            local x, y = tonumber(xInput:GetText()), tonumber(yInput:GetText())
            if not ValidNumber(x, -10000, 10000) or not ValidNumber(y, -10000, 10000) then
                status:SetText("请输入 -10000 到 10000 之间的位置数值。")
                return
            end
            db.x, db.y = x, y
            RestorePosition()
            xInput:ClearFocus()
            yInput:ClearFocus()
            status:SetText("位置已保存；也可以解锁后直接拖动监控窗口标题。")
        end
        Button("应用位置", 238, -161, 90, ApplyPosition)
        xInput:SetScript("OnEnterPressed", ApplyPosition)
        yInput:SetScript("OnEnterPressed", ApplyPosition)
        local visibility = Button("", 22, -247, 120, function()
            db.hidden = not db.hidden
            RebuildRoster()
        end)
        local lock = Button("", 157, -247, 120, function()
            SavePosition()
            db.locked = not db.locked
            RebuildRoster()
        end)
        local test = Button("", 292, -247, 126, TogglePreview)
        Button("窗口居中", 22, -292, 120, function()
            db.point, db.relativePoint, db.x, db.y = "CENTER", "CENTER", 0, 0
            db.hidden = false
            RestorePosition()
            RebuildRoster()
        end)
        Button("恢复默认", 157, -292, 120, function()
            for key, value in pairs(defaults) do db[key] = value end
            preview = false
            RestorePosition()
            RebuildRoster()
            status:SetText("已恢复本插件的默认大小、位置和显示设置。")
        end)
        Button("完成", 292, -292, 126, function() panel:Hide() end)

        local syncing = false
        SyncSettings = function()
            if not panel:IsShown() then return end
            syncing = true
            scale:SetValue(db.scale)
            scaleLabel:SetText("整体大小：" .. math.floor(db.scale * 100 + 0.5) .. "%")
            xInput:SetText(string.format("%.1f", db.x))
            yInput:SetText(string.format("%.1f", db.y))
            hint:SetText("正值向右 / 向上；相对锚点：" .. db.point)
            visibility:SetText(db.hidden and "显示监控窗口" or "隐藏监控窗口")
            lock:SetText(db.locked and "解锁位置" or "锁定位置")
            test:SetText(preview and "结束示例预览" or "显示示例预览")
            syncing = false
        end
        scale:SetScript("OnValueChanged", function(_, value)
            if syncing then return end
            db.scale = math.floor(value * 100 + 0.5) / 100
            RestorePosition()
            scaleLabel:SetText("整体大小：" .. math.floor(db.scale * 100 + 0.5) .. "%")
        end)
        panel:SetScript("OnShow", function() SyncSettings() end)
        settingsPanel = panel
    end
    settingsPanel:Show()
    SyncSettings()
end

local function CreateUI()
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(0.035, 0.055, 0.075, 0.88)
    frame:SetBackdropBorderColor(0.18, 0.4, 0.43, 0.9)
    local handle = CreateFrame("Frame", nil, frame)
    handle:SetPoint("TOPLEFT", 0, 0)
    handle:SetPoint("TOPRIGHT", -202, 0)
    handle:SetHeight(34)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if not db.locked then frame:StartMoving() end
    end)
    handle:SetScript("OnDragStop", SavePosition)
    title = NewText(handle, "GameFontNormal")
    title:SetPoint("LEFT", 12, 0)
    title:SetWidth(174)
    title:SetTextColor(0.4, 0.9, 0.83)
    footer = NewText(frame, "GameFontDisableSmall")
    footer:SetPoint("BOTTOMLEFT", 14, 9)
    footer:SetPoint("BOTTOMRIGHT", -12, 9)
    lockButton = NewButton("锁定", 56, -10, function()
        SavePosition()
        db.locked = not db.locked
        RebuildRoster()
    end)
    testButton = NewButton("预览", 76, -70, TogglePreview)
    NewButton("设置", 48, -150, ShowSettings)
end

local function Message(text)
    print("|cff66e6d4PartyTargetWatch|r: " .. text)
end

local function HandleCommand(message)
    if not initialized then return end
    local command, argument = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "settings" or command == "config" then
        ShowSettings()
        return
    elseif command == "hide" then
        db.hidden = true
    elseif command == "show" or command == "" then
        db.hidden = false
        preview = false
    elseif command == "lock" or command == "unlock" then
        SavePosition()
        db.locked = command == "lock"
        db.hidden = false
    elseif command == "test" then
        TogglePreview()
        return
    elseif command == "reset" then
        SavePosition()
        for key, value in pairs(defaults) do db[key] = value end
        preview = false
        RestorePosition()
    elseif command == "scale" then
        local scale = tonumber(argument)
        if not ValidNumber(scale, 0.6, 2) then Message("缩放范围：/ptw scale 0.6 到 2") return end
        db.scale = scale
        RestorePosition()
    else
        Message("/ptw settings 设置；show 显示；hide 隐藏；unlock 解锁拖动；lock 锁定；test 示例预览；reset 重置；scale 1 缩放。")
        return
    end
    RebuildRoster()
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        InitializeDB()
        CreateUI()
        RestorePosition()
        initialized = true
        self:UnregisterEvent("ADDON_LOADED")
        for _, name in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "UNIT_TARGET",
            "PLAYER_TARGET_CHANGED", "UNIT_NAME_UPDATE", "UNIT_CONNECTION" }) do
            self:RegisterEvent(name)
        end
        SLASH_PARTYTARGETWATCH1 = "/ptw"
        SLASH_PARTYTARGETWATCH2 = "/partytargetwatch"
        SlashCmdList.PARTYTARGETWATCH = HandleCommand
        RebuildRoster()
        Message("已加载。拖动标题移动；/ptw 显示窗口，/ptw help 查看命令。")
    elseif not initialized then
        return
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        RebuildRoster()
    else
        -- Coalesce bursts of unit events; the timer also catches missed changes.
        elapsedSinceRefresh = 0.2
    end
end)

frame:SetScript("OnUpdate", function(_, elapsed)
    if not initialized then return end
    elapsedSinceRefresh = elapsedSinceRefresh + elapsed
    if elapsedSinceRefresh >= 0.2 then
        elapsedSinceRefresh = 0
        RefreshTargets()
    end
end)
