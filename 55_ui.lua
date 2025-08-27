-- GROUP 55_ui: 5 file(s) merged

-- BEGIN 25_editbox_gfx.lua
 do
local _, ns = ...

-- Esconde as bordas/texturas do EditBox padrão (esquerda/centro/direita)
function ns.hideEditBoxGfx()
  local L = _G.ChatFrame1EditBoxLeft;  if L then L:Hide() end
  local M = _G.ChatFrame1EditBoxMid;   if M then M:Hide() end
  local R = _G.ChatFrame1EditBoxRight; if R then R:Hide() end
end

-- Restaura as bordas/texturas do EditBox padrão
function ns.showEditBoxGfx()
  local L = _G.ChatFrame1EditBoxLeft;  if L then L:Show() end
  local M = _G.ChatFrame1EditBoxMid;   if M then M:Show() end
  local R = _G.ChatFrame1EditBoxRight; if R then R:Show() end
end

 end
-- END 25_editbox_gfx.lua

-- BEGIN 45_menu_button.lua
 do
-- 45_menu_button.lua
local _, ns = ...

-- ===== helpers =====
local function MarkInside()
  ns.state.panelClickAt = GetTime() or 0
  ns.state.mouseInside  = true
end

local function RefocusEditBoxAfter(delay)
  delay = delay or 0.10
  if not (C_Timer and C_Timer.After) then return end
  C_Timer.After(delay, function()
    if ns.frames and ns.frames.panel and ns.frames.panel:IsShown() and ns.EDIT then
      ns.EDIT:Show()
      ns.EDIT:SetFocus()
      if ns.raiseTabsBar then ns.raiseTabsBar() end
    end
  end)
end

-- Sobe/wire menus: além de z-index, controla a FLAG de menu aberto
local function WireMenu(container)
  if not container or not container.HookScript or container.__hkd_wired then return end
  container.__hkd_wired = true
  container:HookScript("OnShow", function() ns.state.hkdMenuOpen = true;  MarkInside() end)
  container:HookScript("OnHide", function() ns.state.hkdMenuOpen = false; MarkInside(); RefocusEditBoxAfter(0.10) end)
  container:HookScript("OnMouseDown", function() MarkInside() end)
  container:HookScript("OnEnter",  function() ns.state.mouseInside = true end)
  container:HookScript("OnLeave",  function() ns.state.mouseInside = false end)
end

local function RaiseAndWireMenus()
  for i = 1, 10 do
    local f = _G["DropDownList"..i]
    if f then
      if f.SetToplevel then f:SetToplevel(true) end
      if f.SetFrameStrata then f:SetFrameStrata("TOOLTIP") end
      if f.SetFrameLevel and ns.frames and ns.frames.panel then
        f:SetFrameLevel(math.max((ns.frames.panel:GetFrameLevel() or 10) + 200, f:GetFrameLevel() or 1))
      end
      WireMenu(f)
    end
  end
  for _, name in ipairs({ "ChatMenu", "LanguageMenu", "EmoteMenu", "VoiceMacroMenu" }) do
    local f = _G[name]
    if f then
      if f.SetToplevel then f:SetToplevel(true) end
      if f.SetFrameStrata then f:SetFrameStrata("TOOLTIP") end
      if f.SetFrameLevel and ns.frames and ns.frames.panel then
        f:SetFrameLevel(math.max((ns.frames.panel:GetFrameLevel() or 10) + 200, f:GetFrameLevel() or 1))
      end
      WireMenu(f)
    end
  end
end

