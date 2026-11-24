-- CBAS (Craphunts Blacklisted Addon Suite) - Instanzen: Raids & Dungeons erkennen, per /who nach Zone scannen
local ADDON, ns = ...

-- kw = Lua-Muster fuer Chat-Texte (kleingeschrieben)
ns.INSTANCES = {
    { key = "MC",   kind = "raid", de = "Geschmolzener Kern", en = "Molten Core",
      kw = { "%f[%w]mc%f[%W]", "molten core", "geschmolzene" } },
    { key = "ONY",  kind = "raid", de = "Onyxias Hort", en = "Onyxia's Lair",
      kw = { "%f[%w]ony%f[%W]", "onyxia" } },
    { key = "BWL",  kind = "raid", de = "Pechschwingenhort", en = "Blackwing Lair",
      kw = { "%f[%w]bwl%f[%W]", "pechschwingen", "blackwing" } },
    { key = "ZG",   kind = "raid", de = "Zul'Gurub", en = "Zul'Gurub",
      kw = { "%f[%w]zg%f[%W]", "zul'gurub", "zul gurub", "zulgurub" } },
    { key = "AQ20", kind = "raid", de = "Ruinen von Ahn'Qiraj", en = "Ruins of Ahn'Qiraj",
      kw = { "%f[%w]aq ?20%f[%W]", "ruinen von ahn", "ruins of ahn" } },
    { key = "AQ40", kind = "raid", de = "Tempel von Ahn'Qiraj", en = "Temple of Ahn'Qiraj",
      kw = { "%f[%w]aq ?40%f[%W]", "tempel von ahn", "temple of ahn" } },
    { key = "NAXX", kind = "raid", de = "Naxxramas", en = "Naxxramas",
      kw = { "naxx" } },

    { key = "UBRS", kind = "dungeon", de = "Schwarzfelsspitze", en = "Blackrock Spire",
      kw = { "%f[%w][ul]brs%f[%W]", "schwarzfelsspitze", "blackrock spire" } },
    { key = "BRD",  kind = "dungeon", de = "Schwarzfelstiefen", en = "Blackrock Depths",
      kw = { "%f[%w]brd%f[%W]", "schwarzfelstiefen", "blackrock depths" } },
    { key = "STRAT", kind = "dungeon", de = "Stratholme", en = "Stratholme",
      kw = { "%f[%w]strat%f[%W]", "stratholme" } },
    { key = "SCHOLO", kind = "dungeon", de = "Scholomance", en = "Scholomance",
      kw = { "scholo" } },
    { key = "DIRE", kind = "dungeon", de = "Düsterbruch", en = "Dire Maul",
      kw = { "düsterbruch", "dire maul", "%f[%w]dm ?[nwo]%f[%W]", "%f[%w]dm ?east", "%f[%w]dm ?west", "%f[%w]dm ?north" } },
    { key = "ST",   kind = "dungeon", de = "Versunkener Tempel", en = "Sunken Temple",
      kw = { "versunkene", "sunken temple", "atal'hakkar" } },
    { key = "MARA", kind = "dungeon", de = "Maraudon", en = "Maraudon",
      kw = { "maraudon", "%f[%w]mara%f[%W]" } },
    { key = "ZF",   kind = "dungeon", de = "Zul'Farrak", en = "Zul'Farrak",
      kw = { "%f[%w]zf%f[%W]", "zul'farrak" } },
    { key = "ULDA", kind = "dungeon", de = "Uldaman", en = "Uldaman",
      kw = { "uldaman", "%f[%w]ulda%f[%W]" } },
    { key = "SM",   kind = "dungeon", de = "Scharlachrotes Kloster", en = "Scarlet Monastery",
      kw = { "%f[%w]sm%f[%W]", "scharlachrote", "scarlet monastery", "kloster" } },
    { key = "RFD",  kind = "dungeon", de = "Hügel der Klingenhauer", en = "Razorfen Downs",
      kw = { "%f[%w]rfd%f[%W]", "hügel der klingenhauer", "razorfen downs" } },
    { key = "GNOMER", kind = "dungeon", de = "Gnomeregan", en = "Gnomeregan",
      kw = { "gnomeregan", "%f[%w]gnomer%f[%W]" } },
    { key = "RFK",  kind = "dungeon", de = "Kral der Klingenhauer", en = "Razorfen Kraul",
      kw = { "%f[%w]rfk%f[%W]", "kral der klingenhauer", "razorfen kraul" } },
    { key = "BFD",  kind = "dungeon", de = "Tiefschwarze Grotte", en = "Blackfathom Deeps",
      kw = { "%f[%w]bfd%f[%W]", "tiefschwarze", "blackfathom" } },
    { key = "STOCKS", kind = "dungeon", de = "Das Verlies", en = "The Stockade",
      kw = { "verlies", "stockade", "%f[%w]stocks%f[%W]" } },
    { key = "SFK",  kind = "dungeon", de = "Burg Schattenfang", en = "Shadowfang Keep",
      kw = { "%f[%w]sfk%f[%W]", "schattenfang", "shadowfang" } },
    { key = "WC",   kind = "dungeon", de = "Die Höhlen des Wehklagens", en = "Wailing Caverns",
      kw = { "%f[%w]wc%f[%W]", "wehklagens", "wailing caverns" } },
    { key = "VC",   kind = "dungeon", de = "Die Todesminen", en = "The Deadmines",
      kw = { "todesminen", "deadmines", "%f[%w]vc%f[%W]" } },
    { key = "RFC",  kind = "dungeon", de = "Der Flammenschlund", en = "Ragefire Chasm",
      kw = { "%f[%w]rfc%f[%W]", "flammenschlund", "ragefire" } },
}

