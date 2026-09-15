local _, NS = ...

local FEATURE_NAME = "SpellHistory"
local DEFAULT_QUEUE_SIZE = 6
local MIN_QUEUE_SIZE = 3
local MAX_QUEUE_SIZE = 12
local ENTRY_DURATION = 10
local PENDING_CAST_TTL = 30
local DEFAULT_ICON_SIZE = 38
local MIN_ICON_SIZE = 24
local MAX_ICON_SIZE = 64
local ICON_SPACING = 4
local HANDLE_HEIGHT = 18
local PREVIEW_ICON = 134400
local DISPLAY_SPELL_ALIASES = {
	[1272694] = 1249625, -- Zenith Stomp -> Zenith
}
local XUEN_SPELL_ID = 123904
local Feature = {
	entries = {},
	icons = {},
	pendingCasts = {},
}

local function IsSecret(value)
	return issecretvalue and issecretvalue(value)
end

local function GetSpellIcon(spellID)
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(spellID)
		if info then
			return info.iconID
		end
	end

	if GetSpellInfo then
		local _, _, icon = GetSpellInfo(spellID)
		return icon
	end

	return nil
end

local function GetIconSize()
	local db = _G.BetterUIDB or NS.DB or {}
	local size = math.floor((tonumber(db.spellHistoryIconSize) or DEFAULT_ICON_SIZE) + 0.5)
	return math.max(MIN_ICON_SIZE, math.min(MAX_ICON_SIZE, size))
end

local function GetQueueSize()
	local db = _G.BetterUIDB or NS.DB or {}
	local size = math.floor((tonumber(db.spellHistoryQueueSize) or DEFAULT_QUEUE_SIZE) + 0.5)
	return math.max(MIN_QUEUE_SIZE, math.min(MAX_QUEUE_SIZE, size))
end

local function CanRecordHere()
	local db = _G.BetterUIDB or NS.DB or {}
	local inInstance, instanceType = IsInInstance()
	if not inInstance or instanceType == "none" then
		return db.spellHistoryRecordWorld and true or false
	end
	if instanceType == "party" then
		return db.spellHistoryRecordDungeons and true or false
	end
	if instanceType == "raid" then
		return db.spellHistoryRecordRaids and true or false
	end
	if instanceType == "arena" then
		return db.spellHistoryRecordArenas and true or false
	end
	if instanceType == "pvp" then
		return db.spellHistoryRecordBattlegrounds and true or false
	end
	return false
end

local function IsXuenSpell(spellID)
	if IsSecret(spellID) or not spellID then
		return false
	end
	if spellID == XUEN_SPELL_ID then
		return true
	end

	if C_Spell and C_Spell.GetBaseSpell then
		local baseSpellID = C_Spell.GetBaseSpell(spellID)
		if not IsSecret(baseSpellID) and baseSpellID == XUEN_SPELL_ID then
			return true
		end
	end

	if C_Spell and C_Spell.GetSpellInfo then
		local spellInfo = C_Spell.GetSpellInfo(spellID)
		local xuenInfo = C_Spell.GetSpellInfo(XUEN_SPELL_ID)
		if IsSecret(spellInfo) or IsSecret(xuenInfo) then
			return false
		end
		local spellName = spellInfo and spellInfo.name
		local xuenName = xuenInfo and xuenInfo.name
		if not IsSecret(spellName) and not IsSecret(xuenName) and spellName and spellName == xuenName then
			return true
		end
	end

	return false
end

function Feature:SavePosition()
	if not self.frame then
		return
	end

	local db = _G.BetterUIDB or NS.DB or {}
	local point, _, relativePoint, x, y = self.frame:GetPoint(1)
	db.spellHistoryPoint = point
	db.spellHistoryRelativePoint = relativePoint
	db.spellHistoryX = x
	db.spellHistoryY = y
	_G.BetterUIDB = db
	NS.DB = db
end

function Feature:RestorePosition()
	if not self.frame then
		return
	end

	local db = _G.BetterUIDB or NS.DB or {}
	self.frame:ClearAllPoints()
	if db.spellHistoryPoint and db.spellHistoryRelativePoint and db.spellHistoryX and db.spellHistoryY then
		self.frame:SetPoint(
			db.spellHistoryPoint,
			UIParent,
			db.spellHistoryRelativePoint,
			db.spellHistoryX,
			db.spellHistoryY
		)
	else
		self.frame:SetPoint("CENTER", UIParent, "CENTER", 320, 0)
	end
end

function Feature:ResetPosition()
	local db = _G.BetterUIDB or NS.DB or {}
	db.spellHistoryPoint = nil
	db.spellHistoryRelativePoint = nil
	db.spellHistoryX = nil
	db.spellHistoryY = nil
	_G.BetterUIDB = db
	NS.DB = db
	self:RestorePosition()
