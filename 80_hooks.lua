-- GROUP 80_hooks: 1 file(s) merged

-- BEGIN 90_hooks.lua
 do
-- 90_hooks.lua
local _, ns = ...

-- ==== safe helpers para fechar painel sem erro durante o boot ====
local function PanelShown()
  return ns and ns.frames and ns.frames.panel and ns.frames.panel:IsShown()
end

local _ready = false
local _readyEvt = CreateFrame("Frame")
_readyEvt:RegisterEvent("PLAYER_LOGIN")
_readyEvt:SetScript("OnEvent", function() _ready = true end)

local function HidePanelSafe(force)
  -- só tenta fechar quando o jogo terminou de montar a UI e a função existe
  if not _ready then return end
  if ns and ns.hidePanel then ns.hidePanel(force) end
end
-- =================================================================

-- ===== Polyfill para mudança da API 11.0+: GetMouseFocus -> GetMouseFoci =====
local function HKD_GetMouseFocus()
  if type(GetMouseFoci) == "function" then
    local t = GetMouseFoci()
    return t and t[1] or nil
  elseif type(GetMouseFocus) == "function" then
    return GetMouseFocus()
  end
  return nil
end
-- ============================================================================

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

  -- [HKD] Se o mouse estiver sobre o painel/EDIT, mantenha aberto e refoca no próximo frame
  if ns.frames and ns.frames.panel and ns.frames.panel:IsShown() then
    local over =
      (ns.EDIT and ns.EDIT.IsMouseOver and ns.EDIT:IsMouseOver()) or
      (ns.frames.panel.IsMouseOver and ns.frames.panel:IsMouseOver()) or
      (ns.frames.container and ns.frames.container.IsMouseOver and ns.frames.container:IsMouseOver()) or
      (ns.frames.chatArea and ns.frames.chatArea.IsMouseOver and ns.frames.chatArea:IsMouseOver()) or
      (ns.frames.tabsBar and ns.frames.tabsBar.IsMouseOver and ns.frames.tabsBar:IsMouseOver())

    if over then
      ns.state.closeOnNextDeactivate = false      -- ignora “fechar no próximo deactivate”
      ns.state.panelClickAt = GetTime()           -- teu grace usual
      C_Timer.After(0, function()                 -- refoca no frame seguinte
        if ns.frames.panel and ns.frames.panel:IsShown() and ns.EDIT then
          ns.EDIT:Show(); ns.EDIT:SetFocus()
        end
        if ns.raiseTabsBar then ns.raiseTabsBar() end
      end)
      return
    end
  end


  if ns.state.closeOnNextDeactivate then
    ns.state.closeOnNextDeactivate = false
    ns.EDIT:Hide()
    HidePanelSafe()
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

  -- bloqueia fechamento se clique for em região de chat / pós-aba
  if HKDChat_ShouldCloseOnClick and not HKDChat_ShouldCloseOnClick() then
    C_Timer.After(0, function()
      if ns.frames.panel and ns.frames.panel:IsShown() and ns.EDIT then
        ns.EDIT:Show(); ns.EDIT:SetFocus()
      end
      if ns.raiseTabsBar then ns.raiseTabsBar() end
    end)
    return
  end

  ns.EDIT:Hide()
  HidePanelSafe()
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

-- [HKD] util: um frame é descendente de outro?
local function HKD_isDescendantOf(frame, root)
  while frame do
    if frame == root then return true end
    frame = frame.GetParent and frame:GetParent()
  end
  return false
end

-- [HKD] clique está em alguma região de chat?
local function HKD_isChatRegion(frame)
  if not frame then return false end
  local name = frame.GetName and frame:GetName()

  if name and (
      name:match("^ChatFrame%d+$") or
      name:match("^ChatFrame%d+Tab$") or
      name:match("^ChatFrame%d+EditBox")
    ) then
    return true
  end

  for i=1, NUM_CHAT_WINDOWS do
    local cf = _G["ChatFrame"..i]
    if cf and (frame == cf or HKD_isDescendantOf(frame, cf)) then
      return true
    end
  end
  return false
end

-- [HKD] chama isso no teu handler de “click fora” ANTES de fechar:
function HKDChat_ShouldCloseOnClick()
  local focused = HKD_GetMouseFocus()  -- <<< usa polyfill
  if HKD_isChatRegion(focused) then
    return false
  end
  return true
end

