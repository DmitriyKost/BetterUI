local ADDON_NAME, NS = ...

local FEATURE_NAME = "PlayerCastBar"

local DEFAULT_WIDTH = 240
local DEFAULT_HEIGHT = 18

local MIN_WIDTH = 150
local MAX_WIDTH = 500

local MIN_HEIGHT = 10
local MAX_HEIGHT = 40

local BORDER_SIZE = 2
local FILL_HORIZONTAL_CROP = 0.035
local SPARK_VISIBLE_WIDTH = 2
local RUNTIME_REFRESH_FRAMES = 3
local STRUCTURAL_SETTLE_SECONDS = 1.25

local Feature = NS.Features[FEATURE_NAME] or {}
NS.Features[FEATURE_NAME] = Feature

local eventFrame = CreateFrame("Frame")
local runtimeDriver = CreateFrame("Frame")
local structuralDriver = CreateFrame("Frame")
runtimeDriver:Hide()
structuralDriver:Hide()

local hiddenRegions = {
	"Border",
	"BorderShield",
	"DropShadow",
	"Icon",
	"TextBorder",
}

local nativeLookRegions = {
	"BorderShield",
	"DropShadow",
	"Icon",
	"TextBorder",
}

local function Clamp(value, minimum, maximum, fallback)
	value = tonumber(value) or fallback
	return math.max(minimum, math.min(maximum, value))
end

local function GetDesiredSize()
	local db = _G.BetterUIDB or NS.DB or {}

	local width = Clamp(db.playerCastBarWidth, MIN_WIDTH, MAX_WIDTH, DEFAULT_WIDTH)

	local height = Clamp(db.playerCastBarHeight, MIN_HEIGHT, MAX_HEIGHT, DEFAULT_HEIGHT)

	return width, height
end

local function CapturePoints(region)
	local points = {}

	for i = 1, region:GetNumPoints() do
		points[i] = { region:GetPoint(i) }
	end

	return points
end

local function RestorePoints(region, points)
	if not region or not points then
		return
	end

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

local function IsEditModeActive()
	if not EditModeManagerFrame then
		return false
	end

	if EditModeManagerFrame.IsEditModeActive then
		return EditModeManagerFrame:IsEditModeActive()
	end

	return EditModeManagerFrame:IsShown()
end

local function IsStructuralUpdateBlocked(frame)
	return InCombatLockdown() or IsEditModeActive() or (frame and frame.reverseChanneling)
end

