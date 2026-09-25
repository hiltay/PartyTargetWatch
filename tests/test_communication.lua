-- Pure mocks: no real chat, network, WoW engine secrets, or key bindings.
local source = assert(COMMUNICATION_SOURCE, "COMMUNICATION_SOURCE is required")
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function boot(grouped, saved)
    local state = { time = 0, group = grouped or false, raid = false, instance = false,
        names = { player = "Alice", target = "Training Dummy", party1 = "Bob", party1target = "Other Dummy" },
        realms = { player = "Test Realm", party1 = "Test Realm" },
        marker = {}, secrets = {}, exists = {}, errors = {}, offline = {},
        addon = {}, chat = {}, changed = 0, registered = {},
        lockdown = false, outgoingRestricted = false, sendResult = 0, registerResult = 0 }
    local env = setmetatable({}, { __index = _G })
    env.C_ChatInfo = {}
    env.LE_PARTY_CATEGORY_INSTANCE = 2
    env.GetTime = function() return state.time end
    env.issecretvalue = function(value) return state.secrets[value] == true end
    env.GetNormalizedRealmName = function() return "TestRealm" end
    env.UnitFullName = function(unit) return state.names[unit], state.realms[unit] end
    env.UnitExists = function(unit)
        if state.errors[unit] == "exists" then error("mock unavailable") end
        if state.exists[unit] ~= nil then return state.exists[unit] end
        return state.names[unit] ~= nil
    end
    env.UnitName = function(unit)
        if state.errors[unit] == "name" then error("mock unavailable") end
        return state.names[unit]
    end
    env.UnitIsConnected = function(unit) return not state.offline[unit] end
    env.GetRaidTargetIndex = function(unit) return state.marker[unit] end
    env.IsInGroup = function(category)
        if category == 2 then return state.instance end
        return state.group or state.raid or state.instance
    end
    env.IsInRaid = function() return state.raid end
    env.C_ChatInfo.InChatMessagingLockdown = function() return state.lockdown end
    env.C_ChatInfo.AreOutgoingAddonChatMessagesRestricted = function() return state.outgoingRestricted end
    env.C_ChatInfo.RegisterAddonMessagePrefix = function(prefix)
        state.registered[#state.registered + 1] = prefix
        return state.registerResult
    end
    env.C_ChatInfo.SendAddonMessage = function(prefix, message, channel)
        assert(type(prefix) == "string" and type(message) == "string" and type(channel) == "string")
        state.addon[#state.addon + 1] = { prefix = prefix, message = message, channel = channel, time = state.time }
        return state.sendResult
    end
    env.C_ChatInfo.SendChatMessage = function(...)
        state.chat[#state.chat + 1] = { ... }
        error("ordinary chat sending has been removed")
    end
    env.SendChatMessage = env.C_ChatInfo.SendChatMessage
    local frame = { scripts = {}, events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(event, fn) self.scripts[event] = fn end
    env.CreateFrame = function() return frame end
    local namespace = {}
    local chunk = assert(loadstring(source, "@Communication.lua"))
    setfenv(chunk, env)
    chunk("PartyTargetWatch", namespace)
    local comm = namespace.Communication
    local settings = saved or {}
    comm.Init(settings, function() state.changed = state.changed + 1 end)
    comm.RebuildRoster({ "player", "party1" })
    local app = { state = state, env = env, comm = comm, db = settings, frame = frame }
    function app:advance(seconds)
        state.time = state.time + seconds
        frame.scripts.OnUpdate(frame, seconds)
    end
    function app:event(event, ...)
        if frame.events[event] then frame.scripts.OnEvent(frame, event, ...) end
    end
    function app:secret()
        local value = setmetatable({}, {
            __concat = function() error("must not concatenate secret mock") end,
            __tostring = function() error("must not stringify secret mock") end,
            __eq = function() error("must not compare secret mock") end,
            __lt = function() error("must not order secret mock") end,
            __le = function() error("must not order secret mock") end,
        })
        state.secrets[value] = true
        return value
    end
    app:advance(0)
    return app
end

local tests = {}

tests["legacy sharing settings cannot register receive or send addon messages"] = function()
    local a = boot(true, { shareFocus = true, acceptFocusCalls = true, declarationFormats = "PTW焦点：%name" })
    equal(#a.state.registered, 0)
    equal(a.frame.events.CHAT_MSG_ADDON, nil)
    equal(a.frame.events.ADDON_RESTRICTION_STATE_CHANGED, nil)
    equal(a.comm.SetEnabled, nil)
    a:event("CHAT_MSG_ADDON", "PTWFocus1", "1|O|4|Remote Snapshot", "PARTY", "Bob-TestRealm")
    equal(a.comm.GetFocus("party1").state, "pending")
    a.state.names.focus = "Local Focus"
    a:event("PLAYER_FOCUS_CHANGED")
    equal(a.comm.GetFocus("player").name, "Local Focus")
    a:event("CHAT_MSG_PARTY", "PTW焦点：{rt4} Public Declaration", "Bob-TestRealm")
    equal(a.comm.GetFocus("party1").name, "Public Declaration")
    a:advance(301)
    a:event("PLAYER_ENTERING_WORLD")
    equal(#a.state.registered, 0)
    equal(#a.state.addon, 0)
    equal(#a.state.chat, 0)
end

tests["own focus reads locally and secrets never become readable names or markers"] = function()
    local a = boot(false)
    a.state.names.focus = "Local Focus"
    a.state.marker.focus = 4
    a.state.lockdown = true
    equal(a.comm.GetFocus("player").name, "Local Focus", "chat lockdown does not block local public reads")
    equal(a.comm.GetFocus("player").marker, 4)
    a.state.marker.focus = a:secret()
    equal(a.comm.GetFocus("player").name, "Local Focus")
    equal(a.comm.GetFocus("player").marker, nil)
    a.state.names.focus = a:secret()
    equal(a.comm.GetFocus("player").state, "restricted")
    equal(a.comm.GetFocus("player").name, nil)
    a.state.exists.focus = a:secret()
    equal(a.comm.GetFocus("player").state, "restricted")
    a.state.exists.focus = nil; a.state.names.focus = nil
    equal(a.comm.GetFocus("player").state, "none")
    a.state.names.focus = "Focus"; a.state.errors.focus = "name"
    equal(a.comm.GetFocus("player").state, "unavailable")
    a.state.errors.focus = "exists"
    equal(a.comm.GetFocus("player").state, "unavailable")
    a:advance(20)
    equal(#a.state.registered, 0); equal(#a.state.addon, 0); equal(#a.state.chat, 0)
end

tests["own public focus takes priority while received declarations survive chat lockdown"] = function()
    local a = boot(true, { acceptFocusCalls = true })
    a:event("CHAT_MSG_PARTY", "我打断月亮", "Bob-TestRealm")
    a:event("CHAT_MSG_PARTY", "我打断方块", "Alice-TestRealm")
    a.state.lockdown = true
    a:advance(1)
    equal(a.comm.GetFocus("party1").state, "declared")
    equal(a.comm.GetFocus("party1").marker, 5)
    equal(a.comm.GetFocus("player").state, "declared")
    a.state.names.focus = "My Real Focus"
    equal(a.comm.GetFocus("player").state, "ok")
    equal(a.comm.GetFocus("player").name, "My Real Focus")
    a.state.names.raid1 = "Alice"; a.state.realms.raid1 = "Test Realm"
    a.state.raid = true; a.comm.RebuildRoster({ "raid1", "party1" })
    equal(a.comm.GetFocus("raid1").name, "My Real Focus", "own raid token still reads local focus")
end

tests["roster changes and leaving clear declarations and recover newly public member identities"] = function()
    local a = boot(true, { acceptFocusCalls = true, declarationFormats = "PTW焦点：%name" })
    a:event("CHAT_MSG_PARTY", "PTW焦点：Bob Focus", "Bob-TestRealm")
    a.state.names.party1 = "Carol"
    a:event("UNIT_NAME_UPDATE", "party1")
    equal(a.comm.GetFocus("party1").state, "pending")
    a:event("CHAT_MSG_PARTY", "PTW焦点：Bob Again", "Bob-TestRealm")
    equal(a.comm.GetFocus("party1").state, "pending")
    a:event("CHAT_MSG_PARTY", "PTW焦点：Carol Focus", "Carol-TestRealm")
    equal(a.comm.GetFocus("party1").name, "Carol Focus")
    a.state.group = false; a.comm.RebuildRoster({ "player" })
    equal(a.comm.GetFocus("party1").state, "unavailable")
    a.state.group = true; a.comm.RebuildRoster({ "player", "party1" })
    equal(a.comm.GetFocus("party1").state, "pending")
    a.state.names.party1 = a:secret(); a:event("GROUP_ROSTER_UPDATE")
    equal(a.comm.GetFocus("party1").state, "unavailable")
    a:event("CHAT_MSG_PARTY", "PTW焦点：Unreadable member", "Carol-TestRealm")
    equal(a.comm.GetFocus("party1").state, "unavailable")
    -- Recovery need not emit a restriction event or wait for a sharing tick.
    a.state.names.party1 = "Carol"
    a:event("CHAT_MSG_PARTY", "PTW焦点：Public Again", "Carol-TestRealm")
    equal(a.comm.GetFocus("party1").name, "Public Again")
    a:event("CHAT_MSG_PARTY", "取消打断", "Carol-TestRealm")
    a.state.offline.party1 = true
    equal(a.comm.GetFocus("party1").state, "unavailable")
    a.state.offline.party1 = false
    equal(a.comm.GetFocus("party1").state, "pending")
    a.comm.SetAcceptCalls(false)
    equal(a.comm.GetFocus("party1").state, "disabled")
    equal(#a.state.addon, 0); equal(#a.state.chat, 0)
end

tests["strict public chat declarations are opt-in and receive only"] = function()
    local a = boot(true)
    a:event("CHAT_MSG_PARTY", "我打断星星", "Bob-TestRealm")
    equal(a.comm.GetFocus("party1").state, "disabled")
    a.comm.SetAcceptCalls(true)
    local names = { "星星", "圆圈", "菱形", "三角", "月亮", "方块", "叉叉", "骷髅" }
    local events = { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" }
    for marker, name in ipairs(names) do
        a:event(events[(marker - 1) % #events + 1], "我打断" .. name, "Bob-TestRealm")
        local info = a.comm.GetFocus("party1")
        equal(info.state, "declared"); equal(info.name, name); equal(info.marker, marker)
    end
    a:event("CHAT_MSG_PARTY", "我打断{rt1}", "Bob")
    equal(a.comm.GetFocus("party1").marker, 1)
    equal(#a.state.addon, 0); equal(#a.state.chat, 0)
    a:event("CHAT_MSG_PARTY", "取消打断", "Bob-TestRealm")
    equal(a.comm.GetFocus("party1").state, "pending")
end

tests["declarations reject mentions malformed messages outsiders and secrets"] = function()
    local a = boot(true)
    a.comm.SetAcceptCalls(true)
    a:event("CHAT_MSG_PARTY", "我打断星星", "Bob-TestRealm")
    for _, text in ipairs({ "我打断骷髅吧", "他说我打断骷髅", "我打断 骷髅", "我打断骷髅\n", " 我打断骷髅",
        "|cffffffff我打断骷髅|r", "我打断{rt9}", "我打断{rt01}", "取消打断吧", string.rep("x", 65) }) do
        a:event("CHAT_MSG_PARTY", text, "Bob-TestRealm")
    end
    a:event("CHAT_MSG_PARTY", "我打断骷髅", "Bob-WrongRealm")
    a:event("CHAT_MSG_PARTY", "我打断骷髅", "Eve-TestRealm")
    a:event("CHAT_MSG_GUILD", "我打断骷髅", "Bob-TestRealm")
    a:event("CHAT_MSG_WHISPER", "我打断骷髅", "Bob-TestRealm")
    a:event("CHAT_MSG_PARTY", a:secret(), "Bob-TestRealm")
    a:event("CHAT_MSG_PARTY", "我打断骷髅", a:secret())
    equal(a.comm.GetFocus("party1").marker, 1)
    equal(#a.state.chat, 0)
end

tests["declarations expire and clear on disable roster or scene changes"] = function()
    local a = boot(true)
    a.comm.SetAcceptCalls(true)
    a:event("CHAT_MSG_PARTY", "我打断星星", "Bob-TestRealm")
    a:advance(299); equal(a.comm.GetFocus("party1").state, "declared")
    a:advance(1); equal(a.comm.GetFocus("party1").state, "pending")
    a:event("CHAT_MSG_PARTY", "我打断星星", "Bob-TestRealm")
    a.comm.SetAcceptCalls(false); a.comm.SetAcceptCalls(true)
    equal(a.comm.GetFocus("party1").state, "pending")
    a:event("CHAT_MSG_PARTY", "我打断星星", "Bob-TestRealm")
    a:event("PLAYER_ENTERING_WORLD")
    equal(a.comm.GetFocus("party1").state, "pending")
    a:event("CHAT_MSG_PARTY", "我打断星星", "Bob-TestRealm")
    a.state.group = false; a.comm.RebuildRoster({ "player" })
    a.state.group = true; a.comm.RebuildRoster({ "player", "party1" })
    equal(a.comm.GetFocus("party1").state, "pending")
end

tests["exact two defaults accept bare markers and numbered markers with names"] = function()
    local a = boot(true)
    local defaults = "我打断%mark\n我的焦点打断是 {rt%mark} %name"
    equal(a.comm.GetDefaultDeclarationFormats(), defaults)
    equal(a.comm.GetDeclarationFormats(), defaults)
    equal(a.db.declarationFormats, defaults)
    local labels = { "星星", "圆圈", "菱形", "三角", "月亮", "方块", "叉叉", "骷髅" }
    for marker, label in ipairs(labels) do
        for _, value in ipairs({ tostring(marker), label, "{rt" .. marker .. "}" }) do
            local got, line = a.comm.TestDeclarationMessage("我打断" .. value)
            equal(got, marker); equal(line, 1)
        end
        equal(a.comm.TestDeclarationMessage("我的焦点打断是 {rt" .. marker .. "}"), nil)
        local namedMarker, namedLine, name = a.comm.TestDeclarationMessage("我的焦点打断是 {rt" .. marker .. "} 训练假人")
        equal(namedMarker, marker); equal(namedLine, 2); equal(name, "训练假人")
    end
    for _, value in ipairs({ "星星", "01", "0", "9", "{rt1}", "1.0" }) do
        equal(a.comm.TestDeclarationMessage("我的焦点打断是 {rt" .. value .. "} 训练假人"), nil)
    end
    equal(a.comm.TestDeclarationMessage("我打断star"), nil)
    equal(a.comm.TestDeclarationMessage("PTW焦点：训练假人"), nil)
    local custom = "我的焦点打断是 {rt%mark}\nPTW焦点：%name"
    equal(a.comm.SetDeclarationFormats(custom), true)
    local marker, line, name = a.comm.TestDeclarationMessage("我的焦点打断是 {rt4}")
    equal(marker, 4); equal(line, 1); equal(name, nil)
    marker, line, name = a.comm.TestDeclarationMessage("PTW焦点：训练假人")
    equal(marker, nil); equal(line, 2); equal(name, "训练假人")
    local reloaded = boot(true, { declarationFormats = a.db.declarationFormats })
    equal(reloaded.comm.GetDeclarationFormats(), custom, "saved older formats remain unchanged")
end

tests["format literals never execute pattern syntax and messages keep exact endpoints"] = function()
    local a = boot(true)
    local format = "  ^.$[]()+-*? 100%: %mark!  \r\n\t\r\n"
    equal(a.comm.SetDeclarationFormats(format), true)
    equal(a.comm.GetDeclarationFormats(), "^.$[]()+-*? 100%: %mark!")
    equal(a.comm.TestDeclarationMessage("^.$[]()+-*? 100%: 星星!"), 1)
    for _, text in ipairs({ " ^.$[]()+-*? 100%: 星星!", "^.$[]()+-*? 100%: 星星! ",
        "prefix ^.$[]()+-*? 100%: 星星!", "^X$[]()+-*? 100%: 星星!", "^.$[]()+-*? 100%: 星星!\n" }) do
        equal(a.comm.TestDeclarationMessage(text), nil)
    end
end

tests["multiple formats preserve configured precedence and effective line numbers"] = function()
    local a = boot(true)
    equal(a.comm.SetDeclarationFormats("\n\t\n A%mark \n%text%mark\nB{rt%mark}"), true)
    local marker, line = a.comm.TestDeclarationMessage("A1")
    equal(marker, 1); equal(line, 1)
    marker, line = a.comm.TestDeclarationMessage("C2")
    equal(marker, 2); equal(line, 2)
    marker, line = a.comm.TestDeclarationMessage("B{rt3}")
    equal(marker, 3); equal(line, 2, "first matching template wins")
    equal(a.comm.SetDeclarationFormats("%text%mark\nA%mark"), true)
    marker, line = a.comm.TestDeclarationMessage("A1")
    equal(marker, 1); equal(line, 1)
end

tests["variable text is nonempty and cannot steal a delimited marker"] = function()
    local a = boot(true)
    equal(a.comm.SetDeclarationFormats("%text我打断{rt%mark}（%text）"), true)
    equal(a.comm.TestDeclarationMessage("提到{rt8}我打断{rt1}（骷髅）"), 1)
    equal(a.comm.TestDeclarationMessage("长长的前文我打断{rt3}（更长的任意说明）"), 3)
    equal(a.comm.TestDeclarationMessage("我打断{rt1}（说明）"), nil)
    equal(a.comm.TestDeclarationMessage("前文我打断{rt1}（）"), nil)
    equal(a.comm.TestDeclarationMessage("前文我打断{rt1}（说明）后缀"), nil)
    equal(a.comm.TestDeclarationMessage("前文\n我打断{rt1}（说明）"), nil)
    equal(a.comm.SetDeclarationFormats("%text%text:%mark"), true)
    equal(a.comm.TestDeclarationMessage("x:1"), nil)
    equal(a.comm.TestDeclarationMessage("xy:1"), 1)
end

tests["ambiguous text-marker boundaries reject instead of guessing or falling through"] = function()
    local a = boot(true)
    equal(a.comm.SetDeclarationFormats("%text%mark%text\nx1y%markz"), false, "unknown placeholder rejected")
    equal(a.comm.SetDeclarationFormats("%text%mark%text\nx1y%mark!"), true)
    local marker, reason = a.comm.TestDeclarationMessage("x1y2!")
    equal(marker, nil); assert(reason:find("存在歧义", 1, true))
    equal(a.comm.TestDeclarationMessage("x1y1!"), 1, "multiple parses with the same marker are safe")
    a.comm.SetAcceptCalls(true)
    a:event("CHAT_MSG_PARTY", "x1y2!", "Bob")
    equal(a.comm.GetFocus("party1").state, "pending")
end

tests["format validation rejects unknown tokens invalid counts and control bytes atomically"] = function()
    local a = boot(true)
    a.comm.SetAcceptCalls(true)
    a:event("CHAT_MSG_PARTY", "我打断星星", "Bob")
    local before, changed = a.comm.GetDeclarationFormats(), a.state.changed
    for _, invalid in ipairs({ "no marker", "%text", "%mark%mark", "{rt%mark}%mark",
        "%text%text%text%mark", "%who:%mark", "%marker", "%mark\0", "A\t%mark", false, 12, {} }) do
        local ok, reason = a.comm.SetDeclarationFormats(invalid)
        equal(ok, false); assert(reason:find("格式错误", 1, true))
        equal(a.comm.GetDeclarationFormats(), before); equal(a.db.declarationFormats, before)
        equal(a.comm.GetFocus("party1").marker, 1)
        equal(a.state.changed, changed)
    end
end

tests["format limits bound valid lines bytes and the raw settings text"] = function()
    local a = boot(true)
    local twenty = string.rep("我打断%mark\n", 19) .. "我打断%mark"
    equal(a.comm.SetDeclarationFormats(twenty), true)
    equal(a.comm.SetDeclarationFormats(twenty .. "\n我打断%mark"), false)
    local atLimit = string.rep("x", 250) .. "%mark"
    equal(#atLimit, 255)
    equal(a.comm.SetDeclarationFormats(atLimit), true)
    equal(a.comm.SetDeclarationFormats("x" .. atLimit), false)
    equal(a.comm.SetDeclarationFormats("%mark\n" .. string.rep(" ", 8186)), true)
    equal(a.comm.GetDeclarationFormats(), "%mark")
    equal(a.comm.SetDeclarationFormats("%mark\n" .. string.rep(" ", 8187)), false)
    -- Limits count UTF-8 bytes, not displayed glyphs.
    equal(a.comm.SetDeclarationFormats(string.rep("星", 84) .. "%mark"), false)
end

tests["draft tests report distinct errors and have no effects on settings or declarations"] = function()
    local a = boot(true)
    a.comm.SetAcceptCalls(true)
    a:event("CHAT_MSG_PARTY", "我打断星星", "Bob")
    local saved, changed = a.db.declarationFormats, a.state.changed
    local marker, line = a.comm.TestDeclarationMessage("自定义3", "自定义%mark")
    equal(marker, 3); equal(line, 1)
    local _, reason = a.comm.TestDeclarationMessage("自定义3", "%bad")
    assert(reason:find("格式错误", 1, true))
    _, reason = a.comm.TestDeclarationMessage("未知", "自定义%mark")
    assert(reason:find("未匹配", 1, true))
    _, reason = a.comm.TestDeclarationMessage("a1b2c", "%text%mark%text")
    assert(reason:find("存在歧义", 1, true))
    equal(a.comm.GetDeclarationFormats(), saved); equal(a.db.declarationFormats, saved)
    equal(a.comm.GetFocus("party1").marker, 1); equal(a.state.changed, changed)
    equal(a.comm.TestDeclarationMessage("自定义3"), nil)
    equal(#a.state.chat, 0); equal(#a.state.addon, 0)
end

tests["secret messages draft formats and saved formats fail before any inspection"] = function()
    local a = boot(true)
    a.comm.SetAcceptCalls(true)
    a:event("CHAT_MSG_PARTY", "我打断星星", "Bob")
    local secret, before, changed = a:secret(), a.db.declarationFormats, a.state.changed
    equal(a.comm.TestDeclarationMessage(secret), nil)
    equal(a.comm.TestDeclarationMessage("我打断1", secret), nil)
    equal(a.comm.SetDeclarationFormats(secret), false)
    a:event("CHAT_MSG_PARTY", secret, "Bob")
    a:event("CHAT_MSG_PARTY", "我打断8", secret)
    equal(a.db.declarationFormats, before)
    equal(a.comm.GetFocus("party1").marker, 1); equal(a.state.changed, changed)
end

tests["successful save clears cached declarations and reload retains formats only"] = function()
    local a = boot(true)
    a.comm.SetAcceptCalls(true)
    a:event("CHAT_MSG_PARTY", "我打断星星", "Bob")
    equal(a.comm.SetDeclarationFormats("  指定{rt%mark}  \r\n"), true)
    equal(a.comm.GetFocus("party1").state, "pending")
    a:event("CHAT_MSG_PARTY", "我打断星星", "Bob")
    equal(a.comm.GetFocus("party1").state, "pending")
    a:event("CHAT_MSG_PARTY", "指定{rt5}", "Bob")
    equal(a.comm.GetFocus("party1").marker, 5)
    local reloaded = boot(true, { acceptFocusCalls = a.db.acceptFocusCalls, declarationFormats = a.db.declarationFormats })
    equal(reloaded.comm.GetDeclarationFormats(), "指定{rt%mark}")
    equal(reloaded.comm.GetFocus("party1").state, "pending", "received declarations are not saved")
    reloaded:event("CHAT_MSG_PARTY", "指定{rt6}", "Bob")
    equal(reloaded.comm.GetFocus("party1").marker, 6)
    equal(reloaded.comm.ResetDeclarationFormats(), reloaded.comm.GetDefaultDeclarationFormats())
    equal(reloaded.comm.GetFocus("party1").state, "pending")
    equal(reloaded.comm.TestDeclarationMessage("指定{rt6}"), nil)
    equal(reloaded.comm.TestDeclarationMessage("我打断6"), 6)
    local marker, line, name = reloaded.comm.TestDeclarationMessage("我的焦点打断是 {rt4} 训练假人")
    equal(marker, 4); equal(line, 2); equal(name, "训练假人")
end

tests["missing or corrupt saved formats migrate but an empty list survives reload"] = function()
    for _, saved in ipairs({ {}, { declarationFormats = false }, { declarationFormats = 4 },
        { declarationFormats = {} }, { declarationFormats = "%unknown" },
        { declarationFormats = string.rep("x", 8193) } }) do
        local a = boot(true, saved)
        equal(a.db.declarationFormats, a.comm.GetDefaultDeclarationFormats())
        equal(a.comm.TestDeclarationMessage("我打断8"), 8)
    end
    local a = boot(true, { declarationFormats = "" })
    equal(a.db.declarationFormats, "")
    equal(a.comm.TestDeclarationMessage("我打断8"), nil)
    a.comm.SetAcceptCalls(true)
    a:event("CHAT_MSG_PARTY", "我打断星星", "Bob")
    equal(a.comm.GetFocus("party1").state, "pending")
    local changed = a.state.changed
    a:event("CHAT_MSG_PARTY", "取消打断", "Bob")
    equal(a.state.changed, changed + 1, "fixed cancellation remains active with empty formats")
    equal(a.comm.SetDeclarationFormats(" \n\t\r\n"), true)
    equal(a.db.declarationFormats, "")
end

tests["custom receiver accepts public messages up to 255 bytes and preserves membership and opt-in checks"] = function()
    local a = boot(true)
    equal(a.comm.SetDeclarationFormats("%text:%mark"), true)
    local message = string.rep("a", 253) .. ":8"
    equal(#message, 255)
    a:event("CHAT_MSG_PARTY", message, "Bob")
    equal(a.comm.GetFocus("party1").state, "disabled")
    a.comm.SetAcceptCalls(true)
    a:event("CHAT_MSG_PARTY", message, "Bob")
    equal(a.comm.GetFocus("party1").marker, 8)
    a:event("CHAT_MSG_PARTY", string.rep("b", 254) .. ":1", "Bob")
    a:event("CHAT_MSG_PARTY", "a:1", "Eve")
    a:event("CHAT_MSG_PARTY", "a:1", "Bob-OtherRealm")
    equal(a.comm.GetFocus("party1").marker, 8)
    a:advance(300)
    equal(a.comm.GetFocus("party1").state, "pending")
end

tests["name formats capture public names with or without raid markers"] = function()
    local a = boot(true)
    equal(a.comm.SetDeclarationFormats("我打断%mark\n我的焦点打断是 {rt%mark} %name\nPTW焦点：%name"), true)
    local marker, line, name = a.comm.TestDeclarationMessage("PTW焦点：光耀播法者")
    equal(marker, nil); equal(line, 3); equal(name, "光耀播法者")
    for _, creature in ipairs({ "光耀播法者", "Arak's Sun-Priest", "数字1号" }) do
        marker, line, name = a.comm.TestDeclarationMessage("我的焦点打断是 {rt4} " .. creature,
            "我的焦点打断是 {rt%mark} %name")
        equal(marker, 4); equal(line, 1); equal(name, creature)
        marker, line, name = a.comm.TestDeclarationMessage("[" .. creature .. "]：骷髅",
            "[%name]：%mark")
        equal(marker, 8); equal(line, 1); equal(name, creature)
    end
    marker, line, name = a.comm.TestDeclarationMessage("前言：<目标名称>完成", "%text：<%name>完成")
    equal(marker, nil); equal(line, 1); equal(name, "目标名称")
    marker, line, name = a.comm.TestDeclarationMessage("我打断三角")
    equal(marker, 4); equal(line, 1); equal(name, nil)
end

tests["leading raid token in a declared name becomes an icon marker not creature text"] = function()
    local a = boot(true)
    equal(a.comm.SetDeclarationFormats("PTW焦点：%name"), true)
    for marker = 1, 8 do
        local got, line, name = a.comm.TestDeclarationMessage("PTW焦点：  {rt" .. marker .. "} 多刺的迅叶龙  ")
        equal(got, marker); equal(line, 1); equal(name, "多刺的迅叶龙")
    end
    local marker, line, name = a.comm.TestDeclarationMessage("PTW焦点：|cffff0000{rt4}|r |cffffffff多刺的迅叶龙|r")
    equal(marker, 4); equal(line, 1); equal(name, "多刺的迅叶龙")
    marker, line, name = a.comm.TestDeclarationMessage("PTW焦点：rt4something")
    equal(marker, nil); equal(line, 1); equal(name, "rt4something")
    marker, line, name = a.comm.TestDeclarationMessage("PTW焦点：{rt4}" .. string.rep("怪", 32))
    equal(marker, 4); equal(line, 1); equal(#name, 96)
    for _, invalid in ipairs({ "{rt0} Monster", "{rt9} Monster", "{rt04} Monster", "{rt4", "{rt4}",
        "{rt4} {rt5} Monster", "{rt4} %f", "{rt4} %T", "{rt4}" .. string.rep("怪", 33) }) do
        marker, line, name = a.comm.TestDeclarationMessage("PTW焦点：" .. invalid)
        equal(marker, nil); equal(name, nil); assert(type(line) == "string")
    end
    a.comm.SetAcceptCalls(true)
    a:event("CHAT_MSG_PARTY", "PTW焦点：{rt4} 多刺的迅叶龙", "Bob")
    local info = a.comm.GetFocus("party1")
    equal(info.state, "declared"); equal(info.marker, 4); equal(info.name, "多刺的迅叶龙")
    equal(info.hasDeclaredName, true)
    a:event("CHAT_MSG_PARTY", a:secret(), "Bob")
    equal(a.comm.GetFocus("party1").name, "多刺的迅叶龙")
    equal(#a.state.chat, 0); equal(#a.state.addon, 0)
end

tests["embedded raid tokens must agree with explicit markers and capture boundaries"] = function()
    local a = boot(true)
    local marker, line, name = a.comm.TestDeclarationMessage("指定三角：{rt4} Monster", "指定%mark：%name")
    equal(marker, 4); equal(line, 1); equal(name, "Monster")
    marker, line, name = a.comm.TestDeclarationMessage("指定三角：{rt8} Monster",
        "指定%mark：%name\n指定三角：%name")
    equal(marker, nil); equal(name, nil); assert(line:find("不一致", 1, true))
    marker, line, name = a.comm.TestDeclarationMessage("x:{rt4} Monster:y:{rt8} Monster:z",
        "%text:%name:%text")
    equal(marker, nil); equal(name, nil); assert(line:find("存在歧义", 1, true))
    a.comm.SetAcceptCalls(true)
    a.comm.SetDeclarationFormats("指定%mark：%name")
    a:event("CHAT_MSG_PARTY", "指定三角：{rt4} Original", "Bob")
    a:event("CHAT_MSG_PARTY", "指定三角：{rt8} Spoof", "Bob")
    equal(a.comm.GetFocus("party1").name, "Original")
    equal(a.comm.GetFocus("party1").marker, 4)
    equal(#a.state.chat, 0); equal(#a.state.addon, 0)
end

tests["name format validation avoids unrestricted chat capture and adjacent wildcard splits"] = function()
    local a = boot(true)
    local before = a.db.declarationFormats
    for _, invalid in ipairs({ "%name", " %name ", "%text%name", "%name%text", "x%name%text",
        "%text%namex", "%name%name", "%mark%mark%name", "x%text%text%text:%name" }) do
        equal(a.comm.SetDeclarationFormats(invalid), false)
        equal(a.db.declarationFormats, before)
    end
    equal(a.comm.SetDeclarationFormats("%name:%text"), true)
    equal(a.comm.SetDeclarationFormats("%mark%name"), true)
    equal(a.comm.SetDeclarationFormats("旧格式%mark"), true)
    local reloaded = boot(true, { declarationFormats = a.db.declarationFormats })
    equal(reloaded.db.declarationFormats, "旧格式%mark", "upgrade must preserve saved user formats")
end

tests["name captures remove markup and reject empty oversized and unexpanded values"] = function()
    local a = boot(true)
    equal(a.comm.SetDeclarationFormats("PTW焦点：%name"), true)
    local marker, line, name = a.comm.TestDeclarationMessage("PTW焦点：|cffff0000|Hunit:test|h怪物名字|h|r")
    equal(marker, nil); equal(line, 1); equal(name, "怪物名字")
    marker, line, name = a.comm.TestDeclarationMessage("PTW焦点：|Ticon:16|t  怪物|Aicon:16:16|a  名字 ||")
    equal(line, 1); equal(name, "怪物 名字"); assert(not name:find("|", 1, true))
    for _, invalid in ipairs({ "", " ", "%f", "%t", "%F", "%T", "|cffffffff|r", "|Ticon:16|t", string.rep("x", 97),
        string.rep("怪", 33) }) do
        marker, line, name = a.comm.TestDeclarationMessage("PTW焦点：" .. invalid)
        equal(marker, nil); equal(name, nil); assert(type(line) == "string")
    end
    marker, line, name = a.comm.TestDeclarationMessage("PTW焦点：" .. string.rep("怪", 32))
    equal(line, 1); equal(#name, 96)
end

tests["ambiguous name or marker captures fail instead of guessing or falling through"] = function()
    local a = boot(true)
    local marker, reason, name = a.comm.TestDeclarationMessage("focus a:One:Two:z",
        "focus %text:%name:%text\nfocus a:%name:z")
    equal(marker, nil); equal(name, nil); assert(reason:find("存在歧义", 1, true))
    marker, reason, name = a.comm.TestDeclarationMessage("focus a:1Foo:2Bar", "focus %text:%mark%name")
    equal(marker, nil); equal(name, nil); assert(reason:find("不同标记", 1, true))
    marker, reason, name = a.comm.TestDeclarationMessage("a:x:x:  Monster", "%text:x:%name")
    equal(marker, nil); equal(name, nil); assert(reason:find("不同名称", 1, true))
    -- Different wildcard paths before a fixed name boundary give the same name.
    marker, reason, name = a.comm.TestDeclarationMessage("abxyz:Monster", "%text%text:%name")
    equal(marker, nil); equal(reason, 1); equal(name, "Monster")
end

tests["name capture budget bounds adversarial formats"] = function()
    local a = boot(true)
    local message = string.rep("A", 75) .. string.rep("x", 97) .. string.rep("B", 75)
    local marker, reason, name = a.comm.TestDeclarationMessage(message,
        "%textA%nameB%text")
    -- Placeholder names require a literal delimiter; adjacent letters are unknown tokens.
    equal(marker, nil); equal(name, nil); assert(reason:find("格式错误", 1, true))
    message = string.rep(":A:", 30) .. string.rep("x", 97) .. string.rep(":B:", 20)
    local template = "%text:A:%name:B:%text"
    marker, reason, name = a.comm.TestDeclarationMessage(message, string.rep(template .. "\n", 16))
    equal(marker, nil); equal(name, nil); assert(reason:find("复杂", 1, true))
end

tests["named declarations retain membership secrecy expiry clearing and no sending"] = function()
    local a = boot(true)
    equal(a.comm.SetDeclarationFormats("我打断%mark\nPTW焦点：%name"), true)
    a:event("CHAT_MSG_PARTY", "PTW焦点：Ignored", "Bob")
    equal(a.comm.GetFocus("party1").state, "disabled")
    a.comm.SetAcceptCalls(true)
    a:event("CHAT_MSG_PARTY", "PTW焦点：光耀播法者", "Bob")
    local info = a.comm.GetFocus("party1")
    equal(info.state, "declared"); equal(info.name, "光耀播法者")
    equal(info.marker, nil); equal(info.hasDeclaredName, true)
    for _, sender in ipairs({ "Eve", "Bob-OtherRealm" }) do
        a:event("CHAT_MSG_PARTY", "PTW焦点：Spoof", sender)
    end
    a:event("CHAT_MSG_PARTY", a:secret(), "Bob")
    a:event("CHAT_MSG_PARTY", "PTW焦点：Secret sender", a:secret())
    equal(a.comm.GetFocus("party1").name, "光耀播法者")
    a.state.lockdown = true
    equal(a.comm.GetFocus("party1").name, "光耀播法者", "already public declarations remain readable")
    a:advance(300); equal(a.comm.GetFocus("party1").state, "pending")
    a:event("CHAT_MSG_PARTY", "PTW焦点：New name", "Bob")
    a:event("CHAT_MSG_PARTY", "取消打断", "Bob")
    equal(a.comm.GetFocus("party1").state, "pending")
    a:event("CHAT_MSG_PARTY", "我打断三角", "Bob")
    equal(a.comm.GetFocus("party1").hasDeclaredName, false)
    a:event("CHAT_MSG_PARTY", "PTW焦点：New name", "Bob")
    a.comm.SetDeclarationFormats("换格式%name")
    equal(a.comm.GetFocus("party1").state, "pending")
    equal(#a.state.chat, 0); equal(#a.state.addon, 0)
end

tests["name sample testing does not mutate declarations or saved settings"] = function()
    local a = boot(true)
    a.comm.SetAcceptCalls(true)
    a:event("CHAT_MSG_PARTY", "我打断三角", "Bob")
    local saved, changed = a.db.declarationFormats, a.state.changed
    local marker, line, name = a.comm.TestDeclarationMessage("焦点=<Creature>", "焦点=<%name>")
    equal(marker, nil); equal(line, 1); equal(name, "Creature")
    equal(a.db.declarationFormats, saved); equal(a.state.changed, changed)
    equal(a.comm.GetFocus("party1").name, "三角"); equal(a.comm.GetFocus("party1").hasDeclaredName, false)
    marker, line, name = a.comm.TestDeclarationMessage(a:secret(), "焦点=<%name>")
    equal(marker, nil); equal(name, nil)
    marker, line, name = a.comm.TestDeclarationMessage("焦点=<Creature>", a:secret())
    equal(marker, nil); equal(name, nil)
    equal(#a.state.chat, 0); equal(#a.state.addon, 0)
end

tests["target monitoring and chat declarations expose no outgoing announcement API"] = function()
    local a = boot(true)
    equal(a.comm.Announce, nil)
    equal(a.comm.GetAnnouncementStatus, nil)
    a.comm.SetAcceptCalls(true)
    equal(a.comm.SetDeclarationFormats("focus={rt%mark}"), true)
    a:event("CHAT_MSG_PARTY", "focus={rt8}", "Bob-TestRealm")
    equal(a.comm.GetFocus("party1").state, "declared")
    equal(a.comm.GetFocus("party1").marker, 8)
    a.state.names.focus = "Public Focus"
    a:event("PLAYER_FOCUS_CHANGED"); a:advance(1)
    equal(a.comm.GetFocus("player").name, "Public Focus")
    equal(#a.state.addon, 0, "no addon messages are sent")
    equal(#a.state.chat, 0, "receiving declarations must not send ordinary chat")
end

local names = {}
for name in pairs(tests) do names[#names + 1] = name end
table.sort(names)
for _, name in ipairs(names) do
    tests[name]()
    print("PASS communication: " .. name)
end
print("Communication tests passed: " .. #names)
