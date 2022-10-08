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

----------------------------------------
-- Local Functions
----------------------------------------
local OnUpdate, OnDragStart, OnDragStop, StopDragging

-- Return a value rounded to the nearest integer.
local round = function(value, precision)
	if (precision) then
		value = value * 10^precision
		value = (value + .5) - (value + .5)%1
		value = value / 10^precision
		return value
	else
		return (value + .5) - (value + .5)%1
	end
end

-- Convert a coordinate within a frame to a usable position
local parse = function(parentWidth, parentHeight, x, y, bottomOffset, leftOffset, topOffset, rightOffset)
	if (y < parentHeight * 1/3) then
		if (x < parentWidth * 1/3) then
			return "BOTTOMLEFT", leftOffset, bottomOffset
		elseif (x > parentWidth * 2/3) then
			return "BOTTOMRIGHT", rightOffset, bottomOffset
		else
			return "BOTTOM", x - parentWidth/2, bottomOffset
		end
	elseif (y > parentHeight * 2/3) then
		if (x < parentWidth * 1/3) then
			return "TOPLEFT", leftOffset, topOffset
		elseif x > parentWidth * 2/3 then
			return "TOPRIGHT", rightOffset, topOffset
		else
			return "TOP", x - parentWidth/2, topOffset
		end
	else
		if (x < parentWidth * 1/3) then
			return "LEFT", leftOffset, y - parentHeight/2
		elseif (x > parentWidth * 2/3) then
			return "RIGHT", rightOffset, y - parentHeight/2
		else
			return "CENTER", x - parentWidth/2, y - parentHeight/2
		end
	end
end

local GetParsedPosition = function(frame)

	-- Retrieve UI coordinates
	local worldHeight = 768 -- WorldFrame:GetHeight()
	local worldWidth = WorldFrame:GetWidth()
	local uiScale = UIParent:GetEffectiveScale()
	local uiWidth, uiHeight = UIParent:GetSize()
	local uiBottom = UIParent:GetBottom()
	local uiLeft = UIParent:GetLeft()
	local uiTop = UIParent:GetTop()
	local uiRight = UIParent:GetRight()

	-- Turn UI coordinates into unscaled screen coordinates
	uiWidth = uiWidth*uiScale
	uiHeight = uiHeight*uiScale
	uiBottom = uiBottom*uiScale
	uiLeft = uiLeft*uiScale
	uiTop = uiTop*uiScale - worldHeight -- use values relative to edges, not origin
	uiRight = uiRight*uiScale - worldWidth -- use values relative to edges, not origin

	-- Retrieve frame coordinates
	local frameScale = frame:GetEffectiveScale()
	local x, y = frame:GetCenter()
	local bottom = frame:GetBottom()
	local left = frame:GetLeft()
	local top = frame:GetTop()
	local right = frame:GetRight()

	-- Turn frame coordinates into unscaled screen coordinates
	x = x*frameScale
	y = y*frameScale
	bottom = bottom*frameScale
	left = left*frameScale
	top = top*frameScale - worldHeight -- use values relative to edges, not origin
	right = right*frameScale - worldWidth -- use values relative to edges, not origin

	-- Figure out the frame position relative to UIParent
	left = left - uiLeft
	bottom = bottom - uiBottom
	right = right - uiRight
	top = top - uiTop

	-- Figure out the point within the given coordinate space
	local point, offsetX, offsetY = parse(uiWidth, uiHeight, x, y, bottom, left, top, right)

	-- Convert coordinates to the frame's scale.
	return point, offsetX/frameScale, offsetY/frameScale
end

local OnDragStart = function(tab, button)

	local frame = _G["ChatFrame"..tab:GetID()]
	if (frame == DEFAULT_CHAT_FRAME) then
		if (frame.isLocked) then
			return
		end

		frame:StartMoving()
		frame:SetUserPlaced(false)

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

	-- OnUpdate simulates OnDragStop
	-- This is a hack fix we need to do because when SetParent is called,
	-- the OnDragStop never fires for the matching OnDragStart.
	tab.dragButton = button
	tab:SetScript("OnUpdate", OnUpdate)

end

local OnDragStop = function(tab)

	local id = tab:GetID()
	local frame = _G["ChatFrame"..id]
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
	local point, x, y = GetParsedPosition(frame)

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

	if (frame == GENERAL_CHAT_DOCK.primary or not frame.isLocked) then
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

----------------------------------------
-- Diabolic Module Overrides
----------------------------------------
ChatFrames.OverrideDockingLocks = function(self)
	--FCF_SetLocked(ChatFrame1, true)
	--hooksecurefunc("FCF_ToggleLockOnDockedFrame", function()
	--	for _, frame in pairs(FCFDock_GetChatFrames(_G.GENERAL_CHAT_DOCK)) do
	--		FCF_SetLocked(frame, true)
	--	end
	--end)
end

ChatFrames.OverrideChatPositions = function(self)

	local frame = _G.ChatFrame1
	frame:SetUserPlaced(false)
	frame:ClearAllPoints()
	frame:SetSize(self:GetDefaultChatFrameSize())
	frame:SetPoint(self:GetDefaultChatFramePosition())
	frame.ignoreFramePositionManager = true

	local scaffold = self.frame
	scaffold:ClearAllPoints()
	scaffold:SetAllPoints(ChatFrame1)

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

----------------------------------------
-- Extension API
----------------------------------------
Chat.StoreFrame = function(self, frame, ...)
	local id = frame:GetID()
	local db = self.db.StoredFrames[id]
	if (not db) then
		db = {
			Place = nil,
			Size = nil,
			FontFamily = nil,
			FontSize = nil
		}
		self.db.StoredFrames[id] = db
	end
end

Chat.RestoreFrame = function(self, frame, ...)
	local id = frame:GetID()
	local db = self.db.StoredFrames[id]
	if (not db) then
		return
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
	self.db = ns.Extension.db -- retrieve settings

	--ChatFrames:PostSetupChatFrames()

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
end
