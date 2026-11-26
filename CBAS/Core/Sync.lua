-- CBAS (Craphunts Blacklisted Addon Suite) - Sync: Datenaustausch mit anderen CBAS-Nutzern in der Gruppe
local ADDON, ns = ...
local S = ns.S

local Sync = {}
ns.Sync = Sync

local PREFIX = "GScout1"
local SEP = "\031"   -- Feldtrenner
local SUB = "\030"   -- Listentrenner
local PROTO = 1

local MAX_GUILDS = 300          -- pro Durchgang hoechstens so viele Gilden senden
local MAX_MEMBERS = 30          -- Mitglieder pro Gilde
local MEMBER_MAX_AGE = 30 * 86400
local GUILD_MAX_AGE = 45 * 86400
local MSG_MAX = 250

local CLASS_CODE = {
    WARRIOR = "WA", PALADIN = "PA", HUNTER = "HU", ROGUE = "RO", PRIEST = "PR",
    SHAMAN = "SH", MAGE = "MA", WARLOCK = "WL", DRUID = "DR",
}
local CODE_CLASS = {}
for k, v in pairs(CLASS_CODE) do CODE_CLASS[v] = k end

Sync.peers = {}       -- Spieler mit CBAS in der Gruppe -> letzte Meldung
Sync.received = {}    -- Statistik pro Absender
Sync.queue = {}       -- Gildenschluessel, die noch gesendet werden
Sync.buffer = {}      -- fertige Nachrichten der aktuellen Gilde
Sync.sent = 0
Sync.interval = 0.5

---------------------------------------------------------------------------
-- Hilfen
---------------------------------------------------------------------------
local function clean(v)
    if v == nil then return "" end
    v = tostring(v)
    return (v:gsub("[\031\030|]", "/"))
end

local function Channel()
    if IsInRaid() then return "RAID" end
    if IsInGroup(LE_PARTY_CATEGORY_HOME or 1) then return "PARTY" end
    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
end

local function Blocked()
    return InCombatLockdown()
end

