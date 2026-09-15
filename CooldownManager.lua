local ADDON_NAME, NS = ...

local FEATURE_NAME = "CooldownManager"
local DECIMAL_THRESHOLD = 10
local REDUCED_GLOW_TEXTURE_FACTOR = 0.875
local WINDWALKER_SPEC_ID = 269

-- Heart of the Jade Serpent
local HOTJS_BASE_SPELL_ID = 443294
local HOTJS_REGULAR_AURA_ID = 443421
local HOTJS_UNITY_AURA_ID = 443616
local HOTJS_ZENITH_AURA_ID = 1238904

local AURA_CONTAINER_ADDON = "Blizzard_AuraContainer"

local PRIMARY_FONT_NAME = "BetterUIHotJSPrimaryCountdownFont"
local UNITY_FONT_NAME = "BetterUIHotJSUnityCountdownFont"
local SECONDARY_FONT_NAME = "BetterUIHotJSSecondaryCountdownFont"

local PRIMARY_Y_OFFSET = 7
local ZENITH_Y_OFFSET = -7

local EDIT_MODE_REFRESH_INTERVAL = 0.10
local EDIT_MODE_REFRESH_DURATION = 2.0

local SCAN_RETRY_DELAYS = {
	0,
	0.2,
	1.0,
}

local Feature = NS.Features[FEATURE_NAME] or {}
NS.Features[FEATURE_NAME] = Feature

local eventFrame = CreateFrame("Frame")
local editModeRefreshDriver = CreateFrame("Frame")
editModeRefreshDriver:Hide()

-- CDM item frames are pooled and may be rebound to another cooldown when
-- the user reorders tracked buffs. Keep a single movable HotJS overlay instead
-- of attaching permanent AuraContainers to pooled item identities.
local hotjsOverlay
local originalCountdownThresholds = setmetatable({}, { __mode = "k" })
local originalGlowStates = setmetatable({}, { __mode = "k" })

local function GetDB()
	return _G.BetterUIDB or NS.DB or {}
end

local function DecimalTimersEnabled()
	return GetDB().cooldownManagerShowTenths and true or false
end

local function ReducedGlowEnabled()
	return GetDB().cooldownManagerReduceGlowAnimation and true or false
end

local function IsWindwalker()
	if not GetSpecialization or not GetSpecializationInfo then
		return false
	end

	local specializationIndex = GetSpecialization()

	if not specializationIndex then
		return false
	end

	local specializationID = GetSpecializationInfo(specializationIndex)

	return specializationID == WINDWALKER_SPEC_ID
end

local function WindwalkerTweaksEnabled()
	return GetDB().cooldownManagerWindwalkerHotJS and IsWindwalker() or false
end

local function ArmEditModeRefresh()
	Feature._editModeRefreshUntil = GetTime() + EDIT_MODE_REFRESH_DURATION
	Feature._editModeRefreshElapsed = 0
	editModeRefreshDriver:Show()
end

local function ApplyCountdownThreshold(cooldown)
	if not cooldown or not cooldown.SetCountdownMillisecondsThreshold then
		return
	end

	if originalCountdownThresholds[cooldown] == nil and cooldown.GetCountdownMillisecondsThreshold then
		originalCountdownThresholds[cooldown] = cooldown:GetCountdownMillisecondsThreshold()
	end

	cooldown:SetCountdownMillisecondsThreshold(DECIMAL_THRESHOLD)
end

local function RestoreCountdownThresholds()
	for cooldown, threshold in pairs(originalCountdownThresholds) do
		if cooldown.SetCountdownMillisecondsThreshold then
			cooldown:SetCountdownMillisecondsThreshold(threshold)
		end
	end

	wipe(originalCountdownThresholds)
end

