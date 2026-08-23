local ADDON_NAME, NS = ...

NS.Features = NS.Features or {}

local Feature = {}
NS.Features.ModernChat = Feature

local TAB_TEXTURE_KEYS = {
	"Left",
	"Middle",
	"Right",
	"ActiveLeft",
	"ActiveMiddle",
	"ActiveRight",
	"HighlightLeft",
	"HighlightMiddle",
	"HighlightRight",
}

local EDIT_BOX_TEXTURE_SUFFIXES = {
	"Left",
	"Mid",
	"Right",
	"FocusLeft",
	"FocusMid",
	"FocusRight",
}

local HIDDEN_CHAT_TEXTURE_SUFFIXES = {
	"Background",
}

local function GetDB()
	return _G.BetterUIDB or NS.DB or {}
end

local function HideNativeChatTextures(frame)
	frame._buiNativeChatTextureState = frame._buiNativeChatTextureState or {}
	for _, suffix in ipairs(HIDDEN_CHAT_TEXTURE_SUFFIXES) do
		local texture = _G[frame:GetName() .. suffix]
		if texture then
			if frame._buiNativeChatTextureState[suffix] == nil then
				frame._buiNativeChatTextureState[suffix] = texture:IsShown()
			end
			texture:Hide()
		end
	end
end

local function RestoreNativeChatTextures(frame)
	local state = frame._buiNativeChatTextureState
	if not state then
		return
	end

	local frameName = frame:GetName()
	local border = _G[frameName .. "TopTexture"]
	local alpha = border and border:GetAlpha() or frame.oldAlpha or DEFAULT_CHATFRAME_ALPHA
	for suffix, shown in pairs(state) do
		local texture = _G[frameName .. suffix]
		if texture then
			texture:SetAlpha(alpha)
			texture:SetShown(shown)
		end
	end
	frame._buiNativeChatTextureState = nil
end

local function SetBackdropState(frame, active)
	local backdrop = frame._buiModernBackdrop
	if not backdrop then
		return
	end

	local db = GetDB()
	local dynamic = db.modernChatDynamicOpacity == true
	local configuredAlpha = frame.oldAlpha or DEFAULT_CHATFRAME_ALPHA or 0.25
	local scale = dynamic and (active and 2.08 or 0.56) or 1.44
	local alpha = math.min(1, configuredAlpha * scale)
	backdrop.Background:SetAlpha(alpha)
end

local function UpdateBackdropColor(frame)
	local backdrop = frame._buiModernBackdrop
	local nativeBackground = frame.Background
	if not backdrop or not nativeBackground then
		return
	end

	local r, g, b = nativeBackground:GetVertexColor()
	backdrop.Background:SetColorTexture(r, g, b, 1)
end

local function UpdateBackdropAnchors(frame, includeEditBox)
	local backdrop = frame._buiModernBackdrop
	local nativeBackground = frame.Background
	if not backdrop or not nativeBackground then
		return
	end

	local background = backdrop.Background
	background:ClearAllPoints()
	background:SetPoint("TOPLEFT", nativeBackground, "TOPLEFT")
	if includeEditBox and frame.editBox then
		background:SetPoint("BOTTOMRIGHT", frame.editBox, "BOTTOMRIGHT")
	else
		background:SetPoint("BOTTOMRIGHT", nativeBackground, "BOTTOMRIGHT")
	end
end

local function EnsureBackdrop(frame)
	if frame._buiModernBackdrop then
		return frame._buiModernBackdrop
	end

	local background = frame:CreateTexture(nil, "BACKGROUND", nil, -8)

	local backdrop = {
		Background = background,
	}
	frame._buiModernBackdrop = backdrop
	UpdateBackdropColor(frame)
	UpdateBackdropAnchors(frame, frame.editBox and frame.editBox:IsShown())
	return backdrop
end

local function SetBackdropShown(frame, shown)
	local backdrop = shown and EnsureBackdrop(frame) or frame._buiModernBackdrop
	if not backdrop then
		return
	end
	backdrop.Background:SetShown(shown)
end

local function HideNativeTabTextures(tab)
	tab._buiNativeTabTextureState = tab._buiNativeTabTextureState or {}
	for _, key in ipairs(TAB_TEXTURE_KEYS) do
		local texture = tab[key]
		if texture then
			if tab._buiNativeTabTextureState[key] == nil then
				tab._buiNativeTabTextureState[key] = texture:IsShown()
			end
			texture:Hide()
		end
	end
