-- GROUP 30_tabs: 2 file(s) merged

-- BEGIN 40_tabs.lua
 do
-- 40_tabs.lua
local _, ns = ...

-- ===== Utils =====
local function getRealChatFrameIndices()
  local list = {}
  if _G.FCFDock_GetChatFrames and _G.GENERAL_CHAT_DOCK then
    local docked = { FCFDock_GetChatFrames(GENERAL_CHAT_DOCK) }
    for _, cf in ipairs(docked) do if cf and cf.GetID then table.insert(list, cf:GetID()) end end
  end
  if #list == 0 and _G.NUM_CHAT_WINDOWS and _G.GetChatWindowInfo then
    for i = 1, NUM_CHAT_WINDOWS do
      local _,_,_,_,_,_, shown, _, docked = GetChatWindowInfo(i)
      if shown or docked then table.insert(list, i) end
    end
  end
  if #list == 0 then table.insert(list, 1) end
  return list
end

local function getTabLabel(i)
  local tab = _G["ChatFrame"..i.."Tab"]
  if tab and tab.GetText then
    local t = tab:GetText()
    if t and t ~= "" then return t end
  end
  local name = GetChatWindowInfo and GetChatWindowInfo(i)
  if name and name ~= "" then return name end
  return tostring(i)
end

local function clearTabsBar()
  local bar = ns.frames and ns.frames.tabsBar
  if not bar or not bar.buttons then return end
  for _,b in ipairs(bar.buttons) do b:Hide(); b:SetParent(nil) end
  wipe(bar.buttons)
end

-- ===== Sincroniza o dock vanilla (sem adotar aqui) =====
local function selectDock(i)
  local cf = _G["ChatFrame"..i]; if not cf then return end
  if _G.GENERAL_CHAT_DOCK then
    if _G.FCFDock_SetSelectedWindow then
      FCFDock_SetSelectedWindow(GENERAL_CHAT_DOCK, cf); return
    elseif _G.FCFDock_SelectWindow then
      FCFDock_SelectWindow(GENERAL_CHAT_DOCK, cf); return
    end
  end
  local tab = _G[cf:GetName().."Tab"]
  if tab and _G.FCF_Tab_OnClick then FCF_Tab_OnClick(tab) end
end

-- ===== Adota no painel (responsivo, no mouse down) =====
local function adoptInPanel(i)
  local cf = _G["ChatFrame"..i]; if not cf then return end
  ns.state.closeOnNextDeactivate = false
  ns.state.panelClickAt = GetTime() or 0
  ns.state.switchingTabs = true
  ns.state.guard = true

  if ns.frames.panel and ns.frames.panel:IsShown() then
    if ns.state.currentChat ~= cf then
      ns.releaseCurrentChat()
      ns.adoptSpecificChatFrame(cf)
    end
    if ns.EDIT then ns.EDIT:Show(); ns.EDIT:SetFocus() end
  end

  ns.state.guard = false
  ns.state.switchingTabs = false
  if ns.raiseTabsBar then ns.raiseTabsBar() end
end

