-- CBAS - Flipper: AH-Flips und Haendler-Flips planen
-- Preisquellen (optional): Auctionator (eigene Scans) und TradeSkillMaster (TSM_API).
-- Kaufen/Einstellen macht immer der Spieler selbst per Klick (Blizzard erlaubt nichts anderes).
local ADDON, ns = ...
local S = ns.S

local F = {}
ns.Flip = F

local CALLER = "CBAS"
F.AH_CUT = 0.05              -- Auktionshaus-Gebuehr auf den Verkaufserloes

function F.db()
    local d = ns.db.flip
    if not d then
        d = { watch = {}, found = {}, settings = { minProfitPct = 15, minVendorProfit = 50 } }
        ns.db.flip = d
    end
    d.watch = d.watch or {}
    d.found = d.found or {}
    d.settings = d.settings or {}
    if d.settings.minProfitPct == nil then d.settings.minProfitPct = 15 end
    if d.settings.minVendorProfit == nil then d.settings.minVendorProfit = 50 end   -- Kupfer
    if d.settings.minMarket == nil then d.settings.minMarket = 2000 end            -- Vorschlaege erst ab 20s Marktwert
    if d.settings.maxSpend == nil then d.settings.maxSpend = 0 end                 -- 0 = kein Budget
    d.suggest = d.suggest or {}
    d.vendorSell = d.vendorSell or {}
    return d
end

---------------------------------------------------------------------------
-- Hilfen
---------------------------------------------------------------------------
function F.ItemID(link)
    if type(link) == "number" then return link end
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)")) or tonumber(link)
end

local function ItemInfo(item, noLoad)
    local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not f then return nil end
    local ok, name, link, quality, _, _, _, _, stack, _, icon, sellPrice, classID, subclassID, bindType = pcall(f, item)
    if not ok or not name then
        if noLoad then return nil end
        -- Daten anfordern, kommen kurz darauf
        local id = F.ItemID(item)
        if id and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
        return nil
    end
    return { name = name, link = link, quality = quality, stack = stack, icon = icon, sell = sellPrice or 0,
        classID = classID, subclassID = subclassID, bind = bindType }
end
F.ItemInfo = ItemInfo

-- Quatsch fuers AH-Flippen: graue Sachen, weisse Ruestung/Waffen (Hemden, Haendlerwaffen),
-- beim Aufheben gebundene Sachen und alles, was du selbst ausgeblendet hast.
function F.IsJunk(id)
    local d = F.db()
    if d.ignore and id and d.ignore[id] then return true end
    if d.settings.hideJunk == false then return false end
    local info = id and ItemInfo(id)
    if not info then return false end
    if info.quality == 0 then return true end
    if info.quality == 1 and (info.classID == 2 or info.classID == 4) then return true end
    if info.bind == 1 then return true end
    return false
end
function F.Ignore(id, on)
    local d = F.db()
    d.ignore = d.ignore or {}
    d.ignore[id] = on and true or nil
end

-- 2h-Schnellflip: stapelbare Handelsware mit viel Angebot und ruhigem Preis
function F.IsQuick(id)
    local info = ItemInfo(id)
    if info and (info.stack or 1) <= 1 then return false end
    local ct = F.ClaudeTip and F.ClaudeTip(id)
    if ct and ct.quick ~= nil then return ct.quick and true or false end
    local st = F.Stats(F.EntryFor(id))
    -- "sicher in ca. 2 Std. verkauft": immer viel im AH, fast jeden Tag gehandelt, ruhiger Preis, nicht fallend
    return (st and st.availAvg and st.availAvg >= 20 and st.days >= 4 and st.liq >= 0.8 and st.cv <= 0.25
        and (st.fslope or 0) > -0.02 and (st.trends[3] or 0) > -0.05) and true or false
end

-- Geld schoen anzeigen (g/s/k), nil -> "-"
function F.Money(c, short)
    if not c or c <= 0 then return "|cff555555-|r" end
    c = math.floor(c + 0.5)
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    if short then
        if g >= 100 then return string.format("|cffffd700%dg|r", g) end
        if g > 0 then return string.format("|cffffd700%dg|r|cffc7c7cf%02ds|r", g, s) end
        if s > 0 then return string.format("|cffc7c7cf%ds|r|cffeda55f%02dk|r", s, k) end
        return string.format("|cffeda55f%dk|r", k)
    end
    local parts = {}
    if g > 0 then parts[#parts + 1] = "|cffffd700" .. g .. "g|r" end
    if s > 0 or g > 0 then parts[#parts + 1] = "|cffc7c7cf" .. s .. "s|r" end
    parts[#parts + 1] = "|cffeda55f" .. k .. "k|r"
    return table.concat(parts, " ")
end

---------------------------------------------------------------------------
-- Preisquellen
---------------------------------------------------------------------------
-- Claude-Tipps (Datei ClaudeTips.lua, von Claude aus deinen Daten erzeugt)
local TIP_MAX_AGE = 3 * 86400
function F.Claude()
    local c = _G.CBAS_CLAUDE
    if type(c) ~= "table" then return nil end
    return c, (c.generated and time() - c.generated < TIP_MAX_AGE) or false
end
function F.ClaudeTip(id)
    local c, fresh = F.Claude()
    if not c or not fresh or type(c.items) ~= "table" or not id then return nil end
    return c.items[id]
end

function F.HasAuctionator()
    return type(Auctionator) == "table" and type(Auctionator.API) == "table" and type(Auctionator.API.v1) == "table"
end
function F.HasTSM()
    return type(TSM_API) == "table" and type(TSM_API.GetCustomPriceValue) == "function"
end

local function AtrCall(fname, link)
    if not F.HasAuctionator() then return nil end
    local fn = Auctionator.API.v1[fname]
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, CALLER, link)
    if ok and type(v) == "number" then return v end
end

local tsmStringCache = {}
local function TSMString(link)
    if tsmStringCache[link] then return tsmStringCache[link] end
    local s
    if type(TSM_API.ToItemString) == "function" then
        local ok, v = pcall(TSM_API.ToItemString, link)
        if ok and type(v) == "string" then s = v end
    end
    s = s or ("i:" .. (F.ItemID(link) or 0))
    tsmStringCache[link] = s
    return s
end

local function TSM(source, link)
    if not F.HasTSM() then return nil end
    local ok, v = pcall(TSM_API.GetCustomPriceValue, source, TSMString(link))
    if ok and type(v) == "number" and v > 0 then return v end
end

-- Auctionator speichert seine Scans in AUCTIONATOR_PRICE_DATABASE[<Realm/Fraktion>][<Schluessel>].m
-- Das ist ein internes Format: wir lesen es nur vorsichtig und nur zum Durchsuchen.
local function AtrRealmTable()
    -- bevorzugt Auctionators eigene, im Spiel entpackte Datenbank
    if type(Auctionator) == "table" and type(Auctionator.Database) == "table" and type(Auctionator.Database.db) == "table" then
        return Auctionator.Database.db
    end
    local db = _G.AUCTIONATOR_PRICE_DATABASE
    if type(db) ~= "table" then return nil end
    local realm = ((GetRealmName and GetRealmName()) or ""):gsub("%s", "")
    local best, bestN
    for k, t in pairs(db) do
        if type(t) == "table" and k ~= "__dbversion" then
            if type(k) == "string" and realm ~= "" and k:gsub("%s", ""):find(realm, 1, true) then return t end
            local n = 0
            for _ in pairs(t) do n = n + 1 if n > 50000 then break end end
            if not bestN or n > bestN then best, bestN = t, n end
        end
    end
    return best
end

-- Auctionator zaehlt Tage seit dem 1.1.2020
function F.Today()
    local day0 = (type(Auctionator) == "table" and Auctionator.Constants and Auctionator.Constants.SCAN_DAY_0)
        or time({ year = 2020, month = 1, day = 1, hour = 0 })
    return math.floor((time() - day0) / 86400), day0
end

function F.DayDate(day)
    local _, day0 = F.Today()
    return day0 + day * 86400 + 12 * 3600
end

-- Wochentag eines Auctionator-Tages (1 = So ... 7 = Sa) ohne date()-Aufruf (spart Speicher)
local wd0
function F.Weekday(day)
    if not wd0 then wd0 = tonumber(date("%w", F.DayDate(0))) end
    return (wd0 + day) % 7 + 1
end

-- Zwischenspeicher fuer Statistik und Preise. F.ver steigt nach jedem AH-Besuch (neue Scans).
F.ver = 0
local statsCache = setmetatable({}, { __mode = "k" })
local priceCache, priceN = {}, 0
function F.Invalidate()
    F.ver = F.ver + 1
    wipe(priceCache)
    priceN = 0
end

-- Verlauf eines Eintrags: sortierte Liste { day, price, avail }
function F.HistoryOf(entry)
    if type(entry) ~= "table" or type(entry.h) ~= "table" then return {} end
    local list = {}
    for dk, vk in pairs(entry.h) do
        local d, v = tonumber(dk), tonumber(vk)
        if d and v and v > 0 then
            local av = type(entry.a) == "table" and tonumber(entry.a[dk] or entry.a[d]) or nil
            list[#list + 1] = { day = d, price = v, avail = av }
        end
    end
    table.sort(list, function(x, y) return x.day < y.day end)
    return list
end

function F.EntryFor(id)
    local t = AtrRealmTable()
    return t and id and (t[tostring(id)] or t[id])
end

local function median(v)
    local s = {}
    for i, x in ipairs(v) do s[i] = x end
    table.sort(s)
    local n = #s
    if n == 0 then return nil end
    if n % 2 == 1 then return s[(n + 1) / 2] end
    return (s[n / 2] + s[n / 2 + 1]) / 2
end
F.Median = median

-- Kennzahlen + Prognose aus dem Verlauf (heute zaehlt nicht mit: das ist der Preis, den wir bewerten)
-- Rueckgabe: { median, avg, cv, days, liq, slope (Anteil/Tag), forecast (in 3 Tagen), sell (erwarteter
--   Verkaufspreis), weekday = {[1..7] = Faktor}, availAvg, hist }
-- Steigung (Anteil pro Tag) einer Punktreihe
local function SlopeOf(xs, ys)
    local n = #xs
    if n < 3 then return nil end
    local mx, my = 0, 0
    for i = 1, n do mx = mx + xs[i]; my = my + ys[i] end
    mx, my = mx / n, my / n
    local num, den = 0, 0
    for i = 1, n do num = num + (xs[i] - mx) * (ys[i] - my); den = den + (xs[i] - mx) ^ 2 end
    if den <= 0 or my <= 0 then return 0, my end
    return math.max(-0.25, math.min(0.25, (num / den) / my)), my
end
local function SSE(xs, ys, a, b)
    local n = #xs
    local mx, my = 0, 0
    for i = a, b do mx = mx + xs[i]; my = my + ys[i] end
    local k = b - a + 1
    mx, my = mx / k, my / k
    local num, den = 0, 0
    for i = a, b do num = num + (xs[i] - mx) * (ys[i] - my); den = den + (xs[i] - mx) ^ 2 end
    local m = den > 0 and num / den or 0
    local e = 0
    for i = a, b do e = e + (ys[i] - (my + m * (xs[i] - mx))) ^ 2 end
    return e
end

-- Raid-Reset (EU: Mittwoch) und eigene Ereignisse (Raidstart, Phase ...)
F.WDNAMES = { "So", "Mo", "Di", "Mi", "Do", "Fr", "Sa" }
function F.ResetWeekday() return (F.db().settings.resetDay or 4) end   -- 1 = So ... 4 = Mi
function F.Events()
    local s = F.db().settings
    s.events = s.events or {}
    return s.events
end
function F.DayOfDate(dd, mm, yy)
    local _, day0 = F.Today()
    local t = time({ year = yy, month = mm, day = dd, hour = 12 })
    return t and math.floor((t - day0) / 86400)
end

function F.Stats(entry, nocache)
    if type(entry) ~= "table" then return nil end
    local c = statsCache[entry]
    local today = F.Today()
    if c and c.v == F.ver and c.d == today then return c.st end
    local st = F.StatsInner(entry)
    if not nocache then statsCache[entry] = { v = F.ver, d = today, st = st } end
    return st
end

function F.StatsInner(entry)
    local hist = F.HistoryOf(entry)
    local today = F.Today()
    local vals, xs, avails = {}, {}, {}
    local first, last = nil, 0
    for _, h in ipairs(hist) do if h.day < today and h.day > last then last = h.day end end
    for _, h in ipairs(hist) do
        if h.day < today and h.day > last - 21 then
            vals[#vals + 1] = h.price
            xs[#xs + 1] = h.day
            if h.avail then avails[#avails + 1] = h.avail end
            first = first or h.day
        end
    end
    local n = #vals
    if n < 3 then return nil end
    local sum = 0
    for _, v in ipairs(vals) do sum = sum + v end
    local avg = sum / n
    local var = 0
    for _, v in ipairs(vals) do var = var + (v - avg) ^ 2 end
    local med = median(vals)
    -- linearer Trend
    local mx, my = 0, avg
    for _, x in ipairs(xs) do mx = mx + x end
    mx = mx / n
    local num, den = 0, 0
    for i = 1, n do num = num + (xs[i] - mx) * (vals[i] - my); den = den + (xs[i] - mx) ^ 2 end
    local slope = den > 0 and (num / den) / my or 0
    slope = math.max(-0.2, math.min(0.2, slope))
    -- Prognose: Median der letzten 7 Tage, fortgeschrieben
    local recent = {}
    for i = 1, n do if xs[i] > last - 7 then recent[#recent + 1] = vals[i] end end
    local base = median(#recent >= 2 and recent or vals)
    local forecast = math.max(1, base * (1 + slope * 3))
    -- Wochentags-Muster (1 = So ... 7 = Sa), Faktor relativ zum Median
    local wd, wdn = {}, {}
    for i = 1, n do
        local w = F.Weekday(xs[i])
        wd[w] = (wd[w] or 0) + vals[i] / med
        wdn[w] = (wdn[w] or 0) + 1
    end
    for w, s in pairs(wd) do wd[w] = s / wdn[w] end
    local aSum = 0
    for _, a in ipairs(avails) do aSum = aSum + a end
    local sell = med
    if slope < 0 then sell = math.min(med, forecast) end   -- fallender Markt: vorsichtig rechnen
    -- Trends fuer mehrere Zeitraeume (Breakpoints 3 / 7 / 14 / 21 Tage)
    local trends = {}
    for _, win in ipairs({ 3, 7, 14, 21 }) do
        local tx, ty = {}, {}
        for i = 1, n do if xs[i] > last - win then tx[#tx + 1] = xs[i]; ty[#ty + 1] = vals[i] end end
        if #tx >= 3 and (win > 3 or #tx >= 3) then trends[win] = SlopeOf(tx, ty) end
    end
    -- Trendwende: beste Zweiteilung (je Seite >= 3 Punkte), nur wenn deutlich besser als eine Gerade
    local brk
    if n >= 7 then
        local whole = SSE(xs, vals, 1, n)
        local best, bi
        for k = 3, n - 3 do
            local e = SSE(xs, vals, 1, k) + SSE(xs, vals, k + 1, n)
            if not best or e < best then best, bi = e, k end
        end
        if bi and whole > 0 and best < whole * 0.6 then
            local bx, by, ax, ay = {}, {}, {}, {}
            for i = 1, bi do bx[#bx + 1] = xs[i]; by[#by + 1] = vals[i] end
            for i = bi + 1, n do ax[#ax + 1] = xs[i]; ay[#ay + 1] = vals[i] end
            local s1, m1 = SlopeOf(bx, by)
            local s2, m2 = SlopeOf(ax, ay)
            if s1 and s2 and (math.abs(s1 - s2) >= 0.02 or math.abs(m2 / m1 - 1) >= 0.12) then
                brk = { day = xs[bi + 1], before = s1, after = s2, levelBefore = m1, levelAfter = m2 }
            end
        end
    end
    -- Preissprung: einmaliger Niveauwechsel (z.B. 55g -> 70g) ist kein Dauertrend.
    -- Zwei Preisniveaus erklaeren die Tage deutlich besser als eine Gerade -> Sprung.
    if not brk and n >= 5 then
        local function LevelSSE(a, b)
            local s = 0
            for i = a, b do s = s + vals[i] end
            local m = s / (b - a + 1)
            local e = 0
            for i = a, b do e = e + (vals[i] - m) ^ 2 end
            return e, m
        end
        local lin = SSE(xs, vals, 1, n)
        local best, bi, m1, m2
        for k = 2, n - 2 do
            local e1, a1 = LevelSSE(1, k)
            local e2, a2 = LevelSSE(k + 1, n)
            if not best or e1 + e2 < best then best, bi, m1, m2 = e1 + e2, k, a1, a2 end
        end
        if bi and lin > 0 and best < lin * 0.5 and math.abs(m2 / m1 - 1) >= 0.10 then
            local ax, ay = {}, {}
            for i = bi + 1, n do ax[#ax + 1] = xs[i]; ay[#ay + 1] = vals[i] end
            brk = { kind = "step", day = xs[bi + 1], before = 0, after = (#ax >= 3 and SlopeOf(ax, ay)) or 0,
                levelBefore = m1, levelAfter = m2 }
        end
    end
    -- nach einer Wende/einem Sprung gilt nur noch das neue Niveau
    local level = med
    if brk then
        local a = {}
        for i = 1, n do if xs[i] >= brk.day then a[#a + 1] = vals[i] end end
        if #a >= 2 then level = median(a); base = level end
    end
    -- Raid-Woche: Preis je Tag relativ zum Reset (0 = Reset-Tag)
    local rw, rwn = {}, {}
    local rd = F.ResetWeekday()
    for i = 1, n do
        local w = F.Weekday(xs[i])
        local k = (w - rd) % 7
        rw[k] = (rw[k] or 0) + vals[i] / med
        rwn[k] = (rwn[k] or 0) + 1
    end
    for k, s in pairs(rw) do rw[k] = s / rwn[k] end
    -- Ereignisse: Median 5 Tage vorher vs. 5 Tage nachher
    local evs = {}
    for _, ev in ipairs(F.Events()) do
        local b, a = {}, {}
        for i = 1, n do
            if xs[i] < ev.day and xs[i] >= ev.day - 5 then b[#b + 1] = vals[i] end
            if xs[i] >= ev.day and xs[i] < ev.day + 5 then a[#a + 1] = vals[i] end
        end
        local e = { name = ev.name, day = ev.day }
        if #b >= 2 and #a >= 2 then e.impact = median(a) / median(b) - 1 end
        evs[#evs + 1] = e
    end
    -- Prognose: nach einer Trendwende zaehlt nur die neue Richtung, sonst der 7-Tage-Trend
    local fslope = (brk and brk.after) or trends[7] or slope
    forecast = math.max(1, base * (1 + fslope * 3))
    sell = level
    local worst = brk and math.min(trends[3] or 0, fslope) or math.min(trends[3] or 0, trends[7] or 0, fslope)
    if worst < 0 then sell = math.min(level, base * (1 + worst * 3)) end
    return {
        trends = trends, brk = brk, level = level, raidWeek = rw, events = evs, fslope = fslope,
        median = med, avg = avg, cv = math.sqrt(var / n) / avg, days = n,
        liq = n / math.min(21, last - first + 1), slope = slope, forecast = forecast, sell = sell,
        weekday = wd, availAvg = #avails > 0 and aSum / #avails or nil, hist = hist,
    }
end

local function AtrHistoryAvg(id)
    local st = F.Stats(F.EntryFor(id))
    if not st then return nil end
    return math.floor(st.sell + 0.5), st.days, st
end

-- Alle Preise zu einem Gegenstand
function F.Prices(link)
    local key = link
    local pc = priceCache[key]
    local now = GetTime()
    if pc and now - pc.t < 30 then return pc.p end
    local p = F.PricesInner(link)
    if priceN > 400 then wipe(priceCache); priceN = 0 end
    if not pc then priceN = priceN + 1 end
    priceCache[key] = { t = now, p = p }
    return p
end

function F.PricesInner(link)
    local info = ItemInfo(link)
    local p = { info = info }
    -- AH-Mindestpreis: Auctionator (letzter eigener Scan), sonst TSM
    p.atr = AtrCall("GetAuctionPriceByItemLink", link)
    p.age = AtrCall("GetAuctionAgeByItemLink", link)           -- Tage seit dem Scan
    p.tsmMin = TSM("dbminbuyout", link)
    p.tsmMarket = TSM("dbmarket", link)
    p.tsmRegion = TSM("dbregionmarketavg", link)
    p.saleRate = TSM("dbregionsalerate", link)
    p.avgBuy = TSM("avgbuy", link)
    p.avgSell = TSM("avgsell", link)
    p.ahMin = p.atr or p.tsmMin
    p.atrAvg, p.atrDays, p.stats = AtrHistoryAvg(F.ItemID(link))
    -- Marktwert: TSM-Markt, sonst TSM-Region, sonst Auctionator-Verlauf
    -- (der aktuelle Preis allein ist kein Marktwert: damit wuerde man ihn mit sich selbst vergleichen)
    if p.tsmMarket then p.market, p.marketSrc = p.tsmMarket, "TSM Markt"
    elseif p.tsmRegion then p.market, p.marketSrc = p.tsmRegion, "TSM Region"
    elseif p.atrAvg then p.market, p.marketSrc = p.atrAvg, "Auctionator-Verlauf " .. p.atrDays .. " Tage" end
    -- Claude-Tipp hat Vorrang vor der eigenen Schaetzung (nicht vor TSM-Marktdaten)
    local ct = F.ClaudeTip and F.ClaudeTip(F.ItemID(link))
    if ct and ct.sellAt and not p.tsmMarket then p.market, p.marketSrc = ct.sellAt, "Claude-Tipp" end
    -- Haendler-Ankaufpreis (was der Haendler zahlt)
    -- Nur der echte Ankaufpreis des Haendlers! (Auctionators "Vendor Price" ist der Preis, zu dem
    -- ein Haendler etwas VERKAUFT - fuer Haendler-Flips unbrauchbar.)
    p.vendor = (info and info.sell and info.sell > 0 and info.sell) or nil
    return p
end

---------------------------------------------------------------------------
-- Flip-Rechnung
---------------------------------------------------------------------------
-- AH-Flip: kaufen zum AH-Min, verkaufen zum Marktwert (minus Gebuehr)
function F.AHFlip(p, w)
    local d = F.db()
    local sell = (w and w.sellAt) or p.market
    local src = (w and w.sellAt) and "dein Verkaufspreis" or p.marketSrc
    if not sell or sell <= 0 then return nil end
    local net = sell * (1 - F.AH_CUT)
    local minPct = (w and w.minPct) or d.settings.minProfitPct
    local buyUpTo = (w and w.buyAt) or math.floor(net / (1 + minPct / 100))
    local r = { sell = sell, net = net, buyUpTo = buyUpTo, src = src }
    if p.ahMin and p.ahMin > 0 then
        r.profit = net - p.ahMin
        r.pct = r.profit / p.ahMin * 100
        r.deal = p.ahMin <= buyUpTo
    end
    return r
end

-- Haendler-Flip: im AH unter dem Haendlerpreis kaufen, beim Haendler verkaufen
function F.VendorFlip(p)
    if not p.vendor or p.vendor <= 0 then return nil end
    local r = { vendor = p.vendor, buyUpTo = p.vendor - 1 }
    if p.ahMin and p.ahMin > 0 then
        r.profit = p.vendor - p.ahMin
        r.deal = r.profit >= F.db().settings.minVendorProfit
    end
    return r
end

---------------------------------------------------------------------------
-- Merkliste
---------------------------------------------------------------------------
function F.Add(link)
    local id = F.ItemID(link)
    if not id then return false end
    local d = F.db()
    local info = ItemInfo(link)
    if not d.watch[id] then
        d.watch[id] = { link = (info and info.link) or link, added = time() }
        ns.Print("Flipper: " .. ((info and info.link) or link) .. " zur Merkliste hinzugefügt.")
    end
    if F.Refresh then F.Refresh() end
    return true
end

function F.Remove(id)
    F.db().watch[id] = nil
    if F.Refresh then F.Refresh() end
end

---------------------------------------------------------------------------
-- Haendler-Flips in den Auctionator-Scans finden (alle bekannten Preise durchgehen)
---------------------------------------------------------------------------
-- Alle Auctionator-Preise analysieren: "Heute flippen" (unter dem eigenen 14-Tage-Schnitt)
-- und Haendler-Flips (unter dem Haendlerpreis). Laeuft in Haeppchen.
function F.Analyze(quiet, onDone)
    if F.scanning then return end
    local t = AtrRealmTable()
    if not t then
        if not quiet then ns.Print("Flipper: keine Auctionator-Scandaten gefunden. Einmal im AH mit Auctionator scannen.") end
        return
    end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    local d = F.db()
    local st = d.settings
    local found, suggest = {}, {}
    F.scanning = { i = 0, n = #keys, hits = 0, sugg = 0, missing = 0 }
    if not quiet then ns.Print(string.format("Flipper: analysiere %d Gegenstände aus deinen Auctionator-Scans ...", #keys)) end
    local budget = (st.maxSpend or 0) > 0 and st.maxSpend or nil
    local function step()
        local sc = F.scanning
        if not sc then return end
        local stop = math.min(sc.n, sc.i + 200)   -- in Haeppchen, damit das Spiel nicht ruckelt
        for i = sc.i + 1, stop do
            local key = keys[i]
            local e = t[key]
            local price = type(e) == "table" and tonumber(e.m)
            local id = tonumber(key) or (type(key) == "string" and tonumber(key:match("^(%d+)")))
            if price and price > 0 and id and (not budget or price <= budget) then
                -- 1) Haendler-Flip (nur Gegenstaende, die der Client schon kennt - sonst wuerden
                --    tausende Abfragen an den Server gehen und das Spiel ruckeln)
                local info = ItemInfo(id, true)
                if info then
                    if info.sell and info.sell - price >= st.minVendorProfit then
                        found[id] = { link = info.link, ah = price, vendor = info.sell, profit = info.sell - price, t = time(),
                            sellVendor = d.found[id] and d.found[id].sellVendor }
                        sc.hits = sc.hits + 1
                    end
                else
                    sc.missing = sc.missing + 1
                end
                -- 2) unter dem eigenen Schnitt - erst grob ohne Speicherverbrauch vorpruefen,
                --    die volle Statistik nur fuer echte Kandidaten
                local hs
                local hh = type(e.h) == "table" and e.h
                if hh then
                    local n, sum, mx, today, last = 0, 0, 0, F.Today(), 0
                    for dk in pairs(hh) do
                        local dd = tonumber(dk)
                        if dd and dd < today and dd > last then last = dd end
                    end
                    for dk, v in pairs(hh) do
                        local dd = tonumber(dk)
                        v = tonumber(v)
                        if dd and v and dd < today and dd > last - 21 then
                            n = n + 1; sum = sum + v
                            if v > mx then mx = v end
                        end
                    end
                    -- Schnitt ohne den hoechsten Ausreisser
                    if n >= 3 and price * (1 + st.minProfitPct / 100) <= ((sum - mx) / (n - 1)) * (1 - F.AH_CUT) * 1.1 then
                        hs = F.Stats(e, true)
                    end
                end
                if hs and hs.median >= st.minMarket and hs.cv <= 0.6 then
                    local net = hs.sell * (1 - F.AH_CUT)
                    local profit = net - price
                    local pct = profit / price * 100
                    if pct >= st.minProfitPct then
                        local liq = math.min(1, hs.liq)
                        local stab = math.max(0.1, 1 - hs.cv)
                        local tsmRate
                        if info and info.link then
                            local p = TSM("dbregionsalerate", info.link)
                            tsmRate = p
                        end
                        local score = profit * liq * stab * (tsmRate and (0.3 + tsmRate) or 1)
                        suggest[id] = { link = info and info.link, ah = price, avg = math.floor(hs.sell + 0.5),
                            slope = hs.slope, forecast = hs.forecast,
                            profit = math.floor(profit + 0.5), pct = pct, days = hs.days, cv = hs.cv,
                            rate = tsmRate, score = score, odd = price < hs.avg * 0.3 or nil, t = time() }
                        sc.sugg = sc.sugg + 1
                    end
                end
            end
        end
        sc.i = stop
        if F.Refresh then F.Refresh() end
        if sc.i < sc.n then
            C_Timer.After(0.05, step)
        else
            -- nur die besten 150 Vorschlaege behalten (haelt Speicher und Datei klein)
            local arr = {}
            for id, s in pairs(suggest) do arr[#arr + 1] = { id = id, s = s.score or 0 } end
            if #arr > 150 then
                table.sort(arr, function(a, b) return a.s > b.s end)
                for i = 151, #arr do suggest[arr[i].id] = nil end
            end
            d.found, d.suggest = found, suggest
            d.analyzed = time()
            F.scanning = nil
            if not quiet or sc.sugg + sc.hits > 0 then
                ns.Print(string.format("Flipper: %d Flip-Vorschläge und %d Händler-Flips gefunden%s.", sc.sugg, sc.hits,
                    sc.missing > 0 and (" (" .. sc.missing .. " Gegenstände noch nicht geladen - gleich nochmal analysieren)") or ""))
            end
            if onDone then onDone() end
            if F.Refresh then F.Refresh() end
        end
    end
    step()
end
F.FindVendorFlips = F.Analyze

---------------------------------------------------------------------------
-- AH-Kaufhilfe: beim Suchen im AH Menge, Kosten und Gewinn ausrechnen
---------------------------------------------------------------------------
-- Kaufziel je Stueck: hoechster Preis, zu dem sich AH- oder Haendler-Flip noch lohnt
function F.Targets(link, id)
    local p = F.Prices(link)
    local w = F.db().watch[id]
    local af, vf = F.AHFlip(p, w), F.VendorFlip(p)
    local s = F.db().suggest and F.db().suggest[id]
    local ahMax = af and af.buyUpTo
    local ahNet = af and af.net
    local ct = F.ClaudeTip(id)
    local capQty
    if ct and ct.buyUpTo and ct.sellAt and not (w and w.buyAt) then
        ahMax, ahNet = ct.buyUpTo, ct.sellAt * (1 - F.AH_CUT)
        capQty = ct.maxQty
    end
    if not ahMax and s then
        ahNet = s.avg * (1 - F.AH_CUT)
        ahMax = math.floor(ahNet / (1 + F.db().settings.minProfitPct / 100))
    end
    local vMax = vf and (vf.vendor - F.db().settings.minVendorProfit)
    return { maxQty = capQty, ahMax = ahMax, ahNet = ahNet, vMax = vMax, vendor = vf and vf.vendor, p = p }
end

function F.EvaluateListings(id, listings)
    local info = ItemInfo(id)
    if not info and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    info = info or { link = "Gegenstand " .. id }
    local T = F.Targets(info.link ~= ("Gegenstand " .. id) and info.link or id, id)
    if not T.ahMax and not T.vMax then return nil end
    table.sort(listings, function(a, b) return a.unit < b.unit end)
    local budget = (F.db().settings.maxSpend or 0) > 0 and F.db().settings.maxSpend or nil
    local r = { link = info.link, qty = 0, cost = 0, gain = 0, ahQty = 0, vQty = 0, T = T }
    for _, l in ipairs(listings) do
      if not l.own then
        local u = l.unit
        local gA = T.ahMax and u <= T.ahMax and (T.ahNet - u) or nil
        local gV = T.vMax and u <= T.vMax and (T.vendor - u) or nil
        local g = math.max(gA or -1e12, gV or -1e12)
        if g <= 0 then
            r.stopAt = u
            break
        end
        local q = l.qty
        local toAH = not (gV and (not gA or gV >= gA))
        if toAH and T.maxQty then
            q = math.min(q, T.maxQty - r.ahQty)
            if q <= 0 then r.capHit = true break end
        end
        if budget and r.cost + u * q > budget then
            q = math.floor((budget - r.cost) / u)
            r.budgetHit = true
        end
        if q <= 0 then break end
        r.qty = r.qty + q
        r.cost = r.cost + u * q
        r.gain = r.gain + g * q
        if gV and (not gA or gV >= gA) then r.vQty = r.vQty + q else r.ahQty = r.ahQty + q end
        r.maxUnit = u
        if r.budgetHit then break end
      end
    end
    return r
end

local function PlaceOverlay(o)
    local s = ns.db.settings
    o:SetScale(s.flipOverlayScale or 1.15)
    o:ClearAllPoints()
    local pos = s.flipOverlayPos
    if pos then
        o:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
        return
    end
    -- rechts neben das AH, wenn dort Platz ist - sonst rechts in die Bildschirmmitte
    local ah = AuctionHouseFrame
    local fits = false
    pcall(function()
        fits = ah and ah:IsShown() and ah:GetRight() and UIParent:GetRight() and
            (ah:GetRight() * ah:GetEffectiveScale() + o:GetWidth() * o:GetEffectiveScale() + 20 < UIParent:GetRight() * UIParent:GetEffectiveScale())
    end)
    if fits then
        o:SetPoint("TOPLEFT", ah, "TOPRIGHT", 6, 0)
    else
        o:SetPoint("RIGHT", UIParent, "RIGHT", -80, 60)
    end
end

local function Overlay()
    if F.overlay then return F.overlay end
    local o = CreateFrame("Frame", "CBASFlipOverlay", UIParent, "BackdropTemplate")
    o:SetSize(360, 120)
    o:SetFrameStrata("DIALOG")
    o:SetClampedToScreen(true)
    o:SetMovable(true)
    o:EnableMouse(true)
    o:RegisterForDrag("LeftButton")
    o:SetScript("OnDragStart", o.StartMoving)
    o:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        ns.db.settings.flipOverlayPos = { p, rp, x, y }
    end)
    -- Strg + Mausrad = Groesse, Rechtsklick auf den Titel = zuruecksetzen
    o:EnableMouseWheel(true)
    o:SetScript("OnMouseWheel", function(self, d)
        if not IsControlKeyDown() then return end
        local s = ns.db.settings
        s.flipOverlayScale = math.max(0.8, math.min(2, (s.flipOverlayScale or 1.15) + d * 0.05))
        self:SetScale(s.flipOverlayScale)
    end)
    o:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            ns.db.settings.flipOverlayPos, ns.db.settings.flipOverlayScale = nil, nil
            PlaceOverlay(self)
        end
    end)
    if o.SetBackdrop then
        o:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        o:SetBackdropColor(0, 0, 0, 0.9)
    end
    local t = o:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("TOPLEFT", 10, -30)
    t:SetPoint("BOTTOMRIGHT", -10, 68)
    t:SetJustifyH("LEFT")
    t:SetJustifyV("TOP")
    t:SetSpacing(2)
    o.text = t
    local title = o:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -9)
    title:SetText("|cff33ccffCBAS Flipper|r  |cff666666(ziehen = verschieben, Strg+Rad = Größe)|r")
    o.title = title
    -- zwei Knoepfe: Kaufen-Schritt und Einstellen-Schritt (ein Klick = ein Schritt, wie die Tasten)
    local pb = CreateFrame("Button", nil, o, "UIPanelButtonTemplate")
    pb:SetSize(344, 30)
    pb:SetPoint("BOTTOM", 0, 34)
    pb:SetText("Autopilot")
    pb:SetScript("OnClick", function() if F.Pilot then F.Pilot() end end)
    o.pilot = pb
    local b = CreateFrame("Button", nil, o, "UIPanelButtonTemplate")
    b:SetSize(168, 22)
    b:SetPoint("BOTTOMLEFT", 8, 7)
    b:SetText("Kaufen: nächster Schritt")
    b:SetScript("OnClick", function() if F.Step then F.Step() end end)
    o.btn = b
    local sb = CreateFrame("Button", nil, o, "UIPanelButtonTemplate")
    sb:SetSize(168, 22)
    sb:SetPoint("BOTTOMRIGHT", -8, 7)
    sb:SetText("Einstellen")
    sb:SetScript("OnClick", function() if F.Stock then F.Stock.Step() end end)
    o.sellBtn = sb
    o:Hide()
    F.overlay = o
    if F.Snipe then F.Snipe.AttachButton(o) end
    return o
end

local function FillOverlay(o, L)
    if F.Stock and F.Stock.Hint then
        local h = F.Stock.Hint()
        if h then L[#L + 1] = " "; L[#L + 1] = h end
    end
    o.text:SetText(table.concat(L, "\n"))
    local lines = 0
    for _, l in ipairs(L) do lines = lines + 1 + math.floor(#l:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") / 52) end
    o:SetHeight(108 + lines * 15)
    if F.PilotText then o.pilot:SetText(F.PilotText()) end
    if F.StepButtonText then o.btn:SetText("Kaufen: " .. F.StepButtonText()) end
    if F.Stock and F.Stock.ButtonText then o.sellBtn:SetText(F.Stock.ButtonText()) end
    PlaceOverlay(o)
    o:Show()
end
F.FillOverlay = function(L) FillOverlay(Overlay(), L) end

function F.ShowBuyHelp(r)
    if ns.db.settings.flipAHHelp == false then return end
    local o = Overlay()
    local M = F.Money
    local L = { r.link or "" }
    if r.qty > 0 then
        L[#L + 1] = string.format("|cff40ff40%d Stück kaufen|r bis je %s", r.qty, M(r.maxUnit, true))
        L[#L + 1] = string.format("Kosten %s · Gewinn ca. |cff40ff40%s|r", M(r.cost, true), M(r.gain, true))
        local parts = {}
        if r.ahQty > 0 then parts[#parts + 1] = r.ahQty .. "× wieder ins AH" end
        if r.vQty > 0 then parts[#parts + 1] = r.vQty .. "× zum Händler" end
        L[#L + 1] = "|cff888888" .. table.concat(parts, " · ") .. "|r"
    else
        L[#L + 1] = "|cffff4040Gerade nichts unter deinem Kaufziel.|r"
    end
    if r.stopAt then L[#L + 1] = "|cffffd100Ab " .. M(r.stopAt, true) .. " nicht mehr kaufen.|r" end
    if r.budgetHit then L[#L + 1] = "|cffffd100Budget erreicht.|r" end
    if r.capHit then L[#L + 1] = "|cffffd100Höchstmenge erreicht (" .. (r.T.maxQty or 0) .. " Stück) - mehr verkauft sich nicht gut.|r" end
    if F.StepHint then
        L[#L + 1] = " "
        L[#L + 1] = F.StepHint()
    end
    if F.Snipe and F.Snipe.Status() then L[#L + 1] = F.Snipe.Status() end
    FillOverlay(o, L)
    -- Haendler-Flips aus dem AH beim naechsten Haendler automatisch verkaufen
    if r.vQty > 0 then F.MarkVendor(F.ItemID(r.link), true, true) end
end

-- Overlay nur mit dem Schritt-Hinweis (z.B. "nichts zu kaufen, weiter")
function F.ShowStepOnly(extra)
    if ns.db.settings.flipAHHelp == false then return end
    if not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then return end
    local o = Overlay()
    local L = {}
    if extra then L[#L + 1] = extra end
    if F.StepHint then L[#L + 1] = F.StepHint() end
    if F.Snipe and F.Snipe.Status() then L[#L + 1] = F.Snipe.Status() end
    FillOverlay(o, L)
end

local function OnCommodityResults(itemID)
    if not (C_AuctionHouse and C_AuctionHouse.GetNumCommoditySearchResults) then return end
    local n = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
    local list = {}
    for i = 1, math.min(n, 200) do
        local info = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
        if info and info.unitPrice and info.quantity then
            local q = info.quantity - math.min(info.quantity, info.numOwnerItems or 0)   -- eigene Stuecke zaehlen nicht
            list[#list + 1] = { unit = info.unitPrice, qty = q, own = q <= 0 }
        end
    end
    if F.Stock and F.Stock.OnResults(itemID, list, true) then return end
    local r = #list > 0 and F.EvaluateListings(itemID, list)
    F.cur = { id = itemID, commodity = true, r = r, list = list, t = GetTime() }
    if F.Snipe and F.Snipe.OnResults(itemID, r) then return end
    if r then F.ShowBuyHelp(r) elseif F.overlay then F.ShowStepOnly() end
end

local function OnItemResults(itemKey)
    if not (C_AuctionHouse and C_AuctionHouse.GetNumItemSearchResults) or type(itemKey) ~= "table" then return end
    local n = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
    local list = {}
    for i = 1, math.min(n, 200) do
        local info = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
        if info and info.buyoutAmount and info.buyoutAmount > 0 then
            local q = info.quantity or 1
            list[#list + 1] = { unit = info.buyoutAmount / q, qty = q, auctionID = info.auctionID, buyout = info.buyoutAmount,
                own = info.containsOwnerItem and true or false }
        end
    end
    if F.Stock and F.Stock.OnResults(itemKey.itemID, list, false) then return end
    local r = #list > 0 and F.EvaluateListings(itemKey.itemID, list)
    F.cur = { id = itemKey.itemID, commodity = false, r = r, list = list, t = GetTime() }
    if F.Snipe and F.Snipe.OnResults(itemKey.itemID, r) then return end
    if r then F.ShowBuyHelp(r) elseif F.overlay then F.ShowStepOnly() end
end

---------------------------------------------------------------------------
-- Haendler: markierte Haendler-Flips automatisch verkaufen
---------------------------------------------------------------------------
-- markiert einen Gegenstand fuer den automatischen Haendlerverkauf
function F.MarkVendor(id, on, silent)
    if not id then return end
    local d = F.db()
    d.vendorSell = d.vendorSell or {}
    local was = d.vendorSell[id]
    d.vendorSell[id] = on and true or nil
    if not silent and was ~= d.vendorSell[id] then
        local info = ItemInfo(id)
        ns.Print("Flipper: " .. ((info and info.link) or id) .. (on and " wird beim Händler automatisch verkauft." or " wird nicht mehr automatisch verkauft."))
    end
    if F.Refresh then F.Refresh() end
end

function F.IsVendorMarked(id)
    local d = F.db()
    return d.vendorSell and d.vendorSell[id] or false
end

function F.SellAtMerchant()
    if ns.db.settings.flipAutoVendor == false then return end
    local d = F.db()
    if not d.vendorSell or not next(d.vendorSell) then return end
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.UseContainerItem) then return end
    local todo = {}
    for bag = 0, 4 do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local it = C_Container.GetContainerItemInfo(bag, slot)
            if it and it.itemID and d.vendorSell[it.itemID] and not it.isLocked and not it.hasNoValue then
                todo[#todo + 1] = { bag = bag, slot = slot, id = it.itemID, count = it.stackCount or 1 }
            end
        end
    end
    if #todo == 0 then return end
    F.selling = true
    local total, n = 0, 0
    local function sellNext(i)
        if not F.selling or not (MerchantFrame and MerchantFrame:IsShown()) then F.selling = false return end
        local x = todo[i]
        if not x then
            F.selling = false
            ns.Print(string.format("Flipper: %d Stapel Händler-Flips verkauft für %s.", n, F.Money(total)))
            return
        end
        local it = C_Container.GetContainerItemInfo(x.bag, x.slot)
        if it and it.itemID == x.id then
            local info = ItemInfo(x.id)
            C_Container.UseContainerItem(x.bag, x.slot)
            total = total + ((info and info.sell) or 0) * (it.stackCount or 1)
            n = n + 1
        end
        C_Timer.After(0.15, function() sellNext(i + 1) end)
    end
    sellNext(1)
end

---------------------------------------------------------------------------
-- Im Auktionshaus suchen (nur per Klick, AH muss offen sein)
---------------------------------------------------------------------------
function F.SearchAH(names)
    if type(names) == "string" then names = { names } end
    if #names == 0 then return end
    if not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then
        ns.Print("Flipper: bitte zuerst das Auktionshaus öffnen.")
        return
    end
    if F.HasAuctionator() and type(Auctionator.API.v1.MultiSearchExact) == "function" then
        if pcall(Auctionator.API.v1.MultiSearchExact, CALLER, names) then return end
    end
    local bar = AuctionHouseFrame.SearchBar
    if bar and bar.SearchBox then
        bar.SearchBox:SetText(names[1])
        if bar.SearchButton and bar.SearchButton.Click then
            bar.SearchButton:Click()
        elseif bar.StartSearch then
            pcall(bar.StartSearch, bar)
        end
    end
end

---------------------------------------------------------------------------
-- Tooltip-Zeile fuer Gegenstaende
---------------------------------------------------------------------------
local function OnItemTooltip(tooltip, data)
    if not ns.db or ns.db.settings.flipTooltip == false then return end
    local link
    if tooltip.GetItem then
        local ok, _, l = pcall(tooltip.GetItem, tooltip)
        if ok then link = S(l) end
    end
    if not link then return end
    local p = F.Prices(link)
    if not p.ahMin and not p.market then return end
    local parts = {}
    if p.ahMin then parts[#parts + 1] = "AH " .. F.Money(p.ahMin, true) end
    if p.market and p.market ~= p.ahMin then parts[#parts + 1] = "Markt " .. F.Money(p.market, true) end
    local vf = F.VendorFlip(p)
    if vf and vf.profit and vf.profit > 0 then
        parts[#parts + 1] = "|cff40ff40Händler-Flip +" .. F.Money(vf.profit, true) .. "|r"
    end
    local af = F.AHFlip(p)
    if af and af.deal then
        parts[#parts + 1] = string.format("|cff40ff40AH-Flip +%.0f%%|r", af.pct or 0)
    end
    tooltip:AddLine("|cff33ccffCBAS Flip:|r " .. table.concat(parts, " · "), 1, 1, 1, true)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        F.db()
        if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
                pcall(OnItemTooltip, tt, data)
            end)
        end
        for _, e in ipairs({ "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED",
            "AUCTION_HOUSE_CLOSED", "MERCHANT_SHOW", "MERCHANT_CLOSED" }) do
            pcall(ev.RegisterEvent, ev, e)
        end
        -- nach Auctionator-Scans automatisch neu analysieren (falls Auctionator das anbietet)
        if F.HasAuctionator() and type(Auctionator.API.v1.RegisterForDBUpdate) == "function" then
            pcall(Auctionator.API.v1.RegisterForDBUpdate, CALLER, function()
                if not F.dbUpdateQueued then
                    F.dbUpdateQueued = true
                    C_Timer.After(10, function() F.dbUpdateQueued = false; pcall(F.Analyze, true) end)
                end
            end)
        end
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        pcall(OnCommodityResults, arg1)
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        pcall(OnItemResults, arg1)
    elseif event == "AUCTION_HOUSE_CLOSED" then
        if F.overlay then F.overlay:Hide() end
        F.Invalidate()
        -- nach dem AH-Besuch (evtl. neuer Scan) im Hintergrund neu analysieren
        local d = F.db()
        if not d.analyzed or time() - d.analyzed > 600 then C_Timer.After(2, function() pcall(F.Analyze, true) end) end
    elseif event == "MERCHANT_SHOW" then
        C_Timer.After(0.3, function() pcall(F.SellAtMerchant) end)
    elseif event == "MERCHANT_CLOSED" then
        F.selling = false
    end
end)
