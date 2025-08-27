-- GROUP 15_misc: 7 file(s) merged

-- BEGIN 10_utils.lua
 do
local _, ns = ...

function ns.isVoiceLabel(txt)
  if not txt or txt=="" then return false end
  local s=txt:lower(); return (s=="voice" or s=="voz")
end

function ns.isDefaultishName(i,name)
  if not name or name=="" then return true end
  local n = name:lower():gsub("%s+","")
  return n==("chatframe"..i):lower() or n==("window"..i):lower() or n=="newwindow" or n=="newtab"
end

-- *** NOVO: pega de forma robusta o frame SELECIONADO no dock ***
local function getDockSelectedFrame()
  if _G.GENERAL_CHAT_DOCK and _G.FCFDock_GetSelectedWindow then
    local f = FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
    if f and f.AddMessage then return f end
  end
  return nil
end

function ns.getActiveChatFrame()
  -- 1) selecionado no dock (mais preciso)
  local dockSel = getDockSelectedFrame()
  if dockSel then return dockSel end

  -- 2) último default que deixamos selecionado ao soltar o painel
  if ns.state and ns.state.lastDefaultSelected and ns.state.lastDefaultSelected.AddMessage then
    return ns.state.lastDefaultSelected
  end

  -- 3) variável global do UI
  if _G.SELECTED_CHAT_FRAME and _G.SELECTED_CHAT_FRAME.AddMessage then
    return _G.SELECTED_CHAT_FRAME
  end

  -- 4) edit box ativo (fallback)
  if _G.LAST_ACTIVE_CHAT_EDIT_BOX and _G.LAST_ACTIVE_CHAT_EDIT_BOX.GetParent then
    local cf=_G.LAST_ACTIVE_CHAT_EDIT_BOX:GetParent()
    if cf and cf.AddMessage then return cf end
  end

  -- 5) último recurso
  return ChatFrame1
end

 end
-- END 10_utils.lua

-- BEGIN 20_state.lua
 do
local _, ns = ...

ns.EDIT = ChatFrame1EditBox
ns.state = {
  adopted=false, guard=false, loginBlockUntil=0, currentChat=nil,
  origByFrame={}, origAlphaByIdx={}, origTexAlphaByIdx={}, texAlphaByIdx={},
  origTabShown={}, suppressedFrames={},

  -- Enter no editbox deve fechar mesmo com mouse em cima
  closeOnNextDeactivate = false,

  -- Mouse-over robusto do painel
  mouseInside = false,

  -- Guard temporário quando usuário clica para trocar de aba
  switchingTabs = false,

  -- Timestamp do último clique em qualquer área do painel (para ignorar Deactivate "fantasma")
  panelClickAt = 0,
}

function ns.snapshotOriginalsFor(f)
  if ns.state.origByFrame[f] then return end
  local o={ parent=f:GetParent(), strata=f:GetFrameStrata(), level=f:GetFrameLevel(),
            w=f:GetWidth(), h=f:GetHeight(), points={} }
  for i=1,f:GetNumPoints() do o.points[i]={f:GetPoint(i)} end
  ns.state.origByFrame[f]=o
end

function ns.restoreFrame(f)
  local o=ns.state.origByFrame[f]; if not o then return end
  f:SetParent(o.parent or UIParent); f:ClearAllPoints()
  for _,p in ipairs(o.points) do f:SetPoint(unpack(p)) end
  if o.w and o.h then f:SetSize(o.w,o.h) end
  f:SetFrameStrata(o.strata or "LOW"); f:SetFrameLevel(o.level or 1); f:Show()
end

 end
-- END 20_state.lua

-- BEGIN 35_sidebar.lua
 do
-- 35_sidebar.lua
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

ns.frames.leftBar = bar           -- nome legado usado no addon
ns.frames.sidebar = bar           -- alias novo pra evitar confusão futura

-- Fundo
local bg = bar:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(true)
bg:SetColorTexture(0,0,0,0.70)

-- Slots topo/rodapé
local topSlot    = CreateFrame("Frame", "HKDChatLeftBarTop", bar)
local bottomSlot = CreateFrame("Frame", "HKDChatLeftBarBottom", bar)
local base = (CFG.LEFTBAR_W - 2*CFG.LEFTBAR_PAD)
topSlot:SetPoint("TOPLEFT",     bar, "TOPLEFT",  CFG.LEFTBAR_PAD, -CFG.LEFTBAR_PAD)
topSlot:SetPoint("TOPRIGHT",    bar, "TOPRIGHT", -CFG.LEFTBAR_PAD, -CFG.LEFTBAR_PAD)
topSlot:SetHeight( math.ceil(base * (CFG.SCALE_SOCIAL   or 1)) + 4 )
bottomSlot:SetPoint("BOTTOMLEFT",  bar, "BOTTOMLEFT",  CFG.LEFTBAR_PAD, CFG.LEFTBAR_PAD)
bottomSlot:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -CFG.LEFTBAR_PAD, CFG.LEFTBAR_PAD)
bottomSlot:SetHeight(math.ceil(base * (CFG.SCALE_CHATMENU or 1)) + 4)

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

-- ancora padrão no slot superior
local function AnchorSocialBtn()
  local btn = ns.frames and ns.frames.socialBtn
  if not (btn and topSlot) then return end
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", topSlot, "CENTER", 0, 0)
end

