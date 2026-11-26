-- CBAS - Theme: einheitlicher, flacher Look fuer alle Fenster
--   ns.T.C              Farben (Akzent = Einhorn-Pink)
--   ns.T.Button(...)    flacher Knopf: "primary" (pink), "normal", "quiet" (nur Text)
--   ns.T.Toggle(...)    Schalter mit Beschriftung und Erklaerzeile
--   ns.T.Section(...)   Abschnitts-Ueberschrift mit Linie
--   ns.T.Card(...)      Flaeche mit dezentem Rand
--   ns.T.Skin(frame)    macht vorhandene Blizzard-Knoepfe, Haekchen, Eingabefelder,
--                       Rahmen und Scrollbalken in einem Bereich flach (einmalig je Element)
local ADDON, ns = ...
local T = {}
ns.T = T

local WHITE = "Interface\\Buttons\\WHITE8x8"
local unpack = unpack or table.unpack
T.WHITE = WHITE

T.C = {
    bg       = { 0.071, 0.075, 0.090, 0.97 },
    side     = { 0.047, 0.051, 0.063, 0.98 },
    head     = { 0.082, 0.086, 0.104, 0.98 },
    card     = { 1, 1, 1, 0.035 },
    line     = { 1, 1, 1, 0.08 },
    lineHi   = { 1, 1, 1, 0.20 },
    btn      = { 1, 1, 1, 0.06 },
    text     = { 0.93, 0.93, 0.95 },
    dim      = { 0.56, 0.58, 0.63 },
    accent   = { 1.00, 0.25, 0.63 },
    accentHi = { 1.00, 0.45, 0.74 },
    ok       = { 0.33, 0.86, 0.47 },
    warn     = { 1.00, 0.78, 0.22 },
    bad      = { 1.00, 0.33, 0.33 },
}
-- Farbcodes fuer Texte
T.HEX = { accent = "|cffff40a0", dim = "|cff8f949f", ok = "|cff55dc78", warn = "|cffffc738", bad = "|cffff5555", text = "|cffededf2" }

local function tex(f, layer, sub)
    local t = f:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetTexture(WHITE)
    return t
end

-- Flaeche + 1-px-Rand; mehrfach aufrufbar (aendert dann nur die Farben)
function T.Box(f, bg, border)
    local b = rawget(f, "_cbasBox")
    if not b then
        b = {}
        b.bg = tex(f, "BACKGROUND", -6)
        b.bg:SetAllPoints()
        b.t = tex(f, "BORDER", -6); b.t:SetPoint("TOPLEFT"); b.t:SetPoint("TOPRIGHT"); b.t:SetHeight(1)
        b.b = tex(f, "BORDER", -6); b.b:SetPoint("BOTTOMLEFT"); b.b:SetPoint("BOTTOMRIGHT"); b.b:SetHeight(1)
        b.l = tex(f, "BORDER", -6); b.l:SetPoint("TOPLEFT"); b.l:SetPoint("BOTTOMLEFT"); b.l:SetWidth(1)
        b.r = tex(f, "BORDER", -6); b.r:SetPoint("TOPRIGHT"); b.r:SetPoint("BOTTOMRIGHT"); b.r:SetWidth(1)
        rawset(f, "_cbasBox", b)
    end
    bg = bg or T.C.card
    border = border or T.C.line
    b.bg:SetVertexColor(bg[1], bg[2], bg[3], bg[4] or 1)
    for _, k in ipairs({ "t", "b", "l", "r" }) do b[k]:SetVertexColor(border[1], border[2], border[3], border[4] or 1) end
    return b
end

function T.Card(parent, w, h)
    local c = CreateFrame("Frame", nil, parent)
    if w then c:SetSize(w, h or 40) end
    T.Box(c, T.C.card, T.C.line)
    return c
end

---------------------------------------------------------------------------
-- Knoepfe
---------------------------------------------------------------------------
local KIND = {
    primary = { bg = { 1.00, 0.25, 0.63, 0.88 }, border = { 1.00, 0.50, 0.78, 0.9 }, font = "GameFontHighlight" },
    normal  = { bg = { 1, 1, 1, 0.06 }, border = { 1, 1, 1, 0.13 }, font = "GameFontHighlight" },
    quiet   = { bg = { 1, 1, 1, 0 }, border = { 1, 1, 1, 0 }, font = "GameFontHighlight", dim = true },
}
T.KIND = KIND

