#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <basebuilder>

#define PLUGIN_NAME BB_PLUGIN_NAME ... " - Player Hud"

ConVar g_cHudRefresh;

enum struct PlayerData 
{
    int iTarget;

    bool bActiveHud;
    bool bHiddenOnHud;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

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
    CreateNative("BB_IsPlayerHudActive", Native_IsPlayerHudActive);
    CreateNative("BB_SetPlayerVisibilityOnHud", Native_SetPlayerVisibilityOnHud);

    RegPluginLibrary("basebuilder_playerhud");

    return APLRes_Success;
}

public int Native_IsPlayerHudActive(Handle plugin, int numParams)
{
    return g_iPlayer[GetNativeCell(1)].bActiveHud;
}

public int Native_SetPlayerVisibilityOnHud(Handle plugin, int numParams)
{
    return g_iPlayer[GetNativeCell(1)].bHiddenOnHud = !view_as<bool>(GetNativeCell(2));
}

public void OnPluginStart()
{
    BB_IsGameCSGO();
    BB_LoadTranslations();

    BB_StartConfig("playerhud");
    CreateConVar("bb_hud_version", BB_PLUGIN_VERSION, BB_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cHudRefresh = AutoExecConfig_CreateConVar("bb_hud_refresh", "0.1", "How fast hud should be refreshed (in seconds)?.", _, true, 0.1);
    BB_EndConfig();
}

public void OnConfigsExecuted()
{
    CreateTimer(g_cHudRefresh.FloatValue, Timer_UpdateText, _, TIMER_REPEAT);
}

public void BB_OnRoundStart(int roundid, int zombies, int builders)
{
    LoopValidClients(i)
    {
        g_iPlayer[i].bHiddenOnHud = false;
    }
}

public Action Timer_UpdateText(Handle timer)
{
    if (BB_GetRoundStatus() == Round_Inactive)
    {
        return;
    }

    LoopValidClients(i)
    {
        int iTarget = TraceClientViewEntity(i);

        if (!BB_IsClientValid(iTarget) || g_iPlayer[iTarget].bHiddenOnHud)
        {
            g_iPlayer[i].bActiveHud = false;
            continue;
        }

        g_iPlayer[i].iTarget = iTarget;
        g_iPlayer[i].bActiveHud = true;

        char sHintText[1024];
        PrepareText(i, iTarget, sHintText, sizeof(sHintText));
        
        PrintCenterText2(i, "BaseBuilder", sHintText);
    }
}

public bool PrepareText(int client, int target, char[] sHintText, int iHintTextLength)
{
    //char sPlayerName[256];
    //Format(sPlayerName, sizeof(sPlayerName), "Nick: <font color='%s'>%N</font>", Gangs_IsClientInGang(target) ? Gangs_GetPrefixColor(Gangs_GetGangPrefixColor(Gangs_GetClientGang(target))) : "#EEEEEE", target);
    char sPlayerName[256];
    Format(sPlayerName, sizeof(sPlayerName), "Nick: <font color='%s'>%N</font>", "#EEEEEE", target);

    char sPlayerLevel[128];
    Format(sPlayerLevel, sizeof(sPlayerLevel), "%T", "PlayerHUD: Current LVL", LANG_SERVER, BB_GetClientLevel(target));
    //Format(sPlayerLevel, sizeof(sPlayerLevel), "Aktualny poziom: <font color='#11FF00'>%i level</font>", BB_GetClientLevel(target));

    if (GetClientTeam(target) == TEAM_ZOMBIES)
    {
        char sPlayerHealth[128];
        int iHealth = GetEntProp(target, Prop_Send, "m_iHealth");
        Format(sPlayerHealth, sizeof(sPlayerHealth), "%T", "PlayerHUD: Health points", LANG_SERVER, iHealth >= 2200 ? "#11FF00" : (iHealth >= 850 ? "#EB9900" : "#B80000"), iHealth);
        //Format(sPlayerHealth, sizeof(sPlayerLevel), "Punktów życia: <font color='%s'>%i HP</font>", iHealth >= 2200 ? "#11FF00" : (iHealth >= 850 ? "#EB9900" : "#B80000"), iHealth);

        Format(sHintText, iHintTextLength, "<pre>%s<br>%s<br>%s</pre>", sPlayerName, sPlayerHealth, sPlayerLevel);
    }
    else
    {
        Format(sHintText, iHintTextLength, "<pre>%s<br>%s</pre>", sPlayerName, sPlayerLevel);
    }
}

int TraceClientViewEntity(int client)
{
    float m_fVecOrigin[3];
    float m_fAngRotation[3];

    GetClientEyePosition(client, m_fVecOrigin);
    GetClientEyeAngles(client, m_fAngRotation);

    int pEntity = -1;
    Handle tr = TR_TraceRayFilterEx(m_fVecOrigin, m_fAngRotation, MASK_SOLID, RayType_Infinite, TRDontHitSelf, client);

    if (TR_DidHit(tr))
    {
        pEntity = TR_GetEntityIndex(tr);
        delete tr;
        return pEntity;
    }

    delete tr;
    return -1;
}

public bool TRDontHitSelf(int entity, int mask, int data)
{
    return (entity != data);
}