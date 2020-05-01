#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <basebuilder>

#define PLUGIN_NAME BB_PLUGIN_NAME ... " - Hide Radar"

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = BB_PLUGIN_AUTHOR,
    description = BB_PLUGIN_DESCRIPTION,
    version = BB_PLUGIN_VERSION,
    url = BB_PLUGIN_URL
};

public void OnPluginStart()
{
    BB_IsGameCSGO();

    HookEvent("player_spawn", Event_OnPlayerSpawn);
    HookEvent("player_blind", Event_OnPlayerBlind, EventHookMode_Post);
}

public Action Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(0.0, Timer_RemoveRadar, GetClientOfUserId(event.GetInt("userid")));
}

public Action Timer_RemoveRadar(Handle timer, any client)
{
    if (BB_IsClientValid(client))
    {
        SetEntProp(client, Prop_Send, "m_iHideHUD", 1<<12);
    }
}

public Action Event_OnPlayerBlind(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (BB_IsClientValid(client))
    {
        CreateTimer(GetEntPropFloat(client, Prop_Send, "m_flFlashDuration"), Timer_RemoveRadar, client);
    }
}
