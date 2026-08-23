local ADDON_NAME, NS = ...
local FEATURE_NAME = "MythicPlusTweaks"

-- Challenge Mode map IDs for the current Midnight Mythic+ dungeon pool.
local portalSpellsByChallengeMapID = {
	[161] = 1254557, -- Skyreach
	[239] = 1254551, -- Seat of the Triumvirate
	[249] = 1286831, -- King's Rest
	[250] = 1286828, -- Temple of Sethraliss
	[399] = 393256, -- Ruby Life Pools
	[402] = 393273, -- Algeth'ar Academy
	[556] = 1254555, -- Pit of Saron
	[557] = 1254400, -- Windrunner Spire
	[558] = 1254572, -- Magisters' Terrace
	[559] = 1254563, -- Nexus-Point Xenas
	[560] = 1254559, -- Maisara Caverns
	[584] = 1286801, -- The Blinding Vale
	[585] = 1286804, -- Voidscar Arena
	[586] = 1286807, -- Den of Nalorakk
	[587] = 1286809, -- Murder Row
	[588] = 1286812, -- Altar of Fangs
}

local Portals = {}
Portals.__index = Portals

local function IsEnabled()
	local db = _G.BetterUIDB or NS.DB or {}
	return db.enableMythicPlusTweaks == true
end

local function ShowRunStats()
	local db = _G.BetterUIDB or NS.DB or {}
	return db.mythicPlusShowRunStats == true
end

local function HighlightOwnedKeystone()
	local db = _G.BetterUIDB or NS.DB or {}
	return db.mythicPlusHighlightOwnedKeystone == true
end

local function FormatDuration(sec)
	if not sec or sec <= 0 then
		return nil
	end

	if SecondsToClock then
		return SecondsToClock(sec, false)
	end

	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

function Portals:GetPortalSpell(icon)
	if not icon or not icon.mapID then
		return nil
	end

	return portalSpellsByChallengeMapID[icon.mapID]
end

function Portals:CreateButton(icon)
	if icon.BetterUIPortalButton or InCombatLockdown() then
		return icon.BetterUIPortalButton
	end

	local button = CreateFrame("Button", nil, icon, "SecureActionButtonTemplate")
	button:SetAllPoints(icon)
	button:SetFrameLevel(icon:GetFrameLevel() + 10)
	button:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
	button.parentIcon = icon

	button:SetScript("OnEnter", function(self)
		local onEnter = self.parentIcon:GetScript("OnEnter")
		if onEnter then
			onEnter(self.parentIcon)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function(self)
		local onLeave = self.parentIcon:GetScript("OnLeave")
		if onLeave then
			onLeave(self.parentIcon)
		else
			GameTooltip:Hide()
		end
	end)
	button:Hide()

	icon.BetterUIPortalButton = button
	return button
end

function Portals:CreateStatsLines(icon)
	if InCombatLockdown() then
		return false
	end

	if not icon.BetterUIStatsTime then
		-- Level row is Blizzard's own HighestLevel label; we only add time and score.
		icon.BetterUIStatsTime = icon:CreateFontString(nil, "OVERLAY", "SystemFont_Huge1_Outline")
		icon.BetterUIStatsTime:SetPoint("CENTER", icon, "CENTER")

		icon.BetterUIStatsScore = icon:CreateFontString(nil, "OVERLAY", "SystemFont_Huge1_Outline")
		icon.BetterUIStatsScore:SetPoint("BOTTOM", icon, "BOTTOM", 0, 3)
	end

	self:SyncStatsFont(icon)
	return true
end

function Portals:SyncStatsFont(icon)
	local reference = icon.HighestLevel
	if not reference or not reference.GetFont then
		return
	end

	local path, size, flags = reference:GetFont()
	if not path or not size then
		return
	end

	icon.BetterUIStatsScore:SetFont(path, size, flags)

	-- Time is rendered slightly smaller than level/score.
	local timeSize = math.max(8, math.floor(size * 0.7 + 0.5))
	icon.BetterUIStatsTime:SetFont(path, timeSize, flags)
end

function Portals:HideStatsLines(icon)
	if icon.BetterUIStatsTime then
		icon.BetterUIStatsTime:Hide()
	end
	if icon.BetterUIStatsScore then
		icon.BetterUIStatsScore:Hide()
	end
end

function Portals:GetMapScoreColor(score)
	local color =
		C_ChallengeMode
		and C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor
		and C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(score)

	return color or HIGHLIGHT_FONT_COLOR
end

