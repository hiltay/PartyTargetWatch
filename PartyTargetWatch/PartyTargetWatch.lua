-- Independent group target display; secret values only go to supported UI sinks.
local addonName, ns = ...
local frame = CreateFrame("Frame", "PartyTargetWatchFrame", UIParent, "BackdropTemplate")
frame:Hide()
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:SetFrameStrata("MEDIUM")
local app = { frame = frame, rows = {}, units = {}, preview = false }
ns.App = app
local db, title, footer, lockButton, testButton
local initialized, elapsedSinceRefresh = false, 0
local headers = {}
local ROW_HEIGHT, TOP, BOTTOM = 24, 86, 28
local validPoints = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true,
    CENTER = true, RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }
local defaults = { point = "CENTER", relativePoint = "CENTER", x = -320, y = 100,
    scale = 1, locked = false, hidden = false, showWorld = true, showResting = true,
    showDungeon = true, showRaid = true, showScenario = true, showBattleground = true,
    showArena = true, showFocus = false, shareFocus = false, acceptFocusCalls = false,
    backgroundAlpha = 0.88 }
local sceneSettings = { world = "showWorld", resting = "showResting", party = "showDungeon",
    raid = "showRaid", scenario = "showScenario", pvp = "showBattleground", arena = "showArena" }
local sceneLabels = { world = "野外", resting = "主城/旅店（休息区）", party = "地下城",
    raid = "团队副本", scenario = "场景战役", pvp = "战场", arena = "竞技场" }
local function IsSecret(value) return issecretvalue and issecretvalue(value) end
function app.ValidNumber(value, low, high)
    return not IsSecret(value) and type(value) == "number" and value == value and value >= low and value <= high
end
function app.NewText(parent, font)
    local text = parent:CreateFontString(nil, "OVERLAY", font)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end
function app.Message(text) print("|cff66e6d4PartyTargetWatch|r: " .. text) end
function app.SyncSettings() if app.settings then app.settings.Sync() end end
local function InitializeDB()
    if type(PartyTargetWatchDB) ~= "table" then PartyTargetWatchDB = {} end
    db, app.db = PartyTargetWatchDB, PartyTargetWatchDB
    for key, value in pairs(defaults) do
        if IsSecret(db[key]) or type(db[key]) ~= type(value) then db[key] = value end
    end
    if not validPoints[db.point] then db.point = defaults.point end
    if not validPoints[db.relativePoint] then db.relativePoint = defaults.relativePoint end
    if not app.ValidNumber(db.x, -10000, 10000) then db.x = defaults.x end
    if not app.ValidNumber(db.y, -10000, 10000) then db.y = defaults.y end
    if not app.ValidNumber(db.scale, 0.6, 2) then db.scale = defaults.scale end
    if not app.ValidNumber(db.backgroundAlpha, 0, 1) then db.backgroundAlpha = defaults.backgroundAlpha end
end
function app.ApplyAppearance()
    -- Only background surfaces fade; readable text/icons retain their opacity.
    frame:SetBackdropColor(0.035, 0.055, 0.075, db.backgroundAlpha)
    frame:SetBackdropBorderColor(0.18, 0.4, 0.43, db.backgroundAlpha)
    for index, row in ipairs(app.rows) do
        row.background:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.05 * db.backgroundAlpha or 0)
    end
end
function app.RestorePosition()
    frame:ClearAllPoints()
    frame:SetScale(db.scale)
    frame:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
end
function app.SavePosition()
    frame:StopMovingOrSizing()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if not IsSecret(point) and not IsSecret(relativePoint) and validPoints[point] and validPoints[relativePoint]
        and app.ValidNumber(x, -10000, 10000) and app.ValidNumber(y, -10000, 10000) then
        db.point, db.relativePoint, db.x, db.y = point, relativePoint, x, y
    end
    app.SyncSettings()
end
function app.GetScene()
    local ok, inside, kind = pcall(IsInInstance)
    if ok and not IsSecret(inside) and not IsSecret(kind) and inside and sceneSettings[kind] then return kind end
    local restOK, resting = pcall(IsResting)
    if restOK and not IsSecret(resting) and resting then return "resting" end
    return "world"
