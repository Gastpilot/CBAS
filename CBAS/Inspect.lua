-- CBAS (Craphunts Blacklisted Addon Suite) - Inspektion: echte Gildengroesse, Itemlevel, Spezialisierung/Rolle
-- Beim Anvisieren (oder Mouseover in Reichweite) wird ein Gildenmitglied im Hintergrund
-- inspiziert. Das Spiel liefert dann u.a. die tatsaechliche Mitgliederzahl seiner Gilde.
local ADDON, ns = ...
local S = ns.S

local Insp = { last = -100 }
ns.Inspect = Insp

local GUILD_REFRESH = 6 * 3600     -- Gildengroesse hoechstens alle 6 Std. neu holen
local MEMBER_REFRESH = 3 * 86400   -- Itemlevel/Spec je Spieler alle 3 Tage

local function Allowed()
    if not ns.db or not ns.db.settings.inspect then return false end
    if InCombatLockdown() or IsInInstance() then return false end
    if InspectFrame and InspectFrame:IsShown() then return false end  -- Spieler inspiziert selbst
    return NotifyInspect ~= nil and CanInspect ~= nil
end

function Insp:Try(unit)
    if not Allowed() then return end
    if GetTime() - self.last < 4 then return end
    if not UnitExists(unit) or not S(UnitIsPlayer(unit)) then return end
    if S(UnitIsUnit(unit, "player")) then return end
    local ok, can = pcall(CanInspect, unit, false)
    if not ok or not S(can) then return end
    -- grobe Reichweite (Inspektion klappt nur in der Naehe)
    if CheckInteractDistance then
        local ok2, near = pcall(CheckInteractDistance, unit, 1)
        if ok2 and S(near) == false then return end
    end
    local gName = S(GetGuildInfo(unit))
    if not gName or gName == "" then return end
    local g = ns.db.guilds[gName]
    if not g then return end
    local name, realm = UnitName(unit)
    name, realm = S(name), S(realm)
    if not name then return end
    local full = ns.NormFull(ns.FullName(name, realm))
    local m = g.members[full]
    local now = time()
    local needGuild = not g.inspect or now - (g.inspect.t or 0) > GUILD_REFRESH
    local needMember = m and (not m.inspT or now - m.inspT > MEMBER_REFRESH)
    if not needGuild and not needMember then return end
    local guid = S(UnitGUID(unit))
    if not guid then return end
    self.last = GetTime()
    self.pending = { guid = guid, unit = unit, full = full, key = gName, t = GetTime() }
    pcall(NotifyInspect, unit)
end

local function FindUnit(guid, preferred)
    for _, u in ipairs({ preferred or "target", "target", "mouseover", "focus" }) do
        if UnitExists(u) and S(UnitGUID(u)) == guid then return u end
    end
end

