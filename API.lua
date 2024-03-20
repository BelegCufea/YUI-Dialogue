local _, addon = ...
local API = addon.API;
local L = addon.L;

local floor = math.floor;
local sqrt = math.sqrt;
local tostring = tostring;

local function AlwaysFalse(arg)
    --used to replace non-existent API in Classic
    return false
end
API.AlwaysFalse = AlwaysFalse;

local function AlwaysZero(arg)
    return 0
end

do  --Math
    local function GetPointsDistance2D(x1, y1, x2, y2)
        return sqrt( (x1 - x2)*(x1 - x2) + (y1 - y2)*(y1 - y2))
    end
    API.GetPointsDistance2D = GetPointsDistance2D;

    local function Round(n)
        return floor(n + 0.5);
    end
    API.Round = Round;

    local function Clamp(value, min, max)
        if value > max then
            return max
        elseif value < min then
            return min
        end
        return value
    end
    API.Clamp = Clamp;

    local function Lerp(startValue, endValue, amount)
        return (1 - amount) * startValue + amount * endValue;
    end
    API.Lerp = Lerp;

    local function ClampLerp(startValue, endValue, amount)
        amount = Clamp(amount, 0, 1);
        return Lerp(startValue, endValue, amount);
    end
    API.ClampLerp = ClampLerp;

    local function Saturate(value)
        return Clamp(value, 0.0, 1.0);
    end

    local TARGET_FRAME_PER_SEC = 60.0;

    local function DeltaLerp(startValue, endValue, amount, timeSec)
        return Lerp(startValue, endValue, Saturate(amount * timeSec * TARGET_FRAME_PER_SEC));
    end
    API.DeltaLerp = DeltaLerp;


    --Used for currency amount. Simplified from Blizzard's "AbbreviateNumbers" in UIParent.lua
    local ABBREVIATION_K = FIRST_NUMBER_CAP_NO_SPACE or "K";
    local function AbbreviateNumbers(value)
        if value > 10000 then
            return floor(value / 1000).. ABBREVIATION_K
        elseif value > 1000 then
            return floor(value / 100)/10 .. ABBREVIATION_K
        else
            return tostring(value)
        end
    end
    API.AbbreviateNumbers = AbbreviateNumbers;
end

do  -- Table
    local function Mixin(object, ...)
        for i = 1, select("#", ...) do
            local mixin = select(i, ...)
            for k, v in pairs(mixin) do
                object[k] = v;
            end
        end
        return object
    end
    API.Mixin = Mixin;

    local function CreateFromMixins(...)
        return Mixin({}, ...)
    end
    API.CreateFromMixins = CreateFromMixins;
end

do  --Pixel
    local GetPhysicalScreenSize = GetPhysicalScreenSize;
    local SCREEN_WIDTH, SCREEN_HEIGHT = GetPhysicalScreenSize();

    local function GetPixelForScale(scale, pixelSize)
        if pixelSize then
            return pixelSize * (768/SCREEN_HEIGHT)/scale
        else
            return (768/SCREEN_HEIGHT)/scale
        end
    end
    API.GetPixelForScale = GetPixelForScale;

    local function GetPixelForWidget(widget, pixelSize)
        local scale = widget:GetEffectiveScale();
        return GetPixelForScale(scale, pixelSize);
    end
    API.GetPixelForWidget = GetPixelForWidget;

    local function GetSizeInPixel(scale, size)
        return size * scale / (768/SCREEN_HEIGHT)
    end
    API.GetSizeInPixel = GetSizeInPixel;

    local function DisableSharpening(texture)
        texture:SetTexelSnappingBias(0);
        texture:SetSnapToPixelGrid(false);
    end
    API.DisableSharpening = DisableSharpening;


    local PixelUtil = CreateFrame("Frame");
    addon.PixelUtil = PixelUtil;

    PixelUtil.objects = {};

    function PixelUtil:AddPixelPerfectObject(object)
        table.insert(self.objects, object);
    end

    function PixelUtil:MarkScaleDirty()
        self.scaleDirty = true;
    end
    PixelUtil:MarkScaleDirty();

    function PixelUtil:RequireUpdate()
        if self.scaleDirty then
            self.scaleDirty = nil;
            local scale;

            for _, object in ipairs(self.objects) do
                scale = object:GetEffectiveScale();
                object:UpdatePixel(scale);
            end
        end
    end

    PixelUtil:RegisterEvent("UI_SCALE_CHANGED");
    PixelUtil:RegisterEvent("DISPLAY_SIZE_CHANGED");

    PixelUtil:SetScript("OnEvent", function(self, event, ...)
        SCREEN_WIDTH, SCREEN_HEIGHT = GetPhysicalScreenSize();
        self:MarkScaleDirty();
    end);
end

do  --Object Pool
    local ObjectPoolMixin = {};
    local ipairs = ipairs;
    local tinsert = table.insert;

    function ObjectPoolMixin:Release()
        for i, object in ipairs(self.objects) do
            if i <= self.numActive then
                self.Remove(object);
            else
                break
            end
        end
        self.numActive = 0;
    end

    function ObjectPoolMixin:Acquire()
        local n = self.numActive + 1;
        self.numActive = n;

        if not self.objects[n] then
            self.objects[n] = self.Create();
        end

        if self.OnAcquired then
            self.OnAcquired(self.objects[n]);
        end

        self.objects[n]:Show();

        return self.objects[n]
    end

    function ObjectPoolMixin:OnLoad()
        self.numActive = 0;
        self.objects = {};
    end

    function ObjectPoolMixin:CallActive(method)
        for i = 1, self.numActive do
            self.objects[i][method](self.objects[i]);
        end
    end

    function ObjectPoolMixin:CallAllObjects(method, ...)
        for i, obj in ipairs(self.objects) do
            obj[method](obj, ...);
        end
    end

    function ObjectPoolMixin:ProcessActiveObjects(func)
        for i = 1, self.numActive do
            func(self.objects[i]);
        end
    end

    function ObjectPoolMixin:ProcessAllObjects(func)
        for i, obj in ipairs(self.objects) do
            func(obj);
        end
    end

    function ObjectPoolMixin:GetObjectsByPredicate(pred)
        local tbl = {};
        for i, obj in ipairs(self.objects) do
            if pred(obj) then
                tinsert(tbl, obj);
            end
        end
        return tbl
    end

    function ObjectPoolMixin:GetActiveObjects()
        local tbl = {};
        for i = 1, self.numActive do
            tinsert(tbl, self.objects[i]);
        end
        return tbl
    end

    local function RemoveObject(object)
        object:Hide();
        object:ClearAllPoints();
    end

    local function CreateObjectPool(createFunc, removeFunc, onAcquiredFunc)
        local pool = API.CreateFromMixins(ObjectPoolMixin);
        pool:OnLoad();
        pool.Create = createFunc;
        pool.Remove = removeFunc or RemoveObject;
        pool.OnAcquired = onAcquiredFunc;
        return pool
    end
    API.CreateObjectPool = CreateObjectPool;
end

do  --String
    local match = string.match;
    local gmatch = string.gmatch;
    local gsub = string.gsub;
    local tinsert = table.insert;

    local function SplitParagraph(text)
        local tbl = {};

        for v in gmatch(text, "[%C]+") do
            tinsert(tbl, v)
        end

        return tbl
    end
    API.SplitParagraph = SplitParagraph;


    local READING_CPS = 15; --Vary depends on Language
    local strlenutf8 = strlenutf8;

    local function GetTextReadingTime(text)
        local numWords = strlenutf8(text);
        return API.Clamp(numWords / READING_CPS, 2.75, 8);
    end
    API.GetTextReadingTime = GetTextReadingTime;


    local function ReplaceRegularExpression(formatString)
        return gsub(formatString, "%%d", "%%s")
    end
    API.ReplaceRegularExpression = ReplaceRegularExpression;

    do
        local function UpdateFormat(k)
            if L[k] then
                L[k] = ReplaceRegularExpression(L[k]);
            else
                print("DialogueUI Missing String:", k);
            end
        end

        UpdateFormat("Format Player XP");
        UpdateFormat("Format Gold Amount")
        UpdateFormat("Format Silver Amount")
        UpdateFormat("Format Copper Amount")
    end

    local function GetItemIDFromHyperlink(link)
        local id = match(link, "[Ii]tem:(%d*)");
        if id then
            return tonumber(id)
        end
    end
    API.GetItemIDFromHyperlink = GetItemIDFromHyperlink;