-- ===== Botão de aba =====
local function makeTabButton(i, label)
  local bar = ns.frames.tabsBar
  local b = CreateFrame("Button", "HKDChatTabBtn"..i, bar)
  b:SetSize(22, 44)
  b:RegisterForClicks("LeftButtonUp") -- OnClick no mouse-up
  b:EnableMouse(true)
  b:SetPropagateMouseClicks(false)
  b:SetFrameStrata(bar:GetFrameStrata())
  b:SetFrameLevel(bar:GetFrameLevel() + 1)
  if b.SetToplevel then b:SetToplevel(true) end

  if #bar.buttons == 0 then
    b:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
  else
    b:SetPoint("TOPRIGHT", bar.buttons[#bar.buttons], "BOTTOMRIGHT", 0, -6)
  end

  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("CENTER"); fs:SetText(label or tostring(i)); fs:SetRotation(math.rad(90))
  b.fs = fs

  local t = b:CreateTexture(nil, "ARTWORK")
  t:SetAllPoints(true); t:SetColorTexture(1,1,1,0.06)
  b.bg = t

  b:SetScript("OnEnter", function() b.bg:SetAlpha(0.15); ns.state.mouseInside = true end)
  b:SetScript("OnLeave", function() b.bg:SetAlpha(0.06);  ns.state.mouseInside = false end)

  -- PRESS: troca no painel
  b:SetScript("OnMouseDown", function()
    ns.state.panelClickAt = GetTime() or 0
    if ns.frames.panel and ns.frames.panel:IsShown() and ns.EDIT then ns.EDIT:Show(); ns.EDIT:SetFocus() end
    adoptInPanel(i)
  end)

  -- RELEASE: sincroniza dock vanilla (sem reentrar)
  b:SetScript("OnClick", function()
    ns.state.guard = true
    selectDock(i)
    ns.state.guard = false
    if ns.raiseTabsBar then ns.raiseTabsBar() end
  end)

  table.insert(bar.buttons, b)
  return b
end

function ns.rebuildTabsBar()
  if not ns.frames or not ns.frames.tabsBar then return end
  local bar = ns.frames.tabsBar
  clearTabsBar()
  bar.buttons = bar.buttons or {}

  for _, i in ipairs(getRealChatFrameIndices()) do
    local lbl = getTabLabel(i)
    if not ns.isVoiceLabel or not ns.isVoiceLabel(lbl) then
      makeTabButton(i, lbl)
    end
  end

  if ns.raiseTabsBar then ns.raiseTabsBar() end
  ns.relocateChatMenuButton()
end

-- init tardio
local function safeInitTabs()
  if ns.frames and ns.frames.tabsBar and ns.frames.panel then
    if ns.raiseTabsBar then ns.raiseTabsBar() end
    ns.rebuildTabsBar()
    return true
  end
end

local initEv = CreateFrame("Frame")
initEv:RegisterEvent("PLAYER_ENTERING_WORLD")
initEv:SetScript("OnEvent", function()
  C_Timer.After(0, function()
    if not safeInitTabs() then C_Timer.After(0, safeInitTabs) end
  end)
end)

hooksecurefunc(ns, "showPanel", function()
  C_Timer.After(0, safeInitTabs)
end)

 end
-- END 40_tabs.lua

-- BEGIN 53_chat_tabs.lua
 do
-- 53_chat_tabs.lua (v4.5 – abas vanilla com a mesma “moldurinha” dos badges)
local _, ns = ...

-------------------------------------------------
-- CONFIG (igual ao MakeBox da topbar)
-------------------------------------------------
local BOX_BG     = "Interface\\Tooltips\\UI-Tooltip-Background"
local BOX_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
local BG_COLOR   = {0, 0, 0, 0.70}
local BRD_COLOR  = {1, 1, 1, 0.12}

-- insets da moldura dentro da aba (afina a caixa)
local INSET_L, INSET_R, INSET_T, INSET_B = 4, 4, 3, 6

-- estados
local ALPHA_SELECTED   = 1.00
local ALPHA_HOVER      = 0.95
local ALPHA_DESELECTED = 0.55

-- evita truncar: largura mínima = texto + padding
local TAB_TEXT_PAD = 22

-------------------------------------------------
-- HELPERS
-------------------------------------------------
local function isActiveTab(tab)
  if not tab then return false end
  if tab.owner and _G.SELECTED_CHAT_FRAME then
    return tab.owner == _G.SELECTED_CHAT_FRAME
  end
  return _G.SELECTED_CHAT_FRAME and _G.SELECTED_CHAT_FRAME.tab == tab
end

-- emudece TUDO que a Blizzard desenha no tab, mas sem esconder (preserva largura)
local function muteVanillaPieces(tab)
  local name = tab.GetName and tab:GetName()
  if name then
    local ids = {
      "Left","Middle","Right",
      "SelectedLeft","SelectedMiddle","SelectedRight",
      "HighlightLeft","HighlightMiddle","HighlightRight",
      "LeftHighlight","MiddleHighlight","RightHighlight",
      "Glow","ActiveLeft","ActiveMiddle","ActiveRight",
      "Flash","ConversationIcon"
    }
    for _, id in ipairs(ids) do
      local r = _G[name..id]
      if r then
        if r.SetAlpha        then r:SetAlpha(0) end
        if r.SetColorTexture then r:SetColorTexture(1,1,1,0) end
        if r.SetTexture      then r:SetTexture(nil) end
        if r.SetAtlas        then pcall(r.SetAtlas, r, nil, true) end
      end
    end
  end

  local regs = { tab:GetRegions() }
  for _, r in ipairs(regs) do
    if r and r.GetObjectType and r:GetObjectType()=="Texture" and not r.__hkd_keep then
      if r.SetAlpha        then r:SetAlpha(0) end
      if r.SetColorTexture then r:SetColorTexture(1,1,1,0) end
      if r.SetTexture      then r:SetTexture(nil) end
      if r.SetAtlas        then pcall(r.SetAtlas, r, nil, true) end
    end
  end

  if tab.GetNormalTexture then local t = tab:GetNormalTexture();     if t then t:SetAlpha(0); t:SetTexture(nil) end end
  if tab.GetPushedTexture then local t = tab:GetPushedTexture();     if t then t:SetAlpha(0); t:SetTexture(nil) end end
  if tab.GetHighlightTexture then local t = tab:GetHighlightTexture(); if t then t:SetAlpha(0); t:SetTexture(nil) end end
  if tab.GetDisabledTexture then local t = tab:GetDisabledTexture(); if t then t:SetAlpha(0); t:SetTexture(nil) end end

  if tab.HighlightTexture and tab.HighlightTexture.SetAlpha then
    tab.HighlightTexture:SetAlpha(0)
  end
end

local function ensureTextLayer(fs)
  if not fs then return end
  if fs.SetDrawLayer then fs:SetDrawLayer("OVERLAY", 5) end -- acima da moldura
  local p, s = fs:GetFont()
  fs:SetFont(p, math.max(10, (s or 12)), "OUTLINE")
  fs:SetShadowColor(0,0,0,0)
end

local function ensureMinWidth(tab, fs)
  if not tab or not fs or not fs.GetStringWidth then return end
  local need = (fs:GetStringWidth() or 0) + TAB_TEXT_PAD
  if (tab:GetWidth() or 0) < need then tab:SetWidth(need) end
end

-- cria um frame-filho elevado com Backdrop (mesma moldura dos badges)
local function ensureBadge(tab)
  if tab.__hkd_badgeFrame then return tab.__hkd_badgeFrame end

  local bf = CreateFrame("Frame", nil, tab, "BackdropTemplate")
  tab.__hkd_badgeFrame = bf
  bf:SetAllPoints(tab)
  bf:SetFrameLevel((tab:GetFrameLevel() or 0) + 20) -- bem acima do vanilla
  bf:SetFrameStrata("DIALOG")                      -- e numa estrata alta
  bf:Show()

  bf:ClearAllPoints()
  bf:SetPoint("TOPLEFT",     tab, "TOPLEFT",      INSET_L,  -INSET_T)
  bf:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -INSET_R,   INSET_B)

  bf.__hkd_keep = true
  bf:SetIgnoreParentAlpha(true) -- não herdar alpha “apagado” do tab

  bf:SetBackdrop({
    bgFile   = BOX_BG,
    edgeFile = BOX_BORDER,
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  bf:SetBackdropColor(unpack(BG_COLOR))
  bf:SetBackdropBorderColor(unpack(BRD_COLOR))
  return bf
end

local function styleTab(tab)
  if not tab or not tab.GetFontString then return end

  muteVanillaPieces(tab)

  local fs = tab:GetFontString()
  ensureTextLayer(fs)
  ensureMinWidth(tab, fs)

  local badgeFrame = ensureBadge(tab)

  local function applyState()
    local active = isActiveTab(tab)
    if active then
      badgeFrame:SetAlpha(ALPHA_SELECTED)
      if fs then fs:SetTextColor(1,1,1,1.0) end
    elseif tab:IsMouseOver() then
      badgeFrame:SetAlpha(ALPHA_HOVER)
      if fs then fs:SetTextColor(1,1,1,1.0) end
    else
      badgeFrame:SetAlpha(ALPHA_DESELECTED)
      if fs then fs:SetTextColor(1,1,1,0.85) end
    end
  end

  if tab.HookScript and not tab.__hkd_hovered then
    tab.__hkd_hovered = true
    tab:HookScript("OnEnter", applyState)
    tab:HookScript("OnLeave", applyState)
    tab:HookScript("OnShow",  applyState)
  end

  if type(_G.FCF_Tab_OnClick) ~= "function" then
    local orig = tab:GetScript("OnClick")
    tab:SetScript("OnClick", function(self, ...)
      if orig then pcall(orig, self, ...) end
      C_Timer.After(0, applyState)
    end)
  end

  tab.__hkd_apply = applyState
  applyState()
end

local function applyAllTabs()
  for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
    local tab = _G["ChatFrame"..i.."Tab"]
    if tab then styleTab(tab) end
  end
  if _G.SELECTED_CHAT_FRAME and _G.SELECTED_CHAT_FRAME.tab then
    styleTab(_G.SELECTED_CHAT_FRAME.tab)
  end
end

-------------------------------------------------
-- EVENTOS / HOOKS
-------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("UPDATE_CHAT_WINDOWS")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
  C_Timer.After(0, applyAllTabs)
end)

if type(_G.FCF_Tab_OnClick) == "function" then
  hooksecurefunc("FCF_Tab_OnClick", function() C_Timer.After(0, applyAllTabs) end)
end
if type(_G.FCF_SetSelectedWindow) == "function" then
  hooksecurefunc("FCF_SetSelectedWindow", function() C_Timer.After(0, applyAllTabs) end)
end
if type(_G.FCFDock_UpdateTabs) == "function" then
  hooksecurefunc("FCFDock_UpdateTabs", function() C_Timer.After(0, applyAllTabs) end)
end
if type(_G.FCF_UpdateButtonSide) == "function" then
  hooksecurefunc("FCF_UpdateButtonSide", function() C_Timer.After(0, applyAllTabs) end)
end

 end
-- END 53_chat_tabs.lua
