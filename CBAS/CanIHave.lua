-- CBAS - "Can I have it": Offspec-Ausruestung fair bekommen, ohne wie ein Geier zu wirken.
-- Bei jedem Drop prueft CBAS fuer DICH:
--   * Passt das Teil zu deiner Klasse (Ruestung, Waffe, Werte) - sonst Finger weg.
--   * Ist es Main- oder Offspec fuer dich?
--   * Wer in der Gruppe koennte es als MAINSPEC brauchen?  -> die haben Vorrang
--   * Hast du in diesem Run schon etwas bekommen?           -> Fairness
--   * BoE (wertvoll)?                                       -> fragen wirkt gierig
-- Daraus kommt ein klarer Rat und - wenn es fair ist - ein hoeflicher, fertiger Text.
-- CBAS schreibt NIE selbst in den Chat: der Text landet in deiner Eingabezeile, du drueckst Enter.
local ADDON, ns = ...
local S = ns.S
local GW = ns.Geier
local CI = {}
ns.CanIHave = CI

local ROLE_DE = { TANK = "Tank", HEAL = "Heil", CASTER = "Caster", PHYS = "DD" }
local ROLE_EN = { TANK = "tank", HEAL = "healing", CASTER = "caster", PHYS = "dps" }
local T = {
    de = {
        ask = {
            "Darf ich %s für meine %s-Offspec haben? Wer es als Mainspec braucht, hat natürlich Vorrang.",
            "Falls keiner %s als Mainspec braucht: Könnte ich es für meine %s-Offspec haben?",
            "Kurze Frage: %s wäre super für meine %s-Offspec. Mainspec geht aber vor!",
        },
        whisper = "Hi! Falls du %s nicht brauchst: Ich könnte es gut für meine %s-Offspec gebrauchen. Handeln geht noch knapp 2 Std. Kein Stress, danke!",
        reason = { "Bedarf auf %s für meine %s-Offspec - als Mainspec braucht es hier keiner.",
                   "%s: Bedarf für %s-Offspec, Mainspec-Bedarf hat niemand." },
        reasonMain = "Bedarf auf %s - Mainspec (%s).",
        thanks = { "Danke für %s, sehr nett!", "Vielen Dank für %s!" },
    },
    en = {
        ask = {
            "Could I have %s for my %s offspec? Main spec need goes first, of course.",
            "If nobody needs %s for main spec: could I take it for my %s offspec?",
            "Quick question: %s would be great for my %s offspec. MS goes first though!",
        },
        whisper = "Hi! If you don't need %s: it would be great for my %s offspec. It's tradeable for about 2h. No pressure, thanks!",
        reason = { "Need on %s for my %s offspec - nobody here needs it for main spec.",
                   "%s: need for %s offspec, no main spec need in the group." },
        reasonMain = "Need on %s - main spec (%s).",
        thanks = { "Thanks a lot for %s!", "Thank you for %s, much appreciated!" },
    },
}

function CI.db()
    local s = ns.db.settings
    s.cihi = s.cihi or { popup = true, lang = "auto" }
    ns.db.cihi = ns.db.cihi or {}
    return s.cihi, ns.db.cihi
end

function CI.MyClass() return select(2, UnitClass("player")) end

