-- CBAS - Flipper: Sniper-Modus
-- Prueft deine Ziele (Claude-Tipps, Vorschlaege, Merkliste) reihum im AH, im Takt der AH-Drosselung.
-- Kaufen bleibt immer ein Tastendruck (Blizzard-Vorgabe): bei einem Treffer gibt es Alarm und die
-- Flip-Taste steht sofort auf "Kaufen". Erlaubt das Spiel die Suche ohne Tastendruck nicht, sucht
-- jeder Tastendruck das naechste Ziel (Handbetrieb).
local ADDON, ns = ...
local F = ns.Flip
local A = F.Auto
local S = { on = false, i = 0, list = nil, round = 0, checked = 0, hits = 0 }
F.Snipe = S

BINDING_NAME_CBAS_SNIPE = "Flipper: Sniper an/aus"

local RESULT_TIMEOUT = 4      -- Sekunden ohne Antwort -> naechstes Ziel
local HOLD_TIME = 25          -- so lange wartet der Sniper bei einem Treffer auf deinen Tastendruck
local MIN_GAP = 0.6           -- kleinster Abstand zwischen zwei Suchen

local function AHOpen() return AuctionHouseFrame and AuctionHouseFrame:IsShown() end

local function Ready()
    if C_AuctionHouse.IsThrottledMessageSystemReady then
        local ok, r = pcall(C_AuctionHouse.IsThrottledMessageSystemReady)
        if ok and r == false then return false end
    end
    return true
end

