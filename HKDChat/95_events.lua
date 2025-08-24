-- 95_events.lua
local _, ns = ...
local CFG = ns.CFG

local ev = CreateFrame("Frame")
ns.frames.eventFrame = ev
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("UI_SCALE_CHANGED")
ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
ev:RegisterEvent("UPDATE_CHAT_WINDOWS")
ev:RegisterEvent("CHANNEL_UI_UPDATE")
ev:RegisterEvent("VOICE_CHAT_CHANNEL_ACTIVATED")
ev:RegisterEvent("VOICE_CHAT_CHANNEL_DEACTIVATED")

-- util: aplica transparência permanente em todos os ChatFrames padrão existentes
local function applyPermanentTransparencyAll()
  local list = {}
  if NUM_CHAT_WINDOWS then
    for i=1, NUM_CHAT_WINDOWS do
      local cf = _G["ChatFrame"..i]
      if cf then table.insert(list, cf) end
    end
  end
  if _G.ChatFrame2 then table.insert(list, _G.ChatFrame2) end
  for _, cf in ipairs(list) do
    ns.forcePermanentTransparency(cf)
  end
end

ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" then
    ns.state.loginBlockUntil = GetTime and (GetTime() + CFG.LOGIN_DEBOUNCE) or 0

    ns.hideDefaultButtonFrames()
    ns.hideVoiceButtons()
    ns.relocateChatMenuButton()
    applyPermanentTransparencyAll()

    if ns.state.adopted then ns.releaseCurrentChat() end
    ns.frames.panel:Hide(); ns.frames.panel:SetAlpha(0); ns.EDIT:Hide()
    ns.state.texAlphaByIdx = {}
    ns.rebuildTabsBar()

    -- se a sidebar NÃO estiver aberta, garante Social no default (1x)
    C_Timer.After(0.20, function()
      if not (ns.frames.leftBar and ns.frames.leftBar:IsShown()) and ns.ensureSocialOnDefault then
        ns.ensureSocialOnDefault()
      end
    end)

  elseif event == "UPDATE_CHAT_WINDOWS" then
    ns.hideDefaultButtonFrames()
    ns.hideVoiceButtons()
    applyPermanentTransparencyAll()

    if ns.frames.panel:IsShown() and ns.state.adopted then
      ns.hideTabsAndButtonsWhileOpen()
      ns.rebuildTabsBar()
      ns.relocateChatMenuButton()

      local active = ns.getActiveChatFrame()
      if active ~= ns.state.currentChat then
        ns.releaseCurrentChat()
        ns.adoptSpecificChatFrame(active)
      end

      -- se a barra estiver aberta, reancora Social uma vez na barra
      if ns.frames.leftBar and ns.frames.leftBar:IsShown() and ns.attachSocial then
        C_Timer.After(0, ns.attachSocial)
      end
    else
      ns.restoreTabsAndButtons()
      ns.relocateChatMenuButton()
      -- painel fechado → Social no layout padrão (1x)
      if ns.ensureSocialOnDefault then C_Timer.After(0, ns.ensureSocialOnDefault) end
    end

  elseif event == "CHANNEL_UI_UPDATE"
      or event == "VOICE_CHAT_CHANNEL_ACTIVATED"
      or event == "VOICE_CHAT_CHANNEL_DEACTIVATED" then
    ns.hideDefaultButtonFrames()
    ns.hideVoiceButtons()
    ns.relocateChatMenuButton()

    -- reforço leve e único conforme a UI mexe
    if ns.frames.leftBar and ns.frames.leftBar:IsShown() and ns.attachSocial then
      C_Timer.After(0, ns.attachSocial)
    elseif ns.ensureSocialOnDefault then
      C_Timer.After(0, ns.ensureSocialOnDefault)
    end

  else
    if ns.frames.panel:IsShown() and ns.state.adopted then
      ns.layoutChatArea(ns.state.currentChat or ChatFrame1)
    end
  end
end)