if not HKD_ChatTabsHooked then
  local HKD_clickGuardUntil = 0

  local function HKD_HookChatTabs()
    for i = 1, NUM_CHAT_WINDOWS do
      local tab = _G["ChatFrame"..i.."Tab"]
      if tab and not tab.HKD_Hooked then
        tab:HookScript("OnClick", function()
          HKD_clickGuardUntil = GetTime() + 0.08
        end)
        tab.HKD_Hooked = true
      end
    end
  end

  local _hkdTabsEvt = CreateFrame("Frame")
  _hkdTabsEvt:RegisterEvent("PLAYER_LOGIN")
  _hkdTabsEvt:RegisterEvent("UPDATE_CHAT_WINDOWS")
  _hkdTabsEvt:SetScript("OnEvent", HKD_HookChatTabs)

  -- utils locais (shadow-free)
  local function HKD_isDescendantOf(frame, root)
    while frame do
      if frame == root then return true end
      frame = frame.GetParent and frame:GetParent() or nil
    end
    return false
  end

  local function HKD_isChatRegion(frame)
    if not frame then return false end
    local name = frame.GetName and frame:GetName()
    if name and (name:match("^ChatFrame%d+$") or name:match("^ChatFrame%d+Tab$") or name:match("^ChatFrame%d+EditBox")) then
      return true
    end
    for i = 1, NUM_CHAT_WINDOWS do
      local cf = _G["ChatFrame"..i]
      if cf and (frame == cf or HKD_isDescendantOf(frame, cf)) then
        return true
      end
    end
    return false
  end

  function HKDChat_ShouldCloseOnClick()
    if GetTime() < HKD_clickGuardUntil then
      return false
    end
    local focused = HKD_GetMouseFocus()  -- <<< usa polyfill aqui também
    if HKD_isChatRegion(focused) then
      return false
    end
    return true
  end

  HKD_ChatTabsHooked = true
end

-- ================= HKD ▸ Proteção do menu do balão (compat 11.0+, sem duplicatas) =================

-- Polyfill de foco (11.0+: GetMouseFoci; antigo: GetMouseFocus)
local function HKD_GetFocus()
  if type(HKD_GetMouseFocus) == "function" then
    return HKD_GetMouseFocus()
  elseif type(GetMouseFoci) == "function" then
    local t = GetMouseFoci(); return t and t[1] or nil
  elseif type(GetMouseFocus) == "function" then
    return GetMouseFocus()
  end
  return nil
end

-- Liga/desliga “modo menu aberto”
local function HKD_MenuOpen()
  ns.state.hkdMenuOpen = true
  ns.state.menuGuardUntil = (GetTime() or 0) + 1.2   -- pequeno grace dentro do menu
end
local function HKD_MenuClosed()
  ns.state.hkdMenuOpen = false
  ns.state.menuGuardUntil = 0
end

-- Heurística nominal (antigo e novo)
local HKD_MENU_PATTERNS = { "DropDownList%d+$", "Dropdown", "DropDown", "ContextMenu", "Menu" }
local function HKD_NameLooksMenu(fr)
  local n = (fr and fr.GetName) and fr:GetName() or nil
  if not n or n == "" then return false end
  for _,pat in ipairs(HKD_MENU_PATTERNS) do
    if n:match(pat) then return true end
  end
  return false
end

-- Checa se o frame (ou ancestrais) parecem menu por nome ou estão em strata de overlay
local function HKD_IsMenuRegion(frame)
  if not frame then return false end

  -- 1) Nome do próprio frame
  if HKD_NameLooksMenu(frame) then return true end

  -- 2) Filho de algum DropDownList visível (UIDropDown legado)
  for i=1,5 do
    local ddl = _G["DropDownList"..i]
    if ddl and ddl:IsShown() then
      local f = frame
      for _=1,12 do
        if f == ddl then return true end
        f = (f and f.GetParent) and f:GetParent() or nil
        if not f then break end
      end
    end
  end

  -- 3) Sobe ancestrais: nomes “menu-ish” ou strata de overlay (pools anônimos 11.0+)
  local f = frame
  for _=1,15 do
    f = (f and f.GetParent) and f:GetParent() or nil
    if not f then break end
    if HKD_NameLooksMenu(f) then return true end
    local strata = f.GetFrameStrata and f:GetFrameStrata()
    if strata == "FULLSCREEN_DIALOG" or strata == "DIALOG" then
      return true
    end
  end

  return false
end