-- Grossbuchstaben inkl. Umlaute (string.upper laesst UTF-8-Umlaute sonst klein)
function T.Upper(s)
    s = string.upper(s or "")
    return (s:gsub("ä", "Ä"):gsub("ö", "Ö"):gsub("ü", "Ü"))
end

-- gedimmte Schrift fuer leise Knoepfe (beim Ueberfahren wird sie weiss)
local dimFont
local function DimFont()
    if dimFont ~= nil then return dimFont or nil end
    dimFont = false
    if CreateFont and _G.GameFontHighlight then
        local ok, f = pcall(CreateFont, "CBASFontDim")
        if ok and f and f.CopyFontObject then
            f:CopyFontObject(_G.GameFontHighlight)
            f:SetTextColor(T.C.dim[1], T.C.dim[2], T.C.dim[3])
            dimFont = f
        end
    end
    return dimFont or nil
end

local function Paint(b)
    local k = KIND[rawget(b, "_cbasKind") or "normal"] or KIND.normal
    local box = T.Box(b, k.bg, k.border)
    if rawget(b, "_cbasActive") then
        local a = T.C.accent
        box.bg:SetVertexColor(a[1], a[2], a[3], 0.20)
        for _, s in ipairs({ "t", "b", "l", "r" }) do box[s]:SetVertexColor(a[1], a[2], a[3], 0.85) end
    end
    local off = b.IsEnabled and b:IsEnabled() == false
    if off then
        box.bg:SetVertexColor(k.bg[1], k.bg[2], k.bg[3], (k.bg[4] or 1) * 0.35)
    end
    -- Schrift ueber Font-Objekte, damit die Farbe beim Ueberfahren nicht verloren geht
    if b.SetNormalFontObject then
        local on = rawget(b, "_cbasActive")
        local normal = (k.dim and not on) and (DimFont() or k.font) or k.font
        b:SetNormalFontObject(normal)
        b:SetHighlightFontObject(k.font)
        b:SetDisabledFontObject("GameFontDisable")
    end
end
T.Paint = Paint

-- Aktiv-Zustand (z. B. gewaehlter Modus); LockHighlight der alten Knoepfe nutzt das automatisch
function T.SetActive(b, on)
    rawset(b, "_cbasActive", on and true or false)
    Paint(b)
end

function T.SetKind(b, kind)
    rawset(b, "_cbasKind", kind)
    Paint(b)
end

local function HookStates(b)
    if rawget(b, "_cbasHooked") then return end
    rawset(b, "_cbasHooked", true)
    -- Hervorhebung beim Ueberfahren
    if b.SetHighlightTexture then
        b:SetHighlightTexture(WHITE)
        local h = b.GetHighlightTexture and b:GetHighlightTexture()
        if h and h.SetVertexColor then h:SetVertexColor(1, 1, 1, 0.07); h:SetAllPoints() end
    end
    -- alte Knoepfe merken "gewaehlt" ueber LockHighlight
    local lock, unlock = b.LockHighlight, b.UnlockHighlight
    if lock and unlock then
        b.LockHighlight = function(s) lock(s); T.SetActive(s, true) end
        b.UnlockHighlight = function(s) unlock(s); T.SetActive(s, false) end
    end
    local en, dis = b.Enable, b.Disable
    if en and dis then
        b.Enable = function(s) en(s); Paint(s) end
        b.Disable = function(s) dis(s); Paint(s) end
    end
    local setEn = b.SetEnabled
    if setEn then b.SetEnabled = function(s, v) setEn(s, v); Paint(s) end end
end

-- neuer flacher Knopf
function T.Button(parent, text, w, h, kind)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 100, h or 22)
    local k = KIND[kind or "normal"] or KIND.normal
    if b.SetNormalFontObject then b:SetNormalFontObject(k.font) end
    if b.SetPushedTextOffset then b:SetPushedTextOffset(0, -1) end
    b:SetText(text or "")
    rawset(b, "_cbasKind", kind or "normal")
    rawset(b, "_cbasSkinned", true)
    HookStates(b)
    Paint(b)
    return b