local function adoptButton(btn, slot, scale)
  if not btn or not slot then return end

  -- lembramos globalmente pra usar em keep-alive/eventos
  ns.frames.socialBtn = btn
  btn.__hkd_anchor = AnchorSocialBtn

  local function apply()
    btn.ignoreFramePositionManager = true
    if btn.SetParent       then btn:SetParent(slot) end
    if btn.ClearAllPoints  then btn:ClearAllPoints() end
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
  if C_Timer and C_Timer.After then
    C_Timer.After(0.05, apply)
    C_Timer.After(0.20, apply)
  end

  -- Keep-alive: se algum sistema ocultar o botão enquanto a sidebar está ativa, revive.
  if btn.HookScript and not btn.__hkd_keepalive then
    btn.__hkd_keepalive = true
    btn:HookScript("OnHide", function(self)
      if self.__hkd_suppress then return end            -- estamos destacando; não revive agora
      if not (ns.state and ns.state.sidebarAttached) then return end
      if not (bar and bar:IsShown()) then return end
      C_Timer.After(0, function()
        if self.__hkd_suppress then return end
        if bar and bar:IsShown() then
          if self.SetParent then self:SetParent(topSlot) end
          if self.SetFrameStrata then self:SetFrameStrata("TOOLTIP") end
          if self.SetFrameLevel then self:SetFrameLevel((bar:GetFrameLevel() or 10) + 30) end
          if self.__hkd_anchor then self:__hkd_anchor() end
          if self.Show then self:Show() end
        end
      end)
    end)
  end
end

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
  adoptButton(btn, topSlot, ns.CFG.SCALE_SOCIAL_SIDEBAR)
end
ns.attachSocial = attachSocial

-- Watchdog: quando amigos entram/saem ou social queue muda, garantimos o botão visível/ancorado
local _hkdSocialKeep = CreateFrame("Frame")
_hkdSocialKeep:RegisterEvent("FRIENDLIST_UPDATE")
_hkdSocialKeep:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
_hkdSocialKeep:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
_hkdSocialKeep:RegisterEvent("SOCIAL_QUEUE_UPDATE")
_hkdSocialKeep:SetScript("OnEvent", function()
  if not (ns.state and ns.state.sidebarAttached) then return end
  local btn = ns.frames and ns.frames.socialBtn
  if btn then
    -- reaplica parent/strata/anchor e mostra
    if btn.SetParent then btn:SetParent(topSlot) end
    if btn.SetFrameStrata then btn:SetFrameStrata("TOOLTIP") end
    if btn.SetFrameLevel then btn:SetFrameLevel((bar:GetFrameLevel() or 10) + 30) end
    if btn.__hkd_anchor then btn:__hkd_anchor() end
    if btn.Show then btn:Show() end
  else
    -- se perdemos a referência, tenta reapegar do sistema
    local fresh = getSocialButton()
    if fresh then
      adoptButton(fresh, topSlot, ns.CFG.SCALE_SOCIAL_SIDEBAR)
    end
  end
end)

function ns.ensureSocialOnDefault()
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

  -- suprime keep-alive enquanto reposiciona de volta pro default
  btn.__hkd_suppress = true

  if btn.SetIgnoreFramePositionManager then btn:SetIgnoreFramePositionManager(false) end
  btn.ignoreFramePositionManager = nil
  btn:SetParent(UIParent)
  btn:ClearAllPoints()

  local dock = _G.GeneralDockManager
  local tab1 = _G.ChatFrame1Tab
  local cf1  = _G.ChatFrame1 or UIParent

  if dock then
    btn:SetPoint("BOTTOMLEFT", dock, "TOPLEFT", 0, 6)
  elseif tab1 then
    btn:SetPoint("BOTTOMLEFT", tab1, "TOPLEFT", -2, 6)
  else
    btn:SetPoint("TOPLEFT", cf1, "TOPLEFT", 0, 18)
  end

  if btn.EnableMouse then btn:EnableMouse(true) end
  if btn.SetFrameStrata then btn:SetFrameStrata("HIGH") end
  if btn.Show then btn:Show() end

  if btn.HookScript and not btn.__hkd_default_guard then
    btn.__hkd_default_guard = true
    btn:HookScript("OnHide", function(self)
      if ns.frames and ns.frames.panel and ns.frames.panel:IsShown() then
        -- se o painel está aberto, deixamos o keep-alive da sidebar cuidar
        return
      end
      C_Timer.After(0, function()
        if ns.frames and ns.frames.panel and ns.frames.panel:IsShown() then
          return
        end
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
      end)
    end)
  end

  local defaultScale = (orig.Friends and orig.Friends.scale)
                    or (ns.CFG and ns.CFG.SCALE_SOCIAL_DEFAULT)
                    or 1
  if btn.SetScale then btn:SetScale(defaultScale) end

  local nt = btn.GetNormalTexture and btn:GetNormalTexture()
  if nt and nt.ClearAllPoints then nt:ClearAllPoints(); nt:SetPoint("CENTER") end
  local pt = btn.GetPushedTexture and btn:GetPushedTexture()
  if pt and pt.ClearAllPoints then pt:ClearAllPoints(); pt:SetPoint("CENTER") end

  -- libera supressão depois que tudo “assenta”
  C_Timer.After(0.2, function() if btn then btn.__hkd_suppress = nil end end)
end

-- API
function ns.sidebarAttach()
  if not ns.frames or not ns.frames.panel then return end
  if ns.topInfoBar_Ensure then ns.topInfoBar_Ensure() end

  local panel = ns.frames.panel
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT",    panel, "TOPLEFT",  CFG.EDGE_PADDING, -CFG.EDGE_PADDING)
  bar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", CFG.EDGE_PADDING,  CFG.EDGE_PADDING)
  bar:SetWidth(CFG.LEFTBAR_W)
  bar:SetFrameLevel(panel:GetFrameLevel() + CFG.LEFTBAR_LEVEL_BONUS)
  bar:Show()

  ns.state.sidebarAttached = true
  attachSocial()

  if ns.layoutChatArea  then ns.layoutChatArea(ns.state.currentChat or ChatFrame1) end
  if ns.positionEditBox then ns.positionEditBox() end
end

function ns.sidebarDetach()
  bar:Hide()
  ns.state.sidebarAttached = false

  -- não deixe o keep-alive reviver enquanto voltamos pro default
  local btn = ns.frames and ns.frames.socialBtn
  if btn then btn.__hkd_suppress = true end

  if ns.ensureSocialOnDefault then ns.ensureSocialOnDefault() end
  if ns.topInfoBar_Hide then ns.topInfoBar_Hide() end

  if ns.ensureSocialOnDefault then
    C_Timer.After(0, ns.ensureSocialOnDefault)
  end

  if ns.layoutChatArea then
    ns.layoutChatArea(ns.state.currentChat or ChatFrame1)
  end
  if ns.positionEditBox then ns.positionEditBox() end

  -- libera supressão após destacar
  C_Timer.After(0.3, function()
    local b = ns.frames and ns.frames.socialBtn
    if b then b.__hkd_suppress = nil end
  end)