local function split(s, sep)
    local t = {}
    if not s or s == "" then return t end
    for part in (s .. sep):gmatch("(.-)" .. sep) do t[#t + 1] = part end
    return t
end

local function joinKeys(tbl)
    local t = {}
    for k in pairs(tbl or {}) do t[#t + 1] = clean(k) end
    table.sort(t)
    return table.concat(t, SUB)
end

local function Send(msg)
    local ch = Channel()
    if not ch then return false end
    local ok, res = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, ch)
    if not ok then
        Sync.fails = (Sync.fails or 0) + 1
        Sync.lastResult = "Fehler"
        return false
    end
    -- Neuere Clients geben ein Enum zurueck (0 = Erfolg), aeltere true/false
    if res == nil or res == true or res == 0 then
        Sync.okCount = (Sync.okCount or 0) + 1
        return true
    end
    Sync.fails = (Sync.fails or 0) + 1
    Sync.lastResult = tostring(res)
    return false
end

---------------------------------------------------------------------------
-- Senden
---------------------------------------------------------------------------
local function BuildGuildMessages(key)
    local g = ns.db.guilds[key]
    if not g then return {} end
    local out = {}
    local now = time()

    out[#out + 1] = table.concat({
        "G", clean(g.name), clean(g.realm), clean(g.faction), g.lastSeen or "", g.recruit.last or "",
        g.recruit.posts or 0, joinKeys(g.loot), clean(g.days), clean(g.times), clean(g.leader),
        g.whoMaxOnline or "", g.statedSize or "", clean(g.lang), g.finder and g.finder.members or "",
        g.firstSeen or "", joinKeys(g.tags), joinKeys(g.wanted),
    }, SEP):sub(1, MSG_MAX)

    -- Loot-Hinweise und Raid-Fortschritt
    local le = {}
    for sys, e in pairs(g.lootEv or {}) do
        local n = (e.recruit or 0) + (e.chat or 0) + (e.run or 0) + (e.finder or 0)
        if n > 0 then le[#le + 1] = clean(sys):gsub(":", "") .. ":" .. n end
    end
    local pr = {}
    for k, p in pairs(g.progress or {}) do pr[#pr + 1] = k .. ":" .. string.format("%.2f", p.v) .. ":" .. clean(p.txt) end
    if #le > 0 or #pr > 0 then
        out[#out + 1] = table.concat({ "L", clean(g.name), clean(g.realm), table.concat(le, SUB), table.concat(pr, SUB) }, SEP):sub(1, MSG_MAX)
    end

    -- Zusatzinfos: echte Groesse, Sprache, Laender, Region
    out[#out + 1] = table.concat({
        "X", clean(g.name), clean(g.realm),
        g.inspect and g.inspect.members or "", g.inspect and g.inspect.t or "",
        clean(g.lang), clean(g.langTag), joinKeys(g.countries), clean(g.region),
    }, SEP):sub(1, MSG_MAX)

    -- Raenge
    local ranks = {}
    for i = 0, g.maxRankIndex or 0 do
        if g.ranks[i] then ranks[#ranks + 1] = i .. ":" .. clean(g.ranks[i]):gsub(":", " ") end
    end
    if #ranks > 0 then
        out[#out + 1] = ("R" .. SEP .. clean(g.name) .. SEP .. clean(g.realm) .. SEP .. table.concat(ranks, SUB)):sub(1, MSG_MAX)
    end

    -- Mitglieder (zuletzt gesehene zuerst)
    local mem = {}
    for full, m in pairs(g.members) do
        if m.seen and now - m.seen < MEMBER_MAX_AGE then mem[#mem + 1] = { full = full, m = m } end
    end
    table.sort(mem, function(a, b)
        local ra, rb = a.m.rankIndex or 99, b.m.rankIndex or 99
        if ra ~= rb then return ra < rb end
        return a.m.seen > b.m.seen
    end)
    local head = "M" .. SEP .. clean(g.name) .. SEP .. clean(g.realm) .. SEP
    local cur = {}
    local curLen = #head
    for i = 1, math.min(MAX_MEMBERS, #mem) do
        local e = mem[i]
        local pn = ns.NormFull(e.full)
        local entry = table.concat({
            clean(pn):gsub(":", ""), e.m.level or "", CLASS_CODE[e.m.class or ""] or (e.m.class or ""),
            e.m.rankIndex or "", math.floor((now - e.m.seen) / 86400),
        }, ":")
        if curLen + #entry + 1 > MSG_MAX and #cur > 0 then
            out[#out + 1] = head .. table.concat(cur, SUB)
            cur, curLen = {}, #head
        end
        cur[#cur + 1] = entry
        curLen = curLen + #entry + 1
    end
    if #cur > 0 then out[#out + 1] = head .. table.concat(cur, SUB) end

    -- Raid-/Dungeon-Aktivitaet: key:seen:last:max:groups:mention
    local il = {}
    for k, e in pairs(g.instances or {}) do
        il[#il + 1] = table.concat({ clean(k), e.seen or "", e.last or "", e.max or "", e.groups or "", e.mention or "" }, ":")
    end
    if #il > 0 then
        out[#out + 1] = ("I" .. SEP .. clean(g.name) .. SEP .. clean(g.realm) .. SEP .. table.concat(il, SUB)):sub(1, MSG_MAX)
    end

    -- die zwei neuesten Rekrutierungstexte
    for i = 1, math.min(2, #g.recruit.msgs) do
        local m = g.recruit.msgs[i]
        local base = table.concat({ "T", clean(g.name), clean(g.realm), m.t, clean(m.from), clean(m.class), "" }, SEP)
        out[#out + 1] = base .. clean(m.text):sub(1, MSG_MAX - #base)
    end
    return out
end

function Sync:StartBroadcast()
    if not ns.db.settings.sync or not Channel() then return end
    local now = time()
    if self.active then return end
    if self.lastBroadcast and now - self.lastBroadcast < 600 then return end
    self.lastBroadcast = now

    local list = {}
    for key, g in pairs(ns.db.guilds) do
        local t = math.max(g.lastSeen or 0, g.recruit.last or 0)
        if now - t < GUILD_MAX_AGE and not g.unverified then
            -- rekrutierende Gilden zuerst, dann nach Aktualitaet
            local prio = t + (ns.IsRecruiting(g) and 10 * 86400 or 0)
            list[#list + 1] = { key = key, p = prio }
        end
    end
    table.sort(list, function(a, b) return a.p > b.p end)
    wipe(self.queue)
    wipe(self.buffer)
    for i = 1, math.min(MAX_GUILDS, #list) do self.queue[#self.queue + 1] = list[i].key end
    self.total = #self.queue
    self.done = 0
    self.sent = 0
    if self.total == 0 then return end
    self.active = true
    ns.Print(string.format("Sync: teile %d Gilden mit der Gruppe (läuft im Hintergrund).", self.total))
    self:Tick()
end

function Sync:Tick()
    if not self.active then return end
    if not Channel() or not ns.db.settings.sync then
        self.active = false
        return
    end
    if Blocked() then
        C_Timer.After(5, function() Sync:Tick() end)
        return
    end
    if #self.buffer == 0 then
        local key = table.remove(self.queue, 1)
        if not key then
            Send("E" .. SEP .. self.done)
            self.active = false
            ns.Print("Sync: alle Daten gesendet (" .. self.done .. " Gilden).")
            ns.RefreshUI()
            return
        end
        self.buffer = BuildGuildMessages(key)
        self.done = self.done + 1
    end
    local msg = self.buffer[1]
    if Send(msg) then
        table.remove(self.buffer, 1)
        self.sent = self.sent + 1
        self.interval = math.max(0.5, self.interval * 0.9)
    else
        -- gedrosselt -> langsamer werden und erneut versuchen
        self.interval = math.min(3, self.interval * 2)
        if (self.fails or 0) >= 10 and (self.okCount or 0) == 0 then
            self.active = false
            ns.Print("Sync: WoW Forever blockiert Addon-Nachrichten für diesen Account (Code " .. tostring(self.lastResult) .. ").")
            return
        end
    end
    C_Timer.After(self.interval, function() Sync:Tick() end)
end

function Sync:Hello(force)
    if not ns.db.settings.sync or not Channel() or Blocked() then return end
    local now = GetTime()
    if not force and self.lastHello and now - self.lastHello < 30 then return end
    self.lastHello = now
    local n = 0
    for _ in pairs(ns.db.guilds) do n = n + 1 end
    Send(table.concat({ "H", PROTO, ns.VERSION, n }, SEP))
end

---------------------------------------------------------------------------
-- Empfangen
---------------------------------------------------------------------------
local function validName(s) return s and #s >= 2 and #s <= 40 end

local function Stat(sender)
    local st = Sync.received[sender]
    if not st then
        st = { guilds = 0, new = 0, members = 0 }
        Sync.received[sender] = st
    end
    return st
end

local function MarkShared(g, sender)
    g.sharedBy = g.sharedBy or {}
    if not g.sharedBy[sender] then
        g.sharedBy[sender] = true
        g.shared = (g.shared or 0) + 1
    end
end

local function GetForSync(name, realm, sender)
    if not validName(name) then return end
    if realm == "" then realm = nil end
    local existed = ns.GetGuild(name, realm, false)
    local notify = ns.db.settings.notifyNew
    ns.db.settings.notifyNew = false   -- keine Chat-Flut bei Sync
    local g, key = ns.GetGuild(name, realm, true, "sync")
    ns.db.settings.notifyNew = notify
    if not existed then Stat(sender).new = Stat(sender).new + 1 end
    MarkShared(g, sender)
    return g, key
end

local function num(v) return tonumber(v) end

local function MergeG(f, sender)
    local g = GetForSync(f[2], f[3], sender)
    if not g then return end
    Stat(sender).guilds = Stat(sender).guilds + 1
    local now = time()
    local function plausible(t) return t and t > 1500000000 and t < now + 86400 end

    if f[4] == "Alliance" or f[4] == "Horde" then
        if not g.factionHint then g.factionHint = f[4] end
        ns.UpdateGuildFaction(g)
    end
    local ls = num(f[5]); if plausible(ls) and ls > (g.lastSeen or 0) then g.lastSeen = ls end
    local rl = num(f[6])
    if plausible(rl) and (not g.recruit.last or rl > g.recruit.last) then g.recruit.last = rl end
    local posts = num(f[7]); if posts and posts > (g.recruit.posts or 0) then g.recruit.posts = posts end
    for _, l in ipairs(split(f[8], SUB)) do if l ~= "" and not g.loot[l] then g.loot[l] = rl or now end end
    if (not g.days or g.days == "") and f[9] ~= "" then g.days = f[9] end
    if (not g.times or g.times == "") and f[10] ~= "" then g.times = f[10] end
    if not g.leader and validName(f[11]) then
        g.leader = ns.NormFull(f[11]:find("-", 1, true) and f[11] or ns.FullName(f[11]))
    end
    local wm = num(f[12]); if wm and wm > (g.whoMaxOnline or 0) and wm <= 500 then g.whoMaxOnline = wm end
    local ss = num(f[13]); if ss and not g.statedSize and ss < 1000 then g.statedSize = ss end
    if not g.lang and f[14] ~= "" then g.lang = f[14] end
    local fm = num(f[15]); if fm and not g.finder then g.finder = { members = fm, t = now } end
    local fs = num(f[16]); if plausible(fs) and fs < (g.firstSeen or now) then g.firstSeen = fs end
    for _, t in ipairs(split(f[17], SUB)) do if t ~= "" and not g.tags[t] then g.tags[t] = rl or now end end
    if not next(g.wanted) then
        for _, w in ipairs(split(f[18], SUB)) do if w ~= "" then g.wanted[w] = true end end
    end
end

local function MergeL(f, sender)
    local g = GetForSync(f[2], f[3], sender)
    if not g then return end
    g.lootEv = g.lootEv or {}
    for _, e in ipairs(split(f[4], SUB)) do
        local sys, n = e:match("^(.-):(%d+)$")
        n = tonumber(n)
        if sys and sys ~= "" and n and #sys <= 30 then
            local ev = g.lootEv[sys] or {}
            g.lootEv[sys] = ev
            -- fremde Hinweise zaehlen hoechstens 3x (keine Aufschaukelung bei wiederholtem Sync)
            ev.sync = math.max(ev.sync or 0, math.min(3, n))
            ev.last = ev.last or time()
        end
    end
    for _, e in ipairs(split(f[5], SUB)) do
        local k, v, txt = e:match("^(%w+):([%d%.]+):(.+)$")
        v = tonumber(v)
        if k and v and ns.RAID_TIER and ns.RAID_TIER[k] then
            g.progress = g.progress or {}
            if not g.progress[k] or v > g.progress[k].v then g.progress[k] = { v = v, txt = txt, t = time() } end
        end
    end
end

local function MergeX(f, sender)
    local g = GetForSync(f[2], f[3], sender)
    if not g then return end
    local now = time()
    local im, it = tonumber(f[4]), tonumber(f[5])
    if im and it and im > 0 and im < 2000 and it < now + 86400 then
        if not g.inspect or it > (g.inspect.t or 0) then
            g.inspect = { members = im, t = it, shared = true }
        end
        if im > (g.inspectMax or 0) then g.inspectMax = im end
    end
    local lang, tag = f[6], f[7]
    if tag and ns.LANG_NAMES[tag] and not g.langTag then g.langTag = tag; g.lang = tag end
    if lang and ns.LANG_NAMES[lang] and not g.lang then g.lang = lang end
    for _, c in ipairs(split(f[8], SUB)) do
        if c:match("^%u%u$") then
            g.countries = g.countries or {}
            g.countries[c] = true
        end
    end
    if not g.region and f[9] and f[9] ~= "" then g.region = f[9] end
end

local function MergeR(f, sender)
    local g = GetForSync(f[2], f[3], sender)
    if not g then return end
    for _, e in ipairs(split(f[4], SUB)) do
        local i, n = e:match("^(%d+):(.+)$")
        i = tonumber(i)
        if i and i < 20 then
            if not g.ranks[i] then g.ranks[i] = n end
            if i > (g.maxRankIndex or 0) then g.maxRankIndex = i end
        end
    end
end

local function MergeM(f, sender)
    local g, key = GetForSync(f[2], f[3], sender)
    if not g then return end
    local now = time()
    for _, e in ipairs(split(f[4], SUB)) do
        local pn, lvl, cls, ri, ago = e:match("^([^:]+):(%d*):(%u*):(%d*):(%d+)$")
        if pn and validName(pn) then
            local full = ns.NormFull(pn:find("-", 1, true) and pn or ns.FullName(pn))
            local seen = now - tonumber(ago) * 86400
            local m = g.members[full]
            if not m then
                local ok = true
                local oldKey = ns.db.players[full]
                if oldKey and oldKey ~= key then
                    local og = ns.db.guilds[oldKey]
                    local om = og and og.members[full]
                    if om and (om.seen or 0) >= seen then
                        ok = false   -- wir wissen Neueres
                    elseif om then
                        og.members[full] = nil
                        og.memberCount = math.max(0, og.memberCount - 1)
                    end
                end
                if ok then
                    m = { shared = true }
                    g.members[full] = m
                    g.memberCount = g.memberCount + 1
                    ns.db.players[full] = key
                    Stat(sender).members = Stat(sender).members + 1
                end
            end
            if m and (not m.seen or seen > m.seen or m.shared) then
                if lvl ~= "" then m.level = tonumber(lvl) end
                if cls ~= "" then m.class = CODE_CLASS[cls] or cls end
                if ri ~= "" then
                    m.rankIndex = tonumber(ri)
                    if m.rankIndex == 0 and not g.leader then g.leader = full end
                    if m.rankIndex > (g.maxRankIndex or 0) then g.maxRankIndex = m.rankIndex end
                    if g.ranks[m.rankIndex] then m.rank = g.ranks[m.rankIndex] end
                end
                if not m.seen or seen > m.seen then m.seen = seen end
            end
        end
    end
    if g.memberCount > 0 then g.unverified = nil end
end

local function MergeI(f, sender)
    local g = GetForSync(f[2], f[3], sender)
    if not g then return end
    local now = time()
    g.instances = g.instances or {}
    for _, e in ipairs(split(f[4], SUB)) do
        local k, seen, last, mx, groups, mention = e:match("^(%w+):(%d*):(%d*):(%d*):(%d*):(%d*)$")
        if k and ns.INSTANCE_BY_KEY[k] then
            local ie = g.instances[k] or {}
            g.instances[k] = ie
            seen, mention = tonumber(seen), tonumber(mention)
            if seen and seen < now + 86400 and seen > (ie.seen or 0) then
                ie.seen = seen
                ie.last = tonumber(last) or ie.last
            end
            mx = tonumber(mx); if mx and mx > (ie.max or 0) then ie.max = mx end
            groups = tonumber(groups); if groups and groups > (ie.groups or 0) then ie.groups = groups end
            if mention and mention < now + 86400 and mention > (ie.mention or 0) then ie.mention = mention end
        end
    end
end

local function MergeT(f, sender)
    local g = GetForSync(f[2], f[3], sender)
    if not g then return end
    local t = num(f[4])
    local text = f[7]
    if not t or not text or text == "" then return end
    local r = g.recruit
    for _, m in ipairs(r.msgs) do
        if m.text == text then return end
    end
    r.msgs[#r.msgs + 1] = { t = t, from = f[5], class = f[6] ~= "" and f[6] or nil, text = text, ch = "Sync" }
    table.sort(r.msgs, function(a, b) return a.t > b.t end)
    while #r.msgs > 8 do table.remove(r.msgs) end
    r.count = math.max(r.count or 0, #r.msgs)
    r.recruiters = r.recruiters or {}
    if validName(f[5]) and not r.recruiters[f[5]] then r.recruiters[f[5]] = { t = t } end
    if not r.last or t > r.last then r.last = t end
    ns.ParseDetails(g, text, "sync")
end

function Sync:OnAddonMessage(prefix, text, channel, sender)
    if prefix ~= PREFIX then return end
    text, sender = S(text), S(sender)
    if not text or not sender or not ns.db.settings.sync then return end
    sender = ns.NormFull(sender:find("-", 1, true) and sender or ns.FullName(sender))
    if sender == ns.playerFull then return end

    local f = split(text, SEP)
    local t = f[1]
    local ok, err = pcall(function()
        if t == "H" then
            local isNew = not self.peers[sender]
            self.peers[sender] = { t = time(), version = f[3], guilds = tonumber(f[4]) }
            if isNew then
                ns.Print(string.format("Sync: %s nutzt CBAS (%s Gilden).", ns.SplitName(sender), f[4] or "?"))
                self:Hello(true)      -- antworten, damit er uns auch kennt
                -- neuer Partner: erneut senden, sofern der letzte Durchgang > 5 Min. her ist
                if self.lastBroadcast and time() - self.lastBroadcast > 300 then self.lastBroadcast = nil end
                C_Timer.After(3 + math.random() * 5, function() Sync:StartBroadcast() end)
            end
        elseif t == "G" then MergeG(f, sender)
        elseif t == "R" then MergeR(f, sender)
        elseif t == "M" then MergeM(f, sender)
        elseif t == "T" then MergeT(f, sender)
        elseif t == "I" then MergeI(f, sender)
        elseif t == "X" then MergeX(f, sender)
        elseif t == "L" then MergeL(f, sender)
        elseif t == "E" then
            local st = Stat(sender)
            ns.Print(string.format("Sync von %s fertig: %d Gilden (%d neu), %d neue Spieler.",
                ns.SplitName(sender), st.guilds, st.new, st.members))
        end
    end)
    if not ok and ns.debug then ns.Print("Sync-Fehler: " .. tostring(err)) end
    ns.RefreshUI()
end

function Sync:StatusText()
    local n = 0
    for _ in pairs(self.peers) do n = n + 1 end
    if not ns.db.settings.sync then return "Sync aus" end
    if (self.fails or 0) >= 5 and (self.okCount or 0) == 0 then
        return "Sync vom Spiel blockiert (Code " .. tostring(self.lastResult) .. ")"
    end
    if self.active then
        return string.format("Sync: sende %d/%d", self.done or 0, self.total or 0)
    end
    if not Channel() then return "Sync: keine Gruppe" end
    return "Sync: " .. n .. " Partner"
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
            ev:RegisterEvent("CHAT_MSG_ADDON")
            ev:RegisterEvent("GROUP_ROSTER_UPDATE")
            ev:RegisterEvent("PLAYER_REGEN_ENABLED")
            if IsInGroup() then C_Timer.After(10, function() Sync:Hello() end) end
        end
    elseif event == "CHAT_MSG_ADDON" then
        Sync:OnAddonMessage(...)
    elseif event == "GROUP_ROSTER_UPDATE" then
        if not IsInGroup() then
            wipe(Sync.peers)
            Sync.active = false
            return
        end
        -- kurz warten, bis sich die Gruppe gefuellt hat
        if not Sync.helloQueued then
            Sync.helloQueued = true
            C_Timer.After(8, function()
                Sync.helloQueued = false
                Sync:Hello()
            end)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if IsInGroup() and not next(Sync.peers) then Sync:Hello() end
    end
end)
