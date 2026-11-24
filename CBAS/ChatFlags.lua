-- CBAS - Laenderflaggen im Chat:  [Gruppe] <Flagge> Name: ...
-- WoW verraet keinem Addon, wo ein Spieler wirklich sitzt. Das Land wird abgeleitet, in dieser Rangfolge:
--  1) CBAS-Spieler nennen ihr Land selbst (unsichtbare Addon-Nachricht)          -> sicher
--  2) eigene Angabe im Chat ("bin aus Oesterreich", "from Sweden", "[AT]")         -> sehr wahrscheinlich
--  3) Sprache der eigenen Chatnachrichten (Deutsch -> DE, Franzoesisch -> FR ...)  -> wahrscheinlich
--  4) Sprache der Gilde (GScout)                                                   -> Notnagel
-- Englisch ergibt keine Flagge (auf EU-Servern schreiben alle Englisch). Unklar = keine Flagge.
local ADDON, ns = ...
local S = ns.S
local CF = {}
ns.ChatFlags = CF

local PATH = "Interface\\AddOns\\" .. ADDON .. "\\Flags\\"
CF.CODES = { "DE", "AT", "CH", "FR", "BE", "NL", "GB", "IE", "ES", "PT", "IT", "PL", "CZ", "HU", "RO", "LT",
    "SE", "NO", "DK", "FI", "RU", "UA", "GR", "TR", "US", "BR" }
CF.NAMES = { DE = "Deutschland", AT = "Österreich", CH = "Schweiz", FR = "Frankreich", BE = "Belgien", NL = "Niederlande",
    GB = "Großbritannien", IE = "Irland", ES = "Spanien", PT = "Portugal", IT = "Italien", PL = "Polen", CZ = "Tschechien",
    HU = "Ungarn", RO = "Rumänien", LT = "Litauen", SE = "Schweden", NO = "Norwegen", DK = "Dänemark", FI = "Finnland",
    RU = "Russland", UA = "Ukraine", GR = "Griechenland", TR = "Türkei", US = "USA", BR = "Brasilien" }
local VALID = {}
for _, c in ipairs(CF.CODES) do VALID[c] = true end

-- Sprache -> Land (Englisch bewusst nicht)
local LANG2C = { DE = "DE", FR = "FR", ES = "ES", IT = "IT", PT = "PT", PL = "PL", NL = "NL", RU = "RU" }
local LOCALE2C = { deDE = "DE", frFR = "FR", esES = "ES", itIT = "IT", ptPT = "PT", ptBR = "BR", ruRU = "RU", enGB = "GB" }

-- eigene Angaben im Chat (klein geschrieben, ohne Muster - schnell)
local SAYS = {
    { "aus österreich", "AT" }, { "aus oesterreich", "AT" }, { "from austria", "AT" }, { "[at]", "AT" },
    { "aus der schweiz", "CH" }, { "from switzerland", "CH" }, { "[ch]", "CH" },
    { "aus deutschland", "DE" }, { "from germany", "DE" },
    { "from the uk", "GB" }, { "from uk", "GB" }, { "from england", "GB" }, { "from scotland", "GB" },
    { "from wales", "GB" }, { "[uk]", "GB" }, { "from ireland", "IE" },
    { "from france", "FR" }, { "aus frankreich", "FR" }, { "from belgium", "BE" }, { "aus belgien", "BE" },
    { "from the netherlands", "NL" }, { "from holland", "NL" }, { "aus holland", "NL" }, { "aus den niederlanden", "NL" },
    { "from spain", "ES" }, { "aus spanien", "ES" }, { "from portugal", "PT" }, { "from italy", "IT" }, { "aus italien", "IT" },
    { "from poland", "PL" }, { "aus polen", "PL" }, { "from czech", "CZ" }, { "aus tschechien", "CZ" },
    { "from hungary", "HU" }, { "aus ungarn", "HU" }, { "from romania", "RO" }, { "from lithuania", "LT" },
    { "from sweden", "SE" }, { "aus schweden", "SE" }, { "from norway", "NO" }, { "aus norwegen", "NO" },
    { "from denmark", "DK" }, { "aus dänemark", "DK" }, { "from finland", "FI" }, { "aus finnland", "FI" },
    { "from russia", "RU" }, { "from ukraine", "UA" }, { "from greece", "GR" }, { "aus griechenland", "GR" },
    { "from turkey", "TR" }, { "aus der türkei", "TR" }, { "from the us", "US" }, { "from usa", "US" },
    { "from america", "US" }, { "from brazil", "BR" }, { "from brasil", "BR" },
}

local function Enabled() return ns.db and ns.db.settings.chatFlags ~= false end

function CF.My()
    local s = ns.db and ns.db.settings
    if s and s.myCountry and VALID[s.myCountry] then return s.myCountry end
    return LOCALE2C[GetLocale and GetLocale() or ""]