end

 end
-- END 35_sidebar.lua

-- BEGIN 36_topbar.lua
 do
-- 36_topbar.lua
local _, ns = ...
local CFG = ns.CFG

-- ===== Config base (1x); o scale vem de CFG.TOPBAR_FONT_SCALE =====
local TOPBAR_H        = 30
local LEFT_GAP        = 0
local BOX_H_BASE      = 20
local GAP_X_BASE      = 6
local PAD_X_BASE      = 6
local PAD_Y_BASE      = 2
local BORDER_FUDGE    = 6        -- constante; não escala
local NAME_MIN_BASE   = 80
local NAME_MAX_BASE   = 140
local FONT_SCALE_DEF  = 1.3
local TOP_GAP_BASE = 20

ns.frames = ns.frames or {}

-- ===== Helpers =====
local BOX_BG     = "Interface\\Tooltips\\UI-Tooltip-Background"
local BOX_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
local function px(n) return math.floor(n + 0.5) end

local function MakeBox(parent, height)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetHeight(height)
  f:SetBackdrop({
    bgFile = BOX_BG, edgeFile = BOX_BORDER,
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  f:SetBackdropColor(0, 0, 0, 0.70)
  f:SetBackdropBorderColor(1, 1, 1, 0.12)

  local fs = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  fs:SetJustifyH("CENTER"); fs:SetJustifyV("MIDDLE")
  fs:SetWordWrap(false); fs:SetMaxLines(1)
  f.text = fs

  local path, size, flags = fs:GetFont()
  f._fontBase = { path = path, size = size or 12, flags = flags }
  f._padX_base, f._padY_base = PAD_X_BASE, PAD_Y_BASE
  return f
end

local function MakeDiamond(parent, size)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(size, size)

  local border = holder:CreateTexture(nil, "ARTWORK")
  border:SetAllPoints()
  border:SetTexture("Interface\\Buttons\\WHITE8X8")
  border:SetVertexColor(1,1,1,0.12)
  border:SetRotation(math.pi/4)

  local inner = holder:CreateTexture(nil, "ARTWORK")
  local inset = px(size * 0.14)
  inner:SetPoint("TOPLEFT", holder, "TOPLEFT", inset, -inset)
  inner:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -inset, inset)
  inner:SetTexture("Interface\\Buttons\\WHITE8X8")
  inner:SetVertexColor(0,0,0,0.70)
  inner:SetRotation(math.pi/4)

  local fs = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("CENTER")
  fs:SetWordWrap(false); fs:SetMaxLines(1)
  holder.text = fs

  local p, s, fl = fs:GetFont()
  holder._fontBase = { path = p, size = s or 12, flags = fl }
  return holder
end

local function colorNameByClass(s)
  local _, class = UnitClass("player")
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if not c then return s end
  return string.format("|cff%02x%02x%02x%s|r", c.r*255, c.g*255, c.b*255, s)
end

-- ===== Fallbacks de strings da Blizzard (alguns builds não carregam todas) =====
local STR_LOOT_SPEC_TITLE = _G.LOOT_SPECIALIZATION or "Loot Specialization"
local STR_LOOT_CURR_FMT   = _G.GAMETOOLTIP_LOOT_CURRENT_SPEC or "Current Specialization ( %s )"
local STR_UNKNOWN         = _G.UNKNOWN or "Unknown"


-- spec helpers (atuais)
local function getCurrentSpecName()
  local idx = GetSpecialization and GetSpecialization()
  if not idx then return nil end
  local _, specName = GetSpecializationInfo(idx)
  return specName
end

-- ===== Loot Spec helpers =====
local function getLootSpecID()
  return (GetLootSpecialization and GetLootSpecialization()) or 0
end

local function getLootSpecDisplayName()
  local id = getLootSpecID()
  if id == 0 then
    -- "Default" => spec atual
    return getCurrentSpecName() or STR_UNKNOWN
  end
  local name = select(2, GetSpecializationInfoByID and GetSpecializationInfoByID(id))
  if name then return name end
  -- fallback: loop specs do player
  local n = GetNumSpecializations and GetNumSpecializations() or 0
  for i=1,n do
    local sid, nm = GetSpecializationInfo(i)
    if sid == id then return nm end
  end
  return STR_UNKNOWN
end

-- ===== RIO helpers =====
local function norm01(x)
  if not x then return nil end
  if x > 1 then x = x / 255 end
  if x < 0 then x = 0 end
  if x > 1 then x = 1 end
  return x
end

local function getRIOColorRGB(score)
  if RaiderIO and RaiderIO.GetScoreColor then
    local r,g,b = RaiderIO.GetScoreColor(score)
    r, g, b = norm01(r), norm01(g), norm01(b)
    if r and g and b and not (r==1 and g==1 and b==1) then
      return r, g, b, "rio"
    end
  end
  if C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor then
    local col = C_ChallengeMode.GetDungeonScoreRarityColor(score)
    if col and col.r and col.g and col.b then
      return col.r, col.g, col.b, "blizz"
    end
  end
  return 1,1,1,"white"
end

-- Fonte
local function ApplyFontScaleToFS(owner, scale)
  if not owner then return end
  local list = {}
  if owner.text  then table.insert(list, owner.text)  end
  if owner.label then table.insert(list, owner.label) end
  if owner.num   then table.insert(list, owner.num)   end
  if owner._fontBase then
    local b = owner._fontBase
    for _,fs in ipairs(list) do
      local sz = math.max(6, (b.size or 12) * scale)
      fs:SetFont(b.path, sz, b.flags)
    end
  end
end

-- Padding dinâmico
local function ApplyPadding(box, padX, padY)
  box._padX, box._padY = padX, padY
  if box.label and box.num and (box.label:IsShown() or box.num:IsShown()) then
    box.label:ClearAllPoints()
    box.label:SetPoint("LEFT", box, "LEFT", padX, 0)
    box.num:ClearAllPoints()
    box.num:SetPoint("LEFT", box.label, "RIGHT", px(padX > 0 and 2 or 0), 0)
    box.num:SetPoint("RIGHT", box, "RIGHT", -padX, 0)
    if box.text then box.text:Hide() end
  else
    local fs = box.text
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", box, "TOPLEFT", padX, -padY)
    fs:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -padX, padY)
    if box.text then box.text:Show() end
  end