end
function app.ApplyVisibility()
    local scene = app.GetScene()
    app.sceneLabel = sceneLabels[scene]
    if db.hidden or (not app.preview and not db[sceneSettings[scene]]) then frame:Hide() else frame:Show() end
    app.SyncSettings()
end
local function PublicBoolean(api, unit)
    local ok, value = pcall(api, unit)
    if not ok or IsSecret(value) then return nil end
    return not not value
end
local function SetUnitName(label, unit, fallback)
    local ok, name = pcall(UnitName, unit)
    if not ok then label:SetText("不可用")
    elseif IsSecret(name) then label:SetText(name)
    elseif name == nil or name == "" then label:SetText(fallback)
    else label:SetText(name) end
end
local function SetMarker(texture, index)
    texture:Hide()
    -- type() may inspect a secret's type, never its numeric contents.
    if type(index) ~= "number" then return end
    if not IsSecret(index) and (index < 1 or index > 8 or index % 1 ~= 0) then return end
    local ok = pcall(texture.SetSpriteSheetCell, texture, index, 4, 4)
    if ok then texture:Show() end
end
local function UpdateMarker(texture, unit)
    texture:Hide()
    local ok, index = pcall(GetRaidTargetIndex, unit)
    if ok then SetMarker(texture, index) end
end
local focusLabels = { disabled = "共享未开启", pending = "等待共享", stale = "共享已过期",
    none = "无焦点", restricted = "受游戏限制", unavailable = "不可用", offline = "离线" }
local function UpdateFocus(row, unit)
    row.focusMarker:Hide()
    if not db.showFocus then row.focus:SetText("") return end
    local focus = ns.Communication.GetFocus(unit)
    row.focus:SetTextColor(0.73, 0.82, 0.92)
    if focus.state == "declared" then
        if focus.hasDeclaredName then row.focus:SetText(focus.name)
        else row.focus:SetText("约定：" .. (focus.name or "未指定")) end
        row.focus:SetTextColor(1, 0.8, 0.35)
    elseif focus.name then row.focus:SetText(focus.name)
    else row.focus:SetText(focusLabels[focus.state] or "等待共享") end
    SetMarker(row.focusMarker, focus.marker)
end
local function UpdateRow(row, unit)
    SetUnitName(row.member, unit, unit)
    row.member:SetTextColor(0.86, 0.92, 1)
    row.target:SetTextColor(1, 1, 1)
    row.targetMarker:Hide()
    UpdateFocus(row, unit)
    if PublicBoolean(UnitIsConnected, unit) == false then
        row.target:SetText("离线") row.target:SetTextColor(0.55, 0.58, 0.62)
        row.focus:SetText(db.showFocus and "离线" or "") row.focusMarker:Hide()
        return
    end
    local target = unit == "player" and "target" or unit .. "target"
    local exists = PublicBoolean(UnitExists, target)
    if exists == false then
        row.target:SetText("无目标 / 不可见") row.target:SetTextColor(0.55, 0.58, 0.62)
    elseif exists == nil then row.target:SetText("不可用")
    else SetUnitName(row.target, target, "无目标 / 不可见") UpdateMarker(row.targetMarker, target) end
end
local demo = {
    { "战士（示例）", "训练假人", 1 }, { "牧师（示例）", "战士（示例）", 0 },
    { "法师（示例）", "训练假人", 1 }, { "猎人（示例）", "另一个目标", 4 },
    { "你（示例）", "无目标 / 不可见", 0 },
}
function app.RefreshTargets()
    if not initialized or not frame:IsShown() then return end
    if app.preview then
        for i, entry in ipairs(demo) do
            local row = app.rows[i]
            row.member:SetText(entry[1]) row.member:SetTextColor(0.65, 0.75, 0.85)
            row.target:SetText(entry[2]) row.target:SetTextColor(0.95, 0.8, 0.4)
            SetMarker(row.targetMarker, entry[3])
            row.focus:SetText(db.showFocus and (i == 2 and "约定：星星" or "示例焦点") or "")
            row.focus:SetTextColor(0.95, 0.8, 0.4)
            SetMarker(row.focusMarker, db.showFocus and 1 or nil)
        end
    else for i, unit in ipairs(app.units) do UpdateRow(app.rows[i], unit) end end
end
local function NewMarker(parent, x)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18) icon:SetPoint("LEFT", x, 0)
    icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons") icon:Hide()
    return icon
