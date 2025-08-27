-- GROUP 40_layout: 2 file(s) merged

-- BEGIN 44_dock_layout.lua
 do
-- 44_dock_layout.lua
local _, ns = ...
local CFG = ns.CFG or {}

-- ===== util de painel/frames =====
local function getPanelFrame()
  if ns.frames then
    if ns.frames.panel and ns.frames.panel.GetObjectType then
      return ns.frames.panel
    end
    if ns.frames.container and ns.frames.container.GetObjectType then
      return ns.frames.container
    end
  end
  return nil
end

local function Char()   return _G.CharacterFrame end
local function Social() return _G.FriendsFrame end

local function ensureMPlusLoaded()
  if not _G.PVEFrame then
    if UIParentLoadAddOn then pcall(UIParentLoadOn, "Blizzard_PVEUI") end
  end
  return _G.PVEFrame
end
local function MPlus() return ensureMPlusLoaded() end

-- ordem top→down
local ORDER = { "char", "mplus", "social" }

local function frameFor(key)
  if     key == "char"   then return Char(),   "__hkd_char_docked"
  elseif key == "social" then return Social(), "__hkd_social_docked"
  elseif key == "mplus"  then return MPlus(),  "__hkd_mplus_docked"
  end
end

local function H(f) return (f and f.GetHeight and f:GetHeight()) or 0 end

-- ===== guarda & restaura layout original =====
ns._dock_orig = ns._dock_orig or setmetatable({}, { __mode = "k" })

local function saveOriginalLayout(f)
  if not f or ns._dock_orig[f] then return end
  local t = { points = {} }
  t.parent = f:GetParent()
  t.strata = f:GetFrameStrata()
  t.level  = f:GetFrameLevel()
  local n = f:GetNumPoints()
  for i = 1, n do
    local p, rel, rp, x, y = f:GetPoint(i)
    t.points[i] = { p = p, rel = rel, rp = rp, x = x, y = y }
  end
  ns._dock_orig[f] = t
end

local function restoreOriginalLayout(f)
  local t = f and ns._dock_orig[f]
  if not t then return end
  f:ClearAllPoints()
  if t.parent then f:SetParent(t.parent) end
  if t.strata then f:SetFrameStrata(t.strata) end
  if t.level  then f:SetFrameLevel(t.level) end
  if #t.points > 0 then
    for i, pt in ipairs(t.points) do
      f:SetPoint(pt.p, pt.rel, pt.rp, pt.x, pt.y)
    end
  end
end

-- ===== fudge dos tabs =====
local function BottomFudgeFor(f)
  if not f then return 0 end
  if f.__hkd_bottomFudge and type(f.__hkd_bottomFudge) == "number" then
    return f.__hkd_bottomFudge
  end
  return tonumber(CFG.DOCK_TAB_FUDGE) or 0
end

local function normalizeStrata(f, anchor)
  if not (f and anchor) then return end
  local s = anchor:GetFrameStrata() or "HIGH"
  if s == "BACKGROUND" or s == "LOW" or s == "MEDIUM" then s = "HIGH" end
  if f.SetFrameStrata then f:SetFrameStrata(s) end
  if f.SetToplevel   then f:SetToplevel(true) end
end

-- parents/anchors “alvo”
local function getInsideParent()
  local panel = getPanelFrame()
  return (ns.frames and ns.frames.container) or panel
end
local function getOutsideAnchor()
  -- quando fora, não vamos trocar parent; só usar o painel como âncora
  return (ns.frames and ns.frames.panel) or getPanelFrame()
end

