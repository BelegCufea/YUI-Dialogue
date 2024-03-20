local _, addon = ...
local API = addon.API;
local CallbackRegistry = addon.CallbackRegistry;

local CameraUtil = CreateFrame("Frame");
addon.CameraUtil = CameraUtil;
addon.SetCameraController(CameraUtil);

-- User Settings
local HIDE_UI = false;
local HIDE_UNIT_NAMES = false;
local CHANGE_FOV = false;
local FOV_DEFAULT = 90;
local FOV_ZOOMED_IN = 75;
------------------

local Lerp = API.Lerp;
local DeltaLerp = API.DeltaLerp;
local Esaing_OutSine = addon.EasingFunctions.outSine;
local IsPlayingCutscene = API.IsPlayingCutscene;

local SetCVar = C_CVar.SetCVar;     --not boolean
local GetCVar = C_CVar.GetCVar;
local IsInteractingWithNpcOfType = C_PlayerInteractionManager.IsInteractingWithNpcOfType;
local GetCameraZoom = GetCameraZoom;
local CameraZoomIn = CameraZoomIn;
local CameraZoomOut = CameraZoomOut;
local UnitExists = UnitExists;
local UnitIsUnit = UnitIsUnit;
local ConsoleExec = ConsoleExec;
local SetUIVisibility = SetUIVisibility;
local InCombatLockdown = InCombatLockdown;

local UIParent = UIParent;
UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED");  --Disable EXPERIMENTAL_CVAR_WARNING

local FadeHelper = CreateFrame("Frame");

local CVar_TargetFocus = {  --Can be used in combat
    test_cameraTargetFocusInteractEnable = 1,
    test_cameraTargetFocusInteractStrengthPitch = 0,
    test_cameraTargetFocusInteractStrengthYaw = 0,
    test_cameraOverShoulder = 1.5,
    test_cameraHeadMovementStrength = 0,
};

local CVar_UnitText = {     --Shouldn't be used in combat
    UnitNameOwn = 0,
	UnitNameNonCombatCreatureName = 0,
	UnitNameFriendlyPlayerName = 0,
	UnitNameFriendlyPetName = 0,
	UnitNameFriendlyMinionName = 0,
	UnitNameFriendlyGuardianName = 0,
	UnitNameFriendlySpecialNPCName = 0,
	UnitNameEnemyPlayerName = 0,
	UnitNameEnemyPetName = 0,
	UnitNameEnemyGuardianName = 0,
	UnitNameNPC = 0,
	UnitNameInteractiveNPC = 0,
	UnitNameHostleNPC = 0,
	--chatBubbles = 0,
};

local CVar_Backup = {};


function CameraUtil:SetDefaultCameraMode(mode)
    --0: No Zoom
    --1: Zoom to NPC
    --2: Shift camear horizontally
    print(mode)
    self.defaultCameraMode = mode;
    CallbackRegistry:Trigger("Camera.ModeChanged", mode);   --Core.lua: Affects event process delay
end
CameraUtil.defaultCameraMode = 0;


function CameraUtil:ChangeCVars()
    if self.cvarStored then return end;
    self.cvarStored = true;

    if self.cameraMode == 1 then
        ConsoleExec("actioncam on");
        for cvar, value in pairs(CVar_TargetFocus) do
            CVar_Backup[cvar] = GetCVar(cvar);
            SetCVar(cvar, value);
        end
    end

    if (not InCombatLockdown()) and HIDE_UNIT_NAMES then
        for cvar, value in pairs(CVar_UnitText) do
            CVar_Backup[cvar] = GetCVar(cvar);
            SetCVar(cvar, value);
        end
    end

    self:ListenEvent(true);
end

function CameraUtil:RestoreCVars()
    if self.cvarStored then
        self.cvarStored = nil;

        for cvar, value in pairs(CVar_Backup) do
            SetCVar(cvar, value);
        end

        CVar_Backup = {};

        self:ListenEvent(false);

        return true
    end
end

