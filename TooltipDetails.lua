local ADDON_NAME, NS = ...

NS.Features = NS.Features or {}

local Feature = {}
NS.Features.TooltipDetails = Feature

local function AddDetail(tooltip, label, value)
	if issecretvalue(value) or value == nil or value == "" or value == 0 then
		return false
	end
	tooltip:AddDoubleLine(label, tostring(value), 0.55, 0.8, 1, 1, 1, 1)
	return true
end

local function GetItemLink(data)
	local link = data and data.hyperlink
	if not issecretvalue(link) and link then
		return link
	end

	local guid = data and data.guid
	if not issecretvalue(guid) and guid then
		return C_Item.GetItemLinkByGUID(guid)
	end
	return nil
end

local function ParseItemLink(link)
	if issecretvalue(link) or not link then
		return nil, nil, {}
	end

	local itemID, enchantID, gem1, gem2, gem3, gem4 =
		link:match("item:(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+)")
	local gems = {}
	for _, gemID in ipairs({ gem1, gem2, gem3, gem4 }) do
		gemID = tonumber(gemID)
		if gemID and gemID > 0 then
			gems[#gems + 1] = gemID
		end
	end
	return tonumber(itemID), tonumber(enchantID), gems
end

local function ProcessItemTooltip(tooltip, data)
	local db = _G.BetterUIDB or NS.DB or {}
	if not db.tooltipShowItemID and not db.tooltipShowEnchantID and not db.tooltipShowGemIDs then
		return
	end

	local itemID, enchantID, gems = ParseItemLink(GetItemLink(data))
	local changed = false
	if db.tooltipShowItemID then
		changed = AddDetail(tooltip, "Item ID", itemID or (data and data.id)) or changed
	end
	if db.tooltipShowEnchantID and enchantID and enchantID > 0 then
		changed = AddDetail(tooltip, "Enchant ID", enchantID) or changed
	end
	if db.tooltipShowGemIDs and #gems > 0 then
		changed = AddDetail(tooltip, "Gem IDs", table.concat(gems, ", ")) or changed
	end
	if changed then
		tooltip:Show()
	end
end

local function ResolveSpellOverride(spellID)
	if issecretvalue(spellID) or spellID == nil then
		return nil
	end
	spellID = tonumber(spellID)
	if not spellID then
		return spellID
	end

	local overrideID = C_SpellBook.FindSpellOverrideByID(spellID)
	if not issecretvalue(overrideID) and overrideID and overrideID > 0 then
		return overrideID
	end
	return spellID
end

local function GetMacroSpellID(macroID)
	if issecretvalue(macroID) or not macroID then
		return nil
	end

	local spellID = GetMacroSpell(macroID)
	if issecretvalue(spellID) then
		return nil
	end
	return spellID
end

local function ProcessSpellTooltip(tooltip, data, allowDataID, fallbackID)
	local db = _G.BetterUIDB or NS.DB or {}
	if not db.tooltipShowSpellID then
		return
	end

	local spellID = allowDataID and data and data.id or nil
	if issecretvalue(spellID) then
		return
	end
	spellID = spellID or fallbackID
	spellID = ResolveSpellOverride(spellID)
	if tooltip._buiSpellDetailID == spellID then
		return
	end
	if AddDetail(tooltip, "Spell ID", spellID) then
		tooltip._buiSpellDetailID = spellID
		tooltip:Show()
	end
end

local function ProcessDirectSpellTooltip(tooltip, data)
	ProcessSpellTooltip(tooltip, data, true)
end

local function ProcessMacroTooltip(tooltip, data)
	ProcessSpellTooltip(tooltip, data, false, GetMacroSpellID(data and data.id))
end

local function ProcessActionTooltip(tooltip, actionSlot)
	local db = _G.BetterUIDB or NS.DB or {}
	if not db.tooltipShowSpellID then
		return
	end

	local fallbackID
	local actionType, actionID, actionSubType = GetActionInfo(actionSlot)
	if issecretvalue(actionType) or issecretvalue(actionID) or issecretvalue(actionSubType) then
		return
	end
	if actionType == "spell" then
		fallbackID = actionID
	elseif actionType == "macro" and actionSubType == "spell" then
		fallbackID = actionID
	end
	ProcessSpellTooltip(tooltip, nil, false, fallbackID)
end

local function ProcessUnitTooltip(tooltip, data)
	local db = _G.BetterUIDB or NS.DB or {}
	if not db.tooltipShowNPCID then
		return
	end

	local guid = data and data.guid
	if issecretvalue(guid) or not guid then
		return
	end

	local unitType, _, _, _, _, npcID = strsplit("-", guid)
	if unitType ~= "Creature" and unitType ~= "Vehicle" then
		return
	end
	if AddDetail(tooltip, "NPC ID", tonumber(npcID)) then
		tooltip:Show()
	end
end

local function RegisterPostCall(dataType, callback)
	if dataType then
		TooltipDataProcessor.AddTooltipPostCall(dataType, callback)
	end
end

function Feature:Enable()
	if self._hooked or not TooltipDataProcessor or not Enum or not Enum.TooltipDataType then
		return
	end

	self._hooked = true
	RegisterPostCall(Enum.TooltipDataType.Item, ProcessItemTooltip)
	RegisterPostCall(Enum.TooltipDataType.Spell, ProcessDirectSpellTooltip)
	RegisterPostCall(Enum.TooltipDataType.Macro, ProcessMacroTooltip)
	RegisterPostCall(Enum.TooltipDataType.Unit, ProcessUnitTooltip)

	if GameTooltip and GameTooltip.SetAction then
		GameTooltip:HookScript("OnTooltipCleared", function(tooltip)
			tooltip._buiSpellDetailID = nil
		end)
		hooksecurefunc(GameTooltip, "SetAction", ProcessActionTooltip)
	end
end

function Feature:Disable() end