end

function Feature:CreateFrame()
	if self.frame then
		return
	end

	local iconSize = GetIconSize()
	local queueSize = GetQueueSize()
	local frameWidth = (queueSize * iconSize) + ((queueSize - 1) * ICON_SPACING)
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(frameWidth, iconSize)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)

	local handle = CreateFrame("Frame", nil, frame)
	handle:SetPoint("BOTTOMLEFT", frame, "TOPLEFT")
	handle:SetSize(frameWidth, HANDLE_HEIGHT)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", function()
		frame:StartMoving()
	end)
	handle:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		self:SavePosition()
	end)

	local handleText = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	handleText:SetPoint("TOPLEFT", handle, "TOPLEFT", 2, -2)
	handleText:SetText("SPELL HISTORY")
	handleText:SetTextColor(1, 0.82, 0)
	frame.handle = handle

	for i = 1, MAX_QUEUE_SIZE do
		local slot = CreateFrame("Frame", nil, frame)
		slot:SetSize(iconSize, iconSize)

		local background = slot:CreateTexture(nil, "BACKGROUND")
		background:SetAllPoints()
		background:SetColorTexture(0.02, 0.02, 0.02, 0.78)

		local icon = slot:CreateTexture(nil, "ARTWORK")
		icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

		local timeText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		timeText:SetPoint("BOTTOM", slot, "BOTTOM", 0, 2)
		timeText:SetTextColor(1, 1, 1)
		local fontPath, fontSize = timeText:GetFont()
		if fontPath and fontSize then
			timeText:SetFont(fontPath, fontSize, "OUTLINE")
		end
		timeText:SetShadowOffset(0, 0)
		timeText:Hide()

		slot.icon = icon
		slot.timeText = timeText
		slot:Hide()
		self.icons[i] = slot
	end

	self.frame = frame
	self.iconSize = iconSize
	self.queueSize = queueSize
	self:RestorePosition()
end

function Feature:ApplyLayout()
	if not self.frame then
		return
	end

	local iconSize = GetIconSize()
	local queueSize = GetQueueSize()
	local frameWidth = (queueSize * iconSize) + ((queueSize - 1) * ICON_SPACING)
	local point, relativeTo, relativePoint, x, y = self.frame:GetPoint(1)
	self.iconSize = iconSize
	self.queueSize = queueSize
	self.frame:SetSize(frameWidth, iconSize)
	self.frame.handle:SetWidth(frameWidth)
	for i = 1, MAX_QUEUE_SIZE do
		self.icons[i]:SetSize(iconSize, iconSize)
	end
	if point then
		self.frame:ClearAllPoints()
		self.frame:SetPoint(point, relativeTo or UIParent, relativePoint, x, y)
	end
	self:Refresh()
end

function Feature:ApplyLock()
	if not self.frame then
		return
	end

	local db = _G.BetterUIDB or NS.DB or {}
	local locked = db.spellHistoryLocked and true or false
	self.frame.handle:EnableMouse(not locked)
	self.frame.handle:SetShown(not locked)
	self:Refresh()
end

function Feature:Refresh()
	if not self.frame then
		return
	end

	local db = _G.BetterUIDB or NS.DB or {}
	local locked = db.spellHistoryLocked and true or false
	local iconSize = self.iconSize or DEFAULT_ICON_SIZE
	local queueSize = self.queueSize or DEFAULT_QUEUE_SIZE

	for i = 1, MAX_QUEUE_SIZE do
		local slot = self.icons[i]
		local entry = self.entries[i]
		slot:ClearAllPoints()
		slot:SetPoint("TOPLEFT", self.frame, "TOPLEFT", (i - 1) * (iconSize + ICON_SPACING), 0)
		if i <= queueSize and entry then
			slot.icon:SetTexture(entry.icon)
			slot.icon:SetAlpha(1)

			local previousEntry = i < queueSize and self.entries[i + 1]
			if previousEntry then
				local elapsed = math.max(0, entry.createdAt - previousEntry.createdAt)
				slot.timeText:SetText(("%.1f"):format(elapsed))
				slot.timeText:Show()
			else
				slot.timeText:Hide()
			end

			slot:Show()
		elseif i <= queueSize and not locked then
			slot.icon:SetTexture(PREVIEW_ICON)
			slot.icon:SetAlpha(0.35)
			slot.timeText:Hide()
			slot:Show()
		else
			slot.timeText:Hide()
			slot:Hide()
		end
	end

	local count = #self.entries
	self.frame:SetShown(self._enabled and (not locked or (CanRecordHere() and count > 0)))
end

function Feature:StopExpirationTimer()
	if self._expirationTimer then
		self._expirationTimer:Cancel()
		self._expirationTimer = nil
	end
