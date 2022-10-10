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
local Chat = ns.Extension:NewModule("Chat", "LibMoreEvents-1.0", "AceConsole-3.0")
local ChatFrames = DiabolicUI2:GetModule("ChatFrames")

-- Lua API
local _G = _G
local ipairs = ipairs
local pairs = pairs
local string_lower = string.lower
local unpack = unpack

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

-- Keeping it simple.
local GetModuleSettings = function()
	if (not DiabolicUI2ChatExpander_DB.StoredFrames) then
		DiabolicUI2ChatExpander_DB.StoredFrames = {}
	end
	return DiabolicUI2ChatExpander_DB.StoredFrames
end

-- Convert a coordinate within a frame to a usable position
local GetParsedPosition = function(parentWidth, parentHeight, x, y, bottomOffset, leftOffset, topOffset, rightOffset)
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

-- Retrieve a properly scaled position of a frame.
local GetPosition = function(frame)

	-- Retrieve UI coordinates, convert to unscaled screen coordinates
	local worldHeight = 768 -- WorldFrame:GetHeight()
	local worldWidth = WorldFrame:GetWidth()
	local uiScale = UIParent:GetEffectiveScale()
	local uiWidth = UIParent:GetWidth() * uiScale
	local uiHeight = UIParent:GetHeight() * uiScale
	local uiBottom = UIParent:GetBottom() * uiScale
	local uiLeft = UIParent:GetLeft() * uiScale
	local uiTop = UIParent:GetTop() * uiScale - worldHeight -- use values relative to edges, not origin
	local uiRight = UIParent:GetRight() * uiScale - worldWidth -- use values relative to edges, not origin

	-- Retrieve frame coordinates, convert to unscaled screen coordinates
	local frameScale = frame:GetEffectiveScale()
	local x, y = frame:GetCenter(); x = x * frameScale; y = y * frameScale
	local bottom = frame:GetBottom() * frameScale
	local left = frame:GetLeft() * frameScale
	local top = frame:GetTop() * frameScale - worldHeight -- use values relative to edges, not origin
	local right = frame:GetRight() * frameScale - worldWidth -- use values relative to edges, not origin

	-- Figure out the frame position relative to UIParent
	left = left - uiLeft
	bottom = bottom - uiBottom
	right = right - uiRight
	top = top - uiTop

	-- Figure out the point within the given coordinate space
	local point, offsetX, offsetY = GetParsedPosition(uiWidth, uiHeight, x, y, bottom, left, top, right)

	-- Convert coordinates to the frame's scale.
	return point, offsetX / frameScale, offsetY / frameScale
end

OnDragStart = function(tab, button)

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

OnDragStop = function(tab, dragButton)

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

	Chat:StoreFrame(frame)

	MOVING_CHATFRAME = nil -- taint?
end

OnUpdate = function(tab, elapsed)

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
local ChatFrames_OverrideDockingLocks = ChatFrames.OverrideDockingLocks
ChatFrames.OverrideDockingLocks = function(self, ...)
	-- This is where Diabolic forces the chat frames to always be locked.
	-- We're overriding this by having this method exist at all.

	if (ChatFrames_OverrideDockingLocks) then
		ChatFrames_OverrideDockingLocks(self, ...)
	end
end

local ChatFrames_OverrideChatPositions = ChatFrames.OverrideChatPositions
ChatFrames.OverrideChatPositions = function(self, ...)

	-- Put the primary frame in Diabolic's default position
	-- if no saved position is found for it.
	if (not GetModuleSettings()[1]) then
		local frame = _G.ChatFrame1
		frame:SetUserPlaced(false)
		frame:ClearAllPoints()
		frame:SetSize(self:GetDefaultChatFrameSize())
		frame:SetPoint(self:GetDefaultChatFramePosition())
		frame.ignoreFramePositionManager = true
		FCF_SetLocked(frame, true)
	end

	-- Attach the scaffold to the primary frame
	local scaffold = self.frame
	scaffold:ClearAllPoints()
	scaffold:SetAllPoints(ChatFrame1)

	-- Restore all saved frames
	Chat:RestoreAllFrames()

	if (ChatFrames_OverrideChatPositions) then
		ChatFrames_OverrideChatPositions(self, ...)
	end
end

