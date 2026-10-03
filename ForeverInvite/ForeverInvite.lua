-- ForeverInvite: auto-invite on whisper keyword + saved invite list.
-- Uses the modern C_* APIs when present and falls back to the old globals,
-- so the same file works on both new and classic-era clients.

local ADDON = ...
local PREFIX = "|cff33ff99ForeverInvite|r: "
local INVITE_DELAY = 0.5 -- seconds between invites when inviting a whole list

local defaults = {
    enabled = true,
    keywords = { "inv", "invite", "123" },
    guildOnly = false,
    autoRaid = true,
    list = {},
}

local db

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

---------------------------------------------------------------------------
-- API compatibility
---------------------------------------------------------------------------

local function InviteName(name)
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(name)
    elseif InviteUnit then
        InviteUnit(name)
    else
        InviteByName(name)
    end
end

local function GuildInviteName(name)
    if C_GuildInfo and C_GuildInfo.Invite then
        C_GuildInfo.Invite(name)
    else
        GuildInvite(name)
    end
end

local function GroupSize()
    if GetNumGroupMembers then
        return GetNumGroupMembers()
    end
    return math.max(GetNumRaidMembers(), GetNumPartyMembers() + 1)
end

local function InRaid()
    if IsInRaid then
        return IsInRaid()
    end
    return GetNumRaidMembers() > 0
end

local function MakeRaid()
    if C_PartyInfo and C_PartyInfo.ConvertToRaid then
        C_PartyInfo.ConvertToRaid()
    else
        ConvertToRaid()
    end
end

local function CanInvite()
    if GroupSize() <= 1 then
        return true
    end
    return UnitIsGroupLeader and UnitIsGroupLeader("player")
        or IsPartyLeader and IsPartyLeader()
        or IsRaidLeader and IsRaidLeader()
        or UnitIsGroupAssistant and UnitIsGroupAssistant("player")
        or IsRaidOfficer and IsRaidOfficer()
end

local function After(delay, fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, fn)
        return
    end
    local f = CreateFrame("Frame")
    local elapsed = 0
    f:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + (dt or arg1 or 0)
        if elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            fn()
        end
    end)
end

---------------------------------------------------------------------------
-- Inviting
---------------------------------------------------------------------------

local function Invite(name)
    if not CanInvite() then
        Print("Du måste vara gruppledare (eller assistent) för att bjuda in.")
        return false
    end
    -- A party caps at 5; once it is full, convert so the next person fits.
    if db.autoRaid and GroupSize() >= 5 and not InRaid() then
        MakeRaid()
    end
    InviteName(name)
    return true
end

