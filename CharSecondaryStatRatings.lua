local ADDON_NAME, NS = ...

NS.Features = NS.Features or {}

local FEAT = {}
NS.Features.CharSecondaryStatRatings = FEAT

FEAT._enabled = false
FEAT._hooked = false
FEAT._pendingRefresh = false

local EventFrame = CreateFrame("Frame")

local function IsInCombat()
	return InCombatLockdown and InCombatLockdown()
end

local function QueueRefresh()
	if not FEAT._enabled then
		return
	end

	FEAT._pendingRefresh = true
	EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

EventFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_REGEN_ENABLED" then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		FEAT._pendingRefresh = false
	end
end)

local function GetStatTextFontString(statFrame)
	if statFrame and statFrame.Value and statFrame.Value.SetText then
		return statFrame.Value
	end

	local name = statFrame and statFrame.GetName and statFrame:GetName()
	if name then
		local fs = _G[name .. "StatText"] or _G[name .. "Value"] or _G[name .. "Text"]
		if fs and fs.SetText then
			return fs
		end
	end

	return nil
end

local function FormatPercent(value)
	value = tonumber(value)
	if not value then
		return nil
	end

	if value == math.floor(value) then
		return ("%d%%"):format(value)
	end

	return ("%.2f%%"):format(value)
end

local function AppendRating(statFrame, rating)
	if IsInCombat() then
		QueueRefresh()
		return
	end

	local fs = GetStatTextFontString(statFrame)
	if not fs then
		return
	end

	local percentText = FormatPercent(statFrame and statFrame.numericValue)
	if not percentText then
		return
	end

	local ratingValue = tonumber(rating) or 0

	pcall(fs.SetText, fs, ("%s (%d)"):format(percentText, ratingValue))
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

				if IsInCombat() then
					QueueRefresh()
					return
				end

				AppendRating(statFrame, ratingFunc())
			end)
		end
	end
end

function FEAT:Enable()
	self._enabled = true
	EnsureHooks()
end

function FEAT:Disable()
	self._enabled = false
	self._pendingRefresh = false
	EventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
end
