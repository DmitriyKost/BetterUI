local ADDON_NAME, NS = ...

NS.Features = NS.Features or {}
NS.ADDON_NAME = ADDON_NAME
NS.ADDON_PREFIX = "BUI_Utils"
NS.BUTTON_PREFIX = NS.ADDON_PREFIX .. "_TotemButton"

NS._listeners = NS._listeners or {}
function NS.OnSettingChanged(fn)
	NS._listeners[#NS._listeners + 1] = fn
end
function NS.FireSettingChanged()
	for i = 1, #NS._listeners do
		pcall(NS._listeners[i])
	end
end

local defaults = {
	enableStaggerBar = true,
	enableHealthBar = true,
	enableStatueKill = true,

	enablePerformanceMonitor = false,

	perfShowFPS = true,
	perfShowHomeMS = true,
	perfShowWorldMS = false,

	perfLocked = false,
	perfFontSize = 12,

	hideActionBarBorders = "",
	hideActionBarMacroText = "",
	clickThroughActionBars = "",

	enableCharSecondaryStatRatings = true,
}
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, addon)
	if addon ~= ADDON_NAME then
		return
	end

	_G.BetterUIDB = _G.BetterUIDB or {}

	for k, v in pairs(defaults) do
		if _G.BetterUIDB[k] == nil then
			_G.BetterUIDB[k] = v
		end
	end

	NS.DB = _G.BetterUIDB

	C_Timer.After(0, function()
		if NS.ApplySettings then
			NS.ApplySettings()
		end
	end)
end)

local function Prefix()
	return "|cffffaa00" .. (ADDON_NAME or "BetterUI") .. ":|r "
end

function NS.Print(msg)
	if msg == nil then
		return
	end
	print(Prefix() .. tostring(msg))
end

function NS.ApplySettings()
	local db = _G.BetterUIDB or NS.DB or {}

	local function ApplyFeature(name, enabled)
		local feat = NS.Features[name]
		if not feat then
			return
		end
		if enabled then
			pcall(function()
				feat:Enable()
			end)
		else
			pcall(function()
				feat:Disable()
			end)
		end
	end

	ApplyFeature("StaggerBar", db.enableStaggerBar)
	ApplyFeature("HealthBar", db.enableHealthBar)
	ApplyFeature("StatueKill", db.enableStatueKill)
	ApplyFeature("Performance", db.enablePerformanceMonitor)
	ApplyFeature("ActionBarBorders", true)
	ApplyFeature("ActionBarMacroText", true)
	ApplyFeature("ActionBarClickThrough", true)
	ApplyFeature("CharSecondaryStatRatings", db.enableCharSecondaryStatRatings)
end
