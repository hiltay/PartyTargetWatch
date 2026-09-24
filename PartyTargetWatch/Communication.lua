-- Public group chat is sent only by Announce, called from a user action.
-- Optional focus sharing sends public snapshots, never secret values or GUIDs.
local addonName, ns = ...
local Communication = {}
ns.Communication = Communication

local PREFIX, MAX_NAME, MAX_PACKET = "PTWFocus1", 96, 112
local SEND_INTERVAL, HEARTBEAT, TTL, CHAT_INTERVAL = 1, 4, 12, 3
local DECLARATION_TTL = 300
local db, notify, onChanged, eventFrame, prefixReady
local byUnit, members, received = {}, {}, {}
local declarations = {}
local rosterUnits = { "player" }
local ownID, rosterSignature
local nextSend, nextChat, nextPoll, lastSent = 0, 0, 0, -100
local stateDirty, queryPending, disablePending = false, false, false
local restrictionPending = false
local lastOwnPacket, lastRestriction

local function Secret(value)
    return issecretvalue and issecretvalue(value)
end

local function PublicFlag(api, ...)
    if type(api) ~= "function" then return nil end
    local ok, value = pcall(api, ...)
    if not ok or Secret(value) or type(value) ~= "boolean" then return nil end
    return value
end

local function Now()
    return GetTime()
end

local function Changed()
    if onChanged then onChanged() end
end