local function CaptureFadeAnimationState(frame)
	local state = {}

	if frame.FadeOutAnim then
		for _, animation in ipairs({ frame.FadeOutAnim:GetAnimations() }) do
			state[#state + 1] = { animation = animation, duration = animation:GetDuration() }
		end
	end

	if frame.HoldFadeOutAnim then
		for _, animation in ipairs({ frame.HoldFadeOutAnim:GetAnimations() }) do
			if animation:GetOrder() == 2 then
				state[#state + 1] = { animation = animation, duration = animation:GetDuration() }
			end
		end
	end

	return state
end

local function SetFadeAnimationDurations(state, duration)
	for i = 1, #(state or {}) do
		local saved = state[i]
		saved.animation:SetDuration(duration or saved.duration)
	end
end

local function CaptureState(frame)
	if Feature._savedState then
		return
	end

	local hiddenRegionShown = {}

	for i = 1, #hiddenRegions do
		local key = hiddenRegions[i]
		local region = frame[key]

		if region then
			hiddenRegionShown[key] = region:IsShown()
		end
	end

	Feature._savedState = {
		width = frame:GetWidth(),
		height = frame:GetHeight(),
		playCastFX = frame.playCastFX,
		fadeAnimations = CaptureFadeAnimationState(frame),

		hiddenRegionShown = hiddenRegionShown,

		castTimeShown = frame.CastTimeText and frame.CastTimeText:IsShown(),

		sparkWidth = frame.Spark and frame.Spark:GetWidth(),
		sparkHeight = frame.Spark and frame.Spark:GetHeight(),

		channelShadowWidth = frame.ChannelShadow and frame.ChannelShadow:GetWidth(),
		channelShadowHeight = frame.ChannelShadow and frame.ChannelShadow:GetHeight(),

		standardGlowWidth = frame.StandardGlow and frame.StandardGlow:GetWidth(),
		standardGlowHeight = frame.StandardGlow and frame.StandardGlow:GetHeight(),
		standardGlowPoints = frame.StandardGlow and CapturePoints(frame.StandardGlow),
		craftGlowPoints = frame.CraftGlow and CapturePoints(frame.CraftGlow),
		channelShadowPoints = frame.ChannelShadow and CapturePoints(frame.ChannelShadow),

		borderMaskWidth = frame.BorderMask and frame.BorderMask:GetWidth(),
		borderMaskHeight = frame.BorderMask and frame.BorderMask:GetHeight(),

		fillHeight = frame:GetStatusBarTexture() and frame:GetStatusBarTexture():GetHeight(),

		flashVertexColor = frame.Flash and { frame.Flash:GetVertexColor() },
		interruptGlowVertexColor = frame.InterruptGlow and { frame.InterruptGlow:GetVertexColor() },

		castTimePoints = frame.CastTimeText and CapturePoints(frame.CastTimeText),

		castTimeFontObject = frame.CastTimeText and frame.CastTimeText:GetFontObject(),

		castTimeJustifyH = frame.CastTimeText and frame.CastTimeText:GetJustifyH(),

		textPoints = frame.Text and CapturePoints(frame.Text),

		textFontObject = frame.Text and frame.Text:GetFontObject(),

		textJustifyH = frame.Text and frame.Text:GetJustifyH(),
	}
end

local function RefreshSavedNativeStateAfterEditMode(frame)
	local saved = Feature._savedState

	if not saved or not frame then
		return
	end

	-- Edit Mode can switch the cast bar between CLASSIC and UNITFRAME looks.
	-- Blizzard's SetLook() rewrites frame size plus Text anchors/font and
	-- several look-controlled region visibilities. Refresh only those values
	-- while the frame is in its native post-Edit-Mode state, before BetterUI
	-- reapplies its cosmetics.
	saved.width = frame:GetWidth()
	saved.height = frame:GetHeight()
	saved.playCastFX = frame.playCastFX

	if frame.Text then
		saved.textPoints = CapturePoints(frame.Text)
		saved.textFontObject = frame.Text:GetFontObject()
		saved.textJustifyH = frame.Text:GetJustifyH()
	end

	if frame.CastTimeText then
		saved.castTimeShown = frame.CastTimeText:IsShown()
	end

	if saved.hiddenRegionShown then
		for i = 1, #nativeLookRegions do
			local key = nativeLookRegions[i]
			local region = frame[key]

			if region then
				saved.hiddenRegionShown[key] = region:IsShown()
			end
		end
	end
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

	local top = Feature._edges[1]
	top:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
	top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 1)
	top:SetHeight(BORDER_SIZE)

	local bottom = Feature._edges[2]
	bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -1, -1)
	bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
	bottom:SetHeight(BORDER_SIZE)

	local left = Feature._edges[3]
	left:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
	left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -1, -1)
	left:SetWidth(BORDER_SIZE)

	local right = Feature._edges[4]
	right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 1)
	right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
	right:SetWidth(BORDER_SIZE)
end

local function SetCustomRegionsShown(shown)
	if not Feature._edges then
		return
	end

	for i = 1, #Feature._edges do
		Feature._edges[i]:SetShown(shown)
	end
end

local function CaptureTexCoords(texture)
	if not texture then
		return nil
	end

	return { texture:GetTexCoord() }
end

local function TexCoordsEqual(left, right)
	if not left or not right or #left ~= #right then
		return false
	end

	for i = 1, #left do
		if math.abs((left[i] or 0) - (right[i] or 0)) > 0.000001 then
			return false
		end
	end

	return true
end

