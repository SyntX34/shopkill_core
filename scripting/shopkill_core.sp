#include <sourcemod>
#include <shop>
#include <multicolors>
#include <clientprefs>
#include <vip_core>
#undef REQUIRE_PLUGIN
#include <zombiereloaded>
#include <zriot>
#define REQUIRE_PLUGIN
#pragma tabsize 0

#define Head 0
#define Wep 1
#define Death 2
#define NOTIFY_DISABLED 0
#define NOTIFY_CHAT     1
#define NOTIFY_CONSOLE  2
#define NOTIFY_HUD      3
#define COLOR_RANDOM -1
#define COLOR_CUSTOM -2

char g_sHudColorNames[50][32] = {
    "White", "Silver", "Gray", "Dark Red", "Red",
    "Crimson", "Firebrick", "Coral", "Tomato", "Salmon",
    "Dark Orange", "Orange", "Gold", "Yellow", "Khaki",
    "Lime", "Lime Green", "Pale Green", "Spring Green", "Medium Spring Green",
    "Sea Green", "Forest Green", "Green", "Dark Green", "Olive",
    "Teal", "Dark Cyan", "Cyan / Aqua", "Turquoise", "Medium Turquoise",
    "Aquamarine", "Sky Blue", "Deep Sky Blue", "Dodger Blue", "Cornflower Blue",
    "Royal Blue", "Blue", "Medium Blue", "Dark Blue", "Navy",
    "Midnight Blue", "Indigo", "Purple", "Dark Magenta", "Violet",
    "Orchid", "Magenta / Fuchsia", "Medium Orchid", "Hot Pink", "Deep Pink"
};

int g_iHudColorRGB[50][3] = {
    {255, 255, 255}, {192, 192, 192}, {128, 128, 128}, {139, 0, 0}, {255, 0, 0},
    {220, 20, 60}, {178, 34, 34}, {255, 127, 80}, {255, 99, 71}, {250, 128, 114},
    {255, 140, 0}, {255, 165, 0}, {255, 215, 0}, {255, 255, 0}, {240, 230, 140},
    {0, 255, 0}, {50, 205, 50}, {152, 251, 152}, {0, 255, 127}, {0, 250, 154},
    {46, 139, 87}, {34, 139, 34}, {0, 128, 0}, {0, 100, 0}, {128, 128, 0},
    {0, 128, 128}, {0, 139, 139}, {0, 255, 255}, {64, 224, 208}, {72, 209, 204},
    {127, 255, 212}, {135, 206, 235}, {0, 191, 255}, {30, 144, 255}, {100, 149, 237},
    {65, 105, 225}, {0, 0, 255}, {0, 0, 205}, {0, 0, 139}, {0, 0, 128},
    {25, 25, 112}, {75, 0, 130}, {128, 0, 128}, {139, 0, 139}, {238, 130, 238},
    {218, 112, 214}, {255, 0, 255}, {186, 85, 211}, {255, 105, 180}, {255, 20, 147}
};

Handle shopkill_wep;
Handle shopkill_head;
int	Infects[MAXPLAYERS+1];

ConVar g_cvPluginEnabled;
ConVar g_cvChatEnabled;
ConVar g_cvVIPMultiplier;
ConVar g_cvAccessMethod;
ConVar g_cvAccessFlags;
ConVar g_cvVipCoreRequiredFlag;
bool g_bPluginEnabled;
bool g_bChatEnabled;
int g_iAccessMethod;
char g_sAccessFlags[32];
bool g_bVipCoreRequired;

bool g_bHasVIPCore = false;
Cookie g_hNotifyCookie;
Cookie g_hColorModeCookie;
Cookie g_hCustomColorCookie;

int g_iClientNotifyMode[MAXPLAYERS+1] = {NOTIFY_CHAT, ...};
int g_iClientColorChoice[MAXPLAYERS+1] = {COLOR_RANDOM, ...};
char g_sClientCustomColor[MAXPLAYERS+1][32];
bool g_bAwaitingColorInput[MAXPLAYERS+1];

Handle g_hHudSync;

bool g_bHasZombieReloaded = false;
bool g_bHasZombieRiot = false;

public Plugin myinfo =
{
    name            = "[Shop] Give Credits on Actions with VIP Support",
    author          = "[shopkill] by +SyntX",
    description     = "Give credits to players for killing, infecting other players with VIP multiplier and customizable notifications",
    version         = "1.6",
    url             = "https://steamcommunity.com/id/syntx34"
};

public void OnPluginStart()
{
    g_hHudSync = CreateHudSynchronizer();

    g_cvPluginEnabled = CreateConVar("sm_shopkill_enabled", "1", "Enable/disable the ShopKill plugin (1 = enable, 0 = disable)", _, true, 0.0, true, 1.0);
    g_cvChatEnabled = CreateConVar("sm_shopkill_chat", "1", "Enable/disable chat messages globally (1 = enable, 0 = disable)", _, true, 0.0, true, 1.0);
    g_cvVIPMultiplier = CreateConVar("sm_shopkill_vip_multiplier", "2.0", "Multiplier for VIP players (applied to all rewards)", _, true, 1.0, true, 10.0);
    g_cvAccessMethod = CreateConVar("sm_shopkill_access_method", "1", "Access method: 1=Flags only, 2=Vip Core only, 3=Both (Flags OR Vip)", _, true, 1.0, true, 3.0);
    g_cvAccessFlags = CreateConVar("sm_shopkill_access_flags", "o", "Flags required for access (if access_method is 1 or 3). Use standard SM flags (a-z)");
    g_cvVipCoreRequiredFlag = CreateConVar("sm_shopkill_vipcore_required", "1", "Require VIP_Core for access method 2/3? 0=No, 1=Yes", _, true, 0.0, true, 1.0);
    
    g_cvPluginEnabled.AddChangeHook(OnConVarChanged);
    g_cvChatEnabled.AddChangeHook(OnConVarChanged);
    g_cvVIPMultiplier.AddChangeHook(OnConVarChanged);
    g_cvAccessMethod.AddChangeHook(OnConVarChanged);
    g_cvAccessFlags.AddChangeHook(OnConVarChanged);
    g_cvVipCoreRequiredFlag.AddChangeHook(OnConVarChanged);
    
    g_bPluginEnabled = g_cvPluginEnabled.BoolValue;
    g_bChatEnabled = g_cvChatEnabled.BoolValue;
    g_iAccessMethod = g_cvAccessMethod.IntValue;
    g_cvAccessFlags.GetString(g_sAccessFlags, sizeof(g_sAccessFlags));
    g_bVipCoreRequired = g_cvVipCoreRequiredFlag.BoolValue;
    
    g_hNotifyCookie = new Cookie("shopkill_notify_mode", "ShopKill Notification Mode (0=Off, 1=Chat, 2=Console, 3=Custom HUD)", CookieAccess_Private);
    g_hColorModeCookie = new Cookie("shopkill_hud_colormode", "ShopKill HUD Color Choice (-1=Random, -2=Custom, 0..49=Palette)", CookieAccess_Private);
    g_hCustomColorCookie = new Cookie("shopkill_hud_customcolor", "ShopKill Custom HUD Color String", CookieAccess_Private);

    SetCookieMenuItem(ShopKillCookieMenuHandler, 0, "ShopKill Notifications");
    
    HookEvent("player_death", CallBacl_D, EventHookMode_Post);
    LoadTranslations("shopkill_css.txt");
    
    RegConsoleCmd("sm_settings", Command_Settings, "Open player settings menu");
    RegConsoleCmd("sm_shopkillchat", Command_ChatToggle, "Toggle ShopKill notifications");
    RegConsoleCmd("sm_skchat", Command_ChatToggle, "Toggle ShopKill notifications");
    RegConsoleCmd("sm_shopkillprefs", Command_ShowPreferences, "Show ShopKill preferences");

    AutoExecConfig(true);
    CreateTimer(0.5, Timer_DetectPlugins, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Command_Settings(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;

    ShowSettingsMenu(client);
    return Plugin_Handled;
}

public void ShopKillCookieMenuHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
    if (action == CookieMenuAction_SelectOption)
    {
        ShowNotificationMenu(client);
    }
    else if (action == CookieMenuAction_DisplayOption)
    {
        char modeName[64];
        GetNotificationModeName(client, g_iClientNotifyMode[client], modeName, sizeof(modeName));
        Format(buffer, maxlen, "%T", "cookie_menu_display", client, modeName);
    }
}

void ShowSettingsMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Settings);
    char title[128];
    Format(title, sizeof(title), "%T", "settings_menu_title", client);
    menu.SetTitle(title);

    char modeName[64];
    GetNotificationModeName(client, g_iClientNotifyMode[client], modeName, sizeof(modeName));
    char buffer[128];
    Format(buffer, sizeof(buffer), "%T", "settings_notify_item", client, modeName);
    menu.AddItem("notify", buffer);

    char colorDesc[64];
    GetActiveColorName(client, colorDesc, sizeof(colorDesc));
    Format(buffer, sizeof(buffer), "%T", "settings_hud_color_item", client, colorDesc);
    menu.AddItem("color", buffer);

    menu.ExitButton = true;
    menu.Display(client, 30);
}

public int MenuHandler_Settings(Menu menu, MenuAction action, int client, int itemNum)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(itemNum, info, sizeof(info));

        if (StrEqual(info, "notify"))
        {
            ShowNotificationMenu(client);
        }
        else if (StrEqual(info, "color"))
        {
            ShowColorMenu(client);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowNotificationMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Notification);
    char title[128];
    Format(title, sizeof(title), "%T", "notify_menu_title", client);
    menu.SetTitle(title);

    char buffer[128];
    char modeName[64];
    char selectedTag[32];
    Format(selectedTag, sizeof(selectedTag), " %T", "notify_mode_selected_tag", client);

    /* Chat */
    GetNotificationModeName(client, NOTIFY_CHAT, modeName, sizeof(modeName));
    Format(buffer, sizeof(buffer), "%s%s", modeName, (g_iClientNotifyMode[client] == NOTIFY_CHAT) ? selectedTag : "");
    menu.AddItem("1", buffer);

    /* Console */
    GetNotificationModeName(client, NOTIFY_CONSOLE, modeName, sizeof(modeName));
    Format(buffer, sizeof(buffer), "%s%s", modeName, (g_iClientNotifyMode[client] == NOTIFY_CONSOLE) ? selectedTag : "");
    menu.AddItem("2", buffer);

    /* Custom HUD */
    GetNotificationModeName(client, NOTIFY_HUD, modeName, sizeof(modeName));
    Format(buffer, sizeof(buffer), "%s%s", modeName, (g_iClientNotifyMode[client] == NOTIFY_HUD) ? selectedTag : "");
    menu.AddItem("3", buffer);

    /* Disabled */
    GetNotificationModeName(client, NOTIFY_DISABLED, modeName, sizeof(modeName));
    Format(buffer, sizeof(buffer), "%s%s", modeName, (g_iClientNotifyMode[client] == NOTIFY_DISABLED) ? selectedTag : "");
    menu.AddItem("0", buffer);

    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, 30);
}

public int MenuHandler_Notification(Menu menu, MenuAction action, int client, int itemNum)
{
    if (action == MenuAction_Select)
    {
        char info[8];
        menu.GetItem(itemNum, info, sizeof(info));
        int mode = StringToInt(info);

        g_iClientNotifyMode[client] = mode;
        g_hNotifyCookie.Set(client, info);

        char modeName[64];
        GetNotificationModeName(client, mode, modeName, sizeof(modeName));
        CPrintToChat(client, "%t", "chat_notify_changed", modeName);
        ShowNotificationMenu(client);
    }
    else if (action == MenuAction_Cancel && itemNum == MenuCancel_ExitBack)
    {
        ShowSettingsMenu(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowColorMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Color);
    char title[128];
    Format(title, sizeof(title), "%T", "color_menu_title", client);
    menu.SetTitle(title);

    char buffer[128];
    char selectedTag[32];
    Format(selectedTag, sizeof(selectedTag), " %T", "notify_mode_selected_tag", client);

    /* Option 1: Custom Color Option (above all colors) */
    char customDisplay[32];
    if (g_sClientCustomColor[client][0] != '\0')
    {
        strcopy(customDisplay, sizeof(customDisplay), g_sClientCustomColor[client]);
    }
    else
    {
        strcopy(customDisplay, sizeof(customDisplay), "None");
    }
    Format(buffer, sizeof(buffer), "%T%s", "color_custom_input_item", client, customDisplay, (g_iClientColorChoice[client] == COLOR_CUSTOM) ? selectedTag : "");
    menu.AddItem("custom", buffer);

    /* Option 2: Random Vibrant Colors */
    Format(buffer, sizeof(buffer), "%T%s", "color_random_item", client, (g_iClientColorChoice[client] == COLOR_RANDOM) ? selectedTag : "");
    menu.AddItem("random", buffer);

    /* 50 Presets */
    for (int i = 0; i < 50; i++)
    {
        char info[16];
        IntToString(i, info, sizeof(info));
        Format(buffer, sizeof(buffer), "%s%s", g_sHudColorNames[i], (g_iClientColorChoice[client] == i) ? selectedTag : "");
        menu.AddItem(info, buffer);
    }

    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, 30);
}

public int MenuHandler_Color(Menu menu, MenuAction action, int client, int itemNum)
{
    if (action == MenuAction_Select)
    {
        char info[16];
        menu.GetItem(itemNum, info, sizeof(info));

        if (StrEqual(info, "custom"))
        {
            g_bAwaitingColorInput[client] = true;
            CPrintToChat(client, "%t", "chat_custom_color_prompt");
        }
        else if (StrEqual(info, "random"))
        {
            g_iClientColorChoice[client] = COLOR_RANDOM;
            g_hColorModeCookie.Set(client, "-1");

            char colorName[64];
            GetActiveColorName(client, colorName, sizeof(colorName));
            CPrintToChat(client, "%t", "color_selected", colorName);
            ShowColorMenu(client);
        }
        else
        {
            int colorIdx = StringToInt(info);
            g_iClientColorChoice[client] = colorIdx;
            g_hColorModeCookie.Set(client, info);

            char colorName[64];
            GetActiveColorName(client, colorName, sizeof(colorName));
            CPrintToChat(client, "%t", "color_selected", colorName);
            ShowColorMenu(client);
        }
    }
    else if (action == MenuAction_Cancel && itemNum == MenuCancel_ExitBack)
    {
        ShowSettingsMenu(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
    if (!IsValidClient(client) || !g_bAwaitingColorInput[client])
        return Plugin_Continue;

    char trimmed[128];
    strcopy(trimmed, sizeof(trimmed), sArgs);
    TrimString(trimmed);

    if (StrEqual(trimmed, "!cancel", false) || StrEqual(trimmed, "cancel", false))
    {
        g_bAwaitingColorInput[client] = false;
        CPrintToChat(client, "%t", "chat_custom_color_cancelled");
        ShowColorMenu(client);
        return Plugin_Handled;
    }

    int r, g, b, a;
    if (ParseColorString(trimmed, r, g, b, a))
    {
        g_bAwaitingColorInput[client] = false;
        g_iClientColorChoice[client] = COLOR_CUSTOM;
        strcopy(g_sClientCustomColor[client], sizeof(g_sClientCustomColor[]), trimmed);

        g_hColorModeCookie.Set(client, "-2");
        g_hCustomColorCookie.Set(client, trimmed);

        CPrintToChat(client, "%t", "chat_custom_color_success", trimmed);
        ShowColorMenu(client);
        return Plugin_Handled;
    }

    CPrintToChat(client, "%t", "chat_custom_color_invalid");
    return Plugin_Handled;
}

bool ParseColorString(const char[] input, int &r, int &g, int &b, int &a)
{
    char clean[64];
    strcopy(clean, sizeof(clean), input);
    TrimString(clean);

    /* Format 1: #RRGGBB or #RRGGBBAA */
    if (clean[0] == '#')
    {
        int len = strlen(clean);
        if (len == 7 || len == 9)
        {
            char hexR[3], hexG[3], hexB[3], hexA[3];
            Format(hexR, sizeof(hexR), "%c%c", clean[1], clean[2]);
            Format(hexG, sizeof(hexG), "%c%c", clean[3], clean[4]);
            Format(hexB, sizeof(hexB), "%c%c", clean[5], clean[6]);

            if (!IsHexByte(hexR) || !IsHexByte(hexG) || !IsHexByte(hexB))
                return false;

            r = HexToInt(hexR);
            g = HexToInt(hexG);
            b = HexToInt(hexB);
            a = 255;

            if (len == 9)
            {
                Format(hexA, sizeof(hexA), "%c%c", clean[7], clean[8]);
                if (!IsHexByte(hexA))
                    return false;
                a = HexToInt(hexA);
            }
            return true;
        }
        return false;
    }

    /* Format 2: R G B or R G B A (space or comma separated) */
    char copy[64];
    strcopy(copy, sizeof(copy), clean);
    ReplaceString(copy, sizeof(copy), ",", " ");

    char parts[4][16];
    int count = ExplodeString(copy, " ", parts, 4, 16);

    /* Filter out empty tokens from multiple spaces */
    char cleanParts[4][16];
    int tokenCount = 0;
    for (int i = 0; i < count && tokenCount < 4; i++)
    {
        TrimString(parts[i]);
        if (parts[i][0] != '\0')
        {
            strcopy(cleanParts[tokenCount++], 16, parts[i]);
        }
    }

    if (tokenCount >= 3)
    {
        r = StringToInt(cleanParts[0]);
        g = StringToInt(cleanParts[1]);
        b = StringToInt(cleanParts[2]);
        a = (tokenCount >= 4) ? StringToInt(cleanParts[3]) : 255;

        if (r >= 0 && r <= 255 && g >= 0 && g <= 255 && b >= 0 && b <= 255 && a >= 0 && a <= 255)
        {
            return true;
        }
    }

    return false;
}

bool IsHexByte(const char[] str)
{
    for (int i = 0; i < 2; i++)
    {
        char c = str[i];
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')))
            return false;
    }
    return true;
}

int HexToInt(const char[] str)
{
    int val = 0;
    for (int i = 0; i < 2; i++)
    {
        char c = str[i];
        int digit = 0;
        if (c >= '0' && c <= '9') digit = c - '0';
        else if (c >= 'a' && c <= 'f') digit = c - 'a' + 10;
        else if (c >= 'A' && c <= 'F') digit = c - 'A' + 10;
        val = (val << 4) | digit;
    }
    return val;
}

void GetActiveColorName(int client, char[] buffer, int maxlen)
{
    int choice = g_iClientColorChoice[client];
    if (choice == COLOR_RANDOM)
    {
        Format(buffer, maxlen, "%T", "color_random_item", client);
    }
    else if (choice == COLOR_CUSTOM)
    {
        Format(buffer, maxlen, "Custom (%s)", g_sClientCustomColor[client][0] ? g_sClientCustomColor[client] : "#ffffff");
    }
    else if (choice >= 0 && choice < 50)
    {
        strcopy(buffer, maxlen, g_sHudColorNames[choice]);
    }
    else
    {
        Format(buffer, maxlen, "%T", "color_random_item", client);
    }
}

void GetNotificationModeName(int client, int mode, char[] buffer, int maxlen)
{
    switch (mode)
    {
        case NOTIFY_CHAT:    Format(buffer, maxlen, "%T", "notify_mode_chat", client);
        case NOTIFY_CONSOLE: Format(buffer, maxlen, "%T", "notify_mode_console", client);
        case NOTIFY_HUD:     Format(buffer, maxlen, "%T", "notify_mode_hud", client);
        default:             Format(buffer, maxlen, "%T", "notify_mode_disabled", client);
    }
}

public Action Command_ChatToggle(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;
    
    /* Cycle through Chat -> Console -> Custom HUD -> Disabled */
    int nextMode = (g_iClientNotifyMode[client] + 1) % 4;
    g_iClientNotifyMode[client] = nextMode;
    
    char sValue[8];
    IntToString(nextMode, sValue, sizeof(sValue));
    g_hNotifyCookie.Set(client, sValue);
    
    char modeName[64];
    GetNotificationModeName(client, nextMode, modeName, sizeof(modeName));
    CPrintToChat(client, "%t", "chat_notify_changed", modeName);
    
    return Plugin_Handled;
}

public Action Command_ShowPreferences(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;
    
    bool bIsVIP = IsVIP(client);
    float fMultiplier = bIsVIP ? GetConfigVIPMultiplier() : 1.0;
    
    char modeName[64];
    GetNotificationModeName(client, g_iClientNotifyMode[client], modeName, sizeof(modeName));

    char statusScope[64];
    Format(statusScope, sizeof(statusScope), "%T", g_bChatEnabled ? "status_globally_enabled" : "status_globally_disabled", client);

    char colorDesc[64];
    GetActiveColorName(client, colorDesc, sizeof(colorDesc));

    char vipStatus[32];
    Format(vipStatus, sizeof(vipStatus), "%T", bIsVIP ? "yes" : "no", client);

    CPrintToChat(client, "%t", "prefs_header");
    CPrintToChat(client, "%t", "prefs_notify", modeName, statusScope);
    CPrintToChat(client, "%t", "prefs_hud_color", colorDesc);
    CPrintToChat(client, "%t", "prefs_vip_status", vipStatus);
    
    if (bIsVIP)
    {
        CPrintToChat(client, "%t", "prefs_vip_multiplier", fMultiplier);
    }
    
    CPrintToChat(client, "%t", "prefs_hint");
    
    return Plugin_Handled;
}

public void OnClientCookiesCached(int client)
{
    if (!IsValidClient(client))
        return;
    
    char sValue[32];
    g_hNotifyCookie.Get(client, sValue, sizeof(sValue));
    
    if (sValue[0] != '\0')
    {
        int mode = StringToInt(sValue);
        if (mode >= NOTIFY_DISABLED && mode <= NOTIFY_HUD)
        {
            g_iClientNotifyMode[client] = mode;
        }
        else
        {
            g_iClientNotifyMode[client] = NOTIFY_CHAT;
        }
    }
    else
    {
        g_iClientNotifyMode[client] = NOTIFY_CHAT;
        IntToString(NOTIFY_CHAT, sValue, sizeof(sValue));
        g_hNotifyCookie.Set(client, sValue);
    }

    g_hColorModeCookie.Get(client, sValue, sizeof(sValue));
    if (sValue[0] != '\0')
    {
        g_iClientColorChoice[client] = StringToInt(sValue);
    }
    else
    {
        g_iClientColorChoice[client] = COLOR_RANDOM;
    }

    g_hCustomColorCookie.Get(client, g_sClientCustomColor[client], sizeof(g_sClientCustomColor[]));
    g_bAwaitingColorInput[client] = false;
}

public void OnClientDisconnect(int client)
{
    g_iClientNotifyMode[client] = NOTIFY_CHAT;
    g_iClientColorChoice[client] = COLOR_RANDOM;
    g_sClientCustomColor[client][0] = '\0';
    g_bAwaitingColorInput[client] = false;
}

public Action Timer_DetectPlugins(Handle timer)
{
    DetectPlugins();
    return Plugin_Stop;
}

void DetectPlugins()
{
    g_bHasVIPCore = LibraryExists("vip_core");
    g_bHasZombieReloaded = LibraryExists("zombiereloaded");
    g_bHasZombieRiot = LibraryExists("ZombieRiot");
    
    PrintToServer("[ShopKill] Plugin detection: VIP=%d, ZR=%d, ZRiot=%d", 
        g_bHasVIPCore, g_bHasZombieReloaded, g_bHasZombieRiot);
}

public void OnAllPluginsLoaded()
{
    g_bHasVIPCore = LibraryExists("vip_core");
    g_bHasZombieReloaded = LibraryExists("zombiereloaded");
    g_bHasZombieRiot = LibraryExists("ZombieRiot");
    
    if (g_bHasVIPCore)
        PrintToServer("[ShopKill] VIP Core detected.");
    if (g_bHasZombieReloaded)
        PrintToServer("[ShopKill] Zombie:Reloaded detected.");
    if (g_bHasZombieRiot)
        PrintToServer("[ShopKill] Zombie:Riot detected.");
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "vip_core"))
        g_bHasVIPCore = true;
    else if (StrEqual(name, "zombiereloaded"))
        g_bHasZombieReloaded = true;
    else if (StrEqual(name, "ZombieRiot"))
        g_bHasZombieRiot = true;
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "vip_core"))
        g_bHasVIPCore = false;
    else if (StrEqual(name, "zombiereloaded"))
        g_bHasZombieReloaded = false;
    else if (StrEqual(name, "ZombieRiot"))
        g_bHasZombieRiot = false;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cvPluginEnabled)
    {
        g_bPluginEnabled = convar.BoolValue;
    }
    else if (convar == g_cvChatEnabled)
    {
        g_bChatEnabled = convar.BoolValue;
    }
    else if (convar == g_cvVIPMultiplier)
    {
        /* Read directly via kv.GetFloat or config */
    }
    else if (convar == g_cvAccessMethod)
    {
        g_iAccessMethod = g_cvAccessMethod.IntValue;
    }
    else if (convar == g_cvAccessFlags)
    {
        g_cvAccessFlags.GetString(g_sAccessFlags, sizeof(g_sAccessFlags));
    }
    else if (convar == g_cvVipCoreRequiredFlag)
    {
        g_bVipCoreRequired = g_cvVipCoreRequiredFlag.BoolValue;
    }
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErr_max) 
{
	shopkill_wep = CreateGlobalForward("ShopKill_OnWepGive", ET_Hook, Param_Cell, Param_CellByRef);
	shopkill_head = CreateGlobalForward("ShopKill_OnHeadGive", ET_Hook, Param_Cell, Param_CellByRef);      

    RegPluginLibrary("shopkill_core");
    return APLRes_Success;    
}

Action ShopKill_OnHeadGive(int iClient, int& count)
{
	Action Result = Plugin_Continue;
	Call_StartForward(shopkill_head);
	Call_PushCell(iClient);
	Call_PushCellRef(count);
	Call_Finish(Result);
	return Result;
}

Action ShopKill_OnWepGive(int iClient, int& count)
{
	Action Result = Plugin_Continue;
	Call_StartForward(shopkill_wep);
	Call_PushCell(iClient);
	Call_PushCellRef(count);
	Call_Finish(Result);
	return Result;
}

int GetConfigMin()
{
    KeyValues kv = new KeyValues("ShopKill");
    char path[PLATFORM_MAX_PATH+1];
    BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/shopkill.cfg");    
    if(kv.ImportFromFile(path))
    {
        int n = kv.GetNum("MinCount", 3);
        delete kv;                
        return n;   
    }
    delete kv;
    
    return -1;
}

float GetConfigVIPMultiplier()
{
    KeyValues kv = new KeyValues("ShopKill");
    char path[PLATFORM_MAX_PATH+1];
    BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/shopkill.cfg");    
    if(kv.ImportFromFile(path))
    {
        float multiplier = kv.GetFloat("VIPMultiplier", 2.0);
        delete kv;
        return multiplier;
    }
    delete kv;
    
    return 2.0;
}

bool IsVIP(int client)
{
    if (!IsValidClient(client))
        return false;

    if (GetUserFlagBits(client) & ADMFLAG_ROOT)
        return true;
    
    bool bHasFlagAccess = false;
    bool bHasVipCoreAccess = false;
    if (g_iAccessMethod == 1 || g_iAccessMethod == 3)
    {
        int flagCount = strlen(g_sAccessFlags);
        if (flagCount > 0)
        {
            for (int i = 0; i < flagCount; i++)
            {
                AdminFlag flag;
                if (FindFlagByChar(g_sAccessFlags[i], flag))
                {
                    if (CheckCommandAccess(client, "sm_shopkill_access", flag, true))
                    {
                        bHasFlagAccess = true;
                        break;
                    }
                }
            }
        }
        
        if (!bHasFlagAccess && flagCount == 0)
        {
            bHasFlagAccess = CheckCommandAccess(client, "sm_shopkill_access", ADMFLAG_CUSTOM1, true);
        }
    }
    if ((g_iAccessMethod == 2 || g_iAccessMethod == 3) && g_bHasVIPCore)
    {
        char feature[64] = "VIPFeatures";
        bHasVipCoreAccess = VIP_IsClientVIP(client) && VIP_IsClientFeatureUse(client, feature);
    }
    else if ((g_iAccessMethod == 2 || g_iAccessMethod == 3) && !g_bHasVIPCore && g_bVipCoreRequired)
    {
        bHasVipCoreAccess = false;
    }
    else if ((g_iAccessMethod == 2 || g_iAccessMethod == 3) && !g_bHasVIPCore && !g_bVipCoreRequired)
    {
        bHasVipCoreAccess = false;
    }
    switch (g_iAccessMethod)
    {
        case 1: return bHasFlagAccess;
        case 2: return bHasVipCoreAccess;
        case 3: return (bHasFlagAccess || bHasVipCoreAccess);
        default: return false;
    }
}

void StripColorTags(const char[] input, char[] output, int maxlen)
{
    int inLen = strlen(input);
    int outIdx = 0;
    bool inTag = false;

    for (int i = 0; i < inLen && outIdx < maxlen - 1; i++)
    {
        if (input[i] == '{')
        {
            inTag = true;
            continue;
        }
        if (inTag)
        {
            if (input[i] == '}')
            {
                inTag = false;
            }
            continue;
        }
        output[outIdx++] = input[i];
    }
    output[outIdx] = '\0';
}

void GetClientHudColor(int client, int &r, int &g, int &b, int &a)
{
    a = 255;
    int choice = g_iClientColorChoice[client];

    if (choice == COLOR_CUSTOM)
    {
        if (ParseColorString(g_sClientCustomColor[client], r, g, b, a))
        {
            return;
        }
        /* Fallback if custom parsing fails */
        choice = COLOR_RANDOM;
    }

    if (choice >= 0 && choice < 50)
    {
        r = g_iHudColorRGB[choice][0];
        g = g_iHudColorRGB[choice][1];
        b = g_iHudColorRGB[choice][2];
        return;
    }

    /* Random vibrant HUD color palette */
    int palette[10][3] = {
        {255, 255, 0},   /* Yellow */
        {0, 255, 128},   /* Bright Green */
        {0, 200, 255},   /* Cyan */
        {255, 140, 0},   /* Orange */
        {255, 80, 80},   /* Red-Pink */
        {180, 100, 255}, /* Purple */
        {255, 215, 0},   /* Gold */
        {0, 255, 255},   /* Aqua */
        {50, 205, 50},   /* Lime Green */
        {255, 20, 147}   /* Deep Pink */
    };
    int pick = GetRandomInt(0, 9);
    r = palette[pick][0];
    g = palette[pick][1];
    b = palette[pick][2];
}

void DispatchCreditNotification(int client, const char[] phraseFormat, any ...)
{
    if (!g_bChatEnabled || !IsValidClient(client))
        return;

    int mode = g_iClientNotifyMode[client];
    if (mode == NOTIFY_DISABLED)
        return;

    SetGlobalTransTarget(client);

    char formatted[256];
    VFormat(formatted, sizeof(formatted), phraseFormat, 3);

    if (mode == NOTIFY_CHAT)
    {
        CPrintToChat(client, "%s", formatted);
    }
    else if (mode == NOTIFY_CONSOLE)
    {
        char plain[256];
        StripColorTags(formatted, plain, sizeof(plain));
        PrintToConsole(client, "[ShopKill] %s", plain);
    }
    else if (mode == NOTIFY_HUD)
    {
        char plain[256];
        StripColorTags(formatted, plain, sizeof(plain));

        /* Random screen position (0.15 to 0.85) to avoid edge clipping */
        float posX = GetRandomFloat(0.15, 0.85);
        float posY = GetRandomFloat(0.15, 0.85);

        int r, g, b, a;
        GetClientHudColor(client, r, g, b, a);

        SetHudTextParams(posX, posY, 2.5, r, g, b, a, 0, 0.2, 0.3, 0.5);
        ShowSyncHudText(client, g_hHudSync, "%s", plain);
    }
}

void ShopKill_GiveCredits(int iClient, int count, int type, int id)
{
    if (!g_bPluginEnabled)
        return;
        
    KeyValues kv = new KeyValues("ShopKill");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/shopkill.cfg");    
    if(kv.ImportFromFile(path))
    {
        kv.Rewind();
        
        float configVIPMultiplier = kv.GetFloat("VIPMultiplier", 2.0);
        
        bool bIsVIP = IsVIP(iClient);
        float fMultiplier = bIsVIP ? configVIPMultiplier : 1.0;
        
        if(type == 2) /* Death penalty */
        {
            int deathPenalty = kv.GetNum("Death", 0);
            if(deathPenalty > 0 && Shop_GetClientCredits(iClient) - deathPenalty >= 0)
            {
                Shop_TakeClientCredits(iClient, deathPenalty);
                DispatchCreditNotification(iClient, "%t", "death", deathPenalty);
            }
        }
        else if(type == 0) /* Headshot */
        {
            int headshotReward = kv.GetNum("HeadShots", 0);
            if(headshotReward > 0)
            {
                count = headshotReward;
                
                int finalReward = RoundFloat(float(count) * fMultiplier);
                
                switch(ShopKill_OnHeadGive(iClient, count))
                {
                    case Plugin_Continue:
                    {
                        Shop_GiveClientCredits(iClient, finalReward);
                    }
                    case Plugin_Changed:
                    {
                        finalReward = RoundFloat(float(count) * fMultiplier);
                        Shop_GiveClientCredits(iClient, finalReward);                       
                    }
                }
                if (bIsVIP && finalReward > count)
                {
                    int bonus = finalReward - count;
                    DispatchCreditNotification(iClient, "%t", "headshot_vip", finalReward, count, bonus);
                }
                else
                {
                    DispatchCreditNotification(iClient, "%t", "headshot", finalReward);
                }
            }
        }
        else if(type == 1) /* Weapon kill */
        {
            if(count > 0)
            {
                char buffer[164];

                if(id > 0){
                    kv.Rewind();
                    IntToString(id, buffer, 25);
                    if(kv.JumpToKey("Weapons")){
                        if(kv.JumpToKey(buffer)){
                            int baseReward = kv.GetNum("count", 1);
                            int finalReward = RoundFloat(float(baseReward) * fMultiplier);
                            
                            switch (ShopKill_OnWepGive(iClient, count))
                            {
                                case Plugin_Continue:
                                {
                                    Shop_GiveClientCredits(iClient, finalReward);
                                    kv.GetString("name", buffer, 164);
                                    if (bIsVIP && finalReward > baseReward)
                                    {
                                        int bonus = finalReward - baseReward;
                                        DispatchCreditNotification(iClient, "%t", "weapon_credits_vip", buffer, finalReward, baseReward, bonus);
                                    }
                                    else
                                    {
                                        DispatchCreditNotification(iClient, "%t", "weapon_credits", buffer, finalReward);
                                    }
                                }
                                case Plugin_Changed:
                                {
                                    finalReward = RoundFloat(float(count) * fMultiplier);
                                    Shop_GiveClientCredits(iClient, finalReward);                       
                                    kv.GetString("name", buffer, 164);
                                    if (bIsVIP && finalReward > count)
                                    {
                                        int bonus = finalReward - count;
                                        DispatchCreditNotification(iClient, "%t", "weapon_credits_vip", buffer, finalReward, count, bonus);
                                    }
                                    else
                                    {
                                        DispatchCreditNotification(iClient, "%t", "weapon_credits", buffer, finalReward);
                                    }
                                }
                            } 
                        }
                    } 
                }else if(id == -1) /* Knife kill */
                {
                    int knifeReward = kv.GetNum("Knife", 10);
                    int finalReward = RoundFloat(float(knifeReward) * fMultiplier);
                    
                    switch(ShopKill_OnWepGive(iClient, count))
                    {
                        case Plugin_Continue:
                        {
                            Shop_GiveClientCredits(iClient, finalReward);
                            if (bIsVIP && finalReward > knifeReward)
                            {
                                int bonus = finalReward - knifeReward;
                                DispatchCreditNotification(iClient, "%t", "knife_vip", finalReward, knifeReward, bonus);
                            }
                            else
                            {
                                DispatchCreditNotification(iClient, "%t", "knife", finalReward);
                            }
                        }
                        case Plugin_Changed:
                        {
                            finalReward = RoundFloat(float(count) * fMultiplier);
                            Shop_GiveClientCredits(iClient, finalReward);                       
                            if (bIsVIP && finalReward > count)
                            {
                                int bonus = finalReward - count;
                                DispatchCreditNotification(iClient, "%t", "knife_vip", finalReward, count, bonus);
                            }
                            else
                            {
                                DispatchCreditNotification(iClient, "%t", "knife", finalReward);
                            }
                        }
                    }                     
                }
            }
        }
    }else{
        PrintToServer("Shopkill config is missing");
    }
    delete kv;
}

bool IsValidClient(int iClient)
{
    if(iClient > 0 &&  iClient <= MaxClients && IsClientInGame(iClient) && !IsFakeClient(iClient))
    {
        return true;
    }
    return false;
}

int GetPlayerInGameCount()
{
    int n = 0;
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsValidClient(i))
        {
            ++n;
        }
    }
    return n;
}

public Action CallBacl_D(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bPluginEnabled)
        return Plugin_Continue;
        
    if(GetConfigMin() != -1 && GetPlayerInGameCount() >= GetConfigMin()){
        int victim = GetClientOfUserId(GetEventInt(event, "userid"));
        int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
        
        if(IsValidClient(victim))
        {
            ShopKill_GiveCredits(victim, 0, 2, 0);
        }
        
        if(IsValidClient(attacker))
        {
            if(GetEventBool(event, "headshot"))
            {
                ShopKill_GiveCredits(attacker, 0, 0, 0);            
            }

            char weapon[75],
                buffer[75];
            GetEventString(event, "weapon", weapon, 75);
            
            KeyValues kv = new KeyValues("ShopKill");
            char path[PLATFORM_MAX_PATH+1];
            BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/shopkill.cfg");    
            
            if(kv.ImportFromFile(path))
            {
                kv.Rewind();
                
                if(StrContains(weapon, "knife", false) != -1 || (StrContains(weapon, "bayonet", false) != -1))
                {
                    ShopKill_GiveCredits(attacker, kv.GetNum("Knife", 10), 1, -1);
                }
                
                if(kv.JumpToKey("Weapons"))
                {
                    if(kv.GotoFirstSubKey())
                    {
                        do
                        {
                            kv.GetString("wep", buffer, 75);
                            if(StrEqual(buffer, weapon, false) || (StrEqual(buffer, "mp5navy", false) && StrEqual(weapon, "mp5", false)))
                            {
                                kv.GetSectionName(buffer, 25);
                                int weaponCount = kv.GetNum("count", 1);
                                ShopKill_GiveCredits(attacker, weaponCount, 1, StringToInt(buffer));   
                                break;
                            }
                        } while (kv.GotoNextKey());	
                    }  
                }                                      
            }
            delete kv;
        }   
    }
    
    return Plugin_Continue;
}

public Action ZR_OnClientInfect(int &client, int &attacker, bool &motherInfect, bool &respawnOverride, bool &respawn)
{
    if (!g_bHasZombieReloaded)
        return Plugin_Continue;
    HandleInfection(client, attacker);
    return Plugin_Continue;
}

void HandleInfection(int client, int attacker)
{
    if (!g_bPluginEnabled)
        return;
        
    if(client != -1 && attacker != -1 && IsValidClient(attacker) && !IsFakeClient(attacker))
    {
        ++Infects[attacker];
        
        KeyValues kv = new KeyValues("ShopKill");
        char path[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/shopkill.cfg");

        if(kv.ImportFromFile(path))
        {
            int infectionCredits = kv.GetNum("Infection", 1);
            float configVIPMultiplier = kv.GetFloat("VIPMultiplier", 2.0);
            
            bool bIsVIP = IsVIP(attacker);
            float fMultiplier = bIsVIP ? configVIPMultiplier : 1.0;
            
            int finalCredits = RoundFloat(float(infectionCredits) * fMultiplier);

            if(finalCredits > 0)
            {
                Shop_GiveClientCredits(attacker, finalCredits);

                char victimName[64];
                GetClientName(client, victimName, sizeof(victimName));

                if (bIsVIP && finalCredits > infectionCredits)
                {
                    int bonus = finalCredits - infectionCredits;
                    DispatchCreditNotification(attacker, "%t", "infection_vip", finalCredits, victimName, infectionCredits, bonus);
                }
                else
                {
                    DispatchCreditNotification(attacker, "%t", "infection", finalCredits, victimName);
                }
            }
        }
        delete kv;
    }
}
