-- Pure mocks: no real chat, network, WoW engine secrets, or key bindings.
local source = assert(COMMUNICATION_SOURCE, "COMMUNICATION_SOURCE is required")
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function boot(enabled, grouped)
    local state = { time = 0, group = grouped or false, raid = false, instance = false,
        names = { player = "Alice", target = "Training Dummy", party1 = "Bob", party1target = "Other Dummy" },
        realms = { player = "Test Realm", party1 = "Test Realm" },
        marker = {}, secrets = {}, exists = {}, errors = {}, offline = {},
        addon = {}, chat = {}, notices = {}, changed = 0, registered = {},
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
    env.C_ChatInfo.SendChatMessage = function(message, channel)
        assert(type(message) == "string")
        if state.chatError then error("mock chat blocked") end
        state.chat[#state.chat + 1] = { message = message, channel = channel, time = state.time }
    end
    local frame = { scripts = {}, events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(event, fn) self.scripts[event] = fn end
    env.CreateFrame = function() return frame end
    local namespace = {}
    local chunk = assert(loadstring(source, "@Communication.lua"))
    setfenv(chunk, env)
    chunk("PartyTargetWatch", namespace)
    local comm = namespace.Communication
    local settings = { shareFocus = enabled == true }
    comm.Init(settings, function(message) state.notices[#state.notices + 1] = message end,
        function() state.changed = state.changed + 1 end)
    comm.RebuildRoster({ "player", "party1" })
    local app = { state = state, env = env, comm = comm, db = settings }
    function app:advance(seconds)
        state.time = state.time + seconds
        frame.scripts.OnUpdate(frame, seconds)
    end
    function app:event(event, ...)
        if frame.events[event] then frame.scripts.OnEvent(frame, event, ...) end
    end
    function app:receive(message, sender, channel, prefix)
        self:event("CHAT_MSG_ADDON", prefix or "PTWFocus1", message, channel or "PARTY", sender or "Bob-TestRealm")
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

tests["sharing defaults off; own focus reads locally without sends"] = function()
    local a = boot(false, false)
    equal(a.state.registered[1], "PTWFocus1")
    a.state.names.focus = "Local Focus"
    equal(a.comm.GetFocus("player").name, "Local Focus")
    equal(a.comm.GetFocus("party1").state, "disabled")
    a:advance(20)
    equal(#a.state.addon, 0)
    equal(#a.state.chat, 0)
    local ok, reason = a.comm.Announce("player")
    equal(ok, false); equal(reason, "solo")
    equal(#a.state.chat, 0)
end

tests["announcement channels and click-only throttle"] = function()
    local a = boot(false, true)
    a.state.marker.target = 8
    equal(a.comm.Announce("player"), true)
    equal(a.state.chat[1].channel, "PARTY")
    assert(a.state.chat[1].message:find("{rt8}", 1, true))
    local ok, reason = a.comm.Announce("party1")
    equal(ok, false); equal(reason, "throttle")
    a:advance(3)
    a.state.raid = true
    equal(a.comm.Announce("party1"), true)
    equal(a.state.chat[2].channel, "RAID")
    assert(a.state.chat[2].message:find("Bob", 1, true))
    assert(a.state.chat[2].message:find("Other Dummy", 1, true))
    a:advance(3); a.state.instance = true
    equal(a.comm.Announce("target"), true)
    equal(a.state.chat[3].channel, "INSTANCE_CHAT")
    a:advance(20)
    equal(#a.state.chat, 3, "updates never queue public chat")
    equal(#a.state.addon, 0, "sharing remains off")
end

tests["announcement sanitizes names and rejects secret or missing data"] = function()
    local a = boot(false, true)
    a.state.names.target = "|cffff0000|Hspell:123|hBad\nName|h|r {rt8}"
    equal(a.comm.Announce("player"), true)
    local message = a.state.chat[1].message
    assert(not message:find("|", 1, true) and not message:find("\n", 1, true))
    assert(not message:find("{", 1, true))
    a:advance(3); a.state.names.target = a:secret()
    local ok, reason = a.comm.Announce("player")
    equal(ok, false); equal(reason, "restricted"); equal(#a.state.chat, 1)
    a.state.names.target = nil
    ok, reason = a.comm.Announce("player")
    equal(ok, false); equal(reason, "none")
    a.state.names.target = "Dummy"; a.state.exists.target = a:secret()
    ok, reason = a.comm.Announce("player")
    equal(ok, false); equal(reason, "restricted")
    a.state.exists.target = nil; a.state.names.player = a:secret()
    ok, reason = a.comm.Announce("player")
    equal(ok, false); equal(reason, "restricted")
    equal(#a.state.chat, 1)
end

tests["secret marker omitted and announcement failures are not retried"] = function()
    local a = boot(false, true)
    a.state.marker.target = a:secret()
    equal(a.comm.Announce("player"), true)
    assert(not a.state.chat[1].message:find("{rt", 1, true))
    a:advance(3); a.state.chatError = true
    local ok, reason = a.comm.Announce("player")
    equal(ok, false); equal(reason, "failed")
    a.state.chatError = false; a:advance(20)
    equal(#a.state.chat, 1)
    a.state.lockdown = true
    ok, reason = a.comm.Announce("player")
    equal(ok, false); equal(reason, "restricted")
end

tests["sharing handshakes, sends bounded snapshots and heartbeats"] = function()
    local a = boot(true, true)
    equal(a.state.addon[1].message, "1|Q")
    a.state.names.focus = "Focus Dummy"; a.state.marker.focus = 3
    a:advance(1)
    equal(a.state.addon[2].message, "1|O|3|Focus Dummy")
    a:advance(0.25); equal(#a.state.addon, 2)
    a:advance(4); equal(#a.state.addon, 3)
    equal(a.state.addon[3].message, "1|O|3|Focus Dummy")
    for i = 2, #a.state.addon do
        assert(a.state.addon[i].time - a.state.addon[i - 1].time >= 1)
    end
    a:receive("1|Q"); a:advance(1)
    equal(#a.state.addon, 4)
    equal(a.state.addon[4].message, "1|O|3|Focus Dummy")
    equal(#a.state.chat, 0)
end

tests["remote snapshots require enabled sharing and current full roster identity"] = function()
    local a = boot(true, true)
    a:receive("1|O|2|Remote Focus")
    local info = a.comm.GetFocus("party1")
    equal(info.state, "ok"); equal(info.name, "Remote Focus"); equal(info.marker, 2)
    a:advance(1)
    a:receive("1|O|0|Wrong Realm", "Bob-OtherRealm")
    a:receive("1|O|0|Outsider", "Eve-TestRealm")
    a:receive("1|O|0|Wrong Channel", "Bob-TestRealm", "GUILD")
    a:receive("1|O|0|Wrong Prefix", "Bob-TestRealm", "PARTY", "AnotherAddon")
    equal(a.comm.GetFocus("party1").name, "Remote Focus")
    a:receive("1|O|0|Local Realm Short Sender", "Bob")
    equal(a.comm.GetFocus("party1").name, "Local Realm Short Sender")
    for key in pairs(a.db) do
        assert(key == "shareFocus" or key == "acceptFocusCalls", "no received data in saved variables")
    end
    a.comm.SetEnabled(false)
    a:receive("1|O|0|Ignored")
    equal(a.comm.GetFocus("party1").state, "disabled")
end

tests["malformed and secret packets cannot replace or refresh snapshots"] = function()
    local a = boot(true, true)
    a:receive("1|O|0|Original")
    a:advance(10)
    for _, bad in ipairs({ "2|N", "1|O|9|bad", "1|O|1.5|bad", "1|O|1|", "1|D|extra",
        "1|O|0|line\nbreak", "1|O|0||Hfoo|hbar|h", "1|O|0|{rt8} spoof",
        "1|O|0|" .. string.rep("x", 97), string.rep("x", 113) }) do a:receive(bad) end
    a:receive(a:secret())
    a:receive("1|N", a:secret())
    a:receive("1|N", "Bob", a:secret())
    a:receive("1|N", "Bob", "PARTY", a:secret())
    equal(a.comm.GetFocus("party1").name, "Original")
    a:advance(2)
    equal(a.comm.GetFocus("party1").state, "stale")
    equal(a.comm.GetFocus("party1").name, nil)
end

tests["explicit no-focus restricted unavailable and disabled states clear names"] = function()
    local a = boot(true, true)
    local expected = { N = "none", R = "restricted", U = "unavailable", D = "disabled" }
    for code, state in pairs(expected) do
        a:advance(1); a:receive("1|O|0|Old Focus")
        a:receive("1|" .. code)
        equal(a.comm.GetFocus("party1").state, state)
        equal(a.comm.GetFocus("party1").name, nil)
    end
end

tests["own focus clears promptly and never serializes secret values"] = function()
    local a = boot(true, true)
    a.state.names.focus = "Old Focus"; a:advance(1)
    a.state.names.focus = a:secret(); a:event("PLAYER_FOCUS_CHANGED")
    equal(a.comm.GetFocus("player").state, "restricted")
    a:advance(1)
    equal(a.state.addon[#a.state.addon].message, "1|R")
    a.state.names.focus = nil; a:advance(1)
    equal(a.comm.GetFocus("player").state, "none")
    equal(a.state.addon[#a.state.addon].message, "1|N")
    a.state.names.focus = "Focus"; a.state.errors.focus = "name"; a:advance(1)
    equal(a.comm.GetFocus("player").state, "unavailable")
    equal(a.state.addon[#a.state.addon].message, "1|U")
end

tests["lockdown clears cached snapshots and restriction event fails closed"] = function()
    local a = boot(true, true)
    a:receive("1|O|0|Old Focus")
    a.state.lockdown = true
    equal(a.comm.GetFocus("party1").state, "restricted")
    a:advance(1); local sent = #a.state.addon
    a:receive("1|O|0|Must Not Be Accepted"); a:advance(10)
    equal(#a.state.addon, sent)
    a.state.lockdown = false; a:advance(1)
    equal(a.comm.GetFocus("party1").state, "pending")
    a:receive("1|O|0|New Focus")
    a:event("ADDON_RESTRICTION_STATE_CHANGED", 1, true)
    equal(a.comm.GetFocus("party1").state, "restricted", "event-time false APIs do not unlock")
    a:advance(1)
    equal(a.comm.GetFocus("party1").state, "pending")
end

tests["disable broadcasts a clear once and reenable requests fresh data"] = function()
    local a = boot(true, true)
    a:advance(1); a:receive("1|O|0|Old Focus")
    a.comm.SetEnabled(false)
    equal(a.comm.GetFocus("party1").state, "disabled")
    a:advance(1)
    equal(a.state.addon[#a.state.addon].message, "1|D")
    local sent = #a.state.addon; a:advance(20)
    equal(#a.state.addon, sent)
    a.comm.SetEnabled(true); a:advance(1)
    equal(a.state.addon[#a.state.addon].message, "1|Q")
    equal(a.comm.GetFocus("party1").state, "pending")
end

tests["roster changes and leaving clear old token associations"] = function()
    local a = boot(true, true)
    a:receive("1|O|0|Bob Focus")
    a.state.names.party1 = "Carol"
    a.comm.RebuildRoster({ "player", "party1" })
    equal(a.comm.GetFocus("party1").state, "pending")
    a:receive("1|O|0|Bob Again")
    equal(a.comm.GetFocus("party1").state, "pending")
    a:receive("1|O|0|Carol Focus", "Carol-TestRealm")
    equal(a.comm.GetFocus("party1").name, "Carol Focus")
    a.state.group = false; a.comm.RebuildRoster({ "player" })
    equal(a.comm.GetFocus("party1").state, "unavailable")
    local sent = #a.state.addon; a:advance(20); equal(#a.state.addon, sent)
    a.state.group = true; a.comm.RebuildRoster({ "player", "party1" })
    equal(a.comm.GetFocus("party1").state, "pending")
end

tests["API send rejection respects throttle and retries only addon snapshots"] = function()
    local a = boot(true, true)
    a.state.sendResult = 11
    a:advance(1); local sent = #a.state.addon
    a:advance(0.25); equal(#a.state.addon, sent)
    a:advance(0.75); equal(#a.state.addon, sent + 1)
    a.state.outgoingRestricted = true
    sent = #a.state.addon; a:advance(10); equal(#a.state.addon, sent)
    a.state.outgoingRestricted = false; a.state.sendResult = 0
    a:advance(1); equal(#a.state.addon, sent + 1)
end

tests["strict public chat declarations are opt-in and independent of sharing"] = function()
    local a = boot(false, true)
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
    equal(a.comm.GetFocus("party1").state, "disabled")
end

tests["declarations reject mentions malformed messages outsiders and secrets"] = function()
    local a = boot(false, true)
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

tests["automatic focus takes priority while declarations survive local lockdown"] = function()
    local a = boot(true, true)
    a.comm.SetAcceptCalls(true)
    a:event("CHAT_MSG_PARTY", "我打断月亮", "Bob-TestRealm")
    a:receive("1|O|1|Actual Focus")
    equal(a.comm.GetFocus("party1").state, "ok")
    equal(a.comm.GetFocus("party1").name, "Actual Focus")
    a.state.lockdown = true; a:advance(1)
    equal(a.comm.GetFocus("party1").state, "declared")
    equal(a.comm.GetFocus("party1").marker, 5)
    a:event("ADDON_RESTRICTION_STATE_CHANGED", 1, true)
    equal(a.comm.GetFocus("party1").state, "declared")
    a.comm.SetEnabled(false)
    equal(a.comm.GetFocus("party1").state, "declared")
    a.state.lockdown = false; a:advance(1)
    a:event("CHAT_MSG_PARTY", "我打断方块", "Alice-TestRealm")
    equal(a.comm.GetFocus("player").state, "declared")
    a.state.names.focus = "My Real Focus"
    equal(a.comm.GetFocus("player").state, "ok")
    equal(a.comm.GetFocus("player").name, "My Real Focus")
end

tests["declarations expire and clear on disable roster or scene changes"] = function()
    local a = boot(false, true)
    a.comm.SetAcceptCalls(true)
    a:event("CHAT_MSG_PARTY", "我打断星星", "Bob-TestRealm")
    a:advance(299); equal(a.comm.GetFocus("party1").state, "declared")
    a:advance(1); equal(a.comm.GetFocus("party1").state, "disabled")
    a:event("CHAT_MSG_PARTY", "我打断星星", "Bob-TestRealm")
    a.comm.SetAcceptCalls(false); a.comm.SetAcceptCalls(true)
    equal(a.comm.GetFocus("party1").state, "disabled")
    a:event("CHAT_MSG_PARTY", "我打断星星", "Bob-TestRealm")
    a:event("PLAYER_ENTERING_WORLD")
    equal(a.comm.GetFocus("party1").state, "disabled")
    a:event("CHAT_MSG_PARTY", "我打断星星", "Bob-TestRealm")
    a.state.group = false; a.comm.RebuildRoster({ "player" })
    a.state.group = true; a.comm.RebuildRoster({ "player", "party1" })
    equal(a.comm.GetFocus("party1").state, "disabled")
end

local names = {}
for name in pairs(tests) do names[#names + 1] = name end
table.sort(names)
for _, name in ipairs(names) do
    tests[name]()
    print("PASS communication: " .. name)
end
print("Communication tests passed: " .. #names)
