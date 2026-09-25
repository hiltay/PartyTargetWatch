-- Public group chat is received only, for configured focus declarations.
-- The player's own public focus is read locally; no messages are sent.
local addonName, ns = ...
local Communication = {}
ns.Communication = Communication

local MAX_NAME = 96
local DECLARATION_TTL = 300
local db, onChanged, eventFrame
local byUnit, members = {}, {}
local declarations = {}
local rosterUnits = { "player" }
local ownID, rosterSignature
local nextPoll = 0

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
    return ReadUnit("focus")
end

local function Tick()
    if not db then return end
    local time = Now()
    if time < nextPoll then return end
    nextPoll = time + 0.25
    local expired = false
    for id, entry in pairs(declarations) do
        if time - entry.receivedAt >= DECLARATION_TTL then declarations[id] = nil; expired = true end
    end
    if expired then Changed() end
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
        -- player's declaration to a reused party/raid unit token.
        declarations = {}
        rosterSignature = signature
        Changed()
    end
end

local chatEvents = {
    CHAT_MSG_PARTY = true, CHAT_MSG_PARTY_LEADER = true,
    CHAT_MSG_RAID = true, CHAT_MSG_RAID_LEADER = true,
    CHAT_MSG_INSTANCE_CHAT = true, CHAT_MSG_INSTANCE_CHAT_LEADER = true,
}
local markerNames = { "星星", "圆圈", "菱形", "三角", "月亮", "方块", "叉叉", "骷髅" }
local DEFAULT_FORMATS = "我打断%mark\n我的焦点打断是 {rt%mark} %name"
local MAX_FORMATS, MAX_FORMAT_LINE, MAX_FORMAT_BYTES = 20, 255, 8192
local MAX_CAPTURE_CHECKS = 8192

