-- CBAS - Startseite "Lage": eine Tafel wie am Bahnhof.
-- Oben steht, wo du gerade bist. Darunter die Zeilen, die JETZT zaehlen - nach Wichtigkeit sortiert:
-- in der Gruppe die Mitspieler, am Auktionshaus die Tipps und der naechste Autopilot-Schritt,
-- sonst Gilden, Layer und Update. Ein Klick auf eine Zeile oeffnet das passende Modul.
-- Leichtgewichtig: rechnet nur, wenn die Seite offen ist (alle 5 s), Zaehlungen 30 s zwischengespeichert.
local ADDON, ns = ...
local H = {}
ns.Home = H

local ROWS, ROW_H = 7, 52
local W = 828                      -- nutzbare Breite (Panel 860 - Raender)
local unpack = unpack or table.unpack

local function T() return ns.T end
local function Hx(k) return ns.T.HEX[k] end

local function Ago(t)
    if not t then return "?" end
    return ns.Ago and ns.Ago(t) or (math.floor((time() - t) / 60) .. " Min.")
end

local function AHOpen()
    return (AuctionHouseFrame and AuctionHouseFrame:IsShown()) or (AuctionFrame and AuctionFrame:IsShown()) or false
end

local function InGroup() return IsInGroup and IsInGroup() end

---------------------------------------------------------------------------
-- Zeilen der Tafel: jede liefert { prio, state, cat, title, detail, target, cat2 }
-- state: "bad" | "warn" | "ok" | "info" | "idle"
---------------------------------------------------------------------------
local function GroupRow()
    if not InGroup() then
        return { prio = 10, state = "idle", cat = "Gruppe", title = "Keine Gruppe",
            detail = "Geierwacht und Can I have it springen an, sobald du in einer Gruppe bist.", target = "geier" }
    end
    local GW = ns.Geier
    local geier, frag = {}, {}
    if ns.LFGInfo and ns.LFGInfo.GeierStats then geier, frag = ns.LFGInfo.GeierStats() end
    local bad, warn, n, notes = 0, 0, 0, {}
    for _, unit in ipairs((GW and GW.GroupUnits()) or {}) do
        if unit ~= "player" and UnitExists(unit) then
            local nm, rl = UnitName(unit)
            nm, rl = ns.S(nm), ns.S(rl)
            if nm then
                n = n + 1
                local full = ns.NormFull(ns.FullName(nm, rl))
                local why
                local key = ns.db.players[full]
                local g = key and ns.db.guilds[key]
                local mark = GW and GW.db().marked and GW.db().marked[full]
                if g and g.blacklist then why = "Blacklist-Gilde"
                elseif mark then why = "markiert" .. (type(mark) == "table" and mark.note and (": " .. mark.note) or "")
                elseif geier[full] then why = geier[full] .. "x Geier-Bedarf" end
                if why then
                    bad = bad + 1
                    notes[#notes + 1] = Hx("bad") .. full .. "|r " .. Hx("dim") .. "(" .. why .. ")|r"
                elseif frag[full] then
                    warn = warn + 1
                    notes[#notes + 1] = Hx("warn") .. full .. "|r " .. Hx("dim") .. "(" .. frag[full] .. "x fragwürdig)|r"
                end
            end
        end
    end
    local run = GW and GW.CurrentRun and GW.CurrentRun()
    local where = run and GW.RunTitle and GW.RunTitle(run)
    local r = { cat = IsInRaid and IsInRaid() and "Raid" or "Gruppe", target = "geier" }
    if bad > 0 then
        r.prio, r.state = 320, "bad"
        r.title = string.format("%d von %d Mitspielern auffällig", bad, n)
    elseif warn > 0 then
        r.prio, r.state = 260, "warn"
        r.title = string.format("%d Mitspieler mit fragwürdigem Bedarf", warn)
    else
        r.prio, r.state = 200, "ok"
        r.title = string.format("Gruppe sauber – %d Mitspieler geprüft", n)
        notes[1] = "Niemand auf der Blacklist, keine Geier bekannt" .. (where and (" · " .. where) or "") .. "."
    end
    r.detail = table.concat(notes, "  ·  ")
    return r
end

local tipCache = { t = 0 }
local function TipCount(c)
    if tipCache.c == c and GetTime() - tipCache.t < 30 then return tipCache.n end
    local n = 0
    for _ in pairs(type(c.items) == "table" and c.items or {}) do n = n + 1 end
    tipCache.c, tipCache.t, tipCache.n = c, GetTime(), n
    return n
end

local function AHRow()
    local F = ns.Flip
    if not F then return nil end
    local open = AHOpen()
    local c, fresh = F.Claude()
    local r = { cat = "Auktionshaus", target = "flipper", prio = open and 400 or 70 }
    if not c then
        r.state, r.title = "idle", "Keine Claude-Tipps geladen"
        r.detail = "Tipps entstehen aus deinen Auctionator-Scans. Der Flipper rechnet trotzdem mit eigenen Daten."
    elseif not fresh then
        r.state, r.title = "warn", "Tipps sind älter als 3 Tage"
        r.detail = "Stand vor " .. Ago(c.generated) .. ". Veraltete Tipps werden ignoriert – neue Auswertung anfordern."
    else
        r.state = "ok"
        r.title = string.format("%d Kauf-Tipps bereit", TipCount(c))
        r.detail = "Stand vor " .. Ago(c.generated) .. (c.summary and c.summary.text and (" · " .. c.summary.text) or "")
    end
    if open then
        r.title = "Am Auktionshaus: " .. r.title
        if F.StepHint then
            local ok, hint = pcall(F.StepHint)
            if ok and hint then r.detail = hint end
        end
    end
    return r
end

local function CIHIRow()
    local CI = ns.CanIHave
    if not CI then return nil end
    local _, list = CI.db()
    local e = list and list[1]
    if not e or not e.link then return nil end
    local recent = time() - (e.t or 0) < 900
    return {
        prio = (recent and InGroup()) and 280 or 30,
        state = (e.state == "need") and "ok" or ((e.state == "no") and "bad" or "warn"),
        cat = "Can I have it",
        title = (CI.STATE_TXT[e.state] or "Geprüft") .. "  " .. e.link,
        detail = (e.why and e.why ~= "" and e.why or "Letzte Prüfung") .. Hx("dim") .. " · vor " .. Ago(e.t) .. "|r",
        target = "cihi",
    }
end

local gsCache = { t = -100 }
local function GScoutRow()
    if GetTime() - gsCache.t > 30 then
        local now = time()
        local total, recruit, new = 0, 0, 0
        for _, g in pairs(ns.db.guilds) do
            total = total + 1
            if g.recruit and (g.recruit.last or 0) > now - 30 * 86400 then recruit = recruit + 1 end
            if (g.firstSeen or 0) > now - 86400 then new = new + 1 end
        end
        gsCache = { t = GetTime(), total = total, recruit = recruit, new = new }
    end
    local c = gsCache
    return {
        prio = 90, state = c.new > 0 and "info" or "idle", cat = "Gilden",
        title = string.format("%d %s  ·  %d %s gerade", c.total, c.total == 1 and "Gilde" or "Gilden",
            c.recruit, c.recruit == 1 and "rekrutiert" or "rekrutieren"),
        detail = (c.new > 0 and (Hx("accent") .. c.new .. " neu seit gestern|r · ") or "") .. "Suchen, filtern und scannen im GScout.",
        target = "gscout",
    }
end

local function LayerRow()
    local L = ns.Layer
    if not L then return nil end
    local lines = L.PeerLines and L:PeerLines() or {}
    local r = { prio = 85, state = "info", cat = "Layer", target = "settings", cat2 = "layer" }
    if L.cur then
        r.title = "Layer " .. L.Label(L.cur) .. Hx("dim") .. "  ·  " .. (L.cur.zone or "") .. "|r"
    else
        r.title, r.state = "Layer noch unbekannt", "idle"
    end
    if #lines > 0 then
        r.detail = table.concat(lines, "  ·  ", 1, math.min(#lines, 3))
    else
        r.detail = L.cur and "Keine Layer-Partner eingetragen – Klick zum Eintragen."
            or "Wird erkannt, sobald du einen NPC anvisierst. /who sieht nur deinen Layer."
    end
    return r
end

local function UpdateRow()
    local V = ns.Version
    local newer = V and V.Latest()
    if newer then
        return { prio = 240, state = "warn", cat = "Update", title = "Neue Version " .. newer .. " verfügbar",
            detail = "Du hast " .. ns.VERSION .. ". Klick zeigt den Download-Link zum Kopieren.", target = "settings", cat2 = "general" }
    end
    return { prio = 5, state = "ok", cat = "Version", title = "CBAS " .. ns.VERSION .. " ist aktuell",
        detail = "Andere CBAS-Spieler in Gilde und Gruppe melden neue Versionen automatisch.", target = "settings", cat2 = "general" }
end

-- Mage-Dienste: wartende Kunden ganz oben, sonst Einnahmen und Vorrat (nur auf Magiern)
local function MageRow()
    local MG = ns.Mage
    if not (MG and MG.IsMage()) then return nil end
    MG.Prune()
    local open = {}
    for _, c in ipairs(MG.customers) do if c.state ~= "done" then open[#open + 1] = c end end
    local r = { cat = "Mage-Dienste", target = "mage" }
    if #open > 0 then
        r.prio, r.state = 330, "warn"
        r.title = #open == 1 and "1 Kunde wartet" or (#open .. " Kunden warten")
        local t = {}
        for i = 1, math.min(3, #open) do
            local c = open[i]
            local what = c.kind == "port" and ("Portal" .. (c.dest and (" " .. c.dest:upper()) or "")) or (c.kind == "food" and "Essen" or "Wasser")
            t[#t + 1] = c.full .. Hx("dim") .. " (" .. what .. ")|r"
        end
        r.detail = table.concat(t, "  ·  ") .. Hx("dim") .. "  –  Autopilot-Taste drücken|r"
        return r
    end
    local g, n = MG.Today()
    local st = MG.Stock()
    r.prio, r.state = 60, n > 0 and "ok" or "info"
    r.title = n > 0 and ("Heute " .. MG.Money(g) .. " aus " .. n .. (n == 1 and " Verkauf" or " Verkäufen")) or "Bereit für Kunden"
    r.detail = string.format("Wasser %.1f Stacks · Essen %.1f Stacks", st.water / MG.STACK, st.food / MG.STACK)
        .. (#st.portals > 0 and (" · Runen " .. st.runes) or "") .. " · Kunden erscheinen hier automatisch."
    return r
end

-- Verbundene Addons: was CBAS nutzt und ob etwas fehlt
local function Loaded(name)
    local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if not f then return false end
    local ok, v = pcall(f, name)
    return ok and v and true or false
end
H.Loaded = Loaded

local function AddonsRow()
    local F = ns.Flip
    local atr = F and F.HasAuctionator and F.HasAuctionator() or Loaded("Auctionator")
    local tsm = F and F.HasTSM and F.HasTSM() or Loaded("TradeSkillMaster")
    local lfg = Loaded("LFGForever")
    local parts, have = {}, 0
    local function add(ok, name, use)
        if ok then have = have + 1 end
        parts[#parts + 1] = (ok and "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t " .. Hx("ok") or "|TInterface\\RaidFrame\\ReadyCheck-NotReady:12|t " .. Hx("dim")) .. name .. "|r" .. Hx("dim") .. " " .. use .. "|r"
    end
    add(atr, "Auctionator", "(Preise, Tipps)")
    add(tsm, "TSM", "(Preise)")
    add(lfg, "LFGForever", "(Gruppensuche)")
    local r = { cat = "Addons", target = "flipper" }
    if not atr and not tsm then
        r.prio, r.state = 150, "warn"
        r.title = "Kein Preis-Addon aktiv"
        r.detail = "Der Flipper braucht Auctionator oder TSM für Preise.  " .. table.concat(parts, "  ")
    else
        r.prio, r.state = 20, "ok"
        r.title = have .. " von 3 verbunden"
        r.detail = table.concat(parts, "   ")
    end
    return r
end

local SOURCES = { GroupRow, AHRow, MageRow, CIHIRow, GScoutRow, LayerRow, UpdateRow, AddonsRow }

function H.Collect()
    local list = {}
    for _, fn in ipairs(SOURCES) do
        local ok, r = pcall(fn)
        if ok and r then list[#list + 1] = r end
    end
    table.sort(list, function(a, b) return a.prio > b.prio end)
    return list
end

-- Kopfzeile der Tafel: wo bist du gerade?
function H.Where()
    local zone = (GetRealZoneText and ns.S(GetRealZoneText())) or ""
    local what
    if AHOpen() then what = "Am Auktionshaus"
    elseif IsInRaid and IsInRaid() then what = "Im Raid"
    elseif InGroup() then what = "In der Gruppe"
    elseif IsInInstance and IsInInstance() then what = "In einer Instanz"
    else what = "Unterwegs" end
    local bits = {}
    if zone ~= "" then bits[#bits + 1] = zone end
    if ns.Layer and ns.Layer.cur then bits[#bits + 1] = "Layer " .. ns.Layer.Label(ns.Layer.cur) end
    if ns.Layer then bits[#bits + 1] = ns.Layer.World() end
    return what, table.concat(bits, "  ·  ")
end

---------------------------------------------------------------------------
-- Oberflaeche
---------------------------------------------------------------------------
local COLORS
local function StateColor(s)
    local C = ns.T.C
    COLORS = COLORS or { bad = C.bad, warn = C.warn, ok = C.ok, info = C.accent, idle = { 0.35, 0.36, 0.40 } }
    return COLORS[s] or COLORS.idle
end

local function OpenTarget(r)
    if not r or not r.target then return end
    if r.cat2 then
        ns.db.settings.lastSettingsCat = r.cat2
        if ns.Settings and ns.Settings.panel then ns.Settings.SelectCat(r.cat2) end
    end
    ns.Suite:Select(r.target)
end

local function MakeRow(p, i)
    local C = T().C
    local b = CreateFrame("Button", nil, p)
    b:SetSize(W, ROW_H - 2)
    b:SetPoint("TOPLEFT", 16, -132 - (i - 1) * ROW_H)
    local hl = b:CreateTexture(nil, "BACKGROUND")
    hl:SetTexture(T().WHITE)
    hl:SetAllPoints()
    hl:SetVertexColor(1, 1, 1, 0)
    b.hl = hl
    local bar = b:CreateTexture(nil, "ARTWORK")
    bar:SetTexture(T().WHITE)
    bar:SetWidth(3)
    bar:SetPoint("TOPLEFT", 0, -6)
    bar:SetPoint("BOTTOMLEFT", 0, 6)
    b.bar = bar
    local cat = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cat:SetPoint("TOPLEFT", 18, -14)
    cat:SetWidth(120)
    cat:SetJustifyH("LEFT")
    b.cat = cat
    local title = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 150, -11)
    title:SetPoint("RIGHT", -110, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    b.title = title
    local det = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    det:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    det:SetPoint("RIGHT", -110, 0)
    det:SetJustifyH("LEFT")
    det:SetWordWrap(false)
    det:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    b.det = det
    local go = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    go:SetPoint("RIGHT", -16, 0)
    go:SetText("Öffnen  ›")
    go:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    b.go = go
    local line = b:CreateTexture(nil, "BORDER")
    line:SetTexture(T().WHITE)
    line:SetVertexColor(unpack(C.line))
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 0, -1)
    line:SetPoint("BOTTOMRIGHT", 0, -1)
    b:SetScript("OnEnter", function(s)
        s.hl:SetVertexColor(1, 1, 1, 0.04)
        s.go:SetTextColor(C.accentHi[1], C.accentHi[2], C.accentHi[3])
        if s.r and s.r.detail and s.det:IsTruncated() then
            GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
            GameTooltip:SetText(s.r.title, 1, 1, 1, 1, true)
            GameTooltip:AddLine(s.r.detail, C.dim[1], C.dim[2], C.dim[3], true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(s)
        s.hl:SetVertexColor(1, 1, 1, 0)
        s.go:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
        GameTooltip_Hide()
    end)
    b:SetScript("OnClick", function(s) OpenTarget(s.r) end)
    b:Hide()
    return b
end

function H:Create(p)
    if self.panel then return end
    self.panel = p
    local C = T().C
    -- "Jetzt"-Streifen
    local now = T().Card(p)
    now:SetPoint("TOPLEFT", 16, -36)
    now:SetSize(W, 64)
    self.now = now
    local glow = now:CreateTexture(nil, "ARTWORK")
    glow:SetTexture(T().WHITE)
    glow:SetSize(16, 16)
    glow:SetPoint("LEFT", 20, 0)
    glow:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.25)
    self.glow = glow
    local dot = now:CreateTexture(nil, "OVERLAY")
    dot:SetTexture(T().WHITE)
    dot:SetSize(8, 8)
    dot:SetPoint("CENTER", glow, "CENTER")
    dot:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
    self.dot = dot
    local what = now:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    what:SetPoint("TOPLEFT", 50, -12)
    what:SetTextColor(1, 1, 1)
    self.what = what
    local where = now:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    where:SetPoint("TOPLEFT", what, "BOTTOMLEFT", 0, -4)
    where:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    self.where = where
    local clock = now:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    clock:SetPoint("RIGHT", -20, 6)
    clock:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    self.clock = clock
    local sum = now:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sum:SetPoint("TOPRIGHT", clock, "BOTTOMRIGHT", 0, -4)
    self.sum = sum

    -- Spaltenkoepfe wie auf der Abfahrtstafel
    local function colHead(text, x)
        local fs = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetPoint("TOPLEFT", 16 + x, -114)
        fs:SetText(ns.T.Upper(text))
        fs:SetTextColor(C.dim[1], C.dim[2], C.dim[3], 0.8)
        return fs
    end
    colHead("Bereich", 18)
    colHead("Was gerade zählt", 150)
    local hl = p:CreateTexture(nil, "BORDER")
    hl:SetTexture(T().WHITE)
    hl:SetVertexColor(unpack(C.lineHi))
    hl:SetHeight(1)
    hl:SetPoint("TOPLEFT", 16, -128)
    hl:SetPoint("TOPRIGHT", -16, -128)

    self.rows = {}
    for i = 1, ROWS do self.rows[i] = MakeRow(p, i) end

    local foot = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    foot:SetPoint("BOTTOMLEFT", 18, 16)
    foot:SetTextColor(C.dim[1], C.dim[2], C.dim[3], 0.8)
    foot:SetText("Die Tafel sortiert sich selbst: Was gerade zählt, steht oben.  ·  Klick auf eine Zeile öffnet das Modul.")

    -- Puls des Live-Punkts und das gestaffelte Einblenden der Zeilen (nur solange sichtbar)
    local acc = 0
    p:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc < 0.033 then return end
        local dt = acc
        acc = 0
        local t = GetTime()
        local a = 0.18 + 0.22 * (0.5 + 0.5 * math.sin(t * 3))
        H.glow:SetAlpha(a / 0.25)
        local s = 14 + 6 * (0.5 + 0.5 * math.sin(t * 3))
        H.glow:SetSize(s, s)
        if H.anim then
            local done = true
            for i, r in ipairs(H.rows) do
                if r:IsShown() then
                    local k = math.min(1, math.max(0, (t - H.anim - (i - 1) * 0.05) / 0.22))
                    local e = 1 - (1 - k) * (1 - k)
                    r:SetAlpha(e)
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", 16 + 14 * (1 - e), -132 - (i - 1) * ROW_H)
                    if k < 1 then done = false end
                end
            end
            if done then H.anim = nil end
        end
    end)
    p:SetScript("OnShow", function()
        H.anim = GetTime()
        H:Refresh()
    end)
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(5, function() if H.panel and H.panel:IsVisible() then pcall(H.Refresh, H) end end)
    end
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "ZONE_CHANGED_NEW_AREA" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", function()
        if H.panel and H.panel:IsVisible() and C_Timer and C_Timer.After then
            C_Timer.After(0.2, function() pcall(H.Refresh, H) end)
        end
    end)
end

function H:Refresh()
    if not self.panel then return end
    local what, where = H.Where()
    self.what:SetText(what)
    self.where:SetText(where)
    self.clock:SetText(date("%H:%M"))
    local list = H.Collect()
    local warn = 0
    for i, row in ipairs(self.rows) do
        local r = list[i]
        row.r = r
        if r then
            local c = StateColor(r.state)
            row.bar:SetVertexColor(c[1], c[2], c[3], r.state == "idle" and 0.6 or 1)
            row.cat:SetText(ns.T.Upper(r.cat))
            row.cat:SetTextColor(c[1], c[2], c[3], r.state == "idle" and 0.8 or 1)
            row.title:SetText(r.title or "")
            row.title:SetTextColor(r.state == "idle" and 0.7 or 1, r.state == "idle" and 0.7 or 1, r.state == "idle" and 0.74 or 1)
            row.det:SetText(r.detail or "")
            if r.state == "bad" or r.state == "warn" then warn = warn + 1 end
            if not row:IsShown() then row:SetAlpha(H.anim and 0 or 1) end
            row:Show()
        else
            row:Hide()
        end
    end
    if warn > 0 then
        self.sum:SetText(Hx("warn") .. warn .. (warn == 1 and " Hinweis" or " Hinweise") .. "|r")
    else
        self.sum:SetText(Hx("ok") .. "Alles ruhig|r")
    end
end

ns.Suite:RegisterModule({
    id = "home",
    name = "Lage",
    icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
    desc = "Was gerade zählt – je nachdem, wo du bist",
    create = function(p) H:Create(p) end,
    onShow = function() H:Refresh() end,
})