local function CropHorizontalTexCoords(coords, fraction)
	if not coords then
		return nil
	end

	if #coords >= 8 then
		local ulx, uly = coords[1], coords[2]
		local llx, lly = coords[3], coords[4]
		local urx, ury = coords[5], coords[6]
		local lrx, lry = coords[7], coords[8]

		local function Lerp(from, to, amount)
			return from + ((to - from) * amount)
		end

		return {
			Lerp(ulx, urx, fraction),
			Lerp(uly, ury, fraction),
			Lerp(llx, lrx, fraction),
			Lerp(lly, lry, fraction),
			Lerp(urx, ulx, fraction),
			Lerp(ury, uly, fraction),
			Lerp(lrx, llx, fraction),
			Lerp(lry, lly, fraction),
		}
	end

	if #coords >= 4 then
		local left, right, top, bottom = coords[1], coords[2], coords[3], coords[4]
		local width = right - left

		return {
			left + (width * fraction),
			right - (width * fraction),
			top,
			bottom,
		}
	end

	return coords
end

local function SquareNativeFill(frame)
	local texture = frame and frame:GetStatusBarTexture()

	if not texture then
		return
	end

	local current = CaptureTexCoords(texture)
	local lastApplied = Feature._lastAppliedFillTexCoords

	-- Blizzard resets the status-bar texture/atlas when the cast type changes
	-- and again on successful completion. Capture that fresh native mapping,
	-- but do not recursively crop our own already-cropped coordinates.
	if not Feature._nativeFillTexCoords or not TexCoordsEqual(current, lastApplied) then
		Feature._nativeFillTexCoords = current
	end

	local cropped = CropHorizontalTexCoords(Feature._nativeFillTexCoords, FILL_HORIZONTAL_CROP)

	if cropped then
		texture:SetTexCoord(unpack(cropped))
		Feature._lastAppliedFillTexCoords = cropped
	end
end

local function RestoreNativeFillTexCoords(frame)
	local texture = frame and frame:GetStatusBarTexture()
	local native = Feature._nativeFillTexCoords
	local lastApplied = Feature._lastAppliedFillTexCoords

	if texture and native and lastApplied then
		local current = CaptureTexCoords(texture)

		-- Restore only if the current mapping is still ours. If Blizzard has
		-- already switched to another atlas, leave its fresh mapping alone.
		if TexCoordsEqual(current, lastApplied) then
			texture:SetTexCoord(unpack(native))
		end
	end

	Feature._nativeFillTexCoords = nil
	Feature._lastAppliedFillTexCoords = nil
end

local function FitNativeFill(frame, height)
	local texture = frame:GetStatusBarTexture()

	if texture then
		texture:SetHeight(height)
		SquareNativeFill(frame)
	end
end

local function SuppressAdditiveBorderGlow(region)
	if not region then
		return
	end

	local _, _, _, alpha = region:GetVertexColor()
	region:SetVertexColor(0, 0, 0, alpha or 1)
end

local function RestoreVertexColor(region, color)
	if region and color then
		region:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
	end
end

local function SetOutlinedFontObject(region, fontObject)
	if not region or not fontObject then
		return
	end

	-- Apply the FontObject first so we retain its locale-specific font,
	-- size, color/shadow defaults and any font replacement made by another
	-- addon. Then enforce only the outline flag locally on this FontString.
	region:SetFontObject(fontObject)

	local fontFile, fontHeight, flags = region:GetFont()

	if not fontFile or not fontHeight then
		return
	end

	if flags and flags:find("OUTLINE", 1, true) then
		return
	end

	if flags and flags ~= "" then
		flags = flags .. ",OUTLINE"
	else
		flags = "OUTLINE"
	end

	region:SetFont(fontFile, fontHeight, flags)
end

local function ApplyTextLayout(frame, width)
	if frame.CastTimeText then
		frame.CastTimeText:ClearAllPoints()

		frame.CastTimeText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, 0)

		frame.CastTimeText:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -math.max(42, math.min(72, width * 0.25)), 0)

		frame.CastTimeText:SetJustifyH("RIGHT")

		SetOutlinedFontObject(frame.CastTimeText, _G.SystemFont_NamePlateCastBar or GameFontHighlightSmall)
	end

	if frame.Text then
		frame.Text:ClearAllPoints()

		frame.Text:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, 0)

		if frame.CastTimeText then
			frame.Text:SetPoint("BOTTOMRIGHT", frame.CastTimeText, "BOTTOMLEFT", -5, 0)
		else
			frame.Text:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 0)
		end

		frame.Text:SetJustifyH("CENTER")

		SetOutlinedFontObject(frame.Text, _G.SystemFont_NamePlateCastBar or GameFontHighlightSmall)
	end