ns.INSTANCE_BY_KEY = {}
local zoneMap = {}
for _, inst in ipairs(ns.INSTANCES) do
    ns.INSTANCE_BY_KEY[inst.key] = inst
    zoneMap[inst.de:lower()] = inst.key
    zoneMap[inst.en:lower()] = inst.key
    local deShort = inst.de:lower():gsub("^die ", ""):gsub("^der ", ""):gsub("^das ", "")
    local enShort = inst.en:lower():gsub("^the ", "")
    zoneMap[deShort] = inst.key
    zoneMap[enShort] = inst.key
end

local isDE = (GetLocale and (GetLocale() == "deDE" or GetLocale() == "deAT"))

function ns.InstanceName(key)
    local inst = ns.INSTANCE_BY_KEY[key]
    if not inst then return key end
    return isDE and inst.de or inst.en
end

-- Zonenname aus /who -> Instanz-Schluessel
function ns.ZoneToInstance(zone)
    if type(zone) ~= "string" or zone == "" then return nil end
    local z = zone:lower()
    if zoneMap[z] then return zoneMap[z] end
    for name, key in pairs(zoneMap) do
        if z:find(name, 1, true) then return key end   -- z.B. "Düsterbruch - Ost"
    end
end

-- Instanzen, die in einem Text erwaehnt werden
function ns.MatchInstances(low)
    local found
    for _, inst in ipairs(ns.INSTANCES) do
        for _, p in ipairs(inst.kw) do
            if low:find(p) then
                found = found or {}
                found[#found + 1] = inst.key
                break
            end
        end
    end
    return found
end

local function Entry(g, key)
    g.instances = g.instances or {}
    local e = g.instances[key]
    if not e then
        e = {}
        g.instances[key] = e
    end
    return e
end

function ns.NoteInstanceMention(g, key, t)
    local e = Entry(g, key)
    e.mention = math.max(e.mention or 0, t or time())
end

-- Ergebnis einer /who-Abfrage: count Mitglieder der Gilde gleichzeitig in der Instanz
local DAYNAMES = { [0] = "So", "Mo", "Di", "Mi", "Do", "Fr", "Sa" }
function ns.NoteInstanceSighting(g, key, count, t)
    t = t or time()
    local e = Entry(g, key)
    e.seen = t
    e.last = count
    if count > (e.max or 0) then e.max = count end
    if count >= 3 then
        -- gleiche Stunde nicht doppelt zaehlen
        local slot = date("%Y%m%d%H", t)
        if e.lastSlot ~= slot then
            e.lastSlot = slot
            e.groups = (e.groups or 0) + 1
            e.slots = e.slots or {}
            local wd = tonumber(date("%w", t))
            local key2 = DAYNAMES[wd] .. " " .. date("%H", t) .. " Uhr"
            e.slots[key2] = (e.slots[key2] or 0) + 1
        end
    end
end

-- Kurzbeschreibung fuer Profil
function ns.InstanceLines(g)
    local out = {}
    if not g.instances then return out end
    local list = {}
    for key, e in pairs(g.instances) do
        list[#list + 1] = { key = key, e = e, t = math.max(e.seen or 0, e.mention or 0) }
    end
    table.sort(list, function(a, b)
        local ga, gb = a.e.groups or 0, b.e.groups or 0
        if ga ~= gb then return ga > gb end
        return a.t > b.t
    end)
    for _, x in ipairs(list) do
        local e = x.e
        local parts = {}
        if e.seen then
            parts[#parts + 1] = string.format("vor %s mit %d Mitgl. drin (max. %d)", ns.Ago(e.seen), e.last or 0, e.max or 0)
        end
        if e.groups and e.groups > 0 then
            parts[#parts + 1] = "|cff40ff40" .. e.groups .. "x als Gruppe|r"
        end
        if e.mention then parts[#parts + 1] = "in Werbung erwähnt" end
        local s = "|cffffd100" .. ns.InstanceName(x.key) .. "|r: " .. table.concat(parts, ", ")
        if e.slots then
            local sl = {}
            for k, n in pairs(e.slots) do sl[#sl + 1] = { k = k, n = n } end
            table.sort(sl, function(a, b) return a.n > b.n end)
            local txt = {}
            for i = 1, math.min(4, #sl) do txt[#txt + 1] = sl[i].k .. (sl[i].n > 1 and (" (" .. sl[i].n .. "x)") or "") end
            s = s .. "\n    |cff888888beobachtet: " .. table.concat(txt, ", ") .. "|r"
        end
        out[#out + 1] = s
    end
    return out
end

function ns.HasInstance(g, key)
    return g.instances and g.instances[key] ~= nil
end

---------------------------------------------------------------------------
-- Raid-/Dungeon-Scan per /who (ein Klick = eine Instanz)
---------------------------------------------------------------------------
ns.zoneIndex = 1
function ns.ZoneScanList()
    local only = ns.db.settings.zoneScanDungeons ~= false
    local list = {}
    for _, inst in ipairs(ns.INSTANCES) do
        if inst.kind == "raid" or only then list[#list + 1] = inst end
    end
    return list
end

function ns.WhoZoneStep()
    local list = ns.ZoneScanList()
    if ns.zoneIndex > #list then ns.zoneIndex = 1 end
    local inst = list[ns.zoneIndex]
    local zname = ns.InstanceName(inst.key)
    if ns.SendWho('z-"' .. zname .. '"', { zone = inst.key }) then
        ns.Print(string.format("Instanz-Scan %d/%d: %s", ns.zoneIndex, #list, zname))
        ns.zoneIndex = ns.zoneIndex + 1
        if ns.zoneIndex > #list then ns.zoneIndex = 1 end
        ns.RefreshUI()
    end
end

---------------------------------------------------------------------------
-- 60er-Gebiete: /who auf Max-Level-Spieler je Gebiet
---------------------------------------------------------------------------
ns.ZONES60 = {
    { de = "Silithus", en = "Silithus" },
    { de = "Winterquell", en = "Winterspring" },
    { de = "Östliche Pestländer", en = "Eastern Plaguelands" },
    { de = "Westliche Pestländer", en = "Western Plaguelands" },
    { de = "Brennende Steppe", en = "Burning Steppes" },
    { de = "Der Schwarzfels", en = "Blackrock Mountain" },
    { de = "Teufelswald", en = "Felwood" },
    { de = "Azshara", en = "Azshara" },
    { de = "Krater von Un'Goro", en = "Un'Goro Crater" },
    { de = "Sengende Schlucht", en = "Searing Gorge" },
    { de = "Verwüstete Lande", en = "Blasted Lands" },
    { de = "Gebirgspass der Totenwinde", en = "Deadwind Pass" },
    { de = "Mondlichtung", en = "Moonglade" },
}
ns.CAPITALS = {
    { de = "Orgrimmar", en = "Orgrimmar" },
    { de = "Unterstadt", en = "Undercity" },
    { de = "Donnerfels", en = "Thunder Bluff" },
    { de = "Sturmwind", en = "Stormwind City" },
    { de = "Eisenschmiede", en = "Ironforge" },
    { de = "Darnassus", en = "Darnassus" },
}

ns.zone60Index = 1
ns.zone60Queue = {}

local function zname(z) return isDE and z.de or z.en end

-- feste Liste + aus /who gelernte Gebiete (wo viele 60er gesehen wurden)
function ns.Zone60List()
    local list, seen = {}, {}
    local function add(n)
        if n and n ~= "" and not seen[n:lower()] then
            seen[n:lower()] = true
            list[#list + 1] = n
        end
    end
    for _, z in ipairs(ns.ZONES60) do add(zname(z)) end
    local learned = {}
    for area, e in pairs(ns.db.zones60 or {}) do
        if not seen[area:lower()] and (e.n or 0) >= 3 then learned[#learned + 1] = { a = area, n = e.n } end
    end
    table.sort(learned, function(a, b) return a.n > b.n end)
    for i = 1, math.min(8, #learned) do add(learned[i].a) end
    if ns.db.settings.scanCapitals then
        for _, z in ipairs(ns.CAPITALS) do add(zname(z)) end
    end
    return list
end

function ns.IsCapital(area)
    if not area then return false end
    local a = area:lower()
    for _, z in ipairs(ns.CAPITALS) do
        if z.de:lower() == a or z.en:lower() == a then return true end
    end
    return false
end

-- /who-Treffer: Gebiete merken, in denen Max-Level-Spieler stehen
function ns.LearnZone60(area)
    if type(area) ~= "string" or area == "" then return end
    if ns.ZoneToInstance(area) or ns.IsCapital(area) then return end
    ns.db.zones60 = ns.db.zones60 or {}
    local e = ns.db.zones60[area] or {}
    e.n = (e.n or 0) + 1
    e.t = time()
    ns.db.zones60[area] = e
end

function ns.CurrentZone60()
    if #ns.zone60Queue > 0 then return ns.zone60Queue[1].zone, true end
    local list = ns.Zone60List()
    if ns.zone60Index > #list then ns.zone60Index = 1 end
    return list[ns.zone60Index], false
end

function ns.WhoZone60Step()
    local maxLvl = ns.MaxLevel()
    if #ns.zone60Queue > 0 then
        local it = ns.zone60Queue[1]
        if ns.SendWho(it.q, { zone60 = it.zone, split = true }) then
            table.remove(ns.zone60Queue, 1)
            ns.Print(string.format("60er-Scan %s: %s (noch %d Teilabfragen)", it.zone, it.cls, #ns.zone60Queue))
            ns.RefreshUI()
        end
        return
    end
    local list = ns.Zone60List()
    if ns.zone60Index > #list then ns.zone60Index = 1 end
    local zone = list[ns.zone60Index]
    if ns.SendWho(maxLvl .. ' z-"' .. zone .. '"', { zone60 = zone }) then
        ns.Print(string.format("60er-Scan %d/%d: %s", ns.zone60Index, #list, zone))
        ns.zone60Index = ns.zone60Index + 1
        if ns.zone60Index > #list then ns.zone60Index = 1 end
        ns.RefreshUI()
    end
end

-- Hauptstaedte: eigener Scan (ein Klick = eine Stadt, Level 60)
ns.capIndex = 1
ns.capQueue = {}

function ns.CapitalList()
    local list = {}
    for _, z in ipairs(ns.CAPITALS) do list[#list + 1] = zname(z) end
    return list
end

function ns.CurrentCapital()
    if #ns.capQueue > 0 then return ns.capQueue[1].zone, true end
    local list = ns.CapitalList()
    if ns.capIndex > #list then ns.capIndex = 1 end
    return list[ns.capIndex], false
end

function ns.WhoCapitalStep()
    local maxLvl = ns.MaxLevel()
    if #ns.capQueue > 0 then
        local it = ns.capQueue[1]
        if ns.SendWho(it.q, { zone60 = it.zone, split = true, capital = true }) then
            table.remove(ns.capQueue, 1)
            ns.Print(string.format("Städte-Scan %s: %s (noch %d Teilabfragen)", it.zone, it.cls, #ns.capQueue))
            ns.RefreshUI()
        end
        return
    end
    local list = ns.CapitalList()
    if ns.capIndex > #list then ns.capIndex = 1 end
    local zone = list[ns.capIndex]
    if ns.SendWho(maxLvl .. ' z-"' .. zone .. '"', { zone60 = zone, capital = true }) then
        ns.Print(string.format("Städte-Scan %d/%d: %s", ns.capIndex, #list, zone))
        ns.capIndex = ns.capIndex + 1
        if ns.capIndex > #list then ns.capIndex = 1 end
        ns.RefreshUI()
    end
end

-- Gebiet war voll (50 Treffer) -> Teilabfragen je Klasse einreihen
function ns.SplitZone60(zone, capital)
    local maxLvl = ns.MaxLevel()
    local n = 0
    local queue = capital and ns.capQueue or ns.zone60Queue
    for _, c in ipairs(ns.classNames or {}) do
        table.insert(queue, n + 1, {
            zone = zone, cls = c,
            q = maxLvl .. ' z-"' .. zone .. '" c-"' .. c .. '"',
        })
        n = n + 1
    end
    if n > 0 then
        ns.Print(string.format("%s ist voll (50+ Spieler) - die nächsten %d Klicks fragen die Klassen einzeln ab.", zone, n))
    end
end

-- Wo sind die Mitglieder einer Gilde unterwegs? (aus /who, letzte 14 Tage)
function ns.MemberZones(g)
    local cnt = {}
    local now = time()
    for _, m in pairs(g.members) do
        if m.zone and m.seen and now - m.seen < 14 * 86400 then
            cnt[m.zone] = (cnt[m.zone] or 0) + 1
        end
    end
    local list = {}
    for z, n in pairs(cnt) do list[#list + 1] = { z = z, n = n } end
    table.sort(list, function(a, b) return a.n > b.n end)
    return list
end
