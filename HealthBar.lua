--[[
Enhances DEFAULT Blizzard PlayerFrame health bar:
- Hides Blizzard HP text
- Adds overlays:
    Left   = HP% (copied from Blizzard LeftText)
    Center = Current HP (abbreviated)
    Right  = Total absorbs (abbreviated)
]]

local ADDON_NAME, NS = ...

NS.Features = NS.Features or {}
NS.Features.HealthBar = NS.Features.HealthBar or {}
local Feature = NS.Features.HealthBar

function Feature:IsEnabled()
	return self._enabled == true
end

local function AbbrevBestEffort(n)
	if n == nil then
		return ""
	end
	if AbbreviateNumbers then
		local ok, out = pcall(AbbreviateNumbers, n)
		if ok and out ~= nil then
			return out
		end
	end
	local ok, out = pcall(tostring, n)
	if ok and out ~= nil then
		return out
	end
	return ""
end

local function GetHealthBar()
	return _G.PlayerFrame and _G.PlayerFrame.healthbar or nil
end

local function HideBlizzHPText(hb)
	local regions = {}

	if hb.TextString then
		regions[#regions + 1] = hb.TextString
	end
	if hb.LeftText then
		regions[#regions + 1] = hb.LeftText
	end
	if hb.RightText then
		regions[#regions + 1] = hb.RightText
	end
	if hb.Text and hb.Text ~= hb.TextString then
		regions[#regions + 1] = hb.Text
	end
	if hb.valueText and hb.valueText ~= hb.TextString then
		regions[#regions + 1] = hb.valueText
	end
	if hb.ValueText and hb.ValueText ~= hb.TextString then
		regions[#regions + 1] = hb.ValueText
	end

	for i = 1, #regions do
		local r = regions[i]
		if r and r.SetAlpha then
			r:SetAlpha(0)
		end
	end
end

local function RestoreBlizzHPText(hb)
	if not hb then
		return
	end
	if hb.TextString and hb.TextString.SetAlpha then
		hb.TextString:SetAlpha(1)
	end
	if hb.LeftText and hb.LeftText.SetAlpha then
		hb.LeftText:SetAlpha(1)
	end
	if hb.RightText and hb.RightText.SetAlpha then
		hb.RightText:SetAlpha(1)
	end
	if hb.Text and hb.Text.SetAlpha then
		hb.Text:SetAlpha(1)
	end
	if hb.valueText and hb.valueText.SetAlpha then
		hb.valueText:SetAlpha(1)
	end
	if hb.ValueText and hb.ValueText.SetAlpha then
		hb.ValueText:SetAlpha(1)
	end
end

local function ApplyOutlineFont(refFS, fs)
	local flags = "OUTLINE"
	if refFS and refFS.GetFont then
		local path, size = refFS:GetFont()
		if path and size then
			fs:SetFont(path, size, flags)
			return
		end
	end
	if STANDARD_TEXT_FONT then
		fs:SetFont(STANDARD_TEXT_FONT, 12, flags)
	end
end

local function EnsureOverlays(hb)
	if hb.__BUI_HPLeft and hb.__BUI_HPCenter and hb.__BUI_HPRight then
		return hb.__BUI_HPLeft, hb.__BUI_HPCenter, hb.__BUI_HPRight
	end

	local parent = (hb.TextString and hb.TextString.GetParent and hb.TextString:GetParent()) or hb
	local ref = hb.TextString or hb.LeftText or hb.RightText
	local yOff = 0

	local left = parent:CreateFontString(nil, "OVERLAY")
	left:SetPoint("LEFT", hb, "LEFT", 4, yOff)
	left:SetJustifyH("LEFT")
	left:SetJustifyV("MIDDLE")

	local center = parent:CreateFontString(nil, "OVERLAY")
	center:SetPoint("CENTER", hb, "CENTER", 0, yOff)
	center:SetJustifyH("CENTER")
	center:SetJustifyV("MIDDLE")

	local right = parent:CreateFontString(nil, "OVERLAY")
	right:SetPoint("RIGHT", hb, "RIGHT", -4, yOff)
	right:SetJustifyH("RIGHT")
	right:SetJustifyV("MIDDLE")

	ApplyOutlineFont(ref, left)
	ApplyOutlineFont(ref, center)
	ApplyOutlineFont(ref, right)

	if ref and ref.GetTextColor then
		local r, g, b, a = ref:GetTextColor()
		left:SetTextColor(r, g, b, a)
		center:SetTextColor(r, g, b, a)
		right:SetTextColor(r, g, b, a)
	end

	hb.__BUI_HPLeft = left
	hb.__BUI_HPCenter = center
	hb.__BUI_HPRight = right

	return left, center, right
end

local function ShowOverlays(hb, show)
	if not hb then
		return
	end
	if hb.__BUI_HPLeft then
		hb.__BUI_HPLeft:SetShown(show)
	end
	if hb.__BUI_HPCenter then
		hb.__BUI_HPCenter:SetShown(show)
	end
	if hb.__BUI_HPRight then
		hb.__BUI_HPRight:SetShown(show)
	end
end

local function GetBlizzPercentText(hb)
	if not hb or not hb.LeftText or not hb.LeftText.GetText then
		return ""
	end
	local t = hb.LeftText:GetText()
	if t == nil then
		return ""
	end
	return t
end

local function GetTotalAbsorbText()
	if not UnitGetTotalAbsorbs then
		return ""
	end
	local total = UnitGetTotalAbsorbs("player")
	if total == nil then
		return ""
	end
	return AbbrevBestEffort(total)
end

local function Update()
	if not Feature:IsEnabled() then
		return
	end

	local hb = GetHealthBar()
	if not hb then
		return
	end

	local left, center, right = EnsureOverlays(hb)

	local pctText = GetBlizzPercentText(hb)

	HideBlizzHPText(hb)

	left:SetText(pctText)

	local hp = UnitHealth and UnitHealth("player") or nil
	center:SetText(AbbrevBestEffort(hp))

	right:SetText(GetTotalAbsorbText())
end

local driver = CreateFrame("Frame")
local attached = false

local function TryAttach()
	local hb = GetHealthBar()
	if not hb then
		return false
	end
	if attached then
		return true
	end
	attached = true

	EnsureOverlays(hb)

	if type(hb.SetValue) == "function" then
		hooksecurefunc(hb, "SetValue", function()
			Update()
		end)
	end
	if type(hb.SetMinMaxValues) == "function" then
		hooksecurefunc(hb, "SetMinMaxValues", function()
			Update()
		end)
	end

	local ref = hb.TextString or hb.LeftText or hb.RightText
	if ref and type(ref.SetFont) == "function" then
		hooksecurefunc(ref, "SetFont", function()
			local l, c, r = EnsureOverlays(hb)
			ApplyOutlineFont(ref, l)
			ApplyOutlineFont(ref, c)
			ApplyOutlineFont(ref, r)
		end)
	end

	return true
end

driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
driver:RegisterEvent("UNIT_HEALTH")
driver:RegisterEvent("UNIT_MAXHEALTH")
driver:RegisterEvent("UNIT_AURA")
driver:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")

driver:SetScript("OnEvent", function(_, event, unit)
	if
		event == "UNIT_HEALTH"
		or event == "UNIT_MAXHEALTH"
		or event == "UNIT_AURA"
		or event == "UNIT_ABSORB_AMOUNT_CHANGED"
	then
		if unit ~= "player" then
			return
		end
	end

	if not Feature:IsEnabled() then
		local hb = GetHealthBar()
		if hb then
			ShowOverlays(hb, false)
			RestoreBlizzHPText(hb)
		end
		return
	end

	if not TryAttach() then
		local tries = 0
		local ticker
		ticker = C_Timer.NewTicker(0.25, function()
			tries = tries + 1
			if TryAttach() or tries >= 40 then
				ticker:Cancel()
			end
		end)
		return
	end

	Update()
end)

function Feature:Enable()
	if self._enabled then
		return
	end
	self._enabled = true

	if TryAttach() then
		local hb = GetHealthBar()
		if hb then
			ShowOverlays(hb, true)
		end
		Update()
	end
end

function Feature:Disable()
	if not self._enabled then
		return
	end
	self._enabled = false

	local hb = GetHealthBar()
	if hb then
		ShowOverlays(hb, false)
		RestoreBlizzHPText(hb)
	end
end

if NS.OnSettingChanged then
	NS.OnSettingChanged(function()
		if not NS.DB then
			return
		end
		if NS.DB.enableHealthBar then
			Feature:Enable()
		else
			Feature:Disable()
		end
	end)
end