end

do  --NPC Interaction
    local SetUnitCursorTexture = SetUnitCursorTexture;
    local UnitExists = UnitExists;

    local f = CreateFrame("Frame");
    f.texture = f:CreateTexture();
    f.texture:SetSize(1, 1);

    local CursorTextureTypes = {
        ["Cursor Talk"] = "gossip",     --Most interactable NPC that doesn't provide quests
        [4675624] = "direction",        --Guard, asking for direction
    };

    local TexturePrefix = "Interface/AddOns/DialogueUI/Art/Icons/NPCType-";

    local CustomTypeTexture = {
        direction = "Direction",
    };

    local function GetInteractType(unit)
        if UnitExists(unit) then
            SetUnitCursorTexture(f.texture, unit);
            local file = f.texture:GetTexture();
            return file and CursorTextureTypes[file]
        end
    end
    API.GetInteractType = GetInteractType;

    local function GetInteractTexture(unit)
        local type = GetInteractType(unit);
        if type and CustomTypeTexture[type] then
            return TexturePrefix..CustomTypeTexture[type]
        end
    end
    API.GetInteractTexture = GetInteractTexture;


    local IsInteractingWithNpcOfType = C_PlayerInteractionManager.IsInteractingWithNpcOfType;
    local TYPE_GOSSIP = Enum.PlayerInteractionType and Enum.PlayerInteractionType.Gossip or 3;
    local TYPE_QUEST_GIVER = Enum.PlayerInteractionType and Enum.PlayerInteractionType.QuestGiver or 4;

    local function IsInteractingWithGossip()
        return IsInteractingWithNpcOfType(TYPE_GOSSIP)
    end
    API.IsInteractingWithGossip = IsInteractingWithGossip;

    local function IsInteractingWithQuestGiver()
        return IsInteractingWithNpcOfType(TYPE_QUEST_GIVER)
    end
    API.IsInteractingWithQuestGiver = IsInteractingWithQuestGiver;

    local function IsInteractingWithDialogNPC()
        return (IsInteractingWithNpcOfType(TYPE_GOSSIP) or IsInteractingWithNpcOfType(TYPE_QUEST_GIVER))
    end
    API.IsInteractingWithDialogNPC = IsInteractingWithDialogNPC;

    --A helper to close gossip interaction
    --CloseGossip twice in a row cause issue: UI like MerchantFrame won't close itself, no frame portrait

    local CloseGossip = C_GossipInfo.CloseGossip;

    local function ResetCloseStatus(self, elapsed)
        self.isClosing = false;
        self:SetScript("OnUpdate", nil);
        if f.closeInteraction then
            CloseGossip();
        end
    end

    local function CloseGossipInteraction()
        f.closeInteraction = true;
        if not f.isClosing then
            f.isClosing = true;
            f:SetScript("OnUpdate", ResetCloseStatus);
        end
    end
    API.CloseGossipInteraction = CloseGossipInteraction;

    local function CancelClosingGossipInteraction()
        if f.isClosing then
            f.closeInteraction = false;
        end
    end
    API.CancelClosingGossipInteraction = CancelClosingGossipInteraction;


    f:RegisterEvent("CINEMATIC_START");
    f:RegisterEvent("CINEMATIC_STOP");
    f:RegisterEvent("PLAY_MOVIE");
    f:RegisterEvent("STOP_MOVIE");

    f:SetScript("OnEvent", function(self, event, ...)
        if event == "CINEMATIC_START" then
            self.isPlayingCinematic = true;
        elseif event == "CINEMATIC_STOP" then
            self.isPlayingCinematic = false;
        elseif event == "PLAY_MOVIE" then
            self.isPlayingMovie = true;
        elseif event == "STOP_MOVIE" then
            self.isPlayingMovie = false;
        end

        if self.isPlayingCinematic or self.isPlayingMovie then
            self.isPlayingCutscene = true;
            if self.onPlayCutsceneCallback then
                self.onPlayCutsceneCallback();
            end
        else
            self.isPlayingCutscene = false;
        end
    end);

    local function IsPlayingCutscene()
        return f.isPlayingCutscene
    end
    API.IsPlayingCutscene = IsPlayingCutscene;

    local function SetPlayCutsceneCallback(callback)
        f.onPlayCutsceneCallback = callback;
    end
    API.SetPlayCutsceneCallback = SetPlayCutsceneCallback;


    --Model Size Evaluation
    local ModelScene, UtilityActor, CameraController;
    --local IsUnitModelReadyForUI = IsUnitModelReadyForUI;

    MirageDialogUtilityActorMixin = {};

    function MirageDialogUtilityActorMixin:OnModelLoaded()
        local bottomX, bottomY, bottomZ, topX, topY, topZ = self:GetActiveBoundingBox(); -- Could be nil for invisible models
        if bottomX and bottomY and bottomZ and topX and topY and topZ then
            local width = topX - bottomX;
            local depth = topY - bottomY;
            local height = topZ - bottomZ;

            --local widthScale = width / MODEL_SCENE_ACTOR_DIMENSIONS_FOR_NORMALIZATION.width;
            --local depthScale = depth / MODEL_SCENE_ACTOR_DIMENSIONS_FOR_NORMALIZATION.depth;
            --local heightScale = height / MODEL_SCENE_ACTOR_DIMENSIONS_FOR_NORMALIZATION.height;
            --print(width, depth, height);

            if CameraController and height then
                CameraController:OnModelEvaluationComplete(height);
            end
        end
        self:ClearModel();
    end

    --0.8, 1.0, 1.6: Goblin
    --0.9, 1.1, 2.1: Human
    --1.1, 1.3, 1.7: Dwarf
    --0.9, 1.2, 2.5: NElf M
    --0.8, 0.8, 2.1: VElf F
    --0.5, 0.8, 1.1: Gnome
    --3.2, 2.0, 2.9: Malicia
    --3.8, 3.5, 5.2: Draknoid
    --2.9, 5.1, 7.7: Watcher Koranos
    --30, 20, 14:    Dragon Aspect

    local function EvaluateUnitSize(unit)
        if not ModelScene then
            ModelScene = CreateFrame("ModelScene");
            ModelScene:SetSize(1, 1);
            UtilityActor = ModelScene:CreateActor(nil, "MirageDialogUtilityActorTemplate");
        end

        local success = UtilityActor:SetModelByUnit(unit);
        return success
    end

    local function EvaluateNPCSize()
        return EvaluateUnitSize("npc");
    end
    API.EvaluateNPCSize = EvaluateNPCSize;

    local function SetCameraController(controller)
        CameraController = controller;
    end
    addon.SetCameraController = SetCameraController;


    local match = string.match;

    local function GetCreatureIDFromGUID(guid)
        local id = match(guid, "Creature%-0%-%d*%-%d*%-%d*%-(%d*)");
        if id then
            return tonumber(id)
        end
    end
    API.GetCreatureIDFromGUID = GetCreatureIDFromGUID;

    local function GetCurrentNPCInfo()
        if UnitExists("npc") then
            local name = UnitName("npc");
            local creatureID = GetCreatureIDFromGUID(UnitGUID("npc"));
            return name, creatureID
        end
    end
    API.GetCurrentNPCInfo = GetCurrentNPCInfo;