end

-- vorhandenen Blizzard-Knopf (UIPanelButtonTemplate) flach machen
function T.StyleButton(b, kind)
    if rawget(b, "_cbasSkinned") then if kind then T.SetKind(b, kind) end return end
    rawset(b, "_cbasSkinned", true)
    for _, key in ipairs({ "Left", "Middle", "Right", "LeftSeparator", "RightSeparator" }) do
        local r = rawget(b, key)
        if type(r) == "table" and r.SetAlpha then r:SetAlpha(0) end
    end
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        local t = b[getter] and b[getter](b)
        if type(t) == "table" and t.SetAlpha then t:SetAlpha(0) end
    end
    rawset(b, "_cbasKind", kind or rawget(b, "_cbasKind") or "normal")
    HookStates(b)
    Paint(b)
end

---------------------------------------------------------------------------
-- Haekchen, Eingabefelder, Scrollbalken, Rahmen
---------------------------------------------------------------------------
function T.StyleCheck(cb)
    if rawget(cb, "_cbasSkinned") then return end
    rawset(cb, "_cbasSkinned", true)
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        local t = cb[getter] and cb[getter](cb)
        if type(t) == "table" and t.SetAlpha then t:SetAlpha(0) end
    end
    local hl = cb.GetHighlightTexture and cb:GetHighlightTexture()
    if type(hl) == "table" and hl.SetAlpha then hl:SetAlpha(0.25) end
    local box = CreateFrame("Frame", nil, cb)
    box:SetSize(14, 14)
    box:SetPoint("CENTER")
    box:SetFrameLevel(math.max(0, (cb:GetFrameLevel() or 1) - 1))
    T.Box(box, { 0, 0, 0, 0.35 }, T.C.lineHi)
    local ck = cb.GetCheckedTexture and cb:GetCheckedTexture()
    if type(ck) == "table" and ck.SetTexture then
        ck:SetTexture(WHITE)
        ck:ClearAllPoints()
        ck:SetSize(8, 8)
        ck:SetPoint("CENTER")
        local a = T.C.accent
        ck:SetVertexColor(a[1], a[2], a[3], 1)
    end
end

function T.StyleEdit(e)
    if rawget(e, "_cbasSkinned") then return end
    rawset(e, "_cbasSkinned", true)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        local r = rawget(e, key)
        if type(r) == "table" and r.SetAlpha then r:SetAlpha(0) end
    end
    local bg = CreateFrame("Frame", nil, e)
    bg:SetPoint("TOPLEFT", -6, 1)
    bg:SetPoint("BOTTOMRIGHT", 1, -1)
    bg:SetFrameLevel(math.max(0, (e:GetFrameLevel() or 1) - 1))
    T.Box(bg, { 0, 0, 0, 0.40 }, T.C.line)
    e:HookScript("OnEditFocusGained", function() T.Box(bg, { 0, 0, 0, 0.40 }, { T.C.accent[1], T.C.accent[2], T.C.accent[3], 0.8 }) end)
    e:HookScript("OnEditFocusLost", function() T.Box(bg, { 0, 0, 0, 0.40 }, T.C.line) end)
end

-- Rahmen aus BackdropTemplate mit Tooltip-Kante -> flach
local FLAT = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }
function T.StyleBackdrop(f)
    if rawget(f, "_cbasSkinned") or not (f.GetBackdrop and f.SetBackdrop) then return end
    local bd = f:GetBackdrop()
    if type(bd) ~= "table" or type(bd.edgeFile) ~= "string" or bd.edgeFile == WHITE then return end
    rawset(f, "_cbasSkinned", true)
    local r, g, b, a = 0, 0, 0, 0.5
    if f.GetBackdropColor then r, g, b, a = f:GetBackdropColor() end
    f:SetBackdrop(FLAT)
    -- dunkle Flaechen leicht ins Blaugraue ziehen, Deckkraft behalten
    if (r or 0) + (g or 0) + (b or 0) < 0.4 then r, g, b = 0.02, 0.022, 0.03 end
    f:SetBackdropColor(r or 0, g or 0, b or 0, math.min(0.92, math.max(0.30, a or 0.5)))
    f:SetBackdropBorderColor(T.C.line[1], T.C.line[2], T.C.line[3], T.C.line[4])
