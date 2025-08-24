-- HKDChat v3.9.9
-- • Corrige “tabs fantasmas” e só mostra tabs reais (dockadas/visíveis)
-- • Voice tab nunca aparece; BG zero no adotado; overlap fix; foco do EditBox preservado
-- • Esconde a barrinha lateral escura (ChatFrameXButtonFrame) do default
-- • Mata botões de voz (Deafen/Undeafen/Mute/Unmute) em definitivo
-- • REALOCA o ChatFrameMenuButton (“chat balloon”) para a base da nossa barra lateral

-- ===== Atalho =====
local EDIT = ChatFrame1EditBox

-- ===== Tunáveis =====
local PANEL_W        = 600
local EDGE_PADDING   = 8
local GUTTER_LEFT    = 24
local GUTTER_RIGHT   = 24
local BG_ALPHA       = 0.55
local FADE_MS        = 0.20
local LOGIN_DEBOUNCE = 1.5

local MIN_TEXT_GAP   = 18
local GAP_MULT       = 1.10
local BOTTOM_NUDGE   = 6
local FRAME_INSETS   = { left = 0, top = 2, right = 0, bottom = 2 }
local EXTRA_SPACING  = 1

-- ===== Estado =====
local adopted, guard = false, false
local loginBlockUntil = 0
local currentChat = nil

-- snapshots / estado UI
local origByFrame       = {}
local origAlphaByIdx    = {}
local origTexAlphaByIdx = {}
local texAlphaByIdx     = {}
local origTabShown      = {}
local origButtons = {
  QuickJoinToastButton = nil,
  ChatFrameChannelButton = nil,
  ChatFrameToggleVoiceDeafenButton = nil,
  ChatFrameToggleVoiceMuteButton   = nil,
  ChatFrameMenuButton = nil,
  GeneralDockManager  = nil,
}
local suppressedFrames = {}  -- [frame]=true

-- ===== Helpers =====
local function keyFor(f) return tostring(f) end

local function isVoiceLabel(txt)
  if not txt or txt == "" then return false end
  local s = txt:lower()
  return (s == "voice" or s == "voz")
end

local function isDefaultishName(i, name)
  if not name or name == "" then return true end
  local n = name:lower():gsub("%s+", "")
  if n == ("chatframe"..i):lower() then return true end
  if n == ("window"..i):lower() then return true end
  if n == "newwindow" or n == "newtab" then return true end
  return false
end

-- ===== VOICE UI CLEANUP (mata os botões de voz) =============================
local VOICE_STRINGS = {
  "UNDEAFEN","UNMUTE","DEAFEN","MUTE",
  "Undeafen Voice Chat","Unmute","Deafen","Mute",
  "Cancelar surdez","Ativar som","Silenciar","Ativar microfone"
}

local function killFrame(f)
  if not f or f.__hkd_killed then return end
  f.__hkd_killed = true
  if f.Hide then f:Hide() end
  if f.SetAlpha then f:SetAlpha(0) end
  if f.SetScale then f:SetScale(0.0001) end
  if f.EnableMouse then f:EnableMouse(false) end
  if f.SetScript then f:SetScript("OnShow", function(self) self:Hide() end) end
  if f.UnregisterAllEvents then f:UnregisterAllEvents() end
end

local function tooltipMatches(frame)
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
    if (up:find("VOICE") or up:find("DEAFEN") or up:find("MUTE")) then
      return true
    end
  end
  return false
end

local function tryKnownGlobals()
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
  for _, name in ipairs(known) do
    local f = _G[name]
    if f then killFrame(f) end
  end
end

local function sweepForVoiceButtons()
  local f = EnumerateFrames()
  while f do
    if tooltipMatches(f) then killFrame(f) end
    f = EnumerateFrames(f)
  end
end

