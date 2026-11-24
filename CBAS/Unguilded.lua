-- CBAS - GScout-Erweiterung: Reiter "Gildenlos" (gildenlose Spieler und Gildensucher)
local ADDON, ns = ...
local S = ns.S
local GL = {}
ns.Gildenlos = GL

local ROWS, ROW_H = 16, 20
local COLS = {
    { key = "name",  label = "Spieler",      w = 140, align = "LEFT" },
    { key = "level", label = "Lvl",          w = 32 },
    { key = "class", label = "Klasse",       w = 90, align = "LEFT" },
    { key = "fac",   label = "Fr.",          w = 22 },
    { key = "zone",  label = "Ort",          w = 150, align = "LEFT" },
    { key = "seen",  label = "Zuletzt",      w = 54 },
    { key = "src",   label = "Quelle",       w = 60 },
    { key = "seek",  label = "Sucht Gilde",  w = 240, align = "LEFT" },
}
local SRC = { who = "/who", unit = "gesehen", chat = "Chat" }

local function ClassName(f) return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[f]) or f or "?" end
local function ClassColor(f)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[f or ""]
    return c and c.colorStr and ("|c" .. c.colorStr) or "|cffffffff"
end
local function Fac(f)
    if f == "Alliance" then return "|cff4a9effA|r" end
    if f == "Horde" then return "|cffff4040H|r" end
    return "|cff888888?|r"