-- Hooks para abrir/fechar menu (todos os caminhos conhecidos)
local function HKD_HookMenuSystemsOnce()
  ns.once = ns.once or {}

  -- Chat menu clássico do balão
  if type(ChatFrame_ToggleMenu) == "function" and not ns.once.HKD_ToggleMenuHooked then
    hooksecurefunc("ChatFrame_ToggleMenu", HKD_MenuOpen)
    ns.once.HKD_ToggleMenuHooked = true
  end

  -- MenuUtil (11.0+)
  if _G.MenuUtil and not ns.once.HKD_MenuUtilHooked then
    if type(_G.MenuUtil.CreateContextMenu) == "function" then
      hooksecurefunc(_G.MenuUtil, "CreateContextMenu", HKD_MenuOpen)
    end
    if type(_G.MenuUtil.OpenMenu) == "function" then
      hooksecurefunc(_G.MenuUtil, "OpenMenu", HKD_MenuOpen)
    end
    if type(_G.MenuUtil.CloseMenu) == "function" then
      hooksecurefunc(_G.MenuUtil, "CloseMenu", HKD_MenuClosed)
    end
    ns.once.HKD_MenuUtilHooked = true
  end

  -- UIDropDown legado
  for i=1,5 do
    local ddl = _G["DropDownList"..i]
    if ddl and not ddl.HKD_Hooked then
      ddl:HookScript("OnShow", HKD_MenuOpen)
      ddl:HookScript("OnHide", HKD_MenuClosed)
      ddl.HKD_Hooked = true
    end
  end

  -- Clique no balão arma a proteção e mantém foco no edit
  local btn = _G.ChatFrameMenuButton
  if btn and not btn.HKD_MenuHooked then
    btn:HookScript("OnClick", function()
      HKD_MenuOpen()
      if ns.frames.panel and ns.frames.panel:IsShown() then
        ns.state.panelClickAt = GetTime()
        if ns.EDIT then ns.EDIT:Show(); ns.EDIT:SetFocus() end
      end
    end)
    btn.HKD_MenuHooked = true
  end
end

-- Evento para aplicar os hooks quando o chat existir
local _hkdMenuEvtHKD = CreateFrame("Frame")
_hkdMenuEvtHKD:RegisterEvent("PLAYER_LOGIN")
_hkdMenuEvtHKD:RegisterEvent("UPDATE_CHAT_WINDOWS")
_hkdMenuEvtHKD:SetScript("OnEvent", function()
  HKD_HookMenuSystemsOnce()
end)

-- Wrapper ÚNICO do guard (sem duplicar)
do
  local _prev_Should = HKDChat_ShouldCloseOnClick
  function HKDChat_ShouldCloseOnClick()
    local now = GetTime() or 0

    -- 1) Menu aberto ou grace ainda valendo → NÃO fecha
    if ns.state.hkdMenuOpen or now < (ns.state.menuGuardUntil or 0) then
      return false
    end

    -- 2) Foco/ancestral parece menu/overlay → NÃO fecha
    local focused = HKD_GetFocus()
    if HKD_IsMenuRegion(focused) then
      return false
    end

    -- 3) Fallback pro teu guard anterior (chat/tabs/debounce…)
    if _prev_Should then return _prev_Should() end
    return true
  end
end

-- ===============================================================================================

-- ========== HKD ▸ Desarma o guard do menu assim que uma opção preenche o EditBox ==========
-- Ideia: o primeiro OnTextChanged após HKD_MenuOpen() indica que um item foi escolhido (ex.: "/w ").
-- Então zeramos hkdMenuOpen/menuGuardUntil e garantimos fechar o menu (MenuUtil/DropDown) se ainda estiver aberto.

local function HKD_ForceCloseAnyMenu()
  -- tenta o MenuUtil (11.0+)
  if _G.MenuUtil and type(_G.MenuUtil.CloseMenu) == "function" then
    pcall(_G.MenuUtil.CloseMenu, _G.MenuUtil)
  end
  -- legacy DropDowns
  for i = 1, 5 do
    local ddl = _G["DropDownList"..i]
    if ddl and ddl:IsShown() and type(ddl.Hide) == "function" then
      pcall(ddl.Hide, ddl)
    end
  end
end

local function HKD_DisarmMenuGuard()
  ns.state.hkdMenuOpen = false
  ns.state.menuGuardUntil = 0
end

-- Hooka o EditBox uma vez: ao detectar texto logo após o menu abrir, desarma o guard.
local function HKD_HookEditBoxForMenuDisarm()
  if not ns.EDIT or ns.EDIT.HKD_MenuDisarmHooked then return end
  ns.EDIT:HookScript("OnTextChanged", function(self)
    -- se acabamos de abrir um menu e veio texto ("/w ", "/s ", etc.), desarma imediatamente
    if ns.state and (ns.state.hkdMenuOpen or ((GetTime() or 0) < (ns.state.menuGuardUntil or 0))) then
      HKD_DisarmMenuGuard()
      HKD_ForceCloseAnyMenu()
      -- mantém o foco, pra usuário só digitar o nick/mensagem
      if ns.frames and ns.frames.panel and ns.frames.panel:IsShown() then
        self:Show(); self:SetFocus()
      end
    end
  end)
  ns.EDIT.HKD_MenuDisarmHooked = true