end
local function CreateRow(index)
    local row = CreateFrame("Frame", nil, frame)
    row:EnableMouse(true)
    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.background:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.05 * db.backgroundAlpha or 0)
    row.member = app.NewText(row, "GameFontHighlight")
    row.member:SetPoint("LEFT", 6, 0) row.member:SetWidth(126)
    row.arrow = app.NewText(row, "GameFontNormal")
    row.arrow:SetPoint("LEFT", 136, 0) row.arrow:SetText("→") row.arrow:SetTextColor(0.25, 0.75, 0.7)
    row.targetMarker = NewMarker(row, 155)
    row.target = app.NewText(row, "GameFontHighlight")
    row.target:SetPoint("LEFT", 178, 0) row.target:SetWidth(225)
    row.focusMarker = NewMarker(row, 422)
    row.focus = app.NewText(row, "GameFontHighlight")
    row.focus:SetPoint("LEFT", 445, 0) row.focus:SetWidth(178)
    row:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetText("队友目标与焦点声明")
        GameTooltip:AddLine("黄色名称或“约定”来自聊天声明，不代表已验证的实际焦点。", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    app.rows[index] = row
    return row
end
function app.RebuildRoster()
    if not initialized then return end
    local units = {}
    if IsInRaid() then
        for i = 1, math.min(40, GetNumGroupMembers()) do units[#units + 1] = "raid" .. i end
    else
        units[1] = "player"
        if IsInGroup() then
            for i = 1, math.min(4, GetNumSubgroupMembers()) do units[#units + 1] = "party" .. i end
        end
    end
    app.units = units
    ns.Communication.RebuildRoster(units)
    local count = app.preview and #demo or #units
    local columns = count > 20 and 2 or 1
    local perColumn = math.max(1, math.ceil(count / columns))
    local width = db.showFocus and 650 or 430
    frame:SetSize(width * columns, TOP + perColumn * ROW_HEIGHT + BOTTOM)
    for column = 1, 2 do
        local header = headers[column]
        if not header then
            header = { app.NewText(frame, "GameFontDisableSmall"),
                app.NewText(frame, "GameFontDisableSmall"), app.NewText(frame, "GameFontDisableSmall") }
            headers[column] = header
            header[1]:SetText("队友")
            header[2]:SetText("当前目标")
            header[3]:SetText("焦点 / 约定")
        end
        for index, x in ipairs({ 16, 165, 432 }) do
            local label = header[index]
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", x + (column - 1) * width, -68)
            if column <= columns and (index ~= 3 or db.showFocus) then label:Show() else label:Hide() end
        end
    end
    for i = 1, count do
        local row = app.rows[i] or CreateRow(i)
        local column, rowIndex = math.floor((i - 1) / perColumn), (i - 1) % perColumn
        row:SetSize(width - 20, ROW_HEIGHT) row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 10 + column * width, -TOP - rowIndex * ROW_HEIGHT)
        if db.showFocus then row.focus:Show() else row.focus:Hide() row.focusMarker:Hide() end
        row:Show()
    end
    for i = count + 1, #app.rows do app.rows[i]:Hide() end
    title:SetText(app.preview and "队友目标 · 示例预览" or "队友目标")
    testButton:SetText(app.preview and "结束预览" or "预览")
    lockButton:SetText(db.locked and "解锁" or "锁定")
    if app.preview then footer:SetText("示例数据 · 点击“结束预览”恢复实时监控")
    elseif not IsInGroup() then footer:SetText("未组队 · 当前显示自己的目标")
    else footer:SetText(#units .. " 名成员 · 黄色内容来自聊天声明，不代表实际焦点") end
    app.ApplyVisibility() app.RefreshTargets() app.SyncSettings()
end
function app.TogglePreview() app.preview = not app.preview db.hidden = false app.RebuildRoster() end
function app.Reset()
    ns.Communication.SetEnabled(false) ns.Communication.SetAcceptCalls(false)
    ns.Communication.ResetDeclarationFormats()
    for key, value in pairs(defaults) do db[key] = value end
    app.preview = false
    app.RestorePosition() app.ApplyAppearance() app.RebuildRoster()
    -- Reset saved formats without silently saving or replacing an open draft.
    if app.formatSettings and app.formatSettings:IsShown() then
        app.formatSettings.status:SetText("已恢复保存的内置格式；此处草稿未保存，关闭后重新打开可查看。")
    end
end
function app.ShowSettings()
    if not app.settings then app.settings = ns.CreateSettings(app) end
    app.settings:Show() app.SyncSettings()
end
function app.ShowFormats()
    if not app.formatSettings then app.formatSettings = ns.CreateFormatSettings(app) end
    if not app.formatSettings:IsShown() then app.formatSettings.LoadSaved() end
    app.formatSettings:Show()
end
local function NewButton(text, width, left, callback)
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(width, 23) button:SetPoint("TOPLEFT", left, -35)
    button:SetText(text) button:SetScript("OnClick", callback)
    return button
end
local function CreateUI()
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    app.ApplyAppearance()
    local handle = CreateFrame("Frame", nil, frame)
    handle:SetPoint("TOPLEFT", 0, 0) handle:SetPoint("TOPRIGHT", 0, 0) handle:SetHeight(32)
    handle:EnableMouse(true) handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function() if not db.locked then frame:StartMoving() end end)
    handle:SetScript("OnDragStop", app.SavePosition)
    title = app.NewText(handle, "GameFontNormal")
    title:SetPoint("LEFT", 12, 0) title:SetWidth(390) title:SetTextColor(0.4, 0.9, 0.83)
    footer = app.NewText(frame, "GameFontDisableSmall")
    footer:SetPoint("BOTTOMLEFT", 14, 9) footer:SetPoint("BOTTOMRIGHT", -12, 9)
    NewButton("设置", 58, 10, app.ShowSettings)
    testButton = NewButton("预览", 84, 76, app.TogglePreview)
    lockButton = NewButton("锁定", 58, 168, function()
        app.SavePosition() db.locked = not db.locked app.RebuildRoster()
    end)
end
local function HandleCommand(message)
    if not initialized then return end
    local command, argument = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "settings" or command == "config" then app.ShowSettings() return
    elseif command == "formats" then app.ShowFormats() return
    elseif command == "hide" then db.hidden = true
    elseif command == "show" or command == "" then db.hidden = false app.preview = false
    elseif command == "lock" or command == "unlock" then app.SavePosition() db.locked = command == "lock" db.hidden = false
    elseif command == "test" then app.TogglePreview() return
    elseif command == "reset" then app.Reset() return
    elseif command == "scale" then
        local scale = tonumber(argument)
        if not app.ValidNumber(scale, 0.6, 2) then app.Message("缩放范围：/ptw scale 0.6 到 2") return end
        db.scale = scale app.RestorePosition()
    else
        app.Message("/ptw settings 设置；formats 通报格式；show 显示；hide 隐藏；unlock 解锁拖动；lock 锁定；test 示例预览；reset 重置；scale 1 缩放。")
        return
    end
    app.RebuildRoster()
    if not db.hidden and not frame:IsShown() then app.Message("当前场景已设置为隐藏；/ptw settings 可修改。") end
end
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        InitializeDB() CreateUI() app.RestorePosition()
        initialized = true
        ns.Communication.Init(db, function() end)
        self:UnregisterEvent("ADDON_LOADED")
        for _, name in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "UNIT_TARGET",
            "PLAYER_TARGET_CHANGED", "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "ZONE_CHANGED_NEW_AREA",
            "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_UPDATE_RESTING" }) do self:RegisterEvent(name) end
        SLASH_PARTYTARGETWATCH1, SLASH_PARTYTARGETWATCH2 = "/ptw", "/partytargetwatch"
        SlashCmdList.PARTYTARGETWATCH = HandleCommand
        app.RebuildRoster() app.Message("已加载。/ptw settings 设置；/ptw help 查看命令。")
    elseif initialized then
        if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then app.RebuildRoster()
        elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED"
            or event == "ZONE_CHANGED_INDOORS" or event == "PLAYER_UPDATE_RESTING" then
            app.ApplyVisibility() app.RefreshTargets()
        end
        -- Unit event bursts never accelerate polling beyond five refreshes per second.
    end
end)
frame:SetScript("OnUpdate", function(_, elapsed)
    if not initialized then return end
    elapsedSinceRefresh = elapsedSinceRefresh + elapsed
    if elapsedSinceRefresh >= 0.2 then elapsedSinceRefresh = 0 app.RefreshTargets() end
end)
