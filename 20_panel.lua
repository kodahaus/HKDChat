-- GROUP 20_panel: 1 file(s) merged

-- BEGIN 30_panel.lua
 do
-- 30_panel.lua
local _, ns = ...
local CFG = ns.CFG

-- ===== painel raiz =====
local panel = CreateFrame("Frame", "HKDChatPanel", UIParent, "BackdropTemplate")
panel:SetFrameStrata("HIGH")
panel:SetClampedToScreen(true)
panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -CFG.PANEL_W, 0)
panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
panel:SetWidth(CFG.PANEL_W)
panel:EnableMouse(false)                 -- fechado = click-through
panel:SetPropagateMouseClicks(false)
panel:Hide()
panel:SetAlpha(0)
panel:SetScript("OnMouseDown", function()
  if ns.EDIT and panel:IsShown() then
    ns.state.panelClickAt = GetTime()
    ns.EDIT:Show(); ns.EDIT:SetFocus()
  end
end)

-- === HKDChat: helpers de visibilidade “forte” (use apenas 1x no arquivo) ===
local function _reallyVisible(f)
  if not f or (f.IsForbidden and f:IsForbidden()) then return false end
  if f.IsVisible and not f:IsVisible() then return false end   -- respeita hierarquia de pais
  if f.IsShown   and not f:IsShown()   then return false end
  if f.GetEffectiveAlpha and f:GetEffectiveAlpha() <= 0.05 then return false end
  return true
end

-- === HKDChat: detecção única de “mouse dentro do dock” (use sua versão aqui; esta é segura) ===
function ns.IsPointerOverDock()
  
  
  -- Build a set of root frames we consider part of the "dock"
  local roots = {}
  local function addRoot(f)
    if f and (not f.IsForbidden or not f:IsForbidden()) then
      if _reallyVisible and _reallyVisible(f) then
        roots[#roots+1] = f
      end
    end
  end

  if ns.frames then
    addRoot(ns.frames.panel)
    addRoot(ns.frames.container)
    addRoot(ns.frames.chatArea)
    addRoot(ns.frames.tabsBar)
    addRoot(ns.frames.leftBar)
    addRoot(ns.frames.lootSpecMenu)
  end

  -- Blizzard windows (only when truly visible)
  addRoot(_G and _G.FriendsFrame)
  addRoot(_G and _G.CharacterFrame)
  addRoot(_G and _G.ChallengesFrame)
  addRoot(_G and (_G.ChallengesKeystoneFrame or _G.MythicPlusKeystoneFrame))
  addRoot(_G and _G.PVEFrame)

  -- Helper: check if 'node' is the same as or a descendant of any root
  local function isWithinRoots(node)
    if not node or (node.IsForbidden and node:IsForbidden()) then return false end
    local cur = node
    while cur do
      for i = 1, #roots do
        if cur == roots[i] then return true end
      end
      if cur == UIParent then break end
      cur = (cur.GetParent and cur:GetParent()) or nil
    end
    return false
  end

  -- Prefer modern API: GetMouseFoci() returns all frames under cursor (top-first).
  local foci = GetMouseFoci and GetMouseFoci()
  if foci and type(foci) == "table" then
    for i = 1, #foci do
      local n = foci[i]
      if isWithinRoots(n) then return true end
    end
  else
    -- Fallback: legacy single-focus
    local focus = GetMouseFocus and GetMouseFocus()
    if focus and isWithinRoots(focus) then return true end
  end

  -- Last resort: geometric test on roots (covers rare cases)
  for i = 1, #roots do
    local f = roots[i]
    if f and f.IsMouseOver and f:IsMouseOver() then return true end
  end

  return false

end

-- === HKDChat: overlay (click-catcher) acima do mundo ===
local overlay = CreateFrame("Button", "HKDChatClickCatcher", UIParent)  -- cria botão full-screen
overlay:SetAllPoints(UIParent)                                         -- cobre a tela toda
overlay:EnableMouse(false)                                             -- só liga quando painel abrir
if overlay.SetPropagateMouseClicks then                                 -- deixa clique passar p/ baixo
  overlay:SetPropagateMouseClicks(true)
end
overlay:SetFrameStrata("HIGH")     -- acima do mundo, abaixo de dialogs críticos
overlay:SetToplevel(true)

-- garantir que o overlay não bloqueie hover no login
if overlay.SetPropagateMouseMotion then overlay:SetPropagateMouseMotion(true) end
overlay:Hide()  -- fica oculto até abrirmos o painel


overlay:SetScript("OnMouseDown", function()
  if ns.IsPointerOverDock and ns.IsPointerOverDock() then return end
  if ns.hidePanel then ns.hidePanel(true) end
end)

ns.frames.clickCatcher = overlay

-- fail-safe: sempre iniciar desarmado no login/teleport
do
  local _ovSafe = CreateFrame("Frame")
  _ovSafe:RegisterEvent("PLAYER_LOGIN")
  _ovSafe:RegisterEvent("PLAYER_ENTERING_WORLD")
  _ovSafe:SetScript("OnEvent", function()
    if overlay then
      overlay:EnableMouse(false)
      overlay:Hide()
    end
  end)
end


local bg = panel:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(true)
bg:SetColorTexture(0,0,0,CFG.BG_ALPHA)

local container = CreateFrame("Frame", nil, panel)
container:SetPoint("TOPLEFT",     panel, "TOPLEFT",  CFG.EDGE_PADDING, -CFG.EDGE_PADDING)
container:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -CFG.EDGE_PADDING, CFG.EDGE_PADDING)
container:SetClipsChildren(false)
container:EnableMouse(false)
container:SetPropagateMouseClicks(false)
container:SetScript("OnMouseDown", function()
  if ns.EDIT and panel:IsShown() then
    ns.state.panelClickAt = GetTime()
    ns.EDIT:Show(); ns.EDIT:SetFocus()
  end
end)