-- ===== Social/balloon placement =====
local function placeOnLeftBar(btn)
  local bar  = ns.frames and ns.frames.leftBar
  local slot = ns.frames and ns.frames.leftBarBottomSlot
  if not (btn and bar and slot and bar:IsShown()) then return false end

  btn:ClearAllPoints()
  btn:SetParent(slot)
  btn:SetFrameStrata("TOOLTIP")
  btn:SetFrameLevel((bar:GetFrameLevel() or 10) + 25)
  btn:SetSize(22,22)
  btn:SetPoint("CENTER", slot, "CENTER", 0, 0)
  if btn.SetAlpha then btn:SetAlpha(0.90) end
  if btn.SetScale then btn:SetScale((ns.CFG and ns.CFG.SCALE_CHATMENU) or 1.0) end
  btn:EnableMouse(true)
  btn:SetHitRectInsets(0,0,0,0)
  btn:Show()

  -- proteção do balão
  if not btn.__hkd_protected then
    btn.__hkd_protected = true
    btn:HookScript("OnMouseDown", function() MarkInside(); RaiseAndWireMenus() end)
    btn:HookScript("OnClick",     function() MarkInside(); RaiseAndWireMenus() end)
    btn:HookScript("OnEnter",     function() ns.state.mouseInside = true end)
    btn:HookScript("OnLeave",     function() ns.state.mouseInside = false end)
  end

  return true
end

-- Guarda/restaura posição ORIGINAL do ChatFrameMenuButton (para o chat default)
local _origBalloon
local function savePoints(f) local t={}; for i=1,f:GetNumPoints() do t[i] = { f:GetPoint(i) } end; return t end
local function restorePoints(f, pts) if not pts then return end; f:ClearAllPoints(); for _,p in ipairs(pts) do f:SetPoint(unpack(p)) end end
local function snapshotBalloon(btn)
  if _origBalloon then return end
  _origBalloon = {
    parent = btn:GetParent() or UIParent,
    points = savePoints(btn),
    strata = btn:GetFrameStrata(),
    level  = btn:GetFrameLevel(),
    w = btn:GetWidth(), h = btn:GetHeight(),
    scale  = btn:GetScale(),
    shown  = btn:IsShown(),
  }
end
local function restoreBalloon(btn)
  if not _origBalloon or not btn then return end
  btn:SetParent(_origBalloon.parent or UIParent)
  restorePoints(btn, _origBalloon.points)
  if _origBalloon.w and _origBalloon.h then btn:SetSize(_origBalloon.w,_origBalloon.h) end
  if _origBalloon.strata then btn:SetFrameStrata(_origBalloon.strata) end
  if _origBalloon.level  then btn:SetFrameLevel(_origBalloon.level) end
  if _origBalloon.scale  then btn:SetScale(_origBalloon.scale) end
  if _origBalloon.shown  then btn:Show() else btn:Hide() end
end

function ns.relocateChatMenuButton()
  local btn = _G.ChatFrameMenuButton
  if not btn then return end
  snapshotBalloon(btn)

  -- Só mexe se o painel e a sidebar estiverem ABERTOS
  if ns.frames and ns.frames.panel and ns.frames.panel:IsShown()
     and ns.frames.leftBar and ns.frames.leftBar:IsShown()
     and ns.frames.leftBarBottomSlot then
    if placeOnLeftBar(btn) then RaiseAndWireMenus() end
  else
    -- Painel fechado → devolve pro lugar original do chat default
    restoreBalloon(btn)
  end
end

-- Reforços de timing (funcionam nos dois estados; se painel estiver fechado, restaura)
local function reapply()
  if _G.ChatFrameMenuButton then ns.relocateChatMenuButton() end
end
if C_Timer and C_Timer.After then
  C_Timer.After(0.05, reapply)
  C_Timer.After(0.25, reapply)
  C_Timer.After(0.75, reapply)
  C_Timer.After(1.50, reapply)
end

