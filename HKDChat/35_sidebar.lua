local _, ns = ...
local CFG = ns.CFG

-- Barra lateral esquerda
local bar = CreateFrame("Frame", "HKDChatLeftBar", UIParent, "BackdropTemplate")
bar:SetSize(CFG.LEFTBAR_W, 100)
bar:Hide()
bar:SetClampedToScreen(true)
bar:SetFrameStrata(CFG.LEFTBAR_STRATA)
bar:SetFrameLevel((ns.frames.panel and ns.frames.panel:GetFrameLevel() or 10) + CFG.LEFTBAR_LEVEL_BONUS)
bar:SetToplevel(true)
bar:SetPropagateMouseClicks(false)
bar:EnableMouse(true)
ns.frames.leftBar = bar

-- Fundo
local bg = bar:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(true)
bg:SetColorTexture(0,0,0,0.70)

-- Slots topo/rodapé
local topSlot    = CreateFrame("Frame", "HKDChatLeftBarTop", bar)
local bottomSlot = CreateFrame("Frame", "HKDChatLeftBarBottom", bar)
topSlot:SetPoint("TOPLEFT",     bar, "TOPLEFT",  CFG.LEFTBAR_PAD, -CFG.LEFTBAR_PAD)
topSlot:SetPoint("TOPRIGHT",    bar, "TOPRIGHT", -CFG.LEFTBAR_PAD, -CFG.LEFTBAR_PAD)
topSlot:SetHeight(42)
bottomSlot:SetPoint("BOTTOMLEFT",  bar, "BOTTOMLEFT",  CFG.LEFTBAR_PAD, CFG.LEFTBAR_PAD)
bottomSlot:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -CFG.LEFTBAR_PAD, CFG.LEFTBAR_PAD)
bottomSlot:SetHeight(36)
ns.frames.leftBarTop        = topSlot
ns.frames.leftBarBottomSlot = bottomSlot

-- Login/reload: oculta
local initEv = CreateFrame("Frame")
initEv:RegisterEvent("PLAYER_ENTERING_WORLD")
initEv:SetScript("OnEvent", function()
  bar:Hide()
  ns.state = ns.state or {}
  ns.state.sidebarAttached = false
end)

-- Hover/click contam como “dentro do painel”
local function markPanelInteraction()
  ns.state.panelClickAt = GetTime() or 0
  ns.state.mouseInside  = true
  if ns.frames.panel and ns.frames.panel:IsShown() and ns.EDIT then
    ns.EDIT:Show(); ns.EDIT:SetFocus()
  end
end
local function watchHover(f)
  if not f or not f.HookScript then return end
  f:HookScript("OnEnter", function() ns.state.mouseInside = true end)
  f:HookScript("OnLeave", function() ns.state.mouseInside = false end)
  f:HookScript("OnMouseDown", markPanelInteraction)
end
watchHover(bar); watchHover(topSlot); watchHover(bottomSlot)

-- ===== Social =====
local function savePoints(f) local t={}; for i=1,f:GetNumPoints() do t[i]={f:GetPoint(i)} end; return t end
local function restorePoints(f, pts) if not pts then return end; f:ClearAllPoints(); for _,p in ipairs(pts) do f:SetPoint(unpack(p)) end end

-- pega o botão de Social (QuickJoin ou FriendsMicro)
local function getSocialButton()
  if _G.QuickJoinToastButton then
    local sub = _G.QuickJoinToastButton.FriendsButton or _G.QuickJoinToastButtonFriendsButton
    if sub and type(sub.GetObjectType)=="function" and sub:GetObjectType()=="Texture" then
      return sub:GetParent() or _G.QuickJoinToastButton
    end
    return _G.QuickJoinToastButton
  end
  if _G.FriendsMicroButton then return _G.FriendsMicroButton end
  if _G.SocialsMicroButton then return _G.SocialsMicroButton end
  return nil
end

local orig = { Friends=nil }

local function adoptButton(btn, slot, scale)
  if not btn or not slot then return end
  local function apply()
    btn.ignoreFramePositionManager = true
    if btn.ClearAllPoints then btn:ClearAllPoints() end
    if btn.SetParent       then btn:SetParent(slot) end
    if btn.SetPoint        then btn:SetPoint("CENTER", slot, "CENTER", 0, 0) end
    if scale and btn.SetScale then btn:SetScale(scale) end
    if btn.SetFrameStrata  then btn:SetFrameStrata("TOOLTIP") end
    if btn.SetFrameLevel   then btn:SetFrameLevel((bar:GetFrameLevel() or 10) + 30) end
    if btn.EnableMouse     then btn:EnableMouse(true) end
    if btn.SetHitRectInsets then btn:SetHitRectInsets(0,0,0,0) end
    if btn.Show            then btn:Show() end
    if btn.HookScript and not btn.__hkd_hover then
      btn.__hkd_hover = true
      btn:HookScript("OnMouseDown", markPanelInteraction)
      btn:HookScript("OnEnter", function() ns.state.mouseInside = true end)
      btn:HookScript("OnLeave", function() ns.state.mouseInside = false end)
    end
  end
  apply()
  -- um reforço curto é suficiente quando a barra aparece
  if C_Timer and C_Timer.After then
    C_Timer.After(0.0, apply)
  end
