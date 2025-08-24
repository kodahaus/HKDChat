-- 90_hooks.lua
local _, ns = ...

-- EditBox: Enter alterna e refoco ao perder foco
if not ns.once then ns.once = {} end
if not ns.once.EditHooks then
  ns.once.EditHooks = true
  if ns.EDIT and ns.EDIT.HookScript then
    ns.EDIT:HookScript("OnEnterPressed", function()
      ns.state.closeOnNextDeactivate = true
    end)
    ns.EDIT:HookScript("OnEditFocusLost", function(self)
      if ns.frames.panel and ns.frames.panel:IsShown()
         and (ns.state.mouseInside or ns.state.switchingTabs) then
        C_Timer.After(0, function()
          if ns.frames.panel:IsShown() then self:Show(); self:SetFocus() end
        end)
      end
    end)
  end
end

-- hover helpers contam como “dentro do painel”
local function watchHover(f)
  if not f or not f.HookScript then return end
  f:HookScript("OnEnter", function() ns.state.mouseInside = true end)
  f:HookScript("OnLeave", function() ns.state.mouseInside = false end)
end
if ns.frames and ns.frames.panel     then watchHover(ns.frames.panel)     end
if ns.frames and ns.frames.container then watchHover(ns.frames.container) end
if ns.frames and ns.frames.chatArea  then watchHover(ns.frames.chatArea)  end
if ns.frames and ns.frames.tabsBar   then watchHover(ns.frames.tabsBar)   end
if ns.frames and ns.frames.leftBar   then watchHover(ns.frames.leftBar)   end

-- Ativar/Desativar chat
hooksecurefunc("ChatEdit_ActivateChat", function(editBox)
  if editBox ~= ns.EDIT then return end
  ns.state.closeOnNextDeactivate = false
  ns.EDIT:Show()
  ns.showPanel()
  if ns.raiseTabsBar then C_Timer.After(0, ns.raiseTabsBar) end
end)

hooksecurefunc("ChatEdit_DeactivateChat", function(editBox)
  if editBox ~= ns.EDIT then return end

  if ns.state.hkdMenuOpen then
    C_Timer.After(0, function()
      if ns.frames.panel and ns.frames.panel:IsShown() and ns.EDIT then
        ns.EDIT:Show(); ns.EDIT:SetFocus()
      end
      if ns.raiseTabsBar then ns.raiseTabsBar() end
    end)
    return
  end

  if ns.state.closeOnNextDeactivate then
    ns.state.closeOnNextDeactivate = false
    ns.EDIT:Hide()
    ns.hidePanel()
    return
  end

  local now = GetTime() or 0
  if (now - (ns.state.panelClickAt or 0)) <= 0.30 or ns.state.switchingTabs then
    C_Timer.After(0, function()
      if ns.frames.panel and ns.frames.panel:IsShown() and ns.EDIT then
        ns.EDIT:Show(); ns.EDIT:SetFocus()
      end
      if ns.raiseTabsBar then ns.raiseTabsBar() end
    end)
    return
  end

  if ns.frames.panel and ns.frames.panel:IsShown() and ns.state.mouseInside then
    C_Timer.After(0, function()
      if ns.frames.panel:IsShown() and ns.EDIT then ns.EDIT:Show(); ns.EDIT:SetFocus() end
      if ns.raiseTabsBar then ns.raiseTabsBar() end
    end)
    return
  end

  ns.EDIT:Hide()
  ns.hidePanel()
end)

-- *** Hook ÚNICO: sempre que a aba vanilla mudar, adotamos no painel. ***
hooksecurefunc("FCF_Tab_OnClick", function()
  if not ns.frames.panel or not ns.frames.panel:IsShown() then return end
  ns.state.switchingTabs = true
  C_Timer.After(0, function()
    local active = ns.getActiveChatFrame()
    ns.releaseCurrentChat()
    ns.adoptSpecificChatFrame(active)
    ns.state.switchingTabs = false
    if ns.EDIT then ns.EDIT:Show(); ns.EDIT:SetFocus() end
    if ns.raiseTabsBar then ns.raiseTabsBar() end
  end)
end)