local function InviteList()
    if #db.list == 0 then
        Print("Listan är tom. Lägg till med /finv add <namn>.")
        return
    end
    local me = UnitName("player")
    local queue = {}
    for _, name in ipairs(db.list) do
        if name ~= me and not UnitInParty(name) and not UnitInRaid(name) then
            table.insert(queue, name)
        end
    end
    if #queue == 0 then
        Print("Alla på listan är redan i gruppen.")
        return
    end
    Print("Bjuder in " .. #queue .. " spelare...")
    for i, name in ipairs(queue) do
        After((i - 1) * INVITE_DELAY, function() Invite(name) end)
    end
end

local function IsKeyword(msg)
    msg = strlower(strtrim(msg or ""))
    for _, kw in ipairs(db.keywords) do
        if msg == kw then
            return true
        end
    end
    return false
end

local function SenderAllowed(sender)
    if not db.guildOnly then
        return true
    end
    if IsGuildMember then
        return IsGuildMember(sender) or IsGuildMember(Ambiguate and Ambiguate(sender, "none") or sender)
    end
    -- Old clients: walk the guild roster.
    local short = strmatch(sender, "^[^-]+")
    for i = 1, GetNumGuildMembers() do
        local n = GetGuildRosterInfo(i)
        if n and strmatch(n, "^[^-]+") == short then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- List helpers
---------------------------------------------------------------------------

local function Capitalize(name)
    return strupper(strsub(name, 1, 1)) .. strlower(strsub(name, 2))
end

local function ListIndex(name)
    for i, n in ipairs(db.list) do
        if strlower(n) == strlower(name) then
            return i
        end
    end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function Help()
    Print("Kommandon:")
    Print("  /finv <namn>            - bjud in en spelare")
    Print("  /finv on | off          - slå på/av auto-invite på whisper")
    Print("  /finv kw <ord> [ord...] - sätt nyckelord (nu: " .. table.concat(db.keywords, ", ") .. ")")
    Print("  /finv guildonly         - växla: bara guildmedlemmar auto-invitas")
    Print("  /finv raid              - växla: gör om till raid automatiskt")
    Print("  /finv add <namn>        - lägg till i listan")
    Print("  /finv del <namn>        - ta bort från listan")
    Print("  /finv list              - visa listan")
    Print("  /finv all               - bjud in alla på listan")
    Print("  /finv clear             - töm listan")
    Print("  /finv ginv <namn>       - guild-invite")
    Print("  /finv status            - visa inställningar")
end

local function OnOff(v)
    return v and "|cff00ff00PÅ|r" or "|cffff0000AV|r"
end

local function Status()
    Print("Auto-invite: " .. OnOff(db.enabled)
        .. "  Bara guild: " .. OnOff(db.guildOnly)
        .. "  Auto-raid: " .. OnOff(db.autoRaid))
    Print("Nyckelord: " .. table.concat(db.keywords, ", "))
    Print("Spelare i listan: " .. #db.list)
end

local function HandleSlash(input)
    input = strtrim(input or "")
    local cmd, rest = strmatch(input, "^(%S*)%s*(.-)$")
    cmd = strlower(cmd or "")

    if cmd == "" or cmd == "help" then
        Help()
    elseif cmd == "on" then
        db.enabled = true
        Print("Auto-invite " .. OnOff(true))
    elseif cmd == "off" then
        db.enabled = false
        Print("Auto-invite " .. OnOff(false))
    elseif cmd == "kw" then
        if rest == "" then
            Print("Ange minst ett nyckelord, t.ex. /finv kw inv 123")
            return
        end
        db.keywords = {}
        for word in gmatch(rest, "%S+") do
            table.insert(db.keywords, strlower(word))
        end
        Print("Nyckelord: " .. table.concat(db.keywords, ", "))
    elseif cmd == "guildonly" then
        db.guildOnly = not db.guildOnly
        Print("Bara guild: " .. OnOff(db.guildOnly))
    elseif cmd == "raid" then
        db.autoRaid = not db.autoRaid
        Print("Auto-raid: " .. OnOff(db.autoRaid))
    elseif cmd == "add" then
        if rest == "" then return Print("Användning: /finv add <namn>") end
        for word in gmatch(rest, "%S+") do
            local name = Capitalize(word)
            if ListIndex(name) then
                Print(name .. " finns redan i listan.")
            else
                table.insert(db.list, name)
                Print("La till " .. name .. ".")
            end
        end
    elseif cmd == "del" or cmd == "remove" then
        local i = ListIndex(rest)
        if i then
            Print("Tog bort " .. table.remove(db.list, i) .. ".")
        else
            Print(rest .. " finns inte i listan.")
        end
    elseif cmd == "list" then
        if #db.list == 0 then
            Print("Listan är tom.")
        else
            Print("Lista (" .. #db.list .. "): " .. table.concat(db.list, ", "))
        end
    elseif cmd == "all" then
        InviteList()
    elseif cmd == "clear" then
        db.list = {}
        Print("Listan är tömd.")
    elseif cmd == "ginv" then
        if rest == "" then return Print("Användning: /finv ginv <namn>") end
        GuildInviteName(rest)
        Print("Skickade guild-invite till " .. rest .. ".")
    elseif cmd == "status" then
        Status()
    else
        -- Anything else is treated as a player name.
        if Invite(input) then
            Print("Bjöd in " .. input .. ".")
        end
    end
end

SLASH_FOREVERINVITE1 = "/finv"
SLASH_FOREVERINVITE2 = "/foreverinvite"
SlashCmdList["FOREVERINVITE"] = HandleSlash

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_WHISPER")
frame:RegisterEvent("CHAT_MSG_BN_WHISPER")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ... or arg1
        if name ~= ADDON and name ~= "ForeverInvite" then return end
        ForeverInviteDB = ForeverInviteDB or {}
        for k, v in pairs(defaults) do
            if ForeverInviteDB[k] == nil then
                ForeverInviteDB[k] = type(v) == "table" and {} or v
                if type(v) == "table" then
                    for i, x in ipairs(v) do ForeverInviteDB[k][i] = x end
                end
            end
        end
        db = ForeverInviteDB
        self:UnregisterEvent("ADDON_LOADED")
        Print("laddat. Skriv /finv för hjälp.")
        return
    end

    if not db or not db.enabled then return end

    local msg, sender = ...
    if event == "CHAT_MSG_BN_WHISPER" then
        -- Battle.net whispers carry no character name; only invite if we can resolve one.
        local bnetID = select(13, ...)
        sender = nil
        if bnetID and C_BattleNet and C_BattleNet.GetAccountInfoByID then
            local info = C_BattleNet.GetAccountInfoByID(bnetID)
            local game = info and info.gameAccountInfo
            if game and game.characterName and game.isOnline then
                sender = game.realmName and (game.characterName .. "-" .. game.realmName) or game.characterName
            end
        end
        if not sender then return end
    end

    if IsKeyword(msg) and SenderAllowed(sender) then
        if Invite(sender) then
            Print("Auto-invite: " .. sender)
        end
    end
end)