-- deine Rollen: Main + Offspecs (eingestellt oder automatisch)
function CI.MyRoles()
    local s = CI.db()
    local class = CI.MyClass()
    local possible = GW.CLASS_ROLES[class or ""] or {}
    local main = s.main
    if not main then main = GW.PlayerRoles(ns.playerFull, class) end
    main = main or possible[1]
    local offs = {}
    if s.off then
        offs[1] = s.off
    else
        for _, r in ipairs(possible) do if r ~= main then offs[#offs + 1] = r end end
    end
    return main, offs, possible
end

-- Sprache der Gruppe: Deutsch nur, wenn alle bekannten Mitspieler deutschsprachig sind
function CI.Lang()
    local s = CI.db()
    if s.lang == "de" or s.lang == "en" then return s.lang end
    if GetLocale and GetLocale() ~= "deDE" then return "en" end
    local CF = ns.ChatFlags
    if not CF then return "de" end
    for _, unit in ipairs(GW.GroupUnits()) do
        if unit ~= "player" and UnitExists(unit) then
            local n, r = UnitName(unit)
            n, r = S(n), S(r)
            local c = n and CF.CountryOf(ns.FullName(n, r))
            if c and c ~= "DE" and c ~= "AT" and c ~= "CH" then return "en" end
        end
    end
    return "de"
end

-- Teile, die du in diesem Run schon bekommen hast
local function GotThisRun()
    local run = GW.CurrentRun and GW.CurrentRun()
    if not run then return 0 end
    local n = 0
    for _, h in ipairs(GW.db().history or {}) do
        if h.run == run.id and h.player == ns.playerFull and h.won then n = n + 1 end
    end
    return n
end

-- Kern: Darf ich Bedarf wuerfeln? Dieselben Regeln, mit denen die Geierwacht alle anderen
-- bewertet - nur auf dich angewendet.
-- state:
--   "need"  Bedarf ok (Mainspec, oder Offspec und niemand braucht es als Mainspec)
--   "risky" Bedarf vertretbar, aber nur mit Begruendung (z.B. Leder statt Platte, Werte passen)
--   "wait"  jemand braucht es als MAINSPEC -> der hat Vorrang (kein OK)
--   "boe"   BoE: Bedarf nur, wenn du es wirklich anlegst - sonst Gier
--   "no"    passt nicht zu dir -> wuerde jeder als Geier sehen
--   "pending" Daten laden noch
function CI.Check(link)
    local class = CI.MyClass()
    local verdict, why, extra = GW.Evaluate(link, class, UnitLevel("player"))
    local r = { link = link, t = time() }
    if verdict == "pending" then r.state = "pending" return r end
    if verdict == "info" then r.state = "info"; r.why = why return r end
    r.verdict, r.vwhy = verdict, why
    if verdict == "geier" then
        r.state, r.why = "no", "Passt nicht zu dir (" .. (why or "?") .. "). Bedarf würde jeder als Geier sehen - Gier oder Passen."
        return r
    end
    local roles = (extra and extra.roles) or {}
    local main, offs = CI.MyRoles()
    if roles[main] then
        r.role, r.isMain = main, true
    else
        for _, o in ipairs(offs) do
            if roles[o] then r.role = o break end
        end
    end
    if not r.role and next(roles) then
        r.state, r.why = "no", "Werte passen zu keiner deiner Specs (" .. GW.RoleList(roles) .. "). Bedarf würde nach Geier aussehen."
        return r
    end
    r.role = r.role or main          -- z.B. Ringe/Umhänge ohne klare Rolle
    -- wer koennte es als Mainspec brauchen?
    r.ms, r.maybe = {}, {}
    if not r.isMain then
        for _, unit in ipairs(GW.GroupUnits()) do
            if unit ~= "player" and UnitExists(unit) then
                local n, rl = UnitName(unit)
                n, rl = S(n), S(rl)
                local _, cls = UnitClass(unit)
                cls = S(cls)
                if n and cls then
                    local full = ns.FullName(n, rl)
                    local v = GW.Evaluate(link, cls, S(UnitLevel(unit)))
                    if v == "ok" then
                        local fit = GW.RoleFit(roles, full, cls)
                        if fit == "main" then r.ms[#r.ms + 1] = n
                        elseif fit == "possible" then r.maybe[#r.maybe + 1] = n end
                    end
                end
            end
        end
    end
    r.got = GotThisRun()
    local roleTxt = GW.ROLE_NAMES[r.role] or r.role or "?"
    local note = (verdict == "frag") and (" Achtung: " .. (why or "") .. ".") or ""
    if extra and extra.boe and not r.isMain then
        r.state, r.why = "boe", "BoE (Gold wert). Bedarf nur, wenn du es wirklich anlegst - sonst wirkt es wie Geld-Geier. Normal: Gier."
    elseif r.isMain then
        r.state = verdict == "frag" and "risky" or "need"
        r.why = "Mainspec (" .. roleTxt .. ") - Bedarf ganz normal." .. note
    elseif #r.ms > 0 then
        r.state, r.why = "wait", "Offspec (" .. roleTxt .. "), aber " .. table.concat(r.ms, ", ") ..
            " braucht es als Mainspec - die haben Vorrang. Kein Bedarf; höchstens nachfragen, falls sie passen."
    else
        r.state = verdict == "frag" and "risky" or "need"
        r.why = "Offspec (" .. roleTxt .. "), niemand in der Gruppe braucht es als Mainspec" ..
            (#r.maybe > 0 and (" (Offspec möglich bei: " .. table.concat(r.maybe, ", ") .. ")") or "") ..
            " - Bedarf ist vertretbar." .. note
    end
    if r.got > 0 and (r.state == "need" or r.state == "risky") and not r.isMain then
        r.why = r.why .. " Du hast in diesem Run schon " .. r.got .. " Teil(e)."
    end
    return r
end

---------------------------------------------------------------------------
-- Texte in die Eingabezeile legen (der Spieler drueckt selbst Enter)
---------------------------------------------------------------------------
local function GroupSlash()
    if IsInRaid and IsInRaid() then return "/ra " end
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "/i " end
    if IsInGroup and IsInGroup() then return "/p " end
    return "/s "
end

local function Pick(list, seed)
    if type(list) == "string" then return list end
    return list[(seed % #list) + 1]
end

local function RoleWord(role, lang) return (lang == "en" and ROLE_EN or ROLE_DE)[role] or role end

function CI.Ask(e)
    local lang = CI.Lang()
    e.n = (e.n or 0) + 1
    local txt = Pick(T[lang].ask, e.n + (e.t or 0)):format(e.link, RoleWord(e.role, lang))
    if ChatFrame_OpenChat then ChatFrame_OpenChat(GroupSlash() .. txt) end
    e.asked = time()
    CI.Changed()
end

-- ehrliche Begruendung in die Gruppe (wenn jemand fragt "wieso Bedarf?")
function CI.Reason(e)
    local lang = CI.Lang()
    local tpl = e.isMain and T[lang].reasonMain or Pick(T[lang].reason, e.t or 0)
    local txt = tpl:format(e.link, RoleWord(e.role, lang))
    if ChatFrame_OpenChat then ChatFrame_OpenChat(GroupSlash() .. txt) end
    e.reasoned = time()
    CI.Changed()
end

function CI.WhisperWinner(e)
    if not e.winner then return end
    local lang = CI.Lang()
    local txt = T[lang].whisper:format(e.link, RoleWord(e.role, lang))
    if ChatFrame_SendTell then
        ChatFrame_SendTell(e.winner)
        local eb = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
        if eb then eb:Insert(txt) end
    elseif ChatFrame_OpenChat then
        ChatFrame_OpenChat("/w " .. e.winner .. " " .. txt)
    end
    e.whispered = time()
    CI.Changed()
end

function CI.Thanks(e)
    local lang = CI.Lang()
    local txt = Pick(T[lang].thanks, e.t or 0):format(e.link)
    if e.from and ChatFrame_SendTell then
        ChatFrame_SendTell(e.from)
        local eb = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
        if eb then eb:Insert(txt) end
    elseif ChatFrame_OpenChat then
        ChatFrame_OpenChat(GroupSlash() .. txt)
    end
    e.thanked = time()
    CI.Changed()
end

---------------------------------------------------------------------------
-- Liste der Gelegenheiten (fuer die Ansicht) + Popup
---------------------------------------------------------------------------
local STATE_TXT = {
    need = "|cff40ff40BEDARF OK|r", risky = "|cffff8000Bedarf mit Begründung|r", wait = "|cffffd100MS hat Vorrang|r",
    boe = "|cffffd100BoE: nur wenn du's trägst|r", no = "|cffff4040Geier - kein Bedarf|r",
}
CI.STATE_TXT = STATE_TXT

function CI.Changed()
    if CI.popup and CI.popup:IsShown() then CI.ShowPopup(CI.popup.e) end
    if CI.Refresh then pcall(CI.Refresh) end
end

local function Remember(r)
    local _, list = CI.db()
    for _, e in ipairs(list) do
        if e.link == r.link and time() - e.t < 900 then
            for k, v in pairs(r) do if e[k] == nil or k == "state" or k == "why" or k == "ms" then e[k] = v end end
            return e
        end
    end
    table.insert(list, 1, r)
    while #list > 40 do table.remove(list) end
    return r
end

function CI.OnDrop(link, tries)
    if not link then return end
    local r = CI.Check(link)
    if r.state == "pending" then
        if (tries or 0) < 5 then C_Timer.After(1, function() CI.OnDrop(link, (tries or 0) + 1) end) end
        return
    end
    if r.state == "info" then return end   -- kein Ausruestungsgegenstand
    local e = Remember(r)
    local s = CI.db()
    if s.popup ~= false then CI.ShowPopup(e) end
    CI.Changed()
end

-- jemand hat etwas gewonnen/erhalten
function CI.OnLoot(kind, full, link)
    if kind ~= "won" and kind ~= "got" then return end
    local _, list = CI.db()
    local e
    for _, x in ipairs(list) do
        if x.link == link and time() - x.t < 1800 then e = x break end
    end
    if full == ns.playerFull then
        if e then e.mine = true; CI.Changed() end
        return
    end
    -- Gewinner braucht es evtl. nicht (keine Mainspec bei ihm) -> hoeflich anfluestern moeglich
    if not e then
        local r = CI.Check(link)
        if r.state ~= "need" and r.state ~= "risky" and r.state ~= "wait" then return end
        e = Remember(r)
    end
    if e.mine then return end
    local cls, lvl = GW.PlayerInfo(full)
    local fit = "none"
    if cls then
        local v, _, ex = GW.Evaluate(link, cls, lvl)
        if v == "ok" and ex then fit = GW.RoleFit(ex.roles, full, cls) or "none" end
    end
    e.winner = full
    e.winnerFit = fit
    e.canWhisper = (fit ~= "main")
    CI.Changed()
end

---------------------------------------------------------------------------
-- Popup
---------------------------------------------------------------------------
local function Popup()
    if CI.popup then return CI.popup end
    local f = CreateFrame("Frame", "CBASCanIHave", UIParent, "BackdropTemplate")
    f:SetSize(380, 130)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        CI.db().pos = { p, rp, x, y }
    end)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        f:SetBackdropColor(0, 0, 0, 0.9)
    end
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -9)
    title:SetText("|cff33ccffCan I have it?|r |cff888888Darf ich Bedarf würfeln?|r")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    local item = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    item:SetPoint("TOPLEFT", 10, -28)
    item:SetPoint("TOPRIGHT", -10, -28)
    item:SetJustifyH("LEFT")
    f.item = item
    local why = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    why:SetPoint("TOPLEFT", 10, -46)
    why:SetPoint("TOPRIGHT", -10, -46)
    why:SetJustifyH("LEFT")
    why:SetJustifyV("TOP")
    why:SetSpacing(2)
    f.why = why
    local function B(text, w)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(w, 22)
        b:SetText(text)
        return b
    end
    f.ask = B("Begründung posten", 130)
    f.ask:SetPoint("BOTTOMLEFT", 8, 8)
    f.ask:SetScript("OnClick", function()
        if f.e.state == "wait" or f.e.state == "boe" then CI.Ask(f.e) else CI.Reason(f.e) end
    end)
    f.whisper = B("Gewinner fragen", 120)
    f.whisper:SetPoint("LEFT", f.ask, "RIGHT", 4, 0)
    f.whisper:SetScript("OnClick", function() CI.WhisperWinner(f.e) end)
    f.thanks = B("Danke sagen", 110)
    f.thanks:SetPoint("LEFT", f.whisper, "RIGHT", 4, 0)
    f.thanks:SetScript("OnClick", function() CI.Thanks(f.e) end)
    for _, b in ipairs({ f.ask, f.whisper, f.thanks }) do
        b:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Der Text landet in deiner Chat-Eingabe - du kannst ihn noch ändern und schickst ihn selbst mit Enter.", 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", GameTooltip_Hide)
    end
    f:Hide()
    CI.popup = f
    return f
end

function CI.ShowPopup(e)
    if not e then return end
    local f = Popup()
    f.e = e
    f.item:SetText(e.link .. "  " .. (STATE_TXT[e.state] or ""))
    local L = { e.why or "" }
    if e.asked then L[#L + 1] = "|cff888888Gefragt um " .. date("%H:%M", e.asked) .. ".|r" end
    if e.winner and not e.mine then
        L[#L + 1] = e.canWhisper and ("|cffffd100" .. e.winner .. " hat es bekommen, braucht es aber wohl nicht als Mainspec.|r")
            or ("|cff888888" .. e.winner .. " hat es bekommen (Mainspec) - passt so.|r")
    end
    if e.mine then L[#L + 1] = "|cff40ff40Du hast es bekommen!|r" end
    f.why:SetText(table.concat(L, "\n"))
    local isWait = e.state == "wait" or e.state == "boe"
    f.ask:SetText(isWait and "Höflich fragen" or "Begründung posten")
    f.ask:SetEnabled(e.state ~= "no" and not e.mine and not (isWait and e.winner) and true or false)
    f.whisper:SetEnabled(e.winner and e.canWhisper and not e.mine and true or false)
    f.thanks:SetEnabled(e.mine and true or false)
    f:ClearAllPoints()
    local pos = CI.db().pos
    if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("TOP", UIParent, "TOP", 0, -140) end
    f:SetHeight(84 + math.max(1, #L) * 14 + (#(e.why or "") > 70 and 14 or 0))
    f:Show()
    f.shownAt = GetTime()
    local at = f.shownAt
    C_Timer.After(90, function() if f.e == e and f.shownAt == at then f:Hide() end end)
end

---------------------------------------------------------------------------
-- Events (nur bei Beute - kostet sonst nichts)
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, a1)
    if event == "PLAYER_LOGIN" then
        pcall(ev.RegisterEvent, ev, "START_LOOT_ROLL")
        pcall(ev.RegisterEvent, ev, "CHAT_MSG_LOOT")
    elseif event == "START_LOOT_ROLL" then
        local link = GetLootRollItemLink and S(GetLootRollItemLink(a1))
        if link then pcall(CI.OnDrop, link) end
    elseif event == "CHAT_MSG_LOOT" then
        local msg = S(a1)
        if not msg then return end
        local ok, kind, player, link = pcall(GW.ParseLootMessage, msg)
        if not ok or not kind then return end
        player = S(player)
        if not player then return end
        player = player:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
        pcall(CI.OnLoot, kind, ns.NormFull(player), link:match("(|c%x+|Hitem:.-|h.-|h|r)") or link)
    end
end)
