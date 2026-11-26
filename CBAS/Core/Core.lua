-- CBAS (Craphunts Blacklisted Addon Suite) - Core: Datenbank & Datenerfassung
local ADDON, ns = ...
_G.CBAS = ns

ns.VERSION = "2.26.0"
local PREFIX = "|cff33ccffCBAS|r: "

function ns.Print(...)
    print(PREFIX .. string.join(" ", tostringall(...)))
end

-- Midnight/Forever: manche Werte sind "secret" (z.B. im Kampf / in Instanzen).
-- Solche Werte duerfen wir nicht vergleichen -> einfach verwerfen.
local issecret = _G.issecretvalue
local function S(v)
    if v == nil then return nil end
    if issecret and issecret(v) then return nil end
    return v
end
ns.S = S

local DEFAULT_SETTINGS = {
    chatScan = true,       -- Chat nach Rekrutierungsnachrichten durchsuchen
    notifyNew = false,     -- Meldung bei jeder neuen Gilde
    notifyRecruit = true,  -- Meldung bei neu entdeckter rekrutierender Gilde
    tooltip = true,        -- Gildeninfo im Spieler-Tooltip
    notifySeeker = true,   -- Meldung, wenn jemand im Chat eine Gilde sucht
    flipTooltip = true,    -- Flip-Info im Gegenstands-Tooltip
    flipAHHelp = true,     -- Kaufhilfe neben dem AH
    flipAutoVendor = true, -- markierte Haendler-Flips automatisch verkaufen
    nameplates = true,     -- Namensplaketten mitlesen
    sync = true,           -- Daten mit anderen CBAS-Nutzern in der Gruppe tauschen
    zoneScanDungeons = true,  -- Instanz-Scan auch fuer Dungeons (sonst nur Raids)
    scanCapitals = false,     -- 60er-Scan auch in den Hauptstaedten (dafuer gibt es den Staedte-Knopf)
    inspect = true,           -- Gildenmitglieder beim Anvisieren inspizieren (echte Gildengroesse)
}

---------------------------------------------------------------------------
-- Datenbank
---------------------------------------------------------------------------
function ns.InitDB()
    -- Uebernahme der Daten aus GildenScout (Datei GildenScout.lua -> CBAS.lua umbenannt)
    if (not CBASDB or not CBASDB.guilds) and type(GildenScoutDB) == "table" then
        CBASDB = GildenScoutDB
        ns.migratedFromGildenScout = true
    end
    GildenScoutDB = nil
    CBASDB = CBASDB or {}
    local db = CBASDB
    db.guilds = db.guilds or {}
    db.players = db.players or {}   -- "Name-Realm" -> guildKey
    db.pending = db.pending or {}   -- Rekrutierer ohne bekannte Gilde
    db.chatlog = db.chatlog or {}   -- zuletzt erkannte Rekrutierungsnachrichten
    db.nearmiss = db.nearmiss or {} -- Nachrichten mit Gildenbezug, die NICHT erkannt wurden
    db.unguilded = db.unguilded or {} -- gildenlose Spieler und Gildensucher
    db.settings = db.settings or {}
    for k, v in pairs(DEFAULT_SETTINGS) do
        if db.settings[k] == nil then db.settings[k] = v end
    end
    if (db.settingsVersion or 1) < 2 then
        db.settings.zoneScanDungeons = true   -- ab 1.5.0: Dungeons standardmaessig mit scannen
        db.settingsVersion = 2
    end
    if db.settingsVersion < 3 then
        db.settings.scanCapitals = false      -- Hauptstaedte haben jetzt einen eigenen Knopf
        db.settingsVersion = 3
    end
    ns.db = db
    for _, g in pairs(db.guilds) do ns.EnsureFields(g) end
end

-- WoW Forever hat keine klassischen Realms: GetRealmName() liefert z.B. "CAMWOW EU4 Realm 7",
-- in Spielernamen steht aber der Heimat-Realm (z.B. "Treoninka"). Massgeblich ist UnitFullName.
-- WoW Forever: Es gibt keine Realms im klassischen Sinn - Spieler haben VOR- UND NACHNAMEN
-- ("Fdtd Waechter", "Craphunt Qt"). Je nach Quelle liefert WoW den Nachnamen unterschiedlich:
--   Chat:            "Fdtd Waechter"           (mit Leerzeichen)
--   UnitName/Who/...: "Azuryss", "Stormweaver"  (Nachname im Realm-Feld -> "Azuryss-Stormweaver")
-- Einheitliche Schreibweise in CBAS: "Vorname Nachname". Der Server-Name (GetRealmName, z.B.
-- "CAMWOW EU4 Realm 7") ist der einzige echte "Realm" und wird nie an Namen gehaengt.
function ns.MyRealm()
    if ns.myRealm then return ns.myRealm end
    local r = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName())
    if not r or r == "" then return "?" end
    ns.myRealm = r:gsub("[%s%-]", "")
    return ns.myRealm
end

-- eigener Nachname (Forever liefert ihn bei UnitFullName im Realm-Feld)
function ns.MySurname()
    if ns.mySurname ~= nil then return ns.mySurname or nil end
    local _, s = UnitFullName and UnitFullName("player")
    if s and s ~= "" then ns.mySurname = s; return s end
    return nil
end

-- Name + "Realm"-Feld einer API -> "Vorname Nachname"
function ns.FullName(name, realm)
    if type(name) ~= "string" then return name end
    if not realm or realm == "" then return ns.NormFull(name) end
    local r = realm:gsub("[%s%-]", "")
    if ns.realmAliases and ns.realmAliases[r] then return ns.NormFull(name) end
    return ns.NormFull(name .. " " .. realm)
end

-- Anzeige-Name und "Realm" (es gibt keinen -> immer der eigene Server, damit nie etwas angehaengt wird)
function ns.SplitName(full)
    if type(full) ~= "string" then return full, ns.MyRealm() end
    return ns.NormFull(full), ns.MyRealm()
end

-- Alle Schreibweisen des Servers (nur der echte Server-Name, NIE ein Nachname)
function ns.BuildRealmAliases()
    local a = {}
    local function add(r)
        if type(r) == "string" and r ~= "" then
            a[r] = true
            a[(r:gsub("[%s%-]", ""))] = true
        end
    end
    add(GetNormalizedRealmName and GetNormalizedRealmName())
    add(GetRealmName and GetRealmName())
    ns.realmAliases = a
end