local chatArea = CreateFrame("Frame", nil, container)
chatArea:SetClipsChildren(false)
chatArea:EnableMouse(false)
chatArea:SetPropagateMouseClicks(false)
chatArea:SetScript("OnMouseDown", function()
  if ns.EDIT and panel:IsShown() then
    ns.state.panelClickAt = GetTime()
    ns.EDIT:Show(); ns.EDIT:SetFocus()
  end
end)

-- barra de abas (direita)
local tabsBar = CreateFrame("Frame", "HKDChatTabs", container)
tabsBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, -6)
tabsBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4, 6)
tabsBar:SetWidth(26)
tabsBar:EnableMouse(false)
tabsBar:SetPropagateMouseClicks(false)
tabsBar.buttons = {}
tabsBar:SetFrameStrata("FULLSCREEN_DIALOG")
tabsBar:SetFrameLevel(panel:GetFrameLevel() + 5000)
tabsBar:SetToplevel(true)

ns.frames.panel     = panel
ns.frames.container = container
ns.frames.chatArea  = chatArea
ns.frames.tabsBar   = tabsBar

-- [HKDChat] Removed duplicate Guard/IsPointerOverDock block

-- pulso contínuo: mantém o guard true enquanto o mouse estiver sobre dock/char/social/m+
local _guardPulse = CreateFrame("Frame")
_guardPulse:SetScript("OnUpdate", function()
  if panel:IsShown() and ns.IsPointerOverDock and ns.IsPointerOverDock() then
    ns.state.guard = true
  else
    if not (ns.anim and ns.anim.fadeOutAG and ns.anim.fadeOutAG:IsPlaying()) then
      ns.state.guard = false
    end
  end
end)

-- hover flags (aproveitados por outros hooks)
local function watchHover(f)
  if not f or not f.HookScript then return end
  f:HookScript("OnEnter", function() ns.state.mouseInside = true end)
  f:HookScript("OnLeave", function() ns.state.mouseInside = false end)
end
watchHover(panel); watchHover(container); watchHover(chatArea); watchHover(tabsBar)

-- ===== animações =====
local fadeInAG    = panel:CreateAnimationGroup()
local fadeInAlpha = fadeInAG:CreateAnimation("Alpha")
fadeInAlpha:SetFromAlpha(0); fadeInAlpha:SetToAlpha(1)
fadeInAlpha:SetDuration(CFG.FADE_MS); fadeInAlpha:SetSmoothing("OUT")
fadeInAG:SetScript("OnFinished", function() panel:SetAlpha(1) end)

local fadeOutAG    = panel:CreateAnimationGroup()
local fadeOutAlpha = fadeOutAG:CreateAnimation("Alpha")
fadeOutAlpha:SetFromAlpha(1); fadeOutAlpha:SetToAlpha(0)
fadeOutAlpha:SetDuration(CFG.FADE_MS); fadeOutAlpha:SetSmoothing("IN")
fadeOutAG:SetScript("OnFinished", function()
  panel:Hide()
  panel:SetAlpha(0)
end)

ns.anim = { fadeInAG=fadeInAG, fadeOutAG=fadeOutAG }

function ns.raiseTabsBar()
  if not ns.frames.tabsBar then return end
  local bar = ns.frames.tabsBar
  bar:SetFrameStrata("FULLSCREEN_DIALOG")
  bar:SetFrameLevel(panel:GetFrameLevel() + 5000)
  bar:SetToplevel(true)
  for _, b in ipairs(bar.buttons or {}) do
    if b.SetFrameStrata then b:SetFrameStrata(bar:GetFrameStrata()) end
    if b.SetFrameLevel  then b:SetFrameLevel(bar:GetFrameLevel() + 1) end
    if b.SetToplevel    then b:SetToplevel(true) end
  end
