-- CBAS - Mage-Dienste: Portale, Wasser & Essen verkaufen
-- Kunden werden im Chat erkannt (Handel, Allgemein, Sagen, Schreien, Fluestern, Gilde).
-- Die Autopilot-Taste macht bei jedem Druck den naechsten sinnvollen Schritt:
--   Kunde anschreiben -> einladen -> Handel oeffnen -> Ware hineinlegen -> annehmen (wenn bezahlt)
--   -> Portal oeffnen -> Gruppe verlassen. Ohne Kunden: Vorrat herbeizaubern, Werbung vorbereiten.
-- Blizzard-Regeln: Zauber, Handel und Einladen nur per Tastendruck; Chat-Texte landen nur in der
-- Eingabezeile (Enter drueckst du selbst). Nichts laeuft ohne Tastendruck.
-- Leichtgewichtig: Chat wird nur auf Magiern ausgewertet, hoechstens 20 Kunden, 5 Min. Verfall,
-- Vorrat 2 s zwischengespeichert.
local ADDON, ns = ...
local S = ns.S
local MG = {}
ns.Mage = MG

---------------------------------------------------------------------------
-- Zauber und Gegenstaende (Classic-IDs)
---------------------------------------------------------------------------
MG.RUNE = 17032   -- Rune der Portale
MG.PORTALS = {
    { key = "org",  spell = 11417, faction = "Horde",    de = "Orgrimmar",     en = "Orgrimmar",
      words = { "orgrimmar", "orgri", "%f[%w]org%f[%W]", "%f[%w]og%f[%W]" } },
    { key = "uc",   spell = 11418, faction = "Horde",    de = "Unterstadt",    en = "Undercity",
      words = { "undercity", "unterstadt", "%f[%w]uc%f[%W]", "%f[%w]us%f[%W]" } },
    { key = "tb",   spell = 11420, faction = "Horde",    de = "Donnerfels",    en = "Thunder Bluff",
      words = { "thunder ?bluff", "donnerfels", "%f[%w]tb%f[%W]", "%f[%w]df%f[%W]" } },
    { key = "sw",   spell = 10059, faction = "Alliance", de = "Sturmwind",     en = "Stormwind",
      words = { "stormwind", "sturmwind", "%f[%w]sw%f[%W]" } },
    { key = "if",   spell = 11416, faction = "Alliance", de = "Eisenschmiede", en = "Ironforge",
      words = { "ironforge", "eisenschmiede", "%f[%w]if%f[%W]", "%f[%w]ef%f[%W]" } },
    { key = "darn", spell = 11419, faction = "Alliance", de = "Darnassus",     en = "Darnassus",
      words = { "darnassus", "darna", "%f[%w]darn%f[%W]" } },
}
-- Rang 1..7: Zauber -> herbeigezauberter Gegenstand
MG.WATER = { { 5504, 5350 }, { 5505, 2288 }, { 5506, 2136 }, { 6127, 3772 }, { 10138, 8077 }, { 10139, 8078 }, { 10140, 8079 } }
MG.FOOD  = { { 587, 5349 }, { 597, 1113 }, { 990, 1114 }, { 6129, 1487 }, { 10144, 8075 }, { 10145, 8076 }, { 28612, 22895 } }
MG.STACK = 20

local DEFAULTS = {
    listen = true,          -- Chat nach Kunden durchsuchen
    portalPrice = 10000,    -- Kupfer (1 Gold)
    waterPrice = 5000,      -- je Stack (50 Silber)
    foodPrice = 5000,
    stacks = 2,             -- Stacks je Verkauf
    keepWater = 6,          -- Vorrat in Stacks, den der Autopilot herbeizaubert
    keepFood = 2,
    payFirst = true,        -- Portal erst nach Bezahlung
    adEvery = 90,           -- Sekunden zwischen zwei Werbungen
    lang = "de",
}

function MG.db()
    local s = ns.db.settings
    s.mage = s.mage or {}
    local m = s.mage
    for k, v in pairs(DEFAULTS) do if m[k] == nil then m[k] = v end end
    m.log = m.log or {}
    return m
end

function MG.IsMage()
    if not UnitClass then return false end
    local _, cls = UnitClass("player")
    return S(cls) == "MAGE"