-- ===== relayout do stack =====
function ns.dock_StackRelayout()
  local panel = getPanelFrame()
  if not (panel and panel.IsShown and panel:IsShown()) then return end

  local GAP       = tonumber(CFG.CHARFRAME_GAP)  or 12
  local STACK_GAP = tonumber(CFG.DOCK_STACK_GAP) or 8
  local inside    = (CFG.CHARFRAME_INSIDE == true)

  local insideParent = getInsideParent()
  local outsideAnchor = getOutsideAnchor()
  if inside and not insideParent then return end
  if (not inside) and not outsideAnchor then return end

  -- coleta frames a dockar
  local list = {}
  for _, key in ipairs(ORDER) do
    local f, flag = frameFor(key)
    if f and f.IsShown and f:IsShown() then
      -- marca dockado; mas salva layout original uma única vez
      if flag then f[flag] = true end
      saveOriginalLayout(f)
      table.insert(list, f)
    end
  end
  if #list == 0 then return end

  -- altura total
  local totalH = 0
  for i, f in ipairs(list) do
    if i > 1 then
      local prev = list[i - 1]
      totalH = totalH + STACK_GAP + BottomFudgeFor(prev)
    end
    totalH = totalH + H(f)
  end

  local anchor = inside and insideParent or outsideAnchor
  local availH = anchor:GetHeight() or totalH
  if availH <= 0 then availH = totalH end

  local topOffset = math.max(0, (availH - totalH) * 0.5)
  local y = topOffset

  for i, f in ipairs(list) do
    if i > 1 then
      local prev = list[i - 1]
      y = y + STACK_GAP + BottomFudgeFor(prev)
    end

    f:ClearAllPoints()

    if inside then
      -- DENTRO DO PAINEL: parent = insideParent (herda visibilidade do painel)
      if f:GetParent() ~= insideParent then
        f:SetParent(insideParent)
      end
      f:SetPoint("TOPLEFT", insideParent, "TOPLEFT", 0, -y)
      normalizeStrata(f, insideParent)
    else
      -- FORA DO PAINEL (à direita): mantém parent original, só ancora no painel
      -- (assim não some quando o painel some)
      local orig = ns._dock_orig[f]
      if orig and orig.parent and f:GetParent() ~= orig.parent then
        f:SetParent(orig.parent)
      end
      f:SetPoint("TOPLEFT", outsideAnchor, "TOPRIGHT", GAP, -y)
      normalizeStrata(f, outsideAnchor)
    end

    y = y + H(f)
  end
end

-- ===== reassert & hooks =====
local function reassertDockFlagsForShown()
  for _, key in ipairs(ORDER) do
    local f, flag = frameFor(key)
    if f and f.IsShown and f:IsShown() and flag then
      f[flag] = true
      saveOriginalLayout(f)
    end
  end
end

function ns.dock_ReassertAndRelayout()
  ensureMPlusLoaded()
  reassertDockFlagsForShown()
  C_Timer.After(0, function()
    if ns.dock_StackRelayout then ns.dock_StackRelayout() end
  end)
end

-- Restaurar TUDO quando o painel some (não queremos nada escondido)
local function restoreAllOnPanelHide()
  for _, key in ipairs(ORDER) do
    local f, flag = frameFor(key)
    if f then
      if flag then f[flag] = nil end
      restoreOriginalLayout(f)
    end
  end
end

-- Hook painel: OnShow = redock; OnHide = restore original
do
  local p = getPanelFrame()
  if p and not p.__hkd_dock_hooks then
    p.__hkd_dock_hooks = true

    p:HookScript("OnShow", function()
      if ns.dock_ReassertAndRelayout then ns.dock_ReassertAndRelayout() end
    end)

    p:HookScript("OnHide", function()
      restoreAllOnPanelHide()
    end)

    p:HookScript("OnSizeChanged", function()
      if ns.dock_StackRelayout then ns.dock_StackRelayout() end
    end)
  end
end

-- Hook no M+ para reancorar quando ele abre com o painel visível
local function hookMPlusOnShow()
  local m = MPlus()
  if m and not m.__hkd_onshow_hooked then
    m.__hkd_onshow_hooked = true
    m:HookScript("OnShow", function(self)
      local panel = getPanelFrame()
      if panel and panel:IsShown() then
        self.__hkd_mplus_docked = true
        saveOriginalLayout(self)
        if ns.dock_ReassertAndRelayout then ns.dock_ReassertAndRelayout() end
      end
    end)
  end