local function ApplyReducedGlow(item)
	local glow = item and item.SpellActivationAlert

	if not glow
		or not glow.ProcStartFlipbook
		or not glow.ProcLoopFlipbook
	then
		return
	end

	local state = originalGlowStates[glow]

	if not state then
		local startWidth, startHeight =
			glow.ProcStartFlipbook:GetSize()

		state = {
			startWidth = startWidth,
			startHeight = startHeight,
			frameLevel = glow:GetFrameLevel(),
		}

		originalGlowStates[glow] = state
	end

	-- Keep proc state visible while the GCD/cooldown swipe is active.
	-- SpellActivationAlert and Cooldown are siblings, so establish the
	-- intended visual ordering explicitly.
	if item.Cooldown then
		glow:SetFrameLevel(
			item.Cooldown:GetFrameLevel() + 1
		)
	end

	-- Do not scale SpellActivationAlert itself: ProcLoopFlipbook is normally
	-- stretched across the entire alert frame, so shrinking the parent makes
	-- the animation look like a smaller square inside the CDM icon.
	--
	-- Instead, keep Blizzard's frame, flipbook animations, alpha and timing
	-- untouched and reduce only the animated textures around their center.
	local glowWidth, glowHeight = glow:GetSize()

	glow.ProcLoopFlipbook:ClearAllPoints()
	glow.ProcLoopFlipbook:SetPoint("CENTER", glow, "CENTER")
	glow.ProcLoopFlipbook:SetSize(
		glowWidth * REDUCED_GLOW_TEXTURE_FACTOR,
		glowHeight * REDUCED_GLOW_TEXTURE_FACTOR
	)

	glow.ProcStartFlipbook:SetSize(
		state.startWidth * REDUCED_GLOW_TEXTURE_FACTOR,
		state.startHeight * REDUCED_GLOW_TEXTURE_FACTOR
	)
end

local function RestoreReducedGlows()
	for glow, state in pairs(originalGlowStates) do
		glow:SetFrameLevel(state.frameLevel)

		if glow.ProcStartFlipbook then
			glow.ProcStartFlipbook:SetSize(
				state.startWidth,
				state.startHeight
			)
		end

		if glow.ProcLoopFlipbook then
			glow.ProcLoopFlipbook:ClearAllPoints()
			glow.ProcLoopFlipbook:SetAllPoints(glow)
		end
	end

	wipe(originalGlowStates)
end

local function ScanReducedGlowViewer(viewer)
	local pool = viewer and viewer.itemFramePool

	if not pool or not pool.EnumerateActive then
		return
	end

	for item in pool:EnumerateActive() do
		ApplyReducedGlow(item)
	end
end

local function RefreshReducedGlows()
	if not Feature._enabled or not ReducedGlowEnabled() then
		return
	end

	ScanReducedGlowViewer(_G.EssentialCooldownViewer)
	ScanReducedGlowViewer(_G.UtilityCooldownViewer)
end

local function QueueGlowRefresh()
	if Feature._glowRefreshQueued then
		return
	end

	Feature._glowRefreshQueued = true

	C_Timer.After(0, function()
		Feature._glowRefreshQueued = false
		RefreshReducedGlows()
	end)
end

local function IsHeartOfJadeSerpentItem(item)
	if not item then
		return false
	end

	if item.GetBaseSpellID then
		local baseSpellID = item:GetBaseSpellID()

		if baseSpellID ~= nil then
			return baseSpellID == HOTJS_BASE_SPELL_ID
		end
	end

	if item.GetCooldownInfo then
		local info = item:GetCooldownInfo()

		return info and info.spellID == HOTJS_BASE_SPELL_ID or false
	end

	return false
end

local function CopyFontMetrics(targetFont, sourceFontString)
	if not targetFont or not sourceFontString then
		return
	end

	local fontFile, fontHeight, flags = sourceFontString:GetFont()

	if fontFile and fontHeight then
		targetFont:SetFont(fontFile, fontHeight, flags or "")
		return
	end

	local fontObject = sourceFontString:GetFontObject()

	if fontObject then
		targetFont:CopyFontObject(fontObject)
	end
end

local function EnsureCountdownFonts(item)
	local nativeCountdownText = item
		and item.Cooldown
		and item.Cooldown.GetCountdownFontString
		and item.Cooldown:GetCountdownFontString()
	local fontSource = nativeCountdownText or _G.GameFontHighlightOutline or _G.GameFontHighlight

	local primaryFont = _G[PRIMARY_FONT_NAME]

	if not primaryFont then
		primaryFont = CreateFont(PRIMARY_FONT_NAME)
	end

	CopyFontMetrics(primaryFont, fontSource)
	primaryFont:SetTextColor(1, 1, 1, 1)

	local unityFont = _G[UNITY_FONT_NAME]

	if not unityFont then
		unityFont = CreateFont(UNITY_FONT_NAME)
	end

	CopyFontMetrics(unityFont, fontSource)

	local monkColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS.MONK

	if monkColor then
		unityFont:SetTextColor(monkColor.r, monkColor.g, monkColor.b, 1)
	else
		unityFont:SetTextColor(0, 1, 0.596, 1)
	end

	local secondaryFont = _G[SECONDARY_FONT_NAME]

	if not secondaryFont then
		secondaryFont = CreateFont(SECONDARY_FONT_NAME)
	end

	-- Zenith uses exactly the same native CDM font metrics as primary.
	CopyFontMetrics(secondaryFont, fontSource)
	secondaryFont:SetTextColor(1, 1, 1, 1)