local function hideVoiceButtons()
  tryKnownGlobals()
  sweepForVoiceButtons()
  -- também tenta nos “button frames” do chat padrão
  for i=1, (NUM_CHAT_WINDOWS or 10) do
    local bf = _G["ChatFrame"..i.."ButtonFrame"]
    if bf and bf.GetChildren then
      for _, child in ipairs({bf:GetChildren()}) do
        if tooltipMatches(child) then killFrame(child) end
      end
    end
  end
  -- se nosso chat custom tiver um buttonFrame, idem
  if HKDChat and HKDChat.ButtonFrame and HKDChat.ButtonFrame.GetChildren then
    for _, child in ipairs({HKDChat.ButtonFrame:GetChildren()}) do
      if tooltipMatches(child) then killFrame(child) end
    end
  end
end
-- ===========================================================================

-- ===== Painel =====
local panel = CreateFrame("Frame", "HKDChatPanel", UIParent, "BackdropTemplate")
panel:SetFrameStrata("HIGH")
panel:SetClampedToScreen(true)
panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -PANEL_W, 0)
panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
panel:SetWidth(PANEL_W)
panel:EnableMouse(true)
panel:SetPropagateMouseClicks(false)
panel:Hide()
panel:SetAlpha(0)
panel:SetScript("OnMouseDown", function() if EDIT and panel:IsShown() then EDIT:SetFocus() end end)

local bg = panel:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(true)
bg:SetColorTexture(0,0,0,BG_ALPHA)

local container = CreateFrame("Frame", nil, panel)
container:SetPoint("TOPLEFT",     panel, "TOPLEFT",  EDGE_PADDING, -EDGE_PADDING)
container:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -EDGE_PADDING, EDGE_PADDING)
container:SetClipsChildren(false)
container:EnableMouse(true)
container:SetPropagateMouseClicks(false)
container:SetScript("OnMouseDown", function() if EDIT and panel:IsShown() then EDIT:SetFocus() end end)

local chatArea = CreateFrame("Frame", nil, container)
chatArea:SetClipsChildren(false)
chatArea:EnableMouse(true)
chatArea:SetPropagateMouseClicks(false)
chatArea:SetScript("OnMouseDown", function() if EDIT and panel:IsShown() then EDIT:SetFocus() end end)

-- ===== Barra vertical de abas (direita) =====
local tabsBar = CreateFrame("Frame", "HKDChatTabs", container)
tabsBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, -6)
tabsBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4, 6)
tabsBar:SetWidth(26)
tabsBar:EnableMouse(true)
tabsBar:SetPropagateMouseClicks(false)
tabsBar.buttons = {}

local function clearTabsBar()
  for _,b in ipairs(tabsBar.buttons) do b:Hide(); b:SetParent(nil) end
  wipe(tabsBar.buttons)
end

-- ===== Esconder a barrinha lateral default (ChatFrameXButtonFrame) =====
local function hideDefaultButtonFrames()
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

-- ===== Relocar Chat Balloon (ChatFrameMenuButton) para nossa barra =====
local function relocateChatMenuButton()
  local btn = _G.ChatFrameMenuButton
  if not btn then return end

  -- Força ficar no nosso tabsBar sempre que mostrar
  if btn.SetScript then
    btn:SetScript("OnShow", function(self)
      if not tabsBar or not tabsBar:IsShown() then self:Hide(); return end
      self:ClearAllPoints()
      self:SetParent(tabsBar)
      self:SetFrameStrata(tabsBar:GetFrameStrata())
      self:SetFrameLevel(tabsBar:GetFrameLevel() + 2)
      self:SetSize(20, 20)
      self:SetPoint("BOTTOM", tabsBar, "BOTTOM", 0, 2)
      if self.SetAlpha then self:SetAlpha(0.90) end
    end)
  end
  -- Se algum addon esconder, traz de volta
  if btn.HKD_Hooked ~= true and btn.HookScript then
    btn:HookScript("OnHide", function(self)
      C_Timer.After(0, function()
        if tabsBar and tabsBar:IsShown() then self:Show() end
      end)
    end)
    btn.HKD_Hooked = true
  end

  btn:ClearAllPoints()
  btn:SetParent(tabsBar)
  btn:SetFrameStrata(tabsBar:GetFrameStrata())
  btn:SetFrameLevel(tabsBar:GetFrameLevel() + 2)
  btn:SetSize(20, 20)
  btn:SetPoint("BOTTOM", tabsBar, "BOTTOM", 0, 2)
  btn:Show()
  if btn.SetAlpha then btn:SetAlpha(0.90) end
