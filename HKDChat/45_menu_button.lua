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