end

local function IsAuraContainerLoaded()
	if not C_AddOns or not C_AddOns.IsAddOnLoaded then
		return false
	end

	local _, loaded = C_AddOns.IsAddOnLoaded(AURA_CONTAINER_ADDON)

	return loaded == true
end

local function LoadAuraContainer()
	if IsAuraContainerLoaded() then
		return true
	end

	if not C_AddOns or not C_AddOns.LoadAddOn then
		return false
	end

	local callOK, loaded = pcall(C_AddOns.LoadAddOn, AURA_CONTAINER_ADDON)

	return callOK and loaded == true
end

local function PositionCountdownText(cooldown, yOffset)
	if not cooldown.GetCountdownFontString then
		return
	end

	local text = cooldown:GetCountdownFontString()

	if not text then
		return
	end

	text:ClearAllPoints()
	text:SetPoint("CENTER", cooldown, "CENTER", 0, yOffset)
end

local function InitializeAuraTimerButton(button, fontName, yOffset, showManagedIcon, frameLevelOffset)
	button:SetAllPoints()

	-- AuraContainer owns this texture and updates it from the assigned aura.
	-- Regular/Zenith keep it transparent because the CDM item already supplies
	-- the icon. Unity keeps it visible: since it is the same HotJS icon and
	-- sits above regular HotJS, it cleanly covers the lower WDP countdown.
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(button)
	icon:SetAlpha(showManagedIcon and 1 or 0)
	button:SetIcon(icon)

	if showManagedIcon then
		-- Match CooldownViewerBuffIconItemTemplate exactly: Blizzard's tracked
		-- buff icons are masked and have the CDM icon overlay. A raw spell icon
		-- exposes its own square edge and looks like it has a foreign border.
		local mask = button:CreateMaskTexture()
		mask:SetAtlas("UI-HUD-CoolDownManager-Mask")
		mask:SetAllPoints(button)
		icon:AddMaskTexture(mask)

		local overlay = button:CreateTexture(nil, "OVERLAY")
		overlay:SetAtlas("UI-HUD-CoolDownManager-IconOverlay")
		overlay:SetPoint("TOPLEFT", button, "TOPLEFT", -8, 7)
		overlay:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 8, -7)
	end

	local parentLevel = button:GetParent():GetFrameLevel()
	button:SetFrameLevel(parentLevel + frameLevelOffset)

	local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")

	cooldown:SetAllPoints(button)
	cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
	cooldown:SetHideCountdownNumbers(false)

	if cooldown.SetDrawSwipe then
		cooldown:SetDrawSwipe(false)
	end

	if cooldown.SetDrawEdge then
		cooldown:SetDrawEdge(false)
	end

	if cooldown.SetDrawBling then
		cooldown:SetDrawBling(false)
	end

	if cooldown.SetCountdownMillisecondsThreshold then
		cooldown:SetCountdownMillisecondsThreshold(DECIMAL_THRESHOLD)
	end

	if cooldown.SetCountdownFont then
		cooldown:SetCountdownFont(fontName)
	end

	PositionCountdownText(cooldown, yOffset)
	button:SetDurationCooldown(cooldown)
end

local function AddAuraSlot(container, slotKey, spellID, fontName, yOffset, showManagedIcon, frameLevelOffset)
	container:AddAuraSlot(slotKey, "HELPFUL", {
		candidateFilters = {
			includeSpellIDs = {
				[spellID] = true,
			},
		},
		initializeFrame = function(auraButton)
			InitializeAuraTimerButton(auraButton, fontName, yOffset, showManagedIcon, frameLevelOffset)
		end,
	})
end

local function HideNativeHotJSTimer(item, state)
	if not item or not item.Cooldown then
		return
	end

	item.Cooldown:SetHideCountdownNumbers(true)

	if item.Cooldown.GetCountdownFontString then
		local text = item.Cooldown:GetCountdownFontString()

		if text then
			state.nativeCountdownAlphas = state.nativeCountdownAlphas or setmetatable({}, { __mode = "k" })

			if state.nativeCountdownAlphas[text] == nil then
				state.nativeCountdownAlphas[text] = text:GetAlpha()
			end

			-- Edit Mode can re-apply timer visibility after our first pass.
			-- Keep the native FontString hidden as a second line of defense.
			text:SetAlpha(0)
		end
	end
end