-- Pós-ganchos nas rotas de abertura dos menus (deixa o padrão rodar)
if not ns.__hkd_menuHooks then
  ns.__hkd_menuHooks = true
  if type(ChatFrame_ToggleMenu) == "function" then
    hooksecurefunc("ChatFrame_ToggleMenu", function() MarkInside(); RaiseAndWireMenus() end)
  end
  if type(ToggleDropDownMenu) == "function" then
    hooksecurefunc("ToggleDropDownMenu", function() MarkInside(); RaiseAndWireMenus() end)
  end
  if type(ChatFrame_ChangeChatLanguage) == "function" then
    hooksecurefunc("ChatFrame_ChangeChatLanguage", function() MarkInside(); RefocusEditBoxAfter(0.10) end)
  end
end

 end
-- END 45_menu_button.lua

-- BEGIN 50_voice_cleanup.lua
 do
local _, ns = ...

local VOICE_STRINGS = {
  "UNDEAFEN","UNMUTE","DEAFEN","MUTE",
  "Undeafen Voice Chat","Unmute","Deafen","Mute",
  "Cancelar surdez","Ativar som","Silenciar","Ativar microfone"
}

local function isVoiceBtn(frame)
  if not frame or not frame:IsObjectType("Button") then return false end
  local tt = frame.tooltipText or frame.tooltip
  if type(tt) == "string" then
    local up = tt:upper()
    for _, key in ipairs(VOICE_STRINGS) do
      if up:find(key) then return true end
    end
  end
  local n = frame.GetName and frame:GetName() or ""
  if n and n ~= "" then
    local up = n:upper()
    if up:find("VOICE") or up:find("DEAFEN") or up:find("MUTE") then return true end
  end
  return false
end

local function kill(f)
  if not f or f.__hkd_killed then return end
  f.__hkd_killed = true
  if f.Hide then f:Hide() end
  if f.SetAlpha then f:SetAlpha(0) end
  if f.SetScale then f:SetScale(0.0001) end
  if f.EnableMouse then f:EnableMouse(false) end
  if f.SetScript then f:SetScript("OnShow", function(self) self:Hide() end) end
  if f.UnregisterAllEvents then f:UnregisterAllEvents() end
end

function ns.hideVoiceButtons()
  local known = {
    "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton",
    "ChatFrameDeafenButton",
    "ChatFrameMuteButton",
    "VoiceDeafenButton",
    "VoiceMuteButton",
    "QuickJoinDeafenButton",
    "QuickJoinMuteButton",
  }
  for _, name in ipairs(known) do local f=_G[name]; if f then kill(f) end end

  local f = EnumerateFrames()
  while f do
    if isVoiceBtn(f) then kill(f) end
    f = EnumerateFrames(f)
  end

  for i=1, (NUM_CHAT_WINDOWS or 10) do
    local bf = _G["ChatFrame"..i.."ButtonFrame"]
    if bf and bf.GetChildren then
      for _, child in ipairs({bf:GetChildren()}) do
        if isVoiceBtn(child) then kill(child) end
      end
    end
  end
end

 end
-- END 50_voice_cleanup.lua

-- BEGIN 52_glass_style.lua
 do
-- 52_glass_style.lua  (HKDChat)
-- Gap entre parágrafos usando textura transparente + highlight + scroll vanilla + BG opcional

local _, ns = ...
ns.frames = ns.frames or {}
ns.state  = ns.state  or {}
local CFG = ns.CFG or {}

local GLASS = {
  timeVisible     = 50,
  fadeDuration    = 3.0,

  -- BG de cada parágrafo (tarja):
  paraPadX        = 4,
  paraPadY        = 2,
  paraAlphaLeft   = 0.12,
  paraAlphaRight  = 0.00,
  repaintThrottle = 0.05,

  -- a tarja entra N px antes do texto (cria o “respiro” visual)
  gapBeforeText   = 2,

  -- Busca do SMF interno:
  diveMaxDepth    = 3,

  -- Gap só ENTRE mensagens (sem afetar wrap):
  useParagraphGap = true,

  -- Altura do gap (px) – ajustável:
  paragraphGapPx  = 3,

  -- TGA transparente (8x8 RGBA) que você colocou:
  spacerTexture   = "Interface\\AddOns\\HKDChat\\assets\\transparent.tga",

  -- BG global por trás do chat:
  globalBG        = false,  -- false => totalmente transparente
}

