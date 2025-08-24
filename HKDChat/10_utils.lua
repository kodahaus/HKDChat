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