-- Ziele nach moeglichem Gewinn: Claude-Tipps (Gewinn x Menge), dann der Rest der Warteschlange
local function BuildList()
    if S.round > 0 then wipe(A.done) end      -- neue Runde: auch schon gekaufte Ziele wieder pruefen
    local q = A.BuildQueue()
    local c, fresh = F.Claude()
    local val = {}
    for i, id in ipairs(q) do
        local t = fresh and c.items and c.items[id]
        val[id] = t and (t.profit or 0) * (t.maxQty or 1) * (t.conf or 0.5) or (1e-3 * (#q - i))
    end
    local l = {}
    for _, id in ipairs(q) do l[#l + 1] = id end
    table.sort(l, function(a, b) return val[a] > val[b] end)
    S.list, S.i = l, 0
    S.round = S.round + 1
end

local function Busy()
    local st = A.state
    if st == "starting" or st == "confirm" or st == "buying" then return true end
    -- Treffer wartet auf Tastendruck
    if S.hitId and S.hitAt and GetTime() - S.hitAt < HOLD_TIME then
        local cur = F.cur
        if cur and cur.id == S.hitId and cur.r and cur.r.qty > 0 and not A.done[S.hitId] then
            if cur.commodity then return true end
            for _, l in ipairs(cur.list or {}) do
                if not l.bought and l.auctionID and l.unit <= cur.r.maxUnit and (A.boughtQty or 0) + l.qty <= cur.r.qty then return true end
            end
        end
    end
    S.hitId = nil
    return false
end

local function SearchId(id)
    local key = C_AuctionHouse.MakeItemKey and C_AuctionHouse.MakeItemKey(id)
    if not key then return false end
    local sorts = { { sortOrder = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0, reverseSort = false } }
    S.waitId, S.sentAt, S.lastSend = id, GetTime(), GetTime()
    return pcall(C_AuctionHouse.SendSearchQuery, key, sorts, true)
end

function S.Status()
    if not S.on then return nil end
    if S.manual then
        return "|cffffd100Sniper (Handbetrieb):|r jeder Tastendruck prüft das nächste Ziel."
    end
    local n = S.list and #S.list or 0
    if S.hitId then return "|cff40ff40SNIPER-TREFFER - jetzt Taste drücken!|r" end
    return string.format("|cff66ccffSniper läuft:|r %d/%d · Runde %d · %d geprüft · %d Treffer", S.i, n, S.round, S.checked, S.hits)
end

local function Refresh()
    if F.ShowStepOnly and not S.hitId then F.ShowStepOnly() end
    if S.btn then S.btn:SetText(S.on and "Sniper: AN" or "Sniper: aus") end
end

local function Tick()
    if not S.on then return end
    if not AHOpen() then return end
    if S.manual then return end
    if Busy() then return end
    local now = GetTime()
    if S.waitId and now - (S.sentAt or 0) < RESULT_TIMEOUT then return end   -- Antwort abwarten
    S.waitId = nil
    if S.lastSend and now - S.lastSend < MIN_GAP then return end
    if not Ready() then return end
    if not S.list or S.i >= #S.list then BuildList() end
    if #S.list == 0 then
        S.on = false
        ns.Print("Sniper: keine Ziele. Erst scannen/analysieren oder Claude-Tipps holen.")
        Refresh()
        return
    end
    -- naechstes noch offenes Ziel
    local id
    repeat
        S.i = S.i + 1
        id = S.list[S.i]
    until not id or not A.done[id]
    if not id then return end
    if not SearchId(id) then S.waitId = nil end
end

-- wird von den Suchergebnissen aufgerufen. true = Sniper hat das Ergebnis verbraucht (kein Treffer)
function S.OnResults(id, r)
    if not S.on then return false end
    local mine = (id == S.waitId)
    if mine then S.waitId = nil; S.checked = S.checked + 1 end
    if r and r.qty > 0 then
        if id ~= S.hitId then
            S.hits = S.hits + 1
            S.hitId, S.hitAt = id, GetTime()
            A.stepId, A.state, A.bought, A.boughtQty, A.pending = id, "searching", 0, 0, nil
            if PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master") end
            if FlashClientIcon then pcall(FlashClientIcon) end
            local info = F.ItemInfo(id)
            ns.Print(string.format("|cff40ff40Sniper-Treffer:|r %s - %d Stück bis je %s (Gewinn ca. %s). Taste drücken!",
                info and info.link or ("Gegenstand " .. id), r.qty, F.Money(r.maxUnit, true), F.Money(r.gain, true)))
        end
        return false      -- Kaufhilfe normal anzeigen
    end
    if mine then
        Refresh()
        return true
    end
    return false
end

function S.Toggle(on)
    if on == nil then on = not S.on end
    S.on = on and true or false
    if S.on then
        if not AHOpen() then ns.Print("Sniper: startet, sobald du das Auktionshaus öffnest.") end
        S.list, S.round, S.checked, S.hits, S.hitId, S.waitId = nil, 0, 0, 0, nil, nil
        if not S.ticker then S.ticker = C_Timer.NewTicker(0.25, function() pcall(Tick) end) end
        ns.Print("Sniper |cff40ff40an|r - prüft deine Ziele reihum. Bei einem Treffer: Alarm + Flip-Taste drücken.")
    else
        if S.ticker then S.ticker:Cancel(); S.ticker = nil end
        S.waitId, S.hitId = nil, nil
        ns.Print("Sniper |cffff4040aus|r.")
    end
    Refresh()
end

-- Knopf im AH-Fenster der Kaufhilfe
function S.AttachButton(o)
    if S.btn or not o then return end
    local b = CreateFrame("Button", nil, o, "UIPanelButtonTemplate")
    b:SetSize(90, 20)
    b:SetPoint("TOPRIGHT", -6, -6)
    b:SetScript("OnClick", function() S.Toggle() end)
    S.btn = b
    Refresh()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "PLAYER_LOGIN" then
        for _, e in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" }) do
            pcall(ev.RegisterEvent, ev, e)
        end
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if a1 == ADDON and type(a2) == "string" and a2:find("SendSearchQuery") and S.on and not S.manual then
            S.manual = true
            S.waitId = nil
            ns.Print("Sniper: das Spiel erlaubt die Suche nur per Tastendruck. Weiter im Handbetrieb - jeder Druck auf die Flip-Taste prüft das nächste Ziel (Reihenfolge nach Gewinn).")
            Refresh()
        end
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        if S.on then pcall(Tick) end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        S.waitId, S.hitId = nil, nil
    end
end)