end

-- Medições
local function measureFSWidth(fs)
  if not fs then return 0 end
  local w = (fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth())
         or (fs.GetStringWidth and fs:GetStringWidth())
         or 0
  return px(w)
end

local function measureBoxWidth(box, border_fudge)
  if not box then return 0 end
  local padX = box._padX or 0
  if box.label and box.num and (box.label:IsShown() or box.num:IsShown()) then
    local w = (box.label:IsShown() and measureFSWidth(box.label) or 0)
            + (box.num:IsShown()   and measureFSWidth(box.num)   or 0)
    return px(w + padX*2 + (border_fudge or 0))
  elseif box.text then
    local w = (box.text.GetUnboundedStringWidth and box.text:GetUnboundedStringWidth())
           or (box.text.GetStringWidth and box.text:GetStringWidth())
           or 0
    return px(w + padX*2 + (border_fudge or 0))
  end
  return 0
end

-- Elipse UTF-8-safe (só pro nameBox)
local function EllipsizeByWidth(fs, fullText, maxWidth)
  if not fs or not fullText or maxWidth <= 0 then return fullText end
  fs:SetText(fullText)
  if fs:GetStringWidth() <= maxWidth then return fullText end
  local ell, s = "…", fullText
  local function chop_utf8(str)
    local i = #str
    while i > 0 do
      local b = string.byte(str, i)
      if not b then break end
      if b < 128 or b >= 192 then return string.sub(str, 1, i - 1) end
      i = i - 1
    end
    return ""
  end
  while s ~= "" do
    s = chop_utf8(s)
    fs:SetText(s .. ell)
    if fs:GetStringWidth() <= maxWidth then return s .. ell end
  end
  return ell
end

local function measureEllipsis(fs)
  if not fs then return 8 end
  local prev = fs:GetText()
  fs:SetText("…")
  local w = (fs.GetStringWidth and fs:GetStringWidth()) or 8
  fs:SetText(prev or "")
  return px(w)
end

-- ===== Loot Spec dropdown (MenuUtil, 11.x) =====
local function SetLootSpecSafe(specID)
  local function apply()
    SetLootSpecialization(specID or 0)
    local f = ns.frames and ns.frames.topInfoBar
    if f and f.specBox and f.specBox.num then
      f.specBox.num:SetText(colorNameByClass(getLootSpecDisplayName() or "—"))
    end
  end
  if InCombatLockdown and InCombatLockdown() then
    local waiter = CreateFrame("Frame")
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    waiter:SetScript("OnEvent", function(self)
      self:UnregisterAllEvents()
      apply()
    end)
  else
    apply()
  end
end

local function showLootMenu(owner)
  local MU = _G.MenuUtil
  local title = STR_LOOT_SPEC_TITLE
  local fmt   = STR_LOOT_CURR_FMT

  if MU and type(MU.CreateContextMenu) == "function" then
    MU.CreateContextMenu(owner, function(_, root)
      root:CreateTitle(title)

      local curName = getCurrentSpecName() or STR_UNKNOWN
      local lootID  = getLootSpecID()

      root:CreateRadio(string.format(fmt, curName),
        function() return lootID == 0 end,
        function() SetLootSpecSafe(0) end)

      root:CreateDivider()

      local n = GetNumSpecializations and GetNumSpecializations() or 0
      for i = 1, n do
        local sid, nm = GetSpecializationInfo(i)
        root:CreateRadio(nm or ("Spec "..i),
          function() return lootID == sid end,
          function() SetLootSpecSafe(sid) end)
      end
    end)

  elseif MU and type(MU.OpenMenu) == "function" then
    local lootID  = getLootSpecID()
    local curName = getCurrentSpecName() or STR_UNKNOWN
    local items = {
      {
        text = string.format(fmt, curName),
        checked = (lootID == 0),
        func = function() SetLootSpecSafe(0) end,
      },
    }
    local n = GetNumSpecializations and GetNumSpecializations() or 0
    for i = 1, n do
      local sid, nm = GetSpecializationInfo(i)
      table.insert(items, {
        text    = nm or ("Spec "..i),
        checked = (lootID == sid),
        func    = function() SetLootSpecSafe(sid) end,
      })
    end
    MU.OpenMenu(owner, items)

  else
    print("|cffff5555HKDChat|r: MenuUtil indisponível — não foi possível abrir o menu de Loot Spec.")
  end
end

