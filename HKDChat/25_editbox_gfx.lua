local _, ns = ...

-- Esconde as bordas/texturas do EditBox padrão (esquerda/centro/direita)
function ns.hideEditBoxGfx()
  local L = _G.ChatFrame1EditBoxLeft;  if L then L:Hide() end
  local M = _G.ChatFrame1EditBoxMid;   if M then M:Hide() end
  local R = _G.ChatFrame1EditBoxRight; if R then R:Hide() end
end

-- Restaura as bordas/texturas do EditBox padrão
function ns.showEditBoxGfx()
  local L = _G.ChatFrame1EditBoxLeft;  if L then L:Show() end
  local M = _G.ChatFrame1EditBoxMid;   if M then M:Show() end
  local R = _G.ChatFrame1EditBoxRight; if R then R:Show() end
end
