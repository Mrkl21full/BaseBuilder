#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <multicolors>
#include <emitsoundany>
#include <basebuilder>

#define PLUGIN_NAME BB_PLUGIN_NAME ... " - Base testing"

Handle g_hTimer = null;

enum struct PlayerData 
{
    int iDistance[MAXPLAYERS + 1];

    bool bIsTesting;
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
    CreateNative("BB_IsClientTesting", Native_IsClientTesting);
    CreateNative("BB_SetClientTesting", Native_SetClientTesting);

    RegPluginLibrary("basebuilder_basetesting");

    return APLRes_Success;
}

public int Native_IsClientTesting(Handle plugin, int numParams)
{
	return g_iPlayer[GetNativeCell(1)].bIsTesting;
}

public int Native_SetClientTesting(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (view_as<bool>(GetNativeCell(2)))
    {
        g_iPlayer[client].bIsTesting = true;
        BB_TeleportToBuilders(client);
        //BB_SetPlayerVisibilityOnHud(client, false);
        CPrintToChat(client, "Now you are testing Builders bases!");
    }
    else
    {
        g_iPlayer[client].bIsTesting = false;
        BB_TeleportToZombies(client);
        //BB_SetPlayerVisibilityOnHud(client, true);
        CPrintToChat(client, "You went back home!");
    }
}

public void OnPluginStart()
{
    BB_IsGameCSGO();

    RegConsoleCmd("sm_basetesting", Command_BaseTesting);

    LoopValidClients(i)
        OnClientPutInServer(i);
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
    g_iPlayer[client].bIsTesting = false;

    LoopValidClients(i)
        g_iPlayer[client].iDistance[i] = 10000;

    SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
}

public Action Command_BaseTesting(int client, int args)
{
    if (!BB_IsClientValid(client))
		return Plugin_Handled;

    if (GetClientTeam(client) != TEAM_ZOMBIES) {
        CPrintToChat(client, "Only zombies can use this command!");
        return Plugin_Handled;
    }

    if (BB_GetRoundStatus() != Round_Building) {
        CPrintToChat(client, "This command can be used only while building phase!");
        return Plugin_Handled;
    }

    BB_SetClientTesting(client, !g_iPlayer[client].bIsTesting);
    return Plugin_Handled;
}

public void BB_OnPrepStart() 
{
    LoopValidClients(i) {
        if (g_iPlayer[i].bIsTesting) {
            g_iPlayer[i].bIsTesting = false;
            BB_TeleportToZombies(i);
        }
    }

    g_hTimer = CreateTimer(0.25, Timer_CheckPlayersDistances, _, TIMER_REPEAT);
}

public void BB_OnRoundEnd(int winner)
{
    BB_ClearTimer(g_hTimer);

    LoopValidClients(i){
        LoopValidClients(j) {
            g_iPlayer[i].iDistance[j] = 10000;
        }
    }
}

public Action Timer_CheckPlayersDistances(Handle timer)
{
    float fPlayer[3], fTarget[3];
    LoopValidClients(i) {
        GetEntPropVector(i, Prop_Data, "m_vecOrigin", fPlayer);

        LoopValidClients(j) {
            GetEntPropVector(j, Prop_Data, "m_vecOrigin", fTarget);
            g_iPlayer[i].iDistance[j] = RoundToZero(GetVectorDistance(fPlayer, fTarget, true));
        }
    }
}

public Action Hook_SetTransmit(int entity, int client)
{
    if (!BB_IsClientValid(client) || !BB_IsClientValid(entity) || client == entity)
        return Plugin_Continue;

    if (IsPlayerAlive(client) && IsPlayerAlive(entity) && GetClientTeam(entity) == TEAM_ZOMBIES && GetClientTeam(client) == TEAM_ZOMBIES && g_iPlayer[client].iDistance[entity] <= 9000)
        return Plugin_Handled;

    if (IsPlayerAlive(client) && IsPlayerAlive(entity) && GetClientTeam(entity) == TEAM_BUILDERS && GetClientTeam(client) == TEAM_BUILDERS && BB_IsClientInParty(client) && BB_GetClientPartyPerson(client) == entity && g_iPlayer[client].iDistance[entity] <= 9000 && BB_GetRoundStatus() == Round_Preparation)
        return Plugin_Handled;

    if (!g_iPlayer[entity].bIsTesting || GetClientTeam(client) == CS_TEAM_T)
        return Plugin_Continue;

    if (IsPlayerAlive(client) && g_iPlayer[entity].bIsTesting) 
        return Plugin_Handled;

    return Plugin_Continue;
}