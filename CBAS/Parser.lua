-- CBAS (Craphunts Blacklisted Addon Suite) - Parser: erkennt Rekrutierungsnachrichten im Chat und liest Details heraus
local ADDON, ns = ...
local S = ns.S

ns.CHAT_EVENTS = {
    "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER",
    "CHAT_MSG_COMMUNITIES_CHANNEL",
}
ns.CHAT_EVENT_SET = {}
for _, e in ipairs(ns.CHAT_EVENTS) do ns.CHAT_EVENT_SET[e] = true end

local function has(low, list)
    for _, w in ipairs(list) do
        if low:find(w, 1, true) then return w end
    end
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

---------------------------------------------------------------------------
-- Erkennung "ist das eine Gilden-Rekrutierung?"
---------------------------------------------------------------------------
-- Spieler, die selbst eine Gilde suchen -> keine Rekrutierung
local NEGATIVE = {
    "suche gilde", "suche eine gilde", "suche ne gilde", "suche nach einer gilde",
    "suchen eine gilde", "lf guild", "lf gilde", "looking for a guild", "looking for guild",
    "lfguild", "recruit a friend", "werbt einen freund",
}
local STRONG = {
    "rekrut", "recruit", "verstärkung", "verstaerkung", "neue mitglieder", "new members",
    "nimmt auf", "nehmen auf", "nehmen noch", "bewerbung", "bewerbt", "bewirb",
    "mitglieder gesucht", "accepting members", "accepting new", "sucht mitglieder",
    "suchen mitglieder", "join us", "tritt uns bei",
}
local WEAK = {
    "sucht", "suchen", "suche ", "looking for", "lf ", "lfm", "apply", "wir haben platz", "noch plätze",
    "brauchen", "braucht", "need", "freuen uns", "freut sich", "willkommen", "welcome", "join",
    "beitreten", "beitritt", "meldet euch", "melde dich", "meld dich", "/w ", "whisper", "flüster",
    "anschließen", "anschliessen", "dabei sein", "mitmachen", "interesse", "interested", "invite",
    "einladung", "inv ", "aufnahme", "wir sind", "we are", "ist eine", "is a ",
}
local GUILDWORD = { "gilde", "guild", "<", "raidgilde", "levelgilde", "pvp-gilde", "raidkader", "raidteam", "raidgruppe" }
-- typische reine Gruppensuche (ohne Mitgliederbezug) -> keine Gildenwerbung
local GROUPONLY = { "%f[%w]lf%d+m", "%f[%w]lf ?%d ", "noch %d ", "%d/%d", "%f[%w]run%f[%W]", "für ein[ e]", "für die ini",
    "dungeon", "%f[%w]ini%f[%W]", "%f[%w]inis%f[%W]", "%f[%w]wts%f[%W]", "%f[%w]wtb%f[%W]", "verkaufe", "kaufe" }
local CONTEXT = {
    "mitglied", "member", "spieler", "player", "raider", "kader", "roster", "team",
    "aufbau", "stamm", "core", "neue", "weitere", "aktive", "leute", "people",
    "gleichgesinnte", "gemeinschaft", "community", "familie", "family", "verstärk", "zuwachs",
    "alle klassen", "all classes", "jede klasse", "every class", "jeder ist", "everyone",
}

local MEMBERCTX = { "member", "mitglied", "raider", "kader", "roster", "stammspieler", "gemeinschaft",
    "community", "core team", "raidteam", "raid team", "progress team" }

local function anyFind(low, list)
    for _, p in ipairs(list) do
        if low:find(p) then return p end
    end
end