end

do  --Easing
    local EasingFunctions = {};
    addon.EasingFunctions = EasingFunctions;


    local sin = math.sin;
    local cos = math.cos;
    local pow = math.pow;
    local pi = math.pi;

    --t: total time elapsed
    --b: beginning position
    --e: ending position
    --d: animation duration

    function EasingFunctions.linear(t, b, e, d)
        return (e - b) * t / d + b
    end

    function EasingFunctions.outSine(t, b, e, d)
        return (e - b) * sin(t / d * (pi / 2)) + b
    end

    function EasingFunctions.inOutSine(t, b, e, d)
        return -(e - b) / 2 * (cos(pi * t / d) - 1) + b
    end

    function EasingFunctions.outQuart(t, b, e, d)
        t = t / d - 1;
        return (b - e) * (pow(t, 4) - 1) + b
    end

    function EasingFunctions.outQuint(t, b, e, d)
        t = t / d
        return (b - e)* (pow(1 - t, 5) - 1) + b
    end

    function EasingFunctions.inQuad(t, b, e, d)
        t = t / d
        return (e - b) * pow(t, 2) + b
    end
end

do  --Quest
    local FREQUENCY_DAILY = 1;  --Enum.QuestFrequency.Daily;
    local FREQUENCY_WEELY = 2;  --Enum.QuestFrequency.Weekly;
    local ICON_PATH = "Interface/AddOns/DialogueUI/Art/Icons/";

    local QuestGetAutoAccept = QuestGetAutoAccept or AlwaysFalse;
    local IsOnQuest = C_QuestLog.IsOnQuest;
    local ReadyForTurnIn = C_QuestLog.ReadyForTurnIn or IsQuestComplete or AlwaysFalse;
    local QuestIsFromAreaTrigger = QuestIsFromAreaTrigger or AlwaysFalse;
    local GetSuggestedGroupSize = GetSuggestedGroupSize or AlwaysZero;
    local IsQuestTrivial = C_QuestLog.IsQuestTrivial or AlwaysFalse;
    local IsLegendaryQuest = C_QuestLog.IsLegendaryQuest or AlwaysFalse;
    local IsImportantQuest = C_QuestLog.IsImportantQuest or AlwaysFalse;
    local IsCampaignQuest = (C_CampaignInfo and C_CampaignInfo.IsCampaignQuest) or AlwaysFalse;
    local IsQuestTask = C_QuestLog.IsQuestTask or AlwaysFalse;
    local IsWorldQuest = C_QuestLog.IsWorldQuest or AlwaysFalse;
    local GetRewardSkillPoints = GetRewardSkillPoints or AlwaysFalse;
    local GetRewardArtifactXP = GetRewardArtifactXP or AlwaysZero;
    local QuestCanHaveWarModeBonus = C_QuestLog.QuestCanHaveWarModeBonus or AlwaysFalse;
    local QuestHasQuestSessionBonus = C_QuestLog.QuestHasQuestSessionBonus or AlwaysFalse;
    local GetQuestItemInfoLootType = GetQuestItemInfoLootType or AlwaysZero;
    local GetTitleForQuestID = C_QuestLog.GetTitleForQuestID or C_QuestLog.GetQuestInfo or AlwaysFalse;
    local GetQuestObjectives = C_QuestLog.GetQuestObjectives;


    --Classic
    API.QuestGetAutoAccept = QuestGetAutoAccept;
    API.QuestIsFromAreaTrigger = QuestIsFromAreaTrigger;
    API.GetSuggestedGroupSize = GetSuggestedGroupSize;
    API.GetRewardSkillPoints = GetRewardSkillPoints;
    API.GetRewardArtifactXP = GetRewardArtifactXP;
    API.QuestCanHaveWarModeBonus = QuestCanHaveWarModeBonus;
    API.QuestHasQuestSessionBonus = QuestHasQuestSessionBonus;
    API.GetQuestItemInfoLootType = GetQuestItemInfoLootType;
    API.GetTitleForQuestID = GetTitleForQuestID;

    if GetAvailableQuestInfo then
        API.GetAvailableQuestInfo = GetAvailableQuestInfo;
    else
        API.GetAvailableQuestInfo = function()
            return false, 0, false, false, 0
        end
    end

    if GetActiveQuestID then
        API.GetActiveQuestID = GetActiveQuestID;
    else
        API.GetActiveQuestID = function()
            return 0
        end
    end


    local function CompleteQuestInfo(questInfo)
        if questInfo.isOnQuest == nil then
            questInfo.isOnQuest = IsOnQuest(questInfo.questID);
        end

        if not questInfo.isComplete then     --Classic Shenanigans
            questInfo.isComplete = ReadyForTurnIn(questInfo.questID);
        end

        if questInfo.isCampaign == nil then
            questInfo.isCampaign = IsCampaignQuest(questInfo.questID);  --QuestMixin uses C_CampaignInfo.GetCampaignID() ~= 0. Wonder what's the difference here;
        end

        if questInfo.isLegendary == nil then
            questInfo.isLegendary = IsLegendaryQuest(questInfo.questID);
        end

        if questInfo.isImportant == nil then
            questInfo.isImportant = IsImportantQuest(questInfo.questID);
        end

        if questInfo.isTrivial == nil then
            questInfo.isTrivial  = IsQuestTrivial(questInfo.questID);
        end

        if questInfo.frequency == nil then
            questInfo.frequency = 0;
        end

        return questInfo
    end
    API.CompleteQuestInfo = CompleteQuestInfo;

    local function GetQuestIcon(questInfo)
        --QuestMapLogTitleButton_OnEnter

        if not questInfo then
            return ICON_PATH.."IncompleteQuest.png";
        end

        CompleteQuestInfo(questInfo);

        local file;

        if questInfo.isOnQuest then
            if questInfo.isComplete then
                if questInfo.isCampaign then
                    file = "CompleteCampaignQuest.png";
                elseif questInfo.isLegendary then
                    file = "CompleteLegendaryQuest.png";
                else
                    file = "CompleteQuest.png";
                end
            else
                if questInfo.isCampaign then
                    file = "IncompleteCampaignQuest.png";
                elseif questInfo.isLegendary then
                    file = "IncompleteLegendaryQuest.png";
                else
                    file = "IncompleteQuest.png";
                end
            end

        else
            if questInfo.frequency == FREQUENCY_DAILY then
                file = "DailyQuest.png";
            elseif questInfo.frequency == FREQUENCY_WEELY then
                file = "WeeklyQuest.png";
            elseif  questInfo.repeatable then
                file = "RepeatableQuest.png";
            else
                if questInfo.isCampaign then
                    file = "AvailableCampaignQuest.png";
                elseif questInfo.isLegendary then
                    file = "AvailableLegendaryQuest.png";
                else
                    file = "AvailableQuest.png";
                end
            end
        end

        return ICON_PATH..file
    end

    API.GetQuestIcon = GetQuestIcon;

    local function IsQuestAutoAccepted()
        return QuestGetAutoAccept()
    end
    API.IsQuestAutoAccepted = IsQuestAutoAccepted;

    local function ShouldShowQuestAcceptedAlert(questID)
        return not (IsWorldQuest(questID) and IsQuestTask(questID));
    end
    API.ShouldShowQuestAcceptedAlert = ShouldShowQuestAcceptedAlert;

    local GetDetailText = GetQuestText;
    local GetProgressText = GetProgressText;
    local GetRewardText = GetRewardText;
    local GetGreetingText = GetGreetingText;

    local QuestTextMethod = {
        Detail = GetDetailText,
        Progress = GetProgressText,
        Complete = GetRewardText,
        Greeting = GetGreetingText,
    };

    local function GetQuestText(method)
        local text = QuestTextMethod[method]();
        if text and text ~= "" then
            return text
        end
    end
    API.GetQuestText = GetQuestText;

    --QuestTheme
    local GetQuestDetailsTheme = C_QuestLog.GetQuestDetailsTheme or AlwaysFalse;
    local DECOR_PATH = "Interface/AddOns/DialogueUI/Art/ParchmentDecor/";
    local BackgroundDecors = {
        ["QuestBG-Dragonflight"] = "Dragonflight.png",
        ["QuestBG-Azurespan"] = "Dragonflight.png",
        ["QuestBG-EmeraldDream"] = "Dragonflight-Green.png",
        ["QuestBG-Ohnplains"] = "Dragonflight-Green.png",
        ["QuestBG-Thaldraszus"] = "Dragonflight-Bronze.png",
        ["QuestBG-Walkingshore"] = "Dragonflight-Red.png",
        ["QuestBG-ZaralekCavern"] = "Dragonflight.png",
        ["QuestBG-ExilesReach"] = "Dragonflight.png",

        ["QuestBG-Alliance"] = "Alliance.png",
        ["QuestBG-Horde"] = "Horde.png",
    };

    local function GetQuestBackgroundDecor(questID)
        local theme = GetQuestDetailsTheme(questID);
        if theme and theme.background and BackgroundDecors[theme.background] then
            return DECOR_PATH..BackgroundDecors[theme.background]
        end
    end
    API.GetQuestBackgroundDecor = GetQuestBackgroundDecor;


    local MAX_QUESTS;
    local GetNumQuestLogEntries = C_QuestLog.GetNumQuestLogEntries;
    local IsAccountQuest = C_QuestLog.IsAccountQuest;
    local GetQuestIDForLogIndex = C_QuestLog.GetQuestIDForLogIndex;
    local GetQuestInfo = C_QuestLog.GetInfo;

    local function GetNumQuestCanAccept()
        --*Unreliable
        --numQuests include all types of quests.
        --(Account/Daily) quests don't count towards MaxQuest(35)
        if not MAX_QUESTS then
            MAX_QUESTS = C_QuestLog.GetMaxNumQuestsCanAccept();
        end

        local numShownEntries, numAllQuests = GetNumQuestLogEntries();
        local numQuests = 0;
        local questID;
        local n = 0;
        print("numShownEntries", numShownEntries);

        for i = 1, numShownEntries do
            questID = GetQuestIDForLogIndex(i);
            if questID ~= 0 then
                local info = GetQuestInfo(i);

                if info and not (info.isHidden or info.isHeader) then
                    if not (IsAccountQuest(questID)) then
                        numQuests = numQuests + 1;

                        print(numQuests, questID, info.title)
                    end
                end
            end
        end

        print("Num Quests:", numQuests);
        return MAX_QUESTS - numQuests, MAX_QUESTS
    end

    local GetItemInfoInstant = GetItemInfoInstant;
    local select = select;

    local function IsQuestItem(item)
        if not item then return end;
        local classID, subclassID = select(6, GetItemInfoInstant(item));
        return classID == 12
    end
    API.IsQuestItem = IsQuestItem;



    local HoldableItems = {
        INVTYPE_WEAPON = true,
        INVTYPE_2HWEAPON = true,
        INVTYPE_SHIELD = true,
        INVTYPE_HOLDABLE = true,
        INVTYPE_RANGED = true,
        INVTYPE_RANGEDRIGHT = true,
        INVTYPE_WEAPONMAINHAND = true,
        INVTYPE_WEAPONOFFHAND = true,
    };

    local NoUseTransmogSkin = {
        INVTYPE_HEAD = true,
        INVTYPE_HAND = true,
        --INVTYPE_FEET = true,
    };

    local TransmogSetupGear = {
        INVTYPE_HEAD = {78420},
        INVTYPE_HAND = {78420, 78425},
    };

    local function IsHoldableItem(item)
        if item then
            local _, _, _, itemEquipLoc = GetItemInfoInstant(item);
            return HoldableItems[itemEquipLoc];
        end
    end
    API.IsHoldableItem = IsHoldableItem;

    local function GetTransmogSetup(item)
        local _, _, _, itemEquipLoc = GetItemInfoInstant(item);
        local useTransmogSkin = not (NoUseTransmogSkin[itemEquipLoc] or false);
        local setupGear = TransmogSetupGear[itemEquipLoc];
        return useTransmogSkin, setupGear
    end
    API.GetTransmogSetup = GetTransmogSetup;


    --QuestTag
    
    local GetQuestTagInfo = C_QuestLog.GetQuestTagInfo or AlwaysFalse;
    local QUEST_TAG_NAME = {
        --Also: Enum.QuestTagType
        [Enum.QuestTag.Dungeon] = {L["Quest Type Dungeon"], "QuestTag-Dungeon.png"},
        [Enum.QuestTag.Raid] = {L["Quest Type Raid"], "QuestTag-Raid.png"},
        [Enum.QuestTag.Raid10] = {L["Quest Type Raid"], "QuestTag-Raid.png"},
        [Enum.QuestTag.Raid25] = {L["Quest Type Raid"], "QuestTag-Raid.png"},

        [271] = {L["Quest Type Covenant Calling"]},
    };

    local function GetQuestTag(questID)
        local info = GetQuestTagInfo(questID);
        if info and info.tagID then
            return info.tagID
        end
    end
    API.GetQuestTag = GetQuestTag;

    local function GetQuestTagNameIcon(tagID)
        if QUEST_TAG_NAME[tagID] then
            local icon = QUEST_TAG_NAME[tagID][2];
            if icon then
                icon = ICON_PATH..icon;
            end
            return QUEST_TAG_NAME[tagID][1], icon
        end
    end
    API.GetQuestTagNameIcon = GetQuestTagNameIcon;


    local PLAYER_HONOR_ICON;

    local function GetHonorIcon()
        if PLAYER_HONOR_ICON == nil then
            if UnitFactionGroup and UnitFactionGroup("player") == "Horde" then
                PLAYER_HONOR_ICON = "Interface/Icons/PVPCurrency-Honor-Horde";
            else
                PLAYER_HONOR_ICON = "Interface/Icons/PVPCurrency-Honor-Alliance";
            end
        end

        return PLAYER_HONOR_ICON
    end
    API.GetHonorIcon = GetHonorIcon;