end

local function ApplyRuntimeCosmetics(frame)
	-- Do not mutate child regions before the first stable native snapshot.
	-- This matters when the feature is enabled while combat/Edit Mode blocks
	-- the structural apply: otherwise RestoreStyle() could later restore our
	-- own partially-applied cosmetics as if they were Blizzard defaults.
	if not Feature._enabled or not frame or not Feature._savedState or IsEditModeActive() then
		return
	end

	for i = 1, #hiddenRegions do
		SetRegionShown(frame[hiddenRegions[i]], false)
	end

	frame.playCastFX = false
	SuppressAdditiveBorderGlow(frame.Flash)
	SuppressAdditiveBorderGlow(frame.InterruptGlow)

	if frame.CastTimeText then
		frame.CastTimeText:Show()
	end

	SetCustomRegionsShown(true)

	-- Blizzard SetLook() may reset Text/CastTimeText anchors after our
	-- initial style pass. Reapply only native FontString layout here.
	local width = GetDesiredSize()
	ApplyTextLayout(frame, width)

	FitNativeFill(frame, frame:GetHeight())
end

local function AnchorSparkLinkedRegion(region, points, spark, originalSparkWidth)
	if not region or not points or not points[1] or not spark then
		return
	end

	local point = points[1]
	local anchorPoint = point[1]
	local relativeTo = point[2]
	local relativePoint = point[3]
	local x = point[4] or 0
	local y = point[5] or 0

	if relativeTo ~= spark or relativePoint ~= "LEFT" then
		return
	end

	region:ClearAllPoints()
	region:SetPoint(anchorPoint, spark, "CENTER", x - (originalSparkWidth * 0.5), y)
end

local function ApplyStructuralLayout(frame, width, height)
	local saved = Feature._savedState

	if frame.Spark then
		frame.Spark:SetSize(SPARK_VISIBLE_WIDTH, height)

		local originalSparkWidth = saved and saved.sparkWidth or 8

		AnchorSparkLinkedRegion(frame.StandardGlow, saved and saved.standardGlowPoints, frame.Spark, originalSparkWidth)
		AnchorSparkLinkedRegion(frame.CraftGlow, saved and saved.craftGlowPoints, frame.Spark, originalSparkWidth)
		AnchorSparkLinkedRegion(
			frame.ChannelShadow,
			saved and saved.channelShadowPoints,
			frame.Spark,
			originalSparkWidth
		)
	end

	if frame.ChannelShadow then
		local aspect = saved
				and saved.channelShadowWidth
				and saved.channelShadowHeight
				and saved.channelShadowHeight > 0
				and saved.channelShadowWidth / saved.channelShadowHeight
			or 1

		frame.ChannelShadow:SetSize(height * aspect, height)
	end

	if frame.StandardGlow then
		local aspect = saved
				and saved.standardGlowWidth
				and saved.standardGlowHeight
				and saved.standardGlowHeight > 0
				and saved.standardGlowWidth / saved.standardGlowHeight
			or (37 / 12)

		frame.StandardGlow:SetSize(height * aspect, height)
	end

	if frame.BorderMask then
		local nativeWidth = saved and saved.borderMaskWidth or 256

		local nativeHeight = saved and saved.borderMaskHeight or 13

		frame.BorderMask:SetSize(math.max(nativeWidth, width + 48), math.max(nativeHeight, height + 2))
	end

	ApplyTextLayout(frame, width)
	FitNativeFill(frame, height)
end

function Feature:ApplyStyle()
	if not self._enabled or not PlayerCastingBarFrame then
		return
	end

	local frame = PlayerCastingBarFrame

	if IsStructuralUpdateBlocked(frame) then
		self._pendingApply = true
		return
	end

	-- Capture only a stable Blizzard state. If the feature is enabled while
	-- combat/Edit Mode owns the frame, defer the snapshot together with apply.
	CaptureState(frame)

	local width, height = GetDesiredSize()

	self._pendingApply = false

	EnsureCustomRegions(frame)

	-- Only native widget/region properties are changed here.
	-- Do not call PlayerCastingBarFrame mixin methods that mutate
	-- Blizzard Lua state, and do not invoke managed-layout code.
	frame:SetSize(width, height)
	SetFadeAnimationDurations(self._savedState.fadeAnimations, 0.001)

	ApplyStructuralLayout(frame, width, height)
	ApplyRuntimeCosmetics(frame)
