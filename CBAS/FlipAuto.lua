-- CBAS - Flipper: Ein-Tasten-Ablauf im AH und Post abholen
-- Jeder Tastendruck/Klick macht genau EINEN Schritt (Blizzard verlangt fuer Suchen und Kaufen
-- einen echten Tastendruck). Nichts laeuft von allein.
local ADDON, ns = ...
local S = ns.S
local F = ns.Flip

BINDING_HEADER_CBAS = "Craphunts Blacklisted Addon Suite"
BINDING_NAME_CBAS_FLIPSTEP = "Flipper: nächster Schritt (suchen / kaufen / bestätigen)"
BINDING_NAME_CBAS_TOGGLE = "CBAS-Fenster öffnen/schließen"

local A = { queue = nil, pos = 0, done = {}, state = nil }
F.Auto = A

local PRICE_TOLERANCE = 1.02   -- 2 % Spielraum, falls sich das guenstigste Angebot minimal aendert

local function ItemName(id)
    local info = F.ItemInfo(id)
    return (info and info.link) or ("Gegenstand " .. id)
end

local function AHOpen()
    return AuctionHouseFrame and AuctionHouseFrame:IsShown()
end

---------------------------------------------------------------------------
-- Warteschlange: beste Vorschlaege zuerst, dann Merkliste-Schnaeppchen, dann Haendler-Flips
---------------------------------------------------------------------------
function A.BuildQueue()
    local d = F.db()
    local q, seen = {}, {}
    local mode = d.settings.flipMode or "alle"
    local function add(id)
        if id and F.IsJunk(id) then return end
        if id and mode ~= "alle" and (F.IsQuick(id) and "2h" or "lang") ~= mode then return end
        if id and not seen[id] and not A.done[id] then
            seen[id] = true
            q[#q + 1] = id
        end
    end
    -- Claude-Tipps zuerst (nach Rang)
    local c, fresh = F.Claude()
    if c and fresh and type(c.items) == "table" then
        local ct = {}
        for id, t in pairs(c.items) do if t.buyUpTo then ct[#ct + 1] = { id = id, r = t.rank or 999 } end end
        table.sort(ct, function(x, y) return x.r < y.r end)
        for _, x in ipairs(ct) do add(x.id) end
    end
    local sug = {}
    for id, e in pairs(d.suggest or {}) do if not e.odd then sug[#sug + 1] = { id = id, s = e.score or 0 } end end
    table.sort(sug, function(a, b) return a.s > b.s end)
    for _, x in ipairs(sug) do add(x.id) end
    for id, w in pairs(d.watch) do
        local p = F.Prices(w.link or id)
        local af, vf = F.AHFlip(p, w), F.VendorFlip(p)
        if (af and af.deal) or (vf and vf.deal) then add(id) end
    end
    local fl = {}
    for id, e in pairs(d.found or {}) do fl[#fl + 1] = { id = id, p = e.profit or 0 } end
    table.sort(fl, function(a, b) return a.p > b.p end)
    for _, x in ipairs(fl) do add(x.id) end
    A.queue, A.pos = q, 0
    return q
end

function A.Reset()
    A.queue, A.pos, A.state, A.stepId = nil, 0, nil, nil
    wipe(A.done)
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------
local function KeyName()
    local k = GetBindingKey and GetBindingKey("CBAS_FLIPSTEP")
    return k and ("|cffffd100[" .. k .. "]|r") or "|cff888888(Taste: Optionen > Tastenbelegung > AddOns)|r"
end

function F.StepHint()
    local s = A.state
    local cur = F.cur
    if s == "starting" then return "|cffffd100Preis wird geprüft ...|r" end
    if s == "confirm" and A.pending then
        return string.format("|cff40ff40Nächster Druck: %d Stück für %s kaufen|r %s", A.pending.qty, F.Money(A.pending.total, true), KeyName())
    end
    if cur and cur.id == A.stepId and cur.r and cur.r.qty > 0 then
        if cur.commodity then
            return "Nächster Druck: Kaufpreis für " .. cur.r.qty .. " Stück anfragen " .. KeyName()
        end
        return "Nächster Druck: günstigstes lohnendes Angebot kaufen " .. KeyName()
    end
    local q = A.queue
    local left = q and (#q - A.pos) or nil
    return "Nächster Druck: nächsten Vorschlag suchen" .. (left and (" (" .. left .. " übrig)") or "") .. " " .. KeyName()
end

function F.StepButtonText()
    local s = A.state
    if s == "confirm" then return "Kauf bestätigen" end
    if s == "starting" then return "Preis wird geprüft ..." end
    local cur = F.cur
    if cur and cur.id == A.stepId and cur.r and cur.r.qty > 0 then return cur.commodity and "Preis anfragen" or "Kaufen" end
    return "Nächsten suchen"
end

local function Show(extra)
    if F.ShowStepOnly then F.ShowStepOnly(extra) end
    if F.Refresh then F.Refresh() end
end

---------------------------------------------------------------------------
-- Ein Schritt
---------------------------------------------------------------------------
local function SearchNext()
    if not A.queue or A.pos >= #A.queue then A.BuildQueue() end
    A.pos = A.pos + 1
    local id = A.queue[A.pos]
    if not id then
        ns.Print("Flipper: keine Vorschläge mehr. Neu scannen und analysieren, dann geht es weiter.")
        A.queue = nil
        Show("|cff888888Keine Vorschläge mehr.|r")
        return
    end
    A.stepId = id
    A.state = "searching"
    A.bought, A.boughtQty = 0, 0
    F.cur = nil
    local key = C_AuctionHouse.MakeItemKey and C_AuctionHouse.MakeItemKey(id)
    local sorts = { { sortOrder = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0, reverseSort = false } }
    local ok = key and pcall(C_AuctionHouse.SendSearchQuery, key, sorts, true)
    if not ok then
        ns.Print("Flipper: Suche nicht möglich - das AH dieser Spielversion verhält sich anders.")
        A.state = nil
        return
    end
    ns.Print(string.format("Flipper: suche %s (%d/%d)", ItemName(id), A.pos, #A.queue))
    Show()
end

local function MarkDone(id)
    if id then A.done[id] = true end
    A.state, A.pending = nil, nil
end

function F.Step()
    if not AHOpen() then
        ns.Print("Flipper: bitte zuerst das Auktionshaus öffnen.")
        return
    end
    if not (C_AuctionHouse and C_AuctionHouse.SendSearchQuery) then
        ns.Print("Flipper: dieses Auktionshaus wird nicht unterstützt.")
        return
    end
    -- 1) Handelswaren-Kauf bestaetigen
    if A.state == "confirm" and A.pending then
        local p = A.pending
        local ok = pcall(C_AuctionHouse.ConfirmCommoditiesPurchase, p.id, p.qty)
        if ok then
            ns.Print(string.format("Flipper: kaufe %d× %s für %s ...", p.qty, ItemName(p.id), F.Money(p.total)))
            A.state = "buying"
        else
            ns.Print("Flipper: Kauf vom Spiel abgelehnt.")
            MarkDone(p.id)
        end
        Show()
        return
    end
    if A.state == "starting" or A.state == "buying" then return end   -- warten auf das Spiel

    -- 2) Suchergebnis liegt vor: kaufen
    local cur = F.cur
    if cur and cur.id == A.stepId and A.state == "searching" then
        local r = cur.r
        if not r or r.qty <= 0 then
            MarkDone(cur.id)
            SearchNext()
            return
        end
        if cur.commodity then
            A.state = "starting"
            A.pending = { id = cur.id, qty = r.qty, maxUnit = r.maxUnit, expected = r.cost }
            local ok = pcall(C_AuctionHouse.StartCommoditiesPurchase, cur.id, r.qty)
            if not ok then
                ns.Print("Flipper: Kauf konnte nicht gestartet werden.")
                MarkDone(cur.id)
            end
            Show()
            return
        end
        -- Einzelgegenstaende: je Druck eine Auktion kaufen (guenstigste zuerst)
        for _, l in ipairs(cur.list) do
            if not l.bought and l.auctionID and l.unit <= r.maxUnit and (A.boughtQty or 0) + l.qty <= r.qty then
                l.bought = true
                A.boughtQty = (A.boughtQty or 0) + l.qty
                local ok = pcall(C_AuctionHouse.PlaceBid, l.auctionID, l.buyout)
                if ok then
                    A.bought = (A.bought or 0) + 1
                    F.Log("buy", cur.id, l.qty, l.buyout)
                    ns.Print(string.format("Flipper: kaufe %s für %s", ItemName(cur.id), F.Money(l.buyout)))
                end
                Show()
                return
            end
        end
        MarkDone(cur.id)   -- alle lohnenden Angebote gekauft
    end
    -- 3) naechsten Vorschlag suchen
    SearchNext()
end

---------------------------------------------------------------------------
-- Rueckmeldungen des Spiels
---------------------------------------------------------------------------
local function OnPriceUpdated(unitPrice, totalPrice)
    if A.state ~= "starting" or not A.pending then return end
    local p = A.pending
    unitPrice, totalPrice = S(unitPrice), S(totalPrice)
    if not totalPrice then return end
    if totalPrice > (p.expected or p.maxUnit * p.qty) * PRICE_TOLERANCE then
        pcall(C_AuctionHouse.CancelCommoditiesPurchase)
        ns.Print(string.format("Flipper: Preis gestiegen (%s statt %s für %d Stück) - abgebrochen.",
            F.Money(totalPrice, true), F.Money(p.expected or 0, true), p.qty))
        MarkDone(p.id)
    else
        p.total = totalPrice
        A.state = "confirm"
    end
    Show()
end

local function OnCommodityBought()
    local p = A.pending
    if p then
        F.Log("buy", p.id, p.qty, p.total)
        ns.Print(string.format("Flipper: |cff40ff40gekauft|r %d× %s für %s.", p.qty, ItemName(p.id), F.Money(p.total)))
        MarkDone(p.id)
    end
    Show()
end

local function OnCommodityFailed()
    if A.pending then
        ns.Print("Flipper: Kauf fehlgeschlagen (Angebot weg?) - weiter mit dem nächsten.")
        MarkDone(A.pending.id)
    end
    Show()
end

---------------------------------------------------------------------------
-- Buchhaltung (Grundlage): Kaeufe und Verkaeufe merken
---------------------------------------------------------------------------
function F.Log(kind, id, qty, total, extra)
    local d = F.db()
    d.ledger = d.ledger or {}
    table.insert(d.ledger, 1, { t = time(), kind = kind, id = id, qty = qty, total = total, name = extra })
    while #d.ledger > 2000 do table.remove(d.ledger) end
    if F.Stock then
        if kind == "buy" and id then pcall(F.Stock.Add, id, qty or 1, total or 0)
        elseif kind == "sell" then pcall(F.Stock.OnSold, extra, qty or 1, total or 0) end
    end
end

---------------------------------------------------------------------------
-- Post abholen
---------------------------------------------------------------------------
local M = { running = false }
F.Mail = M

local function FreeSlots()
    if not (C_Container and C_Container.GetContainerNumFreeSlots) then return 99 end
    local n = 0
    for bag = 0, 4 do n = n + (C_Container.GetContainerNumFreeSlots(bag) or 0) end
    return n
end

local AH_SENDER = { "auktionshaus", "auction house", "hôtel des ventes", "casa de subastas" }
local function IsAHMail(i, sender)
    if GetInboxInvoiceInfo then
        local ok, invType = pcall(GetInboxInvoiceInfo, i)
        if ok and S(invType) then return true end
    end
    sender = type(sender) == "string" and sender:lower() or ""
    for _, s in ipairs(AH_SENDER) do if sender:find(s, 1, true) then return true end end
    return false
end

-- alle = true: auch Briefe von Spielern (Nachnahme wird nie bezahlt)
function M.Start(all)
    if M.running then return end
    if not (InboxFrame and InboxFrame:IsVisible()) and not (MailFrame and MailFrame:IsShown()) then
        ns.Print("Flipper: bitte zuerst den Briefkasten öffnen.")
        return
    end
    M.running, M.all, M.gold, M.items, M.i = true, all, 0, 0, nil
    M.Next()
end

function M.Stop(msg)
    M.running = false
    ns.Print(string.format("Flipper: Post abgeholt - %s und %d Gegenstände%s.", F.Money(M.gold or 0), M.items or 0, msg and (" (" .. msg .. ")") or ""))
    if M.button then M.button:SetText("CBAS: AH-Post abholen") end
end

function M.Next()
    if not M.running then return end
    if not (MailFrame and MailFrame:IsShown()) then M.running = false return end
    local n = GetInboxNumItems() or 0
    M.i = M.i and math.min(M.i, n) or n
    while M.i >= 1 do
        local i = M.i
        local _, _, sender, subject, money, cod, _, hasItem = GetInboxHeaderInfo(i)
        money, cod = S(money) or 0, S(cod) or 0
        if cod == 0 and (M.all or IsAHMail(i, S(sender))) then
            -- Verkaufsrechnung merken (fuer die Buchhaltung)
            if GetInboxInvoiceInfo and money > 0 then
                local ok, invType, itemName, _, _, _, _, _, _, _, count = pcall(GetInboxInvoiceInfo, i)
                if ok and S(invType) == "seller" then
                    F.Log("sell", nil, S(count) or 1, money, S(itemName))   -- ausgezahlter Betrag = Erloes nach Gebuehr
                end
            end
            if money > 0 then
                pcall(TakeInboxMoney, i)
                M.gold = M.gold + money
                if M.button then M.button:SetText("Hole Post ... " .. F.Money(M.gold, true)) end
                C_Timer.After(0.4, M.Next)
                return
            elseif hasItem then
                if FreeSlots() <= 0 then M.Stop("Taschen voll") return end
                pcall(AutoLootMailItem, i)
                M.items = M.items + 1
                C_Timer.After(0.5, M.Next)
                return
            end
        end
        M.i = i - 1
    end
    M.Stop()
end

local function MakeMailButton()
    if M.button or not InboxFrame then return end
    local b = CreateFrame("Button", nil, InboxFrame, "UIPanelButtonTemplate")
    b:SetSize(170, 22)
    b:SetPoint("TOPRIGHT", InboxFrame, "TOPRIGHT", -40, -30)
    b:SetText("CBAS: AH-Post abholen")
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function()
        if M.running then M.running = false; M.Stop("abgebrochen") return end
        M.Start(IsShiftKeyDown and IsShiftKeyDown())
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Holt Gold und Gegenstände aus allen Auktionshaus-Briefen.\nShift-Klick: auch Briefe von Spielern (Nachnahme wird nie bezahlt).\nNochmal klicken = anhalten.", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    M.button = b
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        for _, e in ipairs({ "COMMODITY_PRICE_UPDATED", "COMMODITY_PURCHASE_SUCCEEDED", "COMMODITY_PURCHASE_FAILED",
            "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "MAIL_SHOW", "MAIL_CLOSED" }) do
            pcall(ev.RegisterEvent, ev, e)
        end
    elseif event == "COMMODITY_PRICE_UPDATED" then
        pcall(OnPriceUpdated, ...)
    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
        pcall(OnCommodityBought)
    elseif event == "COMMODITY_PURCHASE_FAILED" then
        pcall(OnCommodityFailed)
    elseif event == "AUCTION_HOUSE_SHOW" then
        A.Reset()
        C_Timer.After(0.5, function() pcall(Show) end)
    elseif event == "AUCTION_HOUSE_CLOSED" then
        A.Reset()
    elseif event == "MAIL_SHOW" then
        pcall(MakeMailButton)
        if M.button then M.button:SetText("CBAS: AH-Post abholen") end
    elseif event == "MAIL_CLOSED" then
        M.running = false
    end
end)

---------------------------------------------------------------------------
-- Autopilot: EINE Taste fuer alles. Jeder Druck macht den naechsten sinnvollen Schritt:
-- laufenden Kauf/Verkauf fortsetzen -> fertige Ware einstellen -> naechstes Schnaeppchen kaufen.
-- (Blizzard verlangt fuer jeden Kauf und jedes Einstellen einen Tastendruck - darum Taste statt Automatik.)
---------------------------------------------------------------------------
BINDING_NAME_CBAS_PILOT = "Flipper: AUTOPILOT (eine Taste für alles)"

function A.BuyPending()
    local s = A.state
    if s == "starting" or s == "confirm" or s == "buying" then return true end
    local cur = F.cur
    if cur and cur.id == A.stepId and s == "searching" and cur.r and cur.r.qty > 0 then
        if cur.commodity then return true end
        for _, l in ipairs(cur.list or {}) do
            if not l.bought and l.auctionID and l.unit <= cur.r.maxUnit and (A.boughtQty or 0) + l.qty <= cur.r.qty then return true end
        end
    end
    return false
end

function A.PilotNext()
    local St = F.Stock
    if St and (St.state == "ready" or St.state == "searching" or St.state == "posting") then return "sell" end
    if A.BuyPending() then return "buy" end
    if St and #St.ReadyList() > 0 then return "sell" end
    return "buy"
end

function F.Pilot()
    if not AHOpen() then
        ns.Print("Autopilot: bitte zuerst das Auktionshaus öffnen.")
        return
    end
    if A.PilotNext() == "sell" then F.Stock.Step() else F.Step() end
end

function F.PilotText()
    local St = F.Stock
    if A.PilotNext() == "sell" then
        if St.state == "ready" then return "Autopilot: jetzt einstellen" end
        if St.state == "searching" or St.state == "posting" then return "Autopilot: warte aufs AH ..." end
        return "Autopilot: Ware einstellen (" .. #St.ReadyList() .. ")"
    end
    return "Autopilot: " .. (F.StepButtonText and F.StepButtonText() or "weiter")
end