end

do  --Color
    -- Make Rare and Epic brighter (use the color in Narcissus)
    local CreateColor = CreateColor;
    local ITEM_QUALITY_COLORS = ITEM_QUALITY_COLORS;
    local QualityColors = {};

    QualityColors[0] = CreateColor(0.9, 0.9, 0.9, 1);
    QualityColors[1] = QualityColors[0];
    QualityColors[3] = CreateColor(105/255, 158/255, 255/255, 1);
    QualityColors[4] = CreateColor(185/255, 83/255, 255/255, 1);

    local function GetItemQualityColor(quality)
        if QualityColors[quality] then
            return QualityColors[quality]
        else
            return ITEM_QUALITY_COLORS[quality].color
        end
    end
    API.GetItemQualityColor = GetItemQualityColor;


    local TextPalette = {
        [0] = CreateColor(1, 1, 1, 1),              --Fallback
        [1] = CreateColor(0.87, 0.86, 0.75, 1),     --Ivory: Used by big buttons and low-priority alerts like criteria complete
        [2] = CreateColor(0.19, 0.17, 0.13, 1),     --Dark Brown: Used as paragraph text color
        [3] = CreateColor(0.42, 0.75, 0.48, 1),     --Green: Quest Complete
        [4] = CreateColor(1.000, 0.125, 0.125, 1),  --ERROR_COLOR
    };

    local function GetTextColorByIndex(colorIndex)
        if not (colorIndex and TextPalette[colorIndex]) then
            colorIndex = 0;
        end
        return TextPalette[colorIndex]
    end
    API.GetTextColorByIndex = GetTextColorByIndex;
end

