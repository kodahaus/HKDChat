-- GROUP 50_anchors: 3 file(s) merged

-- BEGIN 46_social_anchor.lua
 do
-- 46_social_anchor.lua
local _, ns = ...
local panel = ns.frames and ns.frames.panel
local F = _G.FriendsFrame

local function hookFriendsClicks()
  if not F or F.__hkd_clicks then return end
  F.__hkd_clicks = true
  local function ping(_, button)
    if button ~= "LeftButton" then return end
    if ns.PingDockInteraction then ns.PingDockInteraction() end
  end
  if F.HookScript then F:HookScript("OnMouseDown", ping) end
  for i = 1, 20 do
    local tab = _G["FriendsFrameTab"..i]
    if tab and tab.HookScript then tab:HookScript("OnMouseDown", ping) end
  end
end

local saved = { points=nil, strata=nil, parent=nil, wasIgnoring=nil, userPlaced=nil }

local function PanelShown()
  return ns.frames and ns.frames.panel and ns.frames.panel:IsShown()
end

local function SaveState()
  if not F then return end
  saved.points = {}
  for i=1, F:GetNumPoints() do
    local p, rel, rp, x, y = F:GetPoint(i)
    saved.points[i] = { p, rel, rp, x, y }
  end
  saved.strata = F:GetFrameStrata()
  saved.parent = F:GetParent()
  if F.IsIgnoringFramePositionManager then
    saved.wasIgnoring = F:IsIgnoringFramePositionManager()
  end
  if F.IsUserPlaced then
    saved.userPlaced = F:IsUserPlaced()
  end
end

local function ApplyAnchor()
  panel = ns.frames and ns.frames.panel
  if not (panel and panel:IsShown() and F and F:IsShown()) then return end

  F:ClearAllPoints()
  local GAP = (ns.CFG and ns.CFG.SOCIAL_GAP) or 12
  F:SetPoint("TOPLEFT", panel, "TOPRIGHT", GAP, 0)

  local pStrata = panel:GetFrameStrata() or "HIGH"
  if pStrata == "BACKGROUND" or pStrata == "LOW" or pStrata == "MEDIUM" then pStrata = "HIGH" end
  F:SetFrameStrata(pStrata)
  F:SetToplevel(true)
end

function ns.social_AnchorToPanel()
  if not (PanelShown() and F and F:IsShown()) then return end
  if not saved.points then SaveState() end
  if F.SetIgnoreFramePositionManager then F:SetIgnoreFramePositionManager(true) end
  if F.SetUserPlaced then F:SetUserPlaced(true) end
  F.__hkd_social_docked = true
  ApplyAnchor()
  if ns.dock_StackRelayout then ns.dock_StackRelayout() end
end

function ns.social_RestoreState()
  if not F then return end
  F.__hkd_social_docked = false
  if F.SetIgnoreFramePositionManager then F:SetIgnoreFramePositionManager(false) end
  if F.SetUserPlaced and saved.userPlaced ~= nil then F:SetUserPlaced(saved.userPlaced) end
  F:ClearAllPoints()
  if saved.points and #saved.points > 0 then
    for _, pt in ipairs(saved.points) do F:SetPoint(unpack(pt)) end
  else
    F:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
  if saved.strata then F:SetFrameStrata(saved.strata) end
  if saved.parent then F:SetParent(saved.parent) end
  if _G.UIParent_ManageFramePositions then _G.UIParent_ManageFramePositions() end
  if _G.UpdateUIPanelPositions then _G.UpdateUIPanelPositions() end
  saved.points, saved.strata, saved.parent, saved.wasIgnoring, saved.userPlaced = nil,nil,nil,nil,nil
end

-- hooks com o panel
if panel then
  panel:HookScript("OnShow", function()
    if F and F:IsShown() then
      ns.social_AnchorToPanel()
      if ns.dock_StackRelayout then ns.dock_StackRelayout() end
    end
  end)
  panel:HookScript("OnHide", function()
    if F and F:IsShown() then ns.social_RestoreState() end
  end)
end

