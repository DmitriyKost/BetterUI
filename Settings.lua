local ADDON_NAME, NS = ...

local function CreateCheckbox(parent, label, tooltip, key, y, x)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetPoint("TOPLEFT", x or 16, y)

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

local function ParseActionBarIDs(value)
	local ids = {}
	for id in tostring(value or ""):gmatch("%d+") do
		id = tonumber(id)
		if id and id >= 1 and id <= 12 then
			ids[id] = true
		end
	end
	return ids
end

local function SerializeActionBarIDs(ids)
	local values = {}
	for id = 1, 12 do
		if ids[id] then
			values[#values + 1] = id
		end
	end
	return table.concat(values, ",")
end

local function CreateActionBarCheckbox(parent, key, barID, x, y, tooltip)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetPoint("TOPLEFT", x, y)
	cb._key = key
	cb._barID = barID
	cb.tooltipText = tooltip

	local db = _G.BetterUIDB or NS.DB or {}
	cb:SetChecked(ParseActionBarIDs(db[key])[barID] and true or false)

	cb:SetScript("OnClick", function(self)
		_G.BetterUIDB = _G.BetterUIDB or {}
		local ids = ParseActionBarIDs(_G.BetterUIDB[self._key])
		ids[self._barID] = self:GetChecked() and true or nil
		_G.BetterUIDB[self._key] = SerializeActionBarIDs(ids)
		NS.DB = _G.BetterUIDB

		if NS.ApplySettings then
			NS.ApplySettings()
		end
		if NS.FireSettingChanged then
			NS.FireSettingChanged()
		end
	end)

	cb:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.tooltipText)
		GameTooltip:Show()
	end)
	cb:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	return cb
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

local SECTION_HEADER_HEIGHT = 24
local SECTION_CONTENT_OFFSET = 28
local SECTION_SPACING = 8

local function CreateCollapsibleSection(panel, root, key, title)
	local section = CreateFrame("Frame", nil, root)
	section:SetPoint("LEFT", root, "LEFT")
	section:SetPoint("RIGHT", root, "RIGHT")

	local previous = panel._buiSections[#panel._buiSections]
	if previous then
		section:SetPoint("TOP", previous, "BOTTOM", 0, -SECTION_SPACING)
	else
		section:SetPoint("TOP", root, "TOP", 0, -60)
	end

	local header = CreateFrame("Button", nil, section)
	header:SetPoint("TOPLEFT", section, "TOPLEFT", 8, 0)
	header:SetPoint("TOPRIGHT", section, "TOPRIGHT", -8, 0)
	header:SetHeight(SECTION_HEADER_HEIGHT)

	local background = header:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.08, 0.08, 0.08, 0.7)

	local highlight = header:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 0.82, 0, 0.08)

	local indicator = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	indicator:SetPoint("LEFT", header, "LEFT", 8, 0)
	indicator:SetWidth(10)
	indicator:SetJustifyH("CENTER")

	local label = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("LEFT", indicator, "RIGHT", 7, 0)
	label:SetText(title)

	local content = CreateFrame("Frame", nil, section)
	content:SetPoint("TOPLEFT", section, "TOPLEFT", 0, -SECTION_CONTENT_OFFSET)
	content:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, -SECTION_CONTENT_OFFSET)

	section.Content = content
	section.Header = header
	section.Label = label
	section.Indicator = indicator
	section.key = key
	section.contentHeight = 0

	function section:RefreshHeight()
		local contentHeight = self.collapsed and 0 or self.contentHeight
		self.Content:SetShown(not self.collapsed)
		self:SetHeight(SECTION_HEADER_HEIGHT + (self.collapsed and 0 or 4 + contentHeight))
		self.Indicator:SetText(self.collapsed and "+" or "-")
		if panel._buiRefreshSectionLayout then
			panel._buiRefreshSectionLayout()
		end
	end

	function section:SetContentHeight(height)
		self.contentHeight = math.max(0, height or 0)
		self.Content:SetHeight(self.contentHeight)
		self:RefreshHeight()
	end

	function section:SetCollapsed(collapsed, persist)
		self.collapsed = collapsed and true or false
		if persist then
			_G.BetterUIDB = _G.BetterUIDB or {}
			_G.BetterUIDB.settingsCollapsedSections = _G.BetterUIDB.settingsCollapsedSections or {}
			_G.BetterUIDB.settingsCollapsedSections[self.key] = self.collapsed or nil
			NS.DB = _G.BetterUIDB
		end
		self:RefreshHeight()
	end

	function section:RefreshCollapsedState()
		local collapsed = (_G.BetterUIDB or {}).settingsCollapsedSections
		self:SetCollapsed(type(collapsed) == "table" and collapsed[self.key] == true, false)
	end

	header:SetScript("OnClick", function()
		section:SetCollapsed(not section.collapsed, true)
	end)

	panel._buiSections[#panel._buiSections + 1] = section
	section:RefreshCollapsedState()
	return section
end

local function BuildPanelUI(panel)
	local root = CreateScrollableContent(panel)

	local title = root:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(ADDON_NAME)

	local sub = root:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	sub:SetText("Quality-of-life tools and small UI enhancements.")

	panel._buiChecks = {}
	panel._buiActionBarChecks = {}
	panel._buiSections = {}
	panel._buiRefreshSectionLayout = function()
		local height = 76
		for i = 1, #panel._buiSections do
			height = height + panel._buiSections[i]:GetHeight()
			if i < #panel._buiSections then
				height = height + SECTION_SPACING
			end
		end
		root:SetHeight(height)

		local scroll = panel._buiScrollFrame
		if scroll then
			scroll:UpdateScrollChildRect()
			local maxScroll = scroll:GetVerticalScrollRange()
			if scroll:GetVerticalScroll() > maxScroll then
				scroll:SetVerticalScroll(maxScroll)
			end
		end
	end

	do
		local section = CreateCollapsibleSection(panel, root, "brewmaster", "Brewmaster")
		local content = section.Content
		local y = -4

		panel._buiChecks[#panel._buiChecks + 1] =
			CreateCheckbox(content, "Enable Stagger bar overlays", "Custom stagger text overlays.", "enableStaggerBar", y)
		y = y - 30

		panel._buiChecks[#panel._buiChecks + 1] = CreateCheckbox(
			content,
			"Enable Black Ox statue removal buttons",
			"Creates /click-safe destroytotem buttons.",
			"enableStatueKill",
			y
		)
		y = y - 30
		section:SetContentHeight(-y + 4)
	end

	do
		local section = CreateCollapsibleSection(panel, root, "general", "General")
		local content = section.Content
		local y = -4

		panel._buiChecks[#panel._buiChecks + 1] =
			CreateCheckbox(content, "Enable Health bar overlays", "HP% / HP / Absorbs overlays.", "enableHealthBar", y)
		y = y - 30

		panel._buiChecks[#panel._buiChecks + 1] = CreateCheckbox(
			content,
			"Show secondary stat rating in Character window",
			"Adds the numeric rating next to the % value (uses Blizzard's same font styling).",
			"enableCharSecondaryStatRatings",
			y
		)
		y = y - 30
		section:SetContentHeight(-y + 4)
	end

	do
		local section = CreateCollapsibleSection(panel, root, "mythicPlus", "Mythic+")
		local content = section.Content
		local y = -4

		panel._buiMythicPlusEnable = CreateCheckbox(
			content,
			"Enable Mythic+ tweaks",
			"Enhances Mythic+ dungeon icons with earned portals and optional run and keystone details.",
			"enableMythicPlusTweaks",
			y
		)
		panel._buiChecks[#panel._buiChecks + 1] = panel._buiMythicPlusEnable
		y = y - 30

		panel._buiMythicPlusStats = CreateCheckbox(
			content,
			"Show level / time / score on icons",
			"Renders best run level, clear time, and dungeon score on each icon.",
			"mythicPlusShowRunStats",
			y,
			32
		)
		panel._buiChecks[#panel._buiChecks + 1] = panel._buiMythicPlusStats
		y = y - 30

		panel._buiMythicPlusKeyHighlight = CreateCheckbox(
			content,
			"Highlight your owned keystone",
			"Adds a gold border to your keystone's dungeon icon and its level to the tooltip.",
			"mythicPlusHighlightOwnedKeystone",
			y,
			32
		)
		panel._buiChecks[#panel._buiChecks + 1] = panel._buiMythicPlusKeyHighlight

		panel._buiRefreshMythicPlusEnabledState = function()
			local db = _G.BetterUIDB or {}
			local enabled = db.enableMythicPlusTweaks and true or false
			SetCheckboxEnabled(panel._buiMythicPlusStats, enabled)
			SetCheckboxEnabled(panel._buiMythicPlusKeyHighlight, enabled)
		end

		panel._buiMythicPlusEnable:HookScript("OnClick", panel._buiRefreshMythicPlusEnabledState)
		panel._buiRefreshMythicPlusEnabledState()
		y = y - 30
		section:SetContentHeight(-y + 4)
	end

	do
		local section = CreateCollapsibleSection(panel, root, "equipmentAudit", "Equipment Audit")
		local content = section.Content
		local y = -4

		panel._buiEquipmentAuditOptions = {}
		panel._buiEquipmentAuditEnable = CreateCheckbox(
			content,
			"Enable equipment audit",
			"Shows item levels, enchants, sockets, and audit warnings on character and inspect frames.",
			"enableCharacterEquipmentAudit",
			y
		)
		panel._buiChecks[#panel._buiChecks + 1] = panel._buiEquipmentAuditEnable
		y = y - 30

		local options = {
			{
				label = "Show item levels",
				tooltip = "Show item level text on equipped items.",
				key = "equipmentAuditShowItemLevels",
			},
			{
				label = "Show item levels in bags",
				tooltip = "Show item level text on equippable items in your bags.",
				key = "equipmentAuditShowBagItemLevels",
			},
			{
				label = "Show enchant indicators",
				tooltip = "Show enchant badges and missing-enchant warnings.",
				key = "equipmentAuditShowEnchants",
			},
			{
				label = "Show socket indicators",
				tooltip = "Show gem icons and empty-socket warnings.",
				key = "equipmentAuditShowSockets",
			},
			{
				label = "Enable on Character frame",
				tooltip = "Show equipment audit information on your character panel.",
				key = "equipmentAuditShowCharacterFrame",
			},
			{
				label = "Enable on Inspect frame",
				tooltip = "Show equipment audit information when inspecting another player.",
				key = "equipmentAuditShowInspectFrame",
			},
		}

		for i = 1, #options do
			local option = options[i]
			local cb = CreateCheckbox(content, option.label, option.tooltip, option.key, y, 32)
			panel._buiEquipmentAuditOptions[#panel._buiEquipmentAuditOptions + 1] = cb
			panel._buiChecks[#panel._buiChecks + 1] = cb
			y = y - 28
		end

		panel._buiRefreshEquipmentAuditEnabledState = function()
			local enabled = _G.BetterUIDB and _G.BetterUIDB.enableCharacterEquipmentAudit and true or false
			for i = 1, #panel._buiEquipmentAuditOptions do
				SetCheckboxEnabled(panel._buiEquipmentAuditOptions[i], enabled)
			end
		end

		panel._buiEquipmentAuditEnable:HookScript("OnClick", panel._buiRefreshEquipmentAuditEnabledState)
		panel._buiRefreshEquipmentAuditEnabledState()
		section:SetContentHeight(-y + 4)
	end

	do
		local section = CreateCollapsibleSection(panel, root, "merchantAssistant", "Merchant Assistant")
		local content = section.Content
		local y = -4

		panel._buiMerchantEnable = CreateCheckbox(
			content,
			"Enable Merchant Assistant",
			"Run selected selling and repair actions when a merchant opens.",
			"enableMerchantAssistant",
			y
		)
		panel._buiChecks[#panel._buiChecks + 1] = panel._buiMerchantEnable
		y = y - 30

		panel._buiMerchantSellJunk =
			CreateCheckbox(content, "Automatically sell junk", "Sell all poor-quality items.", "merchantSellJunk", y, 32)
		panel._buiChecks[#panel._buiChecks + 1] = panel._buiMerchantSellJunk
		y = y - 28

		panel._buiMerchantAutoRepair = CreateCheckbox(
			content,
			"Automatically repair equipment",
			"Repair all damaged equipment when possible.",
			"merchantAutoRepair",
			y,
			32
		)
		panel._buiChecks[#panel._buiChecks + 1] = panel._buiMerchantAutoRepair
		y = y - 28

		panel._buiMerchantGuildRepair = CreateCheckbox(
			content,
			"Prefer guild repair funds",
			"Use available guild repair funds before personal money.",
			"merchantUseGuildRepair",
			y,
			32
		)
		panel._buiChecks[#panel._buiChecks + 1] = panel._buiMerchantGuildRepair

		panel._buiRefreshMerchantEnabledState = function()
			local db = _G.BetterUIDB or {}
			local enabled = db.enableMerchantAssistant and true or false
			SetCheckboxEnabled(panel._buiMerchantSellJunk, enabled)
			SetCheckboxEnabled(panel._buiMerchantAutoRepair, enabled)
			SetCheckboxEnabled(panel._buiMerchantGuildRepair, enabled and db.merchantAutoRepair and true or false)
		end

		panel._buiMerchantEnable:HookScript("OnClick", panel._buiRefreshMerchantEnabledState)
		panel._buiMerchantAutoRepair:HookScript("OnClick", panel._buiRefreshMerchantEnabledState)
		panel._buiRefreshMerchantEnabledState()
		y = y - 30
		section:SetContentHeight(-y + 4)
	end

	do
		local section = CreateCollapsibleSection(panel, root, "actionBars", "Action Bar Control Center")
		local content = section.Content
		local y = -4

		local description = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		description:SetPoint("TOPLEFT", 16, y)
		description:SetText("Choose which adjustments apply to each Blizzard action bar.")
		y = y - 30

		local barHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		barHeader:SetPoint("TOPLEFT", 24, y)
		barHeader:SetText("Action bar")

		local borderHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		borderHeader:SetPoint("TOPLEFT", 190, y)
		borderHeader:SetText("Hide border")

		local macroHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		macroHeader:SetPoint("TOPLEFT", 292, y)
		macroHeader:SetText("Hide macro")

		local clickHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		clickHeader:SetPoint("TOPLEFT", 394, y)
		clickHeader:SetText("Click-through")
		y = y - 24

		local columns = {
			{
				key = "hideActionBarBorders",
				x = 210,
				tooltip = "Hide the decorative border around buttons on Action Bar %d.",
			},
			{
				key = "hideActionBarMacroText",
				x = 310,
				tooltip = "Hide macro names on Action Bar %d.",
			},
			{
				key = "clickThroughActionBars",
				x = 420,
				tooltip = "Prevent mouse clicks from activating buttons on Action Bar %d. Keybinds still work.",
			},
		}

		for barID = 1, 8 do
			local label = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
			label:SetPoint("TOPLEFT", 24, y - 5)
			label:SetText(barID == 1 and "Action Bar 1 (Main)" or ("Action Bar %d"):format(barID))

			for column = 1, #columns do
				local option = columns[column]
				local cb = CreateActionBarCheckbox(
					content,
					option.key,
					barID,
					option.x,
					y,
					option.tooltip:format(barID)
				)
				panel._buiActionBarChecks[#panel._buiActionBarChecks + 1] = cb
			end

			y = y - 28
		end

		y = y - 8
		section:SetContentHeight(-y + 4)
	end

	do
		local section = CreateCollapsibleSection(panel, root, "performance", "Performance Monitor")
		local content = section.Content
		local y = -4
		local hdr = section.Label

	panel._buiRefreshPerformanceEnabledState = function()
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
		SetCheckboxEnabled(panel._buiPerfUseClassColor, enabled)
		SetCheckboxEnabled(panel._buiPerfVertical, enabled)
		SetSliderEnabled(panel._buiPerfFontSlider, enabled)
		SetSliderEnabled(panel._buiPerfIntervalSlider, enabled)
		if panel._buiPerfResetButton then
			panel._buiPerfResetButton:SetEnabled(enabled)
		end
	end

	panel._buiPerfHeader = hdr

	panel._buiPerfEnable = CreateCheckbox(
		content,
		"Enable performance monitor text",
		"Movable text showing FPS / H lat / W lat (toggle what to show below).",
		"enablePerformanceMonitor",
		y
	)
	panel._buiPerfEnable:HookScript("OnClick", function()
		panel._buiRefreshPerformanceEnabledState()
	end)
	panel._buiChecks[#panel._buiChecks + 1] = panel._buiPerfEnable
	y = y - 30

	panel._buiPerfShowFPS = CreateCheckbox(content, "Show FPS", "Show current FPS.", "perfShowFPS", y)
	panel._buiChecks[#panel._buiChecks + 1] = panel._buiPerfShowFPS
	y = y - 30

	panel._buiPerfShowHome = CreateCheckbox(content, "Show Home latency", "Show Home latency (ms).", "perfShowHomeMS", y)
	panel._buiChecks[#panel._buiChecks + 1] = panel._buiPerfShowHome
	y = y - 30

	panel._buiPerfShowWorld =
		CreateCheckbox(content, "Show World latency", "Show World latency (ms).", "perfShowWorldMS", y)
	panel._buiChecks[#panel._buiChecks + 1] = panel._buiPerfShowWorld
	y = y - 30

	panel._buiPerfLocked = CreateCheckbox(
		content,
		"Lock performance frame",
		"Prevents dragging (disables mouse on the frame).",
		"perfLocked",
		y
	)
	panel._buiChecks[#panel._buiChecks + 1] = panel._buiPerfLocked
	y = y - 30

	panel._buiPerfUseClassColor =
		CreateCheckbox(content, "Use class color", "Color performance text using your class color.", "perfUseClassColor", y)
	panel._buiChecks[#panel._buiChecks + 1] = panel._buiPerfUseClassColor
	y = y - 30

	panel._buiPerfVertical = CreateCheckbox(
		content,
		"Stack metrics vertically",
		"Display each enabled metric on a separate line.",
		"perfVertical",
		y
	)
	panel._buiChecks[#panel._buiChecks + 1] = panel._buiPerfVertical
	y = y - 50

	do
		local slider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
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

	do
		local slider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
		slider:SetPoint("TOPLEFT", 16, y)
		slider:SetMinMaxValues(0.25, 2)
		slider:SetValueStep(0.25)
		slider:SetObeyStepOnDrag(true)
		slider:SetWidth(240)

		slider._key = "perfUpdateInterval"
		panel._buiPerfIntervalSlider = slider

		slider.Low:SetText("0.25s")
		slider.High:SetText("2s")

		local function SetLabel(value)
			value = math.floor((tonumber(value) or 0.5) * 4 + 0.5) / 4
			local text = value == math.floor(value) and ("%ds"):format(value) or (("%.2fs"):format(value):gsub("0s$", "s"))
			slider.Text:SetText("Refresh interval: " .. text)
		end

		slider:SetScript("OnValueChanged", function(self, value)
			value = math.floor((tonumber(value) or 0.5) * 4 + 0.5) / 4
			_G.BetterUIDB = _G.BetterUIDB or {}
			_G.BetterUIDB[self._key] = value
			NS.DB = _G.BetterUIDB
			SetLabel(value)

			if NS.ApplySettings then
				NS.ApplySettings()
			end
			if NS.FireSettingChanged then
				NS.FireSettingChanged()
			end
		end)

		slider:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText("Choose how often performance values are refreshed.")
			GameTooltip:Show()
		end)
		slider:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		local value = tonumber((_G.BetterUIDB or {})[slider._key]) or 0.5
		slider:SetValue(value)
		SetLabel(value)
		y = y - 50
	end

	do
		local button = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
		button:SetSize(140, 22)
		button:SetPoint("TOPLEFT", 16, y)
		button:SetText("Reset position")
		button:SetScript("OnClick", function()
			local feature = NS.Features and NS.Features.Performance
			if feature and feature.ResetPosition then
				feature:ResetPosition()
			end
		end)
		panel._buiPerfResetButton = button
		y = y - 40
	end

		section:SetContentHeight(-y + 4)
	end

	panel:SetScript("OnShow", function(self)
		_G.BetterUIDB = _G.BetterUIDB or {}
		for i = 1, #self._buiSections do
			self._buiSections[i]:RefreshCollapsedState()
		end
		for i = 1, #self._buiChecks do
			local cb = self._buiChecks[i]
			cb:SetChecked(_G.BetterUIDB[cb._key] and true or false)
		end
		if self._buiPerfFontSlider then
			local v = tonumber(_G.BetterUIDB[self._buiPerfFontSlider._key]) or 12
			self._buiPerfFontSlider:SetValue(v)
			self._buiPerfFontSlider.Text:SetText(("Performance font size: %d"):format(v))
		end
		if self._buiPerfIntervalSlider then
			local value = tonumber(_G.BetterUIDB[self._buiPerfIntervalSlider._key]) or 0.5
			self._buiPerfIntervalSlider:SetValue(value)
			local text = value == math.floor(value) and ("%ds"):format(value)
				or (("%.2fs"):format(value):gsub("0s$", "s"))
			self._buiPerfIntervalSlider.Text:SetText("Refresh interval: " .. text)
		end
		for i = 1, #self._buiActionBarChecks do
			local cb = self._buiActionBarChecks[i]
			local ids = ParseActionBarIDs(_G.BetterUIDB[cb._key])
			cb:SetChecked(ids[cb._barID] and true or false)
		end
		if self._buiRefreshEquipmentAuditEnabledState then
			self._buiRefreshEquipmentAuditEnabledState()
		end
		if self._buiRefreshMythicPlusEnabledState then
			self._buiRefreshMythicPlusEnabledState()
		end
		if self._buiRefreshMerchantEnabledState then
			self._buiRefreshMerchantEnabledState()
		end
		if self._buiRefreshPerformanceEnabledState then
			self._buiRefreshPerformanceEnabledState()
		end
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
