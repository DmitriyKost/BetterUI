--[[
Replaces the DEFAULT Blizzard Brewmaster stagger bar text with a custom overlay:
  - Left side: uncapped stagger percent (integer) (best-effort; blank if secret)
  - Right side: uncapped stagger pool value (always shown)

Implementation:
  - Hides Blizzard numeric regions on MonkStaggerBar (alpha = 0) for this bar only
  - Creates two overlay FontStrings (left/right) with OUTLINE
  - Updates via StatusBar hooks + UNIT_MAXHEALTH
]]

local ADDON_NAME, NS = ...

NS.Features = NS.Features or {}
NS.Features.StaggerBar = NS.Features.StaggerBar or {}
local Feature = NS.Features.StaggerBar

function Feature:IsEnabled()
	return self._enabled == true
end

local function IsBrewmaster()
	local _, class = UnitClass("player")
	if class ~= "MONK" then
		return false
	end
	local spec = GetSpecialization and GetSpecialization()
	return spec == 1
end

local function GetStaggerBar()
	if _G.PlayerFrame and _G.PlayerFrame.activeAlternatePowerBar then
		return _G.PlayerFrame.activeAlternatePowerBar
	end
	return _G.MonkStaggerBar
end

local function HideBlizzText(bar)
	if bar.TextString and bar.TextString.SetAlpha then
		bar.TextString:SetAlpha(0)
	end
	if bar.LeftText and bar.LeftText.SetAlpha then
		bar.LeftText:SetAlpha(0)
	end
	if bar.RightText and bar.RightText.SetAlpha then
		bar.RightText:SetAlpha(0)
	end

	if bar.Text and bar.Text ~= bar.TextString and bar.Text.SetAlpha then
		bar.Text:SetAlpha(0)
	end
	if bar.valueText and bar.valueText ~= bar.TextString and bar.valueText.SetAlpha then
		bar.valueText:SetAlpha(0)
	end
	if bar.ValueText and bar.ValueText ~= bar.TextString and bar.ValueText.SetAlpha then
		bar.ValueText:SetAlpha(0)
	end
end

local function RestoreBlizzText(bar)
	if bar.TextString and bar.TextString.SetAlpha then
		bar.TextString:SetAlpha(1)
	end
	if bar.LeftText and bar.LeftText.SetAlpha then
		bar.LeftText:SetAlpha(1)
	end
	if bar.RightText and bar.RightText.SetAlpha then
		bar.RightText:SetAlpha(1)
	end

	if bar.Text and bar.Text ~= bar.TextString and bar.Text.SetAlpha then
		bar.Text:SetAlpha(1)
	end
	if bar.valueText and bar.valueText ~= bar.TextString and bar.valueText.SetAlpha then
		bar.valueText:SetAlpha(1)
	end
	if bar.ValueText and bar.ValueText ~= bar.TextString and bar.ValueText.SetAlpha then
		bar.ValueText:SetAlpha(1)
	end
end

local function ApplyOutlineFont(fromFS, toFS)
	local flags = "OUTLINE"
	if fromFS and fromFS.GetFont then
		local path, size = fromFS:GetFont()
		if path and size then
			toFS:SetFont(path, size, flags)
			return
		end
	end
	if STANDARD_TEXT_FONT then
		toFS:SetFont(STANDARD_TEXT_FONT, 12, flags)
	end
end

local function EnsureOverlay(bar)
	if bar.__BUI_StaggerLeft and bar.__BUI_StaggerRight then
		return bar.__BUI_StaggerLeft, bar.__BUI_StaggerRight
	end

	local parent = (bar.TextString and bar.TextString.GetParent and bar.TextString:GetParent()) or bar
	local ref = bar.TextString or bar.LeftText or bar.RightText
	local yOff = 0

	local left = parent:CreateFontString(nil, "OVERLAY")
	left:SetPoint("LEFT", bar, "LEFT", 4, yOff)
	left:SetJustifyH("LEFT")
	left:SetJustifyV("MIDDLE")

	local right = parent:CreateFontString(nil, "OVERLAY")
	right:SetPoint("RIGHT", bar, "RIGHT", -4, yOff)
	right:SetJustifyH("RIGHT")
	right:SetJustifyV("MIDDLE")

	ApplyOutlineFont(ref, left)
	ApplyOutlineFont(ref, right)

	if ref and ref.GetTextColor then
		local r, g, b, a = ref:GetTextColor()
		left:SetTextColor(r, g, b, a)
		right:SetTextColor(r, g, b, a)
	end

	bar.__BUI_StaggerLeft = left
	bar.__BUI_StaggerRight = right

	return left, right
end

local function ShowOverlays(bar, show)
	if not bar then
		return
	end
	if bar.__BUI_StaggerLeft then
		bar.__BUI_StaggerLeft:SetShown(show)
	end
	if bar.__BUI_StaggerRight then
		bar.__BUI_StaggerRight:SetShown(show)
	end
end