end

function CF.Icon(code, size)
    if not code or not VALID[code] then return "" end
    size = size or 11
    -- Textur 32x32, Flagge in den oberen 21 Zeilen
    return string.format("|T%s%s:%d:%d:0:0:32:32:0:32:0:21|t", PATH, code:lower(), size, math.floor(size * 1.5 + 0.5))
end

local function DB()
    ns.db.country = ns.db.country or {}
    return ns.db.country
end

-- Land eines Spielers bestimmen: Code, Quelle
function CF.CountryOf(full)
    if not full then return nil end
    if not CF.me then
        local n = UnitName and UnitName("player")
        CF.me = n and ns.NormFull(n)
    end
    if CF.me and full == CF.me then return CF.My(), "selbst" end
    local e = ns.db.country and ns.db.country[full]
    if e then
        if e.s then return e.s, "CBAS" end
        if e.e then return e.e, "eigene Angabe" end
        if e.v then
            local best, bv, second = nil, 0, 0
            for c, v in pairs(e.v) do
                if v > bv then second = bv; best, bv = c, v elseif v > second then second = v end
            end
            if best and bv >= 2 and bv > second * 2 and LANG2C[best] then return LANG2C[best], "Sprache" end
        end
    end
    local key = ns.db.players and ns.db.players[full]
    local g = key and ns.db.guilds[key]
    if g then
        local only
        for c in pairs(g.countries or {}) do
            if only then only = false break end
            only = c
        end
        if only and VALID[only] then return only, "Gilde" end
        local l = g.langTag or g.lang
        if l and LANG2C[l] then return LANG2C[l], "Gilde" end
    end
end

---------------------------------------------------------------------------
-- Daten sammeln (leichtgewichtig: hoechstens eine Auswertung je Spieler und 10 Sek.)
---------------------------------------------------------------------------
local lastSeen, seenN = {}, 0
local function Learn(text, author)
    text, author = S(text), S(author)
    if type(text) ~= "string" or type(author) ~= "string" or #text < 12 then return end
    local full = ns.NormFull(author)
    local now = GetTime()
    if lastSeen[full] and now - lastSeen[full] < 10 then return end
    lastSeen[full] = now
    seenN = seenN + 1
    if seenN > 400 then seenN = 0; wipe(lastSeen) end
    local low = text:lower()
    local db = DB()
    local e = db[full]
    for _, s in ipairs(SAYS) do
        if low:find(s[1], 1, true) then
            e = e or {}
            e.e, e.t = s[2], time()
            db[full] = e
            CF.Forget(full)
            return
        end
    end
    local lang = ns.DetectLanguage and ns.DetectLanguage(text)
    if lang then
        e = e or {}
        e.v = e.v or {}
        e.v[lang] = math.min(20, (e.v[lang] or 0) + 1)
        e.t = time()
        db[full] = e
        CF.Forget(full)
    end
end

function CF.OnAddon(msg, sender)
    local c = type(msg) == "string" and msg:match("^C:(%u%u)$")
    if not c or not VALID[c] or type(sender) ~= "string" then return end
    local full = ns.NormFull(sender)
    local db = DB()
    local e = db[full] or {}
    e.s, e.t = c, time()
    db[full] = e
    CF.Forget(full)
end