do  --Currency
    local GetCurrencyContainerInfoDefault = C_CurrencyInfo.GetCurrencyContainerInfo;
    local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo;
    local format = string.format;
    local FormatLargeNumber = FormatLargeNumber;

    local function GetCurrencyContainerInfo(currencyID, numItems, name, texture, quality)
        local entry = GetCurrencyContainerInfoDefault(currencyID, numItems);
        if entry then
            return entry.name, entry.icon, entry.displayAmount, entry.quality
        end
        return name, texture, numItems, quality
    end
    API.GetCurrencyContainerInfo = GetCurrencyContainerInfo;


    local function GenerateMoneyText(rawCopper, colorized, noAbbreviation) --coins
        local text;
        local gold = floor(rawCopper / 10000);
        local silver = floor((rawCopper - gold * 10000) / 100);
        local copper = floor(rawCopper - gold * 10000 - silver * 100);

        local goldText, silverText, copperText;

        if copper > 0 then
            if noAbbreviation then
                copperText = format(L["Format Copper Amount"], copper);
            else
                copperText = copper..L["Symbol Copper"];
            end

            if colorized then
                copperText = "|cffe3b277"..copperText.."|r";
            end
        end

        if gold ~= 0 or silver ~= 0 then
            if noAbbreviation then
                silverText = format(L["Format Silver Amount"], silver);
            else
                silverText = silver..L["Symbol Silver"];
            end

            if colorized then
                silverText = "|cffc5d2e8"..silverText.."|r";
            end

            if gold > 0 then
                if noAbbreviation then
                    goldText = format(L["Format Gold Amount"], FormatLargeNumber(gold));
                else
                    goldText = gold..L["Symbol Gold"];
                end

                if colorized then
                    goldText = "|cffffbb18"..goldText.."|r";
                end

                if copperText then
                    text = goldText.." "..silverText.." "..copperText;
                elseif silver == 0 then
                    text = goldText;
                else
                    text = goldText.." "..silverText;
                end
            else
                if copperText then
                    text = silverText.." "..copperText;
                else
                    text = silverText;
                end
            end
        else
            text = copperText;
        end

        return text
    end
    API.GenerateMoneyText = GenerateMoneyText;


    local function WillCurrencyRewardOverflow(currencyID, rewardQuantity)
        local currencyInfo = GetCurrencyInfo(currencyID);
        local quantity = currencyInfo and (currencyInfo.useTotalEarnedForMaxQty and currencyInfo.totalEarned or currencyInfo.quantity);
        return quantity and currencyInfo.maxQuantity > 0 and rewardQuantity + quantity > currencyInfo.maxQuantity;
    end
    API.WillCurrencyRewardOverflow = WillCurrencyRewardOverflow;

    local function GetColorizedAmountForCurrency(currencyID, rewardQuantity, useIcon)
        if WillCurrencyRewardOverflow(currencyID, rewardQuantity) then
            if useIcon then --For Small Button
                return "|TInterface/AddOns/DialogueUI/Art/Icons/CurrencyOverflow.png:0:0|t"..rewardQuantity.."|r"
            else
                return "|cffff2020"..rewardQuantity.."|r"
            end
        else
            return rewardQuantity
        end
    end
    API.GetColorizedAmountForCurrency = GetColorizedAmountForCurrency;


    local UnitXP = UnitXP;
    local UnitXPMax = UnitXPMax;
    local UnitLevel = UnitLevel;

    local function GetXPPercentage(xp)
        local current = UnitXP("player");
        local max = UnitXPMax("player");
        if current and max and max ~= 0 and xp > 0 then
            local ratio = xp/max;
            if ratio > 1 then
                
            end
            return API.Round(ratio*100)
        end
    end
    API.GetXPPercentage = GetXPPercentage;

    local function GetPlayerLevelXP()
        local level = UnitLevel("player");
        local currentXP = UnitXP("player");
        local maxXP = UnitXPMax("player");
        return level, currentXP, maxXP
    end
    API.GetPlayerLevelXP = GetPlayerLevelXP;

    local function IsPlayerAtMaxLevel()
        local maxLevel;

        if GetMaxLevelForPlayerExpansion then
            maxLevel = GetMaxLevelForPlayerExpansion();
        elseif GetMaxPlayerLevel then
            maxLevel = GetMaxPlayerLevel();
        else
            maxLevel = 999
        end

        return UnitLevel("player") >= maxLevel
    end
    API.IsPlayerAtMaxLevel = IsPlayerAtMaxLevel;
end

do  --Grid Layout
    local ipairs = ipairs;
    local tinsert = table.insert;

    local GridMixin = {};

    function GridMixin:OnLoad()
        self:SetGrid(1, 1);
        self:SetSpacing(0);
    end

    function GridMixin:SetGrid(x, y)
        self.x = x;
        self.y = y;
        self:ResetGrid();
    end

    function GridMixin:SetSpacing(spacing)
        self.spacing = spacing;
    end

    function GridMixin:ResetGrid()
        self.grid = {};
        self.fromRow = 1;
        self.maxOccupiedX = 0;
        self.maxOccupiedY = 0;
    end

    function GridMixin:SetGridSize(gridWidth, gridHeight)
        self.gridWidth = gridWidth;
        self.gridHeight = gridHeight;
    end

    function GridMixin:CreateNewRows(n)
        n = n or 1;

        for i = 1, n do
            local tbl = {};
            for col = 1, self.x do
                tinsert(tbl, false);
            end
            tinsert(self.grid, tbl);
        end
    end

    function GridMixin:FindGridForSize(objectSizeX, objectSizeY)
        local found = false;
        local maxRow = #self.grid;
        local topleftGridX, topleftGridY;

        for row = self.fromRow, maxRow do
            local rowStatus = self.grid[row];
            local maxCol = #rowStatus;
            local rowFull = true;

            for col, occupied in ipairs(rowStatus) do
                if not occupied then
                    rowFull = false;
                    if (col + objectSizeX - 1 <= maxCol) and (row + objectSizeY - 1 <= maxRow) then
                        found = true;
                        topleftGridX = col;
                        topleftGridY = row;

                        for _row = row, row + objectSizeY - 1 do
                            for _col = col, col + objectSizeX - 1 do
                                self.grid[_row][_col] = true;
                            end
                        end

                        if topleftGridX > self.maxOccupiedX then
                            self.maxOccupiedX = topleftGridX;
                        end

                        if topleftGridY > self.maxOccupiedY then
                            self.maxOccupiedY = topleftGridY;
                        end

                        break
                    end
                end
            end

            if found then
                break
            end

            if rowFull then
                self.fromRow = self.fromRow + 1;
            end
        end

        if found then
            return topleftGridX, topleftGridY
        else
            self:CreateNewRows(self.y);
            return self:FindGridForSize(objectSizeX, objectSizeY)
        end
    end

    function GridMixin:GetOffsetForGridPosition(topleftGridX, topleftGridY)
        local offsetX = (topleftGridX - 1) * (self.gridWidth + self.spacing);
        local offsetY = (topleftGridY - 1) * (self.gridHeight + self.spacing);
        return offsetX, -offsetY
    end

    function GridMixin:PlaceObject(object, objectSizeX, objectSizeY, anchorTo, fromOffsetX, fromOffsetY)
        local topleftGridX, topleftGridY = self:FindGridForSize(objectSizeX, objectSizeY);
        local offsetX, offsetY = self:GetOffsetForGridPosition(topleftGridX, topleftGridY);
        object:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", fromOffsetX + offsetX, fromOffsetY + offsetY);
    end

    function GridMixin:GetWrappedSize()
        local width = (self.maxOccupiedX > 0 and self.maxOccupiedX * (self.gridWidth + self.spacing) - self.spacing) or 0;
        local height = (self.maxOccupiedY > 0 and self.maxOccupiedY * (self.gridHeight + self.spacing) - self.spacing) or 0;
        return width, height
    end

    local function CreateGridLayout()
        local grid = API.CreateFromMixins(GridMixin);
        grid:OnLoad();
        return grid
    end
    API.CreateGridLayout = CreateGridLayout;
