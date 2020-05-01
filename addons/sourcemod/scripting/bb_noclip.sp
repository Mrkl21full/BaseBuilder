#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <multicolors>
#include <emitsoundany>
#include <EverGames>
#include <basebuilder>
#include <basebuilder_shop>
#include <basebuilder_noclip>
#include <basebuilder_playerhud>

#define PLUGIN_NAME BB_PLUGIN_NAME ... " - Things: Base Testing"

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

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
    CreateNative("BB_IsClientWalking", Native_IsClientWalking);
    CreateNative("BB_SetClientWalking", Native_SetClientWalking);

    RegPluginLibrary("basebuilder_noclip");

    return APLRes_Success;
}

public int Native_IsClientWalking(Handle plugin, int numParams)
{
	return g_iPlayer[GetNativeCell(1)].bIsTesting;
}

public int Native_SetClientWalking(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if(view_as<bool>(GetNativeCell(2))) {
        g_iPlayer[client].bIsTesting = true;
        BB_TeleportToBuilders(client);
        BB_SetPlayerVisibilityOnHud(client, false);
        CPrintToChat(client, "%s Możesz chodzić pomiędzy budowniczymi!", g_sPluginTag);
    } else {
        g_iPlayer[client].bIsTesting = false;
        BB_TeleportToZombies(client);
        BB_SetPlayerVisibilityOnHud(client, true);
        CPrintToChat(client, "%s Wróciłeś do swoich!", g_sPluginTag);
    }
}

public void OnPluginStart()
{
    BB_IsGameCSGO();

    RegConsoleCmd("sm_walk", Command_BaseTesting);
    RegConsoleCmd("sm_noclipbb", Command_Noclip);

    LoopValidClients(i)
        OnClientPutInServer(i);
}

public void OnConfigsExecuted()
{
    g_cPluginTag = FindConVar("bb_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if(convar == g_cPluginTag)
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
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
        CPrintToChat(client, "%s Ta funkcja dostępna jest po stronie drużyny zombie!", g_sPluginTag);
        return Plugin_Handled;
    }

    if (BB_GetRoundStatus() != Round_Building) {
        CPrintToChat(client, "%s Tej funkcji możesz użyć tylko podczas czasu budowania!", g_sPluginTag);
        return Plugin_Handled;
    }

    BB_SetClientWalking(client, !g_iPlayer[client].bIsTesting);
    return Plugin_Handled;
}

public Action Command_Noclip(int client, int args)
{
    if (!BB_IsClientValid(client))
		return Plugin_Handled;
    
    if (EG_GetUserRang(client) < 80)
        return Plugin_Handled;

    char sRangWithNick[MAX_NAME_LENGTH * 2];
    EG_GetRangColor(client, sRangWithNick, sizeof(sRangWithNick));
    
    if(GetEntityMoveType(client) != MOVETYPE_NOCLIP) {
        SetEntityMoveType(client, MOVETYPE_NOCLIP);

        BB_SetPlayerVisibilityOnHud(client, false);
        
        LoopValidClients(i)
            if (EG_GetUserRang(i) >= 80)
                CPrintToChat(i, "%s %s \x06włączył noclipa.", g_sPluginTag, sRangWithNick);
    } else {
        SetEntityMoveType(client, MOVETYPE_WALK);

        BB_SetPlayerVisibilityOnHud(client, true);

        LoopValidClients(i)
            if (EG_GetUserRang(i) >= 80)
                CPrintToChat(i, "%s %s \x07wyłączył noclipa.", g_sPluginTag, sRangWithNick);
    }

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

    LoopValidClients(i) {
        if (GetEntityMoveType(i) == MOVETYPE_NOCLIP)
                Command_Noclip(i, 0);
        
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
    if(!BB_IsClientValid(client) || !BB_IsClientValid(entity) || client == entity)
        return Plugin_Continue;
    
    if(GetEntityMoveType(entity) == MOVETYPE_NOCLIP && client != entity && EG_GetUserRang(client) < 80)
        return Plugin_Handled;

    if(IsPlayerAlive(client) && IsPlayerAlive(entity) && GetClientTeam(entity) == TEAM_ZOMBIES && GetClientTeam(client) == TEAM_ZOMBIES && g_iPlayer[client].iDistance[entity] <= 9000)
        return Plugin_Handled;

    if(IsPlayerAlive(client) && IsPlayerAlive(entity) && GetClientTeam(entity) == TEAM_BUILDERS && GetClientTeam(client) == TEAM_BUILDERS && BB_IsClientInParty(client) && BB_GetClientPartyPerson(client) == entity && g_iPlayer[client].iDistance[entity] <= 9000 && BB_GetRoundStatus() == Round_Preparation)
        return Plugin_Handled;

    if(!g_iPlayer[entity].bIsTesting || GetClientTeam(client) == CS_TEAM_T)
        return Plugin_Continue;

    if(IsPlayerAlive(client) && g_iPlayer[entity].bIsTesting) 
        return Plugin_Handled;

    return Plugin_Continue;
}