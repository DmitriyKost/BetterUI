local ADDON_NAME, NS = ...

NS.Features = NS.Features or {}

local Feature = {}
NS.Features.CharacterEquipmentAudit = Feature

local EQUIPMENT_SLOTS = {
	{ name = "CharacterHeadSlot", id = 1 },
	{ name = "CharacterNeckSlot", id = 2 },
	{ name = "CharacterShoulderSlot", id = 3 },
	{ name = "CharacterChestSlot", id = 5 },
	{ name = "CharacterWaistSlot", id = 6 },
	{ name = "CharacterLegsSlot", id = 7 },
	{ name = "CharacterFeetSlot", id = 8 },
	{ name = "CharacterWristSlot", id = 9 },
	{ name = "CharacterHandsSlot", id = 10 },
	{ name = "CharacterFinger0Slot", id = 11 },
	{ name = "CharacterFinger1Slot", id = 12 },
	{ name = "CharacterTrinket0Slot", id = 13 },
	{ name = "CharacterTrinket1Slot", id = 14 },
	{ name = "CharacterBackSlot", id = 15 },
	{ name = "CharacterMainHandSlot", id = 16 },
	{ name = "CharacterSecondaryHandSlot", id = 17 },
}

local ENCHANTABLE_SLOTS = {
	[1] = true,
	[3] = true,
	[5] = true,
	[7] = true,
	[8] = true,
	[11] = true,
	[12] = true,
	[16] = true,
}

local EMPTY_SOCKET_TEXTURES = {
	EMPTY_SOCKET_META = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Meta",
	EMPTY_SOCKET_RED = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Red",
	EMPTY_SOCKET_YELLOW = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Yellow",
	EMPTY_SOCKET_BLUE = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Blue",
	EMPTY_SOCKET_PRISMATIC = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic",
}

local DEFAULT_EMPTY_SOCKET_TEXTURE = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic"

local EventFrame = CreateFrame("Frame")

local function SafeCall(func, ...)
	if type(func) ~= "function" then
		return nil
	end

	local ok, value = pcall(func, ...)
	if ok then
		return value
	end
	return nil
end

local function GetDetailedItemLevel(itemLink)
	local func = C_Item and C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo
	local level = SafeCall(func, itemLink)
	level = tonumber(level)
	if level then
		return math.floor(level + 0.5)
	end
	return nil
end

local function HasEnchant(itemLink)
	local enchantID = itemLink and itemLink:match("item:%d+:(%-?%d+)")
	enchantID = tonumber(enchantID)
	return enchantID ~= nil and enchantID > 0
end

local function GetGemItemIDs(itemLink)
	local gem1, gem2, gem3, gem4 = itemLink:match("item:[^:]*:[^:]*:([^:]*):([^:]*):([^:]*):([^:]*)")
	return {
		tonumber(gem1) or 0,
		tonumber(gem2) or 0,
		tonumber(gem3) or 0,
		tonumber(gem4) or 0,
	}
end

local function GetSocketTypes(itemLink)
	local func = C_Item and C_Item.GetItemStats or GetItemStats
	local stats = SafeCall(func, itemLink)
	if type(stats) ~= "table" then
		stats = {}
	end

	local sockets = {}
	for stat, value in pairs(stats) do
		if type(stat) == "string" and stat:find("^EMPTY_SOCKET_") then
			for _ = 1, tonumber(value) or 0 do
				sockets[#sockets + 1] = stat
			end
		end
	end

	local gemItemIDs = GetGemItemIDs(itemLink)
	for index = 1, #gemItemIDs do
		if gemItemIDs[index] > 0 then
			while #sockets < index do
				sockets[#sockets + 1] = "EMPTY_SOCKET_PRISMATIC"
			end
		end
	end
	return sockets
end

local function GetGemInfo(itemLink, index)
	local func = C_Item and C_Item.GetItemGem or GetItemGem
	if type(func) == "function" then
		local ok, _, gemLink = pcall(func, itemLink, index)
		if ok and gemLink then
			local iconFunc = C_Item and C_Item.GetItemIconByID or GetItemIcon
			return gemLink, SafeCall(iconFunc, gemLink)
		end
	end

	local gemItemID = GetGemItemIDs(itemLink)[index]
	if not gemItemID or gemItemID == 0 then
		return nil, nil
	end

	local iconFunc = C_Item and C_Item.GetItemIconByID or GetItemIcon
	return gemItemID, SafeCall(iconFunc, gemItemID)
end

local function CanEnchant(slotID, itemLink)
	if ENCHANTABLE_SLOTS[slotID] then
		return true
	end
	if slotID ~= 17 then
		return false
	end

	local func = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
	if type(func) ~= "function" then
		return false
	end

	local ok, _, _, _, equipLocation = pcall(func, itemLink)
	if not ok then
		return false
	end
	return equipLocation == "INVTYPE_WEAPON" or equipLocation == "INVTYPE_WEAPONOFFHAND"
end

local function AddTooltipAudit(tooltip)
	local owner = tooltip and tooltip:GetOwner()
	local messages = owner and owner._buiAuditMessages
	if not Feature._enabled or not messages or #messages == 0 then
		return
	end

	tooltip:AddLine(" ")
	tooltip:AddLine("BetterUI Equipment Audit", 1, 0.82, 0)
	for i = 1, #messages do
		tooltip:AddLine(messages[i], 1, 0.25, 0.25)
	end
	tooltip:Show()
end

local function EnsureTooltipHook()
	if Feature._tooltipHooked then
		return
	end
	if not TooltipDataProcessor or not TooltipDataProcessor.AddTooltipPostCall or not Enum or not Enum.TooltipDataType then
		return
	end

	Feature._tooltipHooked = true
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddTooltipAudit)
end

local function EnsureOverlay(buttonName)
	local button = _G[buttonName]
	if not button then
		return nil
	end
	if button._buiAuditLevel then
		return button
	end

	local level = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	level:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
	level:SetTextColor(1, 1, 1)
	local fontPath, fontSize = level:GetFont()
	if fontPath and fontSize then
		level:SetFont(fontPath, fontSize, "OUTLINE")
	end
	level:SetShadowOffset(0, 0)

	local enchantBorder = button:CreateTexture(nil, "OVERLAY", nil, 6)
	enchantBorder:SetSize(10, 10)
	enchantBorder:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
	enchantBorder:SetColorTexture(0, 0, 0, 1)
	enchantBorder:Hide()

	local enchantBackground = button:CreateTexture(nil, "OVERLAY", nil, 7)
	enchantBackground:SetSize(8, 8)
	enchantBackground:SetPoint("CENTER", enchantBorder)
	enchantBackground:SetColorTexture(0.05, 0.55, 0.65, 1)
	enchantBackground:Hide()

	local enchant = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	enchant:SetDrawLayer("OVERLAY", 8)
	enchant:SetPoint("CENTER", enchantBackground, "CENTER", 0, 1)
	enchant:SetText("+")
	enchant:SetTextColor(1, 1, 1)
	local enchantFontPath = enchant:GetFont()
	if enchantFontPath then
		enchant:SetFont(enchantFontPath, 8)
	end
	enchant:Hide()

	button._buiAuditLevel = level
	button._buiAuditEnchant = enchant
	button._buiAuditEnchantBorder = enchantBorder
	button._buiAuditEnchantBackground = enchantBackground
	button._buiAuditSockets = {}

	if not Feature._tooltipHooked then
		button:HookScript("OnEnter", function(self)
			if GameTooltip:IsOwned(self) then
				AddTooltipAudit(GameTooltip)
			end
		end)
	end

	return button
end

local function HideEquipment(inspecting)
	for i = 1, #EQUIPMENT_SLOTS do
		local slot = EQUIPMENT_SLOTS[i]
		local buttonName = inspecting and slot.name:gsub("^Character", "Inspect") or slot.name
		local button = _G[buttonName]
		if button and button._buiAuditLevel then
			button._buiAuditLevel:Hide()
			button._buiAuditEnchant:Hide()
			button._buiAuditEnchantBorder:Hide()
			button._buiAuditEnchantBackground:Hide()
			for socket = 1, #button._buiAuditSockets do
				button._buiAuditSockets[socket].border:Hide()
				button._buiAuditSockets[socket].icon:Hide()
			end
			button._buiAuditMessages = nil
		end
	end
end

local function HideOverlays()
	HideEquipment(false)
	HideEquipment(true)
end

local function UpdateSlot(slot, buttonName, unit)
	local button = EnsureOverlay(buttonName)
	if not button then
		return
	end

	local itemLink = GetInventoryItemLink(unit, slot.id)
	if not itemLink then
		button._buiAuditLevel:Hide()
		button._buiAuditEnchant:Hide()
		button._buiAuditEnchantBorder:Hide()
		button._buiAuditEnchantBackground:Hide()
		for socket = 1, #button._buiAuditSockets do
			button._buiAuditSockets[socket].border:Hide()
			button._buiAuditSockets[socket].icon:Hide()
		end
		button._buiAuditMessages = nil
		return
	end

	local db = _G.BetterUIDB or NS.DB or {}
	if db.equipmentAuditShowItemLevels then
		local itemLevel = GetDetailedItemLevel(itemLink)
		button._buiAuditLevel:SetText(itemLevel or "")
		button._buiAuditLevel:SetShown(itemLevel ~= nil)
	else
		button._buiAuditLevel:Hide()
	end

	local messages = {}
	if db.equipmentAuditShowEnchants then
		local hasEnchant = HasEnchant(itemLink)
		button._buiAuditEnchant:SetShown(hasEnchant)
		button._buiAuditEnchantBorder:SetShown(hasEnchant)
		button._buiAuditEnchantBackground:SetShown(hasEnchant)

		if CanEnchant(slot.id, itemLink) and not hasEnchant then
			messages[#messages + 1] = "Missing enchant"
		end
	else
		button._buiAuditEnchant:Hide()
		button._buiAuditEnchantBorder:Hide()
		button._buiAuditEnchantBackground:Hide()
	end

	local socketTypes = db.equipmentAuditShowSockets and GetSocketTypes(itemLink) or {}
	local emptySockets = 0
	for index = 1, #socketTypes do
		local socket = button._buiAuditSockets[index]
		if not socket then
			local border = button:CreateTexture(nil, "OVERLAY", nil, 6)
			border:SetSize(9, 9)
			border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -((index - 1) * 9), 0)
			border:SetColorTexture(0, 0, 0, 1)

			local icon = button:CreateTexture(nil, "OVERLAY", nil, 7)
			icon:SetSize(8, 8)
			icon:SetPoint("CENTER", border)
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

			socket = { border = border, icon = icon }
			button._buiAuditSockets[index] = socket
		end

		local gemLink, gemIcon = GetGemInfo(itemLink, index)
		if gemLink then
			socket.icon:SetTexture(gemIcon or DEFAULT_EMPTY_SOCKET_TEXTURE)
		else
			emptySockets = emptySockets + 1
			socket.icon:SetTexture(EMPTY_SOCKET_TEXTURES[socketTypes[index]] or DEFAULT_EMPTY_SOCKET_TEXTURE)
		end
		socket.border:Show()
		socket.icon:Show()
	end
	for index = #socketTypes + 1, #button._buiAuditSockets do
		button._buiAuditSockets[index].border:Hide()
		button._buiAuditSockets[index].icon:Hide()
	end

	if emptySockets > 0 then
		messages[#messages + 1] = emptySockets == 1 and "1 empty socket" or (emptySockets .. " empty sockets")
	end

	button._buiAuditMessages = messages
end

local function UpdateEquipment(unit, inspecting)
	for i = 1, #EQUIPMENT_SLOTS do
		local slot = EQUIPMENT_SLOTS[i]
		local buttonName = inspecting and slot.name:gsub("^Character", "Inspect") or slot.name
		UpdateSlot(slot, buttonName, unit)
	end
end

function Feature:Refresh()
	if not self._enabled then
		HideOverlays()
		return
	end
	if InCombatLockdown() then
		self._pendingRefresh = true
		return
	end
	self._pendingRefresh = false
	local db = _G.BetterUIDB or NS.DB or {}
	if db.equipmentAuditShowCharacterFrame and CharacterFrame and CharacterFrame:IsShown() then
		UpdateEquipment("player", false)
	else
		HideEquipment(false)
	end
	if db.equipmentAuditShowInspectFrame and InspectFrame and InspectFrame:IsShown() then
		local unit = InspectFrame.unit or "target"
		if UnitExists(unit) then
			UpdateEquipment(unit, true)
		else
			HideEquipment(true)
		end
	else
		HideEquipment(true)
	end
end

function Feature:ScheduleRefresh(delay)
	if self._refreshScheduled then
		return
	end

	self._refreshScheduled = true
	C_Timer.After(delay or 0, function()
		self._refreshScheduled = false
		self:Refresh()
	end)
end

function Feature:TryAttach()
	EnsureTooltipHook()
	local attached = false
	if CharacterFrame and not self._characterFrameHooked then
		self._characterFrameHooked = true
		CharacterFrame:HookScript("OnShow", function()
			self:ScheduleRefresh(0.1)
		end)
	end
	if CharacterFrame then
		attached = true
	end

	if InspectFrame and not self._inspectFrameHooked then
		self._inspectFrameHooked = true
		InspectFrame:HookScript("OnShow", function()
			self:ScheduleRefresh(0.1)
		end)
	end
	if InspectFrame then
		attached = true
	end

	return attached
end

function Feature:Enable()
	self._enabled = true
	self:TryAttach()
	self:ScheduleRefresh()
end

function Feature:Disable()
	self._enabled = false
	self._pendingRefresh = false
	HideOverlays()
end

EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
EventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("INSPECT_READY")
EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

EventFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON_NAME and arg1 ~= "Blizzard_CharacterUI" and arg1 ~= "Blizzard_InspectUI" then
			return
		end
		Feature:TryAttach()
	elseif event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then
		local inspectUnit = InspectFrame and InspectFrame.unit
		if not inspectUnit or arg1 ~= inspectUnit then
			return
		end
	elseif event == "PLAYER_REGEN_ENABLED" and not Feature._pendingRefresh then
		return
	end

	if Feature._enabled then
		Feature:ScheduleRefresh(0.1)
	end
end)