-- Spieler sucht selbst eine Gilde?
local SEEKER = {
    "suche gilde", "suche eine gilde", "suche ne gilde", "suche nach einer gilde", "suchen eine gilde",
    "suche eine raidgilde", "suche raidgilde", "suche aktive gilde", "suche eine aktive gilde",
    "suche neue gilde", "suche eine neue gilde", "suche deutsche gilde", "suche eine deutsche gilde",
    "suche pvp gilde", "suche eine pvp gilde", "suche levelgilde", "suche eine levelgilde",
    "suchen gilde", "suchen eine raidgilde", "suchen neue gilde",
    "sucht gilde", "sucht eine gilde", "sucht ne gilde", "sucht raidgilde", "sucht eine raidgilde",
    "sucht neue gilde", "sucht eine neue gilde", "sucht aktive gilde", "sucht eine aktive gilde",
    "sucht eine deutsche gilde", "sucht eine pvp gilde", "is looking for a guild", "looking for an active guild",
    "lf guild", "lf gilde", "lfguild", "looking for a guild", "looking for guild", "looking for a raiding guild",
    "looking for a new guild", "lf raiding guild", "lf raid guild", "lf active guild", "guildless", "gildenlos",
}
function ns.IsGuildSeeker(low)
    return has(low, SEEKER) ~= nil
end

-- Gibt true/false und einen kurzen Grund zurueck (fuer /crap test)
function ns.IsRecruit(low, channelLow)
    if has(low, NEGATIVE) then return false, "Spieler sucht selbst eine Gilde" end
    if channelLow and (channelLow:find("rekrut", 1, true) or channelLow:find("recruit", 1, true)) then
        return true, "Rekrutierungskanal"
    end
    local strong = has(low, STRONG)
    if strong then return true, "Schlüsselwort '" .. strong .. "'" end
    local guild = has(low, GUILDWORD)
    if not guild then
        -- ohne das Wort "Gilde": Such-Wort + eindeutiger Mitgliederbezug
        local w, mc = has(low, WEAK), has(low, MEMBERCTX)
        if w and mc and not anyFind(low, GROUPONLY) then
            return true, "'" .. w .. "' + '" .. mc .. "'"
        end
        return false, "kein Gildenbezug (Gilde/guild/<Name>)"
    end
    local weak = has(low, WEAK)
    if not weak then return false, "Gildenbezug, aber kein Such-Wort" end
    if has(low, CONTEXT) then return true, "Gilde + '" .. weak .. "' + Mitgliederbezug" end
    local grp = anyFind(low, GROUPONLY)
    if grp then return false, "sieht nach Gruppensuche/Handel aus" end
    return true, "Gilde + '" .. weak .. "'"
end

---------------------------------------------------------------------------
-- Gildennamen aus Nachricht extrahieren
---------------------------------------------------------------------------
local VERBS = {
    " sucht", " rekrutiert", " is recruiting", " recruiting", " recruits",
    " is looking", " nimmt", " freut sich", " sind auf der suche", " ist auf der suche",
}
local STOPWORDS = {
    ["wir"] = true, ["we"] = true, ["ich"] = true, ["i"] = true, ["hallo"] = true,
    ["hi"] = true, ["hey"] = true, ["moin"] = true, ["servus"] = true, ["unsere gilde"] = true,
    ["our guild"] = true, ["die gilde"] = true, ["gilde"] = true, ["guild"] = true,
    ["wer"] = true, ["who"] = true, ["sie"] = true, ["er"] = true, ["man"] = true,
    ["spieler"] = true, ["raider"] = true, ["leute"] = true, ["casual"] = true, ["neue"] = true,
    ["eine"] = true, ["ein"] = true, ["alle"] = true, ["horde"] = true, ["allianz"] = true, ["alliance"] = true,
}
local PREFIXES = { "die gilde ", "gilde ", "the guild ", "guild ", "unsere gilde ", "our guild " }
local LEADS = { "gilde ", "guild ", "wir sind ", "we are ", "willkommen bei ", "welcome to ", "join " }

-- Bis zu 4 aufeinanderfolgende grossgeschriebene Woerter ab Position pos
-- (Bindewoerter wie "of", "der", "des", "the", "von" duerfen dazwischen stehen)
local JOIN = { ["of"] = true, ["the"] = true, ["der"] = true, ["des"] = true, ["von"] = true,
    ["und"] = true, ["and"] = true, ["die"] = true, ["das"] = true, ["vom"] = true, ["zur"] = true, ["zum"] = true }