end

local function StyleThumb(t)
    if type(t) ~= "table" or not t.SetTexture then return end
    t:SetTexture(WHITE)
    t:SetVertexColor(1, 1, 1, 0.22)
    if t.SetSize then t:SetSize(6, 28) end
end

function T.StyleSlider(s)
    if rawget(s, "_cbasSkinned") then return end
    rawset(s, "_cbasSkinned", true)
    StyleThumb(s.GetThumbTexture and s:GetThumbTexture())
    T.StyleBackdrop(s)
end

function T.StyleScrollFrame(sf)
    local bar = rawget(sf, "ScrollBar")
    if type(bar) ~= "table" or rawget(bar, "_cbasSkinned") then return end
    rawset(bar, "_cbasSkinned", true)
    for _, key in ipairs({ "ScrollUpButton", "ScrollDownButton" }) do
        local btn = rawget(bar, key)
        if type(btn) == "table" and btn.SetAlpha then btn:SetAlpha(0.35) end
    end
    StyleThumb(rawget(bar, "ThumbTexture") or (bar.GetThumbTexture and bar:GetThumbTexture()))
end

-- Bereich einmal komplett durchgehen (nur Elemente, die noch nicht dran waren)
function T.Skin(root, depth)
    depth = depth or 0
    if not root or depth > 14 or rawget(root, "_cbasNoSkin") then return end
    local ot = root.GetObjectType and root:GetObjectType()
    if ot == "Button" then
        if type(rawget(root, "Left")) == "table" and type(rawget(root, "Middle")) == "table" then T.StyleButton(root) end
    elseif ot == "CheckButton" then
        local ck = root.GetCheckedTexture and root:GetCheckedTexture()
        if ck and not rawget(root, "_cbasToggle") then T.StyleCheck(root) end
    elseif ot == "EditBox" then
        if type(rawget(root, "Left")) == "table" then T.StyleEdit(root) end
    elseif ot == "Slider" then
        T.StyleSlider(root)
    elseif ot == "ScrollFrame" then
        T.StyleScrollFrame(root)
    end
    if ot and ot ~= "GameTooltip" then T.StyleBackdrop(root) end
    if root.GetChildren then
        for _, c in ipairs({ root:GetChildren() }) do T.Skin(c, depth + 1) end
    end
end

---------------------------------------------------------------------------
-- Schalter mit Beschriftung und Erklaerzeile
---------------------------------------------------------------------------
local function PaintToggle(cb)
    local on = cb:GetChecked() and true or false
    local a = T.C.accent
    if on then
        cb.track:SetVertexColor(a[1], a[2], a[3], 0.95)
        cb.knob:ClearAllPoints(); cb.knob:SetPoint("RIGHT", cb.trackFrame, "RIGHT", -2, 0)
    else
        cb.track:SetVertexColor(1, 1, 1, 0.14)
        cb.knob:ClearAllPoints(); cb.knob:SetPoint("LEFT", cb.trackFrame, "LEFT", 2, 0)
    end
end

-- onChange(cb) wird nach dem Umschalten aufgerufen; cb:GetChecked() liefert den neuen Wert
function T.Toggle(parent, label, desc, onChange, width)
    local cb = CreateFrame("CheckButton", nil, parent)
    rawset(cb, "_cbasToggle", true)
    rawset(cb, "_cbasSkinned", true)
    width = width or 560
    cb:SetSize(30, 16)
    local tf = CreateFrame("Frame", nil, cb)
    tf:SetAllPoints()
    tf:EnableMouse(false)
    cb.trackFrame = tf
    local track = tf:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(WHITE)
    track:SetAllPoints()
    cb.track = track
    local knob = tf:CreateTexture(nil, "ARTWORK")
    knob:SetTexture(WHITE)
    knob:SetSize(12, 12)
    knob:SetVertexColor(1, 1, 1, 1)
    cb.knob = knob
    local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 10, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(label or "")
    cb.label = fs
    if desc and desc ~= "" then
        local d = cb:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        d:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
        d:SetWidth(width - 44)
        d:SetJustifyH("LEFT")
        d:SetTextColor(T.C.dim[1], T.C.dim[2], T.C.dim[3])
        d:SetText(desc)
        cb.desc = d
    end
    -- ganze Zeile anklickbar
    if cb.SetHitRectInsets then cb:SetHitRectInsets(0, -(width - 30), -4, -4) end
    local orig = cb.SetChecked
    cb.SetChecked = function(s, v) orig(s, v); PaintToggle(s) end
    cb:SetScript("OnClick", function(s)
        PaintToggle(s)
        if PlaySound and SOUNDKIT then pcall(PlaySound, s:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF) end
        if onChange then onChange(s) end
    end)
    cb:SetScript("OnEnter", function() fs:SetTextColor(1, 1, 1) end)
    cb:SetScript("OnLeave", function() fs:SetTextColor(T.C.text[1], T.C.text[2], T.C.text[3]) end)
    fs:SetTextColor(T.C.text[1], T.C.text[2], T.C.text[3])
    PaintToggle(cb)
    -- Hoehe der Zeile fuer das Stapeln
    cb.rowHeight = (desc and desc ~= "") and 40 or 26
    return cb