-- hooks do Friends
if F then
  F:HookScript("OnShow", function()
    if PanelShown() then
      ns.social_AnchorToPanel()
      if _G.PVEFrame and _G.PVEFrame:IsShown() and ns.mplus_AnchorToPanel then ns.mplus_AnchorToPanel() end
      if ns.dock_StackRelayout then ns.dock_StackRelayout() end
    end
    hookFriendsClicks()
  end)

  F:HookScript("OnHide", function()
    local p = ns.frames and ns.frames.panel
    if p and p:IsShown() then
      if _G.PVEFrame and _G.PVEFrame:IsShown() and ns.mplus_AnchorToPanel then ns.mplus_AnchorToPanel() end
      if _G.CharacterFrame and _G.CharacterFrame:IsShown() and ns.char_AnchorToPanel then ns.char_AnchorToPanel() end
      if ns.dock_StackRelayout then ns.dock_StackRelayout() end
      return
    end
    ns.social_RestoreState()
  end)
end

-- anti-dança
local function reinforce()
  if F and F.__hkd_social_docked and PanelShown() and F:IsShown() then
    ApplyAnchor()
    if ns.dock_StackRelayout then ns.dock_StackRelayout() end
  end
end
if _G.UpdateUIPanelPositions then hooksecurefunc("UpdateUIPanelPositions", reinforce) end
if _G.UIParent_ManageFramePositions then hooksecurefunc("UIParent_ManageFramePositions", reinforce) end

 end
-- END 46_social_anchor.lua

-- BEGIN 47_character_anchor.lua
 do
-- 47_character_anchor.lua
local _, ns = ...
local CFG = ns.CFG or {}

local function Panel()  return ns.frames and ns.frames.panel end
local function Char()   return _G.CharacterFrame end
local function Social() return _G.FriendsFrame end

-- ping em cliques (mantém EditBox vivo) — **agora só no LeftButton**
local function hookCharClicks()
  local cf = Char(); if not cf or cf.__hkd_clicks then return end
  cf.__hkd_clicks = true
  local function ping(_, button)
    if button ~= "LeftButton" then return end
    if ns.PingDockInteraction then ns.PingDockInteraction() end
  end
  if cf.HookScript then cf:HookScript("OnMouseDown", ping) end
  local frames = {
    _G.PaperDollFrame,
    _G.ReputationFrame or _G.CharacterReputationFrame,
    _G.TokenFrame      or _G.CharacterTokenFrame,
  }
  for _, fr in ipairs(frames) do
    if fr and fr.HookScript then fr:HookScript("OnMouseDown", ping) end
  end
  for i = 1, 20 do
    local tab = _G["CharacterFrameTab"..i]
    if tab and tab.HookScript then tab:HookScript("OnMouseDown", ping) end
  end
end

-- helpers
local function Over(f)
  if not f or not f.IsShown or not f:IsShown() then return false end
  if f.IsMouseOver then return f:IsMouseOver() end
  if MouseIsOver then return MouseIsOver(f) end
  return false
end
local function IsOnCloseButton_Char()
  local cf = Char()
  local close = cf and (cf.CloseButton or _G.CharacterFrameCloseButton)
  return Over(close)
end
local function IsInteractingWith_Char() return Over(Char()) end

-- snapshot
local saved = { points=nil, strata=nil, parent=nil, wasIgnoring=nil, userPlaced=nil }
local function saveCharState()
  local cf = Char(); if not cf then return end
  saved.points = {}
  for i = 1, cf:GetNumPoints() do
    local p, rel, rp, x, y = cf:GetPoint(i)
    saved.points[i] = { p, rel, rp, x, y }
  end
  saved.strata = cf:GetFrameStrata()
  saved.parent = cf:GetParent()
  if cf.IsIgnoringFramePositionManager then
    saved.wasIgnoring = cf:IsIgnoringFramePositionManager()
  end
  if cf.IsUserPlaced then
    saved.userPlaced = cf:IsUserPlaced()
  end
end
local function restoreCharState()
  local cf = Char(); if not cf then return end
  if cf.SetIgnoreFramePositionManager then cf:SetIgnoreFramePositionManager(false) end
  if cf.SetUserPlaced and saved.userPlaced ~= nil then cf:SetUserPlaced(saved.userPlaced) end
  cf:ClearAllPoints()
  if saved.points and #saved.points > 0 then
    for _, pt in ipairs(saved.points) do cf:SetPoint(unpack(pt)) end
  else
    cf:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
  if saved.strata then cf:SetFrameStrata(saved.strata) end
  if saved.parent then cf:SetParent(saved.parent) end
  if _G.UIParent_ManageFramePositions then _G.UIParent_ManageFramePositions() end
  if _G.UpdateUIPanelPositions then _G.UpdateUIPanelPositions() end
  saved.points, saved.strata, saved.parent, saved.wasIgnoring, saved.userPlaced = nil,nil,nil,nil,nil