end

local function RestoreNativeTabTextures(tab)
	local state = tab._buiNativeTabTextureState
	if not state then
		return
	end

	for key, shown in pairs(state) do
		local texture = tab[key]
		if texture then
			texture:SetShown(shown)
		end
	end
	tab._buiNativeTabTextureState = nil
end

local function UpdateTabVisual(tab)
	if not tab._buiModernUnderline then
		return
	end

	local selected = tab._buiModernSelected
	local hovered = tab:IsMouseOver()
	tab._buiModernUnderline:SetShown(selected or hovered)
	tab._buiModernUnderline:SetHeight(selected and 2 or 1)
	tab._buiModernUnderline:SetAlpha(selected and 0.9 or 0.4)

	local color = tab.selectedColorTable or DEFAULT_TAB_SELECTED_COLOR_TABLE or NORMAL_FONT_COLOR
	tab._buiModernUnderline:SetColorTexture(color.r, color.g, color.b, 1)
end

local function EnsureTab(tab)
	if tab._buiModernUnderline then
		return
	end

	local underline = tab:CreateTexture(nil, "ARTWORK", nil, 7)
	underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 8, 4)
	underline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -8, 4)
	underline:SetHeight(2)

	tab._buiModernUnderline = underline

	tab:HookScript("OnEnter", function(self)
		if Feature._enabled then
			UpdateTabVisual(self)
		end
	end)
	tab:HookScript("OnLeave", function(self)
		if Feature._enabled then
			UpdateTabVisual(self)
		end
	end)
end

local function StyleTab(tab, selected)
	if not tab then
		return
	end

	EnsureTab(tab)
	tab._buiModernSelected = selected and true or false
	HideNativeTabTextures(tab)
	UpdateTabVisual(tab)
end

local function RestoreTab(tab)
	if not tab then
		return
	end

	RestoreNativeTabTextures(tab)
	if tab._buiModernUnderline then
		tab._buiModernUnderline:Hide()
	end

	local frame = _G["ChatFrame" .. tab:GetID()]
	if frame and FCFTab_UpdateColors then
		local selected = not frame.isDocked or frame == FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
		FCFTab_UpdateColors(tab, selected)
	end
end

local function HideNativeEditBoxTextures(editBox)
	local name = editBox:GetName()
	if not name then
		return
	end

	editBox._buiNativeTextureAlpha = editBox._buiNativeTextureAlpha or {}
	for _, suffix in ipairs(EDIT_BOX_TEXTURE_SUFFIXES) do
		local texture = _G[name .. suffix]
		if texture then
			if editBox._buiNativeTextureAlpha[suffix] == nil then
				editBox._buiNativeTextureAlpha[suffix] = texture:GetAlpha()
			end
			texture:SetAlpha(0)
		end
	end
end

local function RestoreNativeEditBoxTextures(editBox)
	local name = editBox:GetName()
	local state = editBox._buiNativeTextureAlpha
	if not name or not state then
		return
	end

	for suffix, alpha in pairs(state) do
		local texture = _G[name .. suffix]
		if texture then
			texture:SetAlpha(alpha)
		end
	end
	editBox._buiNativeTextureAlpha = nil
end

local function UpdateEditBoxVisual(editBox, focused)
	if not editBox._buiModernFocusLine then
		return
	end

	local r, g, b = NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b
	if focused and editBox.header and editBox.header:IsShown() then
		r, g, b = editBox.header:GetTextColor()
	end

	editBox._buiModernFocusLine:SetColorTexture(r, g, b, focused and 0.9 or 0.3)
	editBox._buiModernFocusLine:SetShown(focused)
end