end

function Feature:RestoreStyle(preserveSavedState)
	local frame = PlayerCastingBarFrame
	local saved = self._savedState

	if not frame or not saved then
		return
	end

	SetCustomRegionsShown(false)
	frame.playCastFX = saved.playCastFX
	SetFadeAnimationDurations(saved.fadeAnimations)
	RestoreVertexColor(frame.Flash, saved.flashVertexColor)
	RestoreVertexColor(frame.InterruptGlow, saved.interruptGlowVertexColor)

	if saved.width and saved.height then
		frame:SetSize(saved.width, saved.height)
	end

	if saved.hiddenRegionShown then
		for key, shown in pairs(saved.hiddenRegionShown) do
			SetRegionShown(frame[key], shown)
		end
	end

	if frame.CastTimeText then
		RestorePoints(frame.CastTimeText, saved.castTimePoints)

		if saved.castTimeFontObject then
			frame.CastTimeText:SetFontObject(saved.castTimeFontObject)
		end

		frame.CastTimeText:SetJustifyH(saved.castTimeJustifyH or "LEFT")

		SetRegionShown(frame.CastTimeText, saved.castTimeShown)
	end

	if frame.Text then
		RestorePoints(frame.Text, saved.textPoints)

		if saved.textFontObject then
			frame.Text:SetFontObject(saved.textFontObject)
		end

		frame.Text:SetJustifyH(saved.textJustifyH or "CENTER")
	end

	if frame.Spark and saved.sparkWidth and saved.sparkHeight then
		frame.Spark:SetSize(saved.sparkWidth, saved.sparkHeight)
	end

	if frame.ChannelShadow and saved.channelShadowWidth and saved.channelShadowHeight then
		frame.ChannelShadow:SetSize(saved.channelShadowWidth, saved.channelShadowHeight)
	end

	if frame.StandardGlow and saved.standardGlowWidth and saved.standardGlowHeight then
		frame.StandardGlow:SetSize(saved.standardGlowWidth, saved.standardGlowHeight)
	end

	RestorePoints(frame.StandardGlow, saved.standardGlowPoints)
	RestorePoints(frame.CraftGlow, saved.craftGlowPoints)
	RestorePoints(frame.ChannelShadow, saved.channelShadowPoints)

	if frame.BorderMask and saved.borderMaskWidth and saved.borderMaskHeight then
		frame.BorderMask:SetSize(saved.borderMaskWidth, saved.borderMaskHeight)
	end

	RestoreNativeFillTexCoords(frame)

	if saved.fillHeight then
		local texture = frame:GetStatusBarTexture()

		if texture then
			texture:SetHeight(saved.fillHeight)
		end
	end

	if not preserveSavedState then
		self._savedState = nil
	end
end

local function QueueApply()
	if not Feature._enabled or Feature._applyQueued then
		return
	end

	Feature._applyQueued = true

	C_Timer.After(0, function()
		Feature._applyQueued = false

		if not Feature._enabled then
			return
		end

		local frame = PlayerCastingBarFrame

		if not frame then
			return
		end

		if IsStructuralUpdateBlocked(frame) then
			Feature._pendingApply = true
			return
		end

		Feature:ApplyStyle()
	end)
end

local function ArmRuntimeRefresh(frameCount)
	if not Feature._enabled then
		return
	end

	Feature._runtimeRefreshFrames = math.max(Feature._runtimeRefreshFrames or 0, frameCount or RUNTIME_REFRESH_FRAMES)

	-- Apply once immediately. The OnUpdate passes below repeat this after
	-- all handlers for the spellcast event have had a chance to run.
	ApplyRuntimeCosmetics(PlayerCastingBarFrame)

	runtimeDriver:Show()
end