function CameraUtil:RestoreCombatCVar()
    if self.cvarStored then
        for cvar, value in pairs(CVar_Backup) do
            if CVar_UnitText[cvar] ~= nil then
                SetCVar(cvar, value);
                CVar_Backup[cvar] = nil;
            end
        end
    end
end

function CameraUtil:OnEvent(event, ...)
    self:RestoreCVars();
end

function CameraUtil:ListenEvent(state)
    if state then
        self:RegisterEvent("PLAYER_LOGOUT");
        self:RegisterEvent("PLAYER_QUITING");
        self:RegisterEvent("PLAYER_CAMPING");
        self:SetScript("OnEvent", self.OnEvent);
    else
        self:UnregisterEvent("PLAYER_LOGOUT");
        self:UnregisterEvent("PLAYER_QUITING");
        self:UnregisterEvent("PLAYER_CAMPING");
        self:SetScript("OnEvent", nil);
    end
end

local function GetShoulderOffsetByZoom(zoom)
	return zoom * 0.3283 - 0.02
end

function CameraUtil:GetShoulderOffsetForCurrentZoom()
    return GetShoulderOffsetByZoom(GetCameraZoom())
end

function CameraUtil:ZoomTo(goal, noZoomOut)
    local current = GetCameraZoom();
    self.oldZoom = current;

    local diff = current - goal;

    if noZoomOut and diff < 0 then
        return
    end

    if diff < 0.1 and diff > -0.1 then
        return
    end

    if diff > 0 then
        CameraZoomIn(diff);
    else
        CameraZoomOut(-diff);
    end
end

function CameraUtil:GetBestZoomForNPC()
    --Unused. Zoom is driven by ModelSceneActor:OnModelLoaded()
end

function CameraUtil:OnModelEvaluationComplete(modelHeight)
    if not (self.isActive and self.cameraMode == 1) then return end;

    local zoom;
    if modelHeight < 2 then
        zoom = 2.0
    elseif modelHeight < 2.6 then    --Pandaren, Elf
        zoom = 3.0
    elseif modelHeight < 4 then
        zoom = 4.0
    elseif modelHeight < 5.1 then
        zoom = 5.0
    elseif modelHeight < 6.1 then
        zoom = 6.0
    elseif modelHeight < 8 then
        zoom = 10.0
    else
        zoom = modelHeight + 2.0;
        if zoom > 28.5 then
            zoom = nil;
        end
    end

    if zoom then
        self:ZoomTo(zoom, true);
    end
end

local CAMERA_MOVEMENT_DURATION = 1.0;

local function ZoomIn_Fov_OnUpdate(self, elapsed)
    self.fovChanged = true;

    local fov = Esaing_OutSine(self.t, FOV_DEFAULT,  FOV_ZOOMED_IN, CAMERA_MOVEMENT_DURATION)--Lerp(90, 75, self.t/CAMERA_MOVEMENT_DURATION);

    if self.t >= CAMERA_MOVEMENT_DURATION then
        fov = FOV_ZOOMED_IN;
    end

    SetCVar("cameraFov", fov);
end

local function ZoomIn_FocusNPC_OnUpdate(self, elapsed)
    self.t = self.t + elapsed;


    local pitch = Esaing_OutSine(self.t, 88,  15, CAMERA_MOVEMENT_DURATION) --Lerp(88, 15, self.t/CAMERA_MOVEMENT_DURATION);
    local targetStrengh = Esaing_OutSine(self.t, 0.0, 1.0, CAMERA_MOVEMENT_DURATION);

    if self.t >= CAMERA_MOVEMENT_DURATION then
        ConsoleExec("pitchlimit "..15);
        pitch = 88;
        targetStrengh = 1.0;
        self:SetScript("OnUpdate", nil);
    end

    if CHANGE_FOV then
        ZoomIn_Fov_OnUpdate(self, elapsed);
    end

    SetCVar("test_cameraTargetFocusInteractStrengthPitch", targetStrengh);
    ConsoleExec("pitchlimit "..pitch);
end