-- ===== criação / layout base =====
local function createOrGet()
  if ns.frames.topInfoBar then return ns.frames.topInfoBar end
  local p = ns.frames.panel
  if not p then return nil end

  local f = CreateFrame("Frame", "HKDChatTopInfoBar", p, "BackdropTemplate")
  f:SetHeight(TOPBAR_H); f:Hide(); f:SetBackdrop(nil)

  local row = CreateFrame("Frame", nil, f)
  row:SetPoint("LEFT",  f, "LEFT",  8, 0)
  row:SetPoint("RIGHT", f, "RIGHT", -8, 0)
  row:SetPoint("CENTER", f, "CENTER", 0, 0)
  row:SetHeight(BOX_H_BASE)

  local cluster = CreateFrame("Frame", nil, row)
  cluster:SetSize(10, BOX_H_BASE)

  local nameBox  = MakeBox(cluster, BOX_H_BASE)
  local lvlBadge = MakeDiamond(cluster, BOX_H_BASE)
  local specBox  = MakeBox(cluster, BOX_H_BASE)
  local rioBox   = MakeBox(cluster, BOX_H_BASE)

  -- SPEC (agora "Loot: <Spec>"): split em label + num
  specBox.label = specBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  specBox.label:SetJustifyH("LEFT"); specBox.label:SetJustifyV("MIDDLE")
  specBox.label:SetWordWrap(false); specBox.label:SetMaxLines(1)
  specBox.num = specBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  specBox.num:SetJustifyH("LEFT"); specBox.num:SetJustifyV("MIDDLE")
  specBox.num:SetWordWrap(false); specBox.num:SetMaxLines(1)

  specBox:EnableMouse(true)
  specBox:SetScript("OnMouseUp", function(self, btn)
    if btn == "LeftButton" then
      showLootMenu(self)
    end
  end)

  -- RIO: split label + número
  rioBox.label = rioBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  rioBox.label:SetJustifyH("LEFT"); rioBox.label:SetJustifyV("MIDDLE")
  rioBox.label:SetWordWrap(false); rioBox.label:SetMaxLines(1)

  rioBox.num = rioBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  rioBox.num:SetJustifyH("LEFT"); rioBox.num:SetJustifyV("MIDDLE")
  rioBox.num:SetWordWrap(false); rioBox.num:SetMaxLines(1)

  -- clique no badge de M+ abre/ancora ChallengesFrame
  rioBox:EnableMouse(true)
  rioBox:SetScript("OnMouseUp", function()
    if ns.mplus_ToggleAndDock then ns.mplus_ToggleAndDock() end
  end)

  -- CLICK: abrir/dock do Character
  nameBox:EnableMouse(true)
  nameBox:SetScript("OnMouseUp", function()
    if ns.char_ToggleAndDock then ns.char_ToggleAndDock() end
  end)
  lvlBadge:EnableMouse(true)
  lvlBadge:SetScript("OnMouseUp", function()
    if ns.char_ToggleAndDock then ns.char_ToggleAndDock() end
  end)

  ns.frames.topInfoBar = f
  f.row      = row
  f.cluster  = cluster
  f.nameBox  = nameBox
  f.lvlBadge = lvlBadge
  f.specBox  = specBox
  f.rioBox   = rioBox
  return f
end

local function layoutTopbar(f)
  if not f or not ns.frames.panel then return end
  local panel = ns.frames.panel
  local leftX = CFG.EDGE_PADDING + (CFG.LEFTBAR_W or 0) + LEFT_GAP
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT",  panel, "TOPLEFT",  leftX, -CFG.EDGE_PADDING)
  f:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -CFG.EDGE_PADDING, -CFG.EDGE_PADDING)
end

