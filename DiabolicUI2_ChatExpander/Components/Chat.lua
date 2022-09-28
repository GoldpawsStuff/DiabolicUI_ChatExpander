--[[

	The MIT License (MIT)

	Copyright (c) 2022 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
local Addon, ns = ...
local Chat = ns.Extension:NewModule("Chat", "LibMoreEvents-1.0")
local ChatFrames = DiabolicUI2:GetModule("ChatFrames")

-- Lua API
local _G = _G
local ipairs = ipairs

-- WoW API
local GetCursorPosition = GetCursorPosition
local FCF_DockFrame = FCF_DockFrame
local FCFDock_GetChatFrames = FCFDock_GetChatFrames
local FCFDock_GetInsertIndex = FCFDock_GetInsertIndex
local FCFDock_HideInsertHighlight = FCFDock_HideInsertHighlight
local FCFDock_PlaceInsertHighlight = FCFDock_PlaceInsertHighlight
local FCF_SetTabPosition = FCF_SetTabPosition
local FCF_SetButtonSide = FCF_SetButtonSide
local FCF_UpdateButtonSide = FCF_UpdateButtonSide
local IsMouseButtonDown = IsMouseButtonDown

local OnUpdate, OnDragStart, OnDragStop, StopDragging

local OnDragStart = function(tab, button)

	local frame = _G["ChatFrame"..tab:GetID()]
	if (frame == DEFAULT_CHAT_FRAME) then
		if (frame.isLocked) then
			return
		end

		frame:StartMoving()
		MOVING_CHATFRAME = frame

	elseif (frame.isDocked) then

		FCF_UnDockFrame(frame)
		FCF_SetLocked(frame, false)

		local chatTab = _G[frame:GetName().."Tab"]
		local x,y = chatTab:GetCenter()
		x = x - (chatTab:GetWidth()/2)
		y = y - (chatTab:GetHeight()/2)

		chatTab:ClearAllPoints()
		frame:ClearAllPoints()

		-- TODO: FIX SCALE!
		frame:SetPoint("TOPLEFT", "UIParent", "BOTTOMLEFT", x, y)

		FCF_SetTabPosition(frame, 0)

		frame:StartMoving()
		frame:SetUserPlaced(false)

		MOVING_CHATFRAME = frame
		SELECTED_CHAT_FRAME = frame

		Blizzard_CombatLog_Update_QuickButtons()

	else
		if (frame.isLocked) then
			return
		end
		frame:StartMoving()
		frame:SetUserPlaced(false)

		SELECTED_CHAT_FRAME = frame
		MOVING_CHATFRAME = frame
	end

	tab:LockHighlight()

	--OnUpdate simulates OnDragStop
	--This is a hack fix we need to do because when SetParent is called,
	-- the OnDragStop never fires for the matching OnDragStart.
	tab.dragButton = button
	tab:SetScript("OnUpdate", OnUpdate)

end

local OnDragStop = function(tab)

	local frame = _G["ChatFrame"..tab:GetID()]
	frame:StopMovingOrSizing()
	tab:UnlockHighlight()

	FCFDock_HideInsertHighlight(GENERAL_CHAT_DOCK)

	if (GENERAL_CHAT_DOCK:IsMouseOver(10, -10, 0, 10)) then
		local mouseX, mouseY = GetCursorPosition()
		mouseX, mouseY = mouseX / UIParent:GetScale(), mouseY / UIParent:GetScale()

		FCF_DockFrame(frame, FCFDock_GetInsertIndex(GENERAL_CHAT_DOCK, frame, mouseX, mouseY), true)
	else
		FCF_SetTabPosition(frame, 0)
	end

	-- TODO: Store scaled position and save in variables

	MOVING_CHATFRAME = nil -- taint?
end

local OnUpdate = function(tab, elapsed)

	local cursorX, cursorY = GetCursorPosition()
	cursorX, cursorY = cursorX / UIParent:GetScale(), cursorY / UIParent:GetScale()

	local frame = _G["ChatFrame"..tab:GetID()]
	if (frame ~= GENERAL_CHAT_DOCK.primary and GENERAL_CHAT_DOCK:IsMouseOver(10, -10, 0, 10)) then
		FCFDock_PlaceInsertHighlight(GENERAL_CHAT_DOCK, frame, cursorX, cursorY)
	else
		FCFDock_HideInsertHighlight(GENERAL_CHAT_DOCK)
	end

	FCF_UpdateButtonSide(frame)

	if ( frame == GENERAL_CHAT_DOCK.primary or not frame.isLocked ) then
		for _, frame in pairs(FCFDock_GetChatFrames(GENERAL_CHAT_DOCK)) do
			FCF_SetButtonSide(frame, FCF_GetButtonSide(GENERAL_CHAT_DOCK.primary))
		end
	end

	if (not IsMouseButtonDown(tab.dragButton)) then
		OnDragStop(tab, tab.dragButton)
		tab.dragButton = nil
		tab:SetScript("OnUpdate", nil)
	end

end

ChatFrames.OverrideDockingLocks = function(self)
	--FCF_SetLocked(ChatFrame1, true)
	--hooksecurefunc("FCF_ToggleLockOnDockedFrame", function()
	--	for _, frame in pairs(FCFDock_GetChatFrames(_G.GENERAL_CHAT_DOCK)) do
	--		FCF_SetLocked(frame, true)
	--	end
	--end)
end

ChatFrames.OverrideChatPositions = function(self)
	self.frame:ClearAllPoints()
	self.frame:SetAllPoints(ChatFrame1)
	--local frame = _G.ChatFrame1
	--frame:ClearAllPoints()
	--frame:SetAllPoints(self.frame)
	--frame.ignoreFramePositionManager = true
end

ChatFrames.OverrideChatFont = function(self, frame, ...)
	if (not frame or frame._templock) then
		return
	end
	frame._templock = true

	local fontObject = frame:GetFontObject()
	local font, size, style = fontObject:GetFont()
	fontObject:SetFont(font, size, "OUTLINE")
	fontObject:SetShadowColor(0,0,0,.5)
	fontObject:SetShadowOffset(-.75, -.75)
	--fontObject:SetFont(font, size, "")
	--fontObject:SetShadowColor(0,0,0,.75)

	frame._templock = nil
end

ChatFrames.PostSetupChatFrames = function(self)
	for _,frameName in ipairs(_G.CHAT_FRAMES) do
		local frame = _G[frameName]
		if (frame) then
			local tab = frame.tab or _G[frameName .. "Tab"]
			if (tab) then
				tab:HookScript("OnDragStart", OnDragStart)
			end
		end
	end
end


Chat.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		local isInitialLogin, isReloadingUi = ...
		if (isInitialLogin or isReloadingUi) then
			--ChatFrame1:Clear()
		end
	end
end

Chat.OnInitialize = function(self)


	--ChatFrames:PostSetupChatFrames()

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
end
