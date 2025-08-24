local _, ns = ...

local VOICE_STRINGS = {
  "UNDEAFEN","UNMUTE","DEAFEN","MUTE",
  "Undeafen Voice Chat","Unmute","Deafen","Mute",
  "Cancelar surdez","Ativar som","Silenciar","Ativar microfone"
}

local function isVoiceBtn(frame)
  if not frame or not frame:IsObjectType("Button") then return false end
  local tt = frame.tooltipText or frame.tooltip
  if type(tt) == "string" then
    local up = tt:upper()
    for _, key in ipairs(VOICE_STRINGS) do
      if up:find(key) then return true end
    end
  end
  local n = frame.GetName and frame:GetName() or ""
  if n and n ~= "" then
    local up = n:upper()
    if up:find("VOICE") or up:find("DEAFEN") or up:find("MUTE") then return true end
  end
  return false
end

local function kill(f)
  if not f or f.__hkd_killed then return end
  f.__hkd_killed = true
  if f.Hide then f:Hide() end
  if f.SetAlpha then f:SetAlpha(0) end
  if f.SetScale then f:SetScale(0.0001) end
  if f.EnableMouse then f:EnableMouse(false) end
  if f.SetScript then f:SetScript("OnShow", function(self) self:Hide() end) end
  if f.UnregisterAllEvents then f:UnregisterAllEvents() end
end

function ns.hideVoiceButtons()
  local known = {
    "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton",
    "ChatFrameDeafenButton",
    "ChatFrameMuteButton",
    "VoiceDeafenButton",
    "VoiceMuteButton",
    "QuickJoinDeafenButton",
    "QuickJoinMuteButton",
  }
  for _, name in ipairs(known) do local f=_G[name]; if f then kill(f) end end

  local f = EnumerateFrames()
  while f do
    if isVoiceBtn(f) then kill(f) end
    f = EnumerateFrames(f)
  end

  for i=1, (NUM_CHAT_WINDOWS or 10) do
    local bf = _G["ChatFrame"..i.."ButtonFrame"]
    if bf and bf.GetChildren then
      for _, child in ipairs({bf:GetChildren()}) do
        if isVoiceBtn(child) then kill(child) end
      end
    end
  end
end