local function ZoomIn_PanCamera_OnUpdate(self, elapsed)
    self.t = self.t + elapsed;
    if self.t > 0.03 then
        self.t = 0;
        self.shoulderOffset = DeltaLerp(self.shoulderOffset, self:GetShoulderOffsetForCurrentZoom(), self.shoulderBlend, elapsed);
        SetCVar("test_cameraOverShoulder", self.shoulderOffset);
    end
end

function CameraUtil:Intro_None()
    self.cameraMode = 0;
end

function CameraUtil:Intro_FocusNPC()
    --SaveView(5)   --We can't use this to restore pitch because it breaks Camera Following Style

    SetCVar("CameraKeepCharacterCentered", 0);
    self.cameraMode = 1;
    self.oldZoom = GetCameraZoom();
    self.t = 0;
    self:SetScript("OnUpdate", ZoomIn_FocusNPC_OnUpdate);
    API.EvaluateNPCSize();
end

function CameraUtil:Intro_PanCamera()
    SetCVar("CameraKeepCharacterCentered", 0);
    self.cameraMode = 2;
    self.t = 0;
    self.shoulderOffset = tonumber(GetCVar("test_cameraOverShoulder"));

    local targetOffset = self:GetShoulderOffsetForCurrentZoom();
    local diff = targetOffset - self.shoulderOffset;

    if diff > 8 then
        self.shoulderBlend = 0.06;
    else
        self.shoulderBlend = 0.10;
    end

    self:SetScript("OnUpdate", ZoomIn_PanCamera_OnUpdate);
end

function CameraUtil:InitiateInteraction()
    self.isActive = true;

    FadeHelper:FadeOutUI();

    if self.defaultCameraMode == 0 then
        self:Intro_None();
    else
        if (self.defaultCameraMode == 1) and UnitExists("npc") and (not UnitIsUnit("npc", "player")) then
            self:Intro_FocusNPC();
        else
            self:Intro_PanCamera();
        end
    end

    self:ChangeCVars();
end

function CameraUtil:Restore()
    self.isActive = false;

    if not self:RestoreCVars() then
        return
    end

    ConsoleExec("actioncam off");
    ConsoleExec("pitchlimit 88");

    if self.fovChanged then
        SetCVar("cameraFov", FOV_DEFAULT);
        self.fovChanged = nil;
    end

    if self.oldZoom then
        self:ZoomTo(self.oldZoom);
        self.oldZoom = nil;
    end

    self:SetScript("OnUpdate", nil);

    FadeHelper:FadeInUI();
end

function CameraUtil:OnFovSettingsChanged()
    if not (self.isActive and self.cameraMode == 1) then return end;

    if CHANGE_FOV then
        self.fovChanged = true;
        SetCVar("cameraFov", FOV_ZOOMED_IN);
    else
        self.fovChanged = nil;
        SetCVar("cameraFov", FOV_DEFAULT);
    end
end


local MovieFrame = MovieFrame;

local function ShouldShowUIParent()
    --Trading Post, Barbershop, MoviewFrame hide UIParent
    return not ((IsPlayingCutscene()) or (IsInteractingWithNpcOfType(57)) )
end

local function ShowUIParent(state)
    if InCombatLockdown() then return end;

    if state then
        if ShouldShowUIParent() then
            UIParent:Show();
            SetUIVisibility(true);
        else
            MovieFrame.uiParentShown = true;
        end
    else
        SetUIVisibility(false);
    end
end

function FadeHelper:ShowUIParentInstantly()
    self:SnapToFadeResult();
    ShowUIParent(true);
end

addon.CallbackRegistry:Register("PlayerInteraction.Trainer", "ShowUIParentInstantly", FadeHelper);  --For Classic


local ALPHA_UPDATE_INTERVAL = 1/30;

function FadeHelper:OnEvent(event, ...)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAY_MOVIE" or event == "CINEMATIC_START" then
        self:ShowUIParentInstantly();
    end
end
FadeHelper:SetScript("OnEvent", FadeHelper.OnEvent);

