local ADDON_NAME, NS = ...

local FEATURE_NAME = "PlayerCastBar"
local DEFAULT_WIDTH = 240
local DEFAULT_HEIGHT = 18
local MIN_WIDTH = 150
local MAX_WIDTH = 500
local MIN_HEIGHT = 10
local MAX_HEIGHT = 40
local BORDER_SIZE = 2

local Feature = NS.Features[FEATURE_NAME] or {}
NS.Features[FEATURE_NAME] = Feature

local eventFrame = CreateFrame("Frame")
local hiddenRegions = {
	"Border",
	"BorderShield",
	"DropShadow",
	"Icon",
	"TextBorder",
}
local glowRegions = {
	"BaseGlow",
	"ChargeFlash",
	"ChargeGlow",
	"ChannelShadow",
	"EnergyGlow",
	"Flakes01",
	"Flakes02",
	"Flakes03",
	"Flash",
	"InterruptGlow",
	"Sparkles01",
	"Sparkles02",
	"StandardGlow",
	"WispGlow",
}

local function Clamp(value, minimum, maximum, fallback)
	value = tonumber(value) or fallback
	return math.max(minimum, math.min(maximum, value))
end

local function CapturePoints(region)
	local points = {}
	for i = 1, region:GetNumPoints() do
		points[i] = { region:GetPoint(i) }
	end
	return points
end

local function RestorePoints(region, points)
	region:ClearAllPoints()
	for i = 1, #points do
		region:SetPoint(unpack(points[i]))
	end
end

local function SetRegionShown(region, shown)
	if region then
		region:SetShown(shown)
	end
end

local function RefreshManagedLayout(frame)
	if frame.layoutParent and frame.layoutParent.Layout then
		frame.layoutParent:Layout()
	end
end

local function CaptureCastTimeState(frame)
	if Feature._savedState then
		return
	end

	Feature._savedState = {
		showCastTimeSetting = frame.showCastTimeSetting,
		sparkWidth = frame.Spark and frame.Spark:GetWidth(),
		sparkHeight = frame.Spark and frame.Spark:GetHeight(),
		channelShadowWidth = frame.ChannelShadow and frame.ChannelShadow:GetWidth(),
		channelShadowHeight = frame.ChannelShadow and frame.ChannelShadow:GetHeight(),
		standardGlowWidth = frame.StandardGlow and frame.StandardGlow:GetWidth(),
		standardGlowHeight = frame.StandardGlow and frame.StandardGlow:GetHeight(),
		borderMaskWidth = frame.BorderMask and frame.BorderMask:GetWidth(),
		borderMaskHeight = frame.BorderMask and frame.BorderMask:GetHeight(),
		fillHeight = frame:GetStatusBarTexture() and frame:GetStatusBarTexture():GetHeight(),
		castTimePoints = frame.CastTimeText and CapturePoints(frame.CastTimeText),
		castTimeFontObject = frame.CastTimeText and frame.CastTimeText:GetFontObject(),
		castTimeJustifyH = frame.CastTimeText and frame.CastTimeText:GetJustifyH(),
	}
end

