local ADDON_NAME, NS = ...

NS.Features = NS.Features or {}

local FEAT = {}
NS.Features.CharSecondaryStatRatings = FEAT

FEAT._enabled = false
FEAT._hooked = false

local function GetStatTextFontString(statFrame)
	if statFrame.Value and statFrame.Value.GetText then
		return statFrame.Value
	end

	local name = statFrame.GetName and statFrame:GetName()
	if name then
		local fs = _G[name .. "StatText"] or _G[name .. "Value"] or _G[name .. "Text"]
		if fs and fs.GetText then
			return fs
		end
	end

	return nil
end

local function StripExistingSuffix(text)
	return (tostring(text or ""):gsub("%s%(%d+%)%s*$", ""))
end

local function AppendRating(statFrame, rating)
	local fs = GetStatTextFontString(statFrame)
	if not fs then
		return
	end

	local t = fs:GetText()
	if not t or t == "" then
		return
	end

	if not tostring(t):find("%%") then
		return
	end

	t = StripExistingSuffix(t)
	fs:SetText(("%s (%d)"):format(t, tonumber(rating) or 0))
end

local STAT_HOOKS = {
	CRITCHANCE = function()
		return GetCombatRating(CR_CRIT_MELEE) or 0
	end,
	HASTE = function()
		return GetCombatRating(CR_HASTE_MELEE) or 0
	end,
	MASTERY = function()
		return GetCombatRating(CR_MASTERY) or 0
	end,
	VERSATILITY = function()
		return GetCombatRating(CR_VERSATILITY_DAMAGE_DONE) or 0
	end,

	LIFESTEAL = function()
		return GetCombatRating(CR_LIFESTEAL) or 0
	end,

	AVOIDANCE = function()
		return GetCombatRating(CR_AVOIDANCE) or 0
	end,
	SPEED = function()
		return GetCombatRating(CR_SPEED) or 0
	end,
}

local function EnsureHooks()
	if FEAT._hooked then
		return
	end
	FEAT._hooked = true

	if type(PAPERDOLL_STATINFO) ~= "table" then
		return
	end

	for key, ratingFunc in pairs(STAT_HOOKS) do
		local info = PAPERDOLL_STATINFO[key]
		if info and type(info.updateFunc) == "function" then
			hooksecurefunc(info, "updateFunc", function(statFrame, unit)
				if not FEAT._enabled then
					return
				end
				if unit and unit ~= "player" then
					return
				end
				AppendRating(statFrame, ratingFunc())
			end)
		end
	end
end

local function ForceRefresh()
	if PaperDollFrame and PaperDollFrame_UpdateStats then
		pcall(PaperDollFrame_UpdateStats)
	end
	if CharacterStatsPane and CharacterStatsPane.Refresh then
		pcall(CharacterStatsPane.Refresh, CharacterStatsPane)
	end
end

function FEAT:Enable()
	self._enabled = true
	EnsureHooks()
	ForceRefresh()
end

function FEAT:Disable()
	self._enabled = false
	ForceRefresh()
end
