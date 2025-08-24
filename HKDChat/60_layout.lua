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