local function RestoreNativeHotJSTimer(item, state)
	if not item or not state then
		return
	end

	if item.Cooldown then
		local viewer = item.GetViewerFrame and item:GetViewerFrame()
		local timerShown = viewer and viewer.timerShown

		if timerShown ~= nil then
			item.Cooldown:SetHideCountdownNumbers(not timerShown)
		end
	end

	if state.nativeCountdownAlphas then
		for text, alpha in pairs(state.nativeCountdownAlphas) do
			text:SetAlpha(alpha)
		end

		wipe(state.nativeCountdownAlphas)
	end
end

local function DetachHotJSOverlay(state)
	if not state then
		return
	end

	if state.item then
		RestoreNativeHotJSTimer(state.item, state)
		state.item = nil
	end

	if state.container then
		state.container:SetEnabled(false)
	end

	if state.host then
		state.host:Hide()
	end
end

local function CreateHotJSOverlay(parent)
	if not parent or InCombatLockdown() then
		return nil
	end

	if not LoadAuraContainer() then
		return nil
	end

	EnsureCountdownFonts(nil)

	local host = CreateFrame("Frame", nil, parent)
	host:SetSize(1, 1)
	host:SetFrameLevel(parent:GetFrameLevel() + 20)
	host:Hide()

	local container = CreateFrame("AuraContainer", nil, host, "CustomAuraContainerTemplate")

	container:SetAllPoints(host)
	container:SetFrameLevel(host:GetFrameLevel())
	container:Hide()

	local state = {
		host = host,
		container = container,
		item = nil,
		initialized = false,
	}

	-- Store the partial state before constructing slots. If an API/programming
	-- error occurs, later bounded scan retries will not allocate more frames.
	hotjsOverlay = state

	-- Regular WDP/SotWL HotJS: white primary timer.
	AddAuraSlot(
		container,
		"betterui-hotjs-regular",
		HOTJS_REGULAR_AURA_ID,
		PRIMARY_FONT_NAME,
		PRIMARY_Y_OFFSET,
		false,
		1
	)

	-- Unity Within: monk-green primary timer in the same position.
	-- Its managed icon is visible and layered above regular HotJS, so when
	-- both auras exist Unity naturally covers the lower WDP timer.
	AddAuraSlot(container, "betterui-hotjs-unity", HOTJS_UNITY_AURA_ID, UNITY_FONT_NAME, PRIMARY_Y_OFFSET, true, 3)

	-- Zenith: independent stack, white secondary timer.
	AddAuraSlot(
		container,
		"betterui-hotjs-zenith",
		HOTJS_ZENITH_AURA_ID,
		SECONDARY_FONT_NAME,
		ZENITH_Y_OFFSET,
		false,
		5
	)

	-- Slots must exist before assigning the unit.
	container:SetUnit("player")
	container:SetEnabled(false)

	state.initialized = true
	return state
end

local function AttachHotJSOverlay(item)
	local state = hotjsOverlay

	if not state then
		local viewer = item.GetViewerFrame and item:GetViewerFrame()

		state = CreateHotJSOverlay(viewer or item)

		if not state then
			return
		end
	elseif not state.initialized then
		-- A previous construction failed. Keep the partial overlay hidden
		-- instead of leaking another AuraContainer on every retry.
		return
	end

	if state.item ~= item then
		if state.item then
			RestoreNativeHotJSTimer(state.item, state)
		end

		-- Move only our unrestricted host. Managed AuraButtons remain untouched
		-- after initialization and inherit position/scale through the host.
		state.host:SetParent(item)
		state.host:ClearAllPoints()
		state.host:SetAllPoints(item)
		state.host:SetFrameLevel(item:GetFrameLevel() + 20)

		state.item = item

		state.container:SetEnabled(true)
		state.container:UpdateAllAuras()
		state.container:Show()
		state.host:Show()
	end

	EnsureCountdownFonts(item)
	HideNativeHotJSTimer(item, state)
end

