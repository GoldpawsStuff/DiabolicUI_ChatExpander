local Addon, ns = ...
local DiabolicUI2 = _G.DiabolicUI2
if (not DiabolicUI2) then
	return
end

-- Default settings for all modules
_G.DiabolicUI2ChatExpander_DB = {
	Chat = {
		Place = nil,
		Size = nil,
		FontFamily = nil,
		FontSize = nil
	}
}

ns.Extension = DiabolicUI2:NewModule(Addon, "LibMoreEvents-1.0")

ns.Extension.OnEvent = function(self, event, ...)
end

ns.Extension.OnInitialize = function(self)
end