local function CleanName(value)
    if Secret(value) or type(value) ~= "string" then return nil end
    -- Strip chat markup before removing all remaining delimiter/control bytes.
    value = value:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:gsub("[%c|{}]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    if value == "" or #value > MAX_NAME then return nil end
    return value
end

local function LocalRealm()
    if type(GetNormalizedRealmName) ~= "function" then return nil end
    local ok, realm = pcall(GetNormalizedRealmName)
    if not ok or Secret(realm) or type(realm) ~= "string" then return nil end
    realm = realm:gsub("[%s%-]", ""):lower()
    if realm == "" or #realm > 100 or realm:find("[%c|{}]") then return nil end
    return realm
end

local function Identity(name, realm)
    if Secret(name) or Secret(realm) or type(name) ~= "string" then return nil end
    if #name > 160 or name:find("[%c|{}]") then return nil end
    local short, embeddedRealm = name:match("^([^%-]+)%-(.+)$")
    if short then name, realm = short, embeddedRealm end
    if name == "" or name:find("%s") or name:find("%-") then return nil end
    if realm == nil or realm == "" then realm = LocalRealm() end
    if type(realm) ~= "string" or #realm > 100 or realm:find("[%c|{}]") then return nil end
    realm = realm:gsub("[%s%-]", ""):lower()
    if realm == "" then return nil end
    return name:lower() .. "-" .. realm
end

local function UnitIdentity(unit)
    if type(UnitFullName) ~= "function" then return nil end
    local ok, name, realm = pcall(UnitFullName, unit)
    if not ok then return nil end
    return Identity(name, realm)
end

local function Channel()
    if LE_PARTY_CATEGORY_INSTANCE and PublicFlag(IsInGroup, LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if PublicFlag(IsInRaid) then return "RAID" end
    if PublicFlag(IsInGroup) then return "PARTY" end
end

local function Lockdown()
    if restrictionPending then return true end
    if C_ChatInfo and type(C_ChatInfo.InChatMessagingLockdown) == "function" then
        -- API failures fail closed; never keep a previously public name visible.
        return PublicFlag(C_ChatInfo.InChatMessagingLockdown) ~= false
    end
    return false
end

local function SendRestricted()
    if Lockdown() then return true end
    if C_ChatInfo and type(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted) == "function" then
        return PublicFlag(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted) ~= false
    end
    return false
end

local function ReadUnit(unit)
    local ok, exists = pcall(UnitExists, unit)
    if not ok then return { state = "unavailable" } end
    if Secret(exists) then return { state = "restricted" } end
    if type(exists) ~= "boolean" then return { state = "unavailable" } end
    if not exists then return { state = "none" } end
    local nameOK, name = pcall(UnitName, unit)
    if not nameOK then return { state = "unavailable" } end
    if Secret(name) then return { state = "restricted" } end
    name = CleanName(name)
    if not name then return { state = "unavailable" } end
    local marker
    if type(GetRaidTargetIndex) == "function" then
        local markOK, value = pcall(GetRaidTargetIndex, unit)
        -- GetRaidTargetIndex may return a secret even outside combat. Omit it.
        if markOK and not Secret(value) and type(value) == "number"
            and value >= 1 and value <= 8 and value == math.floor(value) then marker = value end
    end
    return { state = "ok", name = name, marker = marker }
end

local function OwnFocus()
    if Lockdown() then return { state = "restricted" } end
    return ReadUnit("focus")
end

local codes = { none = "N", restricted = "R", unavailable = "U", disabled = "D" }
local states = { N = "none", R = "restricted", U = "unavailable", D = "disabled" }
local function Encode(info)
    if info.state == "ok" then
        return "1|O|" .. (info.marker or 0) .. "|" .. info.name
    end
    return "1|" .. (codes[info.state] or "U")
end

local function Decode(message)
    if Secret(message) or type(message) ~= "string" or #message > MAX_PACKET then return nil end
    if message == "1|Q" then return "query" end
    local code = message:match("^1|([NRUD])$")
    if code then return { state = states[code] } end
    local marker, name = message:match("^1|O|([0-8])|(.+)$")
    if not marker or not name or #name > MAX_NAME or CleanName(name) ~= name then return nil end
    marker = tonumber(marker)
    return { state = "ok", name = name, marker = marker > 0 and marker or nil }
end

local function SendPacket(message)
    local channel = Channel()
    if not channel or not prefixReady or SendRestricted() or Now() < nextSend then return false end
    if not C_ChatInfo or type(C_ChatInfo.SendAddonMessage) ~= "function" then return false end
    nextSend = Now() + SEND_INTERVAL
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, message, channel)
    -- Retail SendAddonMessageResult.Success is 0; booleans are not that enum.
    return ok and not Secret(result) and result == 0
end

local function Tick()
    if not db then return end
    local time = Now()
    if time < nextPoll then return end
    nextPoll = time + 0.25
    -- Restriction events may briefly report inactive during dispatch. Query
    -- only on a later OnUpdate, while event-time reads remain fail-closed.
    restrictionPending = false
    local restricted = Lockdown()
    if restricted ~= lastRestriction then
        lastRestriction = restricted
        received = {}
        stateDirty = true
        if db.shareFocus then queryPending = true end
        if not restricted then Communication.RebuildRoster(rosterUnits) end
        Changed()
    end
    local expired = false
    for id, entry in pairs(declarations) do
        if time - entry.receivedAt >= DECLARATION_TTL then declarations[id] = nil; expired = true end
    end
    for _, entry in pairs(received) do
        if entry.state ~= "stale" and time - entry.receivedAt >= TTL then
            entry.state, entry.name, entry.marker = "stale", nil, nil
            expired = true
        end
    end
    if expired then Changed() end
    local packet = Encode(OwnFocus())
    if packet ~= lastOwnPacket then
        lastOwnPacket, stateDirty = packet, true
        Changed()
    end
    if not Channel() then disablePending = false; return end
    if disablePending then
        if SendPacket("1|D") then disablePending = false end
    elseif db.shareFocus then
        if queryPending then
            if SendPacket("1|Q") then queryPending = false end
        elseif stateDirty or time - lastSent >= HEARTBEAT then
            if SendPacket(packet) then stateDirty = false; lastSent = time end
        end
    end
end

function Communication.RebuildRoster(units)
    rosterUnits = {}
    for _, unit in ipairs(units or { "player" }) do
        if type(unit) == "string" and (unit == "player" or unit:match("^party[1-4]$")
            or unit:match("^raid%d+$")) then rosterUnits[#rosterUnits + 1] = unit end
    end
    byUnit, members = {}, {}
    ownID = UnitIdentity("player")
    local channel = Channel()
    local identities = {}
    if channel then
        for _, unit in ipairs(rosterUnits) do
            local id = UnitIdentity(unit)
            if id then
                byUnit[unit], members[id] = id, true
                identities[#identities + 1] = id
            end
        end
    end
    table.sort(identities)
    local signature = (channel or "solo") .. ":" .. table.concat(identities, ",")
    if signature ~= rosterSignature then
        -- Clear on every membership/channel change: never attach a departed
        -- player's snapshot to a reused party/raid unit token.
        received, declarations = {}, {}
        rosterSignature = signature
        stateDirty = true
        queryPending = db and db.shareFocus or false
        if not channel then disablePending = false end
        Changed()
    end
end

local chatEvents = {
    CHAT_MSG_PARTY = true, CHAT_MSG_PARTY_LEADER = true,
    CHAT_MSG_RAID = true, CHAT_MSG_RAID_LEADER = true,
    CHAT_MSG_INSTANCE_CHAT = true, CHAT_MSG_INSTANCE_CHAT_LEADER = true,
}
local markerNames = { "星星", "圆圈", "菱形", "三角", "月亮", "方块", "叉叉", "骷髅" }
local declarationPhrases = {}
for marker, name in ipairs(markerNames) do declarationPhrases["我打断" .. name] = marker end

local function ReceiveDeclaration(message, sender)
    if not db or not db.acceptFocusCalls or not Channel() then return end
    -- These events may carry engine secrets during chat lockdown. Test every
    -- value before type, length, equality, parsing, or identity normalization.
    if Secret(message) or Secret(sender) then return end
    if type(message) ~= "string" or #message > 64 then return end
    local id = Identity(sender)
    if not id or not members[id] then return end
    if message == "取消打断" then
        declarations[id] = nil
        Changed()
        return
    end
    local marker = declarationPhrases[message]
    if not marker then
        local value = message:match("^我打断{rt([1-8])}$")
        if value then marker = tonumber(value) end
    end
    if not marker then return end
    declarations[id] = { marker = marker, receivedAt = Now() }
    Changed()
end

local function Receive(prefix, message, channel, sender)
    if not db or not db.shareFocus or Lockdown() or not prefixReady then return end
    if Secret(prefix) or Secret(message) or Secret(channel) or Secret(sender) then return end
    if prefix ~= PREFIX or channel ~= Channel() then return end
    local id = Identity(sender)
    if not id or not members[id] or id == ownID then return end
    local info = Decode(message)
    if not info then return end
    if info == "query" then stateDirty = true; return end
    -- Limit accepted packets per current member without extending stale data
    -- on malformed packets. Explicit clears always supersede old names.
    local previous = received[id]
    if previous and Now() - previous.receivedAt < 0.25
        and (info.state == "ok" or previous.state ~= "ok") then return end
    info.receivedAt = Now()
    received[id] = info
    Changed()
end

function Communication.Init(settings, report, changed)
    db, notify, onChanged = settings, report, changed
    db.shareFocus = db.shareFocus == true
    db.acceptFocusCalls = db.acceptFocusCalls == true
    prefixReady = false
    if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
        prefixReady = ok and not Secret(result) and (result == 0 or result == 1)
    end
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        for _, event in ipairs({ "CHAT_MSG_ADDON", "PLAYER_FOCUS_CHANGED", "RAID_TARGET_UPDATE",
            "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "UNIT_NAME_UPDATE", "ADDON_RESTRICTION_STATE_CHANGED" }) do
            eventFrame:RegisterEvent(event)
        end
        for event in pairs(chatEvents) do eventFrame:RegisterEvent(event) end
        eventFrame:SetScript("OnEvent", function(_, event, ...)
            if event == "CHAT_MSG_ADDON" then Receive(...)
            elseif chatEvents[event] then ReceiveDeclaration(...)
            elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
                restrictionPending = true
                received = {}
                stateDirty = true
                Changed()
            elseif event == "PLAYER_ENTERING_WORLD" then
                received, declarations = {}, {}
                Communication.RebuildRoster(rosterUnits)
                stateDirty, queryPending = true, db.shareFocus
                Changed()
            elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_NAME_UPDATE" then
                Communication.RebuildRoster(rosterUnits)
            else stateDirty = true; Changed() end
        end)
        eventFrame:SetScript("OnUpdate", Tick)
    end
    Communication.RebuildRoster(rosterUnits)
    stateDirty, queryPending = true, db.shareFocus
end

function Communication.SetAcceptCalls(flag)
    if not db then return end
    db.acceptFocusCalls = flag == true
    declarations = {}
    Changed()
end

function Communication.SetEnabled(flag)
    if not db then return end
    local enabled = flag == true
    if db.shareFocus == enabled then return end
    local wasEnabled = db.shareFocus
    db.shareFocus = enabled
    received = {}
    disablePending = not enabled and wasEnabled and Channel() ~= nil
    stateDirty, queryPending = true, enabled
    Changed()
end

local function AutomaticFocus(unit)
    if unit == "player" or (ownID and byUnit[unit] == ownID) then return OwnFocus() end
    if not db or not db.shareFocus then return { state = "disabled" } end
    if Lockdown() then return { state = "restricted" } end
    if not prefixReady or not Channel() then return { state = "unavailable" } end
    local id = byUnit[unit]
    if not id or PublicFlag(UnitIsConnected, unit) == false then return { state = "unavailable" } end
    local info = received[id]
    if not info then return { state = "pending" } end
    if Now() - info.receivedAt >= TTL then return { state = "stale" } end
    return { state = info.state, name = info.name, marker = info.marker }
end

function Communication.GetFocus(unit)
    local info = AutomaticFocus(unit)
    if info.state == "ok" then return info end
    if db and db.acceptFocusCalls and Channel() then
        local id = unit == "player" and ownID or byUnit[unit]
        local entry = id and declarations[id]
        if entry and members[id] and Now() - entry.receivedAt < DECLARATION_TTL then
            -- A public chat commitment is a declared assignment, never proof
            -- of the member's real focus. It may survive local chat lockdown.
            return { state = "declared", name = markerNames[entry.marker], marker = entry.marker }
        end
    end
    return info
end

local messages = {
    solo = "未组队，无法通报。", throttle = "通报过于频繁，请稍后再试。",
    restricted = "当前信息受游戏限制，无法通报。", unavailable = "当前目标信息不可用，无法通报。",
    none = "当前没有可通报的目标。", failed = "通报发送失败；请检查聊天权限和游戏限制。",
}

function Communication.Announce(unit)
    local function Fail(reason)
        if notify then notify(messages[reason] or messages.failed) end
        return false, reason
    end
    local channel = Channel()
    if not channel then return Fail("solo") end
    if Lockdown() then return Fail("restricted") end
    if Now() < nextChat then return Fail("throttle") end
    if unit == nil or unit == "target" then unit = "player" end
    if type(unit) ~= "string" or (unit ~= "player" and not byUnit[unit]) then return Fail("unavailable") end
    if PublicFlag(UnitIsConnected, unit) == false then return Fail("unavailable") end
    local target = ReadUnit(unit == "player" and "target" or unit .. "target")
    if target.state ~= "ok" then return Fail(target.state) end
    local owner = ReadUnit(unit)
    if owner.state ~= "ok" then return Fail(owner.state) end
    local marker = target.marker and ("{rt" .. target.marker .. "} ") or ""
    local text = "[PTW] 请集火：" .. marker .. target.name .. "（" .. owner.name .. "的目标）"
    if #text > 255 then return Fail("unavailable") end
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    if type(send) ~= "function" then return Fail("failed") end
    -- This call is synchronous with the click/binding; it is never queued.
    nextChat = Now() + CHAT_INTERVAL
    local ok = pcall(send, text, channel)
    if not ok then return Fail("failed") end
    return true
end