end

-- Abschnitt: kleine Ueberschrift in Grossbuchstaben + feine Linie
function T.Section(parent, text, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetText(T.Upper(text))
    fs:SetTextColor(T.C.accentHi[1], T.C.accentHi[2], T.C.accentHi[3])
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture(WHITE)
    line:SetVertexColor(T.C.line[1], T.C.line[2], T.C.line[3], T.C.line[4])
    line:SetHeight(1)
    line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
    line:SetWidth(math.max(20, (width or 560) - (fs:GetStringWidth() or 60) - 10))
    fs.line = line
    return fs
end

-- Tooltip an ein Element haengen (ohne vorhandene Skripte zu ersetzen)
function T.Tip(widget, title, body)
    widget:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(title, 1, 1, 1, 1, true)
        if body then GameTooltip:AddLine(body, T.C.dim[1], T.C.dim[2], T.C.dim[3], true) end
        GameTooltip:Show()
    end)
    widget:HookScript("OnLeave", GameTooltip_Hide)
end

---------------------------------------------------------------------------
-- Nebenfenster (Kurve, Preisverlauf, Export) im selben Look wie das Hauptfenster
-- Liefert f.title / f.TitleText wie BasicFrameTemplate, damit alter Code weiterlaeuft
---------------------------------------------------------------------------
function T.Window(name, parent)
    local f = CreateFrame("Frame", name, parent or UIParent)
    T.Box(f, T.C.bg, { 1, 1, 1, 0.10 })
    local sh = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    sh:SetTexture(WHITE)
    sh:SetVertexColor(0, 0, 0, 0.45)
    sh:SetPoint("TOPLEFT", -4, 4)
    sh:SetPoint("BOTTOMRIGHT", 4, -4)
    local head = f:CreateTexture(nil, "BACKGROUND", nil, -5)
    head:SetTexture(WHITE)
    head:SetVertexColor(unpack(T.C.head))
    head:SetPoint("TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", -1, -1)
    head:SetHeight(26)
    local line = f:CreateTexture(nil, "BORDER")
    line:SetTexture(WHITE)
    line:SetVertexColor(unpack(T.C.line))
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 1, -27)
    line:SetPoint("TOPRIGHT", -1, -27)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("TOPLEFT", 14, -8)
    t:SetPoint("TOPRIGHT", -36, -8)
    t:SetJustifyH("LEFT")
    t:SetTextColor(1, 1, 1)
    f.TitleText = t
    f.title = t
    local close = CreateFrame("Button", nil, f)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -6, -5)
    local ct = close:CreateTexture(nil, "ARTWORK")
    ct:SetTexture("Interface\\Buttons\\UI-StopButton")
    ct:SetAllPoints()
    ct:SetVertexColor(T.C.dim[1], T.C.dim[2], T.C.dim[3])
    close:SetScript("OnEnter", function() ct:SetVertexColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() ct:SetVertexColor(T.C.dim[1], T.C.dim[2], T.C.dim[3]) end)
    close:SetScript("OnClick", function() f:Hide() end)
    f.CloseButton = close
    f:HookScript("OnShow", function(s) pcall(T.Skin, s) end)
    return f
end