local function IsCap(w)
    local b = w:byte(1)
    if not b then return false end
    if b >= 65 and b <= 90 then return true end          -- A-Z
    if b == 195 then                                     -- Ä Ö Ü (UTF-8)
        local b2 = w:byte(2)
        return b2 == 132 or b2 == 150 or b2 == 156
    end
    return false
end
local function CapWords(s, pos)
    local rest = s:sub(pos):gsub("^[\"'%s]+", "")
    local words = {}
    for w in rest:gmatch("[^%s,%.!%?:;\"]+") do
        if IsCap(w) then
            words[#words + 1] = w
        elseif #words > 0 and JOIN[w:lower()] then
            words[#words + 1] = w
        else
            break
        end
        if #words >= 4 then break end
    end
    while #words > 0 and JOIN[words[#words]:lower()] do table.remove(words) end
    if #words == 0 then return nil end
    local name = table.concat(words, " ")
    if #name < 3 or #name > 30 then return nil end
    return name
end

function ns.ExtractGuildName(clean)
    local n = clean:match("<([^<>]+)>")
    if n then
        n = trim(n)
        if #n >= 2 and #n <= 30 then return n end
    end
    n = clean:match('"([^"]+)"')
    if n then
        n = trim(n)
        if #n >= 2 and #n <= 30 then return n end
    end
    local low = clean:lower()
    -- "Gilde Eisenfaust sucht", "wir sind Nachtwache", "we are Legion of Doom"
    for _, lead in ipairs(LEADS) do
        local _, e = low:find(lead, 1, true)
        if e then
            local name = CapWords(clean, e + 1)
            if name and not STOPWORDS[name:lower()] then return name end
        end
    end
    for _, verb in ipairs(VERBS) do
        local s = low:find(verb, 1, true)
        if s and s > 2 then
            local before = clean:sub(1, s - 1)
            before = before:match("[^%.!%?:;|]+$") or before
            before = trim(before:gsub("^[%p%s]+", ""):gsub("[%p%s]+$", ""))
            local bl = before:lower()
            for _, pre in ipairs(PREFIXES) do
                if bl:sub(1, #pre) == pre then
                    before = trim(before:sub(#pre + 1))
                    bl = before:lower()
                    break
                end
            end
            local _, words = before:gsub("%S+", "")
            if bl:find("gilde$") or bl:find("guild$") then before = "" end
            if #before >= 3 and #before <= 30 and words <= 4 and not STOPWORDS[bl] then
                return before
            end
        end
    end
end

function ns.CleanText(msg)
    local t = msg
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    t = t:gsub("|H.-|h(.-)|h", "%1")
    t = t:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    t = t:gsub("{[^}]*}", "")
    t = t:gsub("%s+", " ")
    return trim(t)
end

---------------------------------------------------------------------------
-- Details: Lootsystem, Raidtage, Fokus, gesuchte Klassen ...
---------------------------------------------------------------------------
local LOOT = {
    { "gdkp", "GDKP" },
    { "%f[%w]dkp", "DKP" },
    { "epgp", "EPGP" },
    { "loot council", "Loot Council" }, { "lootcouncil", "Loot Council" },
    { "lootrat", "Loot Council" }, { "%f[%w]lc%f[%W]", "Loot Council" },
    { "soft ?res", "Soft Reserve" }, { "%f[%w]sr%f[%W]", "Soft Reserve" },
    { "hard ?res", "Hard Reserve" }, { "%f[%w]hr%f[%W]", "Hard Reserve" },
    { "ms ?> ?os", "MS>OS" }, { "ms ?/ ?os", "MS>OS" }, { "main ?spec", "MS>OS" },
    { "need ?/ ?greed", "Bedarf/Gier" }, { "bedarf", "Bedarf/Gier" },
    { "plündermeister", "Plündermeister" }, { "master ?loot", "Plündermeister" },
    { "thatsmybis", "TMB/Prio" }, { "%f[%w]tmb%f[%W]", "TMB/Prio" },
    { "prio ?liste", "TMB/Prio" }, { "loot ?prio", "TMB/Prio" },
    { "würfeln", "Würfeln" }, { "%f[%w]roll", "Würfeln" },
    { "fair ?loot", "Faires Loot" }, { "faire lootverteilung", "Faires Loot" },
}

ns.LOOT_PATTERNS = LOOT

local TAGS = {
    { { "raid", "%f[%w]mc%f[%W]", "molten core", "geschmolzene", "bwl", "pechschwingen", "blackwing",
        "onyxia", "%f[%w]ony%f[%W]", "naxx", "%f[%w]aq%d*%f[%W]", "ahn'qiraj", "%f[%w]zg%f[%W]", "zul'gurub", "progress" }, "Raid" },
    { { "hardcore", "%f[%w]hc%f[%W]", "semi%-?hc", "tryhard", "speedrun", "parse" }, "Ambitioniert" },
    { { "casual", "entspannt", "chill", "feierabend", "gemütlich", "kein zwang", "no pressure", "relaxed" }, "Casual" },
    { { "pvp", "%f[%w]bg%f[%W]", "schlachtfeld", "battleground", "ehre", "honor", "world ?pvp", "rang 14", "rank 14" }, "PvP" },
    { { "leveln", "leveling", "levelgilde", "twink", "anfänger", "neulinge", "new players", "beginner" }, "Leveln/Einsteiger" },
    { { "sozial", "social", "familiär", "familie", "family", "gemeinschaft", "community", "freundlich", "friendly" }, "Sozial" },
    { { "%f[%w]rp%f[%W]", "rollenspiel", "roleplay" }, "RP" },
    { { "18%+", "ü18", "Ü18", "erwachsen", "adult", "mature", "ü25", "Ü25", "25%+", "ü30", "Ü30", "30%+" }, "Erwachsene" },
    { { "discord" }, "Discord" },
    { { "%f[%w]ts%f[%W]", "teamspeak", "voice" }, "Voice" },
}

local CLASSWORDS = {
    { { "krieger", "warrior", "warri" }, "WARRIOR" },
    { { "paladin", "pala%f[%W]", "palas%f[%W]", "pally" }, "PALADIN" },
    { { "jäger", "jaeger", "hunter", "%f[%w]hunt%f[%W]" }, "HUNTER" },
    { { "schurke", "rogue", "schurken" }, "ROGUE" },
    { { "priester", "priest" }, "PRIEST" },
    { { "schamane", "shaman", "%f[%w]schamis?%f[%W]", "%f[%w]shamy?%f[%W]" }, "SHAMAN" },
    { { "magier", "%f[%w]mage", "%f[%w]magi%f[%W]" }, "MAGE" },
    { { "hexenmeister", "warlock", "%f[%w]hexer", "%f[%w]lock%f[%W]", "%f[%w]wl%f[%W]" }, "WARLOCK" },
    { { "druide", "druid", "%f[%w]dudu" }, "DRUID" },
    { { "%f[%w]tanks?%f[%W]" }, "TANK" },
    { { "heiler", "healer", "%f[%w]heals?%f[%W]", "%f[%w]heiler" }, "HEAL" },
    { { "%f[%w]dds?%f[%W]", "%f[%w]dps%f[%W]", "schadensverursacher", "damage dealer" }, "DPS" },
}

local DAYS = {
    { "Mo", { "montag", "monday" }, { "mo", "mon" } },
    { "Di", { "dienstag", "tuesday" }, { "di", "tue", "tues" } },
    { "Mi", { "mittwoch", "wednesday" }, { "mi", "wed" } },
    { "Do", { "donnerstag", "thursday" }, { "do", "thu", "thur", "thurs" } },
    { "Fr", { "freitag", "friday" }, { "fr", "fri" } },
    { "Sa", { "samstag", "sonnabend", "saturday" }, { "sa", "sat" } },
    { "So", { "sonntag", "sunday" }, { "so", "sun" } },
}

local function anyPattern(low, list)
    for _, p in ipairs(list) do
        if low:find(p) then return true end
    end
end

local function FindDays(low)
    local found = {}
    for _, d in ipairs(DAYS) do
        local hit = false
        for _, full in ipairs(d[2]) do
            if low:find(full, 1, true) then hit = true break end
        end
        if not hit then
            -- Abkuerzungen nur mit Trennzeichen: "Mi/Do", "Mi + So", "Di, Do"
            for _, ab in ipairs(d[3]) do
                if low:find("%f[%a]" .. ab .. "%.?%s*[/,+&]") or low:find("[/,+&]%s*" .. ab .. "%f[%A]") then
                    hit = true
                    break
                end
            end
        end
        if hit then found[#found + 1] = d[1] end
    end
    if #found > 0 then return table.concat(found, ", ") end
end

local function FindTimes(low)
    local t = low:match("%d%d?[:%.]?%d?%d?%s*%-%s*%d%d?[:%.]?%d?%d?%s*uhr")
        or low:match("%d%d?[:%.]%d%d%s*%-%s*%d%d?[:%.]%d%d")
        or low:match("%d%d?%s*%-%s*%d%d?%s*uhr")
        or low:match("ab %d%d?[:%.]?%d?%d?%s*uhr")
        or low:match("%d%d?[:%.]%d%d%s*uhr")
        or low:match("%d%d?%s*uhr")
        or low:match("%d%d?%s*[ap]m%s*%-%s*%d%d?%s*[ap]m")
        or low:match("%d%d?:%d%d%s*server")
    return t
end

-- source: "recruit", "finder", "sync" oder "none" (= keine Loot-Hinweise zaehlen, z.B. Spam-Wiederholung)
function ns.ParseDetails(g, text, source)
    source = source or "recruit"
    local low = text:lower()
    local now = time()
    if ns.ParseProgress then ns.ParseProgress(g, low) end
    local insts = ns.MatchInstances and ns.MatchInstances(low)
    if insts then
        for _, k in ipairs(insts) do ns.NoteInstanceMention(g, k, now) end
    end

    if ns.MatchLoot then
        for _, sys in ipairs(ns.MatchLoot(low)) do
            g.loot[sys] = now
            if ns.AddLootEvidence then ns.AddLootEvidence(g, sys, source, now) end
        end
    else
        for _, p in ipairs(LOOT) do
            if low:find(p[1]) then g.loot[p[2]] = now end
        end
    end
    for _, t in ipairs(TAGS) do
        if anyPattern(low, t[1]) then g.tags[t[2]] = now end
    end
    local wanted = {}
    local any = false
    for _, c in ipairs(CLASSWORDS) do
        if anyPattern(low, c[1]) then wanted[c[2]] = true; any = true end
    end
    if any then g.wanted = wanted; g.wantedTime = now end

    local days = FindDays(low)
    if days then g.days = days end
    local times = FindTimes(low)
    if times then g.times = times end

    local size = low:match("(%d+)%+?%s*mitglieder") or low:match("(%d+)%+?%s*members")
        or low:match("(%d+)%+?%s*aktive") or low:match("(%d+)%+?%s*active")
    if size and tonumber(size) and tonumber(size) < 1000 then g.statedSize = tonumber(size) end

    if ns.ApplyLanguage then ns.ApplyLanguage(g, text) end
end

---------------------------------------------------------------------------
-- Nachricht einer Gilde zuordnen
---------------------------------------------------------------------------
function ns.ApplyRecruitMessage(g, rec)
    local r = g.recruit
    local firstTime = (r.count or 0) == 0 and not r.finder
    -- Duplikate (Spam-Wiederholungen) zusammenfassen
    local dup = false
    for i, m in ipairs(r.msgs) do
        if m.text == rec.text then
            table.remove(r.msgs, i)
            dup = true
            break
        end
    end
    if not dup then r.count = (r.count or 0) + 1 end
    r.posts = (r.posts or 0) + 1
    table.insert(r.msgs, 1, rec)
    while #r.msgs > 8 do table.remove(r.msgs) end
    if not r.last or rec.t > r.last then
        r.last = rec.t
        r.lastFrom = rec.from
    end
    for _, l in ipairs(ns.db.chatlog) do
        if not l.guild and l.from == rec.from and l.text == rec.text then l.guild = g.name end
    end
    r.recruiters = r.recruiters or {}
    r.recruiters[rec.from] = { t = rec.t, class = rec.class, race = rec.race }
    if rec.race then
        local fac = ns.FactionOfRace(rec.race)
        if fac then
            g.factionHint = fac
            ns.UpdateGuildFaction(g)
        end
    end
    ns.ParseDetails(g, rec.text, dup and "none" or (rec.ch == "Sync" and "sync" or "recruit"))

    if firstTime and ns.db.settings.notifyRecruit then
        local loot = ns.LootString(g)
        ns.Print(string.format("Rekrutierende Gilde entdeckt: |cffffd100<%s>|r%s",
            g.name, loot ~= "" and (" - Loot: " .. loot) or ""))
    end
    ns.RefreshUI()
end

local lastPendingPurge = 0
local function PurgePending()
    local now = time()
    if now - lastPendingPurge < 600 then return end
    lastPendingPurge = now
    for full, list in pairs(ns.db.pending) do
        if not list[1] or now - list[1].t > 14 * 86400 then ns.db.pending[full] = nil end
    end
end

function ns.LogChat(rec, guildName, channel)
    local log = ns.db.chatlog
    table.insert(log, 1, { t = rec.t, from = rec.from, guild = guildName, text = rec.text, ch = channel })
    while #log > 150 do table.remove(log) end
    if ns.debug then
        ns.Print("Erkannt: " .. rec.from .. " -> " .. (guildName and ("<" .. guildName .. ">") or "unzugeordnet"))
    end
    ns.chatHits = (ns.chatHits or 0) + 1
end

local function OnChatInner(event, msg, sender, _, _, _, _, _, _, channelName, _, _, guid)
    if msg ~= nil and S(msg) == nil then
        ns.chatSecret = (ns.chatSecret or 0) + 1  -- vom Spiel gesperrte Nachricht
        return
    end
    msg, sender = S(msg), S(sender)
    if not msg or msg == "" then return end
    if not sender or sender == "" then
        -- Fallback: Name ueber die GUID
        local g2 = S(guid)
        if g2 and GetPlayerInfoByGUID then
            local ok, _, _, _, _, _, n, r = pcall(GetPlayerInfoByGUID, g2)
            if ok and S(n) then sender = S(r) and S(r) ~= "" and (n .. "-" .. r) or n end
        end
        if not sender then return end
    end
    ns.chatSeen = (ns.chatSeen or 0) + 1
    local link = msg:match("|HclubFinder:[^|]*|h%[(.-)%]|h")
    local clean = ns.CleanText(msg)
    local low = clean:lower()
    local chLow = S(channelName) and S(channelName):lower() or nil
    -- Lootsystem-Hinweise aus normalem Chat bekannter Gildenmitglieder ("50 DKP geboten" ...)
    if ns.MatchLoot then
        local early = ns.NormFull(sender:find("-", 1, true) and sender or ns.FullName(sender))
        local gk = ns.db.players[early]
        local gg = gk and ns.db.guilds[gk]
        if gg then
            ns.lootChatSeen = ns.lootChatSeen or {}
            for _, sys in ipairs(ns.MatchLoot(low)) do
                local k = early .. "|" .. sys
                if not ns.lootChatSeen[k] or time() - ns.lootChatSeen[k] > 6 * 3600 then
                    ns.lootChatSeen[k] = time()
                    ns.AddLootEvidence(gg, sys, "chat")
                end
            end
        end
    end
    if not link then
        local ok = ns.IsRecruit(low, chLow)
        -- Gildensucher haben Vorrang ("Priester sucht Gilde" ist keine Werbung)
        if ns.IsGuildSeeker(low) then ok = false end
        if not ok and ns.IsGuildSeeker(low) then
            -- Gildensucher merken (Klasse/Rasse ueber die GUID)
            local sc, sr
            local g2 = S(guid)
            if g2 and GetPlayerInfoByGUID then
                local okg, _, ec, _, er = pcall(GetPlayerInfoByGUID, g2)
                if okg then sc, sr = S(ec), S(er) end
            end
            local who = ns.NormFull(sender:find("-", 1, true) and sender or ns.FullName(sender))
            ns.NoteGuildSeeker(who, clean:sub(1, 255), S(channelName), sc, sr)
            return
        end
        if not ok then
            -- "Beinahe-Treffer" merken, damit man sieht, was durchrutscht
            if low:find("gilde", 1, true) or low:find("guild", 1, true) or low:find("<", 1, true)
                or low:find("rekrut", 1, true) or low:find("recruit", 1, true) then
                local nm = ns.db.nearmiss
                if not (nm[1] and nm[1].text == clean) then
                    table.insert(nm, 1, { t = time(), from = sender, text = clean:sub(1, 255) })
                    while #nm > 40 do table.remove(nm) end
                end
            end
            return
        end
    end

    -- Klasse/Rasse des Absenders ueber die GUID (gibt uns die Fraktion)
    local sClass, sRace
    guid = S(guid)
    if guid and GetPlayerInfoByGUID then
        local ok, _, englishClass, _, englishRace = pcall(GetPlayerInfoByGUID, guid)
        if ok then sClass, sRace = S(englishClass), S(englishRace) end
    end
    channelName = S(channelName)
    local chLabel = (channelName and channelName ~= "" and channelName)
        or (event == "CHAT_MSG_WHISPER" and "Flüstern")
        or (event == "CHAT_MSG_YELL" and "Schreien")
        or (event == "CHAT_MSG_SAY" and "Sagen") or "?"

    local full = ns.NormFull(sender:find("-", 1, true) and sender or ns.FullName(sender))
    local _, senderRealm = ns.SplitName(full)
    local rec = { t = time(), from = full, text = clean:sub(1, 255), ch = chLabel, class = sClass, race = sRace }

    -- 1) Absender ist bereits einer Gilde zugeordnet (zuverlaessigste Quelle)
    local key = ns.db.players[full]
    local g = key and ns.db.guilds[key]
    -- 2) Gildenlink oder Name in der Nachricht
    if not g then
        local gName
        if link then gName = trim(link:match(":%s*(.+)$") or link) end
        gName = gName or ns.ExtractGuildName(clean)
        if gName then
            g = ns.GetGuild(gName, senderRealm, true, "chat")
            if g.memberCount == 0 then g.unverified = true end
        end
    end
    ns.LogChat(rec, g and g.name, chLabel)
    if g then
        ns.ApplyRecruitMessage(g, rec)
        return
    end
    -- 3) Unbekannt: merken, bis wir den Spieler einmal sehen (Maus/Ziel/who)
    PurgePending()
    local p = ns.db.pending[full] or {}
    for i, m in ipairs(p) do
        if m.text == rec.text then table.remove(p, i) break end
    end
    table.insert(p, 1, rec)
    while #p > 3 do table.remove(p) end
    ns.db.pending[full] = p
    ns.RefreshUI()
end

ns.rawlog = {}   -- nur diese Sitzung: was kommt ueberhaupt beim Addon an?
ns.chatEvents = 0

function ns.OnChat(event, ...)
    ns.chatEvents = ns.chatEvents + 1
    if not ns.db or not ns.db.settings.chatScan then return end
    if IsInInstance() then
        ns.chatInInstance = (ns.chatInInstance or 0) + 1
        return
    end
    -- Rohprotokoll (nur lesbare Nachrichten)
    local msg, sender = ...
    local ch = select(9, ...)
    if S(msg) and S(sender) then
        table.insert(ns.rawlog, 1, { t = time(), ev = event, ch = S(ch), from = S(sender), text = ns.CleanText(tostring(S(msg))):sub(1, 200) })
        while #ns.rawlog > 40 do table.remove(ns.rawlog) end
    end
    local ok, err = pcall(OnChatInner, event, ...)
    if not ok then
        ns.chatErrors = (ns.chatErrors or 0) + 1
        ns.lastChatError = tostring(err)
        if ns.debug then ns.Print("Chat-Fehler: " .. tostring(err)) end
    end
end
