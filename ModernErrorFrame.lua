setglobal("UIErrorsFrame_OnLoad", function(self)
	self:RegisterEvent("SYSMSG");
	self:RegisterEvent("UI_INFO_MESSAGE");
	self:RegisterEvent("UI_ERROR_MESSAGE");

	self.flashingFontStrings = {};
	self.errorStrings = {self:GetRegions()}

	for i,fontString in pairs(self.errorStrings) do
		fontString.idx = i
		fontString.Anim = fontString:CreateAnimationGroup()
		fontString.Anim.Fade = fontString.Anim:CreateAnimation("Alpha")
		fontString.Anim.Fade:SetStartDelay(3)
		fontString.Anim.Fade:SetChange(-1)
		fontString.Anim.Fade:SetDuration(1)
		fontString.Anim.Fade:SetSmoothing("IN")
		fontString.Anim:SetScript("OnFinished", function()
			fontString:Hide()

			if fontString.idx == #self.errorStrings then return end

			local needsUpdate = false
			for _,belowString in pairs(self.errorStrings) do
				if fontString.idx <= belowString.idx and belowString:IsShown() then
					fontString.idx = fontString.idx + 1
					belowString.idx = belowString.idx - 1
					needsUpdate = true
				end
			end
			if needsUpdate then
				self:UpdatePositions()
			end
		end)
	end
end)

setglobal("UIErrorsFrame_OnEvent", function(self, event, message, ...)
	if event == "SYSMSG" then
		local r, g, b = ...;
		self:AddMessage(message, r, g, b, 1.0);
	elseif event == "UI_INFO_MESSAGE" then
		self:TryDisplayMessage(message, YELLOW_FONT_COLOR:GetRGB());
	elseif event == "UI_ERROR_MESSAGE" then
		self:TryDisplayMessage(message, RED_FONT_COLOR:GetRGB());
	end
end)

UIErrorsFrame.BLACK_LISTED_MESSAGES = {
    -- [ERR_NO_ATTACK_TARGET] = true,
    -- [ERR_GENERIC_NO_TARGET] = true,
    -- [SPELL_FAILED_BAD_TARGETS] = true,
    -- [ERR_INVALID_ATTACK_TARGET] = true,
};

local FLASH_DURATION_SEC = 0.2;
function UIErrorsFrame:OnUpdate()
	local now = GetTime();
	local needsMoreUpdates = false;
	for fontString, timeStart in pairs(self.flashingFontStrings) do
		if fontString:GetText() == fontString.origMsg then
			if fontString:IsShown() and now - timeStart <= FLASH_DURATION_SEC then
				local percent = (now - timeStart) / FLASH_DURATION_SEC;
				local easedPercent = (percent > .5 and (1.0 - percent) / .5 or percent / .5) * .4;

				fontString:SetTextColor(fontString.origR + easedPercent, fontString.origG + easedPercent, fontString.origB + easedPercent);
				needsMoreUpdates = true;
			else
				fontString:SetTextColor(fontString.origR, fontString.origG, fontString.origB);
				self.flashingFontStrings[fontString] = nil;
			end
		else
			self.flashingFontStrings[fontString] = nil;
		end
	end

	if not needsMoreUpdates then
		self:SetScript("OnUpdate", nil);
	end
end

function UIErrorsFrame:FlashFontString(fontString)
	local now = GetTime()
    if self.flashingFontStrings[fontString] then
		if self.flashingFontStrings[fontString] + (FLASH_DURATION_SEC/1) < now then
			self.flashingFontStrings[fontString] = now
		end
    else
        fontString.origR, fontString.origG, fontString.origB = fontString:GetTextColor();
        fontString.origMsg = fontString:GetText();
        self.flashingFontStrings[fontString] = now
    end
	fontString.Anim:Stop()
	fontString.Anim:Play()
    self:SetScript("OnUpdate", self.OnUpdate);
end

function UIErrorsFrame:TryFlashingExistingMessage(message)
	for _,fontString in pairs(self.errorStrings) do
		if fontString:IsShown() and fontString:GetText() == message then
			self:FlashFontString(fontString);
			return true
		end
	end

	return false;
end

function UIErrorsFrame:ShouldDisplayMessage(message)
	if self.BLACK_LISTED_MESSAGES[message] then
		return false;
	end
    if self:TryFlashingExistingMessage(message) then
        return false;
    end

	return true;
end

function UIErrorsFrame:TryDisplayMessage(message, r, g, b)
	if self:ShouldDisplayMessage(message) then
		self:AddMessage(message, r, g, b, 1.0);
	end
end

local function AddExternalMessage(self, message, color)
	if not self:TryFlashingExistingMessage(message) then
		local r, g, b = color:GetRGB();
		self:AddMessage(message, r, g, b, 1.0);
	end
end

function UIErrorsFrame:AddExternalErrorMessage(message)
	AddExternalMessage(self, message, RED_FONT_COLOR);
end

function UIErrorsFrame:AddExternalWarningMessage(message)
	AddExternalMessage(self, message, YELLOW_FONT_COLOR);
end

function UIErrorsFrame:UpdatePositions()
	for _,fontString in pairs(self.errorStrings) do
		fontString:SetPoint("TOPLEFT", self, "TOPLEFT", 0, (fontString.idx-1) * -23)
		local savedText = fontString:GetText()
		fontString:SetText(" ") --Force update by changing the text
		fontString:SetText(savedText)
	end
end

function UIErrorsFrame:AddMessage(message, r, g, b, alpha)
	for _,fontString in pairs(self.errorStrings) do
		if fontString.idx < #self.errorStrings then
			-- Move existing messages down
			fontString.idx = fontString.idx+1
		else
			-- Populate with our error message
			fontString.idx = 1
			fontString:SetText(message)
			fontString:SetTextColor(r, g, b)
			fontString:SetAlpha(alpha or 1)
			fontString:Show()
			fontString.Anim:Stop()
			fontString.Anim:Play()
		end
	end
	self:UpdatePositions()
end

--Setup ourself
UIErrorsFrame_OnLoad(UIErrorsFrame)