local ChatFrames_OverrideChatFont = ChatFrames.OverrideChatFont
ChatFrames.OverrideChatFont = function(self, frame, ...)
	-- This method is hooked to frame:SetFont(),
	-- so take care to avoid an infinite loop here.
	if (not frame or frame._templock) then
		return
	end

	-- Set a temporary lock flag
	frame._templock = true

	-- Apply our selected font changes.
	-- These are currently the same as Diabolic's default.
	local fontObject = frame:GetFontObject()
	local font, size, style = fontObject:GetFont()
	fontObject:SetFont(font, size, "OUTLINE")
	fontObject:SetShadowColor(0, 0, 0, .5)
	fontObject:SetShadowOffset(-.75, -.75)

	-- Clear the temporary lock flag
	frame._templock = nil

	if (ChatFrames_OverrideChatFont) then
		ChatFrames_OverrideChatFont(self, frame, ...)
	end
end

local ChatFrames_PostSetupChatFrames = ChatFrames.PostSetupChatFrames
ChatFrames.PostSetupChatFrames = function(self, ...)

	-- This is called after each time DiabolicUI
	-- has setup one or several chat frames.
	for _,frameName in pairs(_G.CHAT_FRAMES) do
		local frame = _G[frameName]
		if (frame) then

			-- Put the frame above the actionbar artwork.
			frame:SetFrameStrata("MEDIUM")

			-- Allow movement to the bottom of the screen
			frame:SetClampRectInsets(-54, -54, -54, -54)

			-- Replace the frame's drag handler,
			-- as we're using our own system to handle our own scale.
			local tab = frame.tab or _G[frameName .. "Tab"]
			if (tab) then
				tab:SetScript("OnDragStart", OnDragStart)
			end
		end
	end

	if (ChatFrames_PostSetupChatFrames) then
		ChatFrames_PostSetupChatFrames(self, ...)
	end
end

----------------------------------------
-- Extension API
----------------------------------------
Chat.StoreFrame = function(self, frame, ...)
	local id = frame:GetID()
	local db = GetModuleSettings()[id]
	if (not db) then
		db = {
			Place = nil,
			Size = nil,
			FontFamily = nil,
			FontSize = nil
		}
		GetModuleSettings()[id] = db
	end
	db.Place = { GetPosition(frame) }
	db.Size = { frame:GetSize() }
	db.Scale = { frame:GetEffectiveScale() }
end

Chat.RestoreFrame = function(self, frame, ...)
	local id = frame:GetID()
	local db = GetModuleSettings()[id]
	if (not db) then
		return
	end
	frame:SetUserPlaced(false)
	frame:ClearAllPoints()
	frame:SetPoint(unpack(db.Place))
	frame:SetSize(unpack(db.Size))
end

Chat.RestoreAllFrames = function(self)
	local frame
	for id,db in pairs(GetModuleSettings()) do
		frame = _G["ChatFrame"..id]
		if (frame and frame:IsShown()) then
			self:RestoreFrame(frame)
		end
	end
	-- Dock any floating frames not currently saved in the addon.
	for _,frameName in pairs(_G.CHAT_FRAMES) do
		local frame = _G[frameName]
		if (frame and frame:IsShown()) then
			local id = frame:GetID()
			if (not GetModuleSettings()[id]) then
				local name, fontSize, r, g, b, a, shown, locked, docked, uninteractable = FCF_GetChatWindowInfo(id)
				if (id ~= 1 and not docked and not frame.minimized) then
					FCF_DockFrame(frame)
				end
			end
		end
	end
end

Chat.ResetChat = function(self, input)
	local all
	local args = { self:GetArgs(string_lower(input)) }
	for _,arg in ipairs(args) do
		if (arg == "all") then
			all = true
		end
	end
	local needsUpdate
	if (all) then
		for id in pairs(GetModuleSettings()) do
			GetModuleSettings()[id] = nil
			needsUpdate = true
		end
	else
		if (GetModuleSettings()[1]) then
			GetModuleSettings()[1] = nil
			needsUpdate = true
		end
	end
	if (needsUpdate) then
		ChatFrames:OverrideChatPositions()
	end
end

Chat.OnEvent = function(self, event, ...)
	if (event == "ADDON_LOADED") then
		local addon = ...
		if (addon ~= Addon) then
			return
		end
		self:UnregisterEvent("ADDON_LOADED", "OnEvent")
	end
	ChatFrames:OverrideChatPositions()
end

Chat.OnInitialize = function(self)
	self:RegisterChatCommand("resetchat", "ResetChat")
	self:RegisterEvent("ADDON_LOADED", "OnEvent")
end
