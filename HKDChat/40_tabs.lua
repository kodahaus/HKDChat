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