end
local function Btn(parent, text, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    return b
end
local function Check(parent, label)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local fs = (type(cb.Text) == "table" and cb.Text) or nil
    if not fs then
        fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    end
    fs:SetFontObject("GameFontHighlightSmall")
    fs:SetText(label)
    return cb
end

GL.sortKey, GL.sortDesc = "seek", true

function GL:Create(p)
    self.frame = p
    self.offset = 0

    self.cbSeek = Check(p, "Nur Gildensucher")
    self.cbSeek:SetPoint("TOPLEFT", 14, -32)
    self.cb60 = Check(p, "Nur Max-Level")
    self.cb60:SetPoint("LEFT", self.cbSeek, "RIGHT", 104, 0)
    self.cbFac = Check(p, "Meine Fraktion")
    self.cbFac:SetPoint("LEFT", self.cb60, "RIGHT", 92, 0)
    for _, cb in ipairs({ self.cbSeek, self.cb60, self.cbFac }) do
        cb:SetScript("OnClick", function() GL.offset = 0; GL:Refresh() end)
    end
    local sl = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sl:SetPoint("LEFT", self.cbFac, "RIGHT", 100, 0)
    sl:SetText("Suche:")
    local search = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    search:SetSize(140, 20)
    search:SetPoint("LEFT", sl, "RIGHT", 8, 0)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function() GL.offset = 0; GL:Refresh() end)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    search:SetScript("OnEnterPressed", search.ClearFocus)
    self.search = search
    local count = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    count:SetPoint("TOPRIGHT", -18, -38)
    self.count = count

    -- Spaltenkoepfe (klickbar zum Sortieren)
    local x = 16
    self.headers = {}
    for _, c in ipairs(COLS) do
        local h = CreateFrame("Button", nil, p)
        h:SetSize(c.w, 18)
        h:SetPoint("TOPLEFT", x, -62)
        local fs = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetAllPoints()
        fs:SetJustifyH(c.align or "CENTER")
        h.fs, h.col = fs, c
        h:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        h:SetScript("OnClick", function()
            if GL.sortKey == c.key then GL.sortDesc = not GL.sortDesc
            else GL.sortKey, GL.sortDesc = c.key, (c.key == "level" or c.key == "seen" or c.key == "seek") end
            GL:Refresh()
        end)
        self.headers[#self.headers + 1] = h
        x = x + c.w + 2
    end
    local listW = x - 16

    local area = CreateFrame("Frame", nil, p)
    area:SetPoint("TOPLEFT", 14, -82)
    area:SetSize(listW + 4, ROWS * ROW_H)
    area:EnableMouseWheel(true)
    area:SetScript("OnMouseWheel", function(_, d)
        GL.offset = math.max(0, math.min(math.max(0, #GL.list - ROWS), GL.offset - d * 3))
        GL:UpdateRows()
    end)
    self.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, area)
        r:SetSize(listW, ROW_H)
        r:SetPoint("TOPLEFT", 2, -(i - 1) * ROW_H)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        local sel = r:CreateTexture(nil, "BACKGROUND")
        sel:SetAllPoints()
        sel:SetColorTexture(0.2, 0.6, 1, 0.25)
        sel:Hide()
        r.sel = sel
        if i % 2 == 0 then
            local bg = r:CreateTexture(nil, "BACKGROUND", nil, -1)
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.03)
        end
        r.cells = {}
        local cx = 0
        for ci, c in ipairs(COLS) do
            local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", cx + 2, 0)
            fs:SetSize(c.w - 4, ROW_H)
            fs:SetJustifyH(c.align or "CENTER")
            fs:SetWordWrap(false)
            r.cells[ci] = fs
            cx = cx + c.w + 2
        end
        r:SetScript("OnClick", function(self)
            if self.full then GL.selected = self.full; GL:Refresh() end
        end)
        self.rows[i] = r
    end

    -- Details zum gewaehlten Spieler
    local det = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    det:SetPoint("TOPLEFT", 18, -412)
    det:SetPoint("TOPRIGHT", -18, -412)
    det:SetJustifyH("LEFT")
    det:SetJustifyV("TOP")
    det:SetSpacing(2)
    self.det = det

    -- Knoepfe
    local tell = Btn(p, "Anflüstern", 100)
    tell:SetPoint("BOTTOMLEFT", 14, 12)
    tell:SetScript("OnClick", function()
        if not GL.selected then return end
        if ChatFrameUtil and ChatFrameUtil.SendTell then ChatFrameUtil.SendTell(GL.selected)
        elseif ChatFrame_SendTell then ChatFrame_SendTell(GL.selected) end
    end)
    self.tellBtn = tell
    local who = Btn(p, "/who Spieler", 110)
    who:SetPoint("LEFT", tell, "RIGHT", 6, 0)
    who:SetScript("OnClick", function()
        if not GL.selected then return end
        local n = ns.SplitName(GL.selected)
        if ns.SendWho('n-"' .. n .. '"', {}) then ns.Print("Prüfe " .. n .. " ...") end
        GL:UpdateWhoButton()
    end)
    who:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_TOP")
        GameTooltip:SetText("Prüft per /who, ob der Spieler online ist und ob er inzwischen eine Gilde hat.", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    who:SetScript("OnLeave", GameTooltip_Hide)
    self.whoBtn = who
    local nl = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nl:SetPoint("LEFT", who, "RIGHT", 14, 0)
    nl:SetText("Notiz:")
    local note = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    note:SetSize(260, 20)
    note:SetPoint("LEFT", nl, "RIGHT", 8, 0)
    note:SetAutoFocus(false)
    note:SetScript("OnEscapePressed", note.ClearFocus)
    note:SetScript("OnEnterPressed", note.ClearFocus)
    note:SetScript("OnTextChanged", function(self, user)
        local u = user and GL.selected and ns.db.unguilded[GL.selected]
        if u then
            local t = self:GetText()
            u.note = (t ~= "" and t) or nil
        end
    end)
    self.note = note
    local del = Btn(p, "Entfernen", 90)
    del:SetPoint("LEFT", note, "RIGHT", 12, 0)
    del:SetScript("OnClick", function()
        if GL.selected then
            ns.db.unguilded[GL.selected] = nil
            GL.selected = nil
            GL:Refresh()
        end
    end)
    self.delBtn = del

    p:SetScript("OnShow", function() GL:Refresh() end)
    local acc = 0
    p:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc < 0.1 then return end
        acc = 0
        GL:UpdateWhoButton()
    end)
end

local function SortVal(e, key)
    local u = e.u
    if key == "name" then return e.full:lower() end
    if key == "level" then return u.level or 0 end
    if key == "class" then return ClassName(u.class) end
    if key == "fac" then return u.faction or "" end
    if key == "zone" then return (u.zone or ""):lower() end
    if key == "seen" then return u.seen or 0 end
    if key == "src" then return u.src or "" end
    if key == "seek" then return (u.seeking and u.seeking.t or 0) * 10 + ((u.seen or 0) / 1e10) end
    return 0
end

function GL:BuildList()
    local list = {}
    local onlySeek, only60, onlyFac = self.cbSeek:GetChecked(), self.cb60:GetChecked(), self.cbFac:GetChecked()
    local myFac = UnitFactionGroup("player")
    local q = (self.search:GetText() or ""):lower()
    local maxLvl = ns.MaxLevel()
    local nSeek = 0
    for full, u in pairs(ns.db.unguilded or {}) do
        if u.seeking then nSeek = nSeek + 1 end
        local ok = true
        if onlySeek and not u.seeking then ok = false end
        if ok and only60 and (u.level or 0) < maxLvl then ok = false end
        if ok and onlyFac and u.faction and u.faction ~= myFac then ok = false end
        if ok and q ~= "" then
            local hay = (full .. " " .. ClassName(u.class) .. " " .. (u.zone or "") .. " " ..
                (u.seeking and u.seeking.text or "") .. " " .. (u.note or "")):lower()
            if not hay:find(q, 1, true) then ok = false end
        end
        if ok then list[#list + 1] = { full = full, u = u } end
    end
    local k, desc = self.sortKey, self.sortDesc
    table.sort(list, function(a, b)
        local va, vb = SortVal(a, k), SortVal(b, k)
        if va == vb then return a.full < b.full end
        if desc then return va > vb end
        return va < vb
    end)
    self.list, self.nSeek = list, nSeek
end

function GL:UpdateRows()
    for i = 1, ROWS do
        local r = self.rows[i]
        local e = self.list[self.offset + i]
        if e then
            local u = e.u
            r.full = e.full
            local name, realm = ns.SplitName(e.full)
            if realm ~= ns.MyRealm() then name = name .. "|cff888888-" .. realm .. "|r" end
            r.cells[1]:SetText(ClassColor(u.class) .. name .. "|r")
            r.cells[2]:SetText(u.level and tostring(u.level) or "?")
            r.cells[3]:SetText(u.class and ClassName(u.class) or "|cff888888?|r")
            r.cells[4]:SetText(Fac(u.faction))
            r.cells[5]:SetText(u.zone or "|cff555555-|r")
            r.cells[6]:SetText(ns.Ago(u.seen))
            r.cells[7]:SetText(SRC[u.src or ""] or (u.seeking and "Chat") or "-")
            local seek = "|cff555555-|r"
            if u.seeking then
                seek = "|cff66ccff" .. ns.Ago(u.seeking.t) .. ":|r " .. u.seeking.text
                if u.joinedGuild then seek = "|cff40ff40[jetzt in <" .. u.joinedGuild .. ">]|r " .. seek
                elseif u.inGuild then seek = "|cffffd100[noch in <" .. u.inGuild .. ">]|r " .. seek end
            end
            r.cells[8]:SetText(seek)
            if self.selected == e.full then r.sel:Show() else r.sel:Hide() end
            r:Show()
        else
            r.full = nil
            r:Hide()
        end
    end
end

function GL:UpdateDetail()
    local u = self.selected and ns.db.unguilded[self.selected]
    for _, b in ipairs({ self.tellBtn, self.delBtn }) do b:SetEnabled(u ~= nil) end
    self.note:SetEnabled(u ~= nil)
    if not u then
        self.det:SetText("|cff888888Spieler auswählen. Gildenlose kommen vor allem aus /who (Who-, 60er-, Städte-Scan) " ..
            "und aus dem Chat (\"suche Gilde\", \"LF guild\" ...).|r")
        if not self.note:HasFocus() then self.note:SetText("") end
        self:UpdateWhoButton()
        return
    end
    local L = {}
    L[#L + 1] = string.format("%s%s|r  %s %s%s  %s", ClassColor(u.class), self.selected,
        u.level and ("Level " .. u.level) or "", ClassName(u.class), u.race and (" (" .. u.race .. ")") or "", Fac(u.faction))
    L[#L + 1] = string.format("|cffaaaaaaZuletzt:|r vor %s%s  ·  |cffaaaaaaErstmals:|r %s  ·  |cffaaaaaaQuelle:|r %s",
        ns.Ago(u.seen), u.zone and (" in " .. u.zone) or "", date("%d.%m.%y", u.first or u.seen or time()), SRC[u.src or ""] or "Chat")
    if u.leftGuild then L[#L + 1] = "|cffffd100War früher in <" .. u.leftGuild .. ">|r" end
    if u.joinedGuild then
        L[#L + 1] = string.format("|cff40ff40Hat inzwischen eine Gilde gefunden: <%s> (vor %s)|r", u.joinedGuild, ns.Ago(u.joinedT))
    elseif u.inGuild then
        L[#L + 1] = "|cffffd100Ist noch in <" .. u.inGuild .. "> und sucht trotzdem eine Gilde (wechselwillig)|r"
    end
    if u.seeking then
        L[#L + 1] = string.format("|cff66ccffSucht Gilde (vor %s%s):|r %s", ns.Ago(u.seeking.t),
            u.seeking.ch and (", " .. u.seeking.ch) or "", u.seeking.text)
    end
    self.det:SetText(table.concat(L, "\n"))
    if not self.note:HasFocus() then self.note:SetText(u.note or "") end
    self:UpdateWhoButton()
end

-- /who-Knopf mit derselben Sperre wie die Scans
function GL:UpdateWhoButton()
    local b = self.whoBtn
    if not b then return end
    local rem = ns.WhoCooldown and ns.WhoCooldown() or 0
    if rem > 0 then
        b:SetEnabled(false)
        b:SetText(string.format("/who |cffffd100%ds|r", math.ceil(rem)))
    else
        b:SetText("/who Spieler")
        b:SetEnabled(self.selected ~= nil)
    end
end

function GL:Refresh()
    if not self.frame or not self.frame:IsVisible() then return end
    self:BuildList()
    self.offset = math.min(self.offset, math.max(0, #self.list - ROWS))
    for _, h in ipairs(self.headers) do
        local arrow = (h.col.key == self.sortKey) and (self.sortDesc and " v" or " ^") or ""
        h.fs:SetText(h.col.label .. arrow)
    end
    self:UpdateRows()
    self:UpdateDetail()
    local total = 0
    for _ in pairs(ns.db.unguilded or {}) do total = total + 1 end
    self.count:SetText(string.format("%d gildenlos · %d suchen eine Gilde · %d angezeigt", total, self.nSeek or 0, #self.list))
end

-- in die Aktualisierung von GScout einklinken
local oldRefresh = ns.RefreshUI
ns.RefreshUI = function(...)
    oldRefresh(...)
    if GL.frame and GL.frame:IsVisible() and not GL.queued then
        GL.queued = true
        C_Timer.After(1, function() GL.queued = false; GL:Refresh() end)
    end
end

ns.Suite:RegisterModule({
    id = "gildenlos",
    name = "Gildenlose",
    parent = "gscout",
    hidden = true,
    create = function(p) GL:Create(p) end,
    onShow = function() GL:Refresh() end,
})
