-- CBAS - Version & Update-Hinweis
-- Addons duerfen im Spiel nicht ins Internet. Neue Versionen erfaehrt CBAS darum
--  1) von anderen CBAS-Spielern (Gilde, Gruppe): jedes CBAS nennt beim Einloggen/Gruppenbeitritt
--     unsichtbar seine Versionsnummer - eine kurze Addon-Nachricht, gedrosselt;
--  2) aus der Claude-Tipp-Datei (CBAS_CLAUDE.latest = neueste Version auf GitHub).
local ADDON, ns = ...
local V = {}
ns.Version = V

V.URL = "https://github.com/Gastpilot/CBAS/releases/latest/download/CBAS.zip"
V.PAGE = "https://github.com/Gastpilot/CBAS/releases"
local PREFIX = "CBASv"
local THROTTLE = 300          -- je Kanal hoechstens alle 5 Min. senden
local lastSent = {}
local announced = false

function V.Parse(s)
    if type(s) ~= "string" then return nil end
    local a, b, c = s:match("^v?(%d+)%.(%d+)%.?(%d*)$")
    if not a then return nil end
    return tonumber(a), tonumber(b), tonumber(c) or 0
end

-- ist Version x neuer als y?
function V.Newer(x, y)
    local a1, b1, c1 = V.Parse(x)
    local a2, b2, c2 = V.Parse(y)
    if not a1 or not a2 then return false end
    if a1 ~= a2 then return a1 > a2 end
    if b1 ~= b2 then return b1 > b2 end
    return c1 > c2
end

-- neueste bekannte Version, falls neuer als die installierte
function V.Latest()
    local s = ns.db and ns.db.settings
    if not s or not s.newestVersion then return nil end
    if not V.Newer(s.newestVersion, ns.VERSION) then
        s.newestVersion, s.newestFrom, s.newestT = nil, nil, nil   -- inzwischen aktualisiert
        return nil
    end
    return s.newestVersion, s.newestFrom, s.newestT
end

function V.UpdateBadge()
    local S = ns.Suite
    if not (S and S.gear) then return end
    if not S.gearBadge then
        local b = S.gear:CreateTexture(nil, "OVERLAY")
        b:SetSize(8, 8)
        b:SetPoint("TOPRIGHT", 3, 3)
        b:SetColorTexture(0.2, 1, 0.2, 1)
        S.gearBadge = b
    end
    S.gearBadge:SetShown(V.Latest() and true or false)
    if ns.Standards then pcall(ns.Standards.UpdateMinimap) end
end

function V.Announce(force)
    local ver = V.Latest()
    if not ver or (announced and not force) then return end
    announced = true
    ns.Print(string.format("|cff40ff40Neue Version %s verfügbar|r (du hast %s). Download-Link: Zahnrad > Version, oder |cffffd100/crap version|r.",
        ver, ns.VERSION))
    V.UpdateBadge()
end

function V.Note(ver, from)
    if not ns.db or not V.Parse(ver) or not V.Newer(ver, ns.VERSION) then return end
    local s = ns.db.settings
    if s.newestVersion and not V.Newer(ver, s.newestVersion) then return end
    s.newestVersion, s.newestFrom, s.newestT = ver, from, time()
    announced = false
    V.Announce()
    if ns.Suite and ns.Suite.current == "settings" and V.UpdateSettings then V.UpdateSettings() end
end

local function CanSend()
    if InCombatLockdown() then return false end
    local inInst = IsInInstance and IsInInstance()
    return not inInst      -- in Instanzen sind Addon-Nachrichten auf Forever gesperrt
end

function V.Send(channel, force)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) or not CanSend() then return end
    local now = GetTime()
    if not force and lastSent[channel] and now - lastSent[channel] < THROTTLE then return end
    lastSent[channel] = now
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, "V:" .. ns.VERSION, channel)
    -- eigenes Land fuer die Chat-Flaggen der anderen
    local c = ns.ChatFlags and ns.ChatFlags.My()
    if c then pcall(C_ChatInfo.SendAddonMessage, PREFIX, "C:" .. c, channel) end
end

