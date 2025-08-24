local _, ns = ...

SLASH_HKDCHAT_1 = "/hkdchat"
SlashCmdList.HKDCHAT = function(msg)
  msg = (msg or ""):lower()
  if msg == "reset" then
    if ns.state.adopted then ns.releaseCurrentChat() end
    if FCF_ResetChatWindows then FCF_ResetChatWindows() end
    ns.hideDefaultButtonFrames()
    ns.hideVoiceButtons()
    ns.relocateChatMenuButton()
    ns.log("chat windows resetadas.")
    return
  end
  if ns.frames.panel:IsShown() and ns.state.adopted then ns.hidePanel() else ns.showPanel() end
end
