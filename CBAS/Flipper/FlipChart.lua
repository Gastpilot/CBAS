-- CBAS - Flipper: Preisverlauf, Prognose und Gewinnverlauf als Diagramm
local ADDON, ns = ...
local F = ns.Flip
local C = {}
F.Chart = C

local W, H = 560, 170      -- Zeichenflaeche
local DAYS = 21            -- so viele Tage zurueck
local AHEAD = 3            -- Prognose-Tage
local WD = { "So", "Mo", "Di", "Mi", "Do", "Fr", "Sa" }

local function Create()
    if C.frame then return C.frame end
    local f = ns.T.Window("CBASChart")
    f:SetSize(W + 40, H + 270)
    f:SetPoint("CENTER", 120, 40)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "CBASChart")
    local t = type(f.TitleText) == "table" and f.TitleText or f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if t ~= f.TitleText then t:SetPoint("TOP", 0, -5) end
    f.title = t

    local area = CreateFrame("Frame", nil, f)
    area:SetPoint("TOPLEFT", 20, -58)
    area:SetSize(W, H)
    local bg = area:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.35)
    f.area = area
    f.bars, f.avail, f.labels, f.marks = {}, {}, {}, {}
    local slots = DAYS + AHEAD
    local bw = W / slots
    for i = 1, slots do
        local b = area:CreateTexture(nil, "ARTWORK")
        b:SetWidth(bw - 3)
        b:SetPoint("BOTTOMLEFT", (i - 1) * bw + 1, 0)
        f.bars[i] = b
        local a = area:CreateTexture(nil, "BORDER")
        a:SetWidth(bw - 3)
        a:SetPoint("BOTTOMLEFT", (i - 1) * bw + 1, 0)
        a:SetColorTexture(0.5, 0.5, 0.5, 0.35)
        f.avail[i] = a
        local mk = area:CreateTexture(nil, "BORDER")
        mk:SetWidth(2)
        mk:SetPoint("BOTTOMLEFT", (i - 1) * bw, 0)
        mk:SetHeight(H)
        mk:Hide()
        f.marks[i] = mk
        local l = area:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        l:SetPoint("TOP", area, "BOTTOMLEFT", (i - 0.5) * bw, -2)
        f.labels[i] = l
        -- Maus ueber Balken: Wert zeigen
        local hit = CreateFrame("Frame", nil, area)
        hit:SetPoint("BOTTOMLEFT", (i - 1) * bw, 0)
        hit:SetSize(bw, H)
        hit:EnableMouse(true)
        hit:SetScript("OnEnter", function(self)
            if not self.tip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        hit:SetScript("OnLeave", GameTooltip_Hide)
        b.hit = hit
    end
    local function HLine(r, g, b)
        local l = area:CreateTexture(nil, "OVERLAY")
        l:SetHeight(2)
        l:SetColorTexture(r, g, b, 0.9)
        local fs = area:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("BOTTOMRIGHT", l, "TOPRIGHT", 0, 1)
        l.fs = fs
        return l
    end
    f.medLine = HLine(1, 0.82, 0)
    f.buyLine = HLine(0.25, 1, 0.25)
    f.maxText = area:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.maxText:SetPoint("BOTTOMLEFT", area, "TOPLEFT", 0, 2)

    local info = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", area, "BOTTOMLEFT", 0, -20)
    info:SetPoint("TOPRIGHT", area, "BOTTOMRIGHT", 0, -20)
    info:SetJustifyH("LEFT")
    info:SetJustifyV("TOP")
    info:SetSpacing(2)
    f.info = info

    local pb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    pb:SetSize(130, 22)
    pb:SetPoint("BOTTOMLEFT", 14, 10)
    pb:SetText("Mein Gewinn")
    pb:SetScript("OnClick", function() C.ShowProfit() end)
    f:Hide()
    C.frame = f
    return f
end

local function ClearBars(f)
    for i = 1, #f.bars do
        f.bars[i]:Hide(); f.avail[i]:Hide(); f.labels[i]:SetText(""); f.bars[i].hit.tip = nil; f.marks[i]:Hide()
    end
    f.medLine:Hide(); f.medLine.fs:SetText("")
    f.buyLine:Hide(); f.buyLine.fs:SetText("")
end

local function YLine(line, value, maxV, text)
    if not value or value <= 0 or value > maxV then line:Hide(); line.fs:SetText("") return end
    line:ClearAllPoints()
    line:SetPoint("BOTTOMLEFT", 0, value / maxV * (H - 4))
    line:SetPoint("BOTTOMRIGHT", 0, value / maxV * (H - 4))
    line.fs:SetText(text)
    line:Show()
end

-- Preisverlauf eines Gegenstands
function C.Show(id)
    local f = Create()
    ClearBars(f)
    local info = F.ItemInfo(id)
    local link = info and info.link or id
    f.title:SetText("Preisverlauf: " .. (info and info.name or tostring(id)))
    local entry = F.EntryFor(id)
    local hist = F.HistoryOf(entry)
    local st = F.Stats(entry)
    local today = F.Today()
    local byDay, maxV, maxA = {}, 1, 1
    for _, h in ipairs(hist) do
        if h.day > today - DAYS then
            byDay[h.day] = h
            if h.price > maxV then maxV = h.price end
            if h.avail and h.avail > maxA then maxA = h.avail end
        end
    end
    local T = F.Targets(link, id)
    local ct = F.ClaudeTip(id)
    if st and st.forecast > maxV then maxV = st.forecast end
    if T.ahMax and T.ahMax > maxV then maxV = T.ahMax end
    maxV = maxV * 1.1
    local M = F.Money
    for i = 1, DAYS + AHEAD do
        local day = today - DAYS + i
        local b, a = f.bars[i], f.avail[i]
        local w = F.Weekday(day)
        if i % 3 == 1 or day == today then f.labels[i]:SetText(day == today and "heute" or WD[w]) end
        local mk = f.marks[i]
        local evName
        for _, ev in ipairs(F.Events()) do if ev.day == day then evName = ev.name end end
        if evName then
            mk:SetColorTexture(0.8, 0.3, 1, 0.9); mk:Show()
            f.labels[i]:SetText("|cffcc66ff" .. evName:sub(1, 6) .. "|r")
        elseif st and st.brk and st.brk.day == day then
            mk:SetColorTexture(1, 0.5, 0, 0.9); mk:Show()
            f.labels[i]:SetText(st.brk.kind == "step" and "|cffff8000Sprung|r" or "|cffff8000Wende|r")
        elseif w == F.ResetWeekday() then
            mk:SetColorTexture(0.3, 0.6, 1, 0.5); mk:Show()
            f.labels[i]:SetText("|cff4d99ffReset|r")
        end
        local h = byDay[day]
        if day <= today and h then
            b:SetHeight(math.max(2, h.price / maxV * (H - 4)))
            if day == today then b:SetColorTexture(0.2, 0.6, 1, 0.95) else b:SetColorTexture(0.85, 0.85, 0.85, 0.8) end
            b:Show()
            if h.avail then
                a:SetHeight(math.max(1, h.avail / maxA * H * 0.25))
                a:Show()
            end
            b.hit.tip = string.format("%s %s\nNiedrigster Preis: %s%s", WD[w], date("%d.%m.", F.DayDate(day)), M(h.price),
                h.avail and ("\nIm AH: " .. h.avail .. " Stück") or "")
        elseif day > today and st then
            -- Prognose (gestrichelt wirkt in WoW schlecht -> helle, transparente Balken)
            local fc = (ct and ct.forecast and ct.forecast[day - today]) or st.forecast * (st.weekday[w] or 1)
            b:SetHeight(math.max(2, fc / maxV * (H - 4)))
            b:SetColorTexture(1, 0.82, 0, 0.35)
            b:Show()
            b.hit.tip = string.format("Prognose %s %s: ca. %s", WD[w], date("%d.%m.", F.DayDate(day)), M(fc))
        end
    end
    f.maxText:SetText(M(maxV, true))
    if st then YLine(f.medLine, st.median, maxV, "Median " .. M(st.median, true)) end
    YLine(f.buyLine, T.ahMax, maxV, "Kauf bis " .. M(T.ahMax, true))

    -- Text
    local L = {}
    if st then
        local tr = st.slope * 100
        local trTxt = tr > 1.5 and ("|cff40ff40steigend (+" .. string.format("%.1f", tr) .. " %/Tag)|r")
            or (tr < -1.5 and ("|cffff4040fallend (" .. string.format("%.1f", tr) .. " %/Tag)|r") or "|cffffd100seitwärts|r")
        L[#L + 1] = string.format("|cffffd100Median:|r %s · |cffffd100Prognose in 3 Tagen:|r ca. %s · Schwankung %.0f %%",
            M(st.median), M(st.forecast), st.cv * 100)
        local function TT(s)
            if not s then return "|cff555555-|r" end
            local p = s * 100
            local col = p > 1.5 and "|cff40ff40" or (p < -1.5 and "|cffff4040" or "|cffffd100")
            return string.format("%s%+.1f%%|r", col, p)
        end
        L[#L + 1] = string.format("|cffffd100Trend pro Tag:|r 3 T %s · 7 T %s · 14 T %s · 21 T %s",
            TT(st.trends[3]), TT(st.trends[7]), TT(st.trends[14]), TT(st.trends[21]))
        local t3, t14 = st.trends[3], st.trends[14] or st.trends[7]
        if t3 and t14 and not st.brk and ((t3 > 0.015 and t14 < -0.015) or (t3 < -0.015 and t14 > 0.015)) then
            L[#L + 1] = "|cffff8000Kurzfristig dreht der Trend gegen den langfristigen - Breakpoint möglich.|r"
        end
        if st.brk and st.brk.kind == "step" then
            L[#L + 1] = string.format("|cffff8000Preissprung am %s %s:|r Niveau %s -> %s (%+.0f %%), seitdem %s/Tag. Gerechnet wird nur mit dem neuen Niveau - der 7/14-Tage-Trend enthält den Sprung und ist deshalb zu hoch/zu tief.",
                WD[F.Weekday(st.brk.day)], date("%d.%m.", F.DayDate(st.brk.day)),
                M(st.brk.levelBefore, true), M(st.brk.levelAfter, true), (st.brk.levelAfter / st.brk.levelBefore - 1) * 100, TT(st.brk.after))
        elseif st.brk then
            L[#L + 1] = string.format("|cffff8000Trendwende am %s %s:|r vorher %s/Tag, seitdem %s/Tag (Niveau %s -> %s)",
                WD[F.Weekday(st.brk.day)], date("%d.%m.", F.DayDate(st.brk.day)),
                TT(st.brk.before), TT(st.brk.after), M(st.brk.levelBefore, true), M(st.brk.levelAfter, true))
        end
        -- Raid-Woche
        local rd = F.ResetWeekday()
        local lo, hi
        for k, fac in pairs(st.raidWeek) do
            if not lo or fac < st.raidWeek[lo] then lo = k end
            if not hi or fac > st.raidWeek[hi] then hi = k end
        end
        if lo and hi and st.days >= 7 and st.raidWeek[hi] - st.raidWeek[lo] >= 0.04 then
            local function RW(k) return k == 0 and "am Reset-Tag" or (k == 6 and "1 Tag vor Reset" or (k .. " Tage nach Reset")) end
            L[#L + 1] = string.format("|cff4d99ffRaid-Woche (Reset %s):|r am billigsten %s (%+.0f %%), am teuersten %s (%+.0f %%)",
                WD[rd], RW(lo), (st.raidWeek[lo] - 1) * 100, RW(hi), (st.raidWeek[hi] - 1) * 100)
        end
        for _, ev in ipairs(st.events) do
            if ev.day > today then
                L[#L + 1] = string.format("|cffcc66ffEreignis %s|r am %s - in %d Tagen.", ev.name, date("%d.%m.", F.DayDate(ev.day)), ev.day - today)
            elseif ev.impact then
                L[#L + 1] = string.format("|cffcc66ffEreignis %s|r (%s): Preis danach %+.0f %% gegenüber vorher.", ev.name, date("%d.%m.", F.DayDate(ev.day)), ev.impact * 100)
            end
        end
        -- guenstigster / teuerster Wochentag
        lo, hi = nil, nil
        for w2, fac in pairs(st.weekday) do
            if not lo or fac < st.weekday[lo] then lo = w2 end
            if not hi or fac > st.weekday[hi] then hi = w2 end
        end
        if lo and hi and lo ~= hi and st.days >= 7 and st.weekday[hi] - st.weekday[lo] >= 0.04 then
            L[#L + 1] = string.format("|cffffd100Wochenmuster:|r am billigsten %s (%.0f %%), am teuersten %s (%+.0f %%) -> %s kaufen, %s einstellen",
                WD[lo], (st.weekday[lo] - 1) * 100, WD[hi], (st.weekday[hi] - 1) * 100, WD[lo], WD[hi])
        elseif st.days >= 7 then
            L[#L + 1] = "|cff888888Wochenmuster: kein deutlicher Unterschied zwischen den Wochentagen.|r"
        else
            L[#L + 1] = "|cff888888Wochenmuster: noch zu wenig Scan-Tage (" .. st.days .. ").|r"
        end
        local cur = byDay[today]
        if cur and T.ahMax then
            L[#L + 1] = cur.price <= T.ahMax and ("|cff40ff40Jetzt " .. M(cur.price) .. " - unter deinem Kaufziel " .. M(T.ahMax) .. ".|r")
                or ("Jetzt " .. M(cur.price) .. " - über dem Kaufziel " .. M(T.ahMax) .. ".")
        end
        if st.days < 5 then L[#L + 1] = "|cffffd100Vorsicht: Prognose beruht auf nur " .. st.days .. " Tagen.|r" end
    else
        L[#L + 1] = "|cff888888Zu wenig Verlauf - mindestens 3 Scan-Tage nötig.|r"
    end
    if ct and ct.reason then L[#L + 1] = "|cff66ccffClaude:|r " .. ct.reason end
    f.info:SetText(table.concat(L, "\n"))
    f.mode, f.id = "item", id
    f:Show()
end

-- Gewinnverlauf aus der Buchhaltung (Kaeufe aus dem Ablauf, Verkaeufe aus der Post)
function C.ShowProfit()
    local f = Create()
    ClearBars(f)
    f.title:SetText("Mein Flip-Gewinn (letzte " .. DAYS .. " Tage)")
    local d = F.db()
    local today = F.Today()
    local per = {}
    local buys, sells = 0, 0
    for _, e in ipairs(d.ledger or {}) do
        local day = F.Today() - math.floor((time() - e.t) / 86400)
        if day > today - DAYS then
            per[day] = per[day] or { buy = 0, sell = 0 }
            if e.kind == "buy" then per[day].buy = per[day].buy + (e.total or 0); buys = buys + (e.total or 0)
            elseif e.kind == "sell" then per[day].sell = per[day].sell + (e.total or 0); sells = sells + (e.total or 0) end
        end
    end
    local maxV = 1
    for _, p in pairs(per) do maxV = math.max(maxV, p.buy, p.sell) end
    maxV = maxV * 1.1
    local M = F.Money
    for i = 1, DAYS do
        local day = today - DAYS + i
        local p = per[day]
        local w = F.Weekday(day)
        if i % 3 == 1 or day == today then f.labels[i]:SetText(day == today and "heute" or WD[w]) end
        if p then
            local b, a = f.bars[i], f.avail[i]
            b:SetHeight(math.max(2, p.sell / maxV * (H - 4)))
            b:SetColorTexture(0.25, 1, 0.25, 0.85)
            b:Show()
            a:SetHeight(math.max(1, p.buy / maxV * (H - 4)))
            a:SetColorTexture(1, 0.3, 0.3, 0.45)
            a:Show()
            b.hit.tip = string.format("%s %s\nVerkauft: %s\nEingekauft: %s\nSaldo: %s", WD[w], date("%d.%m.", F.DayDate(day)),
                M(p.sell), M(p.buy), (p.sell - p.buy >= 0 and "+" or "-") .. M(math.abs(p.sell - p.buy)))
        end
    end
    f.maxText:SetText(M(maxV, true))
    local net = sells - buys
    f.info:SetText(string.format("|cff40ff40Grün|r = Verkaufserlöse (aus der AH-Post), |cffff4040rot|r = Einkäufe (über die Flip-Taste).\n" ..
        "Summe: verkauft %s · eingekauft %s · Saldo %s%s|r\n|cff888888Waren, die noch in deinen Taschen oder im AH liegen, sind im Saldo noch nicht enthalten.|r",
        M(sells), M(buys), net >= 0 and "|cff40ff40+" or "|cffff4040-", M(math.abs(net))))
    f.mode = "profit"
    f:Show()
end
