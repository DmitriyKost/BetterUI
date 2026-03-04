--[[
BlackOxStatueRemoval.lua

Creates secure "destroytotem" buttons for Brewmaster.
WoW treats Black Ox Statue as a totem internally.

Buttons:
- BUI_Utils_TotemButton1..4

Notes:
- Secure buttons can only be CREATED out of combat (InCombatLockdown()).
- This version does NOT retry on PLAYER_REGEN_ENABLED.
  If creation fails due to combat at login/reload, it prints a message once.
]]

local ADDON_NAME, NS = ...

local BUTTON_PREFIX = NS.BUTTON_PREFIX or "BUI_Utils_TotemButton"

local function Enabled()
	return _G.BetterUIDB and _G.BetterUIDB.enableStatueKill == true
end

local function GetButtonName(slot)
	return BUTTON_PREFIX .. slot
end

local function ButtonsExist()
	for i = 1, 4 do
		local b = _G[GetButtonName(i)]
		if not b then
			return false
		end
		if b:GetAttribute("type1") ~= "destroytotem" or b:GetAttribute("totem-slot") ~= i then
			return false
		end
	end
	return true
end

local function CreateButtons()
	for i = 1, 4 do
		local name = GetButtonName(i)
		local b = _G[name] or CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
		b:SetAttribute("type1", "destroytotem")
		b:SetAttribute("type", "destroytotem")
		b:SetAttribute("totem-slot", i)
	end
	return true
end

local warnedInCombat = false

local function TryInit(reason)
	if not Enabled() then
		return
	end

	if ButtonsExist() then
		return
	end

	if InCombatLockdown() then
		if not warnedInCombat then
			warnedInCombat = true
			if NS and NS.Print then
				NS.Print(
					"Statue kill buttons couldn't be created because you're in combat. Leave combat and /reload, or toggle the feature off/on out of combat."
				)
			else
				print(
					"BetterUI: Statue kill buttons couldn't be created because you're in combat. Leave combat and /reload, or toggle the feature off/on out of combat."
				)
			end
		end
		return
	end

	CreateButtons()

	if not ButtonsExist() then
		if NS and NS.Print then
			NS.Print("Statue kill buttons failed to initialize (unknown reason).")
		end
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	TryInit("PLAYER_LOGIN")
end)

if NS.OnSettingChanged then
	NS.OnSettingChanged(function()
		warnedInCombat = false
		TryInit("SETTING_CHANGED")
	end)
end
