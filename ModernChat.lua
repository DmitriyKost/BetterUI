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

local function HideTabTextures(tab)
	if not tab then
		return
	end

	tab._buiHiddenTabTextures = tab._buiHiddenTabTextures or {}
	for _, key in ipairs(TAB_TEXTURE_KEYS) do
		local texture = tab[key]
		if texture then
			if tab._buiHiddenTabTextures[key] == nil then
				tab._buiHiddenTabTextures[key] = texture:IsShown()
			end
			texture:Hide()
		end
	end
end

local function RestoreTabTextures(tab)
	if not tab or not tab._buiHiddenTabTextures then
		return
	end

	for key, shown in pairs(tab._buiHiddenTabTextures) do
		local texture = tab[key]
		if texture then
			texture:SetShown(shown)
		end
	end
	tab._buiHiddenTabTextures = nil
end

local function HideEditBoxTextures(editBox)
	local name = editBox and editBox:GetName()
	if not name then
		return
	end

	editBox._buiHiddenEditBoxTextures = editBox._buiHiddenEditBoxTextures or {}
	for _, suffix in ipairs(EDIT_BOX_TEXTURE_SUFFIXES) do
		local texture = _G[name .. suffix]
		if texture then
			if editBox._buiHiddenEditBoxTextures[suffix] == nil then
				editBox._buiHiddenEditBoxTextures[suffix] = texture:IsShown()
			end
			texture:Hide()
		end
	end
end

local function RestoreEditBoxTextures(editBox)
	local name = editBox and editBox:GetName()
	local state = editBox and editBox._buiHiddenEditBoxTextures
	if not name or not state then
		return
	end

	for suffix, shown in pairs(state) do
		local texture = _G[name .. suffix]
		if texture then
			texture:SetShown(shown)
		end
	end
	editBox._buiHiddenEditBoxTextures = nil
end

local function StyleFrame(frame)
	if not frame then
		return
	end

	HideTabTextures(_G[frame:GetName() .. "Tab"])
	HideEditBoxTextures(frame.editBox)
end

local function RestoreFrame(frame)
	if not frame then
		return
	end

	RestoreTabTextures(_G[frame:GetName() .. "Tab"])
	RestoreEditBoxTextures(frame.editBox)
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
	if self._enabled then
		ForEachChatFrame(StyleFrame)
	end
end

function Feature:RestoreAll()
	ForEachChatFrame(RestoreFrame)
end

function Feature:InstallHooks()
	if FCFTab_UpdateColors and not self._tabHookInstalled then
		self._tabHookInstalled = true
		hooksecurefunc("FCFTab_UpdateColors", function(tab)
			if self._enabled then
				HideTabTextures(tab)
			end
		end)
	end
	if FCF_OpenNewWindow and not self._newWindowHookInstalled then
		self._newWindowHookInstalled = true
		hooksecurefunc("FCF_OpenNewWindow", function()
			if self._enabled then
				C_Timer.After(0, function()
					self:ApplyAll()
				end)
			end
		end)
	end
	if FCF_OpenTemporaryWindow and not self._temporaryWindowHookInstalled then
		self._temporaryWindowHookInstalled = true
		hooksecurefunc("FCF_OpenTemporaryWindow", function()
			if self._enabled then
				C_Timer.After(0, function()
					self:ApplyAll()
				end)
			end
		end)
	end
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