local function CompileFormats(text)
    if Secret(text) or type(text) ~= "string" then return nil, "格式错误：模板必须是文本。" end
    if #text > MAX_FORMAT_BYTES then return nil, "格式错误：全部模板最多 8192 字节。" end
    local lines, compiled, lineNumber = {}, {}, 0
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    for raw in (text .. "\n"):gmatch("(.-)\n") do
        lineNumber = lineNumber + 1
        local line = raw:match("^[ \t]*(.-)[ \t]*$")
        if line ~= "" then
            local function Invalid(reason)
                return nil, "格式错误：第 " .. lineNumber .. " 行" .. reason
            end
            if #compiled >= MAX_FORMATS then return Invalid("超过 20 个非空模板的上限。") end
            if #line > MAX_FORMAT_LINE then return Invalid("超过 255 字节。") end
            if line:find("%c") then return Invalid("含有控制字符。") end
            local tokens, literal, marks, names, texts, pos = {}, {}, 0, 0, 0, 1
            local function FlushLiteral()
                if #literal > 0 then
                    tokens[#tokens + 1] = { kind = "literal", value = table.concat(literal) }
                    literal = {}
                end
            end
            while pos <= #line do
                local token, width, wrapped
                if line:sub(pos, pos + 8) == "{rt%mark}" then
                    token, width, wrapped = "mark", 9, true
                elseif line:sub(pos, pos) == "%" then
                    -- Recognize only our named placeholders. All other text,
                    -- including Lua pattern punctuation and a plain %, is literal.
                    token = line:sub(pos):match("^%%([A-Za-z]+)")
                    if token and token ~= "mark" and token ~= "text" and token ~= "name" then
                        return Invalid("含有未知占位符 %" .. token .. "。")
                    end
                    if token then width = #token + 1 end
                end
                if token then
                    FlushLiteral()
                    tokens[#tokens + 1] = { kind = token, wrapped = wrapped }
                    if token == "mark" then marks = marks + 1
                    elseif token == "name" then names = names + 1
                    else texts = texts + 1 end
                    pos = pos + width
                else
                    literal[#literal + 1] = line:sub(pos, pos)
                    pos = pos + 1
                end
            end
            FlushLiteral()
            if marks > 1 or names > 1 or marks + names == 0 then
                return Invalid("必须包含 %mark 或 %name，且各最多一个。")
            end
            if texts > 2 then return Invalid("最多包含两个 %text。") end
            local fixedText = false
            for index, token in ipairs(tokens) do
                if token.kind == "literal" and token.value:find("%S") then fixedText = true end
                if token.kind == "name" then
                    local previous, following = tokens[index - 1], tokens[index + 1]
                    if (previous and previous.kind == "text") or (following and following.kind == "text") then
                        return Invalid("%name 与 %text 之间必须有固定文字分隔。")
                    end
                end
            end
            if names == 1 and marks == 0 and not fixedText then
                return Invalid("仅名称格式还必须包含非空白的固定文字。")
            end
            lines[#lines + 1], compiled[#compiled + 1] = line, tokens
        end
    end
    return table.concat(lines, "\n"), compiled
end

local declarationFormats, declarationTemplates = CompileFormats(DEFAULT_FORMATS)

local function MatchPositions(message, tokens, first, last, markText, wrappedText, backwards)
    -- A small literal/wildcard automaton avoids executing user-supplied Lua
    -- patterns and avoids greedy captures mistaking text for the marker.
    local limit = #message + 1
    local positions = { [backwards and limit or 1] = true }
    for index = first, last, backwards and -1 or 1 do
        local token = tokens[index]
        local nextPositions = {}
        if token.kind == "text" then
            local canEnd = false
            for pos = backwards and limit or 1, backwards and 1 or limit, backwards and -1 or 1 do
                if canEnd then nextPositions[pos] = true end
                if positions[pos] then canEnd = true end
            end
        else
            local value = token.kind == "mark" and (token.wrapped and wrappedText or markText) or token.value
            for pos in pairs(positions) do
                local start = backwards and pos - #value or pos
                if start >= 1 and message:sub(start, start + #value - 1) == value then
                    nextPositions[backwards and start or pos + #value] = true
                end
            end
        end
        positions = nextPositions
    end
    return positions
end

local function MatchWithName(message, tokens, markText, wrappedText, budget)
    local nameIndex
    for index, token in ipairs(tokens) do
        if token.kind == "name" then nameIndex = index; break end
    end
    if not nameIndex then
        return MatchPositions(message, tokens, 1, #tokens, markText, wrappedText)[#message + 1] == true
    end
    local starts = MatchPositions(message, tokens, 1, nameIndex - 1, markText, wrappedText)
    local ends = MatchPositions(message, tokens, #tokens, nameIndex + 1, markText, wrappedText, true)
    local matchedName, matchedMarker
    for start in pairs(starts) do
        for finish in pairs(ends) do
            budget.remaining = budget.remaining - 1
            if budget.remaining < 0 then return nil, nil, "匹配过于复杂，请减少 %text 或增加固定文字。" end
            if finish > start then
                -- Native macro expansion can include a public leading raid
                -- token. Extract that token before CleanName removes braces.
                -- Only color wrappers are ignored here; textures are never
                -- decoded or used to infer a marker.
                local raw = message:sub(start, finish - 1)
                raw = raw:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                local markerText, remainder = raw:match("^%s*{rt([1-8])}%s*(.-)%s*$")
                local marker = markerText and tonumber(markerText) or nil
                if marker then raw = remainder end
                -- Refuse malformed or stacked raid tokens instead of turning
                -- them into creature text or silently choosing a marker.
                local name = not raw:match("^%s*{rt") and CleanName(raw) or nil
                -- An unexpanded macro placeholder is not a declared creature.
                if name and not name:match("^%%[fFtT]$") then
                    if matchedName and (matchedName ~= name or matchedMarker ~= marker) then
                        return nil, nil, "可匹配不同名称或标记。"
                    end
                    matchedName, matchedMarker = name, marker
                end
            end
        end
    end
    return matchedName ~= nil, matchedName, nil, matchedMarker
end

local function MatchDeclaration(message, templates)
    if Secret(message) or type(message) ~= "string" then return nil, "未匹配：消息不可读取。" end
    if #message == 0 or #message > 255 or message:find("%c") then return nil, "未匹配：消息为空、过长或含控制字符。" end
    local budget = { remaining = MAX_CAPTURE_CHECKS }
    for line, tokens in ipairs(templates) do
        local matched, matchedName, hasMarker
        for _, token in ipairs(tokens) do if token.kind == "mark" then hasMarker = true end end
        if not hasMarker then
            local ok, name, reason, marker = MatchWithName(message, tokens, nil, nil, budget)
            if reason then return nil, "存在歧义：第 " .. line .. " 行" .. reason end
            if ok then return marker, line, name end
        end
        for marker, name in ipairs(hasMarker and markerNames or {}) do
            local number, raidToken = tostring(marker), "{rt" .. marker .. "}"
            for _, value in ipairs({ number, name, raidToken }) do
                local ok, capturedName, reason, capturedMarker = MatchWithName(message, tokens, value, raidToken, budget)
                if reason then return nil, "存在歧义：第 " .. line .. " 行" .. reason end
                if ok then
                    if capturedMarker and capturedMarker ~= marker then
                        return nil, "存在歧义：第 " .. line .. " 行名称前的标记与 %mark 不一致。"
                    end
                    if matched and matched ~= marker then return nil, "存在歧义：第 " .. line .. " 行可匹配不同标记。" end
                    if matchedName and matchedName ~= capturedName then return nil, "存在歧义：第 " .. line .. " 行可匹配不同名称。" end
                    matched, matchedName = marker, capturedName
                end
            end
        end
        if matched then return matched, line, matchedName end
    end
    return nil, "未匹配：没有模板与整句消息匹配。"
end

function Communication.GetDefaultDeclarationFormats()
    return DEFAULT_FORMATS
end

function Communication.GetDeclarationFormats()
    return declarationFormats
end

function Communication.SetDeclarationFormats(text)
    local normalized, templates = CompileFormats(text)
    if not normalized then return false, templates end
    if not db then return false, "格式错误：插件尚未初始化。" end
    declarationFormats, declarationTemplates = normalized, templates
    db.declarationFormats = normalized
    declarations = {}
    Changed()
    return true
end

function Communication.ResetDeclarationFormats()
    Communication.SetDeclarationFormats(DEFAULT_FORMATS)
    return DEFAULT_FORMATS
end

function Communication.TestDeclarationMessage(message, draftFormats)
    local templates = declarationTemplates
    if Secret(message) or type(message) ~= "string" then return nil, "未匹配：消息不可读取。" end
    if Secret(draftFormats) then return nil, "格式错误：模板不可读取。" end
    if draftFormats ~= nil then
        local normalized, temporary = CompileFormats(draftFormats)
        if not normalized then return nil, temporary end
        templates = temporary
    end
    return MatchDeclaration(message, templates)
end

local function ReceiveDeclaration(message, sender)
    if not db or not db.acceptFocusCalls or not Channel() then return end
    -- These events may carry engine secrets during chat lockdown. Test every
    -- value before type, length, equality, parsing, or identity normalization.
    if Secret(message) or Secret(sender) then return end
    if type(message) ~= "string" or #message > 255 then return end
    local id = Identity(sender)
    if id and not members[id] then
        -- A roster identity may have been unreadable at the last group/name
        -- event. Recheck current members before accepting a newly public sender.
        Communication.RebuildRoster(rosterUnits)
    end
    if not id or not members[id] then return end
    if message == "取消打断" then
        declarations[id] = nil
        Changed()
        return
    end
    local marker, _, name = MatchDeclaration(message, declarationTemplates)
    if not marker and not name then return end
    declarations[id] = { marker = marker, name = name, receivedAt = Now() }
    Changed()
end

function Communication.Init(settings, changed)
    db, onChanged = settings, changed
    db.acceptFocusCalls = db.acceptFocusCalls == true
    local formats, templates = CompileFormats(db.declarationFormats)
    if not formats then formats, templates = CompileFormats(DEFAULT_FORMATS) end
    declarationFormats, declarationTemplates, db.declarationFormats = formats, templates, formats
    declarations = {}
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        for _, event in ipairs({ "PLAYER_FOCUS_CHANGED", "RAID_TARGET_UPDATE",
            "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "UNIT_NAME_UPDATE" }) do
            eventFrame:RegisterEvent(event)
        end
        for event in pairs(chatEvents) do eventFrame:RegisterEvent(event) end
        eventFrame:SetScript("OnEvent", function(_, event, ...)
            if chatEvents[event] then ReceiveDeclaration(...)
            elseif event == "PLAYER_ENTERING_WORLD" then
                declarations = {}
                Communication.RebuildRoster(rosterUnits)
                Changed()
            elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_NAME_UPDATE" then
                Communication.RebuildRoster(rosterUnits)
            else Changed() end
        end)
        eventFrame:SetScript("OnUpdate", Tick)
    end
    Communication.RebuildRoster(rosterUnits)
end

function Communication.SetAcceptCalls(flag)
    if not db then return end
    db.acceptFocusCalls = flag == true
    declarations = {}
    Changed()
end

local function LocalFocusOrPending(unit)
    if unit == "player" or (ownID and byUnit[unit] == ownID) then return OwnFocus() end
    if not db or not db.acceptFocusCalls then return { state = "disabled" } end
    if not Channel() then return { state = "unavailable" } end
    local id = byUnit[unit]
    if not id or PublicFlag(UnitIsConnected, unit) == false then return { state = "unavailable" } end
    return { state = "pending" }
end

function Communication.GetFocus(unit)
    local info = LocalFocusOrPending(unit)
    if info.state == "ok" then return info end
    if db and db.acceptFocusCalls and Channel() then
        local id = unit == "player" and ownID or byUnit[unit]
        local entry = id and declarations[id]
        if entry and members[id] and Now() - entry.receivedAt < DECLARATION_TTL then
            -- A public chat commitment is a declared assignment, never proof
            -- of the member's real focus. It may survive local chat lockdown.
            return { state = "declared", name = entry.name or markerNames[entry.marker], marker = entry.marker,
                hasDeclaredName = entry.name ~= nil }
        end
    end
    return info
end
