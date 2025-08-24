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
