local ADDON_NAME, NS = ...

local function CreateCheckbox(parent, label, tooltip, key, y)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetPoint("TOPLEFT", 16, y)

	cb._key = key

	local text = cb.Text or cb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	if not cb.Text then
		cb.Text = text
		text:SetPoint("LEFT", cb, "RIGHT", 6, 0)
	end
	cb.Text:SetText(label)

	cb.tooltipText = tooltip

	cb:SetChecked(NS.DB and NS.DB[key] and true or false)

	cb:SetScript("OnClick", function(self)
		_G.BetterUIDB = _G.BetterUIDB or {}
		_G.BetterUIDB[self._key] = self:GetChecked() and true or false
		NS.DB = _G.BetterUIDB

		if NS.ApplySettings then
			NS.ApplySettings()
			if NS.FireSettingChanged then
				NS.FireSettingChanged()
			end
		end
	end)

	cb:SetScript("OnEnter", function(self)
		if not self.tooltipText then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.tooltipText)
		GameTooltip:Show()
	end)

	cb:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	return cb
end

local function SetCheckboxEnabled(cb, enabled)
	if not cb then
		return
	end
	cb:SetEnabled(enabled)

	if cb.Text and cb.Text.SetTextColor then
		if enabled then
			cb.Text:SetTextColor(1, 0.82, 0)
		else
			cb.Text:SetTextColor(0.5, 0.5, 0.5)
		end
	end
end

local function SetSliderEnabled(slider, enabled)
	if not slider then
		return
	end
	if slider.SetEnabled then
		slider:SetEnabled(enabled)
	end

	local function SetFS(fs)
		if not fs or not fs.SetTextColor then
			return
		end
		if enabled then
			fs:SetTextColor(1, 0.82, 0)
		else
			fs:SetTextColor(0.5, 0.5, 0.5)
		end
	end

	SetFS(slider.Text)
	SetFS(slider.Low)
	SetFS(slider.High)

	if slider.EnableMouse then
		slider:EnableMouse(enabled)
	end
end

local function CreateScrollableContent(panel)
	local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -8)
	scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -32, 8)

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(1, 1)
	scroll:SetScrollChild(content)

	panel._buiScrollFrame = scroll
	panel._buiScrollContent = content

	panel:HookScript("OnSizeChanged", function(self, width)
		if self._buiScrollContent then
			self._buiScrollContent:SetWidth(math.max(1, width - 48))
		end
	end)

	return content
end