end

local function setMouseOpen(open)
  local flag = not not open
  if panel.EnableMouse then panel:EnableMouse(flag) end
  if container.EnableMouse then container:EnableMouse(flag) end
  if chatArea.EnableMouse then chatArea:EnableMouse(flag) end
  if tabsBar.EnableMouse then tabsBar:EnableMouse(flag) end
end

function ns.showPanel()
  if GetTime and GetTime() < (ns.state.loginBlockUntil or 0) then return end
  if panel:IsShown() then return end

  panel:SetFrameStrata("HIGH")
  tabsBar:SetFrameStrata("FULLSCREEN_DIALOG")

  panel:SetAlpha(0); panel:Show()
  ns.anim.fadeOutAG:Stop(); ns.anim.fadeInAG:Stop()
  setMouseOpen(true)

  ns.adoptSpecificChatFrame(ns.getActiveChatFrame())
  if ns.sidebarAttach then ns.sidebarAttach() end
  if ns.glass_ApplyNow then ns.glass_ApplyNow() end

  ns.anim.fadeInAG:Play()
  C_Timer.After(0, ns.raiseTabsBar)

  -- mantém o EditBox visível se interagir no dock/char/social/m+
  if ns.EDIT and ns.EDIT.HookScript and not ns._editGuarded then
    ns._editGuarded = true
    ns.EDIT:HookScript("OnEditFocusLost", function(self)
      if panel:IsShown() and ns.IsPointerOverDock and ns.IsPointerOverDock() then
        C_Timer.After(0, function()
          if panel:IsShown() and self and self.Show and self.SetFocus then
            self:Show(); self:SetFocus()
          end
        end)
      end
    end)
  end
  if ns.frames and ns.frames.clickCatcher then ns.frames.clickCatcher:EnableMouse(true); ns.frames.clickCatcher:Show() end

end

function ns.hidePanel(force)
  -- não fecha se o ponteiro estiver sobre o dock/char/social/m+ (a menos que force)
  if not force and ns.IsPointerOverDock and ns.IsPointerOverDock() then
    return
  end
  if not panel:IsShown() or not ns.state.adopted or ns.state.guard then
    return
  end

  if ns.sidebarDetach then ns.sidebarDetach() end
  ns.releaseCurrentChat()

  setMouseOpen(false)
  ns.anim.fadeInAG:Stop(); ns.anim.fadeOutAG:Stop()
  ns.anim.fadeOutAG:Play()
  if ns.frames and ns.frames.clickCatcher then ns.frames.clickCatcher:EnableMouse(false); ns.frames.clickCatcher:Hide() end

end

-- failsafes: nada deve capturar mouse após fechar
if ns.frames.tabsBar then
  ns.frames.tabsBar:EnableMouse(false)
  ns.frames.tabsBar:SetPropagateMouseClicks(false)
end
if ns.frames.leftBar then
  ns.frames.leftBar:Hide()           -- já faz no sidebarDetach, mas reforça
  ns.frames.leftBar:EnableMouse(false)
end

-- ===== [HKD] Gap padrão entre texto e EditBox (trade-like) =====
local HKD_GAP = 8
local function HKD_applyChatGap(cf)
  if not cf or not cf.GetName then return end
  if cf.SetClampRectInsets then
    cf:SetClampRectInsets(0, 0, HKD_GAP*3, -HKD_GAP*2)
  end
  local eb = _G[cf:GetName().."EditBox"]
  if eb and eb.ClearAllPoints then
    eb:ClearAllPoints()
    eb:SetPoint("BOTTOMLEFT",  cf, "TOPLEFT",  0, HKD_GAP)
    eb:SetPoint("BOTTOMRIGHT", cf, "TOPRIGHT", 0, HKD_GAP)
  end
end

function HKDChat_ApplyAllChatGaps()
  for i = 1, NUM_CHAT_WINDOWS do
    HKD_applyChatGap(_G["ChatFrame"..i])
  end
end

local _hkdGapEvt = CreateFrame("Frame")
_hkdGapEvt:RegisterEvent("PLAYER_LOGIN")
_hkdGapEvt:RegisterEvent("UPDATE_CHAT_WINDOWS")
_hkdGapEvt:SetScript("OnEvent", function()
  if HKDChat_ApplyAllChatGaps then HKDChat_ApplyAllChatGaps() end
end)

 end
-- END 30_panel.lua
