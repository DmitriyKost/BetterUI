-- Make action buttons on specific bars clickthrough (disable mouse interaction).
-- User enters IDs like: 1,7,8
-- 1 = main action bar (ActionButton1..12)
-- 2..8 = Edit Mode action bars by systemIndex (MultiBar*)

local ADDON_NAME, NS = ...
NS.Features = NS.Features or {}
NS.Features.ActionBarClickThrough = NS.Features.ActionBarClickThrough or {}
local Feature = NS.Features.ActionBarClickThrough

Feature._saved = Feature._saved or {}

local function ParseIDs(str)
	local out = {}
	if not str or str == "" then
		return out
	end
	for n in tostring(str):gmatch("%d+") do
		local id = tonumber(n)
		if id and id >= 1 and id <= 12 then
			out[id] = true
		end
	end
	return out
end

local function SaveAndSetMouseEnabled(btn, enabled, saved)
	if not btn or not btn.EnableMouse then
		return
	end
	if saved[btn] == nil then
		saved[btn] = btn:IsMouseEnabled() and true or false
	end
	btn:EnableMouse(enabled and true or false)
end

local function RestoreAll(saved)
	for btn, wasEnabled in pairs(saved) do
		if btn and btn.EnableMouse then
			btn:EnableMouse(wasEnabled and true or false)
		end
		saved[btn] = nil
	end
end

local function ApplyToButton(btn, saved)
	if not btn then
		return
	end
	SaveAndSetMouseEnabled(btn, false, saved)
end

local function ApplyToMainBar(saved)
	for i = 1, 12 do
		ApplyToButton(_G["ActionButton" .. i], saved)
	end

	for i = 1, 12 do
		ApplyToButton(_G["MainMenuBarActionButton" .. i], saved)
	end
end

local function EnumerateCandidateBars()
	local names = {
		"MainMenuBar",
		"MultiBarBottomLeft",
		"MultiBarBottomRight",
		"MultiBarLeft",
		"MultiBarRight",
		"MultiBar5",
		"MultiBar6",
		"MultiBar7",
		"MultiBar8",
	}
	local out = {}
	for i = 1, #names do
		local f = _G[names[i]]
		if f then
			out[#out + 1] = f
		end
	end
	return out
end

local function FindBarsBySystemIndex(targetIndex)
	local bars = EnumerateCandidateBars()
	local out = {}
	for i = 1, #bars do
		local b = bars[i]
		if b.systemIndex == targetIndex then
			out[#out + 1] = b
		end
	end
	return out
end

local function ApplyToBar(bar, saved)
	if not bar then
		return
	end

	if type(bar.actionButtons) == "table" and #bar.actionButtons > 0 then
		for i = 1, #bar.actionButtons do
			ApplyToButton(bar.actionButtons[i], saved)
		end
		return
	end

	local n = bar.GetName and bar:GetName()
	if n then
		for i = 1, 12 do
			ApplyToButton(_G[n .. "Button" .. i], saved)
		end
	end

	if bar.commandNamePrefix then
		local idx = bar.commandNamePrefix:match("MULTIACTIONBAR(%d+)")
		if idx then
			for i = 1, 12 do
				ApplyToButton(_G["MultiActionBar" .. idx .. "Button" .. i], saved)
			end
		end
	end
end

function Feature:Apply()
	local db = _G.BetterUIDB or NS.DB or {}
	local ids = ParseIDs(db.clickThroughActionBars)

	RestoreAll(self._saved)
	if not next(ids) then
		return
	end

	if ids[1] then
		ApplyToMainBar(self._saved)
	end

	for id in pairs(ids) do
		if id ~= 1 then
			local bars = FindBarsBySystemIndex(id)
			for i = 1, #bars do
				ApplyToBar(bars[i], self._saved)
			end
		end
	end
end

function Feature:Enable()
	self:Apply()
end

function Feature:Disable()
	RestoreAll(self._saved)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
f:RegisterEvent("UI_SCALE_CHANGED")
f:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
f:RegisterEvent("UPDATE_BINDINGS")
f:SetScript("OnEvent", function()
	C_Timer.After(0.3, function()
		if Feature and Feature.Apply then
			Feature:Apply()
		end
	end)
end)

if NS.OnSettingChanged then
	NS.OnSettingChanged(function()
		Feature:Apply()
	end)
end
