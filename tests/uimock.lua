-- generisches Frame-Mock: jede Methode existiert
local function newObj()
  local o = { _shown = true, _text = "", _scripts = {}, _checked = false }
  return setmetatable(o, { __index = function(t, k)
    local fixed = {
      Show = function(s) s._shown = true; if s._scripts.OnShow then s._scripts.OnShow(s) end end,
      Hide = function(s) s._shown = false end,
      SetShown = function(s, v) if v then s:Show() else s:Hide() end end,
      IsShown = function(s) return s._shown end,
      IsVisible = function(s) local p = s while p do if not p._shown then return false end p = p._parent end return true end,
      SetText = function(s, v) s._text = v end, GetText = function(s) return s._text end,
      SetChecked = function(s, v) s._checked = v end, GetChecked = function(s) return s._checked end,
      SetScript = function(s, n, f) s._scripts[n] = f end, HookScript = function(s, n, f) s._scripts[n] = f end,
      GetScript = function(s, n) return s._scripts[n] end,
      CreateFontString = function(s) local x = newObj(); x._parent = s; return x end,
      CreateTexture = function(s) local x = newObj(); x._parent = s; return x end,
      GetFontString = function(s) local x = rawget(s, "_fs") if not x then x = newObj(); rawset(s, "_fs", x) end return x end,
      GetStringWidth = function() return 50 end, GetStringHeight = function() return 12 end,
      HasFocus = function() return false end,
      SetScale = function(s, v) rawset(s, "_scale", v) end, GetScale = function(s) return rawget(s, "_scale") or 1 end,
      GetEffectiveScale = function(s) return rawget(s, "_scale") or 1 end,
      GetWidth = function() return 860 end, GetHeight = function() return 573 end,
      GetLeft = function() return 100 end, GetTop = function() return 700 end, GetValue = function() return 0 end,
    }
    if fixed[k] then return fixed[k] end
    if k == 'Text' or k == 'text' or k == 'TitleText' or k:sub(1,1) == '_' or k:lower() == k then return nil end
    return function() end
  end })
end
CreateFrame = function(_, name, parent) local o = newObj(); o._parent = parent; if name then _G[name] = o end; table.insert(FRAMES, o); o.SetScript = function(s,n,f) s._scripts[n]=f; if n=="OnEvent" then s.h=f end end; return o end
UIParent = newObj()
UISpecialFrames = {}
tinsert = table.insert
StaticPopupDialogs = {}
StaticPopup_Show = function() end
GameTooltip = newObj()
GameTooltip_Hide = function() end
RAID_CLASS_COLORS = { WARRIOR = { colorStr = "ffc79c6e" }, MAGE = { colorStr = "ff69ccf0" } }
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Krieger", MAGE = "Magier" }
UnitFactionGroup = function() return "Horde" end
YES = "Ja"; NO = "Nein"
SlashCmdList = {}