runtimeDriver:SetScript("OnUpdate", function(self)
	if not Feature._enabled then
		Feature._runtimeRefreshFrames = 0
		self:Hide()
		return
	end

	local frame = PlayerCastingBarFrame

	if frame and not IsStructuralUpdateBlocked(frame) then
		if Feature._pendingDisable then
			Feature:Disable()
			return
		end

		if Feature._pendingApply then
			QueueApply()
		end
	end

	local remaining = Feature._runtimeRefreshFrames or 0

	if remaining <= 0 then
		self:Hide()
		return
	end

	ApplyRuntimeCosmetics(PlayerCastingBarFrame)
	remaining = remaining - 1
	Feature._runtimeRefreshFrames = remaining

	if remaining <= 0 then
		self:Hide()
	end
end)

local function NativeLayoutNeedsRefresh(frame)
	if not frame then
		return false
	end

	local width, height = GetDesiredSize()

	return math.abs(frame:GetWidth() - width) > 0.5 or math.abs(frame:GetHeight() - height) > 0.5
end

local function ArmStructuralSettle(seconds)
	if not Feature._enabled then
		return
	end

	Feature._structuralRefreshUntil =
		math.max(Feature._structuralRefreshUntil or 0, GetTime() + (seconds or STRUCTURAL_SETTLE_SECONDS))

	structuralDriver:Show()
end

structuralDriver:SetScript("OnUpdate", function(self)
	if not Feature._enabled then
		Feature._structuralRefreshUntil = nil
		self:Hide()
		return
	end

	local refreshUntil = Feature._structuralRefreshUntil

	if not refreshUntil or GetTime() >= refreshUntil then
		Feature._structuralRefreshUntil = nil
		self:Hide()
		return
	end

	local frame = PlayerCastingBarFrame

	if not frame then
		return
	end

	if IsStructuralUpdateBlocked(frame) then
		Feature._pendingApply = true
		return
	end

	-- Blizzard can reapply its native 208x11/Edit Mode look after our first
	-- login pass. Repair any structural drift during a short bounded window
	-- instead of leaving the native height visible until a delayed retry.
	if NativeLayoutNeedsRefresh(frame) then
		Feature:ApplyStyle()
	end
end)

local function WarnCombatEditModeDeferral()
	if Feature._combatEditModeWarningShown then
		return
	end

	Feature._combatEditModeWarningShown = true

	local message = "|cff33ff99BetterUI|r: Player Cast Bar size may temporarily use "
		.. "Blizzard's layout while Edit Mode is used in combat. "
		.. "BetterUI will restore the full layout after combat."

	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(message)
	else
		print(message)
	end
end

local function WarnCombatSettingsDeferral()
	if Feature._combatSettingsWarningShown then
		return
	end

	Feature._combatSettingsWarningShown = true

	local message = "|cff33ff99BetterUI|r: Player Cast Bar setting changes " .. "are deferred until combat ends."

	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(message)
	else
		print(message)
	end
end

local function RecoverAfterEditMode(frame)
	if not frame then
		return
	end

	if Feature._nativeStateExposedForEditMode then
		-- Edit Mode may have called SetLook(), which rewrites native dimensions,
		-- text anchors/fonts and look-controlled region visibility. Only capture
		-- when BetterUI restored native state before Edit Mode began.
		RefreshSavedNativeStateAfterEditMode(frame)
		Feature._nativeStateExposedForEditMode = false
	end

	if Feature._pendingDisable then
		Feature:Disable()
		return
	end

	-- These operations are already used by BetterUI during normal combat
	-- spellcast events and do not touch Blizzard mixin state or managed layout.
	-- Reapply them immediately so only structural size work remains deferred.
	ArmRuntimeRefresh(8)

	if IsStructuralUpdateBlocked(frame) then
		Feature._pendingApply = true

		if InCombatLockdown() then
			WarnCombatEditModeDeferral()
		end

		return
	end

	QueueApply()
end

local function OnEditModeEnter()
	if not Feature._enabled then
		return
	end

	if InCombatLockdown() then
		Feature._nativeStateExposedForEditMode = false
		WarnCombatEditModeDeferral()
	elseif Feature._savedState then
		-- Edit Mode must operate on Blizzard's state, not BetterUI's styled
		-- state, or the exit snapshot becomes self-referential.
		Feature:RestoreStyle(true)
		Feature._nativeStateExposedForEditMode = true
	end
end

local function OnEditModeExit()
	if Feature._enabled then
		RecoverAfterEditMode(PlayerCastingBarFrame)
	end
end