end

-- Preferir dock oficial; fallback: shown/docked em GetChatWindowInfo
local function HKD_GetRealChatFrameIndices()
  local list = {}
  if _G.FCFDock_GetChatFrames and _G.GENERAL_CHAT_DOCK then
    local docked = { FCFDock_GetChatFrames(GENERAL_CHAT_DOCK) }
    for _, cf in ipairs(docked) do
      if cf and cf.GetID then table.insert(list, cf:GetID()) end
    end
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

local function HKD_GetTabLabel(i)
  local tab = _G["ChatFrame"..i.."Tab"]
  if tab and tab.GetText then
    local t = tab:GetText()
    if t and t ~= "" then return t end
  end
  local name = GetChatWindowInfo and GetChatWindowInfo(i)
  if name and name ~= "" then return name end
  return tostring(i)
end

local function makeTabButton(i, label)
  local b = CreateFrame("Button", "HKDChatTabBtn"..i, tabsBar)
  b:SetSize(22, 44)
  if #tabsBar.buttons == 0 then
    b:SetPoint("TOPRIGHT", tabsBar, "TOPRIGHT", 0, 0)
  else
    b:SetPoint("TOPRIGHT", tabsBar.buttons[#tabsBar.buttons], "BOTTOMRIGHT", 0, -6)
  end
  b:EnableMouse(true); b:SetPropagateMouseClicks(false)

  local txt = label or tostring(i)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("CENTER"); fs:SetText(txt); fs:SetRotation(math.rad(90))
  b.fs = fs

  local t = b:CreateTexture(nil, "ARTWORK")
  t:SetAllPoints(true); t:SetColorTexture(1,1,1,0.06)
  b.bg = t
  b:SetScript("OnEnter", function() b.bg:SetAlpha(0.15) end)
  b:SetScript("OnLeave", function() b.bg:SetAlpha(0.06) end)

  b:SetScript("OnClick", function()
    local tab = _G["ChatFrame"..i.."Tab"]
    if tab and FCF_Tab_OnClick then FCF_Tab_OnClick(tab) end
    C_Timer.After(0, function() if panel:IsShown() and EDIT then EDIT:SetFocus() end end)
  end)

  table.insert(tabsBar.buttons, b)
  return b
end

local function rebuildTabsBar()
  clearTabsBar()
  local indices = HKD_GetRealChatFrameIndices()
  for _, i in ipairs(indices) do
    local lbl = HKD_GetTabLabel(i)
    if not isVoiceLabel(lbl) then
      makeTabButton(i, lbl)
    end
  end
  relocateChatMenuButton() -- coloca o “chat balloon” na base da nossa barra
end

-- ===== Fade in/out =====
local fadeInAG    = panel:CreateAnimationGroup()
local fadeInAlpha = fadeInAG:CreateAnimation("Alpha")
fadeInAlpha:SetFromAlpha(0); fadeInAlpha:SetToAlpha(1)
fadeInAlpha:SetDuration(FADE_MS); fadeInAlpha:SetSmoothing("OUT")
fadeInAG:SetScript("OnFinished", function() panel:SetAlpha(1) end)

local fadeOutAG    = panel:CreateAnimationGroup()
local fadeOutAlpha = fadeOutAG:CreateAnimation("Alpha")
fadeOutAlpha:SetFromAlpha(1); fadeOutAlpha:SetToAlpha(0)
fadeOutAlpha:SetDuration(FADE_MS); fadeOutAlpha:SetSmoothing("IN")
fadeOutAG:SetScript("OnFinished", function() panel:Hide(); panel:SetAlpha(0) end)

-- ===== Utils de frame =====
local function savePoints(f, t) wipe(t); for i=1,f:GetNumPoints() do t[i]={f:GetPoint(i)} end end
local function restorePoints(f, t) f:ClearAllPoints(); for _,p in ipairs(t) do f:SetPoint(unpack(p)) end end

local function snapshotOriginalsFor(f)
  local k = keyFor(f); if origByFrame[k] then return end
  origByFrame[k] = { parent=f:GetParent(), strata=f:GetFrameStrata(), level=f:GetFrameLevel(),
    w=f:GetWidth(), h=f:GetHeight(), points={} }
  savePoints(f, origByFrame[k].points)
end
local function restoreFrame(f)
  local o = origByFrame[keyFor(f)]; if not o then return end
  f:SetParent(o.parent or UIParent); restorePoints(f,o.points)
  if o.w and o.h then f:SetSize(o.w,o.h) end
  f:SetFrameStrata(o.strata or "LOW"); f:SetFrameLevel(o.level or 1); f:Show()
end

-- ===== Dock/Abas/Botões =====
local function snapshotTabsAndButtons()
  if NUM_CHAT_WINDOWS then
    for i=1, NUM_CHAT_WINDOWS do
      local t = _G["ChatFrame"..i.."Tab"]
      if t ~= nil and origTabShown[i] == nil then
        origTabShown[i] = t:IsShown() or false
      end
    end
  end
  for k in pairs(origButtons) do
    local obj = _G[k]
    if obj ~= nil and origButtons[k] == nil then
      origButtons[k] = obj:IsShown() or false
    end
  end
end

local function hideTabsAndButtonsWhileOpen()
  if _G.GeneralDockManager then _G.GeneralDockManager:Hide() end
  -- não esconder o ChatFrameMenuButton aqui; vamos relocá-lo e mostrar
  if _G.QuickJoinToastButton then _G.QuickJoinToastButton:Hide() end
  if _G.ChatFrameChannelButton then _G.ChatFrameChannelButton:Hide() end
  -- nunca mostramos os de Voice
  if _G.ChatFrameToggleVoiceDeafenButton then _G.ChatFrameToggleVoiceDeafenButton:Hide() end
  if _G.ChatFrameToggleVoiceMuteButton   then _G.ChatFrameToggleVoiceMuteButton:Hide()   end
  if NUM_CHAT_WINDOWS then
    for i=1, NUM_CHAT_WINDOWS do
      local t = _G["ChatFrame"..i.."Tab"]; if t then t:Hide() end
    end
  end
  hideDefaultButtonFrames() -- mata a barrinha escura
  hideVoiceButtons()        -- reforça
end

-- **MOSTRAR** tabs vanilla só se reais (dockadas/mostradas) e não-Voice
local function restoreTabsAndButtons()
  if _G.GeneralDockManager then _G.GeneralDockManager:Show() end
  if _G.QuickJoinToastButton then _G.QuickJoinToastButton:Show() end
  if _G.ChatFrameChannelButton then _G.ChatFrameChannelButton:Show() end
  -- NÃO reexibir os botões de voice; garantir que sigam ocultos
  hideVoiceButtons()
  -- manter a barrinha default oculta permanentemente
  hideDefaultButtonFrames()

  if NUM_CHAT_WINDOWS and GetChatWindowInfo then
    local valid = {}
    if _G.FCFDock_GetChatFrames and _G.GENERAL_CHAT_DOCK then
      local docked = { FCFDock_GetChatFrames(GENERAL_CHAT_DOCK) }
      for _, cf in ipairs(docked) do if cf and cf.GetID then valid[cf:GetID()] = true end end
    end
    for i=1, NUM_CHAT_WINDOWS do
      local lbl = HKD_GetTabLabel(i)
      local _,_,_,_,_,_, shown, _, docked = GetChatWindowInfo(i)
      local shouldShow = (valid[i] or shown or docked) and (not isVoiceLabel(lbl))
      local t = _G["ChatFrame"..i.."Tab"]
      if t then if shouldShow then t:Show() else t:Hide() end end
    end
  end
end

-- ===== BG helpers =====
local function getChatIndex(cf) return (cf and cf.GetID) and cf:GetID() or nil end
local function readWindowAlpha(idx)
  if not idx or not GetChatWindowInfo then return nil end
  local _,_,_,_,_,_,_,_,_,_, a = GetChatWindowInfo(idx)
  if type(a) ~= "number" then return nil end
  if a > 1 and a <= 100 then return a/100 end
  if a < 0 then return 0 end
  if a > 1 then return 1 end
  return a
end
local function getNamedBackground(cf)
  local name = cf and cf:GetName()
  return name and _G[name.."Background"] or nil
end
local function snapshotBgState(cf)
  local idx = getChatIndex(cf)
  if idx and origAlphaByIdx[idx] == nil then origAlphaByIdx[idx] = readWindowAlpha(idx) or 1 end
  local bgTex = getNamedBackground(cf)
  if idx and bgTex and origTexAlphaByIdx[idx] == nil then origTexAlphaByIdx[idx] = bgTex:GetAlpha() or 1 end
end
local function forceWindowAlphaZero(cf)
  if cf and FCF_SetWindowAlpha then
    FCF_SetWindowAlpha(cf, 0)
  elseif SetChatWindowAlpha then
    local idx = getChatIndex(cf); if idx then SetChatWindowAlpha(idx, 0) end
  end
end
local function zeroAllTextures(cf)
  local idx = getChatIndex(cf); if not idx then return end
  if not texAlphaByIdx[idx] then texAlphaByIdx[idx] = {} end
  local saved = texAlphaByIdx[idx]
  local regions = { cf:GetRegions() }
  for i=1,#regions do
    local r = regions[i]
    if r and r.GetObjectType and r:GetObjectType()=="Texture" then
      if saved[r]==nil then saved[r]=r:GetAlpha() or 1 end
      if r.SetAlpha then r:SetAlpha(0) end
    end
  end
  local bgTex = getNamedBackground(cf)
  if bgTex then if saved[bgTex]==nil then saved[bgTex]=bgTex:GetAlpha() or 1 end; bgTex:SetAlpha(0) end
end
local function restoreAllTextures(cf)
  local idx = getChatIndex(cf); if not idx then return end
  local saved = texAlphaByIdx[idx]; if not saved then return end
  for tex,a in pairs(saved) do if tex and tex.SetAlpha then tex:SetAlpha(a or 1) end end
  texAlphaByIdx[idx] = nil
end
local function enforceTransparentBG(cf) forceWindowAlphaZero(cf); zeroAllTextures(cf) end
local function restoreBG(cf)
  local idx = getChatIndex(cf)
  local a = idx and origAlphaByIdx[idx] or nil
  if a then
    if FCF_SetWindowAlpha then FCF_SetWindowAlpha(cf, a)
    elseif SetChatWindowAlpha and idx then
      local v = (a <= 1) and (a*100) or a
      SetChatWindowAlpha(idx, v)
    end
  end
  local t = idx and origTexAlphaByIdx[idx] or nil
  local bgTex = getNamedBackground(cf)
  if bgTex and t then bgTex:SetAlpha(t) end
  restoreAllTextures(cf)
end

-- ===== EditBox GFX =====
local function hideEditBoxGfx()
  if _G.ChatFrame1EditBoxLeft  then _G.ChatFrame1EditBoxLeft:Hide()  end
  if _G.ChatFrame1EditBoxMid   then _G.ChatFrame1EditBoxMid:Hide()   end
  if _G.ChatFrame1EditBoxRight then _G.ChatFrame1EditBoxRight:Hide() end
end
local function showEditBoxGfx()
  if _G.ChatFrame1EditBoxLeft  then _G.ChatFrame1EditBoxLeft:Show()  end
  if _G.ChatFrame1EditBoxMid   then _G.ChatFrame1EditBoxMid:Show()   end
  if _G.ChatFrame1EditBoxRight then _G.ChatFrame1EditBoxRight:Show() end
end

-- ===== Layout =====
local function layoutChatArea(chatFrameForFont)
  local cf = chatFrameForFont or currentChat or ChatFrame1
  local _, fontH = cf:GetFont()
  local GAP = math.max(MIN_TEXT_GAP, math.ceil((fontH or MIN_TEXT_GAP)*GAP_MULT))
  chatArea:ClearAllPoints()
  chatArea:SetPoint("TOPLEFT",  container, "TOPLEFT",  GUTTER_LEFT,  -GUTTER_LEFT - FRAME_INSETS.top)
  chatArea:SetPoint("TOPRIGHT", container, "TOPRIGHT", -GUTTER_RIGHT - tabsBar:GetWidth() - 6, -GUTTER_RIGHT - FRAME_INSETS.top)
  local editH = EDIT:GetHeight() or 30
  local baseOffset = EDGE_PADDING + editH + GAP + BOTTOM_NUDGE + FRAME_INSETS.bottom
  chatArea:SetPoint("BOTTOMLEFT",  container, "BOTTOMLEFT",  GUTTER_LEFT,  baseOffset)
  chatArea:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -GUTTER_RIGHT - tabsBar:GetWidth() - 6, baseOffset)
end

-- ===== Overlap helpers =====
local function suppressOtherChatFrames(exceptIdx)
  wipe(suppressedFrames)
  if not NUM_CHAT_WINDOWS then return end
  for i=1, NUM_CHAT_WINDOWS do
    local cf = _G["ChatFrame"..i]
    if cf and i ~= exceptIdx and cf:IsShown() then suppressedFrames[cf] = true; cf:Hide() end
  end
end
local function restoreSuppressedChatFrames()
  for cf, wasShown in pairs(suppressedFrames) do
    if wasShown and cf and cf.Show then cf:Show() end
  end
  wipe(suppressedFrames)
end

local function normalizeDockVisibility()
  local selected
  if _G.GENERAL_CHAT_DOCK and _G.FCFDock_GetSelectedWindow then
    selected = FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
  end
  if _G.GENERAL_CHAT_DOCK and _G.FCFDock_GetChatFrames then
    local docked = { FCFDock_GetChatFrames(GENERAL_CHAT_DOCK) }
    for _, cf in ipairs(docked) do if cf ~= selected and cf and cf.Hide then cf:Hide() end end
  end
  if _G.ChatFrame2 and (not selected or _G.ChatFrame2 ~= selected) then ChatFrame2:Hide() end
  if selected and _G.FCF_FadeInChatFrame then FCF_FadeInChatFrame(selected) end
end

-- ===== Aba ativa =====
local function getActiveChatFrame()
  if _G.SELECTED_CHAT_FRAME and _G.SELECTED_CHAT_FRAME.AddMessage then return _G.SELECTED_CHAT_FRAME end
  if _G.LAST_ACTIVE_CHAT_EDIT_BOX and _G.LAST_ACTIVE_CHAT_EDIT_BOX.GetParent then
    local cf = _G.LAST_ACTIVE_CHAT_EDIT_BOX:GetParent()
    if cf and cf.AddMessage then return cf end
  end
  return ChatFrame1
end

-- ===== Adopt / Release =====
local function adoptSpecificChatFrame(cf)
  guard = true; adopted = true; currentChat = cf
  snapshotOriginalsFor(cf); snapshotBgState(cf); snapshotTabsAndButtons()

  EDIT:SetParent(container)
  EDIT:ClearAllPoints()
  EDIT:SetPoint("BOTTOMLEFT",  container, "BOTTOMLEFT",  EDGE_PADDING, EDGE_PADDING/2)
  EDIT:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -EDGE_PADDING - tabsBar:GetWidth() - 6, EDGE_PADDING/2)
  EDIT:SetFrameStrata("DIALOG")
  EDIT:SetFrameLevel(panel:GetFrameLevel() + 10)
  EDIT:Show(); hideEditBoxGfx()

  rebuildTabsBar(); layoutChatArea(cf)

  cf:ClearAllPoints()
  cf:SetParent(chatArea)
  cf:SetPoint("TOPLEFT",     chatArea, "TOPLEFT",     FRAME_INSETS.left, -FRAME_INSETS.top)
  cf:SetPoint("BOTTOMRIGHT", chatArea, "BOTTOMRIGHT", -FRAME_INSETS.right, FRAME_INSETS.bottom)
  cf:SetFrameStrata(panel:GetFrameStrata())
  cf:SetFrameLevel(panel:GetFrameLevel()+1)
  cf:SetFading(false)
  if cf.SetIndentedWordWrap then cf:SetIndentedWordWrap(false) end
  cf:SetSpacing(EXTRA_SPACING)

  enforceTransparentBG(cf)
  if C_Timer and C_Timer.After then C_Timer.After(0, function() enforceTransparentBG(cf) end) end

  suppressOtherChatFrames((cf.GetID and cf:GetID()) or nil)
  hideTabsAndButtonsWhileOpen()
  relocateChatMenuButton()  -- garante o balãozinho no tabsBar
  if cf.ScrollBar then cf.ScrollBar:Hide() end
  if cf.ScrollToBottomButton then cf.ScrollToBottomButton:Hide() end
  if cf.ScrollToBottom then
    if C_Timer and C_Timer.After then C_Timer.After(0, function() cf:ScrollToBottom() end) else cf:ScrollToBottom() end
  end
  if C_Timer and C_Timer.After then C_Timer.After(0, function() guard=false end) else guard=false end
end

local function releaseCurrentChat()
  if not currentChat then return end
  local cf = currentChat
  adopted = false
  restoreBG(cf); showEditBoxGfx()
  restoreFrame(cf)
  if cf.ScrollBar then cf.ScrollBar:Show() end
  if cf.ScrollToBottomButton then cf.ScrollToBottomButton:Show() end
  restoreSuppressedChatFrames()
  clearTabsBar(); restoreTabsAndButtons()
  normalizeDockVisibility()
  EDIT:SetParent(UIParent); EDIT:Hide()
  currentChat = nil
end

local function reAdoptActiveIfOpen()
  if not panel:IsShown() or guard then return end
  local active = getActiveChatFrame()
  if active ~= currentChat then
    releaseCurrentChat()
    adoptSpecificChatFrame(active)
  else
    hideTabsAndButtonsWhileOpen()
    relocateChatMenuButton()  -- reforça ao alternar de aba
    suppressOtherChatFrames((active.GetID and active:GetID()) or nil)
  end
end

-- ===== Mostrar / Ocultar =====
local function showPanel()
  if GetTime and GetTime() < (loginBlockUntil or 0) then return end
  if panel:IsShown() then return end
  panel:SetAlpha(0); panel:Show()
  fadeOutAG:Stop(); fadeInAG:Stop()
  adoptSpecificChatFrame(getActiveChatFrame())
  fadeInAG:Play()
end
local function hidePanel()
  if not panel:IsShown() or not adopted or guard then return end
  fadeInAG:Stop(); fadeOutAG:Stop()
  releaseCurrentChat()
  fadeOutAG:Play()
end

-- ===== Hooks oficiais =====
hooksecurefunc("ChatEdit_ActivateChat", function(editBox)
  if editBox ~= EDIT then return end
  EDIT:Show(); showPanel()
end)
hooksecurefunc("ChatEdit_DeactivateChat", function(editBox)
  if editBox ~= EDIT then return end
  if panel:IsShown() and (panel:IsMouseOver() or container:IsMouseOver() or chatArea:IsMouseOver() or tabsBar:IsMouseOver()) then
    C_Timer.After(0, function() if panel:IsShown() then EDIT:SetFocus() end end)
    return
  end
  EDIT:Hide(); hidePanel()
end)
hooksecurefunc("FCF_Tab_OnClick", function() reAdoptActiveIfOpen() end)

-- **Antifantasmas**: se alguém abrir uma janela nova, não deixa tab inútil/Voice aparecer
if not _G.HKDChat_NewWindowHooked then
  _G.HKDChat_NewWindowHooked = true
  hooksecurefunc("FCF_OpenNewWindow", function(name)
    C_Timer.After(0, function()
      if not NUM_CHAT_WINDOWS or not GetChatWindowInfo then return end
      for i=1, NUM_CHAT_WINDOWS do
        local cf  = _G["ChatFrame"..i]
        if cf then
          local rname = GetChatWindowInfo(i)
          local tab = _G["ChatFrame"..i.."Tab"]
          if tab then
            local label = tab.GetText and tab:GetText() or rname
            if (i >= 5 and isDefaultishName(i, rname)) or isVoiceLabel(label) then
              tab:Hide()
            end
          end
        end
      end
      hideDefaultButtonFrames()
      hideVoiceButtons()
      relocateChatMenuButton()
    end)
  end)
end

-- ===== Post-hooks anti-BG teimoso =====
if not _G.HKDChat_BGHooksInstalled then
  _G.HKDChat_BGHooksInstalled = true
  hooksecurefunc("FCF_SetWindowAlpha", function(frame, a)
    local idx = (frame and frame.GetID) and frame:GetID() or nil
    if not panel:IsShown() then
      if idx and GetChatWindowInfo then
        local _,_,_,_,_,_,_,_,_,_, al = GetChatWindowInfo(idx)
        if type(al)=="number" then
          if al > 1 and al <= 100 then al = al/100 end
          if al < 0 then al = 0 elseif al > 1 then al = 1 end
          origAlphaByIdx[idx] = al
        end
      end
      return
    end
    if frame == currentChat then
      if C_Timer and C_Timer.After then C_Timer.After(0, function() enforceTransparentBG(frame) end)
      else enforceTransparentBG(frame) end
    end
  end)
  if _G.FCF_FadeInChatFrame then
    hooksecurefunc("FCF_FadeInChatFrame", function(frame)
      if panel:IsShown() and frame == currentChat then
        if C_Timer and C_Timer.After then C_Timer.After(0, function() enforceTransparentBG(frame) end)
        else enforceTransparentBG(frame) end
      end
    end)
  end
end

