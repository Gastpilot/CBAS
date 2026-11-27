-- CBAS - Tracker (Lage > Tracker): Was ist heute und diese Woche erledigt?
-- Automatisch (hakt sich selbst ab):
--   Heute: Auktionshaus besucht, GScout-Scans (Ziel einstellbar), Mage-Vorrat (nur Magier)
--   Woche: Raid-IDs aus dem Spiel (Fortschritt "3/10", ZG/AQ20 mit eigenem 3-Tage-Reset)
--   Quests: die wechselnde Pix-Xizzix-Weekly in Beutebucht (ab 60, mit den drei Dungeons) und JEDE angenommene
--   Daily/Weekly (das Spiel meldet, ob taeglich oder woechentlich) - abgehakt ueber das Spiel.
-- Eigene Aufgaben: Text (oder Quest-ID / Wowhead-Link) + taeglich/woechentlich.
-- Zurueckgesetzt wird zum Server-Reset (GetQuestResetTime / C_DateAndTime.GetSecondsUntilWeeklyReset).
-- Haken und Zaehler gelten je Charakter, die Liste eigener Aufgaben fuer alle Charaktere.
-- Leichtgewichtig: Raid-IDs 10 s zwischengespeichert, Ansicht rechnet nur, wenn sie offen ist.
local ADDON, ns = ...
local TR = {}
ns.Tracker = TR

local MAX_TASKS = 20
local unpack = unpack or table.unpack

---------------------------------------------------------------------------
-- Daten
---------------------------------------------------------------------------
local function CharKey()
    local nm, rl = UnitName("player")
    if UnitFullName then
        local n2, r2 = UnitFullName("player")
        nm, rl = n2 or nm, r2 or rl
    end
    return ns.NormFull(ns.FullName(ns.S(nm) or "?", ns.S(rl)))
end

-- Sekunden bis zum naechsten Reset (mit Ersatz, falls die API fehlt: 05:00 bzw. Mittwoch 05:00)
function TR.UntilDaily()
    if GetQuestResetTime then
        local ok, s = pcall(GetQuestResetTime)
        if ok and tonumber(s) and s > 0 then return s end
    end
    local t = date("*t")
    local secs = t.hour * 3600 + t.min * 60 + t.sec
    local d = 5 * 3600 - secs
    if d <= 0 then d = d + 86400 end
    return d
end

function TR.UntilWeekly()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local ok, s = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
        if ok and tonumber(s) and s > 0 then return s end
    end
    local t = date("*t")                 -- wday: 1 = Sonntag ... 4 = Mittwoch
    local days = (4 - t.wday) % 7
    local d = days * 86400 + TR.UntilDaily()
    if d > 7 * 86400 then d = d - 7 * 86400 end
    return d
end

function TR.db()
    local db = ns.db
    db.tracker = db.tracker or {}
    local t = db.tracker
    t.tasks = t.tasks or {}
    t.chars = t.chars or {}
    t.scanGoal = t.scanGoal or 10
    t.nextId = t.nextId or 1
    local key = CharKey()
    local c = t.chars[key]
    if not c then
        c = { done = {}, raids = {}, scans = 0 }
        t.chars[key] = c
    end
    c.done, c.raids = c.done or {}, c.raids or {}
    -- Resets
    local now = time()
    if not c.dayEnd or now >= c.dayEnd then
        for _, task in ipairs(t.tasks) do if task.period == "day" then c.done[task.id] = nil end end
        c.scans, c.ah = 0, nil
        c.dayEnd = now + TR.UntilDaily()
    end
    if not c.weekEnd or now >= c.weekEnd then
        for _, task in ipairs(t.tasks) do if task.period == "week" then c.done[task.id] = nil end end
        c.weekEnd = now + TR.UntilWeekly()
    end
    -- alte Charaktere nicht ewig mitschleppen (60 Tage)
    c.seen = now
    return t, c
end

---------------------------------------------------------------------------
-- Quests: fest eingebaute Forever-Quests und Abfragen beim Spiel
---------------------------------------------------------------------------
-- Feste Quests ausser Pix (derzeit keine; Format: { quest, period, minLevel, text, hint })
TR.QUESTS = {}

---------------------------------------------------------------------------
-- Pix Xizzix (Beutebucht, 28.4/75.8): Stufe-60-Weekly "In Demand", wechselt jede Woche.
-- Je drei Teile von Endbossen dreier Dungeons. Belohnung: Undermine Satchel (10-100 Gold).
-- Unbekannte neue Versionen lernt CBAS selbst (NPC-Name + Quest-Ziele aus dem Spiel).
---------------------------------------------------------------------------
TR.PIX_NPC = "Pix Xizzix"
TR.PIX = {
    [96076] = { name = "Ancient Elven Curiosities", short = "Düsterbruch", parts = {
        { where = "Düsterbruch Ost",  boss = "Alzzin der Wildformer", item = "Felvine Seed" },
        { where = "Düsterbruch West", boss = "Prinz Tortheldrin",     item = "Ancient Memento" },
        { where = "Düsterbruch Nord", boss = "König Gordok",          item = "Earthstone Diamond Pinky Ring" } },
      tip = "West und Nord brauchen den Mondsichelschlüssel (droppt Pusillin in Ost)." },
    [96075] = { name = "Blackrock Legal Records", short = "Schwarzfels", parts = {
        { where = "Obere Schwarzfelsspitze",  boss = "General Drakkisath",         item = "Nefarion's Remit" },
        { where = "Untere Schwarzfelsspitze", boss = "Oberanführer Wyrmthalak",    item = "Overseer's License" },
        { where = "Schwarzfelstiefen",        boss = "Imperator Dagran Thaurissan", item = "Bronzebeard Wedding Contract" } } },
    [96087] = { name = "Plague Records", short = "Scholo & Strat", parts = {
        { where = "Scholomance",          boss = "Dunkelmeister Gandling",      item = "Headmaster's Records" },
        { where = "Stratholme (Untot)",   boss = "Baron Totenschwur",           item = "Grain Shipment Records" },
        { where = "Stratholme (Lebend)",  boss = "Grand Crusader Dathrohan",    item = "Dathrohan's Correspondence" } } },
    [96088] = { name = "Titan Relics", short = "Tempel, Blackmaw, Terrasse", parts = {
        { where = "Versunkener Tempel",    boss = "Schemen von Eranikus", item = "Ysera's Tear" },
        { where = "Blackmaw Hold",         boss = "Varrox Bleakhoof",     item = "Mark of Xavius" },
        { where = "Terrasse des Formers",  boss = "Nanaya",               item = "Freya's Sigil" } } },
}
-- bekannte Wochen (Beginn des Wochen-Resets, Ortszeit) - nur Startwert, danach lernt CBAS selbst
TR.PIX_SEEN = {
    { from = time({ year = 2026, month = 11, day = 26, hour = 3 }), id = 96088 },   -- Titan Relics (EU-Reset 26.11.)
}