-- ===== preencher + layout =====
local function updateTopbarBadges()
  local f = ns.frames.topInfoBar; if not f then return end

  local S = (CFG and CFG.TOPBAR_FONT_SCALE) or FONT_SCALE_DEF
  if S <= 0 then S = 1 end

  -- dimensões escaladas (BORDER_FUDGE não escala)
  local BOX_H  = px(BOX_H_BASE  * S)
  local GAP_X  = px(GAP_X_BASE  * S)
  local PAD_X  = px(PAD_X_BASE  * S)
  local PAD_Y  = px(PAD_Y_BASE  * S)
  local NMIN   = px(NAME_MIN_BASE * S)
  local NMAX   = px(NAME_MAX_BASE * S)
  local TOP_GAP = px(((CFG and CFG.TOPBAR_TOP_GAP) or TOP_GAP_BASE) * S)

  f.row:SetHeight(BOX_H)
  f.cluster:SetHeight(BOX_H)
  f.nameBox:SetHeight(BOX_H)
  f.specBox:SetHeight(BOX_H)
  f.rioBox:SetHeight(BOX_H)
  f.lvlBadge:SetSize(BOX_H, BOX_H)

  -- fontes
  ApplyFontScaleToFS(f.nameBox,  S)
  ApplyFontScaleToFS(f.specBox,  S)
  ApplyFontScaleToFS(f.rioBox,   S)
  ApplyFontScaleToFS(f.lvlBadge, S)

  -- padding
  ApplyPadding(f.nameBox, PAD_X, PAD_Y)
  ApplyPadding(f.specBox, PAD_X, PAD_Y)
  ApplyPadding(f.rioBox,  PAD_X, PAD_Y)

  -- textos
  local titled = UnitPVPName("player") or UnitName("player") or ""
  f.nameBox.text:SetText(titled)

  local lvl = UnitLevel("player") or ""
  f.lvlBadge.text:SetText(tostring(lvl))

  -- === LOOT SPEC ===
  f.specBox.label:SetText("Loot: ")
  f.specBox.label:SetTextColor(1,1,1,1) -- label estático
  f.specBox.num:SetText(colorNameByClass(getLootSpecDisplayName() or "—")) -- spec colorida
  f.specBox.num:SetTextColor(1,1,1,1)

  -- RIO
  local score, r, g, b = nil, nil, nil, nil
  do
    if RaiderIO and RaiderIO.GetProfile then
      local prof = RaiderIO.GetProfile("player")
      if prof and prof.mythicKeystoneProfile and prof.mythicKeystoneProfile.hasRenderableData then
        score = tonumber(prof.mythicKeystoneProfile.currentScore)
      end
    end
    if not score and C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore then
      score = C_ChallengeMode.GetOverallDungeonScore()
    end
    if score then r, g, b = getRIOColorRGB(score) end
  end

  local hasRIO = (score ~= nil)

  if hasRIO then
    f.rioBox.label:SetText("M+ Score: ")
    f.rioBox.label:SetTextColor(1,1,1,1)
    f.rioBox.num:SetText(tostring(score))
    f.rioBox.num:SetTextColor(r or 1, g or 1, b or 1, 1)
    f.rioBox:Show()
  else
    f.rioBox:Hide()
  end

  -- medir larguras
  local available    = f:GetWidth()
  local lvlW         = BOX_H
  local specW        = measureBoxWidth(f.specBox, BORDER_FUDGE)
  local rioW         = hasRIO and measureBoxWidth(f.rioBox, BORDER_FUDGE) or 0
  local nameW_text   = measureBoxWidth(f.nameBox, BORDER_FUDGE)
  local othersW      = GAP_X + lvlW + GAP_X + specW + (hasRIO and (GAP_X + rioW) or 0)

  -- nome pode crescer até o cap real
  local allowByPanel = math.max(NMIN, available - othersW)
  local nameCap      = math.max(NMIN, math.min(NMAX, allowByPanel))
  local nameW_box    = math.min(math.max(nameW_text, NMIN), nameCap)
  local totalW       = nameW_box + othersW

  -- elipse se precisar
  local shown = titled
  if totalW > available then
    local ellW   = measureEllipsis(f.nameBox.text)
    local padX   = f.nameBox._padX or 0
    local nameMinPhysical = px(ellW + padX*2 + BORDER_FUDGE)
    local maxNameByWidth  = math.max(nameMinPhysical, available - othersW)

    nameW_box = math.max(nameMinPhysical, math.min(nameW_box, maxNameByWidth))
    totalW    = nameW_box + othersW

    local innerTextW = math.max(0, nameW_box - padX*2 - BORDER_FUDGE)
    shown = EllipsizeByWidth(f.nameBox.text, titled, innerTextW)
  end

  -- cap de scale
  if totalW > available then
    local ellW   = measureEllipsis(f.nameBox.text)
    local padX   = f.nameBox._padX or 0
    local nameMinPhysical = px(ellW + padX*2 + BORDER_FUDGE)
    local minTotalAtS     = nameMinPhysical + othersW
    if minTotalAtS > 0 then
      local S_cap = available / minTotalAtS
      S_cap = math.max(0.7, math.min(S, S_cap))
      if math.abs(S_cap - S) > 0.001 then
        S = S_cap
        local BOX_H2  = px(BOX_H_BASE  * S)
        local GAP_X2  = px(GAP_X_BASE  * S)
        local PAD_X2  = px(PAD_X_BASE  * S)
        local PAD_Y2  = px(PAD_Y_BASE  * S)
        local NMIN2   = px(NAME_MIN_BASE * S)
        local NMAX2   = px(NAME_MAX_BASE * S)

        f.row:SetHeight(BOX_H2)
        f.cluster:SetHeight(BOX_H2)
        f.nameBox:SetHeight(BOX_H2)
        f.specBox:SetHeight(BOX_H2)
        f.rioBox:SetHeight(BOX_H2)
        f.lvlBadge:SetSize(BOX_H2, BOX_H2)

        ApplyFontScaleToFS(f.nameBox,  S)
        ApplyFontScaleToFS(f.specBox,  S)
        ApplyFontScaleToFS(f.rioBox,   S)
        ApplyFontScaleToFS(f.lvlBadge, S)

        ApplyPadding(f.nameBox, PAD_X2, PAD_Y2)
        ApplyPadding(f.specBox, PAD_X2, PAD_Y2)
        ApplyPadding(f.rioBox,  PAD_X2, PAD_Y2)

        -- re-mede
        available = f:GetWidth()
        lvlW      = BOX_H2
        specW     = measureBoxWidth(f.specBox, BORDER_FUDGE)
        rioW      = hasRIO and measureBoxWidth(f.rioBox, BORDER_FUDGE) or 0
        othersW   = GAP_X2 + lvlW + GAP_X2 + specW + (hasRIO and (GAP_X2 + rioW) or 0)

        local nameW_text2 = measureBoxWidth(f.nameBox, BORDER_FUDGE)
        local allowByPanel2 = math.max(NMIN2, available - othersW)
        local nameCap2 = math.max(NMIN2, math.min(NMAX2, allowByPanel2))
        nameW_box  = math.min(math.max(nameW_text2, NMIN2), nameCap2)
        totalW     = nameW_box + othersW

        if totalW > available then
          local ell2  = measureEllipsis(f.nameBox.text)
          local padX2 = f.nameBox._padX or 0
          local nameMinPhysical2 = px(ell2 + padX2*2 + BORDER_FUDGE)
          local maxNameByWidth2  = math.max(nameMinPhysical2, available - othersW)
          nameW_box = math.max(nameMinPhysical2, math.min(nameW_box, maxNameByWidth2))
          totalW    = nameW_box + othersW
          local innerTextW2 = math.max(0, nameW_box - padX2*2 - BORDER_FUDGE)
          shown = EllipsizeByWidth(f.nameBox.text, titled, innerTextW2)
        end

        GAP_X = GAP_X2
        TOP_GAP = px(((CFG and CFG.TOPBAR_TOP_GAP) or 6) * S)
      end
    end
  end

  -- posiciona e ancora (a partir do topo)
  f.cluster:ClearAllPoints()
  f.cluster:SetSize(totalW, px(BOX_H_BASE * S))
  f.cluster:SetPoint("TOP", f, "TOP", 0, -TOP_GAP)

  f.nameBox:ClearAllPoints()
  f.nameBox:SetPoint("LEFT", f.cluster, "LEFT", 0, 0)
  f.nameBox:SetWidth(nameW_box)
  if f.nameBox.SetClipsChildren then f.nameBox:SetClipsChildren(true) end

  f.lvlBadge:ClearAllPoints()
  f.lvlBadge:SetPoint("LEFT", f.nameBox, "RIGHT", GAP_X, 0)

  f.specBox:ClearAllPoints()
  f.specBox:SetWidth(specW)
  f.specBox:SetPoint("LEFT", f.lvlBadge, "RIGHT", GAP_X, 0)

  if f.rioBox:IsShown() then
    f.rioBox:ClearAllPoints()
    f.rioBox:SetWidth(rioW)
    f.rioBox:SetPoint("LEFT", f.specBox, "RIGHT", GAP_X, 0)
  end

  f.nameBox.text:SetText(colorNameByClass(shown))
end

-- ===== API pública =====
function ns.topInfoBar_Ensure()
  local f = (ns.frames and ns.frames.topInfoBar) or createOrGet()
  if not f then return end
  layoutTopbar(f)
  C_Timer.After(0, function()
    if ns.frames.topInfoBar == f then
      updateTopbarBadges()
      f:Show()
    end
  end)
  f:SetScript("OnSizeChanged", function()
    if f:IsShown() then updateTopbarBadges() end
  end)
