local _, ns = ...
local CFG = ns.CFG

-- painel raiz
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
  if ns.EDIT and panel:IsShown() then ns.EDIT:Show(); ns.EDIT:SetFocus() end
end)

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
  if ns.EDIT and panel:IsShown() then ns.EDIT:Show(); ns.EDIT:SetFocus() end
end)

local chatArea = CreateFrame("Frame", nil, container)
chatArea:SetClipsChildren(false)
chatArea:EnableMouse(false)
chatArea:SetPropagateMouseClicks(false)
chatArea:SetScript("OnMouseDown", function()
  if ns.EDIT and panel:IsShown() then ns.EDIT:Show(); ns.EDIT:SetFocus() end
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

local function watchHover(f)
  if not f or not f.HookScript then return end
  f:HookScript("OnEnter", function() ns.state.mouseInside = true end)
  f:HookScript("OnLeave", function() ns.state.mouseInside = false end)
end
watchHover(panel); watchHover(container); watchHover(chatArea); watchHover(tabsBar)

-- animações
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

  ns.anim.fadeInAG:Play()
  C_Timer.After(0, ns.raiseTabsBar)
end

function ns.hidePanel()
  if not panel:IsShown() or not ns.state.adopted or ns.state.guard then return end

  if ns.sidebarDetach then ns.sidebarDetach() end
  ns.releaseCurrentChat()

  -- desliga o mouse JÁ (pra não bloquear o chat default durante o fade)
  setMouseOpen(false)

  -- roda o fade-out e só esconde no OnFinished
  ns.anim.fadeInAG:Stop(); ns.anim.fadeOutAG:Stop()
  ns.anim.fadeOutAG:Play()
end