function Portals:UpdateStats(icon, showStats)
	if not showStats then
		self:HideStatsLines(icon)
		return
	end

	if not self:CreateStatsLines(icon) then
		return
	end

	local canQuery = icon.mapID ~= nil
		and C_MythicPlus
		and C_MythicPlus.GetSeasonBestForMap ~= nil

	if not canQuery then
		self:HideStatsLines(icon)
		return
	end

	local intimeInfo, overtimeInfo = C_MythicPlus.GetSeasonBestForMap(icon.mapID)
	local info = intimeInfo or overtimeInfo

	if not info or ((info.level or 0) <= 0 and (info.dungeonScore or 0) <= 0) then
		self:HideStatsLines(icon)
		return
	end

	local overallScore
	if C_MythicPlus.GetSeasonBestAffixScoreInfoForMap then
		_, overallScore = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(icon.mapID)
	end
	overallScore = overallScore or info.dungeonScore or 0

	local scoreColor = self:GetMapScoreColor(overallScore)

	-- Middle: clear time.
	local durationText = FormatDuration(info.durationSec)
	if durationText then
		if intimeInfo then
			icon.BetterUIStatsTime:SetText(durationText)
		else
			icon.BetterUIStatsTime:SetText("+" .. durationText)
		end
		icon.BetterUIStatsTime:SetTextColor(1, 1, 1)
		icon.BetterUIStatsTime:Show()
	else
		icon.BetterUIStatsTime:Hide()
	end

	-- Bottom: dungeon score.
	icon.BetterUIStatsScore:SetText(tostring(overallScore))
	icon.BetterUIStatsScore:SetTextColor(scoreColor.r, scoreColor.g, scoreColor.b)
	icon.BetterUIStatsScore:Show()
end

function Portals:GetOwnedKeystoneInfo()
	if not C_MythicPlus then
		return nil, nil
	end

	local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID
		and C_MythicPlus.GetOwnedKeystoneChallengeMapID()
	local level = C_MythicPlus.GetOwnedKeystoneLevel
		and C_MythicPlus.GetOwnedKeystoneLevel()

	return mapID, level
end

function Portals:CreateKeystoneBorder(icon)
	if icon.BetterUIKeystoneBorder then
		return icon.BetterUIKeystoneBorder
	end

	local border = CreateFrame("Frame", nil, icon)
	border:SetAllPoints(icon)
	border:SetFrameLevel(icon:GetFrameLevel() + 9)
	border:EnableMouse(false)

	local function CreateEdge()
		local edge = border:CreateTexture(nil, "OVERLAY")
		edge:SetColorTexture(1, 0.82, 0, 1)
		return edge
	end

	local top = CreateEdge()
	top:SetPoint("TOPLEFT")
	top:SetPoint("TOPRIGHT")
	top:SetHeight(2)

	local bottom = CreateEdge()
	bottom:SetPoint("BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT")
	bottom:SetHeight(2)

	local left = CreateEdge()
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	left:SetWidth(2)

	local right = CreateEdge()
	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")
	right:SetWidth(2)

	border:Hide()
	icon.BetterUIKeystoneBorder = border
	return border
end

function Portals:UpdateKeystoneHighlight(icon)
	local border = self:CreateKeystoneBorder(icon)
	local mapID = self:GetOwnedKeystoneInfo()
	border:SetShown(IsEnabled() and HighlightOwnedKeystone() and icon.mapID == mapID)
end

function Portals:AddDungeonTooltip(icon)
	local lines = {}

	if IsEnabled() and HighlightOwnedKeystone() then
		local mapID, level = self:GetOwnedKeystoneInfo()
		if icon.mapID == mapID and level then
			lines[#lines + 1] = {
				text = ("Your Keystone: +%d"):format(level),
				color = NORMAL_FONT_COLOR,
			}
		end
	end

	local spellID = IsEnabled() and self:GetPortalSpell(icon)
	if spellID and IsPlayerSpell(spellID) and C_Spell and C_Spell.GetSpellCooldown then
		local info = C_Spell.GetSpellCooldown(spellID)
		if info and info.isActive and info.duration > 2 then
			local rate = info.modRate and info.modRate > 0 and info.modRate or 1
			local remaining = info.startTime + (info.duration / rate) - GetTime()
			if remaining > 0 then
				lines[#lines + 1] = {
					text = ("Portal ready in %s"):format(SecondsToTime(remaining, true, false, 2, true)),
					color = LIGHTGRAY_FONT_COLOR,
				}
			end
		end
	end

	if #lines == 0 then
		return
	end

	GameTooltip_AddBlankLineToTooltip(GameTooltip)
	for _, line in ipairs(lines) do
		GameTooltip_AddColoredLine(GameTooltip, line.text, line.color)
	end
	GameTooltip:Show()
end

function Portals:CreatePortalCooldown(icon)
	if icon.BetterUIPortalCooldown then
		return icon.BetterUIPortalCooldown
	end

	local cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
	cooldown:SetAllPoints(icon.Icon or icon)
	cooldown:SetFrameLevel(icon:GetFrameLevel() + 1)
	cooldown:EnableMouse(false)
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetHideCountdownNumbers(true)
	cooldown:SetSwipeColor(0, 0, 0, 0.3)
	cooldown:Hide()

	icon.BetterUIPortalCooldown = cooldown
	return cooldown