end

-- reforço
local function reinforce()
  local p, cf = Panel(), Char()
  if not (p and p:IsShown() and cf and cf:IsShown() and cf.__hkd_char_docked) then return end
  cf:ClearAllPoints()
  local gap = tonumber(CFG.CHARFRAME_GAP) or 12
  if CFG.CHARFRAME_INSIDE then
    local container = ns.frames and ns.frames.container or p
    cf:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
  else
    cf:SetPoint("TOPLEFT", p, "TOPRIGHT", gap, 0)
  end
  local s = p:GetFrameStrata() or "HIGH"
  if s == "BACKGROUND" or s == "LOW" or s == "MEDIUM" then s = "HIGH" end
  cf:SetFrameStrata(s); cf:SetToplevel(true)
end

-- ancoragem
function ns.char_AnchorToPanel()
  local p, cf = Panel(), Char()
  if not (p and p:IsShown() and cf and cf:IsShown()) then return end
  if not saved.points then saveCharState() end
  if cf.SetIgnoreFramePositionManager then cf:SetIgnoreFramePositionManager(true) end
  if cf.SetUserPlaced then cf:SetUserPlaced(true) end
  cf.__hkd_char_docked = true
  reinforce()
  if ns.dock_StackRelayout then ns.dock_StackRelayout() end
end

function ns.char_RestoreState()
  local cf = Char()
  if cf then cf.__hkd_char_docked = false end
  restoreCharState()
end

function ns.char_ToggleAndDock()
  if InCombatLockdown and InCombatLockdown() then
    local waiter = CreateFrame("Frame")
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    waiter:SetScript("OnEvent", function(self)
      self:UnregisterAllEvents()
      if ToggleCharacter then ToggleCharacter("PaperDollFrame") end
      C_Timer.After(0, function()
        ns.char_AnchorToPanel()
        if ns.dock_StackRelayout then ns.dock_StackRelayout() end
      end)
    end)
    return
  end
  if ToggleCharacter then ToggleCharacter("PaperDollFrame") end
  C_Timer.After(0, function()
    ns.char_AnchorToPanel()
    if ns.dock_StackRelayout then ns.dock_StackRelayout() end
  end)
end

-- hooks
do
  local p = Panel()
  if p then
    p:HookScript("OnShow", function()
      if Char() and Char():IsShown() then
        ns.char_AnchorToPanel()
        C_Timer.After(0, function()
          reinforce()
          if ns.dock_StackRelayout then ns.dock_StackRelayout() end
        end)
      end
    end)
    p:HookScript("OnHide", function()
      if Char() and Char():IsShown() then ns.char_RestoreState() end
    end)
  end
end

local function hookChar()
  local cf = Char(); if not cf or cf.__hkd_char_hooked then return end
  cf.__hkd_char_hooked = true

  cf:HookScript("OnShow", function()
    local p = Panel()
    if p and p:IsShown() then
      ns.char_AnchorToPanel()
      C_Timer.After(0, function()
        reinforce()
        if ns.dock_StackRelayout then ns.dock_StackRelayout() end
      end)
    end
    hookCharClicks()
  end)

  cf:HookScript("OnHide", function()
    local p = Panel()
    if p and p:IsShown() then
      if IsInteractingWith_Char() and not IsOnCloseButton_Char() then
        if not InCombatLockdown or not InCombatLockdown() then
          if ToggleCharacter then ToggleCharacter("PaperDollFrame") end
          C_Timer.After(0, function()
            ns.char_AnchorToPanel()
            if _G.UpdateUIPanelPositions then _G.UpdateUIPanelPositions() end
            if ns.dock_StackRelayout then ns.dock_StackRelayout() end
          end)
        end
        return
      end
      -- mantém os outros estáveis
      if _G.FriendsFrame and _G.FriendsFrame:IsShown() and ns.social_AnchorToPanel then
        ns.social_AnchorToPanel()
      end
      if _G.PVEFrame and _G.PVEFrame:IsShown() and ns.mplus_AnchorToPanel then
        ns.mplus_AnchorToPanel()
      end
      if ns.dock_StackRelayout then ns.dock_StackRelayout() end
      return
    end
    ns.char_RestoreState()
  end)
