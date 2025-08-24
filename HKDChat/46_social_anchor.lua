-- 45_social_anchor.lua
local _, ns = ...
local panel = ns.frames and ns.frames.panel

-- Alvo principal: FriendsFrame (janela Social)
local F = _G.FriendsFrame

-- Guarda estado original pra restaurar depois
local saved = {
  points = nil,
  strata = nil,
  parent = nil,
  wasIgnoring = nil,
}

local function SaveState()
  if not F then return end
  saved.points = {}
  for i = 1, F:GetNumPoints() do
    local p, rel, rp, x, y = F:GetPoint(i)
    saved.points[i] = { p, rel, rp, x, y }
  end
  saved.strata = F:GetFrameStrata()
  saved.parent = F:GetParent()
  if F.IsIgnoringFramePositionManager then
    saved.wasIgnoring = F:IsIgnoringFramePositionManager()
  end
end

local function RestoreState()
  if not F then return end
  -- volta a ser gerido pelo manager de painéis
  if F.SetIgnoreFramePositionManager then
    F:SetIgnoreFramePositionManager(false)
  end

  F:ClearAllPoints()
  if saved.points and #saved.points > 0 then
    for i, pt in ipairs(saved.points) do
      F:SetPoint(unpack(pt))
    end
  else
    -- fallback neutro
    F:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end

  if saved.strata then F:SetFrameStrata(saved.strata) end
  if saved.parent then F:SetParent(saved.parent) end

  -- pede pro UIParent recolocar tudo nos eixos
  if UIParent_ManageFramePositions then
    UIParent_ManageFramePositions()
  end

  -- limpa o snapshot pra uma próxima rodada
  saved.points, saved.strata, saved.parent, saved.wasIgnoring = nil, nil, nil, nil
end

local function AnchorFriendsToPanel()
  if not (panel and panel:IsShown() and F and F:IsShown()) then return end

  -- salva o estado só na primeira ancorada
  if not saved.points then
    SaveState()
  end

  -- impede o gerenciador de sobrescrever nossa âncora
  if F.SetIgnoreFramePositionManager then
    F:SetIgnoreFramePositionManager(true)
  end

  F:ClearAllPoints()
  -- cola a janela Social à direita do teu panel
  F:SetPoint("LEFT", panel, "RIGHT", 12, 0)

  -- garante que ela fique por cima do panel (mesma strata ou maior)
  local pStrata = panel:GetFrameStrata() or "HIGH"
  if pStrata == "BACKGROUND" or pStrata == "LOW" or pStrata == "MEDIUM" then
    pStrata = "HIGH"
  end
  F:SetFrameStrata(pStrata)
  F:SetToplevel(true)
end

-- Hooks do teu panel
if panel then
  panel:HookScript("OnShow", function()
    if F and F:IsShown() then
      AnchorFriendsToPanel()
    end
  end)

  panel:HookScript("OnHide", function()
    if F and F:IsShown() then
      RestoreState()
    end
  end)
end

-- Se o FriendsFrame abrir enquanto o panel já está aberto, ancora também
if F then
  F:HookScript("OnShow", function()
    if panel and panel:IsShown() then
      AnchorFriendsToPanel()
    end
  end)

  -- quando o usuário fechar a janela Social manualmente, limpamos o snapshot
  F:HookScript("OnHide", function()
    saved.points, saved.strata, saved.parent, saved.wasIgnoring = nil, nil, nil, nil
  end)
end

-- Opcional: quando o botão Social (FriendsMicroButton) for clicado,
-- se o teu panel estiver aberto, garantir a âncora automática.
local socialBtn = _G.FriendsMicroButton
if socialBtn then
  socialBtn:HookScript("OnClick", function()
    C_Timer.After(0, function() -- espera o frame abrir
      if panel and panel:IsShown() and F and F:IsShown() then
        AnchorFriendsToPanel()
      end
    end)
  end)
end

-- (Opcional) Se você também usa CommunitiesFrame como "social":
-- repita a ideia acima trocando F = _G.CommunitiesFrame