end

-- aplica no login e quando as janelas de chat mudarem (garantia)
local _hkdMenuDisarmEvt = CreateFrame("Frame")
_hkdMenuDisarmEvt:RegisterEvent("PLAYER_LOGIN")
_hkdMenuDisarmEvt:RegisterEvent("UPDATE_CHAT_WINDOWS")
_hkdMenuDisarmEvt:SetScript("OnEvent", function()
  HKD_HookEditBoxForMenuDisarm()
end)
-- =========================================================================================

-- ========== HKD ▸ Enter NÃO fecha se mouse estiver no painel/EDIT ==========
-- Ideia: se o mouse está sobre o EditBox ou qualquer área do painel quando você aperta Enter,
-- cancelamos o "closeOnNextDeactivate" e re-focamos o ns.EDIT no frame seguinte.

local function HKD_AttachEnterKeepOpen()
  if not ns or not ns.EDIT or ns.EDIT.HKD_EnterKeepOpen then return end

  -- garante que o hover do EDIT conta como "dentro do painel"
  ns.EDIT:HookScript("OnEnter", function() ns.state.mouseInside = true end)
  ns.EDIT:HookScript("OnLeave", function() ns.state.mouseInside = false end)

  ns.EDIT:HookScript("OnEnterPressed", function(self)
    -- mouse em cima do edit OU já marcado como "dentro do painel"?
    local overEdit = self.IsMouseOver and self:IsMouseOver()  -- Frame:IsMouseOver docs. :contentReference[oaicite:1]{index=1}
    local panelShown = ns.frames and ns.frames.panel and ns.frames.panel:IsShown()

    if panelShown and (overEdit or ns.state.mouseInside) then
      -- NÃO feche no próximo deactivate
      ns.state.closeOnNextDeactivate = false
      -- dá a mesma janela de proteção que você já usa no Deactivate
      ns.state.panelClickAt = GetTime()

      -- re-foca no próximo frame (Enter desativa o edit por padrão)
      C_Timer.After(0, function()  -- Timer oficial. :contentReference[oaicite:2]{index=2}
        if ns.frames and ns.frames.panel and ns.frames.panel:IsShown() and ns.EDIT then
          ns.EDIT:Show(); ns.EDIT:SetFocus()
          if ns.raiseTabsBar then ns.raiseTabsBar() end
        end
      end)
    else
      -- fora do painel: mantém o comportamento atual (fechar)
      ns.state.closeOnNextDeactivate = true
    end
  end)

  ns.EDIT.HKD_EnterKeepOpen = true
end

-- aplica quando o EDIT existir (login e quando os chat windows atualizam)
local _hkdEnterEvt = CreateFrame("Frame")
_hkdEnterEvt:RegisterEvent("PLAYER_LOGIN")
_hkdEnterEvt:RegisterEvent("UPDATE_CHAT_WINDOWS")
_hkdEnterEvt:SetScript("OnEvent", HKD_AttachEnterKeepOpen)

-- foco do EditBox: se o mouse está por cima do dock/char/social, reativa
do
  local eb = ns.EDIT or _G.ChatFrame1EditBox
  if eb and eb.HookScript and not eb.__hkd_focus_guard then
    eb.__hkd_focus_guard = true
    eb:HookScript("OnEditFocusLost", function(self)
      if ns.frames and ns.frames.panel and ns.frames.panel:IsShown()
         and ns.IsPointerOverDock and ns.IsPointerOverDock() then
        C_Timer.After(0, function()
          if ns.frames.panel:IsShown() and self and self.Show and self.SetFocus then
            self:Show(); self:SetFocus()
          end
        end)
      end
    end)
  end
end

-- quando qualquer rotina chamar ChatEdit_Deactivate, a gente desfaz se estiver sobre o dock
if _G.ChatEdit_Deactivate and not ns.__hkd_deact_hooked then
  ns.__hkd_deact_hooked = true
  hooksecurefunc("ChatEdit_Deactivate", function(editBox)
    if ns.frames and ns.frames.panel and ns.frames.panel:IsShown()
       and ns.IsPointerOverDock and ns.IsPointerOverDock() then
      C_Timer.After(0, function()
        if ns.frames.panel:IsShown() and editBox and editBox.Show and editBox.SetFocus then
          editBox:Show(); editBox:SetFocus()
        end
      end)
    end
  end)
end
 end
-- END 90_hooks.lua