-- ======================
-- Helpers
-- ======================
local function isSMF(f)
  return f and f.AddMessage and f.SetSpacing and f.GetScrollOffset
end

local function resolveSMF(root)
  if not root then return nil end
  if isSMF(root) then return root end
  if root.ScrollTarget   and isSMF(root.ScrollTarget)   then return root.ScrollTarget   end
  if root.ScrollFrame    and isSMF(root.ScrollFrame)    then return root.ScrollFrame    end
  if root.messageFrame   and isSMF(root.messageFrame)   then return root.messageFrame   end

  local function dive(p, d)
    if d > GLASS.diveMaxDepth or not p or not p.GetChildren then return nil end
    local kids = { p:GetChildren() }
    for _, c in ipairs(kids) do
      if isSMF(c) then return c end
      local found = dive(c, d + 1)
      if found then return found end
    end
    return nil
  end
  return dive(root, 1)
end

-- Mata QUALQUER BG default
local function killDefaultBG(root, cf)
  local name = root and root.GetName and root:GetName()
  if name then
    local namedBG = _G[name.."Background"]
    if namedBG and namedBG.Hide then namedBG:Hide() end
    local nine = _G[name.."NineSlice"]
    if nine and nine.Hide then nine:Hide() end
  end

  if root and root.GetRegions then
    local regs = { root:GetRegions() }
    for _, reg in ipairs(regs) do
      if reg and reg.Hide     then pcall(reg.Hide, reg) end
      if reg and reg.SetAlpha then pcall(reg.SetAlpha, reg, 0) end
    end
  end

  if cf and cf.__hkd_bg then
    cf.__hkd_bg:Hide(); cf.__hkd_bg = nil
  end

  if root and root.SetBackdrop then root:SetBackdrop(nil) end
  if cf   and cf.SetBackdrop   then cf:SetBackdrop(nil)   end
end

-- ======================
-- Pool de BGs por parágrafo (no ROOT)
-- ======================
local function acquireBG(root)
  root.__hkd_bgPool = root.__hkd_bgPool or {}
  root.__hkd_bgPoolFree = root.__hkd_bgPoolFree or {}
  local bg = table.remove(root.__hkd_bgPoolFree)
  if not bg then
    bg = root:CreateTexture(nil, "BACKGROUND", nil, -6)
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  end
  table.insert(root.__hkd_bgPool, bg)
  return bg
end

local function releaseAllBG(root)
  if not root.__hkd_bgPool then return end
  for i = #root.__hkd_bgPool, 1, -1 do
    local bg = root.__hkd_bgPool[i]
    bg:Hide(); bg:ClearAllPoints()
    table.insert(root.__hkd_bgPoolFree, bg)
    table.remove(root.__hkd_bgPool, i)
  end
end

-- ======================
-- FontStrings visíveis (mensagens atuais)
-- ======================
local function isSpacerText(s)
  -- trata como "spacer" se:
  -- 1) vazio/só whitespace
  -- 2) UMA textura inline isolada (|T...|t) — nosso espaçador
  if s == nil then return true end
  if type(s) == "string" then
    if s:match("^%s*$") then return true end
    if s:match("^%s*|T.-|t%s*$") and not s:match(".-|t.+") then
      return true
    end
  end
  return false
end

local function iterFontStrings(cf)
  local list = {}

  do
    local regs = { cf:GetRegions() }
    for _, r in ipairs(regs) do
      if r and r.GetObjectType and r:GetObjectType()=="FontString" and r:IsShown() then
        table.insert(list, r)
      end
    end
  end

  if cf.FontStringContainer and cf.FontStringContainer.GetRegions then
    local regs = { cf.FontStringContainer:GetRegions() }
    for _, r in ipairs(regs) do
      if r and r.GetObjectType and r:GetObjectType()=="FontString" and r:IsShown() then
        table.insert(list, r)
      end
    end
  end

  return list
