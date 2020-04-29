#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <clientprefs>
#include <emitsoundany>
#include <basebuilder>

#include "core/globals.sp"
#include "core/config.sp"
#include "core/natives.sp"
#include "core/sql.sp"

public Plugin myinfo =
{
    name = BB_PLUGIN_NAME,
    author = BB_PLUGIN_AUTHOR,
    description = BB_PLUGIN_DESCRIPTION,
    version = BB_PLUGIN_VERSION,
    url = BB_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    InitForwards();
    InitNatives();

    RegPluginLibrary("basebuilder");

    return APLRes_Success;
}

public void OnPluginStart()
{
	BB_IsGameCSGO();

    g_iCollisionOffset = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");

	BB_StartConfig("bb");
    SetupConfig();
	BB_EndConfig();
}