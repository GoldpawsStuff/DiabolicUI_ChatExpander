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
local DiabolicUI2 = _G.DiabolicUI2
if (not DiabolicUI2) then
	return
end

ns.Extension = DiabolicUI2:NewModule(Addon, "LibMoreEvents-1.0")

-- Default settings for all modules
_G.DiabolicUI2ChatExpander_DB = {
	StoredFrames = {
		--[1] = {
		--	Place = nil,
		--	Size = nil,
		--	FontFamily = nil,
		--	FontSize = nil
		--}
	}
}

-- Purge deprecated settings,
-- translate to new where applicable,
-- make sure important ones are within bounds.
local SanitizeSettings = function(db)
	if (not db) then
		return
	end
	db.Chat = nil -- was used during early development
	-- retrieve Diabolic defaults

end

ns.Extension.StoreFrame = function(self, frame, ...)
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

ns.Extension.RestoreFrame = function(self, frame, ...)
	local id = frame:GetID()
	local db = self.db.StoredFrames[id]
	if (not db) then
		return
	end
end

ns.Extension.OnEvent = function(self, event, ...)
end

ns.Extension.OnInitialize = function(self)
	self.db = SanitizeSettings(DiabolicUI2ChatExpander_DB)
end