local function ScanCooldownManager()
	if not Feature._enabled then
		return
	end

	local decimalTimersEnabled = DecimalTimersEnabled()
	local reducedGlowEnabled = ReducedGlowEnabled()
	local windwalkerTweaksEnabled = WindwalkerTweaksEnabled()

	if not decimalTimersEnabled then
		RestoreCountdownThresholds()
	end

	if not reducedGlowEnabled then
		RestoreReducedGlows()
	end

	if not windwalkerTweaksEnabled then
		DetachHotJSOverlay(hotjsOverlay)
	end

	if reducedGlowEnabled then
		RefreshReducedGlows()
	end

	local viewer = _G.BuffIconCooldownViewer
	local pool = viewer and viewer.itemFramePool

	if not pool or not pool.EnumerateActive then
		return
	end

	-- Blizzard_AuraContainer is loaded lazily only for Windwalker and only
	-- when the Heart of the Jade Serpent fix is enabled.
	if windwalkerTweaksEnabled and not hotjsOverlay and not InCombatLockdown() then
		CreateHotJSOverlay(viewer)
	end

	local activeHotJSItem

	for item in pool:EnumerateActive() do
		if item.Cooldown and decimalTimersEnabled then
			ApplyCountdownThreshold(item.Cooldown)
		end

		if windwalkerTweaksEnabled and IsHeartOfJadeSerpentItem(item) then
			activeHotJSItem = item
		end
	end

	if windwalkerTweaksEnabled then
		if activeHotJSItem then
			AttachHotJSOverlay(activeHotJSItem)
		else
			DetachHotJSOverlay(hotjsOverlay)
		end
	end
end

local function QueueScan()
	if not Feature._enabled or Feature._scanQueued then
		return
	end

	Feature._scanQueued = true
	Feature._scanGeneration = (Feature._scanGeneration or 0) + 1

	local generation = Feature._scanGeneration
	local lastIndex = #SCAN_RETRY_DELAYS

	for i = 1, lastIndex do
		local delay = SCAN_RETRY_DELAYS[i]
		local isLast = i == lastIndex

		C_Timer.After(delay, function()
			if Feature._enabled and Feature._scanGeneration == generation then
				ScanCooldownManager()
			end

			if isLast and Feature._scanGeneration == generation then
				Feature._scanQueued = false
			end
		end)
	end
end

local function OnCooldownViewerDataChanged()
	if Feature._enabled then
		-- Blizzard uses this exact callback to rebind pooled item frames after
		-- a tracked-buff reorder. Scan on the next tick, after its synchronous
		-- RefreshData/RefreshLayout work has completed.
		QueueScan()
	end
end

EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", OnCooldownViewerDataChanged, eventFrame)

editModeRefreshDriver:SetScript("OnUpdate", function(self, elapsed)
	if not Feature._enabled then
		self:Hide()
		return
	end

	if not DecimalTimersEnabled() and not ReducedGlowEnabled() and not WindwalkerTweaksEnabled() then
		self:Hide()
		return
	end

	local refreshUntil = Feature._editModeRefreshUntil

	if not refreshUntil or GetTime() >= refreshUntil then
		Feature._editModeRefreshUntil = nil
		Feature._editModeRefreshElapsed = 0
		self:Hide()
		return
	end

	Feature._editModeRefreshElapsed = (Feature._editModeRefreshElapsed or 0) + elapsed

	if Feature._editModeRefreshElapsed < EDIT_MODE_REFRESH_INTERVAL then
		return
	end

	Feature._editModeRefreshElapsed = 0

	-- Blizzard may reconfigure pooled Cooldown items for several frames after
	-- an Edit Mode resize. Re-run the canonical scan so frame rebinding,
	-- decimal thresholds and native-timer suppression stay in sync.
	ScanCooldownManager()
end)

function Feature:Enable()
	if self._enabled then
		QueueScan()
		return
	end

	self._enabled = true
	QueueScan()
end

function Feature:Disable()
	if not self._enabled then
		return
	end

	self._enabled = false
	self._scanQueued = false
	self._glowRefreshQueued = false
	self._scanGeneration = (self._scanGeneration or 0) + 1
	self._editModeRefreshUntil = nil
	self._editModeRefreshElapsed = 0
	editModeRefreshDriver:Hide()

	RestoreCountdownThresholds()
	RestoreReducedGlows()
	DetachHotJSOverlay(hotjsOverlay)
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("COOLDOWN_VIEWER_DATA_LOADED")
eventFrame:RegisterEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED")
eventFrame:RegisterEvent("COOLDOWN_VIEWER_TABLE_HOTFIXED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON_NAME and arg1 ~= "Blizzard_CooldownViewer" and arg1 ~= AURA_CONTAINER_ADDON then
			return
		end
	end

	if not Feature._enabled then
		return
	end

	if event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 and arg1 ~= "player" then
		return
	end

	if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
		if ReducedGlowEnabled() then
			-- Blizzard creates SpellActivationAlert lazily while handling this
			-- event. Defer one UI tick so the frame exists before styling it.
			QueueGlowRefresh()
		end

		return
	end

	if event == "EDIT_MODE_LAYOUTS_UPDATED" then
		QueueScan()
		ArmEditModeRefresh()
		return
	end

	QueueScan()
end)
