-- GROUP 70_adopt: 1 file(s) merged

-- BEGIN 80_adopt_release.lua
 do
-- 80_adopt_release.lua
local _, ns = ...
local CFG = ns.CFG

-- ===== helpers BG =====
local function enforceTransparentBG(cf)
  if ns.enforceTransparentBG then ns.enforceTransparentBG(cf) end
end
local function restoreBG(cf)
  if ns.restoreBG then ns.restoreBG(cf) end
end

-- ===== salvar/restaurar pontos =====
local function savePoints(f, out) wipe(out); for i=1,f:GetNumPoints() do out[i]={f:GetPoint(i)} end end
local function restorePoints(f, pts) f:ClearAllPoints(); for _,p in ipairs(pts) do f:SetPoint(unpack(p)) end end

-- ===== tabs/botões vanilla =====
ns.state.origTabShown = ns.state.origTabShown or {}
ns.state.origButtons  = ns.state.origButtons  or {
  QuickJoinToastButton = nil,
  ChatFrameChannelButton = nil,
  ChatFrameToggleVoiceDeafenButton = nil,
  ChatFrameToggleVoiceMuteButton   = nil,
  ChatFrameMenuButton = nil,
  GeneralDockManager  = nil,
}

local function snapshotTabsAndButtons()
  if NUM_CHAT_WINDOWS then
    for i=1, NUM_CHAT_WINDOWS do
      local t = _G["ChatFrame"..i.."Tab"]
      if t ~= nil and ns.state.origTabShown[i] == nil then
        ns.state.origTabShown[i] = t:IsShown() or false
      end
    end
  end
  for k in pairs(ns.state.origButtons) do
    local obj = _G[k]
    if obj ~= nil and ns.state.origButtons[k] == nil then
      ns.state.origButtons[k] = obj:IsShown() or false
    end
  end
end

function ns.hideTabsAndButtonsWhileOpen()
  if _G.GeneralDockManager then _G.GeneralDockManager:Hide() end
  if _G.ChatFrameMenuButton then _G.ChatFrameMenuButton:Show() end
  if _G.QuickJoinToastButton then _G.QuickJoinToastButton:Hide() end
  if _G.ChatFrameChannelButton then _G.ChatFrameChannelButton:Hide() end
  if _G.ChatFrameToggleVoiceDeafenButton then _G.ChatFrameToggleVoiceDeafenButton:Hide() end
  if _G.ChatFrameToggleVoiceMuteButton   then _G.ChatFrameToggleVoiceMuteButton:Hide()   end
  if NUM_CHAT_WINDOWS then
    for i=1, NUM_CHAT_WINDOWS do
      local t = _G["ChatFrame"..i.."Tab"]; if t then t:Hide() end
    end
  end
end

function ns.restoreTabsAndButtons()
  if _G.GeneralDockManager then _G.GeneralDockManager:Show() end
  if _G.ChatFrameMenuButton then _G.ChatFrameMenuButton:Show() end
  if _G.QuickJoinToastButton then _G.QuickJoinToastButton:Show() end
  if _G.ChatFrameChannelButton then _G.ChatFrameChannelButton:Show() end
  if _G.ChatFrameToggleVoiceDeafenButton then _G.ChatFrameToggleVoiceDeafenButton:Show() end
  if _G.ChatFrameToggleVoiceMuteButton   then _G.ChatFrameToggleVoiceMuteButton:Show()   end

  if ns.HKD_GetRealChatFrameIndices and ns.isVoiceLabel then
    local valid = {}
    for _, idx in ipairs(ns.HKD_GetRealChatFrameIndices()) do valid[idx] = true end
    if NUM_CHAT_WINDOWS and GetChatWindowInfo then
      for i=1, NUM_CHAT_WINDOWS do
        local lbl = (ns.HKD_GetTabLabel and ns.HKD_GetTabLabel(i)) or ""
        local _,_,_,_,_,_, shown, _, docked = GetChatWindowInfo(i)
        local shouldShow = (valid[i] or shown or docked) and (not ns.isVoiceLabel(lbl))
        local t = _G["ChatFrame"..i.."Tab"]
        if t then if shouldShow then t:Show() else t:Hide() end end
      end
    end
  else
    if NUM_CHAT_WINDOWS then
      for i=1, NUM_CHAT_WINDOWS do
        local t = _G["ChatFrame"..i.."Tab"]
        if t and ns.state.origTabShown[i] ~= nil then
          if ns.state.origTabShown[i] then t:Show() else t:Hide() end
        end
      end
    end
  end
