#if defined _basebuilder_included
    #endinput
#endif
#define _basebuilder_included

#define LoopValidClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(BB_IsClientValid(%1))

#define BB_PLUGIN_NAME "BaseBuilder"
#define BB_PLUGIN_AUTHOR "Mrkl21full & K4M1s"
#define BB_PLUGIN_DESCRIPTION "BaseBuidler from CS 1.6"
#define BB_PLUGIN_VERSION "1.0"
#define BB_PLUGIN_URL "https://steamcommunity.com/id/MrKrystianKl/"

#define TEAM_ZOMBIES CS_TEAM_T
#define TEAM_BUILDERS CS_TEAM_CT

#include <autoexecconfig>
#include <multicolors>
#include <sdktools>
#include <cstrike>

enum RoundStatus
{
    Round_Inactive = -1,
    Round_Building,
    Round_Preparation,
    Round_Active
}

/**
 * Called when the build phase starts (also it is round start).
 */
forward void BB_OnBuildStart();

/**
 * Called when the preparation phase starts.
 */
forward void BB_OnPrepStart();

/**
 * Called when the actual round starts (after build and prep time).
 *
 * @param roundid           ID of the current round.
 * @param zombies           Count of zombies players.
 * @param builders          Count of builders players.
 */
forward void BB_OnRoundStart(int roundid, int zombies, int builders);

/**
 * Called when the actual round starts (after build and prep time).
 *
 * @param winner            Team which won the round.
 */
forward void BB_OnRoundEnd(int winner);

/**
 * Called when player starts moving block.
 *
 * @param client            Client index.
 * @param entity            Block index.
 */
forward void BB_OnBlockMove(int client, int entity);

/**
 * Called when player stop moving block.
 *
 * @param client            Client index.
 * @param entity            Block index.
 */
forward void BB_OnBlockStop(int client, int entity);

/**
 * Get current round id (returns -1 on non active round).
 */
native int BB_GetRoundID();

/**
 * Check if current phase is the build time.
 */
native bool BB_IsBuildTime();

/**
 * Check if current phase is the preparation time.
 */
native bool BB_IsPrepTime();

/**
 * Get current round startus (see RoundStatus enum for available status).
 */
native RoundStatus BB_GetRoundStatus();

/**
 * Force player to play in the zombies team.
 */
native bool BB_ForceZombie(int client);

/**
 * Force player to play in the builders team.
 */
native bool BB_ForceBuilder(int client);

/**
 * Teleports client to one of builders spawn.
 *
 * @param client            Client index.
 */
native void BB_TeleportToBuilders(int client);

/**
 * Teleports client to one of zombies spawn.
 *
 * @param client            Client index.
 */
native void BB_TeleportToZombies(int client);

/**
 * Check if client is in party.
 *
 * @param client            Client index.
 *
 * @return bool             True if is, false otherwise.
 */
native bool BB_IsClientInParty(int client);

/**
 * Get client party person.
 *
 * @param client            Client index.
 *
 * @return int              Target index.
 */
native int BB_GetClientPartyPerson(int client);

/**
 * Get client level.
 *
 * @param client            Client index.
 *
 * @return int              Client level.
 */
native int BB_GetClientLevel(int client);

/**
 * Get client points.
 *
 * @param client            Client index.
 *
 * @return int              Client points.
 */
native int BB_GetClientPoints(int client);

/**
 * Check if client index is valid.
 *
 * @param client            Client index.
 */
stock bool BB_IsClientValid(int client)
{
    if (client > 0 && client <= MaxClients)
    {
        if (!IsClientInGame(client))
        {
            return false;
        }

        if (IsClientSourceTV(client))
        {
            return false;
        }

        return true;
    }

    return false;
}

/**
 * Send overlay to client.
 *
 * @param client            Client index.
 * @param overlaypath       Overlay path.
 */
stock void BB_ShowOverlayToClient(int client, const char[] overlaypath)
{
    int iFlags = GetCommandFlags("r_screenoverlay");

    SetCommandFlags("r_screenoverlay", iFlags &~ FCVAR_CHEAT);
    ClientCommand(client, "r_screenoverlay \"%s\"", overlaypath);
    SetCommandFlags("r_screenoverlay", iFlags);
}

/**
 * Send overlay to all clients.
 *
 * @param overlaypath       Overlay path.
 */
stock void BB_ShowOverlayToAll(const char[] overlaypath)
{
    LoopValidClients(i) 
    {
        BB_ShowOverlayToClient(i, overlaypath);
    }
}

/**
 * Kill and clear timer.
 *
 * @param timer             Timer handle pointer.
 * @param autoClose         Auto closed timer.
 */
stock void BB_ClearTimer(Handle &timer, bool autoClose = false)
{
    if (timer != null)
    {
        KillTimer(timer, autoClose);
        timer = null;
    }
}

/**
 * Check if there is active warmup.
 */
stock bool BB_IsWarmUp()
{
    return view_as<bool>(GameRules_GetProp("m_bWarmupPeriod"));
}

/**
 * Get client health points.
 *
 * @param client            Client index.
 *
 * @return int              Client health.
 */
stock int BB_GetClientHealth(int client)
{
    GetEntProp(client, Prop_Send, "m_iHealth");
}

/**
 * Adds client health points.
 *
 * @param client            Client index.
 * @param health            Health points.
 */
stock void BB_AddClientHealth(int client, int health = 10)
{
    SetEntProp(client, Prop_Send, "m_iHealth", BB_GetClientHealth(client) + health);
}

