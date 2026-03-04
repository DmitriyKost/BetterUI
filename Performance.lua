local ADDON_NAME, NS = ...
local FEATURE_NAME = "Performance"

local floor = math.floor
local concat = table.concat
local wipe = wipe

local Perf = {}
Perf.__index = Perf

local function GetClassColorRGB()
	local _, class = UnitClass("player")
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then
		return c.r, c.g, c.b
	end
	return 1, 1, 1
end

function Perf:HasAnyMetricEnabled(db)
	return (db.perfShowFPS and true) or (db.perfShowHomeMS and true) or (db.perfShowWorldMS and true)
end

function Perf:ComputeInterval(db)
	if db.perfShowFPS then
		return 0.5
	end
	return 0.75
end

function Perf:SizeToText()
	if not self.frame or not self.frame.text then
		return
	end
	local w = self.frame.text:GetStringWidth() or 220
	self.frame:SetSize(math.max(60, w + 6), 18)
end

function Perf:CreateFrame()
	if self.frame then
		return
	end

	local f = CreateFrame("Frame", nil, UIParent)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")

	f:SetScript("OnDragStart", function(frame)
		frame:StartMoving()
	end)
	f:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		self:SavePosition()
	end)

	f:SetSize(220, 18)

	local fs = f:CreateFontString(nil, "OVERLAY")
	fs:SetPoint("LEFT", f, "LEFT", 0, 0)
	fs:SetJustifyH("LEFT")

	local fontPath, fontSize, _ = TextStatusBarText:GetFont()
	fs:SetFont(fontPath, fontSize, "OUTLINE")

	local r, g, b = GetClassColorRGB()
	self._classR, self._classG, self._classB = r, g, b
	fs:SetTextColor(r, g, b)
	fs:SetText("")

	f.text = fs

	self.frame = f
	self._parts = self._parts or {}
	self._lastText = nil
	self:RestorePosition()
end

function Perf:SavePosition()
	local db = _G.BetterUIDB or NS.DB or {}
	if not self.frame then
		return
	end

	local point, _, relativePoint, xOfs, yOfs = self.frame:GetPoint(1)
	db.perfPoint = point
	db.perfRelPoint = relativePoint
	db.perfX = xOfs
	db.perfY = yOfs
	_G.BetterUIDB = db
	NS.DB = db
end

function Perf:RestorePosition()
	local db = _G.BetterUIDB or NS.DB or {}
	if not self.frame then
		return
	end

	self.frame:ClearAllPoints()

	if db.perfPoint and db.perfRelPoint and db.perfX and db.perfY then
		self.frame:SetPoint(db.perfPoint, UIParent, db.perfRelPoint, db.perfX, db.perfY)
	else
		self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
	end
end

function Perf:StartUpdating()
	if not self.frame then
		return
	end
	if self._ticker then
		return
	end

	local db = _G.BetterUIDB or NS.DB or {}
	self.updateInterval = self:ComputeInterval(db)
	local interval = self.updateInterval or 0.25

	self._ticker = C_Timer.NewTicker(interval, function()
		local d = _G.BetterUIDB or NS.DB or {}
		if not d.enablePerformanceMonitor then
			return
		end
		if not self:HasAnyMetricEnabled(d) then
			return
		end
		self:UpdateText()
	end)
end

function Perf:StopUpdating()
	if self._ticker then
		self._ticker:Cancel()
		self._ticker = nil
	end
end

function Perf:ApplyFont()
	if not self.frame or not self.frame.text then
		return
	end

	local db = _G.BetterUIDB or NS.DB or {}
	local fontPath, defaultSize, _ = TextStatusBarText:GetFont()
	local size = tonumber(db.perfFontSize) or defaultSize or 12
	size = math.floor(size + 0.5)

	self.frame.text:SetFont(fontPath, size, "OUTLINE")
end

function Perf:ApplyLock()
	if not self.frame then
		return
	end

	local db = _G.BetterUIDB or NS.DB or {}
	local locked = db.perfLocked and true or false

	self.frame:EnableMouse(not locked)
end

function Perf:BuildParts(out, db)
	wipe(out)

	if db.perfShowFPS then
		out[#out + 1] = "FPS: " .. floor(GetFramerate() + 0.5)
	end

	local homeMS, worldMS
	if db.perfShowHomeMS or db.perfShowWorldMS then
		local _, _, h, w = GetNetStats()
		homeMS, worldMS = h, w
	end

	if db.perfShowHomeMS then
		out[#out + 1] = "Home: " .. (homeMS or 0) .. "ms"
	end
	if db.perfShowWorldMS then
		out[#out + 1] = "World: " .. (worldMS or 0) .. "ms"
	end

	return out
end

function Perf:UpdateText()
	if not self.frame or not self.frame.text then
		return
	end

	local db = _G.BetterUIDB or NS.DB or {}

	if not self:HasAnyMetricEnabled(db) then
		local text = "Performance: (enable FPS/latency in settings)"
		if text ~= self._lastText then
			self._lastText = text
			self.frame.text:SetText(text)
			self:SizeToText()
		end
		return
	end

	local parts = self:BuildParts(self._parts, db)
	local text = concat(parts, "  |  ")

	if text ~= self._lastText then
		self._lastText = text
		self.frame.text:SetText(text)

		if self._classR then
			self.frame.text:SetTextColor(self._classR, self._classG, self._classB)
		end

		self:SizeToText()
	end
end

function Perf:ApplyFromDB()
	local db = _G.BetterUIDB or NS.DB or {}
	if not self.frame then
		return
	end

	if not db.enablePerformanceMonitor then
		self:StopUpdating()
		self.frame:Hide()
		return
	end

	self.frame:Show()
	self:ApplyFont()
	self:ApplyLock()

	self:UpdateText()

	if not self:HasAnyMetricEnabled(db) then
		self:StopUpdating()
		return
	end

	local wantInterval = self:ComputeInterval(db)
	if self._ticker and wantInterval ~= self.updateInterval then
		self:StopUpdating()
		self.updateInterval = wantInterval
	end

	self:StartUpdating()
end

function Perf:Enable()
	self:CreateFrame()
	self:ApplyFromDB()

	if not self._hooked then
		self._hooked = true
		NS.OnSettingChanged(function()
			self:ApplyFromDB()
		end)
	end
end

function Perf:Disable()
	self:StopUpdating()
	if self.frame then
		self.frame:Hide()
	end
end

NS.Features[FEATURE_NAME] = setmetatable({}, Perf)
