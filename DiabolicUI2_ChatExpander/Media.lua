local Addon, ns = ...
local DiabolicUI2 = _G.DiabolicUI2
if (not DiabolicUI2) then
	return
end

local LSM = LibStub("LibSharedMedia-3.0")

--LSM.LOCALE_BIT_koKR
--LSM.LOCALE_BIT_ruRU
--LSM.LOCALE_BIT_zhCN
--LSM.LOCALE_BIT_zhTW
--LSM.LOCALE_BIT_western
local langmask = LSM.LOCALE_BIT_western
local mediatype = LSM.MediaType.FONT
local path = "Interface/AddOns/"..Addon.."/Media/"

LSM:Register(mediatype, "ExocetBlizzardLight", path.."ExocetBlizzardLight.ttf", langmask)
LSM:Register(mediatype, "ExocetBlizzardMedium", path.."ExocetBlizzardMedium.ttf", langmask)