end

local function Known(id)
    if not id then return false end
    if IsPlayerSpell then local ok, r = pcall(IsPlayerSpell, id) if ok and r then return true end end
    if IsSpellKnown then local ok, r = pcall(IsSpellKnown, id) if ok and r then return true end end
    return false
end
MG.Known = Known

local function ItemCount(id)
    local f = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not f then return 0 end
    local ok, n = pcall(f, id)
    return ok and tonumber(n) or 0
end
MG.ItemCount = ItemCount

-- hoechster bekannter Rang: Zauber-ID, Gegenstand-ID, Rang
local function Best(list)
    for i = #list, 1, -1 do
        if Known(list[i][1]) then return list[i][1], list[i][2], i end
    end
end

local stockCache = { t = -100 }
-- Vorrat: Wasser/Essen (Stuecke, auch niedrigere Raenge zaehlen), Runen, bekannte Portale
function MG.Stock()
    if GetTime() - stockCache.t < 2 then return stockCache end
    local s = { t = GetTime(), water = 0, food = 0 }
    s.waterSpell, s.waterItem, s.waterRank = Best(MG.WATER)
    s.foodSpell, s.foodItem, s.foodRank = Best(MG.FOOD)
    for _, w in ipairs(MG.WATER) do s.water = s.water + ItemCount(w[2]) end
    for _, f in ipairs(MG.FOOD) do s.food = s.food + ItemCount(f[2]) end
    s.runes = ItemCount(MG.RUNE)
    s.portals = {}
    for _, p in ipairs(MG.PORTALS) do if Known(p.spell) then s.portals[#s.portals + 1] = p end end
    stockCache = s
    return s
end
function MG.Dirty() stockCache.t = -100 end

function MG.PortalByKey(key)
    for _, p in ipairs(MG.PORTALS) do if p.key == key then return p end end
end

function MG.Money(c)
    c = tonumber(c) or 0
    local g, s = math.floor(c / 10000), math.floor((c % 10000) / 100)
    if g > 0 and s > 0 then return g .. "g " .. s .. "s" end
    if g > 0 then return g .. "g" end
    return s .. "s"
end

---------------------------------------------------------------------------
-- Kunden erkennen
---------------------------------------------------------------------------
local BUY = { "wtb", "%f[%w]lf%f[%W]", "%f[%w]lfm?%f[%W]", "need", "suche", "brauch", "any ?mage", "anyone", "jemand",
    "magier", "%f[%w]mage", "kaufe", "pls", "plz", "bitte", "%?" }
local SELL = { "wts", "verkauf", "selling", "%f[%w]vk%f[%W]", "biete", "port service", "portal service" }
local PORT = { "%f[%w]port%f[%W]", "%f[%w]ports%f[%W]", "portal", "porta%f[%W]", "%f[%w]tele" }
local WATER = { "water", "wasser", "%f[%w]drink", "trinken", "getr[aä]nk" }
local FOOD = { "%f[%w]food", "essen", "%f[%w]brot", "bread", "%f[%w]muffin" }

local function Any(s, list)
    for _, p in ipairs(list) do if s:find(p) then return true end end
    return false
end

-- Text -> { kind = "port"|"water"|"food", dest = key } oder nil
function MG.Parse(text, whisper)
    if type(text) ~= "string" then return nil end
    local s = text:lower()
    if Any(s, SELL) then return nil end
    if not whisper and not Any(s, BUY) then return nil end
    if Any(s, PORT) then
        local dest
        for _, p in ipairs(MG.PORTALS) do
            for _, w in ipairs(p.words) do if s:find(w) then dest = p.key break end end
            if dest then break end
        end
        return { kind = "port", dest = dest }
    end
    if Any(s, WATER) then return { kind = "water", food = Any(s, FOOD) } end
    if Any(s, FOOD) then return { kind = "food" } end
    return nil
end

MG.customers = {}   -- aelteste zuerst
MG.MAX, MG.TTL = 20, 300

function MG.Find(full)
    for _, c in ipairs(MG.customers) do if c.full == full then return c end end
end

function MG.Prune()
    local now = time()
    for i = #MG.customers, 1, -1 do
        local c = MG.customers[i]
        local active = c.state ~= "new" and c.state ~= "done"
        if c.state == "done" or (not active and now - c.t > MG.TTL) or (active and now - c.t > 1800) then
            table.remove(MG.customers, i)
            if MG.sel == c then MG.sel = nil end
        end
    end
    while #MG.customers > MG.MAX do table.remove(MG.customers, 1) end
end

function MG.Add(raw, text, src, req, silent)
    local full = ns.NormFull(raw)
    if not full or full == "" then return end
    local c = MG.Find(full)
    if c then
        -- neue Nachricht frischt auf; ein Ziel wird nachgetragen
        c.t, c.msg = time(), text
        if req.dest and not c.dest then c.dest = req.dest end
        if req.kind == "port" then c.kind = "port" end
    else
        c = { full = full, raw = raw, kind = req.kind, dest = req.dest, food = req.food, msg = text, src = src,
              t = time(), state = "new" }
        table.insert(MG.customers, c)
    end
    MG.Prune()
    if not silent then MG.Changed() end
    return c
end

local function Me(raw)
    local me = UnitName("player")
    return raw and me and (raw == me or ns.NormFull(raw) == ns.NormFull(ns.FullName(me, select(2, UnitFullName("player")))))
end

local SRC = { CHAT_MSG_WHISPER = "Flüstern", CHAT_MSG_SAY = "Sagen", CHAT_MSG_YELL = "Schreien",
    CHAT_MSG_GUILD = "Gilde", CHAT_MSG_PARTY = "Gruppe", CHAT_MSG_PARTY_LEADER = "Gruppe" }

function MG.OnChat(event, text, sender, _, chName)
    if not MG.IsMage() or not MG.db().listen then return end
    text, sender = S(text), S(sender)
    if type(text) ~= "string" or type(sender) ~= "string" or Me(sender) then return end
    local req = MG.Parse(text, event == "CHAT_MSG_WHISPER")
    if not req then return end
    local src = SRC[event] or (S(chName) and tostring(S(chName)):gsub("^%d+%.%s*", "")) or "Chat"
    local c = MG.Add(sender, text, src, req)
    if c and not c.alerted and PlaySound and SOUNDKIT and SOUNDKIT.TELL_MESSAGE then
        c.alerted = true
        pcall(PlaySound, SOUNDKIT.TELL_MESSAGE)
    end
end

-- gewaehlter Kunde, sonst der aelteste offene
function MG.Current()
    MG.Prune()
    if MG.sel and MG.Find(MG.sel.full) then return MG.sel end
    for _, c in ipairs(MG.customers) do if c.state ~= "new" then return c end end
    return MG.customers[1]
end

function MG.Select(c) MG.sel = c; MG.Changed() end
function MG.Remove(c)
    for i, x in ipairs(MG.customers) do if x == c then table.remove(MG.customers, i) break end end
    if MG.sel == c then MG.sel = nil end
    MG.Changed()
end

---------------------------------------------------------------------------
-- Texte
---------------------------------------------------------------------------
local TXT = {
    de = {
        port = "Hi! Portal nach %s für %s – ich lade dich ein. Danach kurz handeln, dann öffne ich das Portal.",
        portAny = "Hi! Ich biete Portale an (%s) für %s – wohin soll's gehen? Ich lade dich ein.",
        water = "Hi! %d Stack(s) %s für %s – ich lade dich ein, dann einfach handeln.",
        food = "Hi! %d Stack(s) Essen für %s – ich lade dich ein, dann einfach handeln.",
        ad = "Magier-Service: Portale nach %s (%s) · Wasser & Essen (%s/Stack) – einfach anflüstern!",
        adWater = "Magier-Service: Wasser & Essen (%s/Stack) – einfach anflüstern!",
        waterWord = "Wasser",
    },
    en = {
        port = "Hi! Portal to %s for %s – inviting you now. Open a trade, then I'll open the portal.",
        portAny = "Hi! I sell portals (%s) for %s – where do you want to go? Inviting you.",
        water = "Hi! %d stack(s) of %s for %s – inviting you, then just open a trade.",
        food = "Hi! %d stack(s) of food for %s – inviting you, then just open a trade.",
        ad = "Mage service: portals to %s (%s) · water & food (%s/stack) – just whisper me!",
        adWater = "Mage service: water & food (%s/stack) – just whisper me!",
        waterWord = "water",
    },
}

local function L() local m = MG.db() return TXT[m.lang] or TXT.de end

local function PortalNames(list, lang)
    local t = {}
    for _, p in ipairs(list) do t[#t + 1] = lang == "en" and p.en or p.de end
    return table.concat(t, ", ")
end

function MG.Price(c)
    local m = MG.db()
    if not c then return 0 end
    if c.kind == "port" then return m.portalPrice end
    if c.kind == "food" then return m.foodPrice * m.stacks end
    return m.waterPrice * m.stacks + (c.food and m.foodPrice * m.stacks or 0)
end

function MG.WhisperText(c)
    local m, t = MG.db(), L()
    if c.kind == "port" then
        local p = c.dest and MG.PortalByKey(c.dest)
        if p then return t.port:format(m.lang == "en" and p.en or p.de, MG.Money(m.portalPrice)) end
        return t.portAny:format(PortalNames(MG.Stock().portals, m.lang), MG.Money(m.portalPrice))
    elseif c.kind == "food" then
        return t.food:format(m.stacks, MG.Money(MG.Price(c)))
    end
    return t.water:format(m.stacks, c.food and (t.waterWord .. " + " .. (m.lang == "en" and "food" or "Essen")) or t.waterWord,
        MG.Money(MG.Price(c)))
end

function MG.AdText()
    local m, t = MG.db(), L()
    local st = MG.Stock()
    if #st.portals > 0 then
        return t.ad:format(PortalNames(st.portals, m.lang), MG.Money(m.portalPrice), MG.Money(m.waterPrice))
    end
    return t.adWater:format(MG.Money(m.waterPrice))
end

-- Handelskanal suchen ("Handel - Stadt" / "Trade - City"), sonst /sagen
function MG.AdChannel()
    if GetChannelList then
        local list = { GetChannelList() }
        for i = 1, #list, 3 do
            local id, name = list[i], S(list[i + 1])
            if type(name) == "string" and (name:find("^Handel") or name:find("^Trade")) then return "/" .. id .. " " end
        end
    end
    return "/s "
end

---------------------------------------------------------------------------
-- Gruppe und Handel
---------------------------------------------------------------------------
-- Einheit eines Kunden in der Gruppe (party1..4 / raidN)
function MG.UnitOf(c)
    if not c then return nil end
    local n = (IsInRaid and IsInRaid()) and 40 or 4
    for i = 1, n do
        local u = ((IsInRaid and IsInRaid()) and "raid" or "party") .. i
        if UnitExists(u) then
            local nm, rl = UnitName(u)
            nm, rl = S(nm), S(rl)
            if nm and ns.NormFull(ns.FullName(nm, rl)) == c.full then return u end
        end
    end
end

function MG.TradeOpen() return TradeFrame and TradeFrame:IsShown() or MG.trading or false end

function MG.TradePartner()
    local nm, rl = UnitName("NPC")
    nm, rl = S(nm), S(rl)
    if not nm then return nil end
    return ns.NormFull(ns.FullName(nm, rl)), nm
end

local function TradeMoney()
    local f = GetTargetTradeMoney
    local ok, v = pcall(f or function() return 0 end)
    return ok and tonumber(v) or 0
end
MG.TradeMoney = TradeMoney

-- Ware fuer den Kunden in freie Handelsplaetze legen (ein Tastendruck)
function MG.FillTrade(c)
    local m, st = MG.db(), MG.Stock()
    local want = {}
    if c.kind == "water" then want[#want + 1] = { MG.WATER, m.stacks } end
    if c.kind == "food" or (c.kind == "water" and c.food) then want[#want + 1] = { MG.FOOD, m.stacks } end
    local CC = C_Container or {}
    local numSlots = CC.GetContainerNumSlots or GetContainerNumSlots
    local itemID = CC.GetContainerItemID or GetContainerItemID
    local pickup = CC.PickupContainerItem or PickupContainerItem
    local slot = 1
    local function NextFree()
        while slot <= 6 do
            local ok, name = pcall(GetTradePlayerItemInfo, slot)
            if not ok or not name then return slot end
            slot = slot + 1
        end
    end
    local placed = 0
    for _, w in ipairs(want) do
        local list, n = w[1], w[2]
        -- bester Rang zuerst
        for r = #list, 1, -1 do
            if n <= 0 then break end
            for bag = 0, 4 do
                if n <= 0 then break end
                for s = 1, (numSlots and numSlots(bag) or 0) do
                    if n <= 0 then break end
                    if itemID(bag, s) == list[r][2] then
                        local free = NextFree()
                        if not free then return placed end
                        pickup(bag, s)
                        ClickTradeButton(free)
                        slot = free + 1
                        placed, n = placed + 1, n - 1
                    end
                end
            end
        end
    end
    c.filled = true
    MG.Dirty()
    return placed
end

function MG.Log(c, money)
    local m = MG.db()
    table.insert(m.log, 1, { t = time(), name = c and c.full or "?", kind = c and c.kind or "?", dest = c and c.dest, money = money or 0 })
    while #m.log > 200 do table.remove(m.log) end
end

-- Einnahmen heute (und Anzahl Verkaeufe)
function MG.Today()
    local m = MG.db()
    local day = date("%Y-%m-%d")
    local g, n = 0, 0
    for _, e in ipairs(m.log) do
        if date("%Y-%m-%d", e.t) == day then g, n = g + (e.money or 0), n + 1 else break end
    end
    return g, n
end

---------------------------------------------------------------------------
-- Der naechste Schritt: { text, hint, act = function | cast = spellID | nil (warten), state }
---------------------------------------------------------------------------
local function Name(c) return c.full end

function MG.Next()
    local m = MG.db()
    if not MG.IsMage() then return { text = "Nur für Magier", hint = "Logge einen Magier ein." } end
    if InCombatLockdown and InCombatLockdown() then return { text = "Im Kampf – Pause", hint = "Nach dem Kampf geht es weiter." } end
    local st = MG.Stock()

    -- 1) offener Handel hat Vorrang
    if MG.TradeOpen() then
        local full = MG.TradePartner()
        local c = full and MG.Find(full)
        if not c and full then
            c = MG.Add(full, "(Handel geöffnet)", "Handel", { kind = "water" }, true)
        end
        if c then
            MG.sel = c
            c.state = c.state == "new" and "group" or c.state
            local price = MG.Price(c)
            if c.kind ~= "port" and not c.filled then
                return { text = "Ware in den Handel legen", hint = m.stacks .. " Stack(s) für " .. Name(c),
                    act = function() MG.FillTrade(c) end }
            end
            local got = TradeMoney()
            if got >= price then
                return { text = "Handel annehmen" .. (got > 0 and (" (+" .. MG.Money(got) .. ")") or ""),
                    hint = "Bezahlt: " .. MG.Money(got) .. " von " .. MG.Money(price),
                    act = function() c.tradeMoney = got; AcceptTrade() end }
            end
            return { text = "Warte auf Gold (" .. MG.Money(got) .. " / " .. MG.Money(price) .. ")",
                hint = Name(c) .. " legt das Gold in den Handel." }
        end
    end

    local c = MG.Current()
    if c then
        local unit = MG.UnitOf(c)
        if unit and (c.state == "told" or c.state == "invited") then c.state = "group" end
        if c.state == "new" then
            return { text = "Anschreiben: " .. Name(c), hint = "Text landet in der Chat-Eingabe – Enter drückst du.",
                act = function() MG.Whisper(c) end }
        elseif c.state == "told" then
            return { text = "Einladen: " .. Name(c), hint = "Lädt " .. Name(c) .. " in deine Gruppe ein.",
                act = function() MG.Invite(c) end }
        elseif c.state == "invited" then
            if time() - (c.invited or 0) > 60 then
                return { text = "Nochmal einladen: " .. Name(c), hint = "Keine Antwort seit 1 Minute.", act = function() MG.Invite(c) end }
            end
            return { text = "Warte, bis " .. Name(c) .. " beitritt", hint = "Einladung ist raus." }
        elseif c.state == "group" then
            if c.kind == "port" then
                local p = c.dest and MG.PortalByKey(c.dest)
                if not p then
                    return { text = "Ziel unklar – " .. Name(c) .. " fragen", hint = "Klick auf ein Ziel unten im Kunden-Eintrag oder Text in die Eingabe.",
                        act = function() MG.Whisper(c) end }
                end
                if not Known(p.spell) then return { text = "Portal nach " .. p.de .. " nicht gelernt", hint = "Kunde entfernen oder anderes Ziel wählen." } end
                if st.runes < 1 then return { text = "Keine Rune der Portale!", hint = "Beim Reagenzienhändler kaufen." } end
                if m.payFirst and not c.paid and m.portalPrice > 0 then
                    return { text = "Handel öffnen mit " .. Name(c), hint = "Erst bezahlen, dann Portal (Einstellung).",
                        act = function() if unit then InitiateTrade(unit) end end }
                end
                return { text = "Portal nach " .. p.de .. " öffnen", hint = "Danach betritt " .. Name(c) .. " das Portal.",
                    cast = p.spell, after = function() c.casting = true end }
            end
            if c.paid then
                return { text = "Fertig – Gruppe verlassen", hint = "Verkauf erledigt.", act = function() MG.Finish(c) end }
            end
            return { text = "Handel öffnen mit " .. Name(c), hint = "Dann Ware hineinlegen und annehmen.",
                act = function() if unit then InitiateTrade(unit) end end }
        elseif c.state == "ported" then
            if m.payFirst or c.paid or m.portalPrice == 0 then
                return { text = "Fertig – Gruppe verlassen", hint = "Erst drücken, wenn " .. Name(c) .. " durch das Portal ist!",
                    act = function() MG.Finish(c) end }
            end
            return { text = "Handel öffnen mit " .. Name(c), hint = "Portal steht – jetzt bezahlen lassen.",
                act = function() if unit then InitiateTrade(unit) end end }
        end
    end

    -- 2) kein Kunde: Vorrat auffuellen, dann Werbung
    if st.waterSpell and st.water < m.keepWater * MG.STACK then
        return { text = "Wasser herbeizaubern (" .. math.floor(st.water / MG.STACK) .. "/" .. m.keepWater .. " Stacks)",
            hint = "Vorrat für die nächsten Kunden.", cast = st.waterSpell }
    end
    if st.foodSpell and st.food < m.keepFood * MG.STACK then
        return { text = "Essen herbeizaubern (" .. math.floor(st.food / MG.STACK) .. "/" .. m.keepFood .. " Stacks)",
            hint = "Vorrat für die nächsten Kunden.", cast = st.foodSpell }
    end
    local wait = (MG.lastAd or -1000) + m.adEvery - GetTime()
    if wait <= 0 then
        return { text = "Werbung vorbereiten", hint = "Text landet in der Chat-Eingabe (Handelskanal) – Enter drückst du.",
            act = function() MG.Advertise() end }
    end
    return { text = "Warte auf Kunden ...", hint = string.format("Nächste Werbung in %d s. Kunden erscheinen hier automatisch.", math.ceil(wait)) }
end

---------------------------------------------------------------------------
-- Aktionen
---------------------------------------------------------------------------
local function OpenChat(prefix, text)
    if ChatFrame_OpenChat then ChatFrame_OpenChat(prefix .. text) end
end

function MG.Whisper(c)
    local txt = MG.WhisperText(c)
    if ChatFrame_SendTell then
        ChatFrame_SendTell(c.raw or c.full)
        local eb = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
        if eb then eb:Insert(txt) end
    else
        OpenChat("/w " .. (c.raw or c.full) .. " ", txt)
    end
    if c.state == "new" then c.state = "told" end
    MG.Changed()
end

function MG.Invite(c)
    local f = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    if f then pcall(f, c.raw or c.full) end
    c.state, c.invited = "invited", time()
    MG.Changed()
end

function MG.Advertise()
    OpenChat(MG.AdChannel(), MG.AdText())
    MG.lastAd = GetTime()
    MG.Changed()
end

function MG.Finish(c)
    if MG.UnitOf(c) and not (IsInRaid and IsInRaid()) then
        local f = (C_PartyInfo and C_PartyInfo.LeaveParty) or LeaveParty
        if f then pcall(f) end
    end
    if not c.logged then c.logged = true; MG.Log(c, c.tradeMoney or 0) end
    c.state = "done"
    MG.Prune()
    MG.Changed()
end

-- Insecure Schritt ausfuehren (fuer Zauber gibt es die sichere Taste)
function MG.Step()
    local st = MG.Next()
    if st.act then
        local ok, err = pcall(st.act)
        if not ok then ns.Print("Mage-Dienste: " .. tostring(err)) end
    end
    MG.Changed()
    return st
end

---------------------------------------------------------------------------
-- Sichere Taste: macht bei Zauber-Schritten den Zauber, sonst den normalen Schritt
-- Belegbar unter Tastenbelegung > AddOns > CBAS ("Mage-Dienste: nächster Schritt").
---------------------------------------------------------------------------
_G["BINDING_NAME_CLICK CBASMageButton:LeftButton"] = "Mage-Dienste: nächster Schritt (Autopilot)"

function MG.CreateButton()
    if MG.button then return MG.button end
    local b = CreateFrame("Button", "CBASMageButton", UIParent, "SecureActionButtonTemplate")
    b:SetSize(1, 1)
    b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -50, 50)   -- unsichtbar, nur fuer die Taste
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", nil)
    local last = -10
    b:SetScript("PreClick", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        -- je nach Einstellung kommt der Klick beim Druecken UND Loslassen: nur einmal handeln
        if GetTime() - last < 0.25 then self:SetAttribute("type", nil) return end
        last = GetTime()
        local st = MG.Next()
        MG.pending = st
        if st.cast then
            self:SetAttribute("type", "spell")
            self:SetAttribute("spell", st.cast)
        else
            self:SetAttribute("type", nil)
            if st.act then
                local ok, err = pcall(st.act)
                if not ok then ns.Print("Mage-Dienste: " .. tostring(err)) end
            end
        end
    end)
    b:SetScript("PostClick", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        local st = MG.pending
        MG.pending = nil
        if st and st.cast and st.after then pcall(st.after) end
        self:SetAttribute("type", nil)
        MG.Dirty()
        MG.Changed()
    end)
    MG.button = b
    return b
end

---------------------------------------------------------------------------
-- Ereignisse
---------------------------------------------------------------------------
local listeners = {}
function MG.OnChange(fn) listeners[#listeners + 1] = fn end
function MG.Changed()
    for _, fn in ipairs(listeners) do pcall(fn) end
end

local PORTAL_SPELL = {}
for _, p in ipairs(MG.PORTALS) do PORTAL_SPELL[p.spell] = p end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        if not MG.IsMage() then return end
        MG.db()
        pcall(MG.CreateButton)
        for _, e in ipairs({ "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_GUILD",
            "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "GROUP_ROSTER_UPDATE", "TRADE_SHOW", "TRADE_CLOSED",
            "TRADE_MONEY_CHANGED", "TRADE_ACCEPT_UPDATE", "UI_INFO_MESSAGE", "UNIT_SPELLCAST_SUCCEEDED", "BAG_UPDATE_DELAYED" }) do
            pcall(self.RegisterEvent, self, e)
        end
        return
    end
    if event:find("^CHAT_MSG_") then
        local text, sender, _, _, _, _, _, _, chName = ...
        MG.OnChat(event, text, sender, nil, chName)
    elseif event == "TRADE_SHOW" then
        MG.trading = true
        local c = MG.Find((MG.TradePartner()))
        if c then c.filled = nil end
        MG.Changed()
    elseif event == "TRADE_CLOSED" then
        MG.trading = false
        MG.Changed()
    elseif event == "UI_INFO_MESSAGE" then
        local _, msg = ...
        if msg and ERR_TRADE_COMPLETE and msg == ERR_TRADE_COMPLETE then
            local c = MG.sel
            if c then
                c.paid = true
                MG.Log(c, c.tradeMoney or 0)
                c.logged = true
                if c.kind ~= "port" then c.state = "group" end
            end
            MG.Dirty()
            MG.Changed()
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" and PORTAL_SPELL[S(spellID) or 0] then
            local c = MG.Current()
            if c and c.kind == "port" then c.state = "ported" end
            MG.Dirty()
            MG.Changed()
        end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "BAG_UPDATE_DELAYED" or event == "TRADE_MONEY_CHANGED" or event == "TRADE_ACCEPT_UPDATE" then
        MG.Dirty()
        MG.Changed()
    end
end)