end

do  --Fade Frame
    local abs = math.abs;
    local tinsert = table.insert;
    local wipe = wipe;

    local fadeInfo = {};
    local fadingFrames = {};

    local f = CreateFrame("Frame");

    local function OnUpdate(self, elpased)
        local i = 1;
        local frame, info, timer, alpha;
        local isComplete = true;
        while fadingFrames[i] do
            frame = fadingFrames[i];
            info = fadeInfo[frame];
            if info then
                timer = info.timer + elpased;
                if timer >= info.duration then
                    alpha = info.toAlpha;
                    fadeInfo[frame] = nil;
                    if info.alterShownState and alpha <= 0 then
                        frame:Hide();
                    end
                else
                    alpha = info.fromAlpha + (info.toAlpha - info.fromAlpha) * timer/info.duration;
                    info.timer = timer;
                end
                frame:SetAlpha(alpha);
                isComplete = false;
            end
            i = i + 1;
        end

        if isComplete then
            f:Clear();
        end
    end

    function f:Clear()
        self:SetScript("OnUpdate", nil);
        wipe(fadingFrames);
        wipe(fadeInfo);
    end

    function f:Add(frame, fullDuration, fromAlpha, toAlpha, alterShownState, useConstantDuration)
        local alpha = frame:GetAlpha();
        if alterShownState then
            if toAlpha > 0 then
                frame:Show();
            end
            if toAlpha == 0 then
                if not frame:IsShown() then
                    frame:SetAlpha(0);
                    alpha = 0;
                end
                if alpha == 0 then
                    frame:Hide();
                end
            end
        end
        if fromAlpha == toAlpha or alpha == toAlpha then
            if fadeInfo[frame] then
                fadeInfo[frame] = nil;
            end
            return;
        end
        local duration;
        if useConstantDuration then
            duration = fullDuration;
        else
            if fromAlpha then
                duration = fullDuration * (alpha - toAlpha)/(fromAlpha - toAlpha);
            else
                duration = fullDuration * abs(alpha - toAlpha);
            end
        end
        if duration <= 0 then
            frame:SetAlpha(toAlpha);
            if toAlpha == 0 then
                frame:Hide();
            end
            return;
        end
        fadeInfo[frame] = {
            fromAlpha = alpha,
            toAlpha = toAlpha,
            duration = duration,
            timer = 0,
            alterShownState = alterShownState,
        };
        for i = 1, #fadingFrames do
            if fadingFrames[i] == frame then
                return;
            end
        end
        tinsert(fadingFrames, frame);
        self:SetScript("OnUpdate", OnUpdate);
    end

    function f:SimpleFade(frame, toAlpha, alterShownState, speedMultiplier)
        --Use a constant fading speed: 1.0 in 0.25s
        --alterShownState: if true, run Frame:Hide() when alpha reaches zero / run Frame:Show() at the beginning
        speedMultiplier = speedMultiplier or 1;
        local alpha = frame:GetAlpha();
        local duration = abs(alpha - toAlpha) * 0.25 * speedMultiplier;
        if duration <= 0 then
            return;
        end

        self:Add(frame, duration, alpha, toAlpha, alterShownState, true);
    end

    function f:Snap()
        local i = 1;
        local frame, info;
        while fadingFrames[i] do
            frame = fadingFrames[i];
            info = fadeInfo[frame];
            if info then
                frame:SetAlpha(info.toAlpha);
            end
            i = i + 1;
        end
        self:Clear();
    end

    local function UIFrameFade(frame, duration, toAlpha, initialAlpha)
        if initialAlpha then
            frame:SetAlpha(initialAlpha);
            f:Add(frame, duration, initialAlpha, toAlpha, true, false);
        else
            f:Add(frame, duration, nil, toAlpha, true, false);
        end
    end

    local function UIFrameFadeIn(frame, duration)
        frame:SetAlpha(0);
        f:Add(frame, duration, 0, 1, true, false);
    end


    API.UIFrameFade = UIFrameFade;       --from current alpha
    API.UIFrameFadeIn = UIFrameFadeIn;   --from 0 to 1
end

do  --Model
    local UnitRace = UnitRace;
    local WantsAlteredForm = C_UnitAuras and C_UnitAuras.WantsAlteredForm or AlwaysFalse;

    local function SetModelByUnit(model, unit)
        local _, raceFileName = UnitRace(unit);
        if raceFileName == "Dracthyr" or raceFileName == "Worgen" then
            local arg = WantsAlteredForm(unit);
            model:SetUnit(unit, false, arg);    --blend = false
        else
            model:SetUnit(unit, false);
        end
        model.unit = unit;
    end
    API.SetModelByUnit = SetModelByUnit;


    local function SetModelLight(model, enabled, omni, dirX, dirY, dirZ, ambIntensity, ambR, ambG, ambB, dirIntensity, dirR, dirG, dirB)
        local lightValues = {
            omnidirectional = omni or false;
            point = CreateVector3D(dirX or 0, dirY or 0, dirZ or 0),
            ambientIntensity = ambIntensity or 1,
            ambientColor = CreateColor(ambR or 1, ambG or 1, ambB or 1),
            diffuseIntensity = dirIntensity or 1,
            diffuseColor = CreateColor(dirR or 1, dirG or 1, dirB or 1),
        };

        model:SetLight(enabled, lightValues);
    end
    API.SetModelLight = SetModelLight;
end

do  --Faction --Reputation
    local GetFactionInfoByID = GetFactionInfoByID;
    local GetFactionGrantedByCurrency = C_CurrencyInfo.GetFactionGrantedByCurrency;
    local C_GossipInfo = C_GossipInfo;
    local C_MajorFactions = C_MajorFactions;
    local C_Reputation = C_Reputation;

    local function GetFactionStatusText(factionID)
        --Derived from Blizzard ReputationFrame_InitReputationRow in ReputationFrame.lua

        local name, description, standingID, barMin, barMax, barValue = GetFactionInfoByID(factionID);

        local isParagon = C_Reputation.IsFactionParagon(factionID);
        local isMajorFaction = factionID and C_Reputation.IsMajorFaction(factionID);
        local repInfo = factionID and C_GossipInfo.GetFriendshipReputation(factionID);

        local isCapped;
        local factionStandingtext;  --Revered/Junior/Renown 1

        if repInfo and repInfo.friendshipFactionID > 0 then --Friendship
            factionStandingtext = repInfo.reaction;

            if repInfo.nextThreshold then
                barMin, barMax, barValue = repInfo.reactionThreshold, repInfo.nextThreshold, repInfo.standing;
            else
                barMin, barMax, barValue = 0, 1, 1;
                isCapped = true;
            end

            local rankInfo = C_GossipInfo.GetFriendshipReputationRanks(repInfo.friendshipFactionID);
            if rankInfo then
                factionStandingtext = factionStandingtext .. string.format(" (Lv. %s/%s)", rankInfo.currentLevel, rankInfo.maxLevel);
            end

        elseif isMajorFaction then
            local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);

            barMin, barMax = 0, majorFactionData.renownLevelThreshold;
            isCapped = C_MajorFactions.HasMaximumRenown(factionID);
            barValue = isCapped and majorFactionData.renownLevelThreshold or majorFactionData.renownReputationEarned or 0;
            factionStandingtext = L["Renown Level Label"] .. majorFactionData.renownLevel;

            if isParagon then
                local totalEarned, threshold = C_Reputation.GetFactionParagonInfo(factionID);
                if totalEarned and threshold and threshold ~= 0 then
                    local paragonLevel = floor(totalEarned / threshold);
                    local currentValue = totalEarned - paragonLevel * threshold;
                    factionStandingtext = ("|cff00ccff"..L["Paragon Reputation"].."|r %d/%d"):format(currentValue, threshold);
                end
            else
                if isCapped then
                    factionStandingtext = factionStandingtext.." "..L["Level Maxed"];
                end
            end
        else
            isCapped = standingID == 8;  --MAX_REPUTATION_REACTION
            local gender = UnitSex("player");
		    factionStandingtext = GetText("FACTION_STANDING_LABEL"..standingID, gender);    --GetText: Game API that returns localized texts
        end

        local rolloverText; --(0/24000)
        if not isCapped then
            rolloverText = string.format("(%s/%s)", barValue, barMax);
        end

        local text;

        if factionStandingtext then
            if not text then text = L["Current Colon"] end;
            factionStandingtext = " |cffffffff"..factionStandingtext.."|r";
            text = text .. factionStandingtext;
        end

        if rolloverText then
            if not text then text = L["Current Colon"] end;
            rolloverText = "  |cffffffff"..rolloverText.."|r";
            text = text .. rolloverText;
        end

        if text then
            text = " \n"..text;
        end

        return text
    end
    API.GetFactionStatusText = GetFactionStatusText;

    local function GetFactionStatusTextByCurrencyID(currencyID)
        local factionID =  GetFactionGrantedByCurrency(currencyID);
        if factionID then
            return GetFactionStatusText(factionID);
        end
    end
    API.GetFactionStatusTextByCurrencyID = GetFactionStatusTextByCurrencyID;
