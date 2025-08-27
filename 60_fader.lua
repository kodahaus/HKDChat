-- HKDChat/modules/fader_all.lua (v7.3-ultrafast)
-- LINE ONLY + panel/editbox revive profundo com latência mínima
-- Objetivo: abrir o Panel e exibir TODAS as mensagens imediatamente.

local ADDON, ns = ...

-------------------------------------------------
-- CONFIG
-------------------------------------------------
local TIME_VISIBLE  = 16
local FADE_DURATION = 0.35
local POLL_SEC      = 0.25

-- Ajustes “ultrafast”
local REVIVE_DEPTH_MAX   = 3         -- níveis no deep-walk
local REVIVE_STEP_SEC    = 1/30      -- 0.033s (30 FPS)
local REVIVE_TICKS       = 5         -- 5 * 0.033 = ~0.165s (burst curtíssimo)
local KICK2_DELAY_SEC    = 0.03      -- kick extra mais cedo (antes era 0.10s)
local PREFLUSH_PASSES    = 3         -- varreduras síncronas instantâneas

-------------------------------------------------
-- UTIL
-------------------------------------------------
local _G = _G
local next = next
local function clamp(v) if v>1 then return 1 elseif v<0 then return 0 end return v end
local function outCubic(t,b,c,d) t=t/d-1; return clamp(c*(t^3+1)+b) end

-------------------------------------------------
-- FADER (micro fade-in cosmético opcional)
-------------------------------------------------
local FADE_IN, FADE_OUT = 1, -1
local objects = {}
local updater = CreateFrame("Frame", "HKDChatFaderUpdater")

local function remove(obj)
  objects[obj]=nil
  if not next(objects) then updater:SetScript("OnUpdate", nil) end
end

local function updater_OnUpdate(_, elapsed)
  for object, data in next, objects do
    data.t = data.t + elapsed
    if data.t > 0 then
      data.init = data.init or object:GetAlpha()
      object:SetAlpha(outCubic(data.t, data.init, data.final - data.init, data.dur))
      if data.t >= data.dur then
        local cb = data.cb
        remove(object)
        object:SetAlpha(data.final)
        if cb then pcall(cb, object) end
      end
    end
  end
end

local function add(mode, object, delay, duration, callback)
  if not object or not object.GetAlpha then return end
  local init = object:GetAlpha()
  local final = (mode==FADE_IN) and 1 or 0
  delay = delay or 0; duration = duration or 0.25
  if delay==0 and (duration==0 or init==final) then if callback then pcall(callback,object) end; return end
  objects[object] = {mode=mode, t=-delay, init=init, final=final, dur=duration, cb=callback}
  if not updater:GetScript("OnUpdate") then updater:SetScript("OnUpdate", updater_OnUpdate) end
end

local Fader = {}
function Fader.FadeIn(object, duration, callback, delay)  add(FADE_IN,  object, delay, duration, callback) end
function Fader.FadeOut(object, duration, callback, delay) add(FADE_OUT, object, delay, duration, callback) end
function Fader.Stop(object, alpha) if not object then return end objects[object]=nil; if alpha then object:SetAlpha(alpha) end end
function Fader.IsFading(object) local d=objects[object]; return d and d.mode end
ns.Fader = Fader

-------------------------------------------------
-- DRIVER (LINE only)
-------------------------------------------------
local STATE      = setmetatable({}, { __mode = "k" })
local PANEL_MODE = false
local EDIT_MODE  = false

local function cancelTimer(s) if s and s.timer then s.timer:Cancel(); s.timer=nil end end
local function showNow(cf) Fader.Stop(cf, 1); if cf and cf.SetAlpha then cf:SetAlpha(1) end end
local function anyPause() return PANEL_MODE or EDIT_MODE end

-- micro fade-in (só estético p/ scroll)
local function smoothShow(cf, dur)
  dur = dur or 0.10
  if not cf or not cf.GetAlpha then return end
  if (cf:GetAlpha() or 1) < 0.99 then
    Fader.Stop(cf)
    cf:SetAlpha(0)
    Fader.FadeIn(cf, dur)
  end
end

-- ===== LINE MODE =====
local function applyLineFadingSettings(cf)
  if not cf or not cf.SetFading then return end
  cf:SetFading(true)
  if cf.SetTimeVisible then cf:SetTimeVisible(TIME_VISIBLE) end
  if cf.SetFadeDuration then cf:SetFadeDuration(FADE_DURATION) end
end

local function pauseLineFading(cf)
  if not cf or not cf.SetFading then return end
  local s = STATE[cf]; if not s then return end
  if not s.lineSaved then
    s.lineSaved = {
      tv = (cf.GetTimeVisible and cf:GetTimeVisible()) or TIME_VISIBLE,
      fd = (cf.GetFadeDuration and cf:GetFadeDuration()) or FADE_DURATION,
    }
  end
  cf:SetFading(false)
  if cf.SetAlpha then cf:SetAlpha(1) end
end

local function resumeLineFading(cf)
  if not cf or not cf.SetFading then return end
  local s = STATE[cf]
  cf:SetFading(true)
  if s and s.lineSaved then
    if cf.SetTimeVisible then cf:SetTimeVisible(s.lineSaved.tv or TIME_VISIBLE) end
    if cf.SetFadeDuration then cf:SetFadeDuration(s.lineSaved.fd or FADE_DURATION) end
    s.lineSaved = nil
  else
    applyLineFadingSettings(cf)
  end
end

-------------------------------------------------
-- REVIVER PROFUNDO (alpha=1, sem gradient) + BURST ULTRA-RÁPIDO
-------------------------------------------------

local function _reviveRegion(r)
  if not r or not r.GetObjectType then return end
  if r:GetObjectType() == "FontString" then
    if r.SetAlpha then
      local a = r:GetAlpha()
      if (a or 1) < 1 then r:SetAlpha(1) end
    end
    if r.GetTextColor and r.SetTextColor then
      local cr,cg,cb,ca = r:GetTextColor()
      if ca and ca < 1 then r:SetTextColor(cr or 1, cg or 1, cb or 1, 1) end
    elseif r.GetVertexColor and r.SetVertexColor then
      local vr,vg,vb,va = r:GetVertexColor()
      if va and va < 1 then r:SetVertexColor(vr or 1, vg or 1, vb or 1, 1) end
    end
    if r.SetAlphaGradient then pcall(r.SetAlphaGradient, r, 0, 0) end
    if r.IsIgnoringParentAlpha and r.SetIgnoreParentAlpha then
      if r:IsIgnoringParentAlpha() then r:SetIgnoreParentAlpha(false) end
    end
  end
end

local function reviveFontStrings(cf)
  if not cf then return end

  if cf.GetRegions then
    local regs = { cf:GetRegions() }
    for i=1,#regs do _reviveRegion(regs[i]) end
  end

  local function walk(frame, depth)
    if not frame or depth > REVIVE_DEPTH_MAX then return end
    if frame.GetRegions then
      local regs = { frame:GetRegions() }
      for i=1,#regs do _reviveRegion(regs[i]) end
    end
    if frame.GetChildren then
      local kids = { frame:GetChildren() }
      for i=1,#kids do walk(kids[i], depth + 1) end
    end
  end

  walk(cf, 1)
  if cf.GetScrollChild then walk(cf:GetScrollChild(), 1) end
end

-- Ultra-fast: passes síncronos + 2 kicks curtíssimos + burst curtinho
local function startReviverBurst(cf)
  local s = STATE[cf]; if not s then return end
  if s.reviver then s.reviver:Cancel(); s.reviver = nil end

  -- Pré-chute imediato: varrer já, 3 vezes (pega o estado atual do frame)
  for i = 1, PREFLUSH_PASSES do
    reviveFontStrings(cf)
  end
  if cf.SetAlpha then cf:SetAlpha(1) end

  -- Kicks: no próximo frame e +0.03s
  C_Timer.After(0, function()
    if not cf then return end
    reviveFontStrings(cf)
    if cf.SetAlpha then cf:SetAlpha(1) end
  end)
  C_Timer.After(KICK2_DELAY_SEC, function()
    if not cf then return end
    reviveFontStrings(cf)
    if cf.SetAlpha then cf:SetAlpha(1) end
  end)

  -- Burst curtíssimo (garante cobertura de trocas tardias de linha)
  s.reviver = C_Timer.NewTicker(REVIVE_STEP_SEC, function()
    reviveFontStrings(cf)
    if cf.SetAlpha then cf:SetAlpha(1) end
  end, REVIVE_TICKS)
end

-------------------------------------------------
-- rotina comum
-------------------------------------------------
local function scheduleFade(cf)
  if anyPause() then pauseLineFading(cf) else resumeLineFading(cf) end
end

local function onActivity(cf)
  if anyPause() then pauseLineFading(cf) else resumeLineFading(cf) end
end

local function wireFrame(cf)
  if not cf or STATE[cf] and STATE[cf].wired then return end
  local s = { wired=true, paused=false }; STATE[cf]=s

  applyLineFadingSettings(cf)

  -- hook AddMessage
  local orig = cf.AddMessage
  if orig then
    cf.AddMessage = function(self, ...)
      local r = orig(self, ...)
      onActivity(self)
      return r
    end
  end

  -- mouse wheel: acorda nos dois sentidos
  if cf.HookScript then
    cf:HookScript("OnMouseWheel", function(self)
      local st = STATE[self]; if not st then return end
      pauseLineFading(self)
      smoothShow(self, 0.10)
      if st.wheelResumeTimer then st.wheelResumeTimer:Cancel() end
      st.wheelResumeTimer = C_Timer.NewTimer(1.5, function()
        if not anyPause() then resumeLineFading(self) end
      end)
    end)
  end

  if cf.ScrollToBottom then
    hooksecurefunc(cf, "ScrollToBottom", function(self2) scheduleFade(self2) end)
  end

  showNow(cf)
  scheduleFade(cf)
end

local function forAllChatFrames(fn)
  local n = _G.NUM_CHAT_WINDOWS or 10
  for i=1, n do local cf=_G["ChatFrame"..i]; if cf then fn(cf) end end
end

-------------------------------------------------
-- API pública (mantidos)
-------------------------------------------------
function _G.HKDCHAT_Fade_SetTimes(visible, fade)
  if type(visible)=="number" then TIME_VISIBLE = visible end
  if type(fade)=="number" then FADE_DURATION = fade end
  forAllChatFrames(function(cf)
    local s=STATE[cf]; if s then cancelTimer(s) end
    applyLineFadingSettings(cf)
    showNow(cf)
    scheduleFade(cf)
  end)
end

-- Painel/ENTER: pausa per-line + scroll dance + revive ultrafast
function _G.HKDCHAT_Fade_PanelOpen()
  PANEL_MODE = true
  forAllChatFrames(function(cf)
    local s=STATE[cf]; if s then cancelTimer(s) end

    if cf.SetFading then cf:SetFading(false) end
    if cf.SetAlpha then cf:SetAlpha(1) end

    -- Scroll dance + hook de 2 frames para reflow + revive sem esperar timer
    if cf.ScrollToTop then cf:ScrollToTop() end
    if cf.ScrollToBottom then cf:ScrollToBottom() end

    local framesLeft = 2
    local hookFrame = CreateFrame("Frame")
    hookFrame:SetScript("OnUpdate", function(self)
      framesLeft = framesLeft - 1
      -- cada frame: garante bottom e revive
      if cf and cf.ScrollToBottom then cf:ScrollToBottom() end
      reviveFontStrings(cf)
      if cf and cf.SetAlpha then cf:SetAlpha(1) end
      if framesLeft <= 0 then self:SetScript("OnUpdate", nil) self:Hide() end
    end)

    -- burst ultrafast
    startReviverBurst(cf)

    Fader.Stop(cf, 1)
    if cf.SetAlpha then cf:SetAlpha(1) end
  end)
end

-- Fechar/ESC: retoma per-line
function _G.HKDCHAT_Fade_PanelClose()
  PANEL_MODE = false
  forAllChatFrames(function(cf)
    local s=STATE[cf]
    if s and s.reviver then s.reviver:Cancel(); s.reviver=nil end
    applyLineFadingSettings(cf)
    scheduleFade(cf)
  end)
end

-- EditBox hooks = mesmo fluxo do painel
hooksecurefunc("ChatEdit_ActivateChat", function()
  EDIT_MODE = true
  _G.HKDCHAT_Fade_PanelOpen()
end)

hooksecurefunc("ChatEdit_DeactivateChat", function()
  EDIT_MODE = false
  _G.HKDCHAT_Fade_PanelClose()
end)

-- Painel custom sempre visível (caso use overlay teu)
function _G.HKDCHAT_Fade_LinkPanel(panelFrame)
  if panelFrame and panelFrame.SetAlpha then panelFrame:SetAlpha(1) end
end

-------------------------------------------------
-- Events / temp windows / font size reset
-------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UPDATE_CHAT_WINDOWS")
f:SetScript("OnEvent", function() forAllChatFrames(wireFrame) end)

hooksecurefunc("FCF_OpenTemporaryWindow", function()
  C_Timer.After(0, function()
    if _G.SELECTED_CHAT_FRAME then wireFrame(_G.SELECTED_CHAT_FRAME) end
  end)
end)

hooksecurefunc("FCF_DockFrame", function(chatFrame)
  if chatFrame then wireFrame(chatFrame) end
end)

hooksecurefunc(_G, "FCF_SetChatWindowFontSize", function(_, chatFrame)
  if not chatFrame then return end
  applyLineFadingSettings(chatFrame)
end)

-- Saúde do sistema (placeholder)
local resumeTicker = C_Timer.NewTicker(POLL_SEC, function()
  if anyPause() then return end
end)