local function FormatSecretNumber(n)
	if n == nil then
		return ""
	end
	if AbbreviateNumbers then
		return AbbreviateNumbers(n)
	end
	return tostring(n)
end

local function ClearOverlay(bar)
	if not bar then
		return
	end
	local left, right = EnsureOverlay(bar)
	left:SetText("")
	right:SetText("")
end

local function Update(bar)
	if not Feature:IsEnabled() then
		return
	end
	if not bar then
		return
	end

	if not IsBrewmaster() then
		ShowOverlays(bar, false)
		RestoreBlizzText(bar)
		ClearOverlay(bar)
		return
	end

	HideBlizzText(bar)

	local left, right = EnsureOverlay(bar)

	local stagger = UnitStagger and UnitStagger("player") or nil
	if stagger == nil then
		left:SetText("")
		right:SetText("")
		return
	end

	right:SetText(FormatSecretNumber(stagger))

	local pctText = ""
	if scrubsecretvalues and UnitHealthMax then
		local safeStagger, safeMaxHP = scrubsecretvalues(stagger, UnitHealthMax("player"))
		if safeStagger ~= nil and safeMaxHP ~= nil and safeMaxHP > 0 then
			local pct = (safeStagger / safeMaxHP) * 100
			pctText = string.format("%d%%", math.floor(pct + 0.5))
		end
	end
	left:SetText(pctText)
end

local driver = CreateFrame("Frame")
local attached = false

local retryTicker
local retryTries = 0

local function CancelRetry()
	if retryTicker then
		retryTicker:Cancel()
		retryTicker = nil
	end
end

local function TryAttach()
	local bar = GetStaggerBar()
	if not bar then
		return false
	end
	NS.Bar = bar

	if attached then
		return true
	end
	attached = true

	EnsureOverlay(bar)

	if type(bar.SetValue) == "function" and not bar.__BUI_StaggerHookedValue then
		bar.__BUI_StaggerHookedValue = true
		hooksecurefunc(bar, "SetValue", function(self)
			Update(self)
		end)
	end
	if type(bar.SetMinMaxValues) == "function" and not bar.__BUI_StaggerHookedMinMax then
		bar.__BUI_StaggerHookedMinMax = true
		hooksecurefunc(bar, "SetMinMaxValues", function(self)
			Update(self)
		end)
	end

	local ref = bar.TextString or bar.LeftText or bar.RightText
	if ref and type(ref.SetFont) == "function" and not bar.__BUI_StaggerHookedFont then
		bar.__BUI_StaggerHookedFont = true
		hooksecurefunc(ref, "SetFont", function()
			local l, r = EnsureOverlay(bar)
			ApplyOutlineFont(ref, l)
			ApplyOutlineFont(ref, r)
		end)
	end

	CancelRetry()
	return true
end

driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
driver:RegisterEvent("UNIT_MAXHEALTH")

driver:SetScript("OnEvent", function(_, event, unit)
	if event == "UNIT_MAXHEALTH" and unit ~= "player" then
		return
	end

	if not Feature:IsEnabled() then
		CancelRetry()
		local bar = NS.Bar or GetStaggerBar()
		if bar then
			ShowOverlays(bar, false)
			RestoreBlizzText(bar)
		end
		return
	end

	local bar = NS.Bar or GetStaggerBar()
	if bar and not IsBrewmaster() then
		ShowOverlays(bar, false)
		RestoreBlizzText(bar)
		ClearOverlay(bar)
		CancelRetry()
		return
	end

	if not TryAttach() then
		if retryTicker then
			return
		end
		retryTries = 0
		retryTicker = C_Timer.NewTicker(0.25, function()
			retryTries = retryTries + 1
			if TryAttach() or retryTries >= 40 then
				CancelRetry()
				if NS.Bar then
					Update(NS.Bar)
				end
			end
		end)
		return
	end

	ShowOverlays(NS.Bar, true)
	Update(NS.Bar)
end)

function Feature:Enable()
	if self._enabled then
		return
	end
	self._enabled = true

	if not IsBrewmaster() then
		local bar = NS.Bar or GetStaggerBar()
		if bar then
			ShowOverlays(bar, false)
			RestoreBlizzText(bar)
			ClearOverlay(bar)
		end
		return
	end

	if TryAttach() then
		local bar = NS.Bar
		if bar then
			ShowOverlays(bar, true)
			HideBlizzText(bar)
			Update(bar)
		end
	end
end

function Feature:Disable()
	if not self._enabled then
		return
	end
	self._enabled = false

	CancelRetry()

	local bar = NS.Bar or GetStaggerBar()
	if bar then
		ShowOverlays(bar, false)
		RestoreBlizzText(bar)
		ClearOverlay(bar)
	end
end

if NS.OnSettingChanged then
	NS.OnSettingChanged(function()
		local db = _G.BetterUIDB or NS.DB
		if not db then
			return
		end

		if db.enableStaggerBar then
			Feature:Enable()
		else
			Feature:Disable()
		end
	end)
end