end
hookChar(); if C_Timer and C_Timer.After then C_Timer.After(0.05, hookChar); C_Timer.After(0.25, hookChar) end

if _G.UpdateUIPanelPositions then
  hooksecurefunc("UpdateUIPanelPositions", function()
    reinforce()
    if ns.dock_StackRelayout then ns.dock_StackRelayout() end
  end)
end
if _G.UIParent_ManageFramePositions then
  hooksecurefunc("UIParent_ManageFramePositions", function()
    reinforce()
    if ns.dock_StackRelayout then ns.dock_StackRelayout() end
  end)
end

do
  local fr = Social()
  if fr and not fr.__hkd_char_sidehook then
    fr.__hkd_char_sidehook = true
    fr:HookScript("OnHide", function()
      local p = Panel()
      if p and p:IsShown() and Char() and Char():IsShown() then
        ns.char_AnchorToPanel()
        if ns.dock_StackRelayout then ns.dock_StackRelayout() end
      end
    end)
  end
end

 end
-- END 47_character_anchor.lua

-- BEGIN 48_mplus_anchor.lua
 do
-- 48_mplus_anchor.lua
local _, ns = ...
local CFG = ns.CFG or {}

local function Panel()      return ns.frames and ns.frames.panel end
local function MP_Root()    return _G.PVEFrame end          -- raiz UIParent-managed
local function MP_Content() return _G.ChallengesFrame end   -- conteúdo Mythic+

-- ping em cliques — **apenas LeftButton**
local function hookMPlusClicks()
  local root, cont = MP_Root(), MP_Content()
  local function ping(_, button)
    if button ~= "LeftButton" then return end
    if ns.PingDockInteraction then ns.PingDockInteraction() end
  end

  if root and not root.__hkd_clicks then
    root.__hkd_clicks = true
    if root.HookScript then root:HookScript("OnMouseDown", ping) end
    for i = 1, 20 do
      local t = _G["PVEFrameTab"..i]
      if t and t.HookScript then t:HookScript("OnMouseDown", ping) end
    end
  end
  if cont and not cont.__hkd_clicks then
    cont.__hkd_clicks = true
    if cont.HookScript then cont:HookScript("OnMouseDown", ping) end
  end
end

-- snapshot
local saved = { points=nil, strata=nil, parent=nil, wasIgnoring=nil, userPlaced=nil }
local function canUserPlace(f)
  return f and ((f.IsMovable and f:IsMovable()) or (f.IsResizable and f:IsResizable()))
end
local function saveState()
  local f = MP_Root(); if not f then return end
  saved.points = {}
  for i = 1, f:GetNumPoints() do
    local p, rel, rp, x, y = f:GetPoint(i)
    saved.points[i] = { p, rel, rp, x, y }
  end
  saved.strata = f:GetFrameStrata()
  saved.parent = f:GetParent()
  if f.IsIgnoringFramePositionManager then
    saved.wasIgnoring = f:IsIgnoringFramePositionManager()
  end
  if f.IsUserPlaced and canUserPlace(f) then
    saved.userPlaced = f:IsUserPlaced()
  else
    saved.userPlaced = nil
  end
end
local function restoreState()
  local f = MP_Root(); if not f then return end
  if f.SetIgnoreFramePositionManager then f:SetIgnoreFramePositionManager(false) end
  if f.SetUserPlaced and saved.userPlaced ~= nil and canUserPlace(f) then
    f:SetUserPlaced(saved.userPlaced)
  end
  f:ClearAllPoints()
  if saved.points and #saved.points > 0 then
    for _, pt in ipairs(saved.points) do f:SetPoint(unpack(pt)) end
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
  if saved.strata then f:SetFrameStrata(saved.strata) end
  if saved.parent then f:SetParent(saved.parent) end
  if _G.UIParent_ManageFramePositions then _G.UIParent_ManageFramePositions() end
  if _G.UpdateUIPanelPositions then _G.UpdateUIPanelPositions() end
  saved.points, saved.strata, saved.parent, saved.wasIgnoring, saved.userPlaced = nil,nil,nil,nil,nil
end

-- ancoragem base (topo ao lado do dock; empilhamento é do 44_)
local function applyAnchor()
  local p, f = Panel(), MP_Root()
  if not (p and p:IsShown() and f and f:IsShown()) then return end
  f:ClearAllPoints()
  local GAP = (CFG and CFG.SOCIAL_GAP) or 12
  f:SetPoint("TOPLEFT", p, "TOPRIGHT", GAP, 0)
  local s = p:GetFrameStrata() or "HIGH"
  if s == "BACKGROUND" or s == "LOW" or s == "MEDIUM" then s = "HIGH" end
  f:SetFrameStrata(s)
  f:SetToplevel(true)
end

function ns.mplus_AnchorToPanel()
  local p, f = Panel(), MP_Root()
  if not (p and p:IsShown() and f and f:IsShown()) then return end
  if not saved.points then saveState() end
  if f.SetIgnoreFramePositionManager then f:SetIgnoreFramePositionManager(true) end
  if f.SetUserPlaced and canUserPlace(f) then f:SetUserPlaced(true) end
  f.__hkd_mplus_docked = true
  applyAnchor()
  if ns.dock_StackRelayout then ns.dock_StackRelayout() end
end

function ns.mplus_RestoreState()
  local f = MP_Root()
  if f then f.__hkd_mplus_docked = false end
  restoreState()
end

-- abrir via badge
function ns.mplus_ToggleAndDock()
  if _G.PVEFrame_ToggleFrame then
    _G.PVEFrame_ToggleFrame("ChallengesFrame") -- alterna direto no M+
  elseif _G.TogglePVEFrame then
    _G.TogglePVEFrame()
  end
  C_Timer.After(0, function()
    if Panel() and Panel():IsShown() then
      ns.mplus_AnchorToPanel()
      hookMPlusClicks()
    end
  end)
end

-- hooks
local function hookOnce()
  local f = MP_Root(); if not f or f.__hkd_mplus_hooked then return end
  f.__hkd_mplus_hooked = true

  f:HookScript("OnShow", function()
    if Panel() and Panel():IsShown() then
      ns.mplus_AnchorToPanel()
      if ns.dock_StackRelayout then ns.dock_StackRelayout() end
    end
    hookMPlusClicks()
  end)

  f:HookScript("OnHide", function()
    local p = Panel()
    if p and p:IsShown() then
      f.__hkd_mplus_docked = false
      if ns.dock_StackRelayout then ns.dock_StackRelayout() end
      return
    end
    ns.mplus_RestoreState()
  end)
end
hookOnce(); if C_Timer and C_Timer.After then C_Timer.After(0.05, hookOnce); C_Timer.After(0.25, hookOnce) end

-- anti-“dança”
local function reinforce()
  local p, f = Panel(), MP_Root()
  if f and f.__hkd_mplus_docked and p and p:IsShown() and f:IsShown() then
    applyAnchor()
    if ns.dock_StackRelayout then ns.dock_StackRelayout() end
  end
end
if _G.UpdateUIPanelPositions then hooksecurefunc("UpdateUIPanelPositions", reinforce) end
if _G.UIParent_ManageFramePositions then hooksecurefunc("UIParent_ManageFramePositions", reinforce) end

-- quando Char/Friends mexerem, recalcula a pilha
if _G.CharacterFrame then
  _G.CharacterFrame:HookScript("OnShow", function() C_Timer.After(0, function()
    if ns.dock_StackRelayout then ns.dock_StackRelayout() end end) end)
  _G.CharacterFrame:HookScript("OnHide", function() C_Timer.After(0, function()
    if ns.dock_StackRelayout then ns.dock_StackRelayout() end end) end)
end
if _G.FriendsFrame then
  _G.FriendsFrame:HookScript("OnShow", function() C_Timer.After(0, function()
    if ns.dock_StackRelayout then ns.dock_StackRelayout() end end) end)
  _G.FriendsFrame:HookScript("OnHide", function() C_Timer.After(0, function()
    if ns.dock_StackRelayout then ns.dock_StackRelayout() end end) end)
end

 end
-- END 48_mplus_anchor.lua