/**
 * Subs client health points.
 *
 * @param client            Client index.
 * @param health            Health points.
 */
stock void BB_SubClientHealth(int client, int health = 10)
{
    if (BB_GetClientHealth(client) - 10 <= 0)
    {
        ForcePlayerSuicide(client);
    }
    else
    {
        SetEntProp(client, Prop_Send, "m_iHealth", BB_GetClientHealth(client) - health);
    }
}

/**
 * Sets client health points.
 *
 * @param client            Client index.
 * @param health            Health points.
 */
stock void BB_SetClientHealth(int client, int health = 100)
{
    if (health <= 0)
    {
        ForcePlayerSuicide(client);
    }
    else
    {
        SetEntProp(client, Prop_Send, "m_iHealth", health);
    }
}

/**
 * Check if player has a knife.
 *
 * @param client            Client index.
 *
 * @return int              Weapon index (-1 if not found).
 */
stock int BB_HasClientKnife(int client)
{
    for (int offset = 0; offset < 128; offset += 4)
    {
        int weapon = GetEntDataEnt2(client, FindSendPropInfo("CBasePlayer", "m_hMyWeapons") + offset);

        if (IsValidEntity(weapon))
        {
            char sClass[32];
            GetEntityClassname(weapon, sClass, sizeof(sClass));

            if ((StrContains(sClass, "knife", false) != -1) || (StrContains(sClass, "bayonet", false) != -1))
            {
                return weapon;
            }
        }
    }

    return -1;
}

/**
 * Check if player has a specific weapon.
 *
 * @param client            Client index.
 * @param sWeapon           Weapon name.
 *
 * @return int              Weapon index (-1 if not found).
 */
stock int BB_HasClientWeapon(int client, const char[] sWeapon)
{
    for (int offset = 0; offset < 128; offset += 4)
    {
        int weapon = GetEntDataEnt2(client, FindSendPropInfo("CBasePlayer", "m_hMyWeapons") + offset);

        if (IsValidEntity(weapon))
        {
            char sClass[32];
            GetEntityClassname(weapon, sClass, sizeof(sClass));

            if (StrContains(sClass, sWeapon, false) != -1)
            {
                return weapon;
            }
        }
    }

    return -1;
}

/**
 * Set entity render color (used for colored block and players).
 *
 * @param client            Client index.
 * @param red               Red color range (0-255).
 * @param green             Green color range (0-255).
 * @param blue              Blue color range (0-255).
 * @param alpha             Alpha transparency range (0-255).
 */
stock void BB_SetRenderColor(int entity, int red, int green, int blue, int alpha)
{
    int offset;

    if (!offset && (offset = GetEntSendPropOffs(entity, "m_clrRender")) == -1)
    {
        LogError("Unable to find property offset: \"m_clrRender\"!");
        return;
    }
    
    SetEntData(entity, offset, red, 1, true); 
    SetEntData(entity, offset + 1, green, 1, true); 
    SetEntData(entity, offset + 2, blue, 1, true); 
    SetEntData(entity, offset + 3, alpha, 1, true); 
}

/**
 * Print centered hud message.
 *
 * @param client            Client index.
 * @param title             Title which will be displayed.
 * @param message           Message which will be displayed.
 */
stock void PrintCenterText2(int client, const char[] title, const char[] message)
{
    char sBuffer[2048];
    Format(sBuffer, sizeof(sBuffer), "</font> %s\n%s\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", title, message);
    
    Protobuf hMessage = view_as<Protobuf>(StartMessageOne("TextMsg", client));
    hMessage.SetInt("msg_dst", 4);
    hMessage.AddString("params", "#SFUI_ContractKillStart");
    hMessage.AddString("params", sBuffer);
    hMessage.AddString("params", NULL_STRING);
    hMessage.AddString("params", NULL_STRING);
    hMessage.AddString("params", NULL_STRING);
    hMessage.AddString("params", NULL_STRING);
    
    EndMessage();
}

/**
 * Print centered hud message for all players.
 *
 * @param title             Title which will be displayed.
 * @param message           Message which will be displayed.
 */
stock void PrintCenterText2All(const char[] title, const char[] message, any ...)
{
    char sBuffer[2048];
    
    VFormat(sBuffer, sizeof(sBuffer), message, 3);
    Format(sBuffer, sizeof(sBuffer), "</font> %s\n%s\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", title, sBuffer);

    Protobuf hMessage = view_as<Protobuf>(StartMessageAll("TextMsg"));
    hMessage.SetInt("msg_dst", 4);
    hMessage.AddString("params", "#SFUI_ContractKillStart");
    hMessage.AddString("params", sBuffer);
    hMessage.AddString("params", NULL_STRING);
    hMessage.AddString("params", NULL_STRING);
    hMessage.AddString("params", NULL_STRING);
    hMessage.AddString("params", NULL_STRING);
    
    EndMessage();
}

/**
 * BaseBuilder start config file.
 *
 * @param file              File name.
 * @param directory         Directory name.
 */
stock void BB_StartConfig(char[] file, char[] directory = "basebuilder")
{
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile(file, directory);
}

/**
 * BaseBuilder end config file.
 */
stock void BB_EndConfig()
{
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
}

/**
 * Simple check if current game is CSGO.
 */
stock void BB_IsGameCSGO()
{
    if (GetEngineVersion() != Engine_CSGO)
    {
        SetFailState("Only CS:GO Support!");
        return;
    }
}
