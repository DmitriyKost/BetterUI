local _, NS = ...

NS.Features = NS.Features or {}

local Feature = {}
NS.Features.RoguePoisonReminder = Feature

local WARNING_THRESHOLD = 5 * 60
local BUTTON_SIZE = 36
local BUTTON_SPACING = 6
local MAX_POISON_SLOTS = 4
local DRAG_HANDLE_HEIGHT = 14
local FRAME_WIDTH = MAX_POISON_SLOTS * BUTTON_SIZE + (MAX_POISON_SLOTS - 1) * BUTTON_SPACING

local POISONS = {
	{ spellID = 315584, name = "Instant Poison", category = "lethal" },
	{ spellID = 2823, name = "Deadly Poison", category = "lethal" },
	{ spellID = 8679, name = "Wound Poison", category = "lethal" },
	{ spellID = 381664, name = "Amplifying Poison", category = "lethal" },
	{ spellID = 3408, name = "Crippling Poison", category = "nonlethal" },
	{ spellID = 5761, name = "Numbing Poison", category = "nonlethal" },
	{ spellID = 381637, name = "Atrophic Poison", category = "nonlethal" },
}

local function IsRogue()
	local _, class = UnitClass("player")
	return class == "ROGUE"
end

local function GetDB()
	return _G.BetterUIDB or NS.DB or {}
end

local function GetSpellTexture(spellID)
	if C_Spell and C_Spell.GetSpellTexture then
		return C_Spell.GetSpellTexture(spellID)
	end
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(spellID)
		return info and info.iconID
	end
	return 134400
end

local function GetPoisonAura(spellID)
	if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
		return C_UnitAuras.GetPlayerAuraBySpellID(spellID)
	end
	return nil
end

local function IsSpellKnown(spellID)
	if C_SpellBook and C_SpellBook.IsSpellKnown then
		return C_SpellBook.IsSpellKnown(spellID)
	end
	return IsPlayerSpell and IsPlayerSpell(spellID) or false
end

local function GetRemainingDuration(aura)
	local expirationTime = aura and aura.expirationTime
	if issecretvalue and issecretvalue(expirationTime) then
		return nil
	end
	if type(expirationTime) ~= "number" or expirationTime == 0 then
		return math.huge
	end
	return math.max(0, expirationTime - GetTime())
end

local function FormatRemaining(seconds)
	if seconds < 60 then
		return "<1m"
	end
	return string.format("%dm", math.ceil(seconds / 60))
end

local function CreateButton(parent, poison)
	local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
	button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	button:RegisterForClicks("AnyUp")
	button:SetAttribute("type1", "spell")
	button:SetAttribute("spell1", poison.spellID)
	button.poison = poison

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0, 0, 0, 0.85)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", 2, -2)
	icon:SetPoint("BOTTOMRIGHT", -2, 2)
	icon:SetTexture(GetSpellTexture(poison.spellID))
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.Icon = icon

	button.Border = {}
	local anchors = {
		{ "TOPLEFT", "TOPRIGHT", "height" },
		{ "BOTTOMLEFT", "BOTTOMRIGHT", "height" },
		{ "TOPLEFT", "BOTTOMLEFT", "width" },
		{ "TOPRIGHT", "BOTTOMRIGHT", "width" },
	}
	for index, points in ipairs(anchors) do
		local edge = button:CreateTexture(nil, "OVERLAY")
		edge:SetPoint(points[1])
		edge:SetPoint(points[2])
		if points[3] == "width" then
			edge:SetWidth(2)
		else
			edge:SetHeight(2)
		end
		button.Border[index] = edge
	end

	local remaining = button:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med1")
	remaining:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
	remaining:SetTextColor(1, 0.35, 0.2)
	button.Remaining = remaining

	local marker = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	marker:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3, -1)
	marker:SetText("!")
	marker:SetTextColor(1, 0.82, 0)
	button.Marker = marker

	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetSpellByID(self.poison.spellID)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Click to apply this poison.", 0.2, 1, 0.2)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	button:Hide()
	return button
end