local function EnsureEditBox(editBox)
	if not editBox or editBox._buiModernFocusLine then
		return
	end

	local focusLine = editBox:CreateTexture(nil, "ARTWORK", nil, 7)
	focusLine:SetPoint("TOPLEFT", editBox, "TOPLEFT", 8, 0)
	focusLine:SetPoint("TOPRIGHT", editBox, "TOPRIGHT", -8, 0)
	focusLine:SetHeight(1)
	editBox._buiModernFocusLine = focusLine

	editBox:HookScript("OnEditFocusGained", function(self)
		if not Feature._enabled then
			return
		end
		UpdateEditBoxVisual(self, true)
		if self.chatFrame then
			SetBackdropState(self.chatFrame, true)
		end
	end)
	editBox:HookScript("OnEditFocusLost", function(self)
		if not Feature._enabled then
			return
		end
		UpdateEditBoxVisual(self, false)
		if self.chatFrame then
			SetBackdropState(self.chatFrame, self.chatFrame._buiModernHovered or self.chatFrame.hasBeenFaded == true)
		end
	end)
	editBox:HookScript("OnShow", function(self)
		if Feature._enabled and self.chatFrame then
			UpdateBackdropAnchors(self.chatFrame, true)
			SetBackdropState(self.chatFrame, true)
		end
	end)
	editBox:HookScript("OnHide", function(self)
		if Feature._enabled and self.chatFrame then
			UpdateBackdropAnchors(self.chatFrame, false)
			SetBackdropState(self.chatFrame, self.chatFrame._buiModernHovered or self.chatFrame.hasBeenFaded == true)
		end
	end)
end

local function CapturePoints(frame)
	local points = {}
	for index = 1, frame:GetNumPoints() do
		points[index] = { frame:GetPoint(index) }
	end
	return points
end

local function RestorePoints(frame, points)
	frame:ClearAllPoints()
	for _, point in ipairs(points or {}) do
		frame:SetPoint(unpack(point))
	end
end

local function StyleEditBox(editBox)
	if not editBox then
		return
	end

	EnsureEditBox(editBox)
	if not editBox._buiModernStyling then
		editBox._buiModernStyling = true
		editBox._buiOriginalPoints = CapturePoints(editBox)
		editBox._buiOriginalHeight = editBox:GetHeight()
	end

	HideNativeEditBoxTextures(editBox)
	if editBox.chatFrame and editBox.chatFrame.Background then
		editBox:ClearAllPoints()
		editBox:SetPoint("TOPLEFT", editBox.chatFrame.Background, "BOTTOMLEFT")
		editBox:SetPoint("TOPRIGHT", editBox.chatFrame.Background, "BOTTOMRIGHT")
		editBox:SetHeight(28)
		UpdateBackdropAnchors(editBox.chatFrame, editBox:IsShown())
	end
	UpdateEditBoxVisual(editBox, editBox:HasFocus())
end

local function RestoreEditBox(editBox)
	if not editBox then
		return
	end

	RestoreNativeEditBoxTextures(editBox)
	if editBox._buiModernStyling then
		RestorePoints(editBox, editBox._buiOriginalPoints)
		editBox:SetHeight(editBox._buiOriginalHeight)
		editBox._buiModernStyling = nil
		editBox._buiOriginalPoints = nil
		editBox._buiOriginalHeight = nil
	end
	if editBox._buiModernFocusLine then
		editBox._buiModernFocusLine:Hide()
	end
	if editBox.chatFrame then
		UpdateBackdropAnchors(editBox.chatFrame, false)
	end
end

local function IsSelectedChatFrame(frame)
	if not frame.isDocked then
		return true
	end
	return GENERAL_CHAT_DOCK and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) == frame
end

local function IsChatFrameHovered(frame)
	local tab = _G[frame:GetName() .. "Tab"]
	return frame:IsMouseOver(28, -2, -2, 2)
		or (tab and tab:IsMouseOver())
		or (frame.ScrollBar and frame.ScrollBar:IsMouseOver())
		or (frame.ScrollToBottomButton and frame.ScrollToBottomButton:IsMouseOver())
		or (frame.buttonFrame and frame.buttonFrame:IsMouseOver())
		or (frame.editBox and frame.editBox:IsShown() and frame.editBox:IsMouseOver())
end

local function EnsureFrameHoverHook(frame)
	if frame._buiModernHoverHooked then
		return
	end

	frame._buiModernHoverHooked = true
	frame:HookScript("OnUpdate", function(self)
		if not Feature._enabled then
			return
		end

		local hovered = IsChatFrameHovered(self)
		if hovered ~= self._buiModernHovered then
			self._buiModernHovered = hovered
			local focused = self.editBox and self.editBox:HasFocus()
			SetBackdropState(self, hovered or focused or self.hasBeenFaded == true)
		end
	end)