end

-- ADDON_LOADED pra quando Blizzard_PVEUI carregar depois
local fEvt = CreateFrame("Frame")
fEvt:RegisterEvent("ADDON_LOADED")
fEvt:SetScript("OnEvent", function(_, evt, addonName)
  if evt == "ADDON_LOADED" and addonName == "Blizzard_PVEUI" then
    hookMPlusOnShow()
  end
end)
hookMPlusOnShow()

 end
-- END 44_dock_layout.lua

-- BEGIN 60_layout.lua
 do
local _, ns = ...
local CFG = ns.CFG

-- área do chat (considera barra esquerda e a barra de abas à direita)
function ns.layoutChatArea(chatFrameForFont)
  local panel     = ns.frames.panel
  local container = ns.frames.container
  local chatArea  = ns.frames.chatArea
  local tabsBar   = ns.frames.tabsBar
  local leftBar   = ns.frames.leftBar

  local cf = chatFrameForFont or ns.state.currentChat or ChatFrame1
  local _, fontH = cf:GetFont()
  local GAP = math.max(CFG.MIN_TEXT_GAP, math.ceil((fontH or CFG.MIN_TEXT_GAP) * CFG.GAP_MULT))

  local leftOffset = CFG.GUTTER_LEFT +
    ((leftBar and leftBar:IsShown()) and (CFG.LEFTBAR_W + CFG.LEFTBAR_PAD) or 0)

  chatArea:ClearAllPoints()
  chatArea:SetPoint("TOPLEFT",  container, "TOPLEFT",
    leftOffset, -CFG.GUTTER_LEFT - CFG.FRAME_INSETS.top)
  chatArea:SetPoint("TOPRIGHT", container, "TOPRIGHT",
    -CFG.GUTTER_RIGHT - tabsBar:GetWidth() - 6,
    -CFG.GUTTER_RIGHT - CFG.FRAME_INSETS.top)

  local editH = ns.EDIT:GetHeight() or 30
  local baseOffset = CFG.EDGE_PADDING + editH + GAP + CFG.BOTTOM_NUDGE + CFG.FRAME_INSETS.bottom
  chatArea:SetPoint("BOTTOMLEFT",  container, "BOTTOMLEFT",  leftOffset, baseOffset)
  chatArea:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT",
    -CFG.GUTTER_RIGHT - tabsBar:GetWidth() - 6, baseOffset)

  -- sempre alinhar o EditBox quando relayoutar
  if ns.positionEditBox then ns.positionEditBox() end
end

-- helper: posiciona o EditBox respeitando a barra esquerda
function ns.positionEditBox()
  if not ns.EDIT or not ns.frames or not ns.frames.container or not ns.frames.tabsBar then return end
  local leftBarShown = (ns.frames.leftBar and ns.frames.leftBar:IsShown())
  local leftOffset = CFG.EDGE_PADDING + (leftBarShown and (CFG.LEFTBAR_W + CFG.LEFTBAR_PAD) or 0)

  local EDIT = ns.EDIT
  EDIT:ClearAllPoints()
  EDIT:SetParent(ns.frames.container)
  EDIT:SetPoint("BOTTOMLEFT",  ns.frames.container, "BOTTOMLEFT",  leftOffset, CFG.EDGE_PADDING/2)
  EDIT:SetPoint("BOTTOMRIGHT", ns.frames.container, "BOTTOMRIGHT",
                -CFG.EDGE_PADDING - ns.frames.tabsBar:GetWidth() - 6, CFG.EDGE_PADDING/2)
  EDIT:SetFrameStrata("DIALOG")
  EDIT:SetFrameLevel(ns.frames.panel:GetFrameLevel() + 10)
end

 end
-- END 60_layout.lua
