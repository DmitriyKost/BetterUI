local ADDON_NAME, NS = ...

NS.Features = NS.Features or {}

local Feature = {}
NS.Features.MerchantAssistant = Feature

local EventFrame = CreateFrame("Frame")
local merchantOpen = false
local junkSalePending = false
local moneyBeforeJunkSale

local function FormatMoney(copper)
	return GetMoneyString(copper, true)
end

local function SellJunk()
	if not C_MerchantFrame.IsSellAllJunkEnabled() or C_MerchantFrame.GetNumJunkItems() == 0 then
		return false
	end

	moneyBeforeJunkSale = GetMoney()
	junkSalePending = true
	EventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
	C_MerchantFrame.SellAllJunkItems()
	return true
end

local function RepairItems(db)
	if not merchantOpen or not db.enableMerchantAssistant or not db.merchantAutoRepair or not CanMerchantRepair() then
		return
	end

	local cost, canRepair = GetRepairAllCost()
	if not canRepair or not cost or cost <= 0 then
		return
	end

	if db.merchantUseGuildRepair and CanGuildBankRepair() then
		local allowance = GetGuildBankWithdrawMoney()
		local guildMoney = GetGuildBankMoney()
		local guildAvailable = allowance < 0 and guildMoney or math.min(allowance, guildMoney)
		if guildAvailable > 0 and guildAvailable + GetMoney() >= cost then
			RepairAllItems(true)
			NS.Print("Repaired equipment for " .. FormatMoney(cost) .. " using guild funds where available.")
			return
		end
	end

	if GetMoney() >= cost then
		RepairAllItems(false)
		NS.Print("Repaired equipment for " .. FormatMoney(cost) .. ".")
	else
		NS.Print("Not enough money to repair equipment.")
	end
end

local function HandleMerchantShow()
	local db = _G.BetterUIDB or NS.DB or {}
	if not db.enableMerchantAssistant then
		return
	end

	if db.merchantSellJunk and SellJunk() then
		return
	end

	RepairItems(db)
end

EventFrame:RegisterEvent("MERCHANT_SHOW")
EventFrame:RegisterEvent("MERCHANT_CLOSED")
EventFrame:SetScript("OnEvent", function(_, event)
	if event == "MERCHANT_CLOSED" then
		merchantOpen = false
		junkSalePending = false
		moneyBeforeJunkSale = nil
		EventFrame:UnregisterEvent("BAG_UPDATE_DELAYED")
		return
	end

	if event == "BAG_UPDATE_DELAYED" then
		if not junkSalePending then
			return
		end

		junkSalePending = false
		EventFrame:UnregisterEvent("BAG_UPDATE_DELAYED")
		local earned = math.max(0, GetMoney() - (moneyBeforeJunkSale or GetMoney()))
		moneyBeforeJunkSale = nil
		if earned > 0 then
			NS.Print("Sold junk for " .. FormatMoney(earned) .. ".")
		end
		RepairItems(_G.BetterUIDB or NS.DB or {})
		return
	end

	merchantOpen = true
	HandleMerchantShow()
end)

function Feature:Enable() end

function Feature:Disable() end
