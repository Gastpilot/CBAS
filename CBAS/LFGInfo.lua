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
    return hooked.browse and hooked.list
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event)
    -- die Blizzard-Gruppensuche wird teils erst bei Bedarf geladen -> bei jedem Nachladen erneut versuchen
    if TryHook() then self:UnregisterEvent("ADDON_LOADED") end
end)
