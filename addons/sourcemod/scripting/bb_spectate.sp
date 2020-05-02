#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <multicolors>
#include <emitsoundany>
#include <basebuilder>
#include <basebuilder_spectate>

#define PLUGIN_NAME BB_PLUGIN_NAME ... " - Zombie spectating"

Handle g_hTimer = null;

ConVar g_cvHideZombiesWhileCloseToEachOthers;
ConVar g_cvZombieHideDistance;
ConVar g_cvHidePartyTeammatesWhileCloseToEachOthers;
ConVar g_cvPartyTeammateHideDistance;
ConVar g_cvHideZombieWhileSpectating;

enum struct PlayerData 
{
    int iDistance[MAXPLAYERS + 1];

    bool bIsSpectating;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = BB_PLUGIN_AUTHOR,
    description = BB_PLUGIN_DESCRIPTION,
    version = BB_PLUGIN_VERSION,
    url = BB_PLUGIN_URL
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("BB_IsZombieSpectating", Native_IsZombieSpectating);
    CreateNative("BB_SetZombieSpectating", Native_SetZombieSpectating);

    RegPluginLibrary("basebuilder_basetesting");

    return APLRes_Success;
}

public int Native_IsZombieSpectating(Handle plugin, int numParams)
{
	return g_iPlayer[GetNativeCell(1)].bIsSpectating;
}

public int Native_SetZombieSpectating(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (view_as<bool>(GetNativeCell(2)))
    {
        g_iPlayer[client].bIsSpectating = true;
        BB_TeleportToBuilders(client);
        //BB_SetPlayerVisibilityOnHud(client, false);
        CPrintToChat(client, "Now you are testing Builders bases!");
    }
    else
    {
        g_iPlayer[client].bIsSpectating = false;
        BB_TeleportToZombies(client);
        //BB_SetPlayerVisibilityOnHud(client, true);
        CPrintToChat(client, "You went back home!");
    }
}

public void OnPluginStart()
{
    BB_IsGameCSGO();

    g_cvHideZombiesWhileCloseToEachOthers = CreateConVar("bb_hide_zombie_while_close_to_each_others", "1", "Turn on/off hiding zombies whose is close to each others.");
    g_cvZombieHideDistance = CreateConVar("bb_zombie_hide_distance", "9000", "Sets a distance wherein zombies are not visible for each others.");
    g_cvHidePartyTeammatesWhileCloseToEachOthers = CreateConVar("bb_hide_party_teammates_while_close_to_each_others", "1", "Turn on/off hiding party teammates whose is close to each others.");
    g_cvPartyTeammateHideDistance = CreateConVar("bb_party_teammate_hide_distance", "9000", "Sets a distance wherein party teammates are not visible for each others.");
    g_cvHideZombieWhileSpectating = CreateConVar("bb_hide_spectating_zombie", "1", "Turn on/off hiding zombies which are spectating.");
    
    RegConsoleCmd("sm_spectate", Command_ZombieSpectate);

    LoopValidClients(i)
    {
        OnClientPutInServer(i);
    }
}

public void OnMapStart()
{
    BB_ClearTimer(g_hTimer);
}

public void OnMapEnd()
{
    BB_ClearTimer(g_hTimer);
}

public void OnClientPutInServer(int client)
{
    g_iPlayer[client].bIsSpectating = false;

    LoopValidClients(i)
    {
        g_iPlayer[client].iDistance[i] = 10000;
    }

    SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
}

public Action Command_ZombieSpectate(int client, int args)
{
    if (!BB_IsClientValid(client))
    {
		return Plugin_Handled;
    }

    if (GetClientTeam(client) != TEAM_ZOMBIES)
    {
        CPrintToChat(client, "Only zombies can use this command!");
        return Plugin_Handled;
    }

    if (BB_GetRoundStatus() != Round_Building)
    {
        CPrintToChat(client, "This command can be used only while building phase!");
        return Plugin_Handled;
    }

    BB_SetZombieSpectating(client, !g_iPlayer[client].bIsSpectating);
    return Plugin_Handled;
}

public void BB_OnPrepStart() 
{
    LoopValidClients(i)
    {
        if (g_iPlayer[i].bIsSpectating)
        {
            g_iPlayer[i].bIsSpectating = false;
            BB_TeleportToZombies(i);
        }
    }

    g_hTimer = CreateTimer(0.25, Timer_CheckPlayersDistances, _, TIMER_REPEAT);
}

public void BB_OnRoundEnd(int winner)
{
    BB_ClearTimer(g_hTimer);

    LoopValidClients(i)
    {
        LoopValidClients(j)
        {
            g_iPlayer[i].iDistance[j] = 10000;
        }
    }
}

public Action Timer_CheckPlayersDistances(Handle timer)
{
    float fPlayer[3], fTarget[3];
    LoopValidClients(i)
    {
        GetEntPropVector(i, Prop_Data, "m_vecOrigin", fPlayer);

        LoopValidClients(j)
        {
            GetEntPropVector(j, Prop_Data, "m_vecOrigin", fTarget);
            g_iPlayer[i].iDistance[j] = RoundToZero(GetVectorDistance(fPlayer, fTarget, true));
        }
    }
}

public Action Hook_SetTransmit(int entity, int client)
{
    if (!BB_IsClientValid(client) || !BB_IsClientValid(entity) || client == entity)
    {
        return Plugin_Continue;
    }

    if (IsPlayerAlive(client) && IsPlayerAlive(entity) && GetClientTeam(entity) == TEAM_ZOMBIES && GetClientTeam(client) == TEAM_ZOMBIES && g_cvHideZombiesWhileCloseToEachOthers.BoolValue && g_iPlayer[client].iDistance[entity] <= g_cvZombieHideDistance.IntValue)
    {
        return Plugin_Handled;
    }

    if (IsPlayerAlive(client) && IsPlayerAlive(entity) && GetClientTeam(entity) == TEAM_BUILDERS && GetClientTeam(client) == TEAM_BUILDERS && BB_IsClientInParty(client) && BB_GetClientPartyPerson(client) == entity && g_cvHidePartyTeammatesWhileCloseToEachOthers.BoolValue && g_iPlayer[client].iDistance[entity] <= g_cvPartyTeammateHideDistance.IntValue && BB_GetRoundStatus() == Round_Preparation)
    {
        return Plugin_Handled;
    }

    if (!g_iPlayer[entity].bIsSpectating || GetClientTeam(client) == CS_TEAM_T)
    {
        return Plugin_Continue;
    }

    if (IsPlayerAlive(client) && g_iPlayer[entity].bIsSpectating && g_cvHideZombieWhileSpectating.BoolValue) 
    {
        return Plugin_Handled;
    }   

    return Plugin_Continue;
}
