local _, ns = ...

function ns.hideDefaultButtonFrames()
  for i=1, (NUM_CHAT_WINDOWS or 10) do
    local bf = _G["ChatFrame"..i.."ButtonFrame"]
    if bf then
      if bf.UnregisterAllEvents then bf:UnregisterAllEvents() end
      if bf.SetScript then bf:SetScript("OnShow", function(self) self:Hide() end) end
      bf:Hide()
      if bf.EnableMouse then bf:EnableMouse(false) end
    end
  end
end
