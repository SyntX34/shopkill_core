#include <sourcemod>
#include <shop>
#include <zombiereloaded>
#include <multicolors>
#include <clientprefs>
#include <vip_core>

#pragma tabsize 0

#define Head 0
#define Wep 1
#define Death 2

Handle shopkill_wep;
Handle shopkill_head;
int	Infects[MAXPLAYERS+1];

ConVar g_cvPluginEnabled;
ConVar g_cvChatEnabled;
ConVar g_cvVIPMultiplier;
bool g_bPluginEnabled;
bool g_bChatEnabled;
float g_fVIPMultiplier;

bool g_bHasVIPCore = false;
Handle g_hChatCookie;
bool g_bClientChatEnabled[MAXPLAYERS+1] = {true, ...};

public Plugin myinfo =
{
    name            = "[Shop] Give Credits on Actions with VIP Support",
    author          = "[shopkill] by +SyntX",
    description     = "Give credits to players for killing,infecting other players with VIP multiplier",
    version         = "1.5",
    url             = "https://steamcommunity.com/id/syntx34"
};

public void OnPluginStart()
{
    g_cvPluginEnabled = CreateConVar("sm_shopkill_enabled", "1", "Enable/disable the ShopKill plugin (1 = enable, 0 = disable)", _, true, 0.0, true, 1.0);
    g_cvChatEnabled = CreateConVar("sm_shopkill_chat", "0", "Enable/disable chat messages globally (1 = enable, 0 = disable)", _, true, 0.0, true, 1.0);
    g_cvVIPMultiplier = CreateConVar("sm_shopkill_vip_multiplier", "2.0", "Multiplier for VIP players (applied to all rewards)", _, true, 1.0, true, 10.0);
    
    g_cvPluginEnabled.AddChangeHook(OnConVarChanged);
    g_cvChatEnabled.AddChangeHook(OnConVarChanged);
    g_cvVIPMultiplier.AddChangeHook(OnConVarChanged);
    
    g_bPluginEnabled = g_cvPluginEnabled.BoolValue;
    g_bChatEnabled = g_cvChatEnabled.BoolValue;
    g_fVIPMultiplier = g_cvVIPMultiplier.FloatValue;
    
    g_hChatCookie = RegClientCookie("shopkill_chat", "ShopKill Chat Preferences", CookieAccess_Private);
    
    HookEvent("player_death", CallBacl_D, EventHookMode_Post);
    LoadTranslations("shopkill_css.txt");
    
    RegConsoleCmd("sm_shopkillchat", Command_ChatToggle, "Toggle ShopKill chat messages");
    RegConsoleCmd("sm_skchat", Command_ChatToggle, "Toggle ShopKill chat messages");
    RegConsoleCmd("sm_shopkillprefs", Command_ShowPreferences, "Show ShopKill preferences");

    AutoExecConfig(true);
}

public Action Command_ChatToggle(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;
    
    g_bClientChatEnabled[client] = !g_bClientChatEnabled[client];
    
    char sValue[8];
    IntToString(g_bClientChatEnabled[client] ? 1 : 0, sValue, sizeof(sValue));
    SetClientCookie(client, g_hChatCookie, sValue);
    
    CPrintToChat(client, "{green}[ShopKill]{default} Chat messages are now {lightgreen}%s{default} for you.", 
        g_bClientChatEnabled[client] ? "enabled" : "disabled");
    
    return Plugin_Handled;
}

public Action Command_ShowPreferences(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;
    
    bool bIsVIP = IsVIP(client);
    float fMultiplier = bIsVIP ? GetConfigVIPMultiplier() : 1.0;
    
    CPrintToChat(client, "{green}[ShopKill]{default} Current preferences:");
    CPrintToChat(client, "{green}[ShopKill]{default} • Chat messages: {lightgreen}%s{default} (%s)", 
        g_bClientChatEnabled[client] ? "Enabled" : "Disabled",
        g_bChatEnabled ? "Global setting allows" : "Globally disabled");
    CPrintToChat(client, "{green}[ShopKill]{default} • VIP status: {lightgreen}%s{default}", 
        bIsVIP ? "Yes" : "No");
    
    if (bIsVIP)
    {
        CPrintToChat(client, "{green}[ShopKill]{default} • VIP multiplier: {lightgreen}%.1fx{default}", fMultiplier);
    }
    
    CPrintToChat(client, "{green}[ShopKill]{default} Use {lightgreen}!skchat{default} to toggle chat messages.");
    
    return Plugin_Handled;
}

public void OnClientCookiesCached(int client)
{
    if (!IsValidClient(client))
        return;
    
    char sValue[8];
    GetClientCookie(client, g_hChatCookie, sValue, sizeof(sValue));
    
    if (sValue[0] != '\0')
    {
        g_bClientChatEnabled[client] = (StringToInt(sValue) == 1);
    }
    else
    {
        g_bClientChatEnabled[client] = true;
        IntToString(1, sValue, sizeof(sValue));
        SetClientCookie(client, g_hChatCookie, sValue);
    }
}

public void OnClientDisconnect(int client)
{
    g_bClientChatEnabled[client] = true;
}

public void OnAllPluginsLoaded()
{
    g_bHasVIPCore = LibraryExists("vip_core");
    if (g_bHasVIPCore)
    {
        PrintToServer("[ShopKill] VIP Core detected. VIP multiplier will be applied.");
    }
    else
    {
        PrintToServer("[ShopKill] VIP Core not found. Using config value for VIP multiplier.");
    }
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "vip_core"))
    {
        g_bHasVIPCore = true;
        PrintToServer("[ShopKill] VIP Core loaded.");
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "vip_core"))
    {
        g_bHasVIPCore = false;
        PrintToServer("[ShopKill] VIP Core unloaded.");
    }
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
        g_fVIPMultiplier = convar.FloatValue;
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
    if (!g_bHasVIPCore)
    {
        return false;
    }
    
    char feature[64] = "VIPFeatures";
    return VIP_IsClientVIP(client) && VIP_IsClientFeatureUse(client, feature);
}

bool ShouldShowChat(int client)
{
    if (!g_bChatEnabled)
        return false;
    return g_bClientChatEnabled[client];
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
        
        bool bShowChat = ShouldShowChat(iClient);
        
        if(type == 2) // Death penalty
        {
            int deathPenalty = kv.GetNum("Death", 0);
            if(deathPenalty > 0 && Shop_GetClientCredits(iClient) - deathPenalty >= 0)
            {
                Shop_TakeClientCredits(iClient, deathPenalty);
                if(bShowChat)
                {
                    CPrintToChat(iClient, "%t", "death", deathPenalty);
                }
            }
        }
        else if(type == 0) // Headshot
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
                if(bShowChat)
                {
                    if (bIsVIP && finalReward != count)
                    {
                        CPrintToChat(iClient, "%t", "headshot_vip", finalReward, count, fMultiplier);
                    }
                    else
                    {
                        CPrintToChat(iClient, "%t", "headshot", finalReward);
                    }
                }                
            }
        }
        else if(type == 1) // Weapon kill
        {
            int def = count;            
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
                                    if(bShowChat)
                                    {
                                        kv.GetString("name", buffer, 164);
                                        if (bIsVIP && finalReward != baseReward)
                                        {
                                            CPrintToChat(iClient, "%t", "weapon_credits_vip", buffer, finalReward, baseReward, fMultiplier);
                                        }
                                        else
                                        {
                                            CPrintToChat(iClient, "%t", "weapon_credits", buffer, finalReward);
                                        }
                                    }
                                }
                                case Plugin_Changed:
                                {
                                    finalReward = RoundFloat(float(count) * fMultiplier);
                                    Shop_GiveClientCredits(iClient, finalReward);                       
                                    if(bShowChat)
                                    {
                                        kv.GetString("name", buffer, 164);
                                        if (bIsVIP && finalReward != count)
                                        {
                                            CPrintToChat(iClient, "%t", "weapon_credits_vip", buffer, finalReward, count, fMultiplier);
                                        }
                                        else
                                        {
                                            CPrintToChat(iClient, "%t", "weapon_credits", buffer, finalReward);
                                        }
                                    }                    
                                }
                            } 
                        }
                    } 
                }else if(id == -1) // Knife kill
                {
                    int knifeReward = kv.GetNum("Knife", 10);
                    int finalReward = RoundFloat(float(knifeReward) * fMultiplier);
                    
                    switch(ShopKill_OnWepGive(iClient, count))
                    {
                        case Plugin_Continue:
                        {
                            Shop_GiveClientCredits(iClient, finalReward);
                            if(bShowChat)
                            {
                                if (bIsVIP && finalReward != knifeReward)
                                {
                                    CPrintToChat(iClient, "%t", "knife_vip", finalReward, knifeReward, fMultiplier);
                                }
                                else
                                {
                                    CPrintToChat(iClient, "%t", "knife", finalReward);
                                }
                            }
                        }
                        case Plugin_Changed:
                        {
                            finalReward = RoundFloat(float(count) * fMultiplier);
                            Shop_GiveClientCredits(iClient, finalReward);                       
                            if(bShowChat)
                            {
                                if (bIsVIP && finalReward != count)
                                {
                                    CPrintToChat(iClient, "%t", "knife_vip", finalReward, count, fMultiplier);
                                }
                                else
                                {
                                    CPrintToChat(iClient, "%t", "knife", finalReward);
                                }
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
                            if(StrEqual(buffer, weapon))
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
    if (!g_bPluginEnabled)
        return Plugin_Continue;
        
    if(client != -1 && attacker != -1)
    {
        if (!IsFakeClient(attacker))
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
                
                bool bShowChat = ShouldShowChat(attacker);

                if(finalCredits > 0)
                {
                    Shop_GiveClientCredits(attacker, finalCredits);

                    if(bShowChat)
                    {
                        char attackerName[64];
                        char victimName[64];
                        GetClientName(attacker, attackerName, sizeof(attackerName));
                        GetClientName(client, victimName, sizeof(victimName));

                        if (bIsVIP && finalCredits != infectionCredits)
                        {
                            CPrintToChat(attacker, "%t", "infection_vip", finalCredits, victimName, infectionCredits, fMultiplier);
                        }
                        else
                        {
                            CPrintToChat(attacker, "%t", "infection", finalCredits, victimName);
                        }
                    }
                }
            }
            else
            {
                PrintToServer("Shopkill config is missing");
            }

            delete kv;
        }
        else
        {
            PrintToServer("Credits not given for infecting by bot.");
        }
    }
    
    return Plugin_Continue;
}