end

-- ===== suprimir/voltar outros ChatFrames =====
ns.state.suppressedFrames = ns.state.suppressedFrames or {}
local function getChatIndex(cf) return (cf and cf.GetID) and cf:GetID() or nil end

function ns.suppressOtherChatFrames(exceptIdx)
  wipe(ns.state.suppressedFrames)
  if not NUM_CHAT_WINDOWS then return end
  for i=1, NUM_CHAT_WINDOWS do
    local cf = _G["ChatFrame"..i]
    if cf and i ~= exceptIdx then
      if cf:IsShown() then ns.state.suppressedFrames[cf] = true end
      cf:Hide()
    end
  end
end

function ns.restoreSuppressedChatFrames()
  for cf, wasShown in pairs(ns.state.suppressedFrames) do
    if wasShown and cf and cf.Show then cf:Show() end
  end
  wipe(ns.state.suppressedFrames)
end

-- ===== salvar/restaurar geometria por frame =====
ns.state.origByFrame = ns.state.origByFrame or {}
local function snapshotOriginalsFor(f)
  if ns.state.origByFrame[f] then return end
  ns.state.origByFrame[f] = {
    parent = f:GetParent(),
    strata = f:GetFrameStrata(),
    level  = f:GetFrameLevel(),
    w = f:GetWidth(), h = f:GetHeight(),
    points = {},
  }
  savePoints(f, ns.state.origByFrame[f].points)
end
local function restoreFrame(f)
  local o = ns.state.origByFrame[f]; if not o then return end
  f:SetParent(o.parent or UIParent)
  restorePoints(f, o.points)
  if o.w and o.h then f:SetSize(o.w,o.h) end
  f:SetFrameStrata(o.strata or "LOW")
  f:SetFrameLevel(o.level or 1)
  f:Show()
end

-- ===== Adopt =====
function ns.adoptSpecificChatFrame(cf)
  if not cf then return end
  ns.state.guard   = true
  ns.state.adopted = true
  ns.state.currentChat = cf

  snapshotOriginalsFor(cf)
  if ns.snapshotBgState then ns.snapshotBgState(cf) end
  snapshotTabsAndButtons()

  -- EditBox
  local EDIT = ns.EDIT
  EDIT:SetParent(ns.frames.container)
  if ns.positionEditBox then ns.positionEditBox() end
  EDIT:Show()
  if ns.hideEditBoxGfx then ns.hideEditBoxGfx() end

  -- tabs e layout
  if ns.rebuildTabsBar then ns.rebuildTabsBar() end
  if ns.layoutChatArea then ns.layoutChatArea(cf) end

  -- adota chat
  cf:ClearAllPoints()
  cf:SetParent(ns.frames.chatArea)
  cf:SetPoint("TOPLEFT",     ns.frames.chatArea, "TOPLEFT",     CFG.FRAME_INSETS.left, -CFG.FRAME_INSETS.top)
  cf:SetPoint("BOTTOMRIGHT", ns.frames.chatArea, "BOTTOMRIGHT", -CFG.FRAME_INSETS.right, CFG.FRAME_INSETS.bottom)
  local pnl = ns.frames.panel
  cf:SetFrameStrata((pnl and pnl:GetFrameStrata()) or "HIGH")
  cf:SetFrameLevel(((pnl and pnl:GetFrameLevel()) or 10) + 1)
  cf:SetFading(false)
  if cf.SetIndentedWordWrap then cf:SetIndentedWordWrap(false) end
  cf:SetSpacing(CFG.EXTRA_SPACING)
  if cf.EnableMouse then cf:EnableMouse(true) end
  if cf.SetAlpha then cf:SetAlpha(1) end
  if cf.Show then cf:Show() end

  enforceTransparentBG(cf)

  if cf.ScrollBar then cf.ScrollBar:Hide() end
  if cf.ScrollToBottomButton then cf.ScrollToBottomButton:Hide() end
  if cf.ScrollToBottom then
    if C_Timer and C_Timer.After then C_Timer.After(0, function() if cf.ScrollToBottom then cf:ScrollToBottom() end end)
    else cf:ScrollToBottom() end
  end

  ns.suppressOtherChatFrames(getChatIndex(cf) or -1)
  ns.hideTabsAndButtonsWhileOpen()

  if ns.raiseTabsBar then C_Timer.After(0, ns.raiseTabsBar) end

  -- reforço do Social (se a barra estiver aberta)