local function QuestDone(id)
    local f = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted
    if not f then return false end
    local ok, v = pcall(f, id)
    return ok and v and true or false
end
TR.QuestDone = QuestDone

local function QuestInLog(id)
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local ok, i = pcall(C_QuestLog.GetLogIndexForQuestID, id)
        return ok and i ~= nil
    end
    return false
end

-- Quest-Ziele aus dem Questlog: { {text, finished}, ... } oder nil (nicht im Log)
function TR.Objectives(id)
    if not (C_QuestLog and C_QuestLog.GetQuestObjectives) or not QuestInLog(id) then return nil end
    local ok, list = pcall(C_QuestLog.GetQuestObjectives, id)
    if not ok or type(list) ~= "table" then return nil end
    local out = {}
    for i, o in ipairs(list) do
        out[i] = { text = ns.S(o.text), finished = ns.S(o.finished) and true or false }
    end
    return out
end

function TR.QuestTitle(id)
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, t = pcall(C_QuestLog.GetTitleForQuestID, id)
        t = ok and ns.S(t)
        if type(t) == "string" and t ~= "" then return t end
    end
end

-- "96076", "quest=96076", Wowhead-Link -> 96076
function TR.ParseQuestID(text)
    if type(text) ~= "string" then return nil end
    local id = text:match("quest=(%d+)") or text:match("^%s*(%d%d%d+)%s*$")
    return tonumber(id)
end

-- taeglich/woechentlich laut Spiel (nil = keine Wiederholungsquest)
function TR.QuestPeriod(id)
    if not (C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetInfo) then return nil end
    local ok, i = pcall(C_QuestLog.GetLogIndexForQuestID, id)
    if not ok or not i then return nil end
    local ok2, info = pcall(C_QuestLog.GetInfo, i)
    if not ok2 or type(info) ~= "table" then return nil end
    local f = tonumber(ns.S(info.frequency))
    if f == 1 then return "day" end
    if f == 2 then return "week" end
    if f == 3 then return "week" end   -- ResetByScheduler: wie woechentlich behandeln
    return nil
end

function TR.FindQuestTask(id)
    for _, task in ipairs(TR.db().tasks) do if task.quest == id then return task end end
end

function TR.AddTask(text, period, questID)
    local t = TR.db()
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    questID = questID or TR.ParseQuestID(text)
    if questID then
        for _, q in ipairs(TR.QUESTS) do if q.quest == questID then return nil, "Diese Quest ist schon fest im Tracker." end end
        if TR.IsPix and TR.IsPix(questID) then return nil, "Die Pix-Weekly ist schon fest im Tracker." end
        if TR.FindQuestTask(questID) then return nil, "Diese Quest steht schon im Tracker." end
        if text == "" or TR.ParseQuestID(text) then text = TR.QuestTitle(questID) or ("Quest " .. questID) end
    end
    if text == "" then return nil, "Bitte einen Text eingeben." end
    if #t.tasks >= MAX_TASKS then return nil, "Höchstens " .. MAX_TASKS .. " eigene Aufgaben." end
    local task = { id = t.nextId, text = text:sub(1, 60), period = period == "week" and "week" or "day", quest = questID }
    t.nextId = t.nextId + 1
    table.insert(t.tasks, task)
    TR.Changed()
    return task
end

function TR.RemoveTask(id)
    local t = TR.db()
    for i, task in ipairs(t.tasks) do
        if task.id == id then table.remove(t.tasks, i) break end
    end
    for _, c in pairs(t.chars) do if c.done then c.done[id] = nil end end
    TR.Changed()
end

function TR.ToggleTask(id)
    local _, c = TR.db()
    c.done[id] = (not c.done[id]) or nil
    TR.Changed()
end

function TR.ToggleRaid(key)
    local _, c = TR.db()
    c.raids[key] = (not c.raids[key]) or nil
    TR.Changed()
end

---------------------------------------------------------------------------
-- Raid-IDs aus dem Spiel
---------------------------------------------------------------------------
local raidCache = { t = -100 }
local function RaidByName(name)
    if type(name) ~= "string" then return nil end
    local low = name:lower()
    for _, inst in ipairs(ns.INSTANCES or {}) do
        if inst.kind == "raid" and (low == inst.de:lower() or low == inst.en:lower()) then return inst end
    end
end