end

-- ======================
-- Pintura do highlight (gradiente HORIZONTAL)
-- ======================
local function paintParagraphBGs(root, cf)
  if not cf:IsShown() then return end
  releaseAllBG(root)

  for _, r in ipairs(iterFontStrings(cf)) do
    local txt = r:GetText()
    local sh  = (r.GetStringHeight and r:GetStringHeight()) or 0

    if not isSpacerText(txt) and sh >= 2 then
      local bg = acquireBG(root)
      bg:ClearAllPoints()
      bg:SetPoint("TOP",    r, "TOP",    0,  GLASS.paraPadY)
      bg:SetPoint("BOTTOM", r, "BOTTOM", 0, -GLASS.paraPadY)
      bg:SetPoint("LEFT",   r, "LEFT", -(GLASS.gapBeforeText or 2), 0)
      bg:SetPoint("RIGHT",  r, "RIGHT", GLASS.paraPadX, 0)

      if bg.SetGradientAlpha then
        bg:SetGradientAlpha("HORIZONTAL", 0,0,0,GLASS.paraAlphaLeft, 0,0,0,GLASS.paraAlphaRight)
      elseif bg.SetGradient then
        bg:SetGradient("HORIZONTAL",
          CreateColor(0,0,0,GLASS.paraAlphaLeft),
          CreateColor(0,0,0,GLASS.paraAlphaRight)
        )
      else
        bg:SetColorTexture(0,0,0,(GLASS.paraAlphaLeft + GLASS.paraAlphaRight) * 0.5)
      end

      bg:Show()
    end
  end
end

local function ensureParaRepaint(root, cf)
  if cf.__hkd_paraHooked then return end
  cf.__hkd_paraHooked = true

  cf:HookScript("OnShow",            function() cf.__hkd_nextRepaint = 0 end)
  cf:HookScript("OnSizeChanged",     function() cf.__hkd_nextRepaint = 0 end)
  cf:HookScript("OnHyperlinkEnter",  function() cf.__hkd_nextRepaint = 0 end)
  cf:HookScript("OnHyperlinkLeave",  function() cf.__hkd_nextRepaint = 0 end)

  cf:HookScript("OnUpdate", function(_, dt)
    local t = (cf.__hkd_nextRepaint or 0) - dt
    if t <= 0 then
      paintParagraphBGs(root, cf)
      cf.__hkd_nextRepaint = GLASS.repaintThrottle
    else
      cf.__hkd_nextRepaint = t
    end
  end)

  if not cf.__hkd_addMsgHooked then
    cf.__hkd_addMsgHooked = true
    hooksecurefunc(cf, "AddMessage", function()
      cf.__hkd_nextRepaint = 0
    end)
  end
end

-- ======================
-- Spacer invisível via textura (corrigido: UVs 0..1)
-- CreateTextureMarkup(file, fileW, fileH, width, height, left, right, top, bottom[, xOff, yOff])
-- ======================
local function MakeInvisibleSpacer(height)
  local h = math.max(1, math.floor(tonumber(height) or (GLASS.paragraphGapPx or 2)))
  local w = 1 -- 1px de largura é suficiente pra ocupar layout vertical
  if CreateTextureMarkup then
    -- UVs normalizados 0..1 para usar a textura inteira (transparente):
    return CreateTextureMarkup(GLASS.spacerTexture, 8, 8, w, h, 0, 1, 0, 1)
  else
    -- Fallback manual: |T path:height:width:offX:offY:dimx:dimy:cx1:cx2:cy1:cy2 |t
    return ("|T%s:%d:%d:0:0:8:8:0:8:0:8|t"):format(GLASS.spacerTexture, h, w)
  end
end