end

function ns.topInfoBar_Hide()
  if ns.frames.topInfoBar then ns.frames.topInfoBar:Hide() end
end

-- eventos
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("KNOWN_TITLES_UPDATE")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED") -- atualiza quando troca loot spec
ev:SetScript("OnEvent", function()
  local f = ns.frames and ns.frames.topInfoBar
  if f and f:IsShown() then
    updateTopbarBadges()
  end
end)

 end
-- END 36_topbar.lua

-- BEGIN 60_Loot_spec_badge.lua
 do
-- 60_loot_spec_badge.lua
local ADDON, ns = ...
local CFG = ns.CFG or {}

-- ===== helpers de spec/loot =====
local function CurrentSpecID()
  local specIndex = GetSpecialization and GetSpecialization()
  if not specIndex then return nil end
  local id = select(1, GetSpecializationInfo, specIndex)
  if type(GetSpecializationInfo) == "function" then
    local specID = select(1, GetSpecializationInfo(specIndex))
    return specID
  end
  -- fallback pra APIs antigas
  local classID = select(3, UnitClass("player"))
  if GetSpecializationInfoForClassID then
    return select(1, GetSpecializationInfoForClassID(classID, specIndex))
  end
  return nil
end

local function CurrentSpecName()
  local specIndex = GetSpecialization and GetSpecialization()
  if not specIndex then return UNKNOWN end
  local name = select(2, GetSpecializationInfo(specIndex))
  return name or UNKNOWN
end

local function LootSpecID()
  return (GetLootSpecialization and GetLootSpecialization()) or 0
end

local function LootSpecDisplayName()
  local id = LootSpecID()
  if id == 0 then
    -- "Default" = spec atual
    return CurrentSpecName()
  end
  local name = select(2, GetSpecializationInfoByID and GetSpecializationInfoByID(id))
  if name then return name end
  -- fallback: tenta mapear por classID/index
  local classID = select(3, UnitClass("player"))
  for i=1, GetNumSpecializations() or 0 do
    local sid, sname = GetSpecializationInfo(i)
    if sid == id then return sname end
  end
  return UNKNOWN
end

-- ===== badge UI =====
local function makeBadge(parent)
  local b = CreateFrame("Button", "HKDLootSpecBadge", parent, "UIPanelButtonTemplate")
  b:SetHeight(18)
  b:SetText("Loot: " .. (LootSpecDisplayName() or "—"))
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  -- estilinho mínimo
  if b.SetNormalFontObject then b:SetNormalFontObject(GameFontHighlightSmall) end
  return b
end

-- ===== dropdown =====
local function buildMenu()
  local menu = {}

  local curSpecName = CurrentSpecName()
  local lootID      = LootSpecID()

  -- 1) "Current Specialization (X)"
  table.insert(menu, {
    text = string.format("Current Specialization ( %s )", curSpecName or UNKNOWN),
    checked = (lootID == 0),
    func = function()
      local set = function()
        SetLootSpecialization(0)
        if HKDLootSpecBadge and HKDLootSpecBadge.SetText then
          HKDLootSpecBadge:SetText("Loot: " .. (LootSpecDisplayName() or "—"))
        end
      end
      if InCombatLockdown and InCombatLockdown() then
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:SetScript("OnEvent", function(self)
          self:UnregisterAllEvents(); set()
        end)
      else
        set()
      end
    end,
  })

  -- 2) Lista de specs da classe
  local num = GetNumSpecializations and GetNumSpecializations() or 0
  for i = 1, num do
    local sid, name = GetSpecializationInfo(i)
    table.insert(menu, {
      text = name or ("Spec "..i),
      checked = (lootID == sid),
      func = function()
        local set = function()
          SetLootSpecialization(sid)
          if HKDLootSpecBadge and HKDLootSpecBadge.SetText then
            HKDLootSpecBadge:SetText("Loot: " .. (LootSpecDisplayName() or "—"))
          end
        end
        if InCombatLockdown and InCombatLockdown() then
          local f = CreateFrame("Frame")
          f:RegisterEvent("PLAYER_REGEN_ENABLED")
          f:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents(); set()
          end)
        else
          set()
        end
      end,
    })
  end

  return menu
end

local dropdown -- frame do menu pra gente poder incluir no IsPointerOverDock
local function showMenu(owner)
  if not dropdown then
    dropdown = CreateFrame("Frame", "HKDLootSpecMenu", UIParent, "UIDropDownMenuTemplate")
    -- guarda referência pro painel saber que é “área do dock”
    ns.frames = ns.frames or {}
    ns.frames.lootSpecMenu = dropdown
  end

  -- Protege o painel de fechar enquanto o menu existir
  if ns.GuardPanel then ns.GuardPanel(0.3) end
  dropdown:Hide() -- evita bug de menu reciclado
  EasyMenu(buildMenu(), dropdown, owner, 0, 0, "MENU", 2)

  -- Quando o menu sumir, solta o guard depois de um tiquinho
  dropdown:HookScript("OnHide", function()
    C_Timer.After(0.05, function()
      if ns.GuardPanel then ns.GuardPanel(0.01) end
    end)
  end)
end

-- ===== eventos para manter o texto atualizado =====
local function refreshBadge()
  if HKDLootSpecBadge and HKDLootSpecBadge.SetText then
    HKDLootSpecBadge:SetText("Loot: " .. (LootSpecDisplayName() or "—"))
  end
end

local evt = CreateFrame("Frame")
evt:RegisterEvent("PLAYER_ENTERING_WORLD")
evt:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
evt:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
evt:SetScript("OnEvent", refreshBadge)

-- ===== API pública =====
-- Call este cara no mesmo lugar onde você criava a badge antiga de "spec".
-- Ex.: ns.lootSpecBadge_Init(ns.frames.tabsBar) ou onde preferir no cabeçalho.
function ns.lootSpecBadge_Init(anchorFrame)
  local parent = anchorFrame or (ns.frames and ns.frames.tabsBar) or (ns.frames and ns.frames.container) or UIParent
  if _G.HKDLootSpecBadge then
    _G.HKDLootSpecBadge:SetParent(parent)
    _G.HKDLootSpecBadge:ClearAllPoints()
  else
    makeBadge(parent)
  end

  local b = _G.HKDLootSpecBadge
  -- posicionamento: ajusta conforme teu layout
  if b and not b.__hkd_pos then
    b.__hkd_pos = true
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
  end

  b:SetScript("OnClick", function(self, button)
    if button ~= "LeftButton" then return end
    showMenu(self)
  end)

  refreshBadge()
  return b