end

-- reancora Social na esquerda (quando a barra está aberta)
local function attachSocial()
  local btn = getSocialButton()
  if not btn then return end
  if not orig.Friends then
    orig.Friends = {
      parent = (btn.GetParent      and btn:GetParent())      or UIParent,
      points = (btn.GetNumPoints   and savePoints(btn))      or nil,
      strata = (btn.GetFrameStrata and btn:GetFrameStrata()) or "LOW",
      level  = (btn.GetFrameLevel  and btn:GetFrameLevel())  or 1,
      scale  = (btn.GetScale       and btn:GetScale())       or 1,
      shown  = (btn.IsShown        and btn:IsShown())        or true,
    }
  end
  adoptButton(btn, topSlot, ns.CFG.SCALE_SOCIAL)
end
ns.attachSocial = attachSocial

-- garantir Social no layout padrão (sem sidebar/panel) — ANCORAGEM + GUARD
function ns.ensureSocialOnDefault()
  -- resolve o botão (QuickJoinToastButton > FriendsMicroButton)
  local btn
  if _G.QuickJoinToastButton then
    local sub = _G.QuickJoinToastButton.FriendsButton or _G.QuickJoinToastButtonFriendsButton
    if sub and type(sub.GetObjectType)=="function" and sub:GetObjectType()=="Texture" then
      btn = sub:GetParent() or _G.QuickJoinToastButton
    else
      btn = _G.QuickJoinToastButton
    end
  end
  if not btn then btn = _G.FriendsMicroButton or _G.SocialsMicroButton end
  if not btn then return end

  -- volta pro gerenciamento padrão
  if btn.SetIgnoreFramePositionManager then btn:SetIgnoreFramePositionManager(false) end
  btn.ignoreFramePositionManager = nil
  btn:SetParent(UIParent)
  btn:ClearAllPoints()

  -- alvo preferencial: Dock (mesmo que não esteja :IsShown() no frame atual)
  local dock = _G.GeneralDockManager
  local tab1 = _G.ChatFrame1Tab
  local cf1  = _G.ChatFrame1 or UIParent

  if dock then
    -- posiciona logo ACIMA do dock (fica sobre as abas)
    btn:SetPoint("BOTTOMLEFT", dock, "TOPLEFT", 0, 6)
  elseif tab1 then
    -- fallback: alinha pela primeira aba (um pouco acima)
    btn:SetPoint("BOTTOMLEFT", tab1, "TOPLEFT", -2, 6)
  else
    -- último recurso: canto superior do ChatFrame1
    btn:SetPoint("TOPLEFT", cf1, "TOPLEFT", 0, 18)
  end

  if btn.EnableMouse then btn:EnableMouse(true) end
  if btn.SetFrameStrata then btn:SetFrameStrata("HIGH") end
  if btn.Show then btn:Show() end

  -- guard: se algum addon esconder enquanto o painel está FECHADO, recoloca no mesmo lugar
  if btn.HookScript and not btn.__hkd_default_guard then
    btn.__hkd_default_guard = true
    btn:HookScript("OnHide", function(self)
      if not (ns.frames and ns.frames.panel and ns.frames.panel:IsShown()) then
        C_Timer.After(0, function()
          if not (ns.frames and ns.frames.panel and ns.frames.panel:IsShown()) then
            self:SetParent(UIParent)
            self:ClearAllPoints()
            local d = _G.GeneralDockManager
            local t = _G.ChatFrame1Tab
            local c = _G.ChatFrame1 or UIParent
            if d then
              self:SetPoint("BOTTOMLEFT", d, "TOPLEFT", 0, 6)
            elseif t then
              self:SetPoint("BOTTOMLEFT", t, "TOPLEFT", -2, 6)
            else
              self:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 18)
            end
            if self.Show then self:Show() end
          end
        end)
      end
    end)
  end
end

-- API
function ns.sidebarAttach()
  if not ns.frames or not ns.frames.panel then return end
  local panel = ns.frames.panel
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT",    panel, "TOPLEFT",  CFG.EDGE_PADDING, -CFG.EDGE_PADDING)
  bar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", CFG.EDGE_PADDING,  CFG.EDGE_PADDING)
  bar:SetWidth(CFG.LEFTBAR_W)
  bar:SetFrameLevel(panel:GetFrameLevel() + CFG.LEFTBAR_LEVEL_BONUS)
  bar:Show()

  attachSocial() -- 1x basta
  if ns.layoutChatArea  then ns.layoutChatArea(ns.state.currentChat or ChatFrame1) end
  if ns.positionEditBox then ns.positionEditBox() end
  ns.state.sidebarAttached = true
end

function ns.sidebarDetach()
  bar:Hide()
  ns.state.sidebarAttached = false

  -- volta o Social pro default (1x seguro)
  if ns.ensureSocialOnDefault then ns.ensureSocialOnDefault() end

  -- reforço extra: garante posição correta no próximo frame também
  if ns.ensureSocialOnDefault then
    C_Timer.After(0, ns.ensureSocialOnDefault)
  end

  if ns.layoutChatArea then
    ns.layoutChatArea(ns.state.currentChat or ChatFrame1)
  end
  if ns.positionEditBox then ns.positionEditBox() end
end