function Feature:EnsureFrame()
	if self.frame or InCombatLockdown() then
		return self.frame
	end

	local frame = CreateFrame("Frame", nil, UIParent)
	local position = GetDB().roguePoisonReminderPosition
	if type(position) == "table" and position.point and position.relativePoint then
		frame:SetPoint(position.point, UIParent, position.relativePoint, position.x or 0, position.y or 0)
	else
		frame:SetPoint("TOP", UIParent, "TOP", 0, -180)
	end
	frame:SetSize(FRAME_WIDTH, BUTTON_SIZE + DRAG_HANDLE_HEIGHT)
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)

	local dragHandle = CreateFrame("Button", nil, frame)
	dragHandle:SetPoint("TOPLEFT")
	dragHandle:SetPoint("TOPRIGHT")
	dragHandle:SetHeight(DRAG_HANDLE_HEIGHT)
	dragHandle:RegisterForDrag("LeftButton")

	local dragLabel = dragHandle:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	dragLabel:SetPoint("LEFT", 2, 0)
	dragLabel:SetText("POISONS")
	dragHandle.Label = dragLabel

	local dragHighlight = dragHandle:CreateTexture(nil, "HIGHLIGHT")
	dragHighlight:SetAllPoints()
	dragHighlight:SetColorTexture(1, 0.82, 0, 0.08)

	dragHandle:SetScript("OnDragStart", function()
		if not InCombatLockdown() then
			frame:StartMoving()
			frame._buiPoisonMoving = true
		end
	end)
	dragHandle:SetScript("OnDragStop", function()
		Feature:StopDragging()
	end)
	frame.DragHandle = dragHandle

	frame.Buttons = {}
	for _, poison in ipairs(POISONS) do
		frame.Buttons[poison.spellID] = CreateButton(frame, poison)
	end

	frame:Hide()
	self.frame = frame
	self:ApplyLock()
	return frame
end

function Feature:ApplyLock()
	if not self.frame or not self.frame.DragHandle then
		return
	end
	if InCombatLockdown() then
		self.pendingLockUpdate = true
		return
	end

	self.pendingLockUpdate = nil
	local locked = GetDB().roguePoisonReminderLocked == true
	self.frame.DragHandle:SetShown(not locked)
	self.frame:SetHeight(BUTTON_SIZE + (locked and 0 or DRAG_HANDLE_HEIGHT))
end

function Feature:StopDragging()
	local frame = self.frame
	if not frame or not frame._buiPoisonMoving then
		return
	end
	if InCombatLockdown() then
		self.pendingDragStop = true
		return
	end

	frame:StopMovingOrSizing()
	frame._buiPoisonMoving = nil
	self.pendingDragStop = nil
	local point, _, relativePoint, x, y = frame:GetPoint(1)
	_G.BetterUIDB = _G.BetterUIDB or {}
	_G.BetterUIDB.roguePoisonReminderPosition = {
		point = point,
		relativePoint = relativePoint,
		x = x,
		y = y,
	}
	NS.DB = _G.BetterUIDB
end

function Feature:SetSlotOrder(poisons)
	local previousSlots = self.slotBySpellID or {}
	local slotBySpellID = {}
	local spellIDBySlot = {}

	for _, poison in ipairs(poisons) do
		local slot = previousSlots[poison.spellID]
		if slot and slot <= MAX_POISON_SLOTS and not spellIDBySlot[slot] then
			slotBySpellID[poison.spellID] = slot
			spellIDBySlot[slot] = poison.spellID
		end
	end
	for _, poison in ipairs(poisons) do
		if not slotBySpellID[poison.spellID] then
			for slot = 1, MAX_POISON_SLOTS do
				if not spellIDBySlot[slot] then
					slotBySpellID[poison.spellID] = slot
					spellIDBySlot[slot] = poison.spellID
					break
				end
			end
		end
	end
	self.slotBySpellID = slotBySpellID
	self.spellIDBySlot = spellIDBySlot
end

function Feature:GetButtonSlot(spellID)
	local slot = self.slotBySpellID and self.slotBySpellID[spellID]
	if slot then
		return slot
	end

	self.slotBySpellID = self.slotBySpellID or {}
	self.spellIDBySlot = self.spellIDBySlot or {}
	for index = 1, MAX_POISON_SLOTS do
		if not self.spellIDBySlot[index] then
			self.spellIDBySlot[index] = spellID
			self.slotBySpellID[spellID] = index
			return index
		end
	end
	return nil