-- key -> { done, total, reset (Sekunden), name }; bekannte Raids unter ihrem Kuerzel (MC, BWL ...),
-- neue Forever-Raids (z. B. Hyjal) unter ihrem Namen aus dem Spiel
function TR.Lockouts()
    if GetTime() - raidCache.t < 10 then return raidCache.list end
    local list = {}
    if GetNumSavedInstances and GetSavedInstanceInfo then
        local ok, n = pcall(GetNumSavedInstances)
        for i = 1, (ok and tonumber(n) or 0) do
            local ok2, name, _, reset, _, locked, _, _, isRaid, _, _, numEnc, encProg = pcall(GetSavedInstanceInfo, i)
            name = ok2 and ns.S(name)
            if ok2 and locked and type(name) == "string" then
                local inst = RaidByName(name)
                if inst or ns.S(isRaid) then
                    list[inst and inst.key or name] = { done = tonumber(ns.S(encProg)) or 0, total = tonumber(ns.S(numEnc)) or 0,
                        reset = tonumber(ns.S(reset)) or 0, name = inst and inst.de or name, known = inst ~= nil }
                end
            end
        end
    end
    raidCache = { t = GetTime(), list = list }
    return list
end
function TR.DirtyRaids() raidCache.t = -100 end

---------------------------------------------------------------------------
-- Alle Eintraege: { id, text, detail, done, auto, period, task, raid }
---------------------------------------------------------------------------
local function Dur(s)
    s = math.max(0, math.floor(s or 0))
    if s >= 86400 then return math.floor(s / 86400) .. " T. " .. math.floor((s % 86400) / 3600) .. " Std." end
    if s >= 3600 then return math.floor(s / 3600) .. " Std. " .. math.floor((s % 3600) / 60) .. " Min." end
    return math.max(1, math.floor(s / 60)) .. " Min."
end
TR.Dur = Dur