end

function Feature:RemoveExpiredEntries()
	local now = GetTime()
	local changed = false
	for i = #self.entries, 1, -1 do
		if self.entries[i].expiresAt <= now then
			table.remove(self.entries, i)
			changed = true
		end
	end

	if changed then
		self:Refresh()
	end
	self:ScheduleExpiration()
end

function Feature:ScheduleExpiration()
	self:StopExpirationTimer()
	if not self._enabled or #self.entries == 0 then
		return
	end

	local nextExpiration = self.entries[1].expiresAt
	for i = 2, #self.entries do
		nextExpiration = math.min(nextExpiration, self.entries[i].expiresAt)
	end
	self._expirationTimer = C_Timer.NewTimer(math.max(0.05, nextExpiration - GetTime()), function()
		self._expirationTimer = nil
		if not self._enabled then
			return
		end
		self:RemoveExpiredEntries()
	end)
end

function Feature:Clear()
	for i = #self.entries, 1, -1 do
		self.entries[i] = nil
	end
	for castGUID in pairs(self.pendingCasts) do
		self.pendingCasts[castGUID] = nil
	end
	self:StopExpirationTimer()
	self:Refresh()
end

function Feature:PrunePendingCasts(now)
	now = now or GetTime()
	for castGUID, pending in pairs(self.pendingCasts) do
		if now - pending.createdAt > PENDING_CAST_TTL then
			self.pendingCasts[castGUID] = nil
		end
	end
end

function Feature:TrackPendingCast(castGUID, spellID)
	if not self._enabled or IsSecret(castGUID) or IsSecret(spellID) then
		return
	end
	if not CanRecordHere() or not castGUID or not spellID then
		return
	end

	local now = GetTime()
	self:PrunePendingCasts(now)
	self.pendingCasts[castGUID] = {
		spellID = spellID,
		createdAt = now,
	}
end

function Feature:ResolvePendingCast(castGUID, spellID, succeeded)
	if IsSecret(castGUID) or not castGUID then
		return
	end

	local pending = self.pendingCasts[castGUID]
	self.pendingCasts[castGUID] = nil
	if not succeeded or not self._enabled then
		return
	end

	if pending then
		self:RecordCast(castGUID, pending.spellID)
		return
	end

	-- Xuen has historically needed a SUCCEEDED-only fallback on some clients.
	if not IsSecret(spellID) and IsXuenSpell(spellID) then
		self:RecordCast(castGUID, XUEN_SPELL_ID)
	end
end

function Feature:RecordCast(castGUID, spellID)
	if not self._enabled or IsSecret(castGUID) or IsSecret(spellID) then
		return
	end
	if not CanRecordHere() then
		return
	end
	if not castGUID or not spellID then
		return
	end
	for i = 1, #self.entries do
		if self.entries[i].castGUID == castGUID then
			return
		end
	end

	if IsXuenSpell(spellID) then
		spellID = XUEN_SPELL_ID
	else
		spellID = DISPLAY_SPELL_ALIASES[spellID] or spellID
	end
	local now = GetTime()
	local newest = self.entries[1]
	if spellID == XUEN_SPELL_ID and newest and newest.spellID == spellID and now - newest.createdAt < 1 then
		return
	end
	local icon = GetSpellIcon(spellID)
	if IsSecret(icon) then
		return
	end
	icon = icon or 134400

	table.insert(self.entries, 1, {
		castGUID = castGUID,
		spellID = spellID,
		icon = icon,
		createdAt = now,
		expiresAt = now + ENTRY_DURATION,
	})

	self:Refresh()
	self:ScheduleExpiration()
end

function Feature:Enable()
	if self._enabled then
		return
	end

	self._enabled = true
	self:CreateFrame()
	self:ApplyLayout()
	self:ApplyLock()

	if not self._settingsHooked then
		self._settingsHooked = true
		NS.OnSettingChanged(function()
			if self._enabled then
				if not CanRecordHere() then
					self:Clear()
				end
				self:ApplyLayout()
				self:ApplyLock()
			end
		end)
	end
end

function Feature:Disable()
	if not self._enabled then
		return
	end

	self._enabled = false
	self:Clear()
	if self.frame then
		self.frame:Hide()
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED_QUIET", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		if Feature._enabled then
			Feature:Clear()
		end
		return
	end

	if event == "UNIT_SPELLCAST_SENT" then
		local _, _, castGUID, spellID = ...
		Feature:TrackPendingCast(castGUID, spellID)
		return
	end

	local _, castGUID, spellID = ...
	Feature:ResolvePendingCast(castGUID, spellID, event == "UNIT_SPELLCAST_SUCCEEDED")
end)

NS.Features[FEATURE_NAME] = Feature