-- Haushalt: Eintraege aelter als 60 Tage weg, hoechstens 4000
function CF.Cleanup()
    local db = DB()
    local limit, n = time() - 60 * 86400, 0
    for k, e in pairs(db) do
        if (e.t or 0) < limit then db[k] = nil else n = n + 1 end
    end
    if n > 4000 then
        local arr = {}
        for k, e in pairs(db) do arr[#arr + 1] = { k = k, t = e.t or 0 } end
        table.sort(arr, function(a, b) return a.t > b.t end)
        for i = 4001, #arr do db[arr[i].k] = nil end
    end
end

---------------------------------------------------------------------------
-- Anzeige: Flagge vor den Spielerlink setzen
---------------------------------------------------------------------------
local cache, cacheT = {}, 0
function CF.Forget(full) cache[full] = nil end

local function FlagFor(name)
    local now = GetTime()
    if now - cacheT > 60 then wipe(cache); cacheT = now end
    local full = ns.NormFull(name)
    local v = cache[full]
    if v == nil then
        local c = CF.CountryOf(full)
        v = c and (CF.Icon(c) .. " ") or false
        cache[full] = v
    end
    return v
end

local function Decorate(text)
    if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return text end
    local s = text:find("|Hplayer:", 1, true)
    if not s then return text end
    local name = text:match("|Hplayer:([^:|]+)", s)
    if not name then return text end
    local flag = FlagFor(name)
    if not flag then return text end
    return text:sub(1, s - 1) .. flag .. text:sub(s)
end
CF.Decorate = Decorate

local hooked = {}
local function HookFrame(cf)
    if not cf or hooked[cf] or not cf.AddMessage then return end
    hooked[cf] = true
    local orig = cf.AddMessage
    cf.AddMessage = function(self, text, ...)
        if Enabled() then
            local ok, t = pcall(Decorate, text)
            if ok then text = t end
        end
        return orig(self, text, ...)
    end
end

local function HookAll()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do HookFrame(_G["ChatFrame" .. i]) end
    for _, n in ipairs(CHAT_FRAMES or {}) do HookFrame(_G[n]) end
end

---------------------------------------------------------------------------
-- Einstellungen (rechte Spalte unter "Version")
---------------------------------------------------------------------------
function CF.BuildSettings(p)
    local box = CreateFrame("Frame", nil, p, "BackdropTemplate")
    box:SetSize(330, 92)
    if p.versionBox then box:SetPoint("TOPRIGHT", p.versionBox, "BOTTOMRIGHT", 0, -8) else box:SetPoint("TOPRIGHT", -22, -164) end
    if box.SetBackdrop then
        box:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        box:SetBackdropColor(0, 0, 0, 0.45)
    end
    local h = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetPoint("TOPLEFT", 10, -8)
    h:SetText("Chat")
    local cb = CreateFrame("CheckButton", nil, box, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", 8, -24)
    local cbt = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cbt:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    cbt:SetText("Länderflaggen vor Spielernamen")
    cb:SetScript("OnClick", function(c) ns.db.settings.chatFlags = c:GetChecked() and true or false end)
    box.cb = cb
    local ml = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ml:SetPoint("TOPLEFT", 12, -56)
    ml:SetText("Mein Land:")
    local prev = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    prev:SetSize(22, 20)
    prev:SetPoint("LEFT", ml, "RIGHT", 8, 0)
    prev:SetText("<")
    local cur = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cur:SetPoint("LEFT", prev, "RIGHT", 8, 0)
    cur:SetWidth(150)
    cur:SetJustifyH("LEFT")
    local nxt = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    nxt:SetSize(22, 20)
    nxt:SetPoint("LEFT", prev, "RIGHT", 166, 0)
    nxt:SetText(">")
    local function Step(d)
        local c = CF.My()
        local idx = 0
        for i, x in ipairs(CF.CODES) do if x == c then idx = i end end
        idx = (idx + d - 1) % #CF.CODES + 1
        ns.db.settings.myCountry = CF.CODES[idx]
        wipe(cache)
        if ns.Version then pcall(ns.Version.SendCountry, true) end
        CF.UpdateSettings()
    end
    prev:SetScript("OnClick", function() Step(-1) end)
    nxt:SetScript("OnClick", function() Step(1) end)
    box.cur = cur
    local tip = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tip:SetPoint("BOTTOMLEFT", 10, 8)
    tip:SetText("Andere CBAS-Spieler sehen diese Flagge bei dir.")
    CF.box = box
    CF.UpdateSettings()
end

function CF.UpdateSettings()
    local box = CF.box
    if not box then return end
    box.cb:SetChecked(Enabled())
    local c = CF.My()
    box.cur:SetText(c and (CF.Icon(c, 14) .. " " .. (CF.NAMES[c] or c)) or "|cff888888nicht gesetzt|r")
end

function CF.Slash(arg)
    local c = (arg or ""):upper():match("^(%u%u)$")
    if c and VALID[c] then
        ns.db.settings.myCountry = c
        wipe(cache)
        if ns.Version then pcall(ns.Version.SendCountry, true) end
        ns.Print("Dein Land: " .. CF.Icon(c, 14) .. " " .. CF.NAMES[c])
    elseif arg == "aus" or arg == "off" then
        ns.db.settings.chatFlags = false
        ns.Print("Länderflaggen im Chat: aus.")
    elseif arg == "an" or arg == "on" then
        ns.db.settings.chatFlags = true
        ns.Print("Länderflaggen im Chat: an.")
    else
        local L = {}
        for _, x in ipairs(CF.CODES) do L[#L + 1] = CF.Icon(x, 12) .. x end
        ns.Print("Benutzung: /crap land DE  ·  /crap land an|aus\n" .. table.concat(L, " "))
    end
    CF.UpdateSettings()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local CHAT = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL" }
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, text, author)
    if event == "PLAYER_LOGIN" then
        for _, e in ipairs(CHAT) do pcall(ev.RegisterEvent, ev, e) end
        HookAll()
        if hooksecurefunc and FCF_OpenTemporaryWindow then hooksecurefunc("FCF_OpenTemporaryWindow", HookAll) end
        C_Timer.After(15, function() pcall(CF.Cleanup) end)
    elseif Enabled() then
        pcall(Learn, text, author)
    end
end)
