-- CBAS - Tracker (Lage > Tracker): Was ist heute und diese Woche erledigt?
-- Automatisch (hakt sich selbst ab):
--   Heute: Auktionshaus besucht, GScout-Scans (Ziel einstellbar), Mage-Vorrat (nur Magier)
--   Woche: Raid-IDs aus dem Spiel (Fortschritt "3/10", ZG/AQ20 mit eigenem 3-Tage-Reset)
--   Quests: die Forever-Weekly in Booty Bay (Pix Xizzix, ab 60) und JEDE angenommene
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
TR.QUESTS = {
    -- WoW: Forever, seit 13.11.2026: Pix Xizzix, Beutebucht (28.4, 75.8); je ein Teil aus Duesterbruch Ost/West/Nord
    { quest = 96076, period = "week", minLevel = 60, text = "Beutebucht-Weekly (Pix Xizzix)",
      hint = "Je ein Teil vom Endboss in Düsterbruch Ost, West und Nord (Felvine Seed, Ancient Memento, Earthstone Diamond Pinky Ring). West und Nord brauchen den Mondsichelschlüssel. Belohnung: Beutel mit 10 bis 100 Gold." },
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
    local d = 0
    for _, e in ipairs(list) do if e.done then d = d + 1 end end
    return d, #list
end

---------------------------------------------------------------------------
-- Lage-Zeile
---------------------------------------------------------------------------
function TR.HomeRow()
    local day, week, c = TR.Items()
    local dd, dn = TR.Count(day)
    local wd, wn = TR.Count(week)
    local open = {}
    for _, e in ipairs(day) do if not e.done then open[#open + 1] = e.text end end
    for _, e in ipairs(week) do if not e.done then open[#open + 1] = e.text end end
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
-- Wiederholungsquest angenommen -> in den Tracker (Daily oder Weekly laut Spiel)
function TR.OnQuestAccepted(id)
    for _, q in ipairs(TR.QUESTS) do if q.quest == id then return end end
    if TR.FindQuestTask(id) then return end
    local period = TR.QuestPeriod(id)
    if not period then return end
    return TR.AddTask(TR.QuestTitle(id) or ("Quest " .. id), period, id)
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
ev:SetScript("OnEvent", function(self, event, a1, a2)
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
            "QUEST_ACCEPTED", "QUEST_TURNED_IN" }) do pcall(self.RegisterEvent, self, e) end
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
local COLW, ROW_H, NROWS = 404, 30, 10

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
            r.name:SetText(e.text .. (e.auto and (T.HEX.dim .. "  · auto|r") or ""))
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