end

function Feature:GetRecommendedPoisons()
	local specialization = GetSpecialization()
	local usePvP = GetDB().roguePoisonUsePvPSuggestions == true
	local recommended = {}

	local function Add(spellID, category)
		if IsSpellKnown(spellID) then
			recommended[#recommended + 1] = { spellID = spellID, category = category }
			return true
		end
		return false
	end

	if usePvP then
		Add(8679, "lethal")
		Add(3408, "nonlethal")
		if specialization == 1 and IsSpellKnown(381801) then
			if not Add(381664, "lethal") then
				Add(2823, "lethal")
			end
			if not Add(5761, "nonlethal") then
				Add(381637, "nonlethal")
			end
		end
	elseif specialization == 1 then
		Add(2823, "lethal")
		local dragonTempered = IsSpellKnown(381801)
		if dragonTempered then
			if not Add(381664, "lethal") then
				Add(8679, "lethal")
			end
		end

		local hasSelectedNonLethal = Add(381637, "nonlethal") or Add(5761, "nonlethal")
		if dragonTempered or not hasSelectedNonLethal then
			Add(3408, "nonlethal")
		end
	else
		Add(315584, "lethal")
		if not Add(381637, "nonlethal") and not Add(5761, "nonlethal") then
			Add(3408, "nonlethal")
		end
	end

	return recommended
end

function Feature:GetSetupSignature()
	local mode = GetDB().roguePoisonUsePvPSuggestions == true and "pvp" or "pve"
	local parts = { mode, tostring(GetSpecialization() or 0) }
	for _, poison in ipairs(self:GetRecommendedPoisons()) do
		parts[#parts + 1] = tostring(poison.spellID)
	end
	return table.concat(parts, ":")
end

function Feature:GetWarnings()
	if self.auraDataRestricted then
		return nil
	end

	local active = {}
	local activeByID = {}
	local activeCounts = { lethal = 0, nonlethal = 0 }
	for _, poison in ipairs(POISONS) do
		local aura = GetPoisonAura(poison.spellID)
		if aura then
			local remaining = GetRemainingDuration(aura)
			if remaining == nil then
				return nil
			end
			active[#active + 1] = {
				spellID = poison.spellID,
				category = poison.category,
				remaining = remaining,
			}
			activeByID[poison.spellID] = true
			activeCounts[poison.category] = activeCounts[poison.category] + 1
		end
	end

	local warnings = {}
	for _, poison in ipairs(active) do
		if poison.remaining < WARNING_THRESHOLD then
			warnings[#warnings + 1] = poison
		end
	end

	local recommended = self:GetRecommendedPoisons()
	local requiredCounts = { lethal = 0, nonlethal = 0 }
	for _, poison in ipairs(recommended) do
		requiredCounts[poison.category] = requiredCounts[poison.category] + 1
	end
	local setupComplete = #recommended > 0
		and activeCounts.lethal >= requiredCounts.lethal
		and activeCounts.nonlethal >= requiredCounts.nonlethal

	if setupComplete and (self.recommendationActive or (not self.setupEstablished and #active > 0)) then
		self.recommendationActive = nil
		self.setupEstablished = true
		self.expectedPoisons = {}
		for _, poison in ipairs(active) do
			self.expectedPoisons[poison.spellID] = true
		end
		self:SetSlotOrder(active)
	elseif self.setupEstablished then
		if setupComplete then
			self.recommendationActive = nil
			self.expectedPoisons = {}
			for _, poison in ipairs(active) do
				self.expectedPoisons[poison.spellID] = true
			end
			self:SetSlotOrder(active)
		else
			self.recommendationActive = true
		end
	elseif #active == 0 then
		self.recommendationActive = true
	end
	if not self.slotBySpellID then
		self:SetSlotOrder(#active > 0 and active or recommended)
	end

	if self.recommendationActive then
		if self.setupEstablished and self.expectedPoisons then
			for _, poison in ipairs(POISONS) do
				if self.expectedPoisons[poison.spellID] and not activeByID[poison.spellID] then
					warnings[#warnings + 1] = {
						spellID = poison.spellID,
						missing = true,
					}
				end
			end
		else
			local missingCounts = {
				lethal = math.max(0, requiredCounts.lethal - activeCounts.lethal),
				nonlethal = math.max(0, requiredCounts.nonlethal - activeCounts.nonlethal),
			}
			for _, poison in ipairs(recommended) do
				if not activeByID[poison.spellID] and missingCounts[poison.category] > 0 then
					warnings[#warnings + 1] = {
						spellID = poison.spellID,
						missing = true,
					}
					missingCounts[poison.category] = missingCounts[poison.category] - 1
				end
			end
		end
	end

	return warnings
end

local function SetBorderColor(button, r, g, b, a)
	for _, edge in ipairs(button.Border) do
		edge:SetColorTexture(r, g, b, a)
	end
end

function Feature:DisplayWarnings(warnings)
	local frame = self:EnsureFrame()
	if not frame then
		self.pendingUpdate = true
		return
	end

	for _, button in pairs(frame.Buttons) do
		button:Hide()
	end

	if #warnings == 0 then
		frame:Hide()
		return
	end

	for _, warning in ipairs(warnings) do
		local button = frame.Buttons[warning.spellID]
		local slot = self:GetButtonSlot(warning.spellID)
		if button and slot then
			button:ClearAllPoints()
			local x = (slot - 1) * (BUTTON_SIZE + BUTTON_SPACING)
			local y = GetDB().roguePoisonReminderLocked == true and 0 or -DRAG_HANDLE_HEIGHT
			button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
			if warning.missing then
				button.Remaining:SetText("")
				button.Marker:Show()
				SetBorderColor(button, 1, 0.72, 0.15, 0.9)
			else
				button.Remaining:SetText(FormatRemaining(warning.remaining))
				button.Marker:Hide()
				SetBorderColor(button, 1, 0.2, 0.1, 0.9)
			end
			button:Show()
		end
	end

	frame:Show()
end

function Feature:Refresh()
	if InCombatLockdown() then
		self.pendingUpdate = true
		return
	end

	self.pendingUpdate = nil
	if not self._enabled or not IsRogue() then
		if self.frame then
			self.frame:Hide()
		end
		return
	end

	local setupSignature = self:GetSetupSignature()
	if self.setupSignature and self.setupSignature ~= setupSignature then
		self.recommendationActive = true
		self.setupEstablished = nil
		self.expectedPoisons = nil
		self.slotBySpellID = nil
		self.spellIDBySlot = nil
	end
	self.setupSignature = setupSignature

	local warnings = self:GetWarnings()
	if not warnings then
		if self.frame then
			self.frame:Hide()
		end
		return
	end
	self:DisplayWarnings(warnings)
end

function Feature:Enable()
	self._enabled = true
	local suggestionMode = GetDB().roguePoisonUsePvPSuggestions == true and "pvp" or "pve"
	if self.suggestionMode and self.suggestionMode ~= suggestionMode then
		self.recommendationActive = nil
		self.setupEstablished = nil
		self.expectedPoisons = nil
	end
	self.suggestionMode = suggestionMode
	self:ApplyLock()
	if not self.ticker then
		self.ticker = C_Timer.NewTicker(10, function()
			self:Refresh()
		end)
	end
	self:Refresh()
end

function Feature:Disable()
	self._enabled = false
	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end
	self:Refresh()
end

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
EventFrame:RegisterEvent("SPELLS_CHANGED")
EventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
EventFrame:RegisterEvent("AURA_DATA_PROVIDER_SWITCH")
EventFrame:RegisterUnitEvent("UNIT_AURA", "player")
EventFrame:SetScript("OnEvent", function(_, event, unit)
	if event == "AURA_DATA_PROVIDER_SWITCH" then
		Feature.auraDataRestricted = not unit
	end
	if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then
		return
	end
	if event == "PLAYER_REGEN_ENABLED" and Feature.pendingDragStop then
		Feature:StopDragging()
	end
	if event == "PLAYER_REGEN_ENABLED" and Feature.pendingLockUpdate then
		Feature:ApplyLock()
	end
	if Feature._enabled or event == "PLAYER_REGEN_ENABLED" then
		Feature:Refresh()
	end
end)