-- ======================
-- Gap entre parágrafos
-- ======================
local function installParagraphGap(cf)
  if not GLASS.useParagraphGap or cf.__hkd_gapWrapped then return end
  cf.__hkd_gapWrapped = true

  local orig = cf.AddMessage
  cf.AddMessage = function(self, text, r,g,b, id, holdTime, ...)
    local ret = orig(self, text, r,g,b, id, holdTime, ...)
    -- Injeta uma “linha” invisível com altura GLASS.paragraphGapPx
    orig(self, MakeInvisibleSpacer(GLASS.paragraphGapPx), r,g,b, id, holdTime, ...)
    return ret
  end
end

-- ======================
-- Aplicação principal
-- ======================
local function applyGlassToRoot(root)
  local cf = resolveSMF(root)
  if not cf or cf.__hkd_glass_applied then
    if cf and not GLASS.globalBG then killDefaultBG(root, cf) end
    return
  end
  cf.__hkd_glass_applied = true

  if cf.SetSpacing then pcall(cf.SetSpacing, cf, 0) end
  if cf.SetFading       then cf:SetFading(true) end
  if cf.SetTimeVisible  then cf:SetTimeVisible(GLASS.timeVisible) end
  if cf.SetFadeDuration then cf:SetFadeDuration(GLASS.fadeDuration) end

  if GLASS.globalBG then
    if not cf.__hkd_bg then
      local bg = root:CreateTexture(nil, "BACKGROUND", nil, -7)
      bg:SetAllPoints(true)
      bg:SetTexture("Interface\\Buttons\\WHITE8X8")
      if bg.SetGradientAlpha then
        bg:SetGradientAlpha("VERTICAL", 0,0,0,0.08, 0,0,0,0.02)
      elseif bg.SetGradient then
        bg:SetGradient("VERTICAL", CreateColor(0,0,0,0.08), CreateColor(0,0,0,0.02))
      else
        bg:SetColorTexture(0,0,0,0.05)
      end
      cf.__hkd_bg = bg
    end
  else
    killDefaultBG(root, cf)
  end

  if cf.SetBackdrop then cf:SetBackdrop(nil) end
  if cf.SetClipsChildren then cf:SetClipsChildren(true) end
  if cf.SetJustifyH then cf:SetJustifyH("LEFT") end
  if cf.SetIndentedWordWrap then cf:SetIndentedWordWrap(true) end

  installParagraphGap(cf)
  ensureParaRepaint(root, cf)

  C_Timer.After(0.05, function()
    if cf and cf.SetSpacing then pcall(cf.SetSpacing, cf, 0) end
    if not GLASS.globalBG and cf and root then killDefaultBG(root, cf) end
    if cf then cf.__hkd_nextRepaint = 0 end
  end)
end

local function applyAll()
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local root = _G["ChatFrame"..i]
    if root then applyGlassToRoot(root) end
  end
end

local _evt = CreateFrame("Frame")
_evt:RegisterEvent("PLAYER_LOGIN")
_evt:RegisterEvent("UPDATE_CHAT_WINDOWS")
_evt:RegisterEvent("PLAYER_ENTERING_WORLD")
_evt:SetScript("OnEvent", function()
  applyAll()
end)

function ns.glass_ApplyNow()
  applyAll()
  C_Timer.After(0.05, applyAll)
end

 end
-- END 52_glass_style.lua

-- BEGIN 55_buttonframe_hide.lua
 do
local _, ns = ...

function ns.hideDefaultButtonFrames()
  for i=1, (NUM_CHAT_WINDOWS or 10) do
    local bf = _G["ChatFrame"..i.."ButtonFrame"]
    if bf then
      if bf.UnregisterAllEvents then bf:UnregisterAllEvents() end
      if bf.SetScript then bf:SetScript("OnShow", function(self) self:Hide() end) end
      bf:Hide()
      if bf.EnableMouse then bf:EnableMouse(false) end
    end
  end
end

 end
-- END 55_buttonframe_hide.lua