local function BuildPanelUI(panel)
	local root = CreateScrollableContent(panel)

	local title = root:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(ADDON_NAME)

	local sub = root:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	sub:SetText("Quality-of-life tools and small UI enhancements.")

	local y = -60
	panel._buiChecks = {}

	do
		local bHdr = root:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		bHdr:SetPoint("TOPLEFT", 16, y)
		bHdr:SetText("Brewmaster")
		y = y - 24

		panel._buiChecks[#panel._buiChecks + 1] =
			CreateCheckbox(root, "Enable Stagger bar overlays", "Custom stagger text overlays.", "enableStaggerBar", y)
		y = y - 30

		panel._buiChecks[#panel._buiChecks + 1] = CreateCheckbox(
			root,
			"Enable Black Ox statue removal buttons",
			"Creates /click-safe destroytotem buttons.",
			"enableStatueKill",
			y
		)
		y = y - 40
	end

	do
		local gHdr = root:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		gHdr:SetPoint("TOPLEFT", 16, y)
		gHdr:SetText("General")
		y = y - 24

		panel._buiChecks[#panel._buiChecks + 1] =
			CreateCheckbox(root, "Enable Health bar overlays", "HP% / HP / Absorbs overlays.", "enableHealthBar", y)
		y = y - 30

		panel._buiChecks[#panel._buiChecks + 1] = CreateCheckbox(
			root,
			"Show secondary stat rating in Character window",
			"Adds the numeric rating next to the % value (uses Blizzard's same font styling).",
			"enableCharSecondaryStatRatings",
			y
		)
		y = y - 40
	end

	do
		local label = root:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		label:SetPoint("TOPLEFT", 16, y)
		label:SetText("Hide ActionBar borders (IDs, e.g. 1,7,8)")
		y = y - 22

		local edit = CreateFrame("EditBox", nil, root, "InputBoxTemplate")
		edit:SetSize(220, 20)
		edit:SetAutoFocus(false)
		edit:SetPoint("TOPLEFT", 16, y)
		edit:SetMaxLetters(64)

		local function Save()
			_G.BetterUIDB = _G.BetterUIDB or {}
			_G.BetterUIDB.hideActionBarBorders = (edit:GetText() or ""):gsub("%s+", "")
			NS.DB = _G.BetterUIDB
			if NS.ApplySettings then
				NS.ApplySettings()
			end
			if NS.FireSettingChanged then
				NS.FireSettingChanged()
			end
		end

		edit:SetScript("OnEnterPressed", function(self)
			self:ClearFocus()
			Save()
		end)

		edit:SetScript("OnEditFocusLost", function()
			Save()
		end)

		edit:SetScript("OnEscapePressed", function(self)
			local db = _G.BetterUIDB or NS.DB or {}
			self:SetText(db.hideActionBarBorders or "")
			self:ClearFocus()
		end)

		panel._buiActionBarBorderEdit = edit
		y = y - 40
	end

	do
		local label = root:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		label:SetPoint("TOPLEFT", 16, y)
		label:SetText("Hide ActionBar macro text (IDs, e.g. 1,7,8)")
		y = y - 22

		local edit = CreateFrame("EditBox", nil, root, "InputBoxTemplate")
		edit:SetSize(220, 20)
		edit:SetAutoFocus(false)
		edit:SetPoint("TOPLEFT", 16, y)
		edit:SetMaxLetters(64)

		local function Save()
			_G.BetterUIDB = _G.BetterUIDB or {}
			_G.BetterUIDB.hideActionBarMacroText = (edit:GetText() or ""):gsub("%s+", "")
			NS.DB = _G.BetterUIDB

			if NS.ApplySettings then
				NS.ApplySettings()
			end
			if NS.FireSettingChanged then
				NS.FireSettingChanged()
			end
		end

		edit:SetScript("OnEnterPressed", function(self)
			self:ClearFocus()
			Save()
		end)
		edit:SetScript("OnEditFocusLost", Save)

		edit:SetScript("OnEscapePressed", function(self)
			local db = _G.BetterUIDB or NS.DB or {}
			self:SetText(db.hideActionBarMacroText or "")
			self:ClearFocus()
		end)

		panel._buiActionBarMacroTextEdit = edit
		y = y - 40
	end

	do
		local label = root:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		label:SetPoint("TOPLEFT", 16, y)
		label:SetText("Make ActionBars clickthrough (IDs, e.g. 1,7,8)")
		y = y - 22

		local edit = CreateFrame("EditBox", nil, root, "InputBoxTemplate")
		edit:SetSize(220, 20)
		edit:SetAutoFocus(false)
		edit:SetPoint("TOPLEFT", 16, y)
		edit:SetMaxLetters(64)

		local function Save()
			_G.BetterUIDB = _G.BetterUIDB or {}
			_G.BetterUIDB.clickThroughActionBars = (edit:GetText() or ""):gsub("%s+", "")
			NS.DB = _G.BetterUIDB

			if NS.ApplySettings then
				NS.ApplySettings()
			end
			if NS.FireSettingChanged then
				NS.FireSettingChanged()
			end
		end

		edit:SetScript("OnEnterPressed", function(self)
			self:ClearFocus()
			Save()
		end)
		edit:SetScript("OnEditFocusLost", Save)

		edit:SetScript("OnEscapePressed", function(self)
			local db = _G.BetterUIDB or NS.DB or {}
			self:SetText(db.clickThroughActionBars or "")
			self:ClearFocus()
		end)

		panel._buiActionBarClickThroughEdit = edit
		y = y - 40
	end

	local hdr = root:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	hdr:SetPoint("TOPLEFT", 16, y)
	hdr:SetText("Performance Monitor")
	y = y - 24

	local function RefreshPerfEnabledState()
		_G.BetterUIDB = _G.BetterUIDB or {}
		local enabled = _G.BetterUIDB.enablePerformanceMonitor and true or false

		if panel._buiPerfHeader and panel._buiPerfHeader.SetTextColor then
			if enabled then
				panel._buiPerfHeader:SetTextColor(1, 0.82, 0)
			else
				panel._buiPerfHeader:SetTextColor(0.5, 0.5, 0.5)
			end
		end

		SetCheckboxEnabled(panel._buiPerfShowFPS, enabled)
		SetCheckboxEnabled(panel._buiPerfShowHome, enabled)
		SetCheckboxEnabled(panel._buiPerfShowWorld, enabled)
		SetCheckboxEnabled(panel._buiPerfLocked, enabled)
		SetSliderEnabled(panel._buiPerfFontSlider, enabled)
	end

	panel._buiPerfHeader = hdr

	panel._buiPerfEnable = CreateCheckbox(
		root,
		"Enable performance monitor text",
		"Movable text showing FPS / H lat / W lat (toggle what to show below).",
		"enablePerformanceMonitor",
		y
	)
	panel._buiPerfEnable:HookScript("OnClick", function()
		RefreshPerfEnabledState()
	end)
	panel._buiChecks[#panel._buiChecks + 1] = panel._buiPerfEnable
	y = y - 30

	panel._buiPerfShowFPS = CreateCheckbox(root, "Show FPS", "Show current FPS.", "perfShowFPS", y)
	panel._buiChecks[#panel._buiChecks + 1] = panel._buiPerfShowFPS
	y = y - 30

	panel._buiPerfShowHome = CreateCheckbox(root, "Show Home latency", "Show Home latency (ms).", "perfShowHomeMS", y)
	panel._buiChecks[#panel._buiChecks + 1] = panel._buiPerfShowHome
	y = y - 30

	panel._buiPerfShowWorld =
		CreateCheckbox(root, "Show World latency", "Show World latency (ms).", "perfShowWorldMS", y)
	panel._buiChecks[#panel._buiChecks + 1] = panel._buiPerfShowWorld
	y = y - 30

	panel._buiPerfLocked = CreateCheckbox(
		root,
		"Lock performance frame",
		"Prevents dragging (disables mouse on the frame).",
		"perfLocked",
		y
	)
	panel._buiChecks[#panel._buiChecks + 1] = panel._buiPerfLocked
	y = y - 50

	do
		local slider = CreateFrame("Slider", nil, root, "OptionsSliderTemplate")
		slider:SetPoint("TOPLEFT", 16, y)
		slider:SetMinMaxValues(8, 24)
		slider:SetValueStep(1)
		slider:SetObeyStepOnDrag(true)
		slider:SetWidth(240)

		slider._key = "perfFontSize"
		panel._buiPerfFontSlider = slider

		slider.Low:SetText("8")
		slider.High:SetText("24")

		local function SetLabel(v)
			v = math.floor((tonumber(v) or 12) + 0.5)
			slider.Text:SetText(("Performance font size: %d"):format(v))
		end

		local function Refresh()
			_G.BetterUIDB = _G.BetterUIDB or {}
			local v = tonumber(_G.BetterUIDB[slider._key]) or 12
			slider:SetValue(v)
			SetLabel(v)
		end

		slider:SetScript("OnValueChanged", function(self, value)
			value = math.floor((tonumber(value) or 12) + 0.5)
			_G.BetterUIDB = _G.BetterUIDB or {}
			_G.BetterUIDB[self._key] = value
			NS.DB = _G.BetterUIDB

			SetLabel(value)

			if NS.ApplySettings then
				NS.ApplySettings()
				if NS.FireSettingChanged then
					NS.FireSettingChanged()
				end
			end
		end)

		slider:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText("Adjust the font size of the performance text.")
			GameTooltip:Show()
		end)
		slider:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		Refresh()
		y = y - 50
	end

	root:SetHeight(-y + 24)

	panel:SetScript("OnShow", function(self)
		_G.BetterUIDB = _G.BetterUIDB or {}
		for i = 1, #self._buiChecks do
			local cb = self._buiChecks[i]
			cb:SetChecked(_G.BetterUIDB[cb._key] and true or false)
		end
		if self._buiPerfFontSlider then
			local v = tonumber(_G.BetterUIDB[self._buiPerfFontSlider._key]) or 12
			self._buiPerfFontSlider:SetValue(v)
			self._buiPerfFontSlider.Text:SetText(("Performance font size: %d"):format(v))
		end
		if self._buiActionBarBorderEdit then
			local db = _G.BetterUIDB or {}
			self._buiActionBarBorderEdit:SetText(db.hideActionBarBorders or "")
		end
		if self._buiActionBarMacroTextEdit then
			local db = _G.BetterUIDB or {}
			self._buiActionBarMacroTextEdit:SetText(db.hideActionBarMacroText or "")
		end
		if self._buiActionBarClickThroughEdit then
			local db = _G.BetterUIDB or {}
			self._buiActionBarClickThroughEdit:SetText(db.clickThroughActionBars or "")
		end
		RefreshPerfEnabledState()
	end)
end

local function RegisterSettingsCategory()
	if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then
		C_Timer.After(0.5, RegisterSettingsCategory)
		return
	end

	local panel = CreateFrame("Frame")
	BuildPanelUI(panel)

	local category = Settings.RegisterCanvasLayoutCategory(panel, ADDON_NAME, ADDON_NAME)
	Settings.RegisterAddOnCategory(category)

	NS.SettingsCategoryID = category:GetID()
end

SLASH_BETTERUI1 = "/bui"
SlashCmdList.BETTERUI = function()
	if Settings and Settings.OpenToCategory and NS.SettingsCategoryID then
		Settings.OpenToCategory(NS.SettingsCategoryID)
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, addon)
	if addon ~= ADDON_NAME then
		return
	end
	RegisterSettingsCategory()
end)