-- Einheitlicher Spielername "Vorname Nachname"
function ns.NormFull(full)
    if type(full) ~= "string" or full == "" then return full end
    local a, b = full:match("^(.-)%-([^%-]+)$")
    if not a or a == "" then return full end
    local rb = b:gsub("%s", "")
    if ns.realmAliases and ns.realmAliases[rb] then return a end          -- echter Server-Name: weg
    if a:find(" ", 1, true) then
        -- "Vorname Nachname-XY": XY ist ein Altlast-Anhang (frueher eigener Nachname als "Realm")
        return a
    end
    return a .. " " .. b                                                   -- "Azuryss-Stormweaver" -> "Azuryss Stormweaver"
end

-- Doppelte Spieler zusammenfuehren (gleicher Name, andere Realm-Schreibweise)
function ns.DedupePlayers()
    local db = ns.db
    local best = {}   -- full -> { key, m }
    for key, g in pairs(db.guilds) do
        local newMembers = {}
        for full, m in pairs(g.members) do
            local nf = ns.NormFull(full)
            local ex = newMembers[nf]
            if ex then
                -- neuere Daten gewinnen, fehlende Felder ergaenzen
                local newer, older = m, ex
                if (ex.seen or 0) > (m.seen or 0) then newer, older = ex, m end
                for k, v in pairs(older) do if newer[k] == nil then newer[k] = v end end
                newMembers[nf] = newer
            else
                newMembers[nf] = m
            end
        end
        g.members = newMembers
        if g.leader then g.leader = ns.NormFull(g.leader) end
        if g.recruit and g.recruit.recruiters then
            local r2 = {}
            for full, v in pairs(g.recruit.recruiters) do r2[ns.NormFull(full)] = v end
            g.recruit.recruiters = r2
        end
        if g.recruit and g.recruit.lastFrom then g.recruit.lastFrom = ns.NormFull(g.recruit.lastFrom) end
        -- ein Spieler kann nur in einer Gilde sein: die neueste Sichtung gewinnt
        for full, m in pairs(g.members) do
            local b = best[full]
            if not b or (m.seen or 0) > (b.m.seen or 0) then
                if b then db.guilds[b.key].members[full] = nil end
                best[full] = { key = key, m = m }
            else
                g.members[full] = nil
            end
        end
    end
    db.players = {}
    for full, b in pairs(best) do db.players[full] = b.key end
    for _, g in pairs(db.guilds) do
        local n = 0
        for _ in pairs(g.members) do n = n + 1 end
        g.memberCount = n
    end
    local p2 = {}
    for full, list in pairs(db.pending) do
        local nf = ns.NormFull(full)
        if not p2[nf] then p2[nf] = list end
    end
    db.pending = p2
end

function ns.EnsureFields(g)
    g.members = g.members or {}
    g.memberCount = g.memberCount or 0
    g.maxRankIndex = g.maxRankIndex or 0
    g.ranks = g.ranks or {}
    g.recruit = g.recruit or {}
    g.recruit.count = g.recruit.count or 0
    g.recruit.msgs = g.recruit.msgs or {}
    g.loot = g.loot or {}
    g.tags = g.tags or {}
    g.wanted = g.wanted or {}
    g.instances = g.instances or {}
    g.notes = g.notes or ""
    g.rating = g.rating or 0
    g.firstSeen = g.firstSeen or time()
    g.lastSeen = g.lastSeen or time()
end

-- Forever: eine gemeinsame Welt pro Regelwerk -> Gilden nur ueber den Namen identifizieren
function ns.GuildKey(name, realm)
    if not realm or realm == "" then realm = ns.MyRealm() end
    return name, realm
end

