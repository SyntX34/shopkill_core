#include <sourcemod>
#include <shop>
#include <zombiereloaded>
#include <multicolors>

#pragma tabsize 0

#define Head 0
#define Wep 1
#define Death 2

Handle shopkill_wep;
Handle shopkill_head;
int	Infects[MAXPLAYERS+1];

int chat = 0;

public Plugin myinfo =
{
    name            = "[Shop] Give Credits on Actions",
    author          = "+SyntX",
    description     = "Give credits to players for killing,infecting other players",
    version         = "1.2",
    url             = "https://steamcommunity.com/id/syntx34 && https://github.com/id/syntx34"
};

public void OnPluginStart()
{
    HookEvent("player_death", CallBacl_D, EventHookMode_Post);
    LoadTranslations("shopkill_css.txt");
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

void ShopKill_GiveCredits(int iClient, int count, int type, int id)
{
    KeyValues kv = new KeyValues("ShopKill");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/shopkill.cfg");    
    if(kv.ImportFromFile(path))
    {
        kv.Rewind();
        chat = kv.GetNum("Chat");    
        if(type == 2)
        {
            if(kv.GetNum("Death") > 0 && Shop_GetClientCredits(iClient) - kv.GetNum("Death") >= 0)
            {
                Shop_TakeClientCredits(iClient, kv.GetNum("Death"));
                if(chat == 1)
                {
                    CPrintToChat(iClient, "%t", "death", kv.GetNum("Death"));
                }
            }
        }
        if(type == 0)
        {
            if(kv.GetNum("HeadShots") > 0)
            {
                count = kv.GetNum("HeadShots"); 
                switch(ShopKill_OnHeadGive(iClient, count))
                {
                    case Plugin_Continue:
                    {
                        Shop_GiveClientCredits(iClient, kv.GetNum("HeadShots"));
                    }
                    case Plugin_Changed:
                    {
                        Shop_GiveClientCredits(iClient, count);                       
                    }
                }
                if(chat == 1)
                {
                    CPrintToChat(iClient, "%t", "headshot", count);
                }                
            }
        }
        if(type == 1)
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
                            switch (ShopKill_OnWepGive(iClient, count))
                            {
                                case Plugin_Continue:
                                {
                                    Shop_GiveClientCredits(iClient, def);
                                    if(chat == 1)
                                    {
                                        kv.GetString("name", buffer, 164);
                                        CPrintToChat(iClient, "%t", "weapon_credits", buffer, def);
                                    }
                                }
                                case Plugin_Changed:
                                {
                                    Shop_GiveClientCredits(iClient, count);                       
                                    if(chat == 1)
                                    {
                                        kv.GetString("name", buffer, 164);
                                        CPrintToChat(iClient, "%t", "weapon_credits", buffer, count);
                                    }                    
                                }
                            } 
                        }
                    } 
                }else if(id == -1)
                {
                    switch(ShopKill_OnWepGive(iClient, count))
                    {
                        case Plugin_Continue:
                        {
                            Shop_GiveClientCredits(iClient, def);
                            if(chat == 1)
                            {
                                CPrintToChat(iClient, "%t", "knife", def);
                            }
                        }
                        case Plugin_Changed:
                        {
                            Shop_GiveClientCredits(iClient, count);                       
                            if(chat == 1)
                            {
                               CPrintToChat(iClient, "%t", "knife", count);
                            }                    
                        }
                    }                     
                }
            }
        }
    }else{
        PrintToServer("Shopkill config is missing")
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
                    ShopKill_GiveCredits(attacker, kv.GetNum("KKnife"), 1, -1);
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
                                ShopKill_GiveCredits(attacker, kv.GetNum("count"), 1, StringToInt(buffer));   
                                break;
                            }
                        }while (kv.GotoNextKey());	
                    }  
                }                                      
            }
            delete kv;
        }   
    }
    
}

public Action ZR_OnClientInfect(int &client, int &attacker, bool &motherInfect, bool &respawnOverride, bool &respawn)
{
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
                int infectionCredits = kv.GetNum("Infection"); 
                int chat = kv.GetNum("Chat");

                if(infectionCredits > 0)
                {
                    Shop_GiveClientCredits(attacker, infectionCredits);

                    if(chat == 1)
                    {
                        char attackerName[64];
                        char victimName[64];
                        GetClientName(attacker, attackerName, sizeof(attackerName));
                        GetClientName(client, victimName, sizeof(victimName));

                        CPrintToChat(attacker, "%t", "infection", infectionCredits, victimName);
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

