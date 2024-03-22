local _, addon = ...

local Banner = CreateFrame("Frame");
Banner:Hide();
addon.Banner = Banner;

local outQuart = addon.EasingFunctions.outQuart;

function Banner:Init()
    -- Banner theme is always brown
    -- 3-Slice Background
    local pieces = {};
    local file = "Interface/AddOns/DialogueUI/Art/Theme_Shared/Banner-H-Brown.png";

    for i = 1, 3 do
        pieces[i] = self:CreateTexture(nil, "BACKGROUND");
        pieces[i]:SetTexture(file);
        pieces[i]:ClearAllPoints();
    end

    pieces[1]:SetSize(80, 160);     --Left
    pieces[3]:SetSize(80, 160);     --Right
    pieces[2]:SetSize(352, 160);    --Center

    pieces[1]:SetTexCoord(0, 80/512, 0, 160/256);
    pieces[2]:SetTexCoord(80/512, 430/512, 0, 160/256);
    pieces[3]:SetTexCoord(430/512, 1, 0, 160/256);

    pieces[1]:SetPoint("CENTER", self, "LEFT", 0, 0);
    pieces[3]:SetPoint("CENTER", self, "RIGHT", 0, 0);
    pieces[2]:SetPoint("TOPLEFT", pieces[1], "TOPRIGHT", 0, 0);
    pieces[2]:SetPoint("BOTTOMRIGHT", pieces[3], "BOTTOMLEFT", 0, 0);

    self.pieces = pieces;

    self.Text = self:CreateFontString(nil, "OVERLAY", "DUIFont_Quest_Paragraph");
    self.Text:SetJustifyH("CENTER");
    self.Text:SetJustifyV("MIDDLE");
    self.Text:SetPoint("CENTER", self, "CENTER", 0, 0);

    addon.ThemeUtil:SetFontColor(self.Text, "DarkBrown");

    local cornerSize = 42;
    self:SetCornerSize(cornerSize);

    self:SetFrameStrata("FULLSCREEN_DIALOG");

    self:SetScript("OnShow", self.OnShow);
    self:SetScript("OnHide", self.OnHide);
    self:SetScript("OnMouseDown", self.OnMouseDown);

    self.Init = nil;
end

function Banner:SetCornerSize(cornerSize)
    local height = 2 * cornerSize;
    self.pieces[1]:SetSize(cornerSize, height);
    self.pieces[3]:SetSize(cornerSize, height);
    self.minWidth = 512 / 80 * cornerSize;
    self.sidePadding = 112 / 80 * cornerSize;
    self:SetHeight(height);

    local shirnkH = 0;
    local shrinkV = 24 / 80 * cornerSize;
    self:SetHitRectInsets(shirnkH, shirnkH, shrinkV, shrinkV);
end

function Banner:Layout()
    local width = self.Text:GetWrappedWidth() + 2 * self.sidePadding;
    self:SetWidth(math.max(width, self.minWidth));
    self.frameWidth = width;

    local offsetY = WorldFrame:GetHeight() * 0.1;
    self.frameOffsetY = -offsetY;
    self.fromOffsetY = self.frameOffsetY - 40;

    self:ClearAllPoints();
    self:SetPoint("TOP", nil, "TOP", 0, self.frameOffsetY);
end

function Banner:OnMouseDown(button)
    if button == "RightButton" then
        self:Hide();
    end
end

function Banner:OnShow()
    if self.onShowFunc then
        self.onShowFunc(self);
    end
end

function Banner:OnHide()
    self:Hide();
    self:SetScript("OnUpdate", nil);
end


local ANIM_DURATION = 0.5;
local function AnimIntro_FlyUp_OnUpdate(self, elapsed)
    self.t = self.t + elapsed;
    if self.t < 0 then return end;  --delay

    local offsetY = outQuart(self.t, self.fromOffsetY, self.frameOffsetY, ANIM_DURATION);
    local alpha = 4*self.t;

    if alpha > 1 then
        alpha = 1;
    end

    if self.t >= ANIM_DURATION then
        offsetY = self.frameOffsetY;
        self:SetScript("OnUpdate", nil);
    end

    self:SetPoint("TOP", nil, "TOP", 0, offsetY);
    self:SetAlpha(alpha);
end


function Banner:DisplayMessage(msg, delay)
    if self.Init then
        self:Init();
    end

    self.Text:SetText(msg);
    self:Layout();

    self:Show();
    self.t = (delay and -delay) or 0;
    self:SetScript("OnUpdate", AnimIntro_FlyUp_OnUpdate);
    self:SetAlpha(0);
end


do  --Teach players how to open Settings
    local TUTORIAL_SHOWN = false;

    local function SetupTutorial_OpenSettings()
        local tutorialFlag = "OpenSettings";

        local function onShowFunc()
            TUTORIAL_SHOWN = true;
            addon.SetTutorialRead(tutorialFlag);
        end
        Banner.onShowFunc = onShowFunc;

        local function DisplayTutorial()
            if not TUTORIAL_SHOWN then
                local delay = 1;
                if C_CVar.GetCVarBool("GamePadEnable") then
                    Banner:DisplayMessage(addon.L["Tutorial Settings Hotkey Console"], delay);
                else
                    Banner:DisplayMessage(addon.L["Tutorial Settings Hotkey"], delay);
                end
            end
        end

        addon.DialogueUI:HookScript("OnShow", DisplayTutorial);


        local function SettingsUI_OnShow()
            Banner:Hide();
        end

        addon.CallbackRegistry:Register("SettingsUI.Show", SettingsUI_OnShow);
    end

    addon.CallbackRegistry:Register("Tutorial.OpenSettings", SetupTutorial_OpenSettings);
end