-- Zwei Eintraege derselben Gilde zusammenfuehren (Umstellung alter Daten)
function ns.MergeGuildInto(a, b)
    ns.EnsureFields(a); ns.EnsureFields(b)
    for full, m in pairs(b.members) do
        local am = a.members[full]
        if not am or (m.seen or 0) > (am.seen or 0) then a.members[full] = m end
    end
    local n = 0
    for _ in pairs(a.members) do n = n + 1 end
    a.memberCount = n
    local ra, rb = a.recruit, b.recruit
    for _, msg in ipairs(rb.msgs) do
        local dup = false
        for _, x in ipairs(ra.msgs) do if x.text == msg.text then dup = true break end end
        if not dup then ra.msgs[#ra.msgs + 1] = msg end
    end
    table.sort(ra.msgs, function(x, y) return x.t > y.t end)
    while #ra.msgs > 8 do table.remove(ra.msgs) end
    ra.count = math.max(ra.count or 0, rb.count or 0)
    ra.posts = (ra.posts or 0) + (rb.posts or 0)
    if (rb.last or 0) > (ra.last or 0) then ra.last, ra.lastFrom = rb.last, rb.lastFrom end
    ra.recruiters = ra.recruiters or {}
    for k, v in pairs(rb.recruiters or {}) do ra.recruiters[k] = ra.recruiters[k] or v end
    ra.finder = ra.finder or rb.finder
    for _, f in ipairs({ "loot", "tags", "ranks" }) do
        for k, v in pairs(b[f]) do if a[f][k] == nil then a[f][k] = v end end
    end
    for k, v in pairs(b.instances or {}) do
        a.instances = a.instances or {}
        if not a.instances[k] then a.instances[k] = v end
    end
    if not next(a.wanted) then a.wanted = b.wanted end
    for _, f in ipairs({ "leader", "days", "times", "statedSize", "lang", "finder", "lootManual", "factionHint" }) do
        if a[f] == nil or a[f] == "" then a[f] = b[f] end
    end
    if b.notes and b.notes ~= "" and b.notes ~= a.notes then
        a.notes = (a.notes ~= "" and (a.notes .. "\n") or "") .. b.notes
    end
    a.rating = math.max(a.rating or 0, b.rating or 0)
    a.favorite = a.favorite or b.favorite
    a.blacklist = a.blacklist or b.blacklist
    a.maxRankIndex = math.max(a.maxRankIndex or 0, b.maxRankIndex or 0)
    a.whoMaxOnline = math.max(a.whoMaxOnline or 0, b.whoMaxOnline or 0)
    a.firstSeen = math.min(a.firstSeen or time(), b.firstSeen or time())
    a.lastSeen = math.max(a.lastSeen or 0, b.lastSeen or 0)
    a.unverified = (a.memberCount == 0) and (a.unverified or b.unverified) or nil
end

-- Alte Schluessel "Gilde-Realm" auf "Gilde" umstellen
-- Einmalige Umstellung (2.19.2): Namen in allen Tabellen auf "Vorname Nachname" bringen.
-- Frueher wurde der eigene Nachname ("Qt") als Realm an fremde Namen gehaengt.
local function Rekey(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do
        local nk = type(k) == "string" and ns.NormFull(k) or k
        local ex = out[nk]
        if ex == nil then
            out[nk] = v
        elseif type(ex) == "table" and type(v) == "table" then
            local a = (v.t or v.seen or v.last or 0) > (ex.t or ex.seen or ex.last or 0) and v or ex
            local b = a == v and ex or v
            for kk, vv in pairs(b) do if a[kk] == nil then a[kk] = vv end end
            out[nk] = a
        end
    end
    return out
end

function ns.MigrateNames()
    local db = ns.db
    if (db.nameVersion or 0) >= 3 then return end
    db.unguilded = Rekey(db.unguilded)
    db.country = Rekey(db.country)
    local d = db.loot
    if d then
        d.players = Rekey(d.players)
        d.marked = Rekey(d.marked)
        for _, h in ipairs(d.history or {}) do if h.player then h.player = ns.NormFull(h.player) end end
        for _, r in pairs(d.runs or {}) do
            if type(r) == "table" then
                r.members = Rekey(r.members)
                if r.leader then r.leader = ns.NormFull(r.leader) end
            end
        end
    end
    local lp = db.settings.layerPartners
    if type(lp) == "table" then
        local seen, out = {}, {}
        for _, f in ipairs(lp) do
            local nf = ns.NormFull(f)
            if not seen[nf] then seen[nf] = true; out[#out + 1] = nf end
        end
        db.settings.layerPartners = out
    end
    for _, l in ipairs(db.chatlog or {}) do if l.from then l.from = ns.NormFull(l.from) end end
    for _, g in pairs(db.guilds) do
        for _, m in ipairs((g.recruit and g.recruit.msgs) or {}) do if m.from then m.from = ns.NormFull(m.from) end end
    end
    db.nameVersion = 3
end

function ns.MigrateKeys()
    local db = ns.db
    if db.keyVersion == 2 then return end
    local newGuilds, map = {}, {}
    for oldKey, g in pairs(db.guilds) do
        local nk = g.name or oldKey
        map[oldKey] = nk
        if newGuilds[nk] then ns.MergeGuildInto(newGuilds[nk], g) else newGuilds[nk] = g end
    end
    db.guilds = newGuilds
    for full, k in pairs(db.players) do db.players[full] = map[k] or k end
    db.keyVersion = 2
end

function ns.GetGuild(name, realm, create, source)
    if not name or name == "" then return nil end
    local key
    key, realm = ns.GuildKey(name, realm)
    local g = ns.db.guilds[key]
    if not g and create then
        g = { name = name, realm = realm, source = source }
        ns.EnsureFields(g)
        ns.db.guilds[key] = g
        ns.sessionNew = (ns.sessionNew or 0) + 1
        if ns.db.settings.notifyNew then
            ns.Print("Neue Gilde entdeckt: |cffffd100<" .. name .. ">|r")
        end
        ns.RefreshUI()
    end
    return g, key
end

function ns.AddMember(g, key, full, info)
    local db = ns.db
    full = ns.NormFull(full)
    local ug = db.unguilded and db.unguilded[full]
    if ug then
        if ug.seeking then
            -- Suchender ist jetzt in einer Gilde: zur Info behalten
            if ug.inGuild ~= g.name then
                ug.joinedGuild, ug.joinedT = g.name, time()
            end
            ug.level = info.level or ug.level
            ug.class = info.class or ug.class
            ug.zone = info.zone or ug.zone
            ug.seen = time()
        else
            db.unguilded[full] = nil
        end
    end
    local now = time()
    -- Spieler hat die Gilde gewechselt?
    local oldKey = db.players[full]
    if oldKey and oldKey ~= key then
        local og = db.guilds[oldKey]
        if og and og.members[full] then
            og.members[full] = nil
            og.memberCount = math.max(0, og.memberCount - 1)
        end
    end
    db.players[full] = key

    local m = g.members[full]
    if not m then
        m = {}
        g.members[full] = m
        g.memberCount = g.memberCount + 1
    end
    for k, v in pairs(info) do m[k] = v end
    m.seen = now
    g.lastSeen = now
    -- Online-Zeiten: je Spieler und Stunde einmal zaehlen (0 = So 0 Uhr ... 167 = Sa 23 Uhr)
    local slot = tonumber(date("%w", now)) * 24 + tonumber(date("%H", now))
    local stamp = date("%Y%m%d%H", now)
    if m.lastSlot ~= stamp then
        m.lastSlot = stamp
        g.activity = g.activity or {}
        g.activity[slot] = (g.activity[slot] or 0) + 1
    end
    if not g.region and ns.region then g.region = ns.region end
    g.unverified = nil

    -- Fraktion: direkt von der Einheit oder ueber die Rasse ableiten
    m.faction = info.faction or m.faction or ns.FactionOfRace(m.race)
    ns.UpdateGuildFaction(g)
    if info.rankIndex then
        if info.rank then g.ranks[info.rankIndex] = info.rank end
        if info.rankIndex == 0 then g.leader = full end
        if info.rankIndex > g.maxRankIndex then g.maxRankIndex = info.rankIndex end
    end

    -- Haben wir von diesem Spieler noch Rekrutierungsnachrichten ohne Gilde?
    local p = db.pending[full]
    if p then
        for _, rec in ipairs(p) do ns.ApplyRecruitMessage(g, rec) end
        db.pending[full] = nil
    end
    ns.RefreshUI()
end

---------------------------------------------------------------------------
-- Fraktion ueber Rasse bestimmen (/who und Chat liefern keine Fraktion)
---------------------------------------------------------------------------
local STATIC_RACES = {
    Alliance = { "Human", "Dwarf", "NightElf", "Gnome", "Mensch", "Menschin", "Zwerg", "Zwergin",
        "Nachtelf", "Nachtelfe", "Gnom", "Gnomin", "Night Elf" },
    Horde = { "Orc", "Scourge", "Undead", "Tauren", "Troll", "Orcin", "Untoter", "Untote",
        "Taurin", "Trollin" },
}

function ns.BuildRaceMap()
    local map = {}
    for fac, list in pairs(STATIC_RACES) do
        for _, r in ipairs(list) do map[r:lower()] = fac end
    end
    if C_CreatureInfo and C_CreatureInfo.GetRaceInfo and C_CreatureInfo.GetFactionInfo then
        for id = 1, 100 do
            local ok1, ri = pcall(C_CreatureInfo.GetRaceInfo, id)
            local ok2, fi = pcall(C_CreatureInfo.GetFactionInfo, id)
            if ok1 and ok2 and ri and fi and (fi.groupTag == "Alliance" or fi.groupTag == "Horde") then
                if ri.clientFileString then map[ri.clientFileString:lower()] = fi.groupTag end
                if ri.raceName then map[ri.raceName:lower()] = fi.groupTag end
            end
        end
    end
    ns.raceMap = map
end

function ns.FactionOfRace(race)
    if type(race) ~= "string" or not ns.raceMap then return nil end
    return ns.raceMap[race:lower()]
end

-- Mehrheit der bekannten Mitglieder entscheidet, sonst Hinweis aus dem Chat
function ns.UpdateGuildFaction(g)
    local a, h = 0, 0
    for _, m in pairs(g.members) do
        if m.faction == "Alliance" then a = a + 1 elseif m.faction == "Horde" then h = h + 1 end
    end
    if a > h then g.faction = "Alliance"
    elseif h > a then g.faction = "Horde"
    elseif g.factionHint then g.faction = g.factionHint
    end
end

function ns.RecomputeFactions()
    for _, g in pairs(ns.db.guilds) do
        for _, m in pairs(g.members) do
            if not m.faction then m.faction = ns.FactionOfRace(m.race) end
        end
        ns.UpdateGuildFaction(g)
    end
end

---------------------------------------------------------------------------
-- Gildenlose Spieler & Gildensucher
---------------------------------------------------------------------------
local UNGUILDED_MAX = 3000

local function TrimUnguilded()
    local db = ns.db
    local n = 0
    for _ in pairs(db.unguilded) do n = n + 1 end
    if n <= UNGUILDED_MAX then return end
    -- aelteste ohne Gildensuche/Notiz zuerst entfernen
    local list = {}
    for full, u in pairs(db.unguilded) do
        if not u.seeking and not u.note then list[#list + 1] = { full = full, t = u.seen or 0 } end
    end
    table.sort(list, function(a, b) return a.t < b.t end)
    for i = 1, math.min(#list, n - UNGUILDED_MAX) do db.unguilded[list[i].full] = nil end
end

-- source "who" ist zuverlaessig (Spiel meldet ausdruecklich keine Gilde),
-- "unit" wurde vorher nachgeprueft
function ns.NoteGuildless(full, info, source)
    if not ns.db or not full then return end
    local db = ns.db
    full = ns.NormFull(full)
    if full == ns.playerFull then return end
    local key = db.players[full]
    if key then
        -- war bisher in einer Gilde: hat sie offenbar verlassen
        local g = db.guilds[key]
        if g and g.members[full] then
            g.members[full] = nil
            g.memberCount = math.max(0, g.memberCount - 1)
        end
        db.players[full] = nil
        info.leftGuild = g and g.name or nil
    end
    local u = db.unguilded[full]
    if not u then
        u = { first = time() }
        db.unguilded[full] = u
        TrimUnguilded()
    end
    for k, v in pairs(info) do if v ~= nil then u[k] = v end end
    u.faction = info.faction or u.faction or ns.FactionOfRace(u.race)
    u.seen = time()
    u.src = source
    ns.RefreshUI()
end

-- Spieler schreibt im Chat, dass er eine Gilde sucht
function ns.NoteGuildSeeker(full, text, ch, class, race)
    if not ns.db or not full then return end
    local db = ns.db
    full = ns.NormFull(full)
    if full == ns.playerFull then return end
    local u = db.unguilded[full] or { first = time() }
    db.unguilded[full] = u
    u.seeking = { t = time(), text = text, ch = ch }
    u.class = u.class or class
    u.race = u.race or race
    u.faction = u.faction or ns.FactionOfRace(race)
    u.seen = time()
    -- steckt er noch in einer Gilde? Dann ist er wechselwillig
    local key = db.players[full]
    u.inGuild = key and db.guilds[key] and db.guilds[key].name or nil
    u.joinedGuild, u.joinedT = nil, nil
    if ns.db.settings.notifySeeker ~= false then
        ns.Print(string.format("|cff66ccffGildensucher:|r %s%s - %s", ns.SplitName(full),
            u.inGuild and (" (noch in <" .. u.inGuild .. ">)") or "", text:sub(1, 90)))
    end
    TrimUnguilded()
    ns.RefreshUI()
end

---------------------------------------------------------------------------
-- Einheiten scannen (Maus, Ziel, Gruppe, Namensplaketten)
---------------------------------------------------------------------------
local recentlyScanned = {}
local scannedN = 0
-- Liste der kuerzlich gesehenen Spieler klein halten (sonst waechst sie in Staedten endlos)
local function PruneScanned(now)
    scannedN = scannedN + 1
    if scannedN < 300 then return end
    scannedN = 0
    for k, t in pairs(recentlyScanned) do
        if now - t > 60 then recentlyScanned[k] = nil end
    end
end

local function ScanUnitInner(unit, force)
    if not UnitExists(unit) then return end
    if not S(UnitIsPlayer(unit)) then return end
    local name, realm = UnitName(unit)
    name, realm = S(name), S(realm)
    if not name or name == "" or name == UNKNOWNOBJECT then return end
    local full = ns.NormFull(ns.FullName(name, realm))

    local now = GetTime()
    if not force and recentlyScanned[full] and now - recentlyScanned[full] < 20 then return end
    PruneScanned(now)

    local gName, rankName, rankIndex, gRealm = GetGuildInfo(unit)
    gName, rankName, rankIndex, gRealm = S(gName), S(rankName), S(rankIndex), S(gRealm)
    if not gName or gName == "" then
        -- noch nicht geladen ODER gildenlos: nach 1,5 s nochmal pruefen
        local guid = S(UnitGUID(unit))
        if guid and not recentlyScanned[full] then
            recentlyScanned[full] = now
            local lvl = S(UnitLevel(unit))
            local _, cf = UnitClass(unit)
            local _, rf = UnitRace(unit)
            local fac = S(UnitFactionGroup(unit))
            C_Timer.After(1.5, function()
                pcall(function()
                    if S(UnitGUID(unit)) ~= guid then return end
                    local g2 = S(GetGuildInfo(unit))
                    if g2 and g2 ~= "" then ns.ScanUnit(unit, true) return end
                    -- in GScout als Gildenmitglied bekannt? Dann lieber nicht als gildenlos fuehren
                    if ns.db.players[full] then return end
                    ns.NoteGuildless(full, { level = lvl, class = S(cf), race = S(rf), faction = fac }, "unit")
                end)
            end)
        end
        return
    end
    recentlyScanned[full] = now
    if ns.db.unguilded[full] then ns.db.unguilded[full] = nil end

    local _, classFile = UnitClass(unit)
    local _, raceFile = UnitRace(unit)
    local faction = UnitFactionGroup(unit)
    local pvpTitle
    if UnitPVPName then
        local pn = S(UnitPVPName(unit))
        if pn and pn ~= name then
            local a, b = pn:find(name, 1, true)
            if a then
                pvpTitle = (pn:sub(1, a - 1) .. pn:sub(b + 1)):gsub("^%s+", ""):gsub("%s+$", "")
                if pvpTitle == "" then pvpTitle = nil end
            end
        end
    end
    local sex = S(UnitSex and UnitSex(unit))
    local info = {
        pvp = pvpTitle,
        sex = sex,
        level = S(UnitLevel(unit)),
        class = S(classFile),
        race = S(raceFile),
        rank = rankName,
        rankIndex = rankIndex,
        faction = S(faction),
    }
    local g, key = ns.GetGuild(gName, gRealm or realm, true, "unit")
    ns.AddMember(g, key, full, info)
end

function ns.ScanUnit(unit, force)
    if not ns.db then return end
    pcall(ScanUnitInner, unit, force)
end

local groupScanQueued = false
function ns.ScanGroup()
    if groupScanQueued then return end
    groupScanQueued = true
    C_Timer.After(2, function()
        groupScanQueued = false
        if InCombatLockdown() then return end
        local n = GetNumGroupMembers() or 0
        if IsInRaid() then
            for i = 1, n do ns.ScanUnit("raid" .. i) end
        else
            for i = 1, 4 do ns.ScanUnit("party" .. i) end
        end
    end)
end

---------------------------------------------------------------------------
-- /who
---------------------------------------------------------------------------
local ALLOWED_CLASSES = {
    WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true,
    SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true,
}

function ns.MaxLevel()
    return (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
end

function ns.BuildScanSteps()
    local steps = {}
    local maxLvl = ns.MaxLevel()
    local lo = 1
    while lo < maxLvl do
        local hi = math.min(lo + 9, maxLvl - 1)
        steps[#steps + 1] = lo .. "-" .. hi
        lo = hi + 1
    end
    -- Max-Level ist am vollsten -> nach Klassen aufteilen (max. 50 Treffer je /who)
    local added = 0
    ns.classNames = {}
    if GetNumClasses and GetClassInfo then
        for i = 1, GetNumClasses() do
            local className, classFile = GetClassInfo(i)
            if className and ALLOWED_CLASSES[classFile] then
                ns.classNames = ns.classNames or {}
                table.insert(ns.classNames, className)
                steps[#steps + 1] = maxLvl .. ' c-"' .. className .. '"'
                added = added + 1
            end
        end
    end
    if added == 0 then steps[#steps + 1] = tostring(maxLvl) end
    ns.scanSteps = steps
    ns.scanIndex = ns.scanIndex or 1
end

-- Restliche Sperrzeit fuer /who in Sekunden (0 = frei)
ns.WHO_COOLDOWN = 5
function ns.WhoCooldown()
    if not ns.lastWho then return 0 end
    return math.max(0, ns.WHO_COOLDOWN - (GetTime() - ns.lastWho))
end

function ns.SendWho(query, meta)
    if not (C_FriendList and C_FriendList.SendWho) then
        ns.Print("/who ist in diesem Client nicht verfuegbar.")
        return false
    end
    local now = GetTime()
    if ns.WhoCooldown() > 0 then
        ns.Print(string.format("Bitte noch %d s warten (/who-Sperre).", math.ceil(ns.WhoCooldown())))
        return false
    end
    ns.lastWho = now
    meta = meta or {}
    meta.query = query
    meta.friendsShown = FriendsFrame and FriendsFrame:IsShown()
    ns.pendingWho = meta
    C_FriendList.SendWho(query)
    if ns.UI and ns.UI.UpdateCooldowns then pcall(ns.UI.UpdateCooldowns, ns.UI) end
    return true
end

-- Ein Klick = ein /who-Schritt (Blizzard erlaubt /who nur per Tastendruck/Klick)
function ns.WhoScanStep()
    if not ns.scanSteps then ns.BuildScanSteps() end
    local q = ns.scanSteps[ns.scanIndex]
    if ns.SendWho(q, { scan = true }) then
        ns.Print(string.format("Who-Scan %d/%d: %s", ns.scanIndex, #ns.scanSteps, q))
        ns.scanIndex = ns.scanIndex + 1
        if ns.scanIndex > #ns.scanSteps then ns.scanIndex = 1 end
        ns.RefreshUI()
    end
end

function ns.WhoGuild(key)
    local g = ns.db.guilds[key]
    if not g then return end
    ns.SendWho('g-"' .. g.name .. '"', { guildKey = key })
end

function ns.PendingCount()
    local n = 0
    for _ in pairs(ns.db.pending) do n = n + 1 end
    return n
end

-- Naechsten Rekrutierer ohne bekannte Gilde per /who aufloesen
function ns.ResolveNextPending(only)
    local bestFull, bestT
    if only and ns.db.pending[only] then bestFull = only end
    for full, list in pairs(bestFull and {} or ns.db.pending) do
        local t = (list[1] and list[1].t) or 0
        if not bestT or t > bestT then bestFull, bestT = full, t end
    end
    if not bestFull then
        ns.Print("Keine unzugeordneten Rekrutierer.")
        return
    end
    local name = ns.SplitName(bestFull)
    if ns.SendWho('n-"' .. name .. '"', { pendingFull = bestFull }) then
        ns.Print("Suche Gilde von " .. bestFull .. " ...")
    end
end

local function OnWhoUpdateInner()
    local meta = ns.pendingWho
    ns.pendingWho = nil
    local n = C_FriendList.GetNumWhoResults() or 0
    local perGuild = {}
    local perInst = {}   -- guildKey -> { instKey -> Anzahl }
    local foundPending = false
    for i = 1, n do
        local info = C_FriendList.GetWhoInfo(i)
        if info then
            local full = S(info.fullName)
            local gName = S(info.fullGuildName)
            if full then
                full = ns.NormFull(full)
                local _, realm = ns.SplitName(full)
                if meta and meta.pendingFull == full then foundPending = true end
                if not gName or gName == "" then
                    ns.NoteGuildless(full, {
                        level = S(info.level), class = S(info.filename), race = S(info.raceStr),
                        zone = S(info.area), faction = ns.FactionOfRace(S(info.raceStr)),
                    }, "who")
                    if ns.db.unguilded[full] then ns.db.unguilded[full].inGuild = nil end
                end
                if gName and gName ~= "" then
                    local g, key = ns.GetGuild(gName, realm, true, "who")
                    ns.AddMember(g, key, full, {
                        level = S(info.level),
                        class = S(info.filename),
                        race = S(info.raceStr),
                        zone = S(info.area),
                    })
                    perGuild[key] = (perGuild[key] or 0) + 1
                    local lvl = S(info.level)
                    if lvl and lvl >= ns.MaxLevel() then ns.LearnZone60(S(info.area)) end
                    local inst = ns.ZoneToInstance(S(info.area))
                    if inst then
                        perInst[key] = perInst[key] or {}
                        perInst[key][inst] = (perInst[key][inst] or 0) + 1
                    end
                end
            end
        end
    end

    -- Auf welchem Layer wurde die Gilde gesehen? (fuer die Absprache mit Partnern)
    if ns.Layer and ns.Layer.cur then
        local c = ns.Layer.cur
        local lk = c.zone .. "|" .. c.key
        for key in pairs(perGuild) do
            local g = ns.db.guilds[key]
            if g then
                g.layerSeen = g.layerSeen or {}
                g.layerSeen[lk] = time()
            end
        end
    end
    if meta and ns.Layer then meta.layer = ns.Layer.cur and ns.Layer.Label(ns.Layer.cur) or nil end

    -- Instanz-Aktivitaet: wie viele Mitglieder einer Gilde stecken gleichzeitig drin?
    local now = time()
    for key, insts in pairs(perInst) do
        local g = ns.db.guilds[key]
        if g then
            for inst, cnt in pairs(insts) do ns.NoteInstanceSighting(g, inst, cnt, now) end
        end
    end
    if meta and meta.zone60 then
        local guilds, unguilded = {}, 0
        for i = 1, n do
            local info = C_FriendList.GetWhoInfo(i)
            local gn = info and S(info.fullGuildName)
            if gn and gn ~= "" then guilds[gn] = (guilds[gn] or 0) + 1 else unguilded = unguilded + 1 end
        end
        local gl = {}
        for gn, c in pairs(guilds) do gl[#gl + 1] = { name = gn, n = c } end
        table.sort(gl, function(a, b) return a.n > b.n end)
        local parts = {}
        for i = 1, math.min(5, #gl) do parts[#parts + 1] = "<" .. gl[i].name .. "> " .. gl[i].n end
        ns.Print(string.format("%s: %d Spieler auf Level %d, %d Gilden, %d gildenlos%s", meta.zone60, n, ns.MaxLevel(),
            #gl, unguilded, #parts > 0 and (" - " .. table.concat(parts, ", ")) or ""))
        if n >= 50 and not meta.split then ns.SplitZone60(meta.zone60, meta.capital) end
    end
    if meta and meta.zone then
        local list = {}
        for key, insts in pairs(perInst) do
            if insts[meta.zone] and ns.db.guilds[key] then
                list[#list + 1] = { name = ns.db.guilds[key].name, n = insts[meta.zone] }
            end
        end
        table.sort(list, function(a, b) return a.n > b.n end)
        local parts = {}
        for i = 1, math.min(6, #list) do parts[#parts + 1] = "<" .. list[i].name .. "> " .. list[i].n end
        ns.Print(string.format("%s: %d Spieler, %d Gilden%s", ns.InstanceName(meta.zone), n, #list,
            #parts > 0 and (" - " .. table.concat(parts, ", ")) or ""))
    end

    if meta then
        if meta.guildKey and ns.db.guilds[meta.guildKey] then
            local g = ns.db.guilds[meta.guildKey]
            g.whoOnline = perGuild[meta.guildKey] or 0
            g.whoTime = time()
            g.whoCapped = n >= 50 or nil
            if g.whoOnline > (g.whoMaxOnline or 0) then g.whoMaxOnline = g.whoOnline end
            ns.Print(string.format("<%s>: %d Mitglieder online%s.", g.name, g.whoOnline, g.whoCapped and " (oder mehr, /who-Limit 50)" or ""))
        end
        if meta.pendingFull then
            local p = ns.db.pending[meta.pendingFull]
            if p then
                if foundPending then
                    -- online, aber gildenlos -> verwerfen
                    ns.db.pending[meta.pendingFull] = nil
                    ns.Print(meta.pendingFull .. " ist in keiner Gilde - Eintrag verworfen.")
                else
                    p.tries = (p.tries or 0) + 1
                    if p.tries >= 3 then ns.db.pending[meta.pendingFull] = nil end
                    ns.Print(meta.pendingFull .. " ist gerade nicht online.")
                end
            end
        end
        if meta.scan then
            ns.Print(string.format("%d Spieler erfasst%s.", n, n >= 50 and " (Limit erreicht)" or ""))
        end
        -- Freundesfenster wieder schliessen, falls wir es geoeffnet haben
        if not meta.friendsShown and FriendsFrame and FriendsFrame:IsShown() and not InCombatLockdown() then
            pcall(HideUIPanel, FriendsFrame)
        end
    end
    ns.RefreshUI()
end

function ns.OnWhoUpdate()
    local ok, err = pcall(OnWhoUpdateInner)
    if not ok and ns.debug then ns.Print("Who-Fehler: " .. tostring(err)) end
end

---------------------------------------------------------------------------
-- Gildenfinder (falls im Client vorhanden)
---------------------------------------------------------------------------
function ns.ImportClubFinder()
    if not (C_ClubFinder and C_ClubFinder.ReturnMatchingGuildList) then return end
    local ok, list = pcall(C_ClubFinder.ReturnMatchingGuildList)
    if not ok or type(list) ~= "table" then return end
    local cnt = 0
    for _, info in ipairs(list) do
        local name = S(info.name)
        if name and name ~= "" then
            local g = ns.GetGuild(name, nil, true, "finder")
            local comment = S(info.comment)
            g.finder = {
                members = S(info.numActiveMembers),
                comment = comment,
                leader = S(info.guildLeader),
                minIlvl = S(info.minILvl),
                t = time(),
            }
            g.recruit.last = time()
            g.recruit.finder = true
            if comment and comment ~= "" then ns.ParseDetails(g, comment, "finder") end
            cnt = cnt + 1
        end
    end
    if cnt > 0 then ns.Print(cnt .. " Gilden aus dem Gildenfinder uebernommen.") end
    ns.RefreshUI()
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------
local function OnTooltipUnit(tooltip)
    if tooltip ~= GameTooltip or not ns.db or not ns.db.settings.tooltip then return end
    local _, unit = tooltip:GetUnit()
    unit = S(unit)
    if not unit then return end
    local gName, _, _, gRealm = GetGuildInfo(unit)
    gName, gRealm = S(gName), S(gRealm)
    if not gName then return end
    local _, realm = UnitName(unit)
    local g = ns.GetGuild(gName, gRealm or S(realm), false)
    if not g then return end
    tooltip:AddLine(ns.TooltipSummary(g), 1, 1, 1, true)
end

---------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------
function ns.Ago(t)
    if not t then return "-" end
    local d = time() - t
    if d < 3600 then return math.max(1, math.floor(d / 60)) .. "m" end
    if d < 86400 then return math.floor(d / 3600) .. "h" end
    return math.floor(d / 86400) .. "T"
end

function ns.IsRecruiting(g, days)
    return g.recruit.last and (time() - g.recruit.last) < (days or 30) * 86400
end

function ns.Stats(g)
    local maxLvl = ns.MaxLevel()
    local atMax, sum, cnt, active = 0, 0, 0, 0
    local classes = {}
    local now = time()
    for _, m in pairs(g.members) do
        if m.level and m.level > 0 then
            sum = sum + m.level
            cnt = cnt + 1
            if m.level >= maxLvl then atMax = atMax + 1 end
        end
        if m.class then classes[m.class] = (classes[m.class] or 0) + 1 end
        if m.seen and now - m.seen < 7 * 86400 then active = active + 1 end
    end
    return atMax, cnt > 0 and (sum / cnt) or 0, active, classes
end

-- Ausfuehrliche Auswertung fuers Profil
function ns.ExtStats(g)
    local maxLvl = ns.MaxLevel()
    local r = { brackets = { 0, 0, 0, 0 }, races = {}, roles = {}, pvp = {}, ilvlSum = 0, ilvlN = 0, specs = {} }
    local now = time()
    for _, m in pairs(g.members) do
        local l = m.level
        if l then
            if l >= maxLvl then r.brackets[1] = r.brackets[1] + 1
            elseif l >= maxLvl - 10 then r.brackets[2] = r.brackets[2] + 1
            elseif l >= maxLvl - 20 then r.brackets[3] = r.brackets[3] + 1
            else r.brackets[4] = r.brackets[4] + 1 end
        end
        if m.race then r.races[m.race] = (r.races[m.race] or 0) + 1 end
        if m.role then r.roles[m.role] = (r.roles[m.role] or 0) + 1 end
        if m.spec then r.specs[m.spec] = (r.specs[m.spec] or 0) + 1 end
        if m.pvp then r.pvp[m.pvp] = (r.pvp[m.pvp] or 0) + 1 end
        if m.ilvl and m.inspT and now - m.inspT < 30 * 86400 then
            r.ilvlSum = r.ilvlSum + m.ilvl
            r.ilvlN = r.ilvlN + 1
        end
    end
    return r
end

-- Online-Zeiten zusammenfassen: Tageszeit und Wochentag/Wochenende
function ns.ActivitySummary(g)
    local a = g.activity
    if not a then return nil end
    local total = 0
    for _, v in pairs(a) do total = total + v end
    if total < 5 then return nil end
    local bands = { { "Morgens", 6, 11 }, { "Mittags", 12, 16 }, { "Abends", 17, 22 }, { "Nachts", 23, 5 } }
    local bandCnt = {}
    local we, wd = 0, 0
    for slot, v in pairs(a) do
        local day, hour = math.floor(slot / 24), slot % 24
        if day == 0 or day == 6 then we = we + v else wd = wd + v end
        for i, b in ipairs(bands) do
            local inBand
            if b[2] <= b[3] then inBand = hour >= b[2] and hour <= b[3] else inBand = hour >= b[2] or hour <= b[3] end
            if inBand then bandCnt[i] = (bandCnt[i] or 0) + v end
        end
    end
    local parts = {}
    local order = {}
    for i in ipairs(bands) do order[#order + 1] = i end
    table.sort(order, function(x, y) return (bandCnt[x] or 0) > (bandCnt[y] or 0) end)
    for k = 1, 2 do
        local i = order[k]
        local pct = math.floor(100 * (bandCnt[i] or 0) / total + 0.5)
        if pct >= 15 then parts[#parts + 1] = string.format("%s %d%%", bands[i][1], pct) end
    end
    -- Wochenende hat 2 von 7 Tagen: deutlich mehr als 2/7 = Wochenend-Gilde
    local weShare = we / total
    local wtxt = weShare > 0.45 and "vor allem am Wochenende" or (weShare < 0.15 and "vor allem unter der Woche" or "über die Woche verteilt")
    -- beste Stunde
    local bestSlot, bestV = nil, 0
    for slot, v in pairs(a) do if v > bestV then bestSlot, bestV = slot, v end end
    local DAYN = { [0] = "So", "Mo", "Di", "Mi", "Do", "Fr", "Sa" }
    local peak = bestSlot and string.format("%s %d Uhr", DAYN[math.floor(bestSlot / 24)], bestSlot % 24) or nil
    return table.concat(parts, ", ") .. " · " .. wtxt .. (peak and (" · Spitze: " .. peak) or ""), total
end

function ns.LootString(g)
    if ns.LootShort then return (ns.LootShort(g)) end
    local t = {}
    for k in pairs(g.loot) do t[#t + 1] = k end
    table.sort(t)
    local s = table.concat(t, ", ")
    if g.lootManual and g.lootManual ~= "" then
        s = g.lootManual .. (s ~= "" and (" (" .. s .. ")") or "")
    end
    return s
end

local tipCache = setmetatable({}, { __mode = "k" })
function ns.TooltipSummary(g)
    local tc = tipCache[g]
    if tc and GetTime() - tc.t < 30 then return tc.s end
    local s = ns.TooltipSummaryInner(g)
    tipCache[g] = { t = GetTime(), s = s }
    return s
end
function ns.TooltipSummaryInner(g)
    local parts = {}
    if g.blacklist then parts[#parts + 1] = "|cffff4040BLACKLIST|r" end
    if g.favorite then parts[#parts + 1] = "|cffffd100Favorit|r" end
    if ns.ScoreText then
        local st, sc, label = ns.ScoreText(g)
        if sc > 0 then parts[#parts + 1] = "Leistung " .. st .. (label ~= "-" and (" " .. label) or "") end
    end
    parts[#parts + 1] = g.memberCount .. " gesehen"
    if ns.IsRecruiting(g) then
        parts[#parts + 1] = "|cff40ff40rekrutiert|r (vor " .. ns.Ago(g.recruit.last) .. ")"
    end
    local loot = ns.LootString(g)
    if loot ~= "" then parts[#parts + 1] = "Loot: " .. loot end
    if g.rating and g.rating > 0 then parts[#parts + 1] = "Wertung " .. g.rating .. "/5" end
    local s = "|cff33ccffCBAS:|r " .. table.concat(parts, " · ")
    if g.notes and g.notes ~= "" then
        s = s .. "\n|cffaaaaaa" .. g.notes:sub(1, 80) .. "|r"
    end
    return s
end

-- Haushalt beim Einloggen: Rauschen entfernen, damit die Datenbank klein bleibt.
-- Weg kommen nur Gilden mit hoechstens 1 bekannten Mitglied, die seit 45 Tagen nicht mehr gesehen
-- wurden, nie rekrutiert haben und keine Notiz/Wertung/Favorit/Blacklist haben.
function ns.Housekeep()
    local limit = time() - 45 * 86400
    local n = 0
    for key, g in pairs(ns.db.guilds) do
        local members = 0
        for _ in pairs(g.members or {}) do members = members + 1 if members > 1 then break end end
        if members <= 1 and (g.lastSeen or 0) < limit and not (g.recruit and g.recruit.last)
            and not g.favorite and not g.blacklist and (g.rating or 0) == 0 and (g.notes or "") == "" then
            for full in pairs(g.members or {}) do
                if ns.db.players[full] == key then ns.db.players[full] = nil end
            end
            ns.db.guilds[key] = nil
            n = n + 1
        end
    end
    local d = ns.db.flip
    if d and d.ledger then while #d.ledger > 1000 do table.remove(d.ledger) end end
    return n
end

-- Speicherverbrauch anzeigen (/crap mem)
function ns.MemoryReport()
    if UpdateAddOnMemoryUsage then UpdateAddOnMemoryUsage() end
    local kb = GetAddOnMemoryUsage and GetAddOnMemoryUsage(ADDON) or 0
    local g, m, u = 0, 0, 0
    for _, gg in pairs(ns.db.guilds) do g = g + 1 end
    for _ in pairs(ns.db.players) do m = m + 1 end
    for _ in pairs(ns.db.unguilded or {}) do u = u + 1 end
    ns.Print(string.format("Speicher: |cffffd100%.1f MB|r (davon Datenbank: %d Gilden, %d Spieler, %d Gildenlose). " ..
        "WoW räumt ungenutzten Speicher von selbst auf - der Wert schwankt deshalb.", kb / 1024, g, m, u))
end

function ns.Purge(days)
    local limit = time() - days * 86400
    local n = 0
    for key, g in pairs(ns.db.guilds) do
        if g.lastSeen < limit and (g.recruit.last or 0) < limit
            and not g.favorite and not g.blacklist and (g.rating or 0) == 0 and (g.notes or "") == "" then
            for full in pairs(g.members) do
                if ns.db.players[full] == key then ns.db.players[full] = nil end
            end
            ns.db.guilds[key] = nil
            n = n + 1
        end
    end
    local u = 0
    for full, e in pairs(ns.db.unguilded or {}) do
        if (e.seen or 0) < limit and not e.note then
            ns.db.unguilded[full] = nil
            u = u + 1
        end
    end
    ns.Print(n .. " alte Gilden und " .. u .. " alte gildenlose Spieler entfernt.")
    ns.RefreshUI()
end

function ns.RefreshUI() end -- wird in UI.lua ueberschrieben

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")

local function SafeRegister(e) pcall(ev.RegisterEvent, ev, e) end

ev:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON then ns.InitDB() end
    elseif event == "PLAYER_LOGIN" then
        ns.MyRealm()
        local pn, ps = UnitFullName("player")      -- Forever: ps = eigener Nachname
        if not pn then pn, ps = UnitName("player") end
        ns.playerFull = ns.FullName(pn, ps)
        ns.BuildScanSteps()
        ns.BuildRaceMap()
        ns.BuildRealmAliases()
        if GetCurrentRegionName then
            local ok, r = pcall(GetCurrentRegionName)
            if ok and type(r) == "string" and r ~= "" then ns.region = r end
        end
        ns.MigrateKeys()
        ns.DedupePlayers()
        pcall(ns.MigrateNames)
        ns.RecomputeFactions()
        pcall(ns.Housekeep)
        SafeRegister("UPDATE_MOUSEOVER_UNIT")
        SafeRegister("PLAYER_TARGET_CHANGED")
        SafeRegister("NAME_PLATE_UNIT_ADDED")
        SafeRegister("GROUP_ROSTER_UPDATE")
        SafeRegister("WHO_LIST_UPDATE")
        SafeRegister("CLUB_FINDER_CLUB_LIST_RETURNED")
        for _, e in ipairs(ns.CHAT_EVENTS) do SafeRegister(e) end
        if TooltipDataProcessor and Enum and Enum.TooltipDataType then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt)
                pcall(OnTooltipUnit, tt)
            end)
        end
        local n = 0
        for _ in pairs(ns.db.guilds) do n = n + 1 end
        ns.Print("Craphunts Blacklisted Addon Suite " .. ns.VERSION .. " geladen - " .. n .. " Gilden in der Datenbank. |cffffd100/crap|r öffnet das Fenster.")
        if ns.migratedFromGildenScout then ns.Print("Daten aus GildenScout übernommen.") end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        ns.ScanUnit("mouseover")
    elseif event == "PLAYER_TARGET_CHANGED" then
        ns.ScanUnit("target", true)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if ns.db.settings.nameplates and not InCombatLockdown() then ns.ScanUnit((...)) end
    elseif event == "GROUP_ROSTER_UPDATE" then
        ns.ScanGroup()
    elseif event == "WHO_LIST_UPDATE" then
        ns.OnWhoUpdate()
    elseif event == "CLUB_FINDER_CLUB_LIST_RETURNED" then
        ns.ImportClubFinder()
    elseif ns.CHAT_EVENT_SET and ns.CHAT_EVENT_SET[event] then
        ns.OnChat(event, ...)
    end
end)