end

do  --Chat Message
    local function PrintMessage(header, msg)
        print("|cff8080FF"..header..": "..msg.."|r")
    end
    API.PrintMessage = PrintMessage;
end

do  --Dev Tool
    local DEV_MODE = true;

    if not DEV_MODE then return end;

    --GetQuestID()

    local IsAccountQuest = C_QuestLog.IsAccountQuest;
    local GetQuestIDForLogIndex = C_QuestLog.GetQuestIDForLogIndex;
    local GetQuestInfo = C_QuestLog.GetInfo;

    local function GetNumQuestCanAccept()
        --numQuests include all types of quests.
        --(Account/Daily) quests don't count towards MaxQuest(35)
        if not MAX_QUESTS then
            MAX_QUESTS = C_QuestLog.GetMaxNumQuestsCanAccept();
        end

        local numShownEntries, numAllQuests = GetNumQuestLogEntries();
        local numQuests = 0;
        local questID;

        for i = 1, numShownEntries do
            questID = GetQuestIDForLogIndex(i);
            if questID ~= 0 then
                print(i, questID)
            end
            if questID ~= 0 and not IsAccountQuest(questID) then
                local info = GetQuestInfo(i);
                if info and (not (info.isHidden or info.isHeader)) and info.frequency == 1 then
                    numAllQuests = numAllQuests - 1;
                end
            end
        end

        return MAX_QUESTS - numAllQuests, MAX_QUESTS
    end

    local function TooltipAddInfo(tooltip, info, key)
        tooltip:AddDoubleLine(key, tostring(info[key]));
    end

    local QuestInfoFields = {
        "questID", "campaignID", "frequency", "isHeader", "isTask", "isBounty", "isStory", "isAutoComplete",
    };

    local function QuestMapLogTitleButton_OnEnter_Callback(_, button, questID)
        print(questID);
        local tooltip = GameTooltip;
        if not tooltip:IsShown() then return end;

        local info = C_QuestLog.GetInfo(button.questLogIndex);

        for _, key in ipairs(QuestInfoFields) do
            TooltipAddInfo(tooltip, info, key)
        end
        tooltip:AddDoubleLine("Account", tostring(IsAccountQuest(questID)));
        tooltip:AddDoubleLine("isCalling", tostring(C_QuestLog.IsQuestCalling(questID)));
        tooltip:AddDoubleLine("QuestType", C_QuestLog.GetQuestType(questID));
        tooltip:AddDoubleLine("isRepeatable", tostring(C_QuestLog.IsRepeatableQuest(questID)));

        tooltip:Show();
    end

    EventRegistry:RegisterCallback("QuestMapLogTitleButton.OnEnter", QuestMapLogTitleButton_OnEnter_Callback, nil);
end


