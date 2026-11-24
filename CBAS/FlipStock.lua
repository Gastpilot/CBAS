-- CBAS - Flipper: Lager & Einstellen (2h-Modus)
-- Merkt sich, was du ueber die Flip-Taste gekauft hast, erinnert dich nach X Stunden
-- und stellt es per Tastendruck ein (Preis: knapp unter dem billigsten fremden Angebot,
-- nie unter deinem Einkaufspreis + Gebuehr). Einstellen braucht - wie Kaufen - einen Tastendruck.
local ADDON, ns = ...
local S = ns.S
local F = ns.Flip
local St = { state = nil, pending = nil, skip = {} }
F.Stock = St

BINDING_NAME_CBAS_FLIPSELL = "Flipper: Einstellen (nächster Verkaufsschritt)"

local DUR_QUICK, DUR_LONG = 1, 2       -- 1 = 12 Std., 2 = 24 Std., 3 = 48 Std.
local MIN_MARGIN = 1.03                -- mindestens 3 % ueber Einkauf + Gebuehr

local function AHOpen() return AuctionHouseFrame and AuctionHouseFrame:IsShown() end
local function Name(id)
    local i = F.ItemInfo(id)
    return (i and i.link) or ("Gegenstand " .. id)
end

function St.db()
    local d = F.db()
    d.stock = d.stock or {}
    return d.stock
end
function St.Hours() return F.db().settings.sellAfterH or 0 end

function St.BagCount(id)
    local f = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not f then return 0 end
    local ok, n = pcall(f, id, false)
    return (ok and tonumber(n)) or 0
end

function St.Add(id, qty, total)
    local s = St.db()
    local e = s[id]
    if not e then
        e = { qty = 0, cost = 0, t = time(), posted = 0, sold = 0, revenue = 0 }
        s[id] = e
    end
    e.qty, e.cost = e.qty + qty, e.cost + total
    e.mode = F.IsQuick(id) and "2h" or "lang"
    local ct = F.ClaudeTip(id)
    local T = F.Targets(id, id)
    e.target = (ct and ct.sellAt) or (T and T.ahNet and math.floor(T.ahNet / (1 - F.AH_CUT))) or e.target
    e.lastBuy, e.notified = time(), nil
end

function St.UnitCost(e) return e.qty > 0 and e.cost / e.qty or 0 end
function St.Floor(e) return math.ceil(St.UnitCost(e) * MIN_MARGIN / (1 - F.AH_CUT)) end
function St.ReadyAt(e) return (e.lastBuy or e.t) + (e.mode == "2h" and St.Hours() * 3600 or 0) end
function St.Left(e) return math.max(0, e.qty - (e.sold or 0) - (e.posted or 0)) end

-- Status fuer die Lagerliste: Text, bereit?
function St.Status(id, e)
    local bags = St.BagCount(id)
    if bags <= 0 or St.Left(e) <= 0 then
        if (e.posted or 0) > 0 then return "|cff66ccffim AH|r", false end
        if (e.sold or 0) > 0 then return "|cff40ff40verkauft|r", false end
        return "|cff888888nicht in den Taschen|r", false
    end
    if St.skip[id] then return "|cffff8000Markt zu billig - warten|r", false end
    local ra = St.ReadyAt(e)
    if time() < ra then return "|cffffd100ab " .. date("%H:%M", ra) .. " einstellen|r", false end
    return "|cff40ff40Einstellen!|r", true
end

-- Verkaufsrechnung aus der Post: dem Lager zuordnen (ueber den Namen)
function St.OnSold(name, count, money)
    if not name then return end
    for id, e in pairs(St.db()) do
        local i = F.ItemInfo(id)
        if i and i.name == name then
            e.sold = (e.sold or 0) + count
            e.posted = math.max(0, (e.posted or 0) - count)
            e.revenue = (e.revenue or 0) + money
            return
        end
    end
end

-- erledigte Eintraege aufraeumen (alles verkauft / nach 14 Tagen nichts mehr da)
function St.Cleanup()
    local s = St.db()
    for id, e in pairs(s) do
        local done = (e.sold or 0) >= e.qty and (e.posted or 0) <= 0
        local gone = St.BagCount(id) <= 0 and (e.posted or 0) <= 0 and time() - (e.lastBuy or e.t) > 14 * 86400
        if done or gone then s[id] = nil end
    end
end

function St.ReadyList()
    local l = {}
    for id, e in pairs(St.db()) do
        local _, ready = St.Status(id, e)
        if ready then l[#l + 1] = { id = id, v = (e.target or 0) * St.Left(e) } end
    end
    table.sort(l, function(a, b) return a.v > b.v end)
    return l
end

---------------------------------------------------------------------------
-- Einstellen: jeder Druck ein Schritt (suchen -> einstellen)
---------------------------------------------------------------------------
local function FindLocation(id)
    if not (C_Container and ItemLocation) then return nil end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            if C_Container.GetContainerItemID(bag, slot) == id then
                local info = C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
                if not (info and info.isBound) then
                    return ItemLocation:CreateFromBagAndSlot(bag, slot)
                end
            end
        end
    end
end

function St.Hint()
    local n = #St.ReadyList()
    if St.state == "ready" and St.pending then
        local p = St.pending
        return string.format("|cff40ff40Einstellen: %d× %s für je %s|r - Knopf \"Einstellen\" / Taste", p.qty, Name(p.id), F.Money(p.price, true))
    end
    if St.state == "searching" then return "|cffffd100Einstellen: prüfe Marktpreis ...|r" end
    if n > 0 then return "|cff40ff40" .. n .. " Gegenstand/-stände bereit zum Einstellen|r - Knopf \"Einstellen\"" end
    return nil
end

function St.ButtonText()
    if St.state == "ready" and St.pending then return "Jetzt einstellen" end
    if St.state == "searching" then return "Preis wird geprüft ..." end
    local n = #St.ReadyList()
    return n > 0 and ("Einstellen (" .. n .. ")") or "Einstellen"
end

local function Show()
    if F.ShowStepOnly then F.ShowStepOnly() end
    if F.Refresh then F.Refresh() end
end

function St.Step()
    if not AHOpen() then ns.Print("Flipper: zum Einstellen das Auktionshaus öffnen.") return end
    if St.state == "posting" then
        if GetTime() - (St.postAt or 0) < 5 then return end
        St.state = nil
    end
    if St.state == "searching" and GetTime() - (St.searchAt or 0) < 5 then return end
    -- 2) Preis steht fest -> einstellen
    if St.state == "ready" and St.pending then
        local p = St.pending
        local loc = FindLocation(p.id)
        if not loc then
            ns.Print("Flipper: " .. Name(p.id) .. " nicht (mehr) in den Taschen.")
            St.state, St.pending = nil, nil
            Show()
            return
        end
        local ok
        if p.commodity then
            ok = pcall(C_AuctionHouse.PostCommodity, loc, p.dur, p.qty, p.price)
        else
            ok = pcall(C_AuctionHouse.PostItem, loc, p.dur, 1, nil, p.price)
        end
        if ok then
            St.state, St.postAt = "posting", GetTime()
            ns.Print(string.format("Flipper: stelle %d× %s für je %s ein ...", p.commodity and p.qty or 1, Name(p.id), F.Money(p.price)))
        else
            ns.Print("Flipper: Einstellen vom Spiel abgelehnt.")
            St.state, St.pending = nil, nil
        end
        Show()
        return
    end
    -- 1) naechsten bereiten Gegenstand suchen
    local l = St.ReadyList()
    if #l == 0 then
        ns.Print("Flipper: gerade nichts bereit zum Einstellen.")
        Show()
        return
    end
    local id = l[1].id
    local key = C_AuctionHouse.MakeItemKey and C_AuctionHouse.MakeItemKey(id)
    local sorts = { { sortOrder = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0, reverseSort = false } }
    if key and pcall(C_AuctionHouse.SendSearchQuery, key, sorts, true) then
        St.state, St.searchId, St.searchAt, St.pending = "searching", id, GetTime(), nil
    end
    Show()
end

-- Suchergebnis fuer einen Verkauf? true = verbraucht (keine Kaufhilfe zeigen)
function St.OnResults(id, list, commodity)
    if St.state ~= "searching" or id ~= St.searchId then return false end
    local e = St.db()[id]
    if not e then St.state = nil return false end
    local lowest
    for _, l in ipairs(list) do
        if not l.own and l.qty > 0 and (not lowest or l.unit < lowest) then lowest = l.unit end
    end
    local target = e.target or St.Floor(e)
    local price = lowest and math.min(lowest - 1, math.floor(target * 1.25)) or target
    if commodity then price = math.floor(price / 100) * 100 end            -- Handelswaren: ganze Silber
    local floor = St.Floor(e)
    if price < floor then
        St.skip[id] = true
        St.state = nil
        ns.Print(string.format("Flipper: %s - billigstes Angebot %s, unter deiner Grenze %s. Nicht einstellen, später nochmal.",
            Name(id), F.Money(lowest or 0, true), F.Money(floor, true)))
        Show()
        return true
    end
    local qty = commodity and math.min(St.BagCount(id), St.Left(e)) or 1
    St.pending = { id = id, price = price, qty = qty, commodity = commodity, dur = e.mode == "2h" and DUR_QUICK or DUR_LONG }
    St.state = "ready"
    Show()
    return true
end

local function OnCreated()
    local p = St.pending
    if St.state ~= "posting" or not p then return end
    local e = St.db()[p.id]
    local q = p.commodity and p.qty or 1
    if e then e.posted = (e.posted or 0) + q end
    F.Log("post", p.id, q, p.price * q)
    ns.Print(string.format("Flipper: |cff40ff40eingestellt|r %d× %s für je %s.", q, Name(p.id), F.Money(p.price)))
    -- Einzelgegenstaende: weitere Stuecke zum selben Preis beim naechsten Druck
    if not p.commodity and e and St.Left(e) > 0 and St.BagCount(p.id) > 0 then
        St.state = "ready"
    else
        St.state, St.pending = nil, nil
    end
    Show()
end

-- eigene Auktionen abfragen: wie viel liegt wirklich noch im AH
local function OnOwned()
    if not (C_AuctionHouse.GetNumOwnedAuctions and C_AuctionHouse.GetOwnedAuctionInfo) then return end
    local cnt = {}
    for i = 1, C_AuctionHouse.GetNumOwnedAuctions() or 0 do
        local a = C_AuctionHouse.GetOwnedAuctionInfo(i)
        if a and a.itemKey and (a.status == 0 or a.status == nil) then
            cnt[a.itemKey.itemID] = (cnt[a.itemKey.itemID] or 0) + (a.quantity or 1)
        end
    end
    for id, e in pairs(St.db()) do e.posted = cnt[id] or 0 end
    if F.Refresh then F.Refresh() end
end

-- Erinnerung: 2h-Ware ist bereit
local function Remind()
    local list = {}
    for id, e in pairs(St.db()) do
        local _, ready = St.Status(id, e)
        if ready and not e.notified and e.mode == "2h" then
            e.notified = true
            list[#list + 1] = Name(id)
        end
    end
    if #list > 0 then
        ns.Print("|cff40ff40Flipper:|r jetzt einstellen: " .. table.concat(list, ", ") .. " - im AH Knopf \"Einstellen\" oder Taste.")
        if PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960, "Master") end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        for _, e in ipairs({ "AUCTION_HOUSE_AUCTION_CREATED", "OWNED_AUCTIONS_UPDATED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED" }) do
            pcall(ev.RegisterEvent, ev, e)
        end
        if C_Timer.NewTicker then C_Timer.NewTicker(60, function() pcall(Remind) end) end
        C_Timer.After(10, function() pcall(St.Cleanup); pcall(Remind) end)
    elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
        pcall(OnCreated)
    elseif event == "OWNED_AUCTIONS_UPDATED" then
        pcall(OnOwned)
    elseif event == "AUCTION_HOUSE_SHOW" then
        wipe(St.skip)
        St.state, St.pending = nil, nil
        if C_AuctionHouse.QueryOwnedAuctions then pcall(C_AuctionHouse.QueryOwnedAuctions, {}) end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        St.state, St.pending = nil, nil
    end
end)
