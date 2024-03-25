--Contributors: Voopie
if not (GetLocale() == "ruRU") then return end;

local _, addon = ...
local L = addon.L;


L["Quest Frequency Daily"] = "Ежедневное";
L["Quest Frequency Weekly"] = "Еженедельное";

L["Quest Type Repeatable"] = "Повторяемое";
L["Quest Type Trivial"] = "Простое";    --Low-level quest
L["Quest Type Dungeon"] = "Подземелье";
L["Quest Type Raid"] = "Рейд";
L["Quest Type Covenant Calling"] = "Призыв ковенанта";

L["Accept"] = "Принять";
L["Continue"] = "Продолжить";
L["Complete Quest"] = "Завершить";
L["Incomplete"] = "Не завершено";
L["Cancel"] = "Отмена";
L["Goodbye"] = "До встречи";
L["Decline"] = "Отказаться";
L["OK"] = "OK";
L["Quest Objectives"] = "Задачи";   --We use the shorter one, not QUEST_OBJECTIVES
L["Reward"] = "Награда";
L["Rewards"] = "Награды";
L["War Mode Bonus"] = "Бонус режима войны";
L["Honor Points"] = "Честь";
L["Symbol Gold"] = "з";
L["Symbol Silver"] = "с";
L["Symbol Copper"] = "м";
L["Requirements"] = "Требования";
L["Current Colon"] = "Текущий уровень:";
L["Renown Level Label"] = "Известность ";  --There is a space
L["Abilities"] = "Способности";
L["Traits"] = "Особенности";
L["Costs"] = "Стоимость";   --The costs to continue an action, usually gold
L["Ready To Enter"] = "Можно войти";
L["Show Comparison"] = "Показать сравнение";   --Toggle item comparison on the tooltip
L["Hide Comparison"] = "Скрыть сравнение";
L["Copy Text"] = "Скопировать текст";
L["To Next Level Label"] = "Следующий уровень";
L["Quest Accepted"] = "Задание принято";
L["Quest Log Full"] = "Журнал заданий заполнен";
L["Quest Auto Accepted Tooltip"] = "Это задание автоматически принимается игрой.";
L["Level Maxed"] = "(Макс.)";   --Reached max level
L["Paragon Reputation"] = "Совершенствование";
L["Different Item Types Alert"] = "Типы предметов отличаются!";
L["Click To Read"] = "Щелкните левой кнопкой мыши, чтобы прочитать";


--String Format
L["Format Reputation Reward Tooltip"] = "Улучшает отношение фракции %2$s на %1$d";
L["Format You Have X"] = "- У вас |cffffffff%d|r";
L["Format You Have X And Y In Bank"] = "- У вас |cffffffff%d|r (|cffffffff%d|r в банке)";
L["Format Suggested Players"] = "Рекомендуется %d |4игрок:игрока:игроков;.";
L["Format Current Skill Level"] = "Текущий уровень: |cffffffff%d/%d|r";
L["Format Reward Title"] = "Звание: %s";
L["Format Follower Level Class"] = "Уровень %d %s";
L["Format Monster Say"] = "%s говорит: ";
L["Format Quest Accepted"] = "Вы получили задание \"%s\".";
L["Format Quest Completed"] = "Задание \"%s\" выполнено.";
L["Format Player XP"] = "Опыт: %d/%d (%d%%)";
L["Format Gold Amount"] = "%d |4золотая:золотые:золотых;";
L["Format Silver Amount"] = "%d |4серебряная:серебряные:серебряных;";
L["Format Copper Amount"] = "%d |4медная монета:медные монеты:медных монет;";
L["Format Unit Level"] = "%d-й уровень";
L["Format Replace Item"] = "Заменить %s";


--Settings
L["UI"] = "Интерфейс";
L["Camera"] = "Камера";
L["Control"] = "Управление";

L["Quest"] = "Задание";
L["Gossip"] = "Разговор";
L["Theme"] = "Тема";
L["Theme Desc"] = "Выберите цветовую тему интерфейса.";
L["Theme Brown"] = "Коричневая";
L["Theme Dark"] = "Тёмная";
L["Frame Size"] = "Размер окна";
L["Frame Size Desc"] = "Выберите размер диалогового окна.";
L["Size Small"] = "Малый";
L["Size Medium"] = "Средний";
L["Size Large"] = "Большой";
L["Font Size"] = "Размер шрифта";
L["Font Size Desc"] = "Выберите размер шрифта.";
L["Hide UI"] = "Скрыть интерфейс";
L["Hide UI Desc"] = "Скрыть интерфейс игры, когда вы взаимодействуете с NPC.";
L["Hide Unit Names"] = "Скрыть имена";
L["Hide Unit Names Desc"] = "Скрывать имена игроков и других NPC, когда вы взаимодействуете с NPC.";
L["Show Copy Text Button"] = "Показать кнопку копирования текста";
L["Show Copy Text Button Desc"] = "Показывать кнопку копирования текста в правом верхнем углу диалогового окна.";
L["Show Quest Type Text"] = "Показать тип задания";
L["Show Quest Type Text Desc"] = "Показывать тип задания справа от него.\n\nПростые задания всегда помечены.";
L["Show NPC Name On Page"] = "Показать имя NPC";
L["Show NPC Name On Page Desc"] = "Показывать имя NPC.";
L["Simplify Currency Rewards"] = "Упрощение наград с валютой";
L["Simplify Currency Rewards Desc"] = "Использовать значки меньшего размера для обозначения наград с валютой и убрать их названия.";
L["Auto Select"] = "Автовыбор";
L["Auto Select Gossip"] = "Автовыбор варианта";
L["Auto Select Gossip Desc"] = "Автоматически выбирать наилучший вариант диалога при взаимодействии с определенным NPC.";
L["Force Gossip"] = "Принудительный разговор";
L["Force Gossip Desc"] = "По умолчанию игра иногда автоматически выбирает первый вариант, не показывая диалоговое окно. Если включить принудительный просмотр разговора, диалоговое окно станет видимым.";
L["Nameplate Dialog"] = "Отображать диалог на неймплейте";
L["Nameplate Dialog Desc"] = "Отображать диалог на неймплейте NPC, если они не предлагают выбора.\n\nЭтот параметр изменяет CVar \"SoftTarget Nameplate Interact\".";

L["Camera Movement"] = "Движение камеры";
L["Camera Movement Off"] = "ВЫКЛ";
L["Camera Movement Zoom In"] = "Приближение";
L["Camera Movement Horizontal"] = "Горизонтальное";
L["Maintain Camera Position"] = "Сохранять положение камеры";
L["Maintain Camera Position Desc"] = "Сохранять положение камеры на короткое время после окончания взаимодействия с NPC. Включение этой опции уменьшит резкое движение камеры, вызванное задержкой между диалогами.";
L["Change FOV"] = "Изменить поле зрения";
L["Change FOV Desc"] = "Уменьшить поле зрения камеры, чтобы приблизить изображение к NPC.";

L["Input Device"] = "Устройство ввода";
L["Input Device Desc"] = "Влияет на значки горячих клавиш и макет интерфейса.";
L["Input Device KBM"] = "Клавиатура и мышь";
L["Input Device Xbox"] = "Xbox";
L["Input Device Xbox Tooltip"] = "Клавиша подтверждения: [KEY:XBOX:PAD1]\nКлавиша отмены: [KEY:XBOX:PAD2]";
L["Input Device PlayStation"] = "PlayStation";
L["Input Device PlayStation Tooltip"] = "Клавиша подтверждения: [KEY:PS:PAD1]\nКлавиша отмены: [KEY:PS:PAD2]";
L["Primary Control Key"] = "Клавиша подтверждения";
L["Primary Control Key Desc"] = "Нажмите эту клавишу, чтобы выбрать первый доступный вариант, например, принять задание."
L["Press Button To Scroll Down"] = "Нажатие клавиши для прокрутки вниз";
L["Press Button To Scroll Down Desc"] = "Если содержимое превышает высоту окна, нажатие клавиши подтверждения приведет к прокрутке страницы вниз вместо принятия задания.";

L["Key Space"] = "Пробел";
L["Key Interact"] = "Взаимодействие";
L["Cannot Use Key Combination"] = "Комбинация клавиш не поддерживается.";
L["Interact Key Not Set"] = "Вы не установили клавишу взаимодействия.";


--Tutorial
L["Tutorial Settings Hotkey"] = "Нажмите [KEY:PC:F1] для открытия настроек";
L["Tutorial Settings Hotkey Console"] = "Нажмите [KEY:PC:F1] или [KEY:CONSOLE:MENU] для открытия настроек";   --Use this if gamepad enabled