function FadeHelper:SnapToFadeResult(inCombat)
    self:SetScript("OnUpdate", nil);
    self.t = 0;
    self.alpha = 1;
    self:UnregisterEvent("PLAYER_REGEN_DISABLED");
    self:UnregisterEvent("PLAY_MOVIE");
    self:UnregisterEvent("CINEMATIC_START");

    if self.fadeDelta then
        UIParent:SetAlpha(1);
        if self.fadeDelta > 0 then
            ShowUIParent(true);
        elseif not inCombat then
            ShowUIParent(false);
        end
    end
end

function FadeHelper:FadeIn_OnUpdate(elapsed)
    self.t = self.t + elapsed;
    if self.t >= ALPHA_UPDATE_INTERVAL then
        self.alpha = self.alpha + 4*self.t;
        self.t = self.t - ALPHA_UPDATE_INTERVAL;
        if self.alpha >= 1 then
           self:SnapToFadeResult();
        else
            UIParent:SetAlpha(self.alpha);
        end
    end
end

function FadeHelper:FadeOut_OnUpdate(elapsed)
    self.t = self.t + elapsed;
    if self.t >= ALPHA_UPDATE_INTERVAL then
        self.alpha = self.alpha - 2*self.t;
        self.t = self.t - ALPHA_UPDATE_INTERVAL;
        if self.alpha <= 0 then
           self:SnapToFadeResult();
        else
            UIParent:SetAlpha(self.alpha);
        end
    end
end

function FadeHelper:FadeOutUI()
    if not HIDE_UI then return end;

    --UI: UIParent
    if self.fadeDelta == -1 or (not UIParent:IsShown()) then
        return
    end
    self.fadeDelta = -1;

    local inCombat = InCombatLockdown();

    if inCombat then
        self:SnapToFadeResult(inCombat);
    else
        self.alpha = UIParent:GetAlpha();
        self.t = 0;
        self:RegisterEvent("PLAYER_REGEN_DISABLED");
        self:RegisterEvent("PLAY_MOVIE");
        self:RegisterEvent("CINEMATIC_START");
        self:SetScript("OnUpdate", self.FadeOut_OnUpdate);
    end
end

function FadeHelper:FadeInUI()
    if self.fadeDelta == 1 then
        return
    end
    self.fadeDelta = 1;

    local inCombat = InCombatLockdown();

    if inCombat or UIParent:IsVisible() then
        self:SnapToFadeResult(inCombat);
    else
        self.alpha = UIParent:GetAlpha();
        if self.alpha >= 0.999 then
            self.alpha = 0;
        end
        self.t = 0;
        UIParent:SetAlpha(self.alpha);
        ShowUIParent(true);
        self:RegisterEvent("PLAYER_REGEN_DISABLED");
        self:RegisterEvent("PLAY_MOVIE");
        self:RegisterEvent("CINEMATIC_START");
        self:SetScript("OnUpdate", self.FadeIn_OnUpdate);
    end
end


function CameraUtil:OnEnterCombatDuringInteraction()
    self:RestoreCombatCVar()
    if ShouldShowUIParent() then
        ShowUIParent(true);
    end
end


do
    local function Settings_CameraMovement(dbValue)
        CameraUtil:SetDefaultCameraMode(dbValue)
    end
    addon.CallbackRegistry:Register("SettingChanged.CameraMovement", Settings_CameraMovement);

    local function Settings_CameraChangeFov(dbValue)
        CHANGE_FOV = dbValue == true;
        CameraUtil:OnFovSettingsChanged()
    end
    addon.CallbackRegistry:Register("SettingChanged.CameraChangeFov", Settings_CameraChangeFov);

    local function Settings_HideUI(dbValue)
        HIDE_UI = dbValue == true;
    end
    addon.CallbackRegistry:Register("SettingChanged.HideUI", Settings_HideUI);

    local function Settings_HideUnitNames(dbValue)
        HIDE_UNIT_NAMES = dbValue == true;
    end
    addon.CallbackRegistry:Register("SettingChanged.HideUnitNames", Settings_HideUnitNames);
end