local Addon, ns = ...
local Chat = ns.Extension:NewModule("Chat", "LibMoreEvents-1.0")

--[[--

Added Features:
- Primary chat window
	- Move it
	- Resize it
	- Change font face
		- Add LibSharedMedia support here?
		- Add the Exocet font?


--]]--

Chat.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		local isInitialLogin, isReloadingUi = ...
		if (isInitialLogin or isReloadingUi) then
			--ChatFrame1:Clear()
		end
	end
end

Chat.OnInitialize = function(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
end