-- nach Aendern des eigenen Landes sofort in Gilde/Gruppe bekanntgeben
function V.SendCountry()
    local c = ns.ChatFlags and ns.ChatFlags.My()
    if not c or not CanSend() then return end
    local chans = {}
    if IsInGuild and IsInGuild() then chans[#chans + 1] = "GUILD" end
    if IsInRaid and IsInRaid() then chans[#chans + 1] = "RAID" elseif IsInGroup and IsInGroup() then chans[#chans + 1] = "PARTY" end
    for _, ch in ipairs(chans) do pcall(C_ChatInfo.SendAddonMessage, PREFIX, "C:" .. c, ch) end
end

local function GroupChannel()
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
end

---------------------------------------------------------------------------
-- Einstellungen: Versionsblock (oben rechts)
---------------------------------------------------------------------------
function V.BuildSettings(p)
    local box = CreateFrame("Frame", nil, p, "BackdropTemplate")
    box:SetSize(330, 118)
    box:SetPoint("TOPRIGHT", -22, -36)
    if box.SetBackdrop then
        box:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        box:SetBackdropColor(0, 0, 0, 0.45)
    end
    local h = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetPoint("TOPLEFT", 10, -8)
    h:SetText("Version")
    local st = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    st:SetPoint("TOPLEFT", 10, -26)
    st:SetPoint("TOPRIGHT", -10, -26)
    st:SetJustifyH("LEFT")
    st:SetSpacing(2)
    box.status = st
    local e = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
    e:SetSize(306, 20)
    e:SetPoint("BOTTOMLEFT", 14, 26)
    e:SetAutoFocus(false)
    e:SetText(V.URL)
    e:SetCursorPosition(0)
    -- nur zum Kopieren: Text laesst sich nicht veraendern
    e:SetScript("OnTextChanged", function(self, user) if user then self:SetText(V.URL); self:HighlightText() end end)
    e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    e:SetScript("OnMouseUp", function(self) self:SetFocus(); self:HighlightText() end)
    e:SetScript("OnEscapePressed", e.ClearFocus)
    e:SetScript("OnEnterPressed", e.ClearFocus)
    box.link = e
    local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 10, 10)
    hint:SetText("Link anklicken, Strg+C, im Browser einfügen. Zip nach Interface\\AddOns entpacken.")
    p.versionBox = box
    V.box = box
    V.UpdateSettings()
end

function V.UpdateSettings()
    local box = V.box
    if not box then return end
    local ver, from, t = V.Latest()
    if ver then
        box.status:SetText(string.format("Installiert: |cffffffff%s|r\n|cff40ff40Neue Version %s verfügbar!|r |cff888888(gemeldet von %s, vor %s)|r",
            ns.VERSION, ver, from or "?", ns.Ago(t)))
    else
        box.status:SetText(string.format("Installiert: |cffffffff%s|r\n|cff888888Keine neuere Version bekannt.|r", ns.VERSION))
    end
    V.UpdateBadge()
end

function V.Slash()
    local ver = V.Latest()
    ns.Print(string.format("Version %s%s. Download (immer die neueste): %s", ns.VERSION,
        ver and (" - |cff40ff40neue Version " .. ver .. " verfügbar|r") or "", V.URL))
    if ns.Suite then ns.Suite:Toggle("settings") end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, prefix, msg, channel, sender)
    if event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
        pcall(ev.RegisterEvent, ev, "CHAT_MSG_ADDON")
        pcall(ev.RegisterEvent, ev, "GROUP_ROSTER_UPDATE")
        -- Claude-Tipp-Datei kennt die neueste Version auf GitHub
        local c = _G.CBAS_CLAUDE
        if type(c) == "table" and c.latest then V.Note(c.latest, "GitHub") end
        C_Timer.After(20, function()
            pcall(V.Announce)
            if IsInGuild and IsInGuild() then pcall(V.Send, "GUILD") end
            local gc = GroupChannel()
            if gc then pcall(V.Send, gc) end
        end)
    elseif event == "GROUP_ROSTER_UPDATE" then
        local gc = GroupChannel()
        if gc then C_Timer.After(5, function() pcall(V.Send, gc) end) end
    elseif event == "CHAT_MSG_ADDON" then
        if prefix ~= PREFIX then return end
        msg, sender = ns.S(msg), ns.S(sender)
        if type(msg) ~= "string" then return end
        if msg:sub(1, 2) == "C:" then
            if ns.ChatFlags then ns.ChatFlags.OnAddon(msg, sender) end
            return
        end
        local ver = msg:match("^V:(.+)$")
        if not ver then return end
        V.Note(ver, sender and ns.SplitName and ns.SplitName(sender) or sender)
        -- hat der andere eine aeltere Version: einmal antworten, damit er es auch erfaehrt
        if V.Newer(ns.VERSION, ver) and (channel == "GUILD" or channel == "PARTY" or channel == "RAID") then
            C_Timer.After(2 + math.random() * 6, function() pcall(V.Send, channel) end)
        end
    end
end)