function TR.Items()
    local t, c = TR.db()
    local day, week = {}, {}
    -- Heute: automatisch
    day[#day + 1] = { id = "ah", text = "Auktionshaus besucht", auto = true, done = c.ah ~= nil,
        detail = c.ah and date("%H:%M", c.ah) or "noch nicht" }
    day[#day + 1] = { id = "scan", text = "GScout-Scans", auto = true, done = (c.scans or 0) >= t.scanGoal,
        detail = (c.scans or 0) .. "/" .. t.scanGoal }
    local MG = ns.Mage
    if MG and MG.IsMage() then
        local st, m = MG.Stock(), MG.db()
        local stacks = st.water / MG.STACK
        if st.waterSpell then
            day[#day + 1] = { id = "mage", text = "Mage: Wasser-Vorrat", auto = true, done = stacks >= m.keepWater,
                detail = string.format("%.1f/%d Stacks", stacks, m.keepWater) }
        end
    end
    -- Quests: fest eingebaute (ab Mindeststufe)
    local level = UnitLevel and tonumber(ns.S(UnitLevel("player"))) or 0
    for _, q in ipairs(TR.QUESTS) do
        if level >= (q.minLevel or 0) then
            local done = QuestDone(q.quest)
            local e = { id = "q" .. q.quest, text = TR.QuestTitle(q.quest) or q.text, auto = true, done = done, questHint = q.hint }
            if not done then
                e.partial = QuestInLog(q.quest)
                e.detail = e.partial and "im Questlog" or "noch nicht angenommen"
            end
            if q.period == "week" then week[#week + 1] = e else day[#day + 1] = e end
        end
    end
    -- Heute: Mage-Studieren (nur Info)
    TR.StudyItems(day)
    -- Woche: Pix-Xizzix-Weekly (wechselt jede Woche)
    TR.PixItems(week)
    -- Woche: Field of Honor + Rangpunkte-Grenze
    TR.FoHItems(week)
    -- Woche: Raids (gemerkte + alle mit aktueller ID)
    local lock = TR.Lockouts()
    local function RaidEntry(key, label, l)
        local done = l and l.total > 0 and l.done >= l.total
        local det
        if l then
            det = (l.total > 0 and (l.done .. "/" .. l.total) or "ID") .. " · Reset " .. Dur(l.reset)
        else
            det = "offen"
        end
        return { id = "raid:" .. key, raid = key, text = label, auto = true, done = done and true or false,
            partial = l and not done, detail = det }
    end
    for _, inst in ipairs(ns.INSTANCES or {}) do
        if inst.kind == "raid" and (c.raids[inst.key] or lock[inst.key]) then
            week[#week + 1] = RaidEntry(inst.key, inst.de, lock[inst.key])
        end
    end
    for key, l in pairs(lock) do
        if not l.known then week[#week + 1] = RaidEntry(key, l.name, l) end
    end
    -- eigene Aufgaben (Quest-Aufgaben hakt das Spiel ab)
    for _, task in ipairs(t.tasks) do
        local e = { id = task.id, text = task.text, task = task }
        if task.quest then
            e.auto = true
            e.done = QuestDone(task.quest)
            if not e.done then
                e.partial = QuestInLog(task.quest)
                e.detail = e.partial and "im Questlog" or "offen"
            end
            -- Titel nachtragen, sobald das Spiel ihn kennt
            if task.text:match("^Quest %d+$") then
                local title = TR.QuestTitle(task.quest)
                if title then task.text = title:sub(1, 60); e.text = task.text end
            end
        else
            e.done = c.done[task.id] and true or false
        end
        if task.period == "week" then week[#week + 1] = e else day[#day + 1] = e end
    end
    return day, week, c
end

function TR.Count(list)
    local d, n = 0, 0
    for _, e in ipairs(list) do
        if not e.sub and not e.info then
            n = n + 1
            if e.done then d = d + 1 end
        end
    end
    return d, n
end

---------------------------------------------------------------------------
-- Lage-Zeile
---------------------------------------------------------------------------
function TR.HomeRow()
    local day, week, c = TR.Items()
    local dd, dn = TR.Count(day)
    local wd, wn = TR.Count(week)
    local open = {}
    for _, e in ipairs(day) do if not e.done and not e.sub and not e.info then open[#open + 1] = e.text end end
    for _, e in ipairs(week) do if not e.done and not e.sub and not e.info then open[#open + 1] = e.text end end
    local Hx = ns.T.HEX
    local r = { cat = "Tracker", target = "tracker" }
    r.title = string.format("Heute %d/%d  ·  Woche %d/%d erledigt", dd, dn, wd, wn)
    local untilDay = (c.dayEnd or time()) - time()
    if dd == dn and wd == wn then
        r.prio, r.state = 25, "ok"
        r.title = "Alles erledigt  ·  Heute " .. dd .. "/" .. dn .. "  ·  Woche " .. wd .. "/" .. wn
        r.detail = "Nächster Tages-Reset in " .. Dur(untilDay) .. "."
    elseif dd < dn and untilDay < 3 * 3600 then
        -- kurz vor dem Tages-Reset noch offen: nach oben
        r.prio, r.state = 250, "warn"
        r.detail = Hx.warn .. "Reset in " .. Dur(untilDay) .. "|r" .. Hx.dim .. " · offen: |r" .. table.concat(open, ", ", 1, math.min(#open, 4))
    else
        r.prio, r.state = 110, "info"
        r.detail = Hx.dim .. "Offen: |r" .. table.concat(open, ", ", 1, math.min(#open, 4)) .. (#open > 4 and (" +" .. (#open - 4)) or "")
    end
    return r
end

---------------------------------------------------------------------------
-- Ereignisse und Zaehler
---------------------------------------------------------------------------
-- Pix: aktuelle Woche merken (fuer alle Charaktere bis zum naechsten Wochen-Reset)
function TR.PixLearn(id, title)
    if type(id) ~= "number" then return end
    local t, c = TR.db()
    if not TR.PIX[id] then
        -- neue Version: Ziele aus dem Spiel uebernehmen (falls im Log), sonst nur der Name
        local nm = title or TR.QuestTitle(id) or ("Quest " .. id)
        nm = nm:gsub("^In Demand %s*[%-–]%s*", "")
        local v = t.pixLearned and t.pixLearned[id] or { name = nm, parts = {} }
        local obj = TR.Objectives(id)
        if obj and #obj > 0 then
            v.parts = {}
            for i, o in ipairs(obj) do v.parts[i] = { where = o.text or ("Teil " .. i), boss = "", item = o.text or "" } end
        end
        t.pixLearned = t.pixLearned or {}
        t.pixLearned[id] = v
    end
    t.pixWeek = { id = id, untilT = c.weekEnd }
    TR.Changed()
end

function TR.PixInfo(id)
    local t = TR.db()
    return TR.PIX[id] or (t.pixLearned and t.pixLearned[id])
end

local function IsPix(id)
    local t = TR.db()
    return TR.PIX[id] ~= nil or (t.pixLearned and t.pixLearned[id] ~= nil)
end
TR.IsPix = IsPix

-- welche Version laeuft diese Woche? -> id, Quelle ("log" | "done" | "learned" | "seed") oder nil
function TR.PixCurrent()
    local t, c = TR.db()
    local ids = {}
    for id in pairs(TR.PIX) do ids[#ids + 1] = id end
    for id in pairs(t.pixLearned or {}) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do if QuestInLog(id) then return id, "log" end end
    for _, id in ipairs(ids) do if QuestDone(id) then return id, "done" end end
    local w = t.pixWeek
    if w and w.untilT and math.abs(w.untilT - (c.weekEnd or 0)) < 3600 and time() < w.untilT then return w.id, "learned" end
    local now = time()
    for _, s2 in ipairs(TR.PIX_SEEN) do
        if now >= s2.from and now < s2.from + 7 * 86400 then return s2.id, "seed" end
    end
    return nil
end

-- Eintraege fuer die Wochen-Spalte: Kopfzeile + drei Unterzeilen
function TR.PixItems(week)
    local level = UnitLevel and tonumber(ns.S(UnitLevel("player"))) or 0
    if level < 60 then return end
    local id, src = TR.PixCurrent()
    local v = id and TR.PixInfo(id)
    local e = { id = "pix", auto = true, pix = true, text = "Pix-Weekly" .. (v and (": " .. v.name) or "") }
    if not v then
        e.detail = "Version unbekannt"
        e.questHint = "Pix Xizzix in Beutebucht (28.4, 75.8) wechselt die Quest jede Woche. Sprich ihn an – CBAS merkt sich die Version für alle Charaktere."
        week[#week + 1] = e
        return
    end
    local done = QuestDone(id)
    local inLog = QuestInLog(id)
    e.done = done
    e.questHint = "Pix Xizzix, Beutebucht (28.4, 75.8) · Belohnung: Undermine Satchel (10-100 Gold)" .. (v.tip and ("\n" .. v.tip) or "")
        .. (src == "seed" and "\n(Version laut Stand 26.11. – bei Pix bestätigen)" or "")
    if not done then
        e.partial = inLog
        e.detail = inLog and "im Questlog" or "bei Pix annehmen"
    end
    week[#week + 1] = e
    local obj = (not done) and TR.Objectives(id)
    local have = 0
    for i, part in ipairs(v.parts or {}) do
        local o = obj and obj[i]
        if obj and part.item ~= "" then
            for _, x in ipairs(obj) do
                if x.text and x.text:lower():find(part.item:lower(), 1, true) then o = x break end
            end
        end
        local pdone = done or (o and o.finished) or false
        if pdone then have = have + 1 end
        week[#week + 1] = { id = "pix:" .. i, sub = true, auto = true, done = pdone, text = part.where,
            detail = (not pdone) and part.boss or nil,
            questHint = (part.item ~= "" and (part.item .. (part.boss ~= "" and (" – droppt " .. part.boss) or "")) or part.where)
                .. (o and o.text and ("\nIm Questlog: " .. o.text) or "") }
    end
    if not done and obj then e.detail = have .. "/" .. #(v.parts or {}) .. " Teile" end
end

---------------------------------------------------------------------------
-- PvP-Saison: Field of Honor (Wizzik Dustfizz, Gadgetzan 51.8/27.2, ab 60) und Rangpunkte-Grenze
-- Jede Saisonwoche schaltet eine Stufe frei; verpasste Stufen bleiben nachholbar.
-- Saisonstart = Start von WoW Forever (EU-Reset Mi 04.11.2026). Quest-IDs fortlaufend ab 96912.
---------------------------------------------------------------------------
TR.FOH_NPC = "Wizzik Dustfizz"
TR.FOH_FIRST = 96912
TR.FOH_START = time({ year = 2026, month = 11, day = 4, hour = 4 })
TR.FOH_GOALS = {
    [1] = "10 Duelle gewinnen",
    [2] = "3 Spiele Kriegshymnenschlucht beenden",
    [3] = "25 Gegner in der Kriegshymnenschlucht besiegen",
    [4] = "3 Spiele Arathibecken beenden",
}
TR.FOH_LEGACY = { [4] = true, [7] = true, [10] = true }
-- Rangpunkte-Grenze je Saisonwoche (datamined, Stand 27.11.2026): Woche -> { Rang, RP }
TR.RANK_CAP = { [1] = { 3, 2700 }, [2] = { 5, 5250 }, [3] = { 6, 6750 }, [4] = { 7, 8400 }, [10] = { 14, 24750 } }

function TR.SeasonWeek()
    local w = math.floor((time() - TR.FOH_START) / (7 * 86400)) + 1
    return math.max(1, w)
end

function TR.IsFoH(id)
    return type(id) == "number" and id >= TR.FOH_FIRST and id < TR.FOH_FIRST + 20
end

function TR.FoHItems(week)
    local level = UnitLevel and tonumber(ns.S(UnitLevel("player"))) or 0
    if level < 60 then return end
    local sw = math.min(TR.SeasonWeek(), 20)
    local open, inLogStep = {}, nil
    for k = 1, sw do
        local id = TR.FOH_FIRST + k - 1
        if not QuestDone(id) then open[#open + 1] = k end
        if QuestInLog(id) then inLogStep = k end
    end
    local e = { id = "foh", auto = true, text = "Field of Honor (PvP)", done = #open == 0,
        questHint = "Wizzik Dustfizz, Gadgetzan (51.8, 27.2). Jede Woche eine neue Stufe, verpasste Stufen kannst du nachholen. Belohnung: Ehre und Rangpunkte, in Woche 4, 7 und 10 zusätzlich je 1 Legacy-Punkt." }
    if #open > 0 then
        e.partial = inLogStep ~= nil
        e.detail = (#open == 1) and ("Woche " .. open[1] .. " offen") or (#open .. " Stufen offen")
    end
    week[#week + 1] = e
    for i = 1, math.min(#open, 4) do
        local k = open[i]
        local id = TR.FOH_FIRST + k - 1
        local goal = TR.FOH_GOALS[k] or (TR.QuestTitle(id) or "neue Stufe")
        local obj = TR.Objectives(id)
        local det = QuestInLog(id) and "im Questlog" or "bei Wizzik holen"
        if obj and obj[1] and obj[1].text then det = obj[1].text end
        week[#week + 1] = { id = "foh:" .. k, sub = true, auto = true, done = false, partial = QuestInLog(id),
            text = "Woche " .. k .. ": " .. goal .. (TR.FOH_LEGACY[k] and " (+Legacy)" or ""), detail = det }
    end
    if #open > 4 then
        week[#week + 1] = { id = "foh:more", sub = true, auto = true, done = false, text = "+" .. (#open - 4) .. " weitere Stufen" }
    end
    -- Rangpunkte-Grenze dieser Woche (nur Info, zaehlt nicht mit)
    local cap
    for w = sw, 1, -1 do if TR.RANK_CAP[w] then cap = (w == sw) and TR.RANK_CAP[w] or nil break end end
    if sw >= 10 then cap = TR.RANK_CAP[10] end
    week[#week + 1] = { id = "rankcap", info = true, auto = true, done = false,
        text = "Rangpunkte-Grenze (Saisonwoche " .. sw .. ")",
        detail = cap and ("Rang " .. cap[1] .. " · " .. cap[2] .. " RP") or "bis Rang 14 (24750 RP) ab Woche 10",
        questHint = "So hoch kann diese Woche jeder kommen. Wer zurückliegt, holt bis zur Grenze auf; Punkte über der Grenze verfallen. Deinen Stand siehst du im PvP-Fenster (Taste H)." }
end

---------------------------------------------------------------------------
-- Mage: Studieren in der Bibliothek (Lichtfeder -> Buendel Schriftrollen, Abklingzeit laut Spiel)
-- Zauber-ID ist nicht veroeffentlicht: Suche ueber den Namen, beim ersten Wirken gemerkt.
---------------------------------------------------------------------------
TR.STUDY_NAMES = { "Studieren", "Study", "Studium" }
TR.LIGHT_FEATHER = 17056

local function SpellIDByName(name)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, name)
        if ok and type(info) == "table" and info.spellID then return tonumber(ns.S(info.spellID)) end
    end
    if GetSpellInfo then
        local ok, _, _, _, _, _, _, id = pcall(GetSpellInfo, name)
        if ok and id then return tonumber(ns.S(id)) end
    end
end

function TR.StudySpell()
    local t = TR.db()
    if t.studyID then return t.studyID end
    for _, n in ipairs(TR.STUDY_NAMES) do
        local id = SpellIDByName(n)
        if id then return id end
    end
end

-- Restzeit in Sekunden (0 = bereit) oder nil, wenn unbekannt
function TR.StudyCooldown(id)
    if not id then return nil end
    local start, dur
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, cd = pcall(C_Spell.GetSpellCooldown, id)
        if ok and type(cd) == "table" then start, dur = tonumber(ns.S(cd.startTime)), tonumber(ns.S(cd.duration)) end
    elseif GetSpellCooldown then
        local ok, a, b = pcall(GetSpellCooldown, id)
        if ok then start, dur = tonumber(ns.S(a)), tonumber(ns.S(b)) end
    end
    if not start or not dur then return nil end
    if start == 0 or dur <= 1.5 then return 0 end
    return math.max(0, start + dur - GetTime())
end

function TR.StudyItems(day)
    local MG = ns.Mage
    if not (MG and MG.IsMage()) then return end
    local id = TR.StudySpell()
    if not id then return end   -- noch nicht gelernt (erstes Bibliotheksbuch abgeben)
    local feathers = MG.ItemCount and MG.ItemCount(TR.LIGHT_FEATHER) or 0
    local cd = TR.StudyCooldown(id)
    local e = { id = "study", info = true, auto = true, text = "Mage: Studieren (Bibliothek)",
        questHint = "Lichtfeder + 6 s in einer Bibliothek (Magierturm Sturmwind, Königliche Bibliothek, Magierviertel Unterstadt) = Bündel mit 2-4 Schriftrollen." }
    if cd and cd > 0 then
        e.done = true
        e.detail = "wieder in " .. Dur(cd)
    else
        e.done = false
        e.partial = feathers > 0
        e.detail = feathers > 0 and ("bereit · " .. feathers .. " Lichtfedern") or "|cffff5555keine Lichtfeder|r"
    end
    day[#day + 1] = e
end

-- Wiederholungsquest angenommen -> in den Tracker (Daily oder Weekly laut Spiel)
function TR.OnQuestAccepted(id)
    for _, q in ipairs(TR.QUESTS) do if q.quest == id then return end end
    if TR.IsFoH(id) then return end
    -- Pix-Quest (bekannt oder vom NPC Pix Xizzix): nur Woche merken, kein eigener Eintrag
    local npc = UnitName and ns.S(UnitName("npc"))
    if IsPix(id) or npc == TR.PIX_NPC then TR.PixLearn(id) return end
    if TR.FindQuestTask(id) then return end
    local period = TR.QuestPeriod(id)
    if not period then return end
    return TR.AddTask(TR.QuestTitle(id) or ("Quest " .. id), period, id)
end

-- Gespraech mit Pix Xizzix: angebotene Quest erkennen
function TR.PixFromNPC(event)
    local npc = UnitName and ns.S(UnitName("npc"))
    if npc ~= TR.PIX_NPC then return end
    if event == "QUEST_DETAIL" and GetQuestID then
        local ok, id = pcall(GetQuestID)
        id = ok and tonumber(ns.S(id))
        if id and id > 0 then
            local title = GetTitleText and ns.S(GetTitleText())
            TR.PixLearn(id, title)
        end
        return
    end
    if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
        local ok, list = pcall(C_GossipInfo.GetAvailableQuests)
        for _, q in ipairs(ok and list or {}) do
            local id = tonumber(ns.S(q.questID))
            if id and (IsPix(id) or (q.repeatable and true) or (q.frequency and q.frequency ~= 0)) then
                TR.PixLearn(id, ns.S(q.title))
                return
            end
        end
    end
end

local listeners = {}
function TR.OnChange(fn) listeners[#listeners + 1] = fn end
function TR.Changed() for _, fn in ipairs(listeners) do pcall(fn) end end

-- jede erfolgreich gesendete /who-Abfrage zaehlt als Scan
local function HookWho()
    if TR.hooked or not ns.SendWho then return end
    TR.hooked = true
    local orig = ns.SendWho
    ns.SendWho = function(...)
        local ok = orig(...)
        if ok and ns.db then
            local _, c = TR.db()
            c.scans = (c.scans or 0) + 1
        end
        return ok
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, a1, a2, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- Studieren gewirkt? Zauber-ID merken (Name aus dem Spiel)
        if a1 == "player" then
            local id = tonumber(ns.S((...)))
            local nm
            if id and C_Spell and C_Spell.GetSpellName then local ok, n = pcall(C_Spell.GetSpellName, id) nm = ok and ns.S(n) end
            if id and not nm and GetSpellInfo then local ok, n = pcall(GetSpellInfo, id) nm = ok and ns.S(n) end
            for _, n in ipairs(TR.STUDY_NAMES) do
                if nm == n then TR.db().studyID = id TR.Changed() break end
            end
        end
        return
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        if TR.UI.panel and TR.UI.panel:IsVisible() then TR.Changed() end
        return
    end
    if event == "QUEST_DETAIL" or event == "GOSSIP_SHOW" or event == "QUEST_GREETING" then
        TR.PixFromNPC(event)
        return
    elseif event == "QUEST_LOG_UPDATE" then
        -- nur neu zeichnen, wenn die Ansicht offen ist (kommt sehr oft)
        if TR.UI.panel and TR.UI.panel:IsVisible() then TR.Changed() end
        return
    end
    if event == "QUEST_ACCEPTED" then
        -- Classic: (Index, questID), modern: (questID)
        local id = tonumber(ns.S(a2)) or tonumber(ns.S(a1))
        if id then TR.OnQuestAccepted(id) end
        TR.Changed()
        return
    end
    if event == "PLAYER_LOGIN" then
        HookWho()
        if RequestRaidInfo then pcall(RequestRaidInfo) end
        for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "UPDATE_INSTANCE_INFO", "BOSS_KILL", "ENCOUNTER_END",
            "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_DETAIL", "UNIT_SPELLCAST_SUCCEEDED", "SPELL_UPDATE_COOLDOWN", "QUEST_LOG_UPDATE", "GOSSIP_SHOW", "QUEST_GREETING" }) do
            pcall(self.RegisterEvent, self, e)
        end
        -- alte Charaktere (60 Tage nicht gesehen) aufraeumen
        local t = TR.db()
        for k, c in pairs(t.chars) do if (c.seen or 0) < time() - 60 * 86400 then t.chars[k] = nil end end
        return
    end
    if event == "AUCTION_HOUSE_SHOW" then
        local _, c = TR.db()
        c.ah = time()
    elseif event == "BOSS_KILL" or event == "ENCOUNTER_END" then
        if RequestRaidInfo then pcall(RequestRaidInfo) end
    end
    TR.DirtyRaids()
    TR.Changed()
end)
HookWho()

---------------------------------------------------------------------------
-- Ansicht: zwei Spalten "Heute" und "Diese Woche", unten neue Aufgabe
---------------------------------------------------------------------------
local UI = {}
TR.UI = UI
local COLW, ROW_H, NROWS = 404, 22, 16

local function MakeRow(p, x, y)
    local T = ns.T
    local C = T.C
    local r = CreateFrame("Button", nil, p)
    r:SetSize(COLW, ROW_H - 2)
    r:SetPoint("TOPLEFT", x, y)
    local bg = r:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(T.WHITE)
    bg:SetAllPoints()
    bg:SetVertexColor(1, 1, 1, 0)
    r.bg = bg
    local box = CreateFrame("Frame", nil, r)
    box:SetSize(14, 14)
    box:SetPoint("LEFT", 8, 0)
    T.Box(box, { 0, 0, 0, 0.35 }, T.C.lineHi)
    r.box = box
    local tick = box:CreateTexture(nil, "OVERLAY")
    tick:SetTexture(T.WHITE)
    tick:SetSize(8, 8)
    tick:SetPoint("CENTER")
    r.tick = tick
    local name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("LEFT", 32, 0)
    name:SetPoint("RIGHT", -150, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    r.name = name
    local det = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    det:SetPoint("RIGHT", -30, 0)
    det:SetJustifyH("RIGHT")
    r.det = det
    local x2 = T.Button(r, "x", 22, 20, "quiet")
    x2:SetPoint("RIGHT", -4, 0)
    x2:SetScript("OnClick", function() if r.e and r.e.task then TR.RemoveTask(r.e.task.id) end end)
    T.Tip(x2, "Aufgabe löschen", "Verschwindet für alle Charaktere.")
    r.x = x2
    local line = r:CreateTexture(nil, "BORDER")
    line:SetTexture(T.WHITE)
    line:SetVertexColor(unpack(C.line))
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 0, -1)
    line:SetPoint("BOTTOMRIGHT", 0, -1)
    r:SetScript("OnClick", function()
        local e = r.e
        if not e then return end
        if e.task and not e.task.quest then TR.ToggleTask(e.task.id)
        elseif e.raid then TR.ToggleRaid(e.raid) end
    end)
    r:SetScript("OnEnter", function(s)
        s.bg:SetVertexColor(1, 1, 1, 0.04)
        if s.e then
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(s.e.text, 1, 1, 1)
            if s.e.questHint then GameTooltip:AddLine(s.e.questHint, C.dim[1], C.dim[2], C.dim[3], true) end
            if s.e.task and s.e.task.quest then GameTooltip:AddLine("Quest " .. s.e.task.quest .. " – hakt sich selbst ab, sobald du sie abgibst.", C.dim[1], C.dim[2], C.dim[3], true)
            elseif s.e.task then GameTooltip:AddLine("Klick: abhaken / wieder öffnen", C.dim[1], C.dim[2], C.dim[3])
            elseif s.e.raid then GameTooltip:AddLine("Hakt sich selbst ab, sobald alle Bosse liegen.\nKlick: aus der Liste nehmen (solange keine ID besteht).", C.dim[1], C.dim[2], C.dim[3], true)
            else GameTooltip:AddLine("Hakt sich selbst ab.", C.dim[1], C.dim[2], C.dim[3]) end
            GameTooltip:Show()
        end
    end)
    r:SetScript("OnLeave", function(s) s.bg:SetVertexColor(1, 1, 1, 0) GameTooltip_Hide() end)
    r:Hide()
    return r
end

local function Column(p, x, title)
    local T = ns.T
    local col = { rows = {} }
    local h = T.Section(p, title, COLW)
    h:SetPoint("TOPLEFT", x, -36)
    col.head = h
    local reset = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    reset:SetPoint("TOPLEFT", x, -54)
    reset:SetTextColor(T.C.dim[1], T.C.dim[2], T.C.dim[3])
    col.reset = reset
    local big = p:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    big:SetPoint("TOPRIGHT", p, "TOPLEFT", x + COLW, -50)
    col.big = big
    for i = 1, NROWS do col.rows[i] = MakeRow(p, x, -78 - (i - 1) * ROW_H) end
    local empty = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("TOPLEFT", x + 8, -86)
    empty:SetWidth(COLW - 16)
    empty:SetJustifyH("LEFT")
    col.empty = empty
    return col
end

function UI:Create(p)
    if self.panel then return end
    self.panel = p
    local T = ns.T
    local C = T.C
    self.day = Column(p, 16, "Heute")
    self.week = Column(p, 16 + COLW + 20, "Diese Woche")
    self.week.empty:SetText("Raids erscheinen, sobald du eine ID hast – oder unten Raids zum Verfolgen anklicken.")

    -- Raids zum Verfolgen (rechte Spalte unten)
    local y = -78 - NROWS * ROW_H - 8
    local rl = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    rl:SetPoint("TOPLEFT", 16 + COLW + 20, y - 4)
    rl:SetText("Raids verfolgen:")
    rl:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    self.raidBtns = {}
    local rx = 16 + COLW + 20 + 92
    for _, inst in ipairs(ns.INSTANCES or {}) do
        if inst.kind == "raid" then
            local b = T.Button(p, inst.key, 42, 20, "quiet")
            b:SetPoint("TOPLEFT", rx, y)
            b:SetScript("OnClick", function() TR.ToggleRaid(inst.key) end)
            T.Tip(b, inst.de, "Klick: wöchentlich verfolgen an/aus.")
            b.key = inst.key
            rx = rx + 44
            self.raidBtns[#self.raidBtns + 1] = b
        end
    end
    -- GScout-Ziel (linke Spalte unten)
    local gl = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    gl:SetPoint("TOPLEFT", 16, y - 4)
    gl:SetText("Scan-Ziel pro Tag:")
    gl:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    local minus = T.Button(p, "-", 22, 20, "quiet")
    minus:SetPoint("TOPLEFT", 128, y)
    local goal = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    goal:SetPoint("LEFT", minus, "RIGHT", 6, 0)
    goal:SetWidth(24)
    self.goal = goal
    local plus = T.Button(p, "+", 22, 20, "quiet")
    plus:SetPoint("LEFT", goal, "RIGHT", 6, 0)
    minus:SetScript("OnClick", function() local t = TR.db() t.scanGoal = math.max(1, t.scanGoal - 5) TR.Changed() end)
    plus:SetScript("OnClick", function() local t = TR.db() t.scanGoal = math.min(100, t.scanGoal + 5) TR.Changed() end)

    -- neue Aufgabe
    local card = T.Card(p)
    card:SetPoint("BOTTOMLEFT", 16, 14)
    card:SetSize(828, 46)
    local e = CreateFrame("EditBox", nil, card, "InputBoxTemplate")
    e:SetSize(470, 22)
    e:SetPoint("LEFT", 20, 0)
    e:SetAutoFocus(false)
    e:SetMaxLetters(60)
    self.edit = e
    local hint = card:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    hint:SetPoint("LEFT", e, "LEFT", 2, 0)
    hint:SetText("Eigene Aufgabe (z. B. „Kochen skillen“) oder Quest-ID / Wowhead-Link")
    self.editHint = hint
    e:SetScript("OnTextChanged", function(s) hint:SetShown((s:GetText() or "") == "" and not s:HasFocus()) end)
    e:SetScript("OnEditFocusGained", function() hint:Hide() end)
    e:SetScript("OnEditFocusLost", function(s) hint:SetShown((s:GetText() or "") == "") end)
    self.period = "day"
    local per = T.Button(card, "Täglich", 110, 24)
    per:SetPoint("LEFT", e, "RIGHT", 12, 0)
    per:SetScript("OnClick", function()
        UI.period = UI.period == "day" and "week" or "day"
        per:SetText(UI.period == "day" and "Täglich" or "Wöchentlich")
    end)
    T.Tip(per, "Wann zurücksetzen?", "Täglich: zum Tages-Reset des Servers. Wöchentlich: zum Wochen-Reset.")
    self.perBtn = per
    local add = T.Button(card, "Hinzufügen", 160, 24, "primary")
    add:SetPoint("LEFT", per, "RIGHT", 8, 0)
    local function Add()
        local task, err = TR.AddTask(e:GetText(), UI.period)
        if task then e:SetText("") e:ClearFocus() elseif err then ns.Print(err) end
    end
    add:SetScript("OnClick", Add)
    e:SetScript("OnEnterPressed", Add)
    e:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    self.addBtn = add

    TR.OnChange(function() if UI.panel and UI.panel:IsVisible() then UI:Refresh() end end)
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(10, function() if UI.panel and UI.panel:IsVisible() then pcall(UI.Refresh, UI) end end)
    end
end

local function Fill(col, list, untilReset, label)
    local T = ns.T
    local C = T.C
    local d, n = TR.Count(list)
    col.big:SetText((d == n and n > 0 and T.HEX.ok or T.HEX.text) .. d .. "/" .. n .. "|r")
    col.reset:SetText(label .. " in " .. Dur(untilReset))
    for i, r in ipairs(col.rows) do
        local e = list[i]
        r.e = e
        if e then
            local c = e.done and C.ok or (e.partial and C.warn or C.dim)
            r.tick:SetVertexColor(c[1], c[2], c[3], 1)
            r.tick:SetShown(e.done or e.partial or false)
            r.name:SetText(e.text .. ((e.auto and not e.sub) and (T.HEX.dim .. "  · auto|r") or ""))
            r.box:ClearAllPoints()
            r.box:SetPoint("LEFT", e.sub and 28 or 8, 0)
            r.box:SetScale(e.sub and 0.8 or 1)
            r.name:ClearAllPoints()
            r.name:SetPoint("LEFT", e.sub and 50 or 32, 0)
            r.name:SetPoint("RIGHT", -150, 0)
            r.name:SetFontObject(e.sub and "GameFontHighlightSmall" or "GameFontHighlight")
            if e.info then r.name:SetText(e.text .. T.HEX.dim .. "  · Info|r") end
            if e.done then r.name:SetTextColor(C.dim[1], C.dim[2], C.dim[3]) else r.name:SetTextColor(C.text[1], C.text[2], C.text[3]) end
            r.det:SetText(e.detail or (e.done and (T.HEX.ok .. "erledigt|r") or ""))
            r.x:SetShown(e.task ~= nil)
            r:Show()
        else
            r:Hide()
        end
    end
    col.empty:SetShown(#list == 0)
end

function UI:Refresh()
    if not self.panel then return end
    local day, week, c = TR.Items()
    local now = time()
    Fill(self.day, day, (c.dayEnd or now) - now, "Tages-Reset")
    Fill(self.week, week, (c.weekEnd or now) - now, "Wochen-Reset")
    local t = TR.db()
    self.goal:SetText(tostring(t.scanGoal))
    local lock = TR.Lockouts()
    for _, b in ipairs(self.raidBtns) do ns.T.SetActive(b, (c.raids[b.key] or lock[b.key]) and true or false) end
end

ns.Suite:RegisterModule({
    id = "tracker",
    name = "Tracker",
    parent = "home",
    desc = "Heute und diese Woche: was ist erledigt, was fehlt noch?",
    create = function(p) UI:Create(p) end,
    onShow = function() TR.DirtyRaids() if RequestRaidInfo then pcall(RequestRaidInfo) end UI:Refresh() end,
})