do  --Tooltip
    if C_TooltipInfo then
        addon.TooltipAPI = C_TooltipInfo;

    else
        --For Classic where C_TooltipInfo doesn't exist:

        local TooltipAPI = {};
        local CreateColor = CreateColor;
        local TOOLTIP_NAME = "DialogueUIVirtualTooltip";
        local TP = CreateFrame("GameTooltip", TOOLTIP_NAME, nil, "GameTooltipTemplate");
        TP:SetOwner(UIParent, 'ANCHOR_NONE');
        TP:SetClampedToScreen(false);
        TP:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, -128);
        TP:Show();
        TP:SetScript("OnUpdate", nil);


        local UpdateFrame = CreateFrame("Frame");

        local function UpdateTooltipInfo_OnUpdate(self, elapsed)
            self.t = self.t + elapsed;
            if self.t > 0.2 then
                self.t = 0;
                self:SetScript("OnUpdate", nil);
                addon.CallbackRegistry:Trigger("SharedTooltip.TOOLTIP_DATA_UPDATE", 0);
            end
        end

        function UpdateFrame:OnItemChanged(numLines)
            self.t = 0;
            self.numLines = numLines;
            self:SetScript("OnUpdate", UpdateTooltipInfo_OnUpdate);
        end

        local function GetTooltipHyperlink()
            local name, link = TP:GetItem();
            if link then
                return link
            end

            name, link = TP:GetSpell();
            if link then
                return "spell:"..link
            end
        end

        local function GetTooltipTexts()
            local numLines = TP:NumLines();
            if numLines == 0 then return end;

            local tooltipData = {};
            tooltipData.dataInstanceID = 0;

            local newLink = GetTooltipHyperlink();
            if newLink and newLink ~= TP.hperlink then
                UpdateFrame:OnItemChanged(numLines);
            end

            TP.hperlink = newLink;
            tooltipData.hyperlink = newLink;

            local lines = {};
            local n = 0;

            local fs, text;
            for i = 1, numLines do
                fs = _G[TOOLTIP_NAME.."TextLeft"..i];
                if fs then
                    n = n + 1;

                    local r, g, b = fs:GetTextColor();
                    text = fs:GetText();
                    local lineData = {
                        leftText = text,
                        leftColor = CreateColor(r, g, b),
                        rightText = nil,
                        wrapText = true,
                        leftOffset = 0,
                    };

                    fs = _G[TOOLTIP_NAME.."TextRight"..i];
                    if fs then
                        text = fs:GetText();
                        if text and text ~= "" then
                            r, g, b = fs:GetTextColor();
                            lineData.rightText = text;
                            lineData.rightColor = CreateColor(r, g, b);
                        end
                    end

                    lines[n] = lineData;
                end
            end

            tooltipData.lines = lines;
            return tooltipData
        end

        do
            local accessors = {
                SetItemByID = "GetItemByID",
                SetCurrencyByID = "GetCurrencyByID",
                SetQuestItem = "GetQuestItem",
                SetQuestCurrency = "GetQuestCurrency",
                SetSpellByID = "GetSpellByID",
                SetItemByGUID = "GetItemByGUID",
                SetHyperlink = "GetHyperlink",
            };

            for accessor, getterName in pairs(accessors) do
                if TP[accessor] then
                    local function GetterFunc(...)
                        TP:ClearLines();
                        TP:SetOwner(UIParent, "ANCHOR_PRESERVE");
                        TP[accessor](TP, ...);
                        return GetTooltipTexts();
                    end

                    TooltipAPI[getterName] = GetterFunc;
                end
            end
        end

        addon.TooltipAPI = TooltipAPI;


        local EQUIPLOC_SLOTID = {
            INVTYPE_HEAD = 1,
            INVTYPE_NECK = 2,
            INVTYPE_SHOULDER = 3,
            INVTYPE_BODY = 4,
            INVTYPE_CHEST = 5,
            INVTYPE_WAIST = 6,
            INVTYPE_LEGS = 7,
            INVTYPE_FEET = 8,
            INVTYPE_WRIST = 9,
            INVTYPE_HAND = 10,
            INVTYPE_FINGER = 11,    --12
            INVTYPE_TRINKET = 13,
            INVTYPE_WEAPON = 16,
            INVTYPE_SHIELD = 17,
            INVTYPE_CLOAK = 15,
            INVTYPE_2HWEAPON = 16,
            INVTYPE_WEAPONMAINHAND = 16,
            INVTYPE_WEAPONOFFHAND = 17,
            INVTYPE_HOLDABLE = 17,
            INVTYPE_RANGED = 18,    --Classic
            INVTYPE_RANGEDRIGHT = 18,
        };


        local tinsert = table.insert;
        local match = string.match;

        local function RemoveBrackets(text)
            return string.gsub(text, "[()（）]", "")
        end

        local function Pattern_RemoveControl(text)
            return string.gsub(text, "%%c", "");
        end

        local function Pattern_WrapSpace(text)
            return string.gsub(Pattern_RemoveControl(text), "%%s", "%(%.%+%)");
        end

        local STATS_PATTERN;
        local STATS_ORDER = {
            "dps", "armor", "stamina", "strength", "agility", "intellect", "spirit",
        };

        local FORMAT_POSITIVE_VALUE = "|cff19ff19+%s|r %s";
        local FORMAT_NEGATIVE_VALUE = "|cffff2020%s|r %s";

        local STATS_NAME = {
            dps = ITEM_MOD_DAMAGE_PER_SECOND_SHORT or "Damage per Second",
            armor = RESISTANCE0_NAME or "Armor",
            stamina = SPELL_STAT3_NAME or "Stamina",
            strength = SPELL_STAT1_NAME or "Strengh",
            agility = SPELL_STAT2_NAME or "Agility",
            intellect = SPELL_STAT4_NAME or "Intellect",
            spirit = SPELL_STAT5_NAME or "Spirit",
        };

        local function BuildStatsPattern()
            local PATTERN_DPS = Pattern_WrapSpace(RemoveBrackets(DPS_TEMPLATE or "(%s damage per second)"));
            local PATTERN_ARMOR = Pattern_WrapSpace(ARMOR_TEMPLATE or "%s Armor");
            local PATTERN_STAMINA = Pattern_WrapSpace(ITEM_MOD_STAMINA or "%c%s Stamina");
            local PATTERN_STRENGTH = Pattern_WrapSpace(ITEM_MOD_STRENGTH or "%c%s Strength");
            local PATTERN_AGILITY = Pattern_WrapSpace(ITEM_MOD_AGILITY or "%c%s Agility");
            local PATTERN_INTELLECT = Pattern_WrapSpace(ITEM_MOD_INTELLECT or "%c%s Intellect");
            local PATTERN_SPIRIT = Pattern_WrapSpace(ITEM_MOD_SPIRIT or "%c%s Spirit");

            STATS_PATTERN = {
                dps = PATTERN_DPS,
                armor = PATTERN_ARMOR,
                stamina = PATTERN_STAMINA,
                strength = PATTERN_STRENGTH,
                agility = PATTERN_AGILITY,
                intellect = PATTERN_INTELLECT,
                spirit = PATTERN_SPIRIT,
            };
        end

        local function GetItemStatsFromTooltip()
            if not STATS_PATTERN then
                BuildStatsPattern();
            end

            local numLines = TP:NumLines();
            if numLines == 0 then return end;

            local stats = {};
            local n = 0;

            local fs, text, value;
            for i = 3, numLines do
                fs = _G[TOOLTIP_NAME.."TextLeft"..i];
                if fs then
                    n = n + 1;
                    text = fs:GetText();
                    if text and text ~= " " then
                        for key, pattern in pairs(STATS_PATTERN) do
                            if not stats[key] then
                                if key == "dps" then
                                    text = RemoveBrackets(text);
                                end
                                value = match(text, pattern);
                                if value then
                                    value = tonumber(value);
                                    stats[key] = value;
                                end
                            end
                        end
                    end
                end
            end

            return stats
        end

        local function FormatValueDiff(value, name)
            if value > 0 then
                return FORMAT_POSITIVE_VALUE:format(value, name);
            else
                return FORMAT_NEGATIVE_VALUE:format(value, name);
            end
        end

        local GetItemInfoInstant = GetItemInfoInstant;

        local function AreItemsSameType(item1, item2)
            local classID1, subclassID1 = select(6, GetItemInfoInstant(item1));
            local classID2, subclassID2 = select(6, GetItemInfoInstant(item2));
            return classID1 == classID2 and subclassID1 == subclassID2;
        end

        local function GetItemComparisonInfo(item)
            --Classic
            local _, _, _, itemEquipLoc = GetItemInfoInstant(item);
            local slotID = itemEquipLoc and EQUIPLOC_SLOTID[itemEquipLoc];
            if slotID then
                local equippedItemLink = GetInventoryItemLink("player", slotID);
                if equippedItemLink then
                    TP:ClearLines();
                    TP:SetOwner(UIParent, "ANCHOR_PRESERVE");
                    if type(item) == "number" then
                        TP:SetItemByID(item);
                    else
                        TP:SetHyperlink(item);
                    end
                    local stats1 = GetItemStatsFromTooltip();

                    TP:ClearLines();
                    TP:SetOwner(UIParent, "ANCHOR_PRESERVE");
                    TP:SetHyperlink(equippedItemLink);
                    local stats2 = GetItemStatsFromTooltip();

                    if stats1 and stats2 then
                        local deltaStats;
                        local v1, v2;
                        for _, k in ipairs(STATS_ORDER) do
                            v1 = stats1[k] or 0;
                            v2 = stats2[k] or 0;
                            if v1 ~= v2 then
                                if not deltaStats then
                                    deltaStats = {};
                                end
                                tinsert(deltaStats, FormatValueDiff(v1 - v2, STATS_NAME[k]));
                            end
                        end
                        return deltaStats, equippedItemLink, AreItemsSameType(item, equippedItemLink)
                    end
                end
            end
        end
        API.GetItemComparisonInfo = GetItemComparisonInfo;
    end
end


do  --Items
    local IsEquippableItem = IsEquippableItem;
    local IsCosmeticItem = IsCosmeticItem or AlwaysFalse;
    local GetTransmogItemInfo = (C_TransmogCollection and C_TransmogCollection.GetItemInfo) or AlwaysFalse;

    API.IsCosmeticItem = IsCosmeticItem;
    API.GetTransmogItemInfo = GetTransmogItemInfo;

    local function IsItemValidForComparison(itemID)
        return itemID and (not IsCosmeticItem(itemID)) and IsEquippableItem(itemID)
    end
    API.IsItemValidForComparison = IsItemValidForComparison;
end

do  --Keybindings
    local GetBindingKey = GetBindingKey;

    local function GetBestInteractKey()
        local key1, key2 = GetBindingKey("INTERACTTARGET");
        local key, errorText;

        if key1 == "" then key1 = nil; end;
        if key2 == "" then key2 = nil; end;

        if key1 or key2 then
            if key1 then
                if not string.find(key1, "-") then
                    key = key1;
                end
            end

            if (not key) and key2 then
                if not string.find(key2, "-") then
                    key = key2;
                end
            end

            if not key then
                errorText = L["Cannot Use Key Combination"];
            end
        else
            errorText = L["Interact Key Not Set"];
        end

        return key, errorText
    end
    API.GetBestInteractKey = GetBestInteractKey;
end