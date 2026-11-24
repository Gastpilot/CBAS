-- CBAS - GScout: Leistungswert (High Performer) und Lootsystem-Erkennung mit Hinweisen
local ADDON, ns = ...

---------------------------------------------------------------------------
-- Lootsystem: Hinweise sammeln und gewichten
---------------------------------------------------------------------------
-- Gewicht je Quelle
local EV_WEIGHT = { recruit = 2, chat = 1, run = 3, finder = 2, sync = 1 }
local EV_NAMES = { recruit = "Werbung", chat = "Chat", run = "eigener Run", finder = "Gildenfinder", sync = "von Mitspielern" }

-- Plündermethode eines Runs -> wahrscheinliches Lootsystem
local METHOD_SYSTEM = {
    ["Plündermeister"] = "Plündermeister", ["Gruppenplündern"] = "Bedarf/Gier",
    ["Bedarf vor Gier"] = "Bedarf/Gier", ["Reihum"] = "Bedarf/Gier",
    ["Jeder gegen jeden"] = "Jeder gegen jeden", ["Persönliche Beute"] = "Persönliche Beute",
}

-- Treffer im Text -> Liste der Systeme
function ns.MatchLoot(low)
    local found, seen = {}, {}
    for _, p in ipairs(ns.LOOT_PATTERNS or {}) do
        if not seen[p[2]] and low:find(p[1]) then
            seen[p[2]] = true
            found[#found + 1] = p[2]
        end
    end
    -- "GDKP" schliesst normales "DKP" aus (beides im selben Text = GDKP)
    if seen.GDKP and seen.DKP then
        for i, s in ipairs(found) do if s == "DKP" then table.remove(found, i) break end end
    end
    return found
end

function ns.AddLootEvidence(g, system, source, t)
    if not g or not system or not EV_WEIGHT[source] then return end
    g.lootEv = g.lootEv or {}
    local e = g.lootEv[system] or {}
    g.lootEv[system] = e
    e[source] = (e[source] or 0) + 1
    e.last = math.max(e.last or 0, t or time())
end

local function EvScore(e)
    local s = 0
    for src, w in pairs(EV_WEIGHT) do s = s + (e[src] or 0) * w end
    return s
end
ns.LootEvScore = EvScore

-- Alte Daten (nur Stichwoerter) in Hinweise umwandeln
function ns.MigrateLoot(g)
    if g.lootEv or not g.loot or not next(g.loot) then return end
    g.lootEv = {}
    for sys, t in pairs(g.loot) do
        g.lootEv[sys] = { recruit = 1, last = type(t) == "number" and t or time() }
    end
end

-- Ergebnis: Liste { system, score, conf ("sicher"/"wahrscheinlich"/"Hinweis"), detail }
-- Systeme, die in Classic ueber den Pluendermeister laufen: ein beobachteter
-- Pluendermeister bestaetigt sie, statt ihnen zu widersprechen
local ML_BASED = { DKP = true, GDKP = true, EPGP = true, ["Loot Council"] = true, ["Soft Reserve"] = true,
    ["Hard Reserve"] = true, ["TMB/Prio"] = true }

function ns.LootRanking(g)
    ns.MigrateLoot(g)
    local list = {}
    local ml = g.lootEv and g.lootEv["Plündermeister"]
    local mlScore = ml and EvScore(ml) or 0
    local hasMlBased = false
    for sys in pairs(g.lootEv or {}) do if ML_BASED[sys] then hasMlBased = true end end
    for sys, e in pairs(g.lootEv or {}) do
        local parts = {}
        for _, src in ipairs({ "recruit", "chat", "run", "finder", "sync" }) do
            if e[src] and e[src] > 0 then parts[#parts + 1] = e[src] .. "× " .. EV_NAMES[src] end
        end
        local score = EvScore(e)
        if ML_BASED[sys] and mlScore > 0 then
            score = score + math.min(3, mlScore)
            parts[#parts + 1] = "Plündermeister beobachtet"
        end
        local conf = score >= 5 and "sicher" or (score >= 2 and "wahrscheinlich" or "Hinweis")
        local entry = { system = sys, score = score, conf = conf, detail = table.concat(parts, ", ") }
        if sys == "Plündermeister" and hasMlBased then
            -- nur Bestaetigung, kein eigenes System
            entry.score = 0
            entry.conf = "Hinweis"
            entry.detail = entry.detail .. ", bestätigt das System oben"
        end
        list[#list + 1] = entry
    end
    table.sort(list, function(a, b) return a.score > b.score end)
    return list
end

local CONF_COLOR = { sicher = "|cff40ff40", wahrscheinlich = "|cffffd100", Hinweis = "|cffaaaaaa" }

-- Kurzform fuer Liste/Tooltip
function ns.LootShort(g)
    if g.lootManual and g.lootManual ~= "" then return g.lootManual, "manuell" end
    local r = ns.LootRanking(g)
    if not r[1] then return "", nil end
    local s = r[1].system
    if r[1].conf ~= "sicher" then s = s .. "?" end
    return s, r[1].conf
end

-- Ausfuehrlich fuers Profil
function ns.LootLines(g)
    local out = {}
    if g.lootManual and g.lootManual ~= "" then
        out[#out + 1] = "|cff40ff40" .. g.lootManual .. "|r |cff888888(deine Angabe)|r"
    end
    for i, e in ipairs(ns.LootRanking(g)) do
        if i > 4 then break end
        out[#out + 1] = string.format("%s%s|r - %s |cff888888(%s)|r", CONF_COLOR[e.conf], e.system, e.conf, e.detail)
    end
    return out
end

-- Beobachtete Plündermethode eines Runs der Gilde zuschreiben
function ns.LootEvidenceFromRun(g, method)
    local sys = METHOD_SYSTEM[method or ""]
    if sys then ns.AddLootEvidence(g, sys, "run") end
end

---------------------------------------------------------------------------
-- Raid-Fortschritt aus Texten ("BWL 6/8", "MC clear", "Naxx farm")
---------------------------------------------------------------------------
local BOSSES = { MC = 10, ONY = 1, BWL = 8, ZG = 10, AQ20 = 6, AQ40 = 9, NAXX = 15 }
local TIER = { NAXX = 6, AQ40 = 5, BWL = 4, MC = 3, ONY = 3, AQ20 = 2, ZG = 2 }
ns.RAID_TIER = TIER

function ns.ParseProgress(g, low)
    if not ns.INSTANCES then return end
    for _, inst in ipairs(ns.INSTANCES) do
        if inst.kind == "raid" then
            for _, kw in ipairs(inst.kw) do
                local s, e = low:find(kw)
                if s then
                    -- im Umfeld von 14 Zeichen nach "x/y", "clear", "farm" suchen
                    local around = low:sub(math.max(1, s - 14), e + 14)
                    local a, b = around:match("(%d+)%s*/%s*(%d+)")
                    a, b = tonumber(a), tonumber(b)
                    local val
                    if a and b and b == BOSSES[inst.key] and a <= b then
                        val = a / b
                    elseif around:find("clear", 1, true) or around:find("farm", 1, true)
                        or around:find("gecleart", 1, true) or around:find("durch", 1, true) then
                        val = 1
                    end
                    if val then
                        g.progress = g.progress or {}
                        local old = g.progress[inst.key]
                        if not old or val > old.v then
                            g.progress[inst.key] = { v = val, txt = val == 1 and "clear" or (a .. "/" .. b), t = time() }
                        end
                    end
                    break
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Leistungswert 0-100
---------------------------------------------------------------------------
local DAY = 86400

local function ComputeScore(g)
    local parts = {}
    local now = time()
    local data = 0
    local function part(name, val, max, txt)
        parts[#parts + 1] = { name = name, v = val, max = max, txt = txt }
    end

    -- 1) Fortschritt: hoechster Raid, in dem die Gilde als Gruppe (5+) gesehen wurde,
    --    oder angegebener Fortschritt (zaehlt 70 %)
    local bestTier, bestTxt = 0, nil
    for key, e in pairs(g.instances or {}) do
        local tier = TIER[key]
        if tier and (e.max or 0) >= 5 and tier > bestTier then
            bestTier, bestTxt = tier, ns.InstanceName(key) .. " (" .. e.max .. " gleichzeitig gesehen)"
        end
    end
    for key, p in pairs(g.progress or {}) do
        local tier = TIER[key]
        if tier then
            local eff = (tier - 1 + p.v) * 0.7 + 0.3
            if eff > bestTier then bestTier, bestTxt = eff, ns.InstanceName(key) .. " " .. p.txt .. " (laut Werbung)" end
        end
    end
    if bestTier > 0 then data = data + 1 end
    part("Raid-Fortschritt", math.min(35, bestTier / 6 * 35), 35, bestTxt or "kein Gildenraid gesehen")

    -- 2) Raid-Aktivitaet der letzten 30 Tage
    local groups = 0
    for key, e in pairs(g.instances or {}) do
        if TIER[key] and e.seen and now - e.seen < 30 * DAY then groups = groups + (e.groups or 0) end
    end
    if groups > 0 then data = data + 1 end
    part("Raid-Aktivität", math.min(15, groups * 3), 15, groups .. "× als Gruppe im Raid (30 Tage)")

    -- 3) Ausruestung
    local xs = ns.ExtStats and ns.ExtStats(g)
    if xs and xs.ilvlN > 0 then
        local il = xs.ilvlSum / xs.ilvlN
        data = data + 1
        part("Ausrüstung", math.max(0, math.min(20, (il - 58) / 30 * 20)), 20,
            string.format("Ø Itemlevel %.0f (%d inspiziert)", il, xs.ilvlN))
    else
        part("Ausrüstung", 0, 20, "noch niemand inspiziert")
    end

    -- 4) Max-Level-Anteil und Aktivitaet
    local atMax, _, active = ns.Stats(g)
    local share = g.memberCount > 0 and atMax / g.memberCount or 0
    if g.memberCount >= 3 then data = data + 1 end
    part("Max-Level & Aktivität", math.min(15, share * 10 + math.min(5, active / 4)), 15,
        string.format("%d%% auf Max-Level, %d aktiv (7 Tage)", math.floor(share * 100 + 0.5), active))

    -- 5) Groesse
    local size = (g.inspect and g.inspect.members) or g.whoMaxOnline or g.memberCount
    part("Größe", math.min(5, size / 10), 5, size .. " Mitglieder" .. ((g.inspect and g.inspect.members) and "" or " (geschätzt)"))

    -- 6) Ausrichtung
    local amb = 0
    if g.tags and g.tags["Ambitioniert"] then amb = 5 elseif g.tags and g.tags["Raid"] then amb = 3 end
    part("Ausrichtung", amb, 5, amb == 5 and "ambitioniert/Progress" or (amb == 3 and "Raidgilde" or "-"))

    -- 7) PvP
    local pvp = 0
    if xs then for _, n in pairs(xs.pvp) do pvp = pvp + n end end
    part("PvP", math.min(5, pvp), 5, pvp .. " Mitglieder mit PvP-Titel")

    local total = 0
    for _, p in ipairs(parts) do total = total + p.v end
    total = math.floor(total + 0.5)
    local label = total >= 70 and "Top" or (total >= 50 and "stark" or (total >= 30 and "solide" or "-"))
    -- wenig Datenpunkte = unsicher
    return total, label, parts, data < 2
end

-- Zwischenspeicher: der Wert wird hoechstens alle 2 Minuten neu berechnet
-- (oder sofort, wenn sich an der Gilde etwas aendert). Spart sehr viel Rechenzeit
-- in der Liste, im Tooltip und in der Kurve. Schwache Schluessel = kein Speicherleck.
local scoreCache = setmetatable({}, { __mode = "k" })
local SCORE_TTL = 120
function ns.PerformanceScore(g)
    local c = scoreCache[g]
    local now = GetTime()
    if c and now - c.t < SCORE_TTL then return c.s, c.label, c.parts, c.unsure end
    local s, label, parts, unsure = ComputeScore(g)
    scoreCache[g] = { t = now, s = s, label = label, parts = parts, unsure = unsure }
    return s, label, parts, unsure
end
function ns.InvalidateScore(g) if g then scoreCache[g] = nil end end

-- Farbige Kurzanzeige
function ns.ScoreText(g)
    local s, label, _, unsure = ns.PerformanceScore(g)
    local col = s >= 70 and "|cffff8000" or (s >= 50 and "|cffa335ee" or (s >= 30 and "|cff0070dd" or "|cff888888"))
    return col .. s .. (unsure and "?" or "") .. "|r", s, label
end

-- Top-Spieler einer Gilde (nach Itemlevel, PvP-Titel, Level)
function ns.TopPlayers(g, n)
    local list = {}
    for full, m in pairs(g.members) do
        local sc = (m.ilvl or 0) * 10 + (m.pvp and 50 or 0) + (m.level or 0)
        list[#list + 1] = { full = full, m = m, sc = sc }
    end
    table.sort(list, function(a, b) return a.sc > b.sc end)
    local out = {}
    for i = 1, math.min(n or 5, #list) do
        if list[i].m.ilvl or list[i].m.pvp then out[#out + 1] = list[i] end
    end
    return out
end
