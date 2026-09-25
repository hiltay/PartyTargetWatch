local _, ns = ...

local minimapButton, settingsCategory, retryFrame
local TITLE = "PartyTargetWatch 队友目标"
local ICON = "Interface\\Icons\\Ability_Hunter_SniperShot"

local function OpenWindow(callback)
    if SettingsPanel and SettingsPanel:IsShown() and type(HideUIPanel) == "function" then
        HideUIPanel(SettingsPanel)
    end
    callback()
end

local function CreateMinimapButton(app)
    if minimapButton or not Minimap then return end
    local button = CreateFrame("Button", "PartyTargetWatchMinimapButton", Minimap)
    minimapButton = button
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", 6, 6)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    -- Minimap collectors may reparent, resize and anchor the button and icon.
    -- Keep all positioning here; never restore it from OnShow or OnUpdate.
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then OpenWindow(app.ShowFormats)
        elseif mouseButton == "LeftButton" then OpenWindow(app.ShowSettings) end
    end)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(TITLE)
        GameTooltip:AddLine("左键：打开插件设置", 1, 1, 1)
        GameTooltip:AddLine("右键：编辑接收格式", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function RegisterSettingsCategory(app)
    if settingsCategory then return true end
    if not Settings or type(Settings.RegisterCanvasLayoutCategory) ~= "function"
        or type(Settings.RegisterAddOnCategory) ~= "function" then return false end

    local panel = CreateFrame("Frame", "PartyTargetWatchBlizzardSettings", UIParent)
    panel:Hide()
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(TITLE)
    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", 16, -50)
    description:SetPoint("TOPRIGHT", -16, -50)
    description:SetJustifyH("LEFT")
    description:SetText("监控队友的当前目标，并接收聊天中的焦点通报。\n使用下方按钮调整显示、背景透明度和接收格式，也可输入 /ptw settings。")

    local function Button(text, y, callback)
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(180, 28)
        button:SetPoint("TOPLEFT", 16, y)
        button:SetText(text)
        button:SetScript("OnClick", function() OpenWindow(callback) end)
    end
    Button("打开设置", -115, app.ShowSettings)
    Button("编辑接收格式", -155, app.ShowFormats)
    settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, TITLE)
    Settings.RegisterAddOnCategory(settingsCategory)
    return true
end

function ns.InitializeIntegration(app)
    if not app or not app.db then return end
    CreateMinimapButton(app)
    if RegisterSettingsCategory(app) then
        if retryFrame then retryFrame:UnregisterEvent("ADDON_LOADED") end
        return
    end
    if retryFrame then return end
    retryFrame = CreateFrame("Frame")
    retryFrame:RegisterEvent("ADDON_LOADED")
    retryFrame:SetScript("OnEvent", function(_, _, addonName)
        if addonName == "Blizzard_Settings" or addonName == "Blizzard_Settings_Shared" then
            ns.InitializeIntegration(app)
        end
    end)
end
