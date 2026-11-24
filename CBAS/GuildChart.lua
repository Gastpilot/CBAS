-- CBAS - GScout: Leistungskurve aller Gilden
-- Ansicht 1 "Alle Gilden": jede Gilde ein Balken, sortiert nach Leistungswert (0-100).
-- Ansicht 2 "Verlauf": Leistungswert der 10 besten Gilden ueber die Tage (wird ab jetzt taeglich gespeichert).
local ADDON, ns = ...
local GC = {}
ns.GuildChart = GC

local W, H = 680, 230
local MAXBARS = 200
local DAYS = 30
local COLORS = {   -- wie die Leistungs-Spalte
    top = { 1, 0.5, 0 }, strong = { 0.64, 0.21, 0.93 }, solid = { 0, 0.44, 0.87 }, low = { 0.5, 0.5, 0.5 },
}
local LINECOL = {
    { 1, 0.5, 0 }, { 0.64, 0.21, 0.93 }, { 0.2, 0.7, 1 }, { 0.3, 1, 0.3 },
    { 1, 0.9, 0.2 }, { 1, 0.35, 0.35 }, { 0.9, 0.9, 0.9 }, { 0.4, 1, 0.9 },
    { 1, 0.6, 0.85 }, { 0.6, 0.45, 0.25 },
}
local TOPN = 10

local function Today() return math.floor(time() / 86400) end

local function ColorFor(s)
    if s >= 70 then return COLORS.top elseif s >= 50 then return COLORS.strong elseif s >= 30 then return COLORS.solid end
    return COLORS.low
end

-- Leistungswerte einmal am Tag je Gilde merken (fuer den Verlauf)
function GC.Record()
    if not (ns.db and ns.db.guilds and ns.PerformanceScore) then return end
    local day = Today()
    for _, g in pairs(ns.db.guilds) do
        if not g.pseudo then
            g.sh = g.sh or {}
            if not g.sh[day] then
                local ok, s = pcall(ns.PerformanceScore, g)
                -- nur relevante Gilden speichern (haelt die Datei klein)
                if ok and s and (s >= 20 or next(g.sh)) then g.sh[day] = s end
            end
            for d in pairs(g.sh) do if d < day - 35 then g.sh[d] = nil end end
            if not next(g.sh) then g.sh = nil end
        end
    end
end

-- Veraenderung gegenueber vor ~7 Tagen
function GC.Delta(g, score)
    if not g.sh then return nil end
    local day = Today()
    local best
    for d, s in pairs(g.sh) do
        if d <= day - 5 and d >= day - 10 and (not best or d > best) then best = d end
    end
    return best and (score - g.sh[best]) or nil
end

local function Create()
    if GC.frame then return GC.frame end
    local f = CreateFrame("Frame", "CBASGuildChart", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(W + 40, H + 190)
    f:SetPoint("CENTER", 60, 30)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "CBASGuildChart")
    local t = type(f.TitleText) == "table" and f.TitleText or f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if t ~= f.TitleText then t:SetPoint("TOP", 0, -5) end
    f.title = t

    -- Umschalter
    local function Btn(text, w)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(w, 22)
        b:SetText(text)
        return b
    end
    f.bAll = Btn("Alle Gilden", 110)
    f.bAll:SetPoint("TOPLEFT", 16, -30)
    f.bAll:SetScript("OnClick", function() GC.mode = "all"; GC.Update() end)
    f.bHist = Btn("Verlauf (Top 10)", 130)
    f.bHist:SetPoint("LEFT", f.bAll, "RIGHT", 6, 0)
    f.bHist:SetScript("OnClick", function() GC.mode = "hist"; GC.Update() end)
    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", f.bHist, "RIGHT", 12, 0)
    hint:SetText("Es gelten die Filter der GScout-Liste (Rekrutiert, Fraktion, Instanz ...)")

    local area = CreateFrame("Frame", nil, f)
    area:SetPoint("TOPLEFT", 26, -78)
    area:SetSize(W - 10, H)
    local bg = area:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.35)
    f.area = area
    -- Hilfslinien 30 / 50 / 70
    f.grid = {}
    for _, v in ipairs({ { 30, "solide" }, { 50, "stark" }, { 70, "Top" } }) do
        local l = area:CreateTexture(nil, "BORDER")
        l:SetHeight(1)
        l:SetColorTexture(1, 1, 1, 0.18)
        l:SetPoint("BOTTOMLEFT", 0, v[1] / 100 * H)
        l:SetPoint("BOTTOMRIGHT", 0, v[1] / 100 * H)
        local fs = area:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetPoint("BOTTOMRIGHT", area, "BOTTOMLEFT", -3, v[1] / 100 * H - 5)
        fs:SetText(v[1])
        local fs2 = area:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        fs2:SetPoint("BOTTOMRIGHT", l, "TOPRIGHT", -2, 1)
        fs2:SetText(v[2])
    end
    f.bars, f.dots, f.lines, f.legend = {}, {}, {}, {}

    local info = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", area, "BOTTOMLEFT", -6, -22)
    info:SetPoint("TOPRIGHT", area, "BOTTOMRIGHT", 0, -22)
    info:SetJustifyH("LEFT")
    info:SetJustifyV("TOP")
    info:SetSpacing(2)
    f.info = info
    f.xlabel = area:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.xlabel:SetPoint("TOP", area, "BOTTOM", 0, -4)
    f:Hide()
    GC.frame = f
    return f
end

local function Bar(f, i)
    local b = f.bars[i]
    if b then return b end
    b = CreateFrame("Button", nil, f.area)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("BOTTOMLEFT")
    b.tex:SetPoint("BOTTOMRIGHT")
    b.rec = b:CreateTexture(nil, "OVERLAY")
    b.rec:SetColorTexture(0.25, 1, 0.25, 1)
    b.rec:SetHeight(3)
    b.rec:SetPoint("BOTTOMLEFT", b.tex, "TOPLEFT", 0, 1)
    b.rec:SetPoint("BOTTOMRIGHT", b.tex, "TOPRIGHT", 0, 1)
    b:SetScript("OnEnter", function(self) GC.Tooltip(self, self.e) end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", function(self) GC.SelectGuild(self.e and self.e.key) end)
    f.bars[i] = b
    return b
end

function GC.Tooltip(owner, e)
    if not e then return end
    local g = e.g
    local s, label, parts, unsure = ns.PerformanceScore(g)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:AddLine("<" .. g.name .. ">", 1, 0.82, 0)
    GameTooltip:AddLine(string.format("Leistung %d (%s)%s - Platz %d von %d", s, label, unsure and ", wenig Daten" or "", e.rank, e.of), 1, 1, 1)
    local dlt = GC.Delta(g, s)
    if dlt then GameTooltip:AddLine(string.format("Veränderung seit ca. 1 Woche: %+d", dlt), dlt >= 0 and 0.3 or 1, dlt >= 0 and 1 or 0.3, 0.3) end
    for _, p in ipairs(parts or {}) do
        GameTooltip:AddDoubleLine(p.name .. ": " .. p.txt, string.format("%d/%d", math.floor(p.v + 0.5), p.max), 0.8, 0.8, 0.8, 1, 1, 1)
    end
    local loot = ns.LootShort and ns.LootShort(g)
    if loot and loot ~= "" then GameTooltip:AddLine("Loot: " .. loot, 0.7, 0.9, 1) end
    GameTooltip:AddLine(ns.IsRecruiting(g) and "|cff40ff40Rekrutiert gerade|r" or "|cff888888keine aktuelle Rekrutierung|r")
    GameTooltip:AddLine("Klick = in der GScout-Liste auswählen", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

function GC.SelectGuild(key)
    local UI = ns.UI
    if not key or not UI then return end
    UI.selected = key
    for i, e in ipairs(UI.list or {}) do
        if e.key == key then UI.offset = math.max(0, i - 3) end
    end
    if UI.Refresh then UI:Refresh() end
    if UI.UpdateDetail then UI:UpdateDetail() end
end

-- Daten: die Gilden der aktuellen GScout-Liste (mit Filtern), nach Leistung sortiert
local function Entries()
    local UI = ns.UI
    if UI and UI.Refresh and (not UI.list or #UI.list == 0) then pcall(UI.Refresh, UI) end
    local l = {}
    for _, e in ipairs((UI and UI.list) or {}) do
        if not e.g.pseudo then
            local ok, s, _, _, unsure = pcall(ns.PerformanceScore, e.g)
            if ok then l[#l + 1] = { key = e.key, g = e.g, s = s, unsure = unsure } end
        end
    end
    table.sort(l, function(a, b) if a.s == b.s then return a.g.name < b.g.name end return a.s > b.s end)
    for i, e in ipairs(l) do e.rank, e.of = i, #l end
    return l
end

local function HideAll(f)
    for _, b in ipairs(f.bars) do b:Hide() end
    for _, d in ipairs(f.dots) do d:Hide() end
    for _, l in ipairs(f.lines) do l:Hide() end
    for _, l in ipairs(f.legend) do l:Hide() end
end

local function ShowAll(f, l)
    local n = math.min(#l, MAXBARS)
    local bw = n > 0 and (W - 10) / n or 1
    for i = 1, n do
        local e = l[i]
        local b = Bar(f, i)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", (i - 1) * bw, 0)
        b:SetSize(math.max(1, bw), H)
        b.tex:SetWidth(math.max(1, bw - (bw > 4 and 1 or 0)))
        b.tex:SetHeight(math.max(2, e.s / 100 * H))
        local c = ColorFor(e.s)
        b.tex:SetColorTexture(c[1], c[2], c[3], e.unsure and 0.4 or 0.9)
        b.rec:SetShown(ns.IsRecruiting(e.g) and true or false)
        b.e = e
        b:Show()
    end
    f.xlabel:SetText(n < #l and string.format("die besten %d von %d Gilden", n, #l) or (#l .. " Gilden, links die beste"))
    -- Zusammenfassung
    local top, strong, solid, unsure = 0, 0, 0, 0
    local rec = {}
    for _, e in ipairs(l) do
        if e.s >= 70 then top = top + 1 elseif e.s >= 50 then strong = strong + 1 elseif e.s >= 30 then solid = solid + 1 end
        if e.unsure then unsure = unsure + 1 end
        if e.s >= 50 and ns.IsRecruiting(e.g) and #rec < 6 then rec[#rec + 1] = string.format("%s (%d)", e.g.name, e.s) end
    end
    local L = {}
    L[#L + 1] = string.format("|cffff8000Top (70+): %d|r · |cffa335eestark (50+): %d|r · |cff0070ddsolide (30+): %d|r · |cff888888darunter: %d|r · blass = wenig Daten (%d)",
        top, strong, solid, #l - top - strong - solid, unsure)
    L[#L + 1] = "|cff40ff40Grüner Strich|r über dem Balken = rekrutiert gerade. Maus über einen Balken = Details, Klick = Gilde in der Liste öffnen."
    L[#L + 1] = #rec > 0 and ("|cff40ff40Starke Gilden, die gerade rekrutieren:|r " .. table.concat(rec, ", "))
        or "|cff888888Gerade keine starke Gilde (50+) mit aktueller Rekrutierung.|r"
    f.info:SetText(table.concat(L, "\n"))
end

local function Line(f, i)
    local l = f.lines[i]
    if l then return l end
    if f.area.CreateLine then
        local ok, ln = pcall(f.area.CreateLine, f.area, nil, "ARTWORK")
        if ok and ln and ln.SetThickness then ln:SetThickness(2); l = ln end
    end
    if not l then
        l = f.area:CreateTexture(nil, "ARTWORK")   -- Ersatz: nur Punkte
        l:SetSize(3, 3)
    end
    f.lines[i] = l
    return l
end

local function ShowHist(f, l)
    local today = Today()
    local n = math.min(TOPN, #l)
    local lineN = 0
    local anyHist = false
    for gi = 1, n do
        local e = l[gi]
        local c = LINECOL[gi]
        local prevX, prevY
        for d = today - DAYS + 1, today do
            local s = e.g.sh and e.g.sh[d]
            if d == today then s = e.s end
            if s then
                local x = (d - (today - DAYS + 1)) / (DAYS - 1) * (W - 20) + 5
                local y = s / 100 * (H - 4) + 2
                if prevX then
                    anyHist = true
                    lineN = lineN + 1
                    local ln = Line(f, lineN)
                    ln:SetColorTexture(c[1], c[2], c[3], 0.95)
                    if ln.SetStartPoint then
                        ln:SetStartPoint("BOTTOMLEFT", f.area, prevX, prevY)
                        ln:SetEndPoint("BOTTOMLEFT", f.area, x, y)
                    else
                        ln:ClearAllPoints()
                        ln:SetPoint("CENTER", f.area, "BOTTOMLEFT", x, y)
                    end
                    ln:Show()
                end
                lineN = lineN + 1
                local dot = Line(f, lineN)
                if dot.SetStartPoint then   -- Punkt als kurze Linie
                    dot:SetStartPoint("BOTTOMLEFT", f.area, x - 2, y)
                    dot:SetEndPoint("BOTTOMLEFT", f.area, x + 2, y)
                else
                    dot:ClearAllPoints()
                    dot:SetPoint("CENTER", f.area, "BOTTOMLEFT", x, y)
                end
                dot:SetColorTexture(c[1], c[2], c[3], 1)
                dot:Show()
                prevX, prevY = x, y
            end
        end
        local lg = f.legend[gi]
        if not lg then
            lg = f.area:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            f.legend[gi] = lg
        end
        lg:ClearAllPoints()
        lg:SetPoint("TOPLEFT", f.area, "TOPLEFT", 6 + ((gi - 1) % 5) * 132, -4 - math.floor((gi - 1) / 5) * 13)
        lg:SetText(string.format("|cff%02x%02x%02x%s|r %d", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255), e.g.name, e.s))
        lg:Show()
    end
    f.xlabel:SetText(string.format("letzte %d Tage (heute rechts)", DAYS))
    local L = {}
    if not anyHist then
        L[#L + 1] = "|cffffd100Der Verlauf beginnt jetzt:|r CBAS speichert ab heute einmal am Tag den Leistungswert jeder Gilde. " ..
            "Nach ein paar Tagen siehst du hier, welche Gilden besser werden (Progress, mehr 60er, bessere Ausrüstung) und welche nachlassen."
    else
        -- Aufsteiger/Absteiger der Woche
        local ups = {}
        for _, e in ipairs(l) do
            local dlt = GC.Delta(e.g, e.s)
            if dlt and dlt ~= 0 then ups[#ups + 1] = { e = e, d = dlt } end
        end
        table.sort(ups, function(a, b) return a.d > b.d end)
        local u, dn = {}, {}
        for i = 1, math.min(5, #ups) do if ups[i].d > 0 then u[#u + 1] = string.format("%s %+d", ups[i].e.g.name, ups[i].d) end end
        for i = #ups, math.max(1, #ups - 4), -1 do if ups[i].d < 0 then dn[#dn + 1] = string.format("%s %+d", ups[i].e.g.name, ups[i].d) end end
        L[#L + 1] = "|cff40ff40Aufsteiger (ca. 1 Woche):|r " .. (#u > 0 and table.concat(u, ", ") or "-")
        L[#L + 1] = "|cffff4040Absteiger:|r " .. (#dn > 0 and table.concat(dn, ", ") or "-")
    end
    f.info:SetText(table.concat(L, "\n"))
end

function GC.Update()
    local f = Create()
    HideAll(f)
    local l = Entries()
    if GC.mode == "hist" then f.bHist:LockHighlight(); f.bAll:UnlockHighlight() else f.bAll:LockHighlight(); f.bHist:UnlockHighlight() end
    f.title:SetText("GScout - Leistungskurve")
    if #l == 0 then
        f.info:SetText("|cff888888Keine Gilden in der Liste (Filter prüfen).|r")
        f.xlabel:SetText("")
        return
    end
    if GC.mode == "hist" then ShowHist(f, l) else ShowAll(f, l) end
end

function GC.Toggle()
    local f = Create()
    if f:IsShown() then f:Hide() return end
    pcall(GC.Record)
    GC.mode = GC.mode or "all"
    f:Show()
    GC.Update()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function() pcall(GC.Record) end)