end

local function StyleFrame(frame)
	if not frame then
		return
	end

	if not frame._buiModernStyling then
		frame._buiModernStyling = true
		frame._buiOriginalSpacing = frame:GetSpacing()
	end

	EnsureFrameHoverHook(frame)
	HideNativeChatTextures(frame)
	SetBackdropShown(frame, true)
	frame._buiModernHovered = IsChatFrameHovered(frame)
	SetBackdropState(
		frame,
		frame._buiModernHovered or frame.hasBeenFaded == true or (frame.editBox and frame.editBox:HasFocus())
	)
	StyleEditBox(frame.editBox)
	StyleTab(_G[frame:GetName() .. "Tab"], IsSelectedChatFrame(frame))
end

local function ApplyFrameSettings(frame)
	local db = GetDB()
	StyleFrame(frame)
	frame:SetSpacing(db.modernChatRelaxedSpacing == true and 2 or 0)
end

local function RestoreFrame(frame)
	if not frame or not frame._buiModernStyling then
		return
	end

	RestoreNativeChatTextures(frame)
	SetBackdropShown(frame, false)
	if frame._buiOriginalSpacing ~= nil then
		frame:SetSpacing(frame._buiOriginalSpacing)
	end
	RestoreEditBox(frame.editBox)
	RestoreTab(_G[frame:GetName() .. "Tab"])
	frame._buiModernHovered = nil
	frame._buiModernStyling = nil
	frame._buiOriginalSpacing = nil
end

local function ForEachChatFrame(callback)
	if ChatFrameUtil and ChatFrameUtil.ForEachChatFrame then
		ChatFrameUtil.ForEachChatFrame(callback)
	elseif CHAT_FRAMES then
		for _, name in ipairs(CHAT_FRAMES) do
			callback(_G[name])
		end
	end
end

function Feature:ApplyAll()
	if not self._enabled then
		return
	end

	ForEachChatFrame(ApplyFrameSettings)
end

function Feature:RestoreAll()
	ForEachChatFrame(RestoreFrame)
end

function Feature:InstallHooks()
	if self._hooksInstalled or not FCF_FadeInChatFrame then
		return false
	end

	self._hooksInstalled = true
	hooksecurefunc("FCF_FadeInChatFrame", function(frame)
		if self._enabled then
			SetBackdropState(frame, true)
		end
	end)
	hooksecurefunc("FCF_FadeOutChatFrame", function(frame)
		if self._enabled then
			SetBackdropState(frame, IsChatFrameHovered(frame) or (frame.editBox and frame.editBox:HasFocus()))
		end
	end)
	hooksecurefunc("FCF_SetWindowAlpha", function(frame)
		if self._enabled then
			SetBackdropState(
				frame,
				IsChatFrameHovered(frame) or frame.hasBeenFaded == true or (frame.editBox and frame.editBox:HasFocus())
			)
		end
	end)
	hooksecurefunc("FCF_SetWindowColor", function(frame)
		if self._enabled then
			UpdateBackdropColor(frame)
		end
	end)
	hooksecurefunc("FCFTab_UpdateColors", function(tab, selected)
		if self._enabled then
			StyleTab(tab, selected)
		end
	end)
	hooksecurefunc("FCF_OpenNewWindow", function()
		if self._enabled then
			C_Timer.After(0, function()
				self:ApplyAll()
			end)
		end
	end)
	hooksecurefunc("FCF_OpenTemporaryWindow", function()
		if self._enabled then
			C_Timer.After(0, function()
				self:ApplyAll()
			end)
		end
	end)

	return true
end

function Feature:Enable()
	self._enabled = true
	self:InstallHooks()
	self:ApplyAll()
end

function Feature:Disable()
	if not self._enabled then
		return
	end

	self._enabled = false
	self:RestoreAll()
end

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:SetScript("OnEvent", function(_, event, addonName)
	if event == "ADDON_LOADED"
		and addonName ~= ADDON_NAME
		and addonName ~= "Blizzard_ChatFrameBase"
		and addonName ~= "Blizzard_ChatFrame"
	then
		return
	end

	if Feature._enabled then
		Feature:InstallHooks()
		Feature:ApplyAll()
	end
end)
