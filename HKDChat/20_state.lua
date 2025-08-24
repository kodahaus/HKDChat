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
