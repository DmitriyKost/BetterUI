local ADDON_NAME, NS = ...

local FEATURE_NAME = "PlayerCastBar"

local DEFAULT_WIDTH = 240
local DEFAULT_HEIGHT = 18

local MIN_WIDTH = 150
local MAX_WIDTH = 500

local MIN_HEIGHT = 10
local MAX_HEIGHT = 40

local BORDER_SIZE = 2
local RUNTIME_REFRESH_FRAMES = 3

local Feature = NS.Features[FEATURE_NAME] or {}
NS.Features[FEATURE_NAME] = Feature

local eventFrame = CreateFrame("Frame")
local runtimeDriver = CreateFrame("Frame")
runtimeDriver:Hide()

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

local glowRegions = {
	"BaseGlow",
	"ChargeFlash",
	"ChargeGlow",
	"ChannelShadow",
	"CraftGlow",
	"EnergyGlow",
	"Flakes01",
	"Flakes02",
	"Flakes03",
	"Flash",
	"InterruptGlow",
	"Shine",
	"Sparkles01",
	"Sparkles02",
	"StandardGlow",
	"WispGlow",
}

local finishAnimationKeys = {
	"StandardFinish",
	"CraftingFinish",
	"ChannelFinish",
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
	return EditModeManagerFrame and EditModeManagerFrame:IsShown()
end

local function IsStructuralUpdateBlocked(frame)
	return InCombatLockdown() or IsEditModeActive() or (frame and frame.reverseChanneling)
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

		hiddenRegionShown = hiddenRegionShown,

		castTimeShown = frame.CastTimeText and frame.CastTimeText:IsShown(),

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

local function FitNativeFill(frame, height)
	local texture = frame:GetStatusBarTexture()

	if texture then
		texture:SetHeight(height)
	end
end

local function GlowAnimationsDisabled()
	local db = _G.BetterUIDB or NS.DB or {}
	return db.playerCastBarDisableGlowAnimations and true or false
end

local function CaptureGlowRegionState(region)
	if not region then
		return
	end

	Feature._glowRegionState = Feature._glowRegionState or setmetatable({}, { __mode = "k" })

	if Feature._glowRegionState[region] then
		return
	end

	Feature._glowRegionState[region] = {
		alpha = region:GetAlpha(),
		shown = region:IsShown(),
		vertexColor = { region:GetVertexColor() },
	}
end

local function SuppressGlowRegion(region)
	if not region then
		return
	end

	CaptureGlowRegionState(region)

	local red, green, blue = region:GetVertexColor()

	-- Animation Alpha tracks can overwrite SetAlpha(), while some FX
	-- templates explicitly Show() their targets when playback starts.
	-- Keep both alpha channels at zero and hide the target.
	region:SetVertexColor(red, green, blue, 0)
	region:SetAlpha(0)
	region:Hide()
end

local function RestoreGlowRegions()
	if not Feature._glowRegionState then
		return
	end

	for region, state in pairs(Feature._glowRegionState) do
		local color = state.vertexColor

		region:SetVertexColor(color[1], color[2], color[3], color[4] or 1)

		region:SetAlpha(state.alpha or 1)
		region:SetShown(state.shown)
	end

	wipe(Feature._glowRegionState)
end

local function StopGlowAnimationGroup(animation)
	if animation and animation:IsPlaying() then
		animation:Stop()
	end
end

local function StopGlowAnimations(frame)
	-- Do not stop FadeOutAnim/HoldFadeOutAnim: those are responsible for
	-- the normal lifetime of the interrupted/completed cast bar.
	StopGlowAnimationGroup(frame.FlashAnim)
	StopGlowAnimationGroup(frame.FlashLoopingAnim)
	StopGlowAnimationGroup(frame.StageFlash)
	StopGlowAnimationGroup(frame.StageFinish)
	StopGlowAnimationGroup(frame.InterruptGlowAnim)

	for i = 1, #finishAnimationKeys do
		StopGlowAnimationGroup(frame[finishAnimationKeys[i]])
	end

	local stagePips = frame.StagePips or {}

	for i = 1, #stagePips do
		StopGlowAnimationGroup(stagePips[i].StageAnim)
	end

	local stageTiers = frame.StageTiers or {}

	for i = 1, #stageTiers do
		StopGlowAnimationGroup(stageTiers[i].FlashAnim)
		StopGlowAnimationGroup(stageTiers[i].FinishAnim)
	end
end

local function SuppressGlowAnimations(frame)
	if not GlowAnimationsDisabled() then
		RestoreGlowRegions()
		return
	end

	-- Stop the actual animation groups first. Merely changing texture
	-- vertex alpha is insufficient because Blizzard's Alpha animation
	-- tracks continue to drive the target regions while playing.
	StopGlowAnimations(frame)

	for i = 1, #glowRegions do
		SuppressGlowRegion(frame[glowRegions[i]])
	end

	local stagePips = frame.StagePips or {}

	for i = 1, #stagePips do
		local pip = stagePips[i]

		SuppressGlowRegion(pip.PipGlow)
		SuppressGlowRegion(pip.FlakesBottom)
		SuppressGlowRegion(pip.FlakesTop)
		SuppressGlowRegion(pip.FlakesTop02)
		SuppressGlowRegion(pip.FlakesBottom02)
	end

	local stageTiers = frame.StageTiers or {}

	for i = 1, #stageTiers do
		SuppressGlowRegion(stageTiers[i].Glow)
	end
end

local function FontHasOutline(region)
	if not region then
		return false
	end

	local _, _, flags = region:GetFont()

	if not flags or flags == "" then
		return false
	end

	return flags:find("OUTLINE", 1, true) ~= nil
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
	if not Feature._enabled or not frame or not Feature._savedState then
		return
	end

	for i = 1, #hiddenRegions do
		SetRegionShown(frame[hiddenRegions[i]], false)
	end

	if frame.CastTimeText then
		frame.CastTimeText:Show()
	end

	SetCustomRegionsShown(true)

	-- Blizzard SetLook() may reset Text/CastTimeText anchors after our
	-- initial style pass. Reapply only native FontString layout here.
	local width = GetDesiredSize()
	ApplyTextLayout(frame, width)

	FitNativeFill(frame, frame:GetHeight())
	SuppressGlowAnimations(frame)
end

local function ApplyStructuralLayout(frame, width, height)
	local saved = Feature._savedState

	if frame.Spark then
		local aspect = saved
				and saved.sparkWidth
				and saved.sparkHeight
				and saved.sparkHeight > 0
				and saved.sparkWidth / saved.sparkHeight
			or 0.4

		frame.Spark:SetSize(height * aspect, height)
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

	ApplyStructuralLayout(frame, width, height)
	ApplyRuntimeCosmetics(frame)
end

function Feature:RestoreStyle()
	local frame = PlayerCastingBarFrame
	local saved = self._savedState

	if not frame or not saved then
		return
	end

	RestoreGlowRegions()
	SetCustomRegionsShown(false)

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

	if frame.BorderMask and saved.borderMaskWidth and saved.borderMaskHeight then
		frame.BorderMask:SetSize(saved.borderMaskWidth, saved.borderMaskHeight)
	end

	if saved.fillHeight then
		FitNativeFill(frame, saved.fillHeight)
	end

	self._savedState = nil
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

local function NearlyEqual(a, b, tolerance)
	tolerance = tolerance or 0.25
	return math.abs((a or 0) - (b or 0)) <= tolerance
end

local function TextLayoutNeedsRefresh(frame)
	if not frame or not frame.Text then
		return false
	end

	local point, relativeTo, relativePoint, x, y = frame.Text:GetPoint(1)

	if
		point ~= "TOPLEFT"
		or relativeTo ~= frame
		or relativePoint ~= "TOPLEFT"
		or not NearlyEqual(x, 5)
		or not NearlyEqual(y, 0)
	then
		return true
	end

	if not FontHasOutline(frame.Text) then
		return true
	end

	if frame.CastTimeText and not FontHasOutline(frame.CastTimeText) then
		return true
	end

	return false
end

local function NativeLayoutNeedsRefresh(frame)
	if not frame then
		return false
	end

	local width, height = GetDesiredSize()

	if not NearlyEqual(frame:GetWidth(), width) or not NearlyEqual(frame:GetHeight(), height) then
		return true
	end

	return TextLayoutNeedsRefresh(frame)
end

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

local function RecoverAfterEditMode(frame)
	if not frame then
		return
	end

	-- Edit Mode may have called SetLook(), which rewrites native dimensions,
	-- text anchors/fonts and look-controlled region visibility.
	RefreshSavedNativeStateAfterEditMode(frame)

	-- These operations are already used by BetterUI during normal combat
	-- spellcast events and do not touch Blizzard mixin state or managed layout.
	-- Reapply them immediately so only structural size work remains deferred.
	ArmRuntimeRefresh(8)

	if IsStructuralUpdateBlocked(frame) then
		Feature._pendingApply = true

		if InCombatLockdown() and NativeLayoutNeedsRefresh(frame) then
			WarnCombatEditModeDeferral()
		end

		return
	end

	QueueApply()
end

local function StartEditModeWatcher()
	if Feature._editModeTicker then
		return
	end

	Feature._editModeShown = IsEditModeActive() and true or false

	Feature._editModeTicker = C_Timer.NewTicker(0.25, function()
		if not Feature._enabled then
			return
		end

		local shown = IsEditModeActive() and true or false
		local wasShown = Feature._editModeShown

		if shown ~= wasShown then
			Feature._editModeShown = shown

			if shown and InCombatLockdown() then
				WarnCombatEditModeDeferral()
			end

			-- Do not touch PlayerCastingBarFrame while Blizzard owns the
			-- Edit Mode update stack. Once Edit Mode closes, restore all
			-- combat-safe cosmetics immediately and defer only structural
			-- sizing/layout work if combat still blocks it.
			if wasShown and not shown then
				local frame = PlayerCastingBarFrame

				if Feature._pendingDisable then
					Feature:Disable()
					return
				end

				RecoverAfterEditMode(frame)
			end

			return
		end

		if shown then
			return
		end

		local frame = PlayerCastingBarFrame

		if not frame then
			return
		end

		local blocked = IsStructuralUpdateBlocked(frame)

		-- Drain deferred lifecycle work independently of layout drift. This
		-- avoids relying on a spellcast event or a fixed post-empower delay.
		if Feature._pendingDisable and not blocked then
			Feature:Disable()
			return
		end

		if Feature._pendingApply and not blocked then
			QueueApply()
			return
		end

		-- Blizzard SetLook() hard-resets the player bar to its native
		-- CLASSIC/UNITFRAME geometry. Detect that native drift instead of
		-- hooking SetLook(), which previously tainted Edit Mode execution.
		if NativeLayoutNeedsRefresh(frame) then
			if blocked then
				Feature._pendingApply = true

				-- FontString anchors are native region state; keep the spell
				-- name/timer aligned even if frame sizing must wait.
				local width = GetDesiredSize()
				ApplyTextLayout(frame, width)
			else
				QueueApply()
			end
		end
	end)
end

local function StopEditModeWatcher()
	if not Feature._editModeTicker then
		return
	end

	Feature._editModeTicker:Cancel()
	Feature._editModeTicker = nil
	Feature._editModeShown = nil
end

function Feature:TryAttach()
	if not PlayerCastingBarFrame then
		return false
	end

	QueueApply()
	return true
end

function Feature:Enable()
	self._enabled = true
	self._pendingDisable = false
	self._combatEditModeWarningShown = false

	self:TryAttach()
	StartEditModeWatcher()

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
		return
	end

	self._enabled = false
	self._pendingApply = false
	self._pendingDisable = false
	self._combatEditModeWarningShown = false
	self._runtimeRefreshFrames = 0

	runtimeDriver:Hide()
	StopEditModeWatcher()

	self:RestoreStyle()
end

local function HandleSpellcastEvent(event)
	-- Runtime cosmetics are repeated for a few rendered frames so Blizzard
	-- animation/event handlers cannot briefly restore interrupt/finish glow.
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

		if Feature._pendingDisable then
			Feature:Disable()
			return
		end

		if Feature._enabled and Feature._pendingApply then
			QueueApply()
		end

		return
	end

	if event == "PLAYER_ENTERING_WORLD" then
		if Feature._enabled then
			QueueApply()

			-- Blizzard may run SetLook()/Edit Mode initialization after our
			-- first PLAYER_ENTERING_WORLD handler. Two later passes stabilize
			-- the native frame without hooking Blizzard methods.
			C_Timer.After(0.2, function()
				if Feature._enabled then
					QueueApply()
				end
			end)

			C_Timer.After(1.0, function()
				if Feature._enabled then
					QueueApply()
				end
			end)
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