function Feature:TryAttach()
	local frame = PlayerCastingBarFrame

	if not frame then
		return false
	end

	if IsStructuralUpdateBlocked(frame) then
		self._pendingApply = true
	else
		self:ApplyStyle()
	end

	ArmStructuralSettle()
	return true
end

function Feature:Enable()
	local wasEnabled = self._enabled
	local wasPendingDisable = self._pendingDisable

	self._enabled = true
	self._pendingDisable = false
	self._combatEditModeWarningShown = false

	if InCombatLockdown() and (not wasEnabled or wasPendingDisable) then
		WarnCombatSettingsDeferral()
	end

	self:TryAttach()

	if not self._settingListenerAdded then
		self._settingListenerAdded = true

		NS.OnSettingChanged(function()
			if Feature._enabled then
				QueueApply()
			end
		end)
	end
end

function Feature:Disable()
	if not self._enabled then
		return
	end

	local frame = PlayerCastingBarFrame

	if IsStructuralUpdateBlocked(frame) then
		self._pendingDisable = true

		if InCombatLockdown() then
			WarnCombatSettingsDeferral()
		end

		return
	end

	self._enabled = false
	self._pendingApply = false
	self._pendingDisable = false
	self._combatEditModeWarningShown = false
	self._combatSettingsWarningShown = false
	self._runtimeRefreshFrames = 0
	self._structuralRefreshUntil = nil

	runtimeDriver:Hide()
	structuralDriver:Hide()
	self._nativeStateExposedForEditMode = false

	self:RestoreStyle()
end

local function HandleSpellcastEvent(event)
	if
		event == "UNIT_SPELLCAST_START"
		or event == "UNIT_SPELLCAST_CHANNEL_START"
		or event == "UNIT_SPELLCAST_EMPOWER_START"
	then
		if InCombatLockdown() then
			Feature._pendingApply = true
		else
			QueueApply()
		end

		ArmRuntimeRefresh(RUNTIME_REFRESH_FRAMES)
		return
	end

	-- Repeat runtime cosmetics briefly after stop events because Blizzard may
	-- update text and child-region layout later in the same event cycle.
	if
		event == "UNIT_SPELLCAST_INTERRUPTED"
		or event == "UNIT_SPELLCAST_FAILED"
		or event == "UNIT_SPELLCAST_STOP"
		or event == "UNIT_SPELLCAST_CHANNEL_STOP"
		or event == "UNIT_SPELLCAST_EMPOWER_STOP"
	then
		ArmRuntimeRefresh(8)
		return
	end

	ArmRuntimeRefresh(RUNTIME_REFRESH_FRAMES)
end

EventRegistry:RegisterCallback("EditMode.Enter", OnEditModeEnter, eventFrame)
EventRegistry:RegisterCallback("EditMode.Exit", OnEditModeExit, eventFrame)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")

eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "player")

eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")

eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "player")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON_NAME and arg1 ~= "Blizzard_UIPanels_Game" then
			return
		end

		if Feature._enabled then
			Feature:TryAttach()
		end

		return
	end

	if event == "PLAYER_REGEN_ENABLED" then
		Feature._combatEditModeWarningShown = false
		Feature._combatSettingsWarningShown = false

		if Feature._pendingDisable then
			Feature:Disable()
			return
		end

		if Feature._enabled and Feature._pendingApply then
			QueueApply()
			ArmStructuralSettle(0.5)
		end

		return
	end

	if event == "PLAYER_ENTERING_WORLD" then
		if Feature._enabled then
			-- Apply immediately, then watch for Blizzard's late login/Edit Mode
			-- initialization resetting the frame to its native 208x11 size.
			Feature:TryAttach()
		end

		return
	end

	if event == "EDIT_MODE_LAYOUTS_UPDATED" then
		if Feature._enabled then
			local frame = PlayerCastingBarFrame

			if frame and not IsEditModeActive() then
				RecoverAfterEditMode(frame)
			else
				QueueApply()
			end
		end

		return
	end

	if event == "UI_SCALE_CHANGED" then
		if Feature._enabled then
			QueueApply()
		end

		return
	end

	if event:find("^UNIT_SPELLCAST_") then
		HandleSpellcastEvent(event)
	end
end)