if ns.frames.leftBar and ns.frames.leftBar:IsShown() and ns.attachSocial then
  ns.attachSocial()
end

  if C_Timer and C_Timer.After then
    C_Timer.After(0, function() ns.state.guard=false end)
  else
    ns.state.guard=false
  end
end

-- ===== Release =====
function ns.releaseCurrentChat()
  local cf = ns.state.currentChat
  if not cf then return end

  -- garante que o dock vanilla fique na mesma aba do cf atual
  local function selectDockByFrame(frame)
    if not frame then return end
    if _G.GENERAL_CHAT_DOCK then
      if _G.FCFDock_SetSelectedWindow then
        FCFDock_SetSelectedWindow(GENERAL_CHAT_DOCK, frame)
      elseif _G.FCFDock_SelectWindow then
        FCFDock_SelectWindow(GENERAL_CHAT_DOCK, frame)
      end
    else
      local tab = frame:GetName() and _G[frame:GetName().."Tab"] or nil
      if tab and _G.FCF_Tab_OnClick then FCF_Tab_OnClick(tab) end
    end
  end

  selectDockByFrame(cf)

  -- lembra qual frame ficou selecionado no default (usado pelo getActiveChatFrame do utils)
  ns.state.lastDefaultSelected = cf

  ns.state.adopted = false

  restoreBG(cf)
  if ns.showEditBoxGfx then ns.showEditBoxGfx() end
  restoreFrame(cf)

  if cf.ScrollBar then cf.ScrollBar:Show() end
  if cf.ScrollToBottomButton then cf.ScrollToBottomButton:Show() end
  ns.restoreSuppressedChatFrames()

  -- limpa barra custom
  if ns.frames and ns.frames.tabsBar and ns.frames.tabsBar.buttons then
    for _,b in ipairs(ns.frames.tabsBar.buttons) do b:Hide(); b:SetParent(nil) end
    wipe(ns.frames.tabsBar.buttons)
  end
  ns.restoreTabsAndButtons()

  if ns.normalizeDockVisibility then ns.normalizeDockVisibility() end

  if ns.EDIT then ns.EDIT:SetParent(UIParent); ns.EDIT:Hide() end
  ns.state.currentChat = nil

  -- === NORMALIZAÇÃO DE VISIBILIDADE PÓS-RELEASE ===
  do
    local selected = cf
    if NUM_CHAT_WINDOWS then
      for i=1, NUM_CHAT_WINDOWS do
        local f = _G["ChatFrame"..i]
        if f then
          if f == selected then
            if f.Show then f:Show() end
            if f.SetAlpha then f:SetAlpha(1) end
          else
            if f.Hide then f:Hide() end
          end
        end
      end
    end
    if UIParent_ManageFramePositions then UIParent_ManageFramePositions() end
    if _G.FCFDock_UpdateTabs and _G.GENERAL_CHAT_DOCK then
      FCFDock_UpdateTabs(GENERAL_CHAT_DOCK)
    end
  end

  -- não chamamos ensureSocial aqui; quem faz isso é o sidebarDetach()
end

 end
-- END 80_adopt_release.lua