local function EnsureCustomRegions(frame)
	if Feature._edges then
		return
	end

	Feature._edges = {}
	for i = 1, 4 do
		local edge = frame:CreateTexture(nil, "OVERLAY", nil, 7)
		edge:SetColorTexture(0, 0, 0, 1)
		Feature._edges[i] = edge
	end

	Feature._edges[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
	Feature._edges[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 1)
	Feature._edges[1]:SetHeight(BORDER_SIZE)
	Feature._edges[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -1, -1)
	Feature._edges[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
	Feature._edges[2]:SetHeight(BORDER_SIZE)
	Feature._edges[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
	Feature._edges[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -1, -1)
	Feature._edges[3]:SetWidth(BORDER_SIZE)
	Feature._edges[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 1)
	Feature._edges[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
	Feature._edges[4]:SetWidth(BORDER_SIZE)
end

local function SetCustomRegionsShown(shown)
	if Feature._edges then
		for i = 1, #Feature._edges do
			Feature._edges[i]:SetShown(shown)
		end
	end
end

local function FitNativeFill(frame, height)
	local texture = frame:GetStatusBarTexture()
	if texture then
		texture:SetHeight(height)
	end
end

local function GlowAnimationsDisabled()
	return (_G.BetterUIDB or NS.DB or {}).playerCastBarDisableGlowAnimations and true or false
end

local function SuppressGlowRegion(region)
	if not region then
		return
	end

	Feature._glowVertexColors = Feature._glowVertexColors or setmetatable({}, { __mode = "k" })
	if not Feature._glowVertexColors[region] then
		Feature._glowVertexColors[region] = { region:GetVertexColor() }
	end

	local red, green, blue = region:GetVertexColor()
	region:SetVertexColor(red, green, blue, 0)
end

local function RestoreGlowRegions()
	if not Feature._glowVertexColors then
		return
	end

	for region, color in pairs(Feature._glowVertexColors) do
		region:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
	end
	wipe(Feature._glowVertexColors)
end

local function SuppressGlowAnimations(frame)
	if not GlowAnimationsDisabled() then
		RestoreGlowRegions()
		return
	end

	for i = 1, #glowRegions do
		SuppressGlowRegion(frame[glowRegions[i]])
	end

	for i = 1, #frame.StagePips do
		local pip = frame.StagePips[i]
		SuppressGlowRegion(pip.PipGlow)
		SuppressGlowRegion(pip.FlakesBottom)
		SuppressGlowRegion(pip.FlakesTop)
		SuppressGlowRegion(pip.FlakesTop02)
		SuppressGlowRegion(pip.FlakesBottom02)
	end
	for i = 1, #frame.StageTiers do
		SuppressGlowRegion(frame.StageTiers[i].Glow)
	end
end

local function ApplyCosmeticLayout(frame, width, height)
	for i = 1, #hiddenRegions do
		SetRegionShown(frame[hiddenRegions[i]], false)
	end
	SetCustomRegionsShown(true)
	if frame.Spark then
		local saved = Feature._savedState
		local aspect = saved and saved.sparkWidth and saved.sparkHeight and saved.sparkHeight > 0
			and saved.sparkWidth / saved.sparkHeight
			or 0.4
		frame.Spark:SetSize(height * aspect, height)
	end
	if frame.ChannelShadow then
		local saved = Feature._savedState
		local aspect = saved and saved.channelShadowWidth and saved.channelShadowHeight and saved.channelShadowHeight > 0
			and saved.channelShadowWidth / saved.channelShadowHeight
			or 1
		frame.ChannelShadow:SetSize(height * aspect, height)
	end
	if frame.StandardGlow then
		local saved = Feature._savedState
		local aspect = saved and saved.standardGlowWidth and saved.standardGlowHeight and saved.standardGlowHeight > 0
			and saved.standardGlowWidth / saved.standardGlowHeight
			or (37 / 12)
		frame.StandardGlow:SetSize(height * aspect, height)
	end
	if frame.BorderMask then
		local saved = Feature._savedState
		local nativeWidth = saved and saved.borderMaskWidth or 256
		local nativeHeight = saved and saved.borderMaskHeight or 13
		frame.BorderMask:SetSize(math.max(nativeWidth, width + 48), math.max(nativeHeight, height + 2))
	end
	FitNativeFill(frame, height)
	SuppressGlowAnimations(frame)

	if frame.CastTimeText then
		frame.CastTimeText:ClearAllPoints()
		frame.CastTimeText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, 0)
		frame.CastTimeText:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -math.max(42, math.min(72, width * 0.25)), 0)
		frame.CastTimeText:SetJustifyH("RIGHT")
		frame.CastTimeText:SetFontObject(_G.SystemFont_NamePlateCastBar or GameFontHighlightSmall)
	end

	if frame.Text then
		frame.Text:ClearAllPoints()
		frame.Text:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, 0)
		frame.Text:SetPoint("BOTTOMRIGHT", frame.CastTimeText or frame, frame.CastTimeText and "BOTTOMLEFT" or "BOTTOMRIGHT", -5, 0)
		frame.Text:SetJustifyH("CENTER")
		frame.Text:SetFontObject(_G.SystemFont_NamePlateCastBar or GameFontHighlightSmall)
	end
end

function Feature:ApplyStyle()
	if not self._enabled or not PlayerCastingBarFrame then
		return
	end
	local frame = PlayerCastingBarFrame
	local db = _G.BetterUIDB or NS.DB or {}
	local width = Clamp(db.playerCastBarWidth, MIN_WIDTH, MAX_WIDTH, DEFAULT_WIDTH)
	local height = Clamp(db.playerCastBarHeight, MIN_HEIGHT, MAX_HEIGHT, DEFAULT_HEIGHT)

	CaptureCastTimeState(frame)
	if InCombatLockdown() or frame.reverseChanneling then
		self._pendingApply = true
		if self._edges then
			ApplyCosmeticLayout(frame, frame:GetWidth(), frame:GetHeight())
		end
		return
	end

	self._pendingApply = false
	EnsureCustomRegions(frame)
	self._settingSize = true
	frame:SetSize(width, height)
	RefreshManagedLayout(frame)
	self._settingSize = false
	frame.showIcon = false
	ApplyCosmeticLayout(frame, width, height)
	frame:SetCastTimeTextShown(true)
end

function Feature:RestoreStyle()
	local frame = PlayerCastingBarFrame
	local saved = self._savedState
	if not frame or not saved then
		return
	end

	frame.showIcon = true
	frame:SetLook(frame.look or (frame.attachedToPlayerFrame and "UNITFRAME" or "CLASSIC"))
	if frame.UpdateSystemSettingBarSize then
		frame:UpdateSystemSettingBarSize()
	end
	RefreshManagedLayout(frame)
	SetRegionShown(frame.Border, true)
	frame:UpdateIconShown()
	SetCustomRegionsShown(false)
	if frame.Spark and saved.sparkWidth and saved.sparkHeight then
		frame.Spark:SetSize(saved.sparkWidth, saved.sparkHeight)
	end
	if frame.ChannelShadow and saved.channelShadowWidth and saved.channelShadowHeight then
		frame.ChannelShadow:SetSize(saved.channelShadowWidth, saved.channelShadowHeight)
	end
	if frame.StandardGlow and saved.standardGlowWidth and saved.standardGlowHeight then
		frame.StandardGlow:SetSize(saved.standardGlowWidth, saved.standardGlowHeight)
	end
	if frame.BorderMask and saved.borderMaskWidth and saved.borderMaskHeight then
		frame.BorderMask:SetSize(saved.borderMaskWidth, saved.borderMaskHeight)
	end
	if saved.fillHeight then
		FitNativeFill(frame, saved.fillHeight)
	end

	if frame.CastTimeText then
		RestorePoints(frame.CastTimeText, saved.castTimePoints)
		if saved.castTimeFontObject then
			frame.CastTimeText:SetFontObject(saved.castTimeFontObject)
		end
		frame.CastTimeText:SetJustifyH(saved.castTimeJustifyH or "LEFT")
	end

	if frame.UpdateSystemSettingShowCastTime then
		frame:UpdateSystemSettingShowCastTime()
	else
		frame.showCastTimeSetting = saved.showCastTimeSetting
		frame:UpdateCastTimeTextShown()
	end
	RestoreGlowRegions()
	self._savedState = nil
end

function Feature:InstallHooks()
	if self._hooksInstalled or not PlayerCastingBarFrame then
		return
	end

	self._hooksInstalled = true
	hooksecurefunc(PlayerCastingBarFrame, "SetLook", function()
		if Feature._enabled then
			Feature:ApplyStyle()
		end
	end)
	hooksecurefunc(PlayerCastingBarFrame, "UpdateShownState", function(frame)
		if Feature._enabled and Feature._edges then
			ApplyCosmeticLayout(frame, frame:GetWidth(), frame:GetHeight())
		end
	end)
	hooksecurefunc(PlayerCastingBarFrame, "UpdateBarFillTexture", function(frame)
		if Feature._enabled then
			FitNativeFill(frame, frame:GetHeight())
		end
	end)
	local function RefreshGlowPreference(frame)
		if Feature._enabled then
			SuppressGlowAnimations(frame)
		end
	end
	hooksecurefunc(PlayerCastingBarFrame, "ShowSpark", RefreshGlowPreference)
	hooksecurefunc(PlayerCastingBarFrame, "AddStages", RefreshGlowPreference)
	hooksecurefunc(PlayerCastingBarFrame, "PlayFadeAnim", function(frame)
		if Feature._enabled and GlowAnimationsDisabled() then
			if frame.FlashAnim then
				frame.FlashAnim:Stop()
			end
			SetRegionShown(frame.Flash, false)
			SuppressGlowAnimations(frame)
		end
	end)
	hooksecurefunc(PlayerCastingBarFrame, "PlayInterruptAnims", function(frame)
		if Feature._enabled and GlowAnimationsDisabled() then
			if frame.InterruptGlowAnim then
				frame.InterruptGlowAnim:Stop()
			end
			if frame.InterruptGlow then
				frame.InterruptGlow:SetAlpha(0)
			end
			SuppressGlowAnimations(frame)
		end
	end)
	hooksecurefunc(PlayerCastingBarFrame, "PlayFinishAnim", function(frame)
		if Feature._enabled and GlowAnimationsDisabled() then
			local finishAnimationKeys = { "StandardFinish", "CraftingFinish", "ChannelFinish" }
			for i = 1, #finishAnimationKeys do
				local animation = frame[finishAnimationKeys[i]]
				if animation then
					animation:Stop()
				end
			end
			for i = 1, #frame.StageTiers do
				if frame.StageTiers[i].FinishAnim then
					frame.StageTiers[i].FinishAnim:Stop()
				end
			end
			SuppressGlowAnimations(frame)
		end
	end)
	local function QueueSizeCorrection()
		if not Feature._enabled or Feature._settingSize or Feature._sizeCorrectionQueued then
			return
		end

		Feature._sizeCorrectionQueued = true
		C_Timer.After(0, function()
			Feature._sizeCorrectionQueued = false
			if Feature._enabled then
				Feature:ApplyStyle()
			end
		end)
	end
	hooksecurefunc(PlayerCastingBarFrame, "SetSize", QueueSizeCorrection)
	hooksecurefunc(PlayerCastingBarFrame, "SetWidth", QueueSizeCorrection)
	hooksecurefunc(PlayerCastingBarFrame, "SetHeight", QueueSizeCorrection)
end

function Feature:TryAttach()
	if not PlayerCastingBarFrame then
		return false
	end

	self:InstallHooks()
	self:ApplyStyle()
	return true
end

function Feature:Enable()
	self._enabled = true
	self._pendingDisable = false
	self:TryAttach()

	if not self._settingListenerAdded then
		self._settingListenerAdded = true
		NS.OnSettingChanged(function()
			if Feature._enabled then
				Feature:ApplyStyle()
			end
		end)
	end
end

function Feature:Disable()
	if not self._enabled then
		return
	end
	if InCombatLockdown() or (PlayerCastingBarFrame and PlayerCastingBarFrame.reverseChanneling) then
		self._pendingDisable = true
		return
	end

	self._enabled = false
	self._pendingApply = false
	self._pendingDisable = false
	self:RestoreStyle()
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "player")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON_NAME and arg1 ~= "Blizzard_UIPanels_Game" then
			return
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if Feature._pendingDisable then
			Feature:Disable()
			return
		end
		if not Feature._pendingApply then
			return
		end
	elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
		C_Timer.After(1.4, function()
			local shouldDisable = Feature._pendingDisable
			local shouldApply = Feature._enabled and Feature._pendingApply
			if (not shouldDisable and not shouldApply) or InCombatLockdown() then
				return
			end

			local frame = PlayerCastingBarFrame
			if frame and frame.reverseChanneling then
				return
			end
			if shouldDisable then
				Feature:Disable()
			elseif shouldApply then
				Feature:ApplyStyle()
			end
		end)
		return
	elseif event == "PLAYER_ENTERING_WORLD" or event == "EDIT_MODE_LAYOUTS_UPDATED" or event == "UI_SCALE_CHANGED" then
		C_Timer.After(0, function()
			if Feature._enabled then
				Feature:TryAttach()
			end
		end)
		return
	end

	if Feature._enabled then
		Feature:TryAttach()
	end
end)
