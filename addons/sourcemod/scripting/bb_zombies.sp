#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
// #include <EverGames>
#include <clientprefs>
#include <multicolors>
#include <basebuilder>
#include <basebuilder_zombies>

#define PLUGIN_NAME BB_PLUGIN_NAME ... " - Zombie"

Cookie g_coZombie = null;

KeyValues g_kvZombies;

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

ConVar g_cGravityTimerInterval;
Handle g_hGravityTimer;

char g_sZombiesFile[PLATFORM_MAX_PATH + 1];

int g_iZombieClass[MAXPLAYERS + 1] = { 0, ... };

enum struct Zombie
{
    int iID;
    int iHealth;

    float fGravity;
    float fSpeed;

    char sFlags[21];

    char sID[8];
    char sName[MAX_NAME_LENGTH];
    char sModel[PLATFORM_MAX_PATH + 1];
}

enum struct PlayerData 
{
    float fSpeed;
    float fGravity;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

ArrayList g_aZombie = null;

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = BB_PLUGIN_AUTHOR,
    description = BB_PLUGIN_DESCRIPTION,
    version = BB_PLUGIN_VERSION,
    url = BB_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("BB_GetClientSpeed", Native_GetClientSpeed);
    CreateNative("BB_AddClientSpeed", Native_AddClientSpeed);
    CreateNative("BB_SetClientSpeed", Native_SetClientSpeed);

    CreateNative("BB_GetClientGravity", Native_GetClientGravity);
    CreateNative("BB_SubClientGravity", Native_SubClientGravity);
    CreateNative("BB_AddClientGravity", Native_AddClientGravity);
    CreateNative("BB_SetClientGravity", Native_SetClientGravity);

    RegPluginLibrary("basebuilder_zombies");

    return APLRes_Success;
}

public void OnPluginStart()
{
    BB_IsGameCSGO();
    BB_LoadTranslations();

    BB_StartConfig("zombies");
    CreateConVar("bb_zombies_version", BB_PLUGIN_VERSION, BB_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cGravityTimerInterval = AutoExecConfig_CreateConVar("bb_gravity_timer_intervar", "0.1", "Set interval for timer setting up clients gravity.", _, true, 0.1, true, 10.0);
    g_cGravityTimerInterval.AddChangeHook(OnConVarChanged);
    BB_EndConfig();

    g_aZombie = new ArrayList(sizeof(Zombie));

    RegConsoleCmd("sm_zombie", Command_ZombieClass);
    RegConsoleCmd("sm_zombies", Command_ZombieClass);
    RegConsoleCmd("sm_class", Command_ZombieClass);
    RegConsoleCmd("sm_klasa", Command_ZombieClass);

    HookEvent("player_spawn", Event_OnRoundStart, EventHookMode_Pre);

    g_coZombie = new Cookie("bb_zombie_class", "Player Zombie Class", CookieAccess_Private);

    BuildPath(Path_SM, g_sZombiesFile, sizeof(g_sZombiesFile), "configs/basebuilder/zombie_classes.ini");

    g_hGravityTimer = CreateTimer(g_cGravityTimerInterval.FloatValue, Timer_SetClientsGravity, _, TIMER_REPEAT);
}

public void OnConfigsExecuted()
{
    g_cPluginTag = FindConVar("bb_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));

    Handle hFile = OpenFile(g_sZombiesFile, "rt");

    if (hFile == null)
    {
        SetFailState("[BB] Can't open File: %s", g_sZombiesFile);
    }

    g_kvZombies = new KeyValues("Zombie-Classes");

    if (!g_kvZombies.ImportFromFile(g_sZombiesFile))
    {
        SetFailState("Can't read %s correctly! (ImportFromFile)", g_sZombiesFile);
        delete hFile;
        return;
    }

    if (!g_kvZombies.GotoFirstSubKey())
    {
        SetFailState("Can't read %s correctly! (GotoFirstSubKey)", g_sZombiesFile);
        delete hFile;
        return;
    }

    if (g_aZombie != null)
    {
        g_aZombie.Clear();
    }

    do
    {
        Zombie zombie;
        char sID[8], sName[MAX_NAME_LENGTH], sGravity[16], sSpeed[16], sHealth[16], sModel[PLATFORM_MAX_PATH + 1], sFlags[21];

        g_kvZombies.GetSectionName(sID, sizeof(sID));
        g_kvZombies.GetString("name", sName, sizeof(sName));
        g_kvZombies.GetString("gravity", sGravity, sizeof(sGravity));
        g_kvZombies.GetString("speed", sSpeed, sizeof(sSpeed));
        g_kvZombies.GetString("health", sHealth, sizeof(sHealth));
        g_kvZombies.GetString("model_path", sModel, sizeof(sModel));
        g_kvZombies.GetString("flags", sFlags, sizeof(sFlags));

        zombie.iID = StringToInt(sID);
        zombie.iHealth = StringToInt(sHealth);

        zombie.fGravity = StringToFloat(sGravity);
        zombie.fSpeed = StringToFloat(sSpeed);

        strcopy(zombie.sFlags, 21, sFlags);

        strcopy(zombie.sID, 8, sID);
        strcopy(zombie.sName, MAX_NAME_LENGTH, sName);
        strcopy(zombie.sModel, PLATFORM_MAX_PATH + 1, sModel);

        g_aZombie.PushArray(zombie, sizeof(zombie));
    } while (g_kvZombies.GotoNextKey());

    delete hFile;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
    else if (convar == g_cGravityTimerInterval)
    {
        delete g_hGravityTimer;
        g_hGravityTimer = CreateTimer(g_cGravityTimerInterval.FloatValue, Timer_SetClientsGravity, _, TIMER_REPEAT);
    }
}

public void OnMapStart()
{
    PrecacheModel("models/weapons/t_arms_professional.mdl");

    Zombie zombie;

    for (int i = 0; i < g_aZombie.Length; i++)
    {
        g_aZombie.GetArray(i, zombie, sizeof(zombie));

        if (strlen(zombie.sModel) > 0)
        {
            PrecacheModel(zombie.sModel);
        }
            
    }
}

public void OnClientPutInServer(int client)
{
    g_iPlayer[client].fSpeed = 1.0;
    g_iPlayer[client].fGravity = 1.0;
    OnClientCookiesCached(client);
}

public void OnClientCookiesCached(int client)
{
    char sBuffer[12];
    g_coZombie.Get(client, sBuffer, sizeof(sBuffer));
    g_iZombieClass[client] = StringToInt(sBuffer);
}

public Action Command_ZombieClass(int client, int args)
{
    if (!BB_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    Menu menu = new Menu(MenuHandlers_ZombieClass);
    menu.SetTitle("EverGames.pl » Wybierz klasę zombie");

    Zombie zombie;

    for(int i = 0; i < g_aZombie.Length; i++)
    {
        g_aZombie.GetArray(i, zombie, sizeof(zombie));

        menu.AddItem(zombie.sID, zombie.sName, g_iZombieClass[client] == zombie.iID ? ITEMDRAW_DISABLED : (strlen(zombie.sFlags) > 0 && !HasPlayerFlags(client, zombie.sFlags) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT));
    }

    menu.ExitButton = true;
    menu.Display(client, 0);
    return Plugin_Handled;
}

public int MenuHandlers_ZombieClass(Menu menu, MenuAction action, int client, int item) 
{
	if (action == MenuAction_Select)
    {
        char sInfo[32];
        GetMenuItem(menu, item, sInfo, sizeof(sInfo));

        g_iZombieClass[client] = StringToInt(sInfo);

        if (GetClientTeam(client) == TEAM_BUILDERS)
        {
            CPrintToChat(client, "%s Klasa zombie została zaktualizowana!", g_sPluginTag);
            return;
        }

        if (BB_GetRoundStatus() == Round_Active)
        {
            CPrintToChat(client, "%s Klasa zombie zostanie zmieniona po śmierci!", g_sPluginTag);
            return;
        }

        CS_RespawnPlayer(client);
    }
}

public Action Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!BB_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if(GetClientTeam(client) == TEAM_BUILDERS)
    {
        BB_SetClientSpeed(client, 1.0);
        BB_SetClientHealth(client, 100);
        BB_SetClientGravity(client, 1.0);
    }
    else
    {
        Zombie zombie;

        for (int i = 0; i < g_aZombie.Length; i++)
        {
            g_aZombie.GetArray(i, zombie, sizeof(zombie));

            if (zombie.iID == g_iZombieClass[client])
            {
                // if (zombie.bVIP && EG_GetUserRang(client) == 0)
                // {
                //     g_coZombie.Set(client, "0");
                //     g_iZombieClass[client] = 0;
                //     CS_RespawnPlayer(client);
                //     break;
                // }

                BB_SetClientSpeed(client, zombie.fSpeed);
                BB_SetClientHealth(client, zombie.iHealth);
                BB_SetClientGravity(client, zombie.fGravity);

                if (!IsModelPrecached(zombie.sModel))
                {
                    PrecacheModel(zombie.sModel);
                }

                SetEntityModel(client, zombie.sModel);

                CPrintToChat(client, "%s Aktualnie grasz klasą o nazwie \x07%s\x01!", g_sPluginTag, zombie.sName);
                break;
            }
        }
    }

    return Plugin_Handled;
}

public Action Timer_SetClientsGravity(Handle timer)
{
    LoopValidClients(client)
    {
        SetEntityGravity(client, g_iPlayer[client].fGravity);
    }
}

public int Native_GetClientSpeed(Handle plugin, int numParams)
{
    return view_as<int>(g_iPlayer[GetNativeCell(1)].fSpeed);
}

public int Native_AddClientSpeed(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    g_iPlayer[client].fSpeed += view_as<float>(GetNativeCell(2));

    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_iPlayer[client].fSpeed);

    return view_as<int>(g_iPlayer[client].fSpeed);
}

public int Native_SetClientSpeed(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    g_iPlayer[client].fSpeed = view_as<float>(GetNativeCell(2));

    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_iPlayer[client].fSpeed);

    return view_as<int>(g_iPlayer[client].fSpeed);
}

public int Native_GetClientGravity(Handle plugin, int numParams)
{
    return view_as<int>(g_iPlayer[GetNativeCell(1)].fGravity);
}

public int Native_AddClientGravity(Handle plugin, int numParams)
{
    return view_as<int>(g_iPlayer[GetNativeCell(1)].fGravity += view_as<float>(GetNativeCell(2)));
}

public int Native_SubClientGravity(Handle plugin, int numParams)
{
    return view_as<int>(g_iPlayer[GetNativeCell(1)].fGravity -= view_as<float>(GetNativeCell(2)));
}

public int Native_SetClientGravity(Handle plugin, int numParams)
{
    return view_as<int>(g_iPlayer[GetNativeCell(1)].fGravity = view_as<float>(GetNativeCell(2)));
}

public bool HasPlayerFlags(int client, char flags[21])
{
	
	if (StrContains(flags, "a") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_RESERVATION))
		{
			return true;
		}
	}		
	else if (StrContains(flags, "b") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_GENERIC))
		{
			return true;
		}
	}
	else if (StrContains(flags, "c") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_KICK))
		{
			return true;
		}
	}
	else if (StrContains(flags, "d") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_BAN))
		{
			return true;
		}
	}
	else if (StrContains(flags, "e") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_UNBAN))
		{
			return true;
		}
	}	
	else if (StrContains(flags, "f") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_SLAY))
		{
			return true;
		}
	}	
	else if (StrContains(flags, "g") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_CHANGEMAP))
		{
			return true;
		}
	}
	else if (StrContains(flags, "h") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", 128))
		{
			return true;
		}
	}		
	else if (StrContains(flags, "i") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_CONFIG))
		{
			return true;
		}
	}
	else if (StrContains(flags, "j") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_CHAT))
		{
			return true;
		}
	}		
	else if (StrContains(flags, "k") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_VOTE))
		{
			return true;
		}
	}	
	else if (StrContains(flags, "l") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_PASSWORD))
		{
			return true;
		}
	}
	else if (StrContains(flags, "m") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_RCON))
		{
			return true;
		}
	}		
	else if (StrContains(flags, "n") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_CHEATS))
		{
			return true;
		}
	}		
	else if (StrContains(flags, "z") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_ROOT))
		{
			return true;
		}
	}		
	else if (StrContains(flags, "o") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_CUSTOM1))
		{
			return true;
		}
	}		
	else if (StrContains(flags, "p") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_CUSTOM2))
		{
			return true;
		}
	}
	else if (StrContains(flags, "q") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_CUSTOM3))
		{
			return true;
		}
	}		
	else if (StrContains(flags, "r") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_CUSTOM4))
		{
			return true;
		}
	}			
	else if (StrContains(flags, "s") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_CUSTOM5))
		{
			return true;
		}
	}			
	else if (StrContains(flags, "t") != -1)
	{
		if (CheckCommandAccess(client, "bb_use_zombie_class", ADMFLAG_CUSTOM6))
		{
			return true;
		}
	}
	
	return false;
}
