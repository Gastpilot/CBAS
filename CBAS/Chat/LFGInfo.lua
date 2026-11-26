-- CBAS - Gruppensuche erweitern: CBAS-Infos zu jedem Suchergebnis
-- Blizzard-Gruppensuche UND LFGForever zeigen beim Ueberfahren eines Ergebnisses dasselbe
-- Blizzard-Fenster (LFGBrowseSearchEntryTooltip). CBAS haengt darunter ein zweites Fenster mit:
--   Land/Sprache, Gilde + Leistung + Lootsystem (GScout), Geierwacht-Warnungen,
--   gemeinsame Runs, Blacklist - fuer Anfuehrer und alle Mitglieder.
-- Kostet nur etwas beim Ueberfahren mit der Maus.
local ADDON, ns = ...
local S = ns.S
local LI = {}
ns.LFGInfo = LI

local function Readable(v)
    if v == nil then return nil end
    if canaccessvalue and not canaccessvalue(v) then return nil end
    return S(v)
end

local function Enabled() return ns.db and ns.db.settings.lfgInfo ~= false end

local tip
local function Tip()
    if tip then return tip end
    tip = CreateFrame("GameTooltip", "CBASLFGTooltip", UIParent, "GameTooltipTemplate")
    tip:SetFrameStrata("TOOLTIP")
    return tip
end

-- einmal je Anzeige: Geier-Urteile und gemeinsame Runs aus der Geierwacht zaehlen
local function GeierStats()
    local GW = ns.Geier
    local geier, frag, runs = {}, {}, {}
    if not GW then return geier, frag, runs end
    local d = GW.db()
    for _, h in ipairs(d.history or {}) do
        if h.verdict == "geier" and (h.kind == "need" or h.won) then geier[h.player] = (geier[h.player] or 0) + 1
        elseif h.verdict == "frag" and h.kind == "need" then frag[h.player] = (frag[h.player] or 0) + 1 end
    end
    for _, r in pairs(d.runs or {}) do
        if type(r) == "table" and type(r.members) == "table" then
            for full in pairs(r.members) do runs[full] = (runs[full] or 0) + 1 end
        end
    end
    return geier, frag, runs
end

LI.GeierStats = GeierStats

local CLASS_COLOR = function(cls)
    local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    return c and c.colorStr and ("|c" .. c.colorStr) or "|cffffffff"
end

-- eine Zeile je Spieler; gibt zusaetzlich Warnstufe zurueck (0 ok, 1 Hinweis, 2 Warnung)
local function PlayerLine(full, cls, stats)
    local geier, frag, runs = stats[1], stats[2], stats[3]
    local CF = ns.ChatFlags
    local parts, warn = {}, 0
    local code = CF and CF.CountryOf(full)
    local flag = code and (CF.Icon(code, 12) .. " ") or ""
    local name = CLASS_COLOR(cls) .. full .. "|r"
    local key = ns.db.players[full]
    local g = key and ns.db.guilds[key]
    if g then
        local gt = "<" .. g.name .. ">"
        if g.blacklist then gt = "|cffff4040" .. gt .. " Blacklist|r"; warn = 2 end
        parts[#parts + 1] = gt
        local st = ns.ScoreText and select(1, ns.ScoreText(g))
        if st and st ~= "" then parts[#parts + 1] = "Leistung " .. st end
        local loot = ns.LootShort and ns.LootShort(g)
        if loot and loot ~= "" then parts[#parts + 1] = "|cff99ccff" .. loot .. "|r" end
    end
    local GW = ns.Geier
    local mark = GW and GW.db().marked and GW.db().marked[full]
    if mark then
        parts[#parts + 1] = "|cffff4040markiert" .. (type(mark) == "table" and mark.note and (": " .. mark.note) or "") .. "|r"
        warn = 2
    end
    if geier[full] then
        parts[#parts + 1] = "|cffff4040" .. geier[full] .. "x Geier-Bedarf|r"
        warn = 2
    elseif frag[full] then
        parts[#parts + 1] = "|cffffd100" .. frag[full] .. "x fragwürdiger Bedarf|r"
        warn = math.max(warn, 1)
    end
    if runs[full] then parts[#parts + 1] = "|cff40ff40" .. runs[full] .. " Run(s) mit dir|r" end
    return flag .. name .. (#parts > 0 and ("  " .. table.concat(parts, " · ")) or ""), warn, code
end

function LI.Show(owner, resultID)
    if not Enabled() or not owner or not resultID then return end
    if not (C_LFGList and C_LFGList.GetSearchResultInfo) then return end
    local ok, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
    if not ok or type(info) ~= "table" then return end
    local stats = { GeierStats() }
    local lines, langs, worst = {}, {}, 0
    local seen = {}
    local n = tonumber(Readable(info.numMembers)) or 1
    for i = 1, math.min(40, n) do
        local ok2, m = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, i)
        local name = ok2 and type(m) == "table" and Readable(m.name)
        if name then
            local full = ns.NormFull(name)
            seen[full] = true
            local l, w, code = PlayerLine(full, Readable(m.classFilename), stats)
            lines[#lines + 1] = l
            worst = math.max(worst, w)
            if code then langs[code] = (langs[code] or 0) + 1 end
        end
    end
    local leader = Readable(info.leaderName)
    if leader and not seen[ns.NormFull(leader)] then
        local l, w, code = PlayerLine(ns.NormFull(leader), nil, stats)
        table.insert(lines, 1, l)
        worst = math.max(worst, w)
        if code then langs[code] = (langs[code] or 0) + 1 end
    end
    if #lines == 0 then return end
    local t = Tip()
    t:SetOwner(owner, "ANCHOR_NONE")
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    t:AddLine("|cff33ccffCBAS|r  " .. (worst == 2 and "|cffff4040Achtung - siehe unten|r" or
        (worst == 1 and "|cffffd100Hinweis|r" or "|cff40ff40nichts Auffälliges|r")))
    -- Sprachen der Gruppe zusammengefasst
    local CF = ns.ChatFlags
    local lp = {}
    for code, c in pairs(langs) do lp[#lp + 1] = (CF and CF.Icon(code, 12) or code) .. (c > 1 and (" x" .. c) or "") end
    if #lp > 0 then t:AddLine("Sprachen: " .. table.concat(lp, "  "), 1, 1, 1) end
    local max = 12
    for i, l in ipairs(lines) do
        if i > max then
            t:AddLine("|cff888888... und " .. (#lines - max) .. " weitere|r")
            break
        end
        t:AddLine(l, 1, 1, 1)
    end
    t:Show()
    if not owner.cbasHooked and owner.HookScript then
        owner.cbasHooked = true
        owner:HookScript("OnHide", function() if tip then tip:Hide() end end)
    end
end

---------------------------------------------------------------------------
-- Warn-Symbole direkt in der Ergebnisliste (seit 2.26.0)
-- Jede sichtbare Ergebniszeile bekommt links einen Farbstreifen und rechts oben ein Symbol:
--   rot  = Blacklist-Gilde, von dir markiert oder Geier-Bedarf
--   gelb = fragwuerdiger Bedarf
-- Funktioniert fuer die Blizzard-Listen und fuer fremde Listen (LFGForever), deren Zeilen wie bei
-- Blizzard ein Feld "resultID" tragen. Leichtgewichtig: Urteil je Gruppe 15 s zwischengespeichert,
-- Geier-Zahlen 10 s, nur sichtbare Zeilen, Nachpruefen hoechstens alle 0,5 s und nur solange
-- eine Ergebnisliste offen ist.
---------------------------------------------------------------------------
local function BadgesOn() return ns.db and ns.db.settings.lfgBadges ~= false end

local statCache = { t = -100 }
local function CachedStats()
    if GetTime() - statCache.t > 10 then
        statCache = { t = GetTime(), s = { GeierStats() } }
    end
    return statCache.s
end

-- Warnstufe eines Spielers (ohne Text zu bauen): 0 ok, 1 Hinweis, 2 Warnung
local function PlayerWarn(full, stats)
    local key = ns.db.players[full]
    local g = key and ns.db.guilds[key]
    if g and g.blacklist then return 2 end
    local GW = ns.Geier
    if GW and GW.db().marked and GW.db().marked[full] then return 2 end
    if stats[1][full] then return 2 end
    if stats[2][full] then return 1 end
    return 0
end

local evalList = {}   -- resultID -> { t, w, n } (begrenzt auf 300)
function LI.Evaluate(resultID)
    if type(resultID) ~= "number" then return 0, 0 end
    local c = evalList[resultID]
    if c and GetTime() - c.t < 15 then return c.w, c.n end
    local ok, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
    if not ok or type(info) ~= "table" then return 0, 0 end
    local stats = CachedStats()
    local worst, bad, seen = 0, 0, {}
    local function check(name)
        if not name then return end
        local full = ns.NormFull(name)
        if seen[full] then return end
        seen[full] = true
        local w = PlayerWarn(full, stats)
        if w > 0 then bad = bad + 1 end
        if w > worst then worst = w end
    end
    local n = tonumber(Readable(info.numMembers)) or 1
    for i = 1, math.min(40, n) do
        local ok2, m = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, i)
        check(ok2 and type(m) == "table" and Readable(m.name) or nil)
    end
    check(Readable(info.leaderName))
    -- nicht unbegrenzt wachsen: bei mehr als 300 Eintraegen leeren
    local cnt = 0
    for _ in pairs(evalList) do cnt = cnt + 1 end
    if cnt > 300 then wipe(evalList) end
    evalList[resultID] = { t = GetTime(), w = worst, n = bad }
    return worst, bad
end

function LI.ClearCache()
    wipe(evalList)
    statCache.t = -100
end

local BADGE_ICON = {
    [2] = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew",
    [1] = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertOther",
}

local function Badge(row)
    local b = rawget(row, "cbasBadge")
    if b then return b end
    b = CreateFrame("Frame", nil, row)
    b:SetAllPoints()
    b:EnableMouse(false)
    b:SetFrameLevel((row.GetFrameLevel and row:GetFrameLevel() or 1) + 5)
    local bar = b:CreateTexture(nil, "OVERLAY")
    bar:SetTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetWidth(3)
    bar:SetPoint("TOPLEFT", 1, -2)
    bar:SetPoint("BOTTOMLEFT", 1, 2)
    b.bar = bar
    local ic = b:CreateTexture(nil, "OVERLAY")
    ic:SetSize(14, 14)
    ic:SetPoint("TOPRIGHT", -3, -2)
    b.icon = ic
    local cnt = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cnt:SetPoint("RIGHT", ic, "LEFT", -1, 0)
    b.count = cnt
    b:Hide()
    rawset(row, "cbasBadge", b)
    return b
end

-- eine Zeile markieren (oder Markierung entfernen)
function LI.DecorateRow(row)
    if not row or type(row) ~= "table" then return end
    local id = rawget(row, "resultID")
    local b = rawget(row, "cbasBadge")
    if not BadgesOn() or type(id) ~= "number" or (row.IsShown and not row:IsShown()) then
        if b then b:Hide(); b.id = nil end
        return
    end
    local w, n = LI.Evaluate(id)
    local stamp = evalList[id] and evalList[id].t
    if w == 0 then
        if b then b:Hide(); b.id, b.t = id, stamp end
        return
    end
    b = Badge(row)
    b.id, b.t = id, stamp
    local c = w == 2 and { 1, 0.25, 0.25 } or { 1, 0.82, 0.13 }
    b.bar:SetVertexColor(c[1], c[2], c[3], 0.95)
    b.icon:SetTexture(BADGE_ICON[w])
    b.count:SetText(n > 1 and (n .. "x") or "")
    b.count:SetTextColor(c[1], c[2], c[3])
    b:Show()
end

-- bekannte Zeilen (schwache Schluessel: verschwindet eine Zeile, faellt sie heraus)
local rows = setmetatable({}, { __mode = "k" })
LI.rows = rows

local function Remember(row) if type(row) == "table" then rows[row] = true end end

-- Zeilen in fremden Listen finden: einmal je Suche alle sichtbaren Frames mit resultID merken
local lastScan = -100
function LI.ScanRows()
    if not EnumerateFrames or GetTime() - lastScan < 2 then return end
    lastScan = GetTime()
    local f = EnumerateFrames()
    local guard = 0
    while f and guard < 20000 do
        guard = guard + 1
        local id = rawget(f, "resultID")
        if type(id) == "number" and f.IsVisible and f:IsVisible() then
            Remember(f)
        end
        f = EnumerateFrames(f)
    end
end

function LI.RefreshRows()
    local any = false
    for row in pairs(rows) do
        if row.IsVisible and row:IsVisible() then any = true end
        local b = rawget(row, "cbasBadge")
        -- nur neu zeichnen, wenn die Zeile eine andere Gruppe zeigt oder das Urteil neu/abgelaufen ist
        local id = rawget(row, "resultID")
        local e = id and evalList[id]
        if not (BadgesOn() and b and b.id == id and e and b.t == e.t and GetTime() - e.t < 15) then
            LI.DecorateRow(row)
        end
    end
    return any
end

-- Waechter: solange eine Ergebnisliste sichtbar ist, alle 0,5 s pruefen (Zeilen werden beim Scrollen
-- wiederverwendet und zeigen dann eine andere Gruppe)
local watcher = CreateFrame("Frame")
watcher:Hide()
local acc = 0
watcher:SetScript("OnUpdate", function(self, el)
    acc = acc + el
    if acc < 0.5 then return end
    acc = 0
    local ok, any = pcall(LI.RefreshRows)
    if ok and not any then self:Hide() end
end)

function LI.OnResults(id)
    if not BadgesOn() then return end
    if type(id) == "number" then evalList[id] = nil else LI.ClearCache() end
    pcall(LI.ScanRows)
    pcall(LI.RefreshRows)
    watcher:Show()
end

-- direkte Haken in die Blizzard-Zeilen (sofortige Anzeige ohne Suche nach Frames)
local function OnRowUpdate(row)
    Remember(row)
    pcall(LI.DecorateRow, row)
    if BadgesOn() then watcher:Show() end
end

local hooked = {}
local function TryHook()
    if not hooksecurefunc then return end
    -- Blizzard-Gruppensuche (Classic-Oberflaeche) - wird auch von LFGForever benutzt
    if not hooked.browse and LFGBrowseSearchEntryTooltip_UpdateAndShow then
        hooked.browse = true
        hooksecurefunc("LFGBrowseSearchEntryTooltip_UpdateAndShow", function(tooltip, resultID)
            pcall(LI.Show, tooltip, resultID)
        end)
    end
    -- moderne Gruppensuche (falls vorhanden)
    if not hooked.list and LFGListUtil_SetSearchEntryTooltip then
        hooked.list = true
        hooksecurefunc("LFGListUtil_SetSearchEntryTooltip", function(tooltip, resultID)
            pcall(LI.Show, tooltip, resultID)
        end)
    end
    -- Ergebniszeilen: Classic-Gruppensuche und moderne Gruppensuche
    for _, fn in ipairs({ "LFGBrowseSearchEntry_Update", "LFGListSearchEntry_Update" }) do
        if not hooked[fn] and type(_G[fn]) == "function" then
            hooked[fn] = true
            hooksecurefunc(fn, OnRowUpdate)
        end
    end
    return hooked.browse and hooked.list and hooked.LFGBrowseSearchEntry_Update and hooked.LFGListSearchEntry_Update
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
for _, e in ipairs({ "LFG_LIST_SEARCH_RESULTS_RECEIVED", "LFG_LIST_SEARCH_RESULT_UPDATED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
        -- eine einzelne Gruppe hat sich geaendert: nur deren Urteil verwerfen, der Waechter zeichnet neu
        local id = Readable(arg1)
        if type(id) == "number" then evalList[id] = nil end
        if BadgesOn() then watcher:Show() end
        return
    elseif event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then
        -- kurz warten, bis die Liste (Blizzard oder LFGForever) ihre Zeilen gefuellt hat
        if C_Timer and C_Timer.After then C_Timer.After(0.3, function() LI.OnResults() end) else LI.OnResults() end
        return
    end
    -- die Blizzard-Gruppensuche wird teils erst bei Bedarf geladen -> bei jedem Nachladen erneut versuchen
    if TryHook() then self:UnregisterEvent("ADDON_LOADED") end
end)
