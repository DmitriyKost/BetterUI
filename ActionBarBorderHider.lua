-- Hide action button border art on specific bars.
-- User enters IDs like: 1,7,8
-- 1 = main action bar (ActionButton1..12)
-- 2..8 = Edit Mode action bars by systemIndex (MultiBar*)

local ADDON_NAME, NS = ...
NS.Features = NS.Features or {}
NS.Features.ActionBarBorders = NS.Features.ActionBarBorders or {}
local Feature = NS.Features.ActionBarBorders

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

local function SaveAndSetAlpha(tex, a, saved)
	if not tex or not tex.SetAlpha then
		return
	end
	if saved[tex] == nil then
		saved[tex] = tex:GetAlpha()
	end
	tex:SetAlpha(a)
end

local function RestoreAll(saved)
	for tex, alpha in pairs(saved) do
		if tex and tex.SetAlpha then
			tex:SetAlpha(alpha or 1)
		end
		saved[tex] = nil
	end
end

local function HideButtonBorder(btn, saved)
	if not btn then
		return
	end

	local nt = btn.GetNormalTexture and btn:GetNormalTexture() or btn.NormalTexture
	if nt then
		SaveAndSetAlpha(nt, 0, saved)
	end

	if btn.Border then
		SaveAndSetAlpha(btn.Border, 0, saved)
	end
	if btn.FloatingBG then
		SaveAndSetAlpha(btn.FloatingBG, 0, saved)
	end
	if btn.LeftDivider then
		SaveAndSetAlpha(btn.LeftDivider, 0, saved)
	end
	if btn.RightDivider then
		SaveAndSetAlpha(btn.RightDivider, 0, saved)
	end
	if btn.SlotBackground then
		SaveAndSetAlpha(btn.SlotBackground, 0, saved)
	end
end

local function HideMainBar(saved)
	for i = 1, 12 do
		HideButtonBorder(_G["ActionButton" .. i], saved)
	end

	for i = 1, 12 do
		HideButtonBorder(_G["MainMenuBarActionButton" .. i], saved)
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

local function HideBarButtons(bar, saved)
	if not bar then
		return
	end

	if type(bar.actionButtons) == "table" and #bar.actionButtons > 0 then
		for i = 1, #bar.actionButtons do
			HideButtonBorder(bar.actionButtons[i], saved)
		end
		return
	end

	local n = bar.GetName and bar:GetName()
	if n then
		for i = 1, 12 do
			HideButtonBorder(_G[n .. "Button" .. i], saved)
		end
	end

	if bar.commandNamePrefix then
		local p = bar.commandNamePrefix
		local idx = p:match("MULTIACTIONBAR(%d+)")
		if idx then
			for i = 1, 12 do
				HideButtonBorder(_G["MultiActionBar" .. idx .. "Button" .. i], saved)
			end
		end
	end
end

function Feature:Apply()
	local db = _G.BetterUIDB or NS.DB or {}
	local ids = ParseIDs(db.hideActionBarBorders)

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
				HideBarButtons(bars[i], self._saved)
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
