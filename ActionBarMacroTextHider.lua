local ADDON_NAME, NS = ...
NS.Features = NS.Features or {}
NS.Features.ActionBarMacroText = NS.Features.ActionBarMacroText or {}
local Feature = NS.Features.ActionBarMacroText

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

local function SaveAndSetShown(fs, shown, saved)
	if not fs or not fs.SetShown then
		return
	end
	if saved[fs] == nil then
		saved[fs] = fs:IsShown()
	end
	fs:SetShown(shown)
end

local function RestoreAll(saved)
	for fs, wasShown in pairs(saved) do
		if fs and fs.SetShown then
			fs:SetShown(wasShown and true or false)
		end
		saved[fs] = nil
	end
end

local function HideMacroTextOnButton(btn, saved)
	if not btn then
		return
	end

	local fs = btn.Name or btn.name

	if not fs then
		fs = btn.Text or btn.text
	end

	if fs and fs.SetShown then
		SaveAndSetShown(fs, false, saved)
		return
	end

	if btn.GetRegions then
		local regions = { btn:GetRegions() }
		for i = 1, #regions do
			local r = regions[i]
			if r and r.GetObjectType and r:GetObjectType() == "FontString" then
				local name = r.GetName and r:GetName()
				if name then
					local n = name:lower()
					if n:find("name", 1, true) or n:find("macro", 1, true) then
						SaveAndSetShown(r, false, saved)
					end
				end
			end
		end
	end
end

local function HideMainBar(saved)
	for i = 1, 12 do
		HideMacroTextOnButton(_G["ActionButton" .. i], saved)
	end
	for i = 1, 12 do
		HideMacroTextOnButton(_G["MainMenuBarActionButton" .. i], saved)
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
			HideMacroTextOnButton(bar.actionButtons[i], saved)
		end
		return
	end

	local n = bar.GetName and bar:GetName()
	if n then
		for i = 1, 12 do
			HideMacroTextOnButton(_G[n .. "Button" .. i], saved)
		end
	end

	if bar.commandNamePrefix then
		local idx = bar.commandNamePrefix:match("MULTIACTIONBAR(%d+)")
		if idx then
			for i = 1, 12 do
				HideMacroTextOnButton(_G["MultiActionBar" .. idx .. "Button" .. i], saved)
			end
		end
	end
end

function Feature:Apply()
	local db = _G.BetterUIDB or NS.DB or {}
	local ids = ParseIDs(db.hideActionBarMacroText)

	RestoreAll(self._saved)
	if not next(ids) then
		return
	end

	if ids[1] then
		HideMainBar(self._saved)
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