end

function Portals:UpdatePortalCooldown(icon, spellID, isLearned)
	local cooldown = icon.BetterUIPortalCooldown
	if not (IsEnabled() and spellID and isLearned and C_Spell and C_Spell.GetSpellCooldown) then
		if cooldown then
			cooldown:Hide()
		end
		return
	end

	local info = C_Spell.GetSpellCooldown(spellID)
	if not info or not info.isActive or info.duration <= 2 then
		if cooldown then
			cooldown:Hide()
		end
		return
	end

	cooldown = cooldown or self:CreatePortalCooldown(icon)
	cooldown:SetCooldown(info.startTime, info.duration, info.modRate)
	cooldown:Show()
end

function Portals:UpdateIcon(icon)
	if InCombatLockdown() then
		self.pendingUpdate = true
		return
	end

	local button = self:CreateButton(icon)
	if not button then
		return
	end

	self:UpdateStats(icon, IsEnabled() and ShowRunStats())
	self:UpdateKeystoneHighlight(icon)

	local spellID = self:GetPortalSpell(icon)
	if not IsEnabled() or not spellID then
		self:UpdatePortalCooldown(icon, spellID, false)
		if icon.Icon then
			icon.Icon:SetDesaturated(false)
		end
		button:Hide()
		return
	end

	local isLearned = IsPlayerSpell(spellID)
	if icon.Icon then
		icon.Icon:SetDesaturated(not isLearned)
	end
	self:UpdatePortalCooldown(icon, spellID, isLearned)
	button:SetAttribute("type1", isLearned and "spell" or nil)
	button:SetAttribute("spell1", isLearned and spellID or nil)
	button:EnableMouse(isLearned)
	button:Show()
end

function Portals:UpdateVisibleIcons()
	if InCombatLockdown() then
		self.pendingUpdate = true
		return
	end

	if not ChallengesFrame or not ChallengesFrame.DungeonIcons then
		return
	end

	for i = 1, #ChallengesFrame.DungeonIcons do
		self:UpdateIcon(ChallengesFrame.DungeonIcons[i])
	end

	self.pendingUpdate = nil
end

function Portals:InstallHook()
	if self.hooked or not ChallengesDungeonIconMixin then
		return
	end

	self.hooked = true
	hooksecurefunc(ChallengesDungeonIconMixin, "SetUp", function(icon)
		self:UpdateIcon(icon)
	end)
	hooksecurefunc(ChallengesDungeonIconMixin, "OnEnter", function(icon)
		self:AddDungeonTooltip(icon)
	end)
	self:UpdateVisibleIcons()
end

function Portals:InstallLoaderHook()
	if self.loaderHooked or not ChallengeMode_LoadUI then
		return
	end

	self.loaderHooked = true
	hooksecurefunc("ChallengeMode_LoadUI", function()
		-- Blizzard defines ChallengesDungeonIconMixin while loading this addon.
		C_Timer.After(0, function()
			self:InstallHook()
			self:UpdateVisibleIcons()
		end)
	end)
end

function Portals:OnEvent(event, addonName)
	if event == "ADDON_LOADED" and addonName == "Blizzard_ChallengesUI" then
		self:InstallHook()
	elseif event == "PLAYER_REGEN_ENABLED" and self.pendingUpdate then
		self:UpdateVisibleIcons()
	elseif event == "SPELLS_CHANGED" or event == "SPELL_UPDATE_COOLDOWN" or event == "CHALLENGE_MODE_MAPS_UPDATE" then
		self:UpdateVisibleIcons()
	elseif event == "BAG_UPDATE" then
		self:UpdateVisibleIcons()
	end
end

function Portals:Enable()
	if not self.eventFrame then
		self.eventFrame = CreateFrame("Frame")
		self.eventFrame:RegisterEvent("ADDON_LOADED")
		self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		self.eventFrame:RegisterEvent("SPELLS_CHANGED")
		self.eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		self.eventFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
		self.eventFrame:RegisterEvent("BAG_UPDATE")
		self.eventFrame:SetScript("OnEvent", function(_, event, ...)
			self:OnEvent(event, ...)
		end)
	end

	self:InstallLoaderHook()
	self:InstallHook()
	self:UpdateVisibleIcons()

	if not self.settingListenerAdded then
		self.settingListenerAdded = true
		NS.OnSettingChanged(function()
			self:UpdateVisibleIcons()
		end)
	end
end

function Portals:Disable()
	self:UpdateVisibleIcons()
end

NS.Features[FEATURE_NAME] = setmetatable({}, Portals)