end

 end
-- END 60_Loot_spec_badge.lua

-- BEGIN 70_bg.lua
 do
local _, ns = ...

-- ===== Utils internos =====
local function getChatIndex(cf)
  return (cf and cf.GetID) and cf:GetID() or nil
end

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

-- ===== Snapshot de BG/alpha original =====
function ns.snapshotBgState(cf)
  local idx = getChatIndex(cf)
  if idx and ns.state.origAlphaByIdx[idx] == nil then
    ns.state.origAlphaByIdx[idx] = readWindowAlpha(idx) or 1
  end
  local bgTex = getNamedBackground(cf)
  if idx and bgTex and ns.state.origTexAlphaByIdx[idx] == nil then
    ns.state.origTexAlphaByIdx[idx] = bgTex:GetAlpha() or 1
  end
end

-- ===== Forçar transparência total =====
local function forceWindowAlphaZero(cf)
  if cf and FCF_SetWindowAlpha then
    FCF_SetWindowAlpha(cf, 0)
  elseif SetChatWindowAlpha then
    local idx = getChatIndex(cf); if idx then SetChatWindowAlpha(idx, 0) end
  end
end

local function zeroAllTextures(cf)
  local idx = getChatIndex(cf); if not idx then return end
  ns.state.texAlphaByIdx[idx] = ns.state.texAlphaByIdx[idx] or {}
  local saved = ns.state.texAlphaByIdx[idx]
  local regions = { cf:GetRegions() }
  for i=1,#regions do
    local r = regions[i]
    if r and r.GetObjectType and r:GetObjectType()=="Texture" then
      if saved[r]==nil then saved[r]=r:GetAlpha() or 1 end
      if r.SetAlpha then r:SetAlpha(0) end
    end
  end
  local bgTex = getNamedBackground(cf)
  if bgTex then
    if saved[bgTex]==nil then saved[bgTex]=bgTex:GetAlpha() or 1 end
    bgTex:SetAlpha(0)
  end
end

local function restoreAllTextures(cf)
  local idx = getChatIndex(cf); if not idx then return end
  local saved = ns.state.texAlphaByIdx[idx]; if not saved then return end
  for tex,a in pairs(saved) do if tex and tex.SetAlpha then tex:SetAlpha(a or 1) end end
  ns.state.texAlphaByIdx[idx] = nil
end

function ns.enforceTransparentBG(cf)
  -- força a janela a não ter BG (sem fade reativar)
  forceWindowAlphaZero(cf)
  zeroAllTextures(cf)
end

function ns.restoreBG(cf)
  local idx = getChatIndex(cf)
  local a   = idx and ns.state.origAlphaByIdx[idx] or nil
  if a then
    if FCF_SetWindowAlpha then
      FCF_SetWindowAlpha(cf, a)
    elseif SetChatWindowAlpha and idx then
      local v = (a <= 1) and (a*100) or a
      SetChatWindowAlpha(idx, v)
    end
  end
  local t = idx and ns.state.origTexAlphaByIdx[idx] or nil
  local bgTex = getNamedBackground(cf)
  if bgTex and t then bgTex:SetAlpha(t) end
  restoreAllTextures(cf)
end

-- ===== Anti-“BG volta quando passa o mouse” (default chat) =====
-- 1) Mantém a transparência global em 0
DEFAULT_CHATFRAME_ALPHA = 0

-- 2) Hooka eventos de mouse/fade para reforçar o alpha 0 SEMPRE
local function makeBGAlwaysZero(cf)
  if not cf or cf.__hkd_bg_patched then return end
  cf.__hkd_bg_patched = true

  -- ao ganhar/ perder mouse
  if cf.HookScript then
    cf:HookScript("OnEnter", function(self) forceWindowAlphaZero(self) end)
    cf:HookScript("OnLeave", function(self) forceWindowAlphaZero(self) end)
    cf:HookScript("OnShow",  function(self) forceWindowAlphaZero(self) end)
  end

  -- quando a Blizzard tentar fade-in no frame
  if _G.FCF_FadeInChatFrame then
    hooksecurefunc("FCF_FadeInChatFrame", function(frame)
      if frame == cf then forceWindowAlphaZero(cf) end
    end)
  end

  -- quando mudar alpha “oficialmente”
  if _G.FCF_SetWindowAlpha then
    hooksecurefunc("FCF_SetWindowAlpha", function(frame)
      if frame == cf then C_Timer.After(0, function() forceWindowAlphaZero(cf) end) end
    end)
  end

  -- reforço visual nas texturas
  C_Timer.After(0, function()
    zeroAllTextures(cf)
  end)
end

-- Exposto: chama isso pros ChatFrames do default
function ns.forcePermanentTransparency(cf)
  if not cf then return end
  forceWindowAlphaZero(cf)
  zeroAllTextures(cf)
  makeBGAlwaysZero(cf)
end

 end
-- END 70_bg.lua

-- BEGIN 99_slash.lua
 do
local _, ns = ...

SLASH_HKDCHAT_1 = "/hkdchat"
SlashCmdList.HKDCHAT = function(msg)
  msg = (msg or ""):lower()
  if msg == "reset" then
    if ns.state.adopted then ns.releaseCurrentChat() end
    if FCF_ResetChatWindows then FCF_ResetChatWindows() end
    ns.hideDefaultButtonFrames()
    ns.hideVoiceButtons()
    ns.relocateChatMenuButton()
    ns.log("chat windows resetadas.")
    return
  end
  if ns.frames.panel:IsShown() and ns.state.adopted then ns.hidePanel() else ns.showPanel() end
end

 end
-- END 99_slash.lua