function Insp:OnReady(guid)
    local p = self.pending
    guid = S(guid)
    if not p or not guid or guid ~= p.guid then return end
    self.pending = nil
    local unit = FindUnit(guid, p.unit)
    if not unit then return end
    local g = p.key and ns.db.guilds[p.key]
    local now = time()

    -- Spezialisierung lesen (fuer GScout und Geierwacht)
    local specName, specRole
    if GetInspectSpecialization and GetSpecializationInfoByID then
        local ok, spec = pcall(GetInspectSpecialization, unit)
        spec = ok and S(spec)
        if spec and spec > 0 then
            local ok2, _, sn, _, _, role = pcall(GetSpecializationInfoByID, spec)
            if ok2 then specName, specRole = S(sn), S(role) end
        end
    end
    if ns.Geier and specRole then
        local gp = ns.Geier.db().players[p.full] or {}
        ns.Geier.db().players[p.full] = gp
        gp.spec, gp.specRole, gp.specT = specName, specRole, now
        local _, cls = UnitClass(unit)
        gp.class = gp.class or S(cls)
        if ns.Geier.Refresh then ns.Geier.Refresh() end
    elseif ns.Geier and p.forGroup then
        local gp = ns.Geier.db().players[p.full] or {}
        ns.Geier.db().players[p.full] = gp
        gp.specT = now   -- nichts lesbar: nicht sofort erneut versuchen
    end
    if not g then
        if ClearInspectPlayer and not (InspectFrame and InspectFrame:IsShown()) then pcall(ClearInspectPlayer) end
        return
    end

    -- 1) Gildeninfo: echte Mitgliederzahl (+ Erfolgspunkte, falls vorhanden)
    if GetInspectGuildInfo then
        local ok, points, numMembers, gName = pcall(GetInspectGuildInfo, unit)
        numMembers, points, gName = S(numMembers), S(points), S(gName)
        if ok and numMembers and numMembers > 0 and (not gName or gName == g.name) then
            g.inspect = { members = numMembers, points = points, t = now, from = p.full }
            if (g.inspectMax or 0) < numMembers then g.inspectMax = numMembers end
        end
    end

    -- 2) Spieler: Itemlevel und Spezialisierung/Rolle
    local m = g.members[p.full]
    if m then
        if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
            local ok, ilvl = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
            ilvl = ok and S(ilvl)
            if ilvl and ilvl > 0 then m.ilvl = math.floor(ilvl + 0.5) end
        end
        if specName then m.spec = specName end
        if specRole then m.role = specRole end
        m.inspT = now
    end
    if ClearInspectPlayer and not (InspectFrame and InspectFrame:IsShown()) then
        pcall(ClearInspectPlayer)
    end
    ns.RefreshUI()
end

-- Gruppenmitglieder nacheinander inspizieren, um ihre Spezialisierung zu kennen (Geierwacht)
local SPEC_REFRESH = 2 * 3600
function Insp:TryGroup()
    if not ns.db or not ns.db.settings.lootSpecInspect or not IsInGroup() then return end
    if InCombatLockdown() or (InspectFrame and InspectFrame:IsShown()) then return end
    if not (NotifyInspect and CanInspect and ns.Geier) then return end
    if GetTime() - self.last < 4 then return end
    local now = time()
    for _, unit in ipairs(ns.Geier.GroupUnits()) do
        if unit ~= "player" and UnitExists(unit) and S(UnitIsConnected(unit)) ~= false then
            local n, r = UnitName(unit)
            n, r = S(n), S(r)
            if n then
                local full = ns.NormFull(ns.FullName(n, r))
                local gp = ns.Geier.db().players[full]
                if not gp or not gp.specT or now - gp.specT > SPEC_REFRESH then
                    local ok, can = pcall(CanInspect, unit, false)
                    local near = true
                    if CheckInteractDistance then
                        local ok2, d = pcall(CheckInteractDistance, unit, 1)
                        if ok2 and S(d) == false then near = false end
                    end
                    local guid = S(UnitGUID(unit))
                    if ok and S(can) and near and guid then
                        self.last = GetTime()
                        local gName = S(GetGuildInfo(unit))
                        self.pending = { guid = guid, unit = unit, full = full, forGroup = true,
                            key = gName and ns.db.guilds[gName] and gName or nil, t = GetTime() }
                        pcall(NotifyInspect, unit)
                        return
                    end
                end
            end
        end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        pcall(ev.RegisterEvent, ev, "INSPECT_READY")
        pcall(ev.RegisterEvent, ev, "PLAYER_TARGET_CHANGED")
        pcall(ev.RegisterEvent, ev, "UPDATE_MOUSEOVER_UNIT")
        if C_Timer.NewTicker then
            C_Timer.NewTicker(6, function() pcall(Insp.TryGroup, Insp) end)
        end
    elseif event == "INSPECT_READY" then
        pcall(Insp.OnReady, Insp, arg1)
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- kurz warten, bis GetGuildInfo geladen ist und der Scan gelaufen ist
        C_Timer.After(0.5, function() pcall(Insp.Try, Insp, "target") end)
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        C_Timer.After(0.3, function() pcall(Insp.Try, Insp, "mouseover") end)
    end
end)