-- ===== Eventos =====
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("UI_SCALE_CHANGED")
ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
ev:RegisterEvent("UPDATE_CHAT_WINDOWS")
ev:RegisterEvent("CHANNEL_UI_UPDATE")
ev:RegisterEvent("VOICE_CHAT_CHANNEL_ACTIVATED")
ev:RegisterEvent("VOICE_CHAT_CHANNEL_DEACTIVATED")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" then
    loginBlockUntil = GetTime and (GetTime() + LOGIN_DEBOUNCE) or 0
    hideDefaultButtonFrames()
    hideVoiceButtons()
    relocateChatMenuButton()
    if adopted then releaseCurrentChat() end
    panel:Hide(); panel:SetAlpha(0); EDIT:Hide()
    texAlphaByIdx = {}; clearTabsBar()
    wipe(origTabShown); wipe(origButtons); wipe(suppressedFrames)
  elseif event == "UPDATE_CHAT_WINDOWS" then
    hideDefaultButtonFrames()
    hideVoiceButtons()
    if panel:IsShown() and adopted then
      hideTabsAndButtonsWhileOpen()
      rebuildTabsBar()
      relocateChatMenuButton()
      reAdoptActiveIfOpen()
    else
      restoreTabsAndButtons()
      relocateChatMenuButton()
    end
  elseif event == "CHANNEL_UI_UPDATE" or event == "VOICE_CHAT_CHANNEL_ACTIVATED" or event == "VOICE_CHAT_CHANNEL_DEACTIVATED" then
    hideDefaultButtonFrames()
    hideVoiceButtons()
    relocateChatMenuButton()
  else
    if panel:IsShown() and adopted then layoutChatArea(currentChat or ChatFrame1) end
  end
end)

-- ===== Slash =====
SLASH_HKDCHAT_1 = "/hkdchat"
SlashCmdList.HKDCHAT = function(msg)
  msg = (msg or ""):lower()
  if msg == "reset" then
    if adopted then releaseCurrentChat() end
    if FCF_ResetChatWindows then FCF_ResetChatWindows() end
    hideDefaultButtonFrames()
    hideVoiceButtons()
    relocateChatMenuButton()
    print("|cff55ff55HKDChat:|r chat windows resetadas.")
    return
  end
  if panel:IsShown() and adopted then hidePanel() else showPanel() end
end
