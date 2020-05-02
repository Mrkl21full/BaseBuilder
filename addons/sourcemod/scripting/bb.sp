#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <clientprefs>
#include <emitsoundany>
#include <basebuilder>
#include <basebuilder_sql>

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
	BB_LoadTranslations();

	g_iCollisionOffset = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");

	BB_StartConfig("bb");
	SetupConfig();
	BB_EndConfig();

	CreateTimer(1.0, Timer_1, _, TIMER_REPEAT);

	// BB System
	RegConsoleCmd("sm_points", Command_Points);
	RegConsoleCmd("sm_level", Command_Level);
	RegConsoleCmd("sm_lvl", Command_Level);

	// Last mover
	RegConsoleCmd("sm_lm", Command_LastMover);
	RegConsoleCmd("sm_lastmover", Command_LastMover);

	// Respawn
	RegConsoleCmd("sm_respawn", Command_Respawn);
	RegConsoleCmd("sm_revive", Command_Respawn);
	RegConsoleCmd("sm_r", Command_Respawn);

	// Colors
	RegConsoleCmd("sm_color", Command_Colors);
	RegConsoleCmd("sm_colors", Command_Colors);

	// Party
	RegConsoleCmd("sm_party", Command_Party);
	RegConsoleCmd("sm_accept", Command_PartyAccept);
	RegConsoleCmd("sm_stopparty", Command_PartyRemove);

	// Extra stuff
	RegConsoleCmd("sm_fl", Command_Flashlight);
	RegConsoleCmd("sm_flashlight", Command_Flashlight);

	// Admin stuff
	RegConsoleCmd("sm_adminbb", Command_AdminMenu);

	// Listeners
	AddCommandListener(Command_LAW, "+lookatweapon");
	AddCommandListener(Command_Kill, "kill");
	AddCommandListener(Command_Kill, "killserver");
	AddCommandListener(Command_Kill, "killvector");
	AddCommandListener(Command_Kill, "explode");
	AddCommandListener(Command_Kill, "explodevector");
	AddCommandListener(Command_Kill, "spectate");
	AddCommandListener(Command_TeamChange, "jointeam");
	AddCommandListener(Command_LockBlock, "drop");

	// Remove radio cmds
	for (int i = 0; i < sizeof(g_sRadioCMDs); i++)
	{
		AddCommandListener(Command_RadioCMDs, g_sRadioCMDs[i]);
	}

	// Hook pre events
	HookEvent("round_start", Event_OnRoundStart, EventHookMode_Pre);
	HookEvent("round_end", Event_OnRoundEnd, EventHookMode_Pre);

	// Hook events
	HookEvent("player_team", Event_OnPlayerTeam);
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("player_hurt", Event_OnPlayerHurt);

	// Change sound volume
	AddNormalSoundHook(SoundHook);
}

public void OnConfigsExecuted()
{
	BB_ClearTimer(g_hWarmupTimer);

	g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));

	if (g_cWarmupTime.FloatValue)
	{
		SetConVarInt(FindConVar("mp_warmuptime"), g_cWarmupTime.IntValue);
		SetConVarInt(FindConVar("mp_do_warmup_period"), 1);

		g_hWarmupTimer = CreateTimer(g_cWarmupTime.FloatValue, Timer_WarmupEnd);
	}
	else
	{
		SetConVarInt(FindConVar("mp_warmuptime"), 0);
		SetConVarInt(FindConVar("mp_do_warmup_period"), 0);

		Call_StartForward(g_fwOnWarmupEnd);
		Call_Finish();
	}
}

public Action Timer_WarmupEnd(Handle timer)
{
	BB_ClearTimer(g_hWarmupTimer);

	Call_StartForward(g_fwOnWarmupEnd);
	Call_Finish();
}

public void BB_OnSQLConnect(Database db) 
{
	g_dDatabase = db;
}

public void OnMapStart()
{
	BB_ClearTimer(g_hCountdownTimer);

	g_iStatus = Round_Inactive;
	g_iSpawns = 0;

	int iEnt;
	char sName[128];

	// Get main CT spawn if exists 
	while ((iEnt = FindEntityByClassname(iEnt, "info_teleport_destination")) != -1)
	{
		if (IsValidEntity(iEnt))
		{
			GetEntPropString(iEnt, Prop_Data, "m_iName", sName, sizeof(sName));

			if (StrEqual(sName, "teleport_lobby"))
			{
				GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", g_fSpawnLocation[g_iSpawns]);
				GetEntPropVector(iEnt, Prop_Data, "m_angRotation", g_fSpawnAngles[g_iSpawns]);
				g_fSpawnLocation[g_iSpawns][2] += 20.0;
				g_iSpawns++;
			}
		}
	}

	// If main CT spawn do not exists save player spawns
	if (g_iSpawns == 0)
	{
		while ((iEnt = FindEntityByClassname(iEnt, "info_player_counterterrorist")) != -1)
		{
			if (IsValidEntity(iEnt))
			{
				GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", g_fSpawnLocation[g_iSpawns]);
				GetEntPropVector(iEnt, Prop_Data, "m_angRotation", 	g_fSpawnAngles[g_iSpawns]); 
				g_fSpawnLocation[g_iSpawns][2] += 20.0;
				g_iSpawns++;
			}
		}
	}

	PrecacheSoundAny("items/flashlight1.wav", true);
}

public void OnMapEnd()
{
	BB_ClearTimer(g_hCountdownTimer);

	g_iStatus = Round_Inactive;
}

public void BB_OnWarmupEnd()
{
	if (g_cScrambleTeams.BoolValue)
	{
		ServerCommand("mp_scrambleteams");
	}
}

public void OnGameFrame()
{
	if (g_cPushPlayersOfBlocks.BoolValue)
	{
		float fVel[3], fNewVel[3];

		LoopValidClients(i)
		{
			if (IsPlayerAlive(i))
			{
				if (g_iPlayer[i].bIsOnIce && GetClientTeam(i) == TEAM_BUILDERS && GetEntityFlags(i) & FL_ONGROUND)
				{
					GetEntPropVector(i, Prop_Data, "m_vecAbsVelocity", fVel);
					fVel[2] = 0.0;

					GetEntPropVector(i, Prop_Data, "m_vecVelocity", fVel); 

					NormalizeVector(fVel, fNewVel);
					ScaleVector(fNewVel, 250.0);
					TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, fNewVel); 
				}

				SetEntityGravity(i, g_iPlayer[i].fGravity);
			}
		}
	}
}

public Action Timer_1(Handle timer)
{
	int iBuildersAlive = 0;
	int iZombiesAlive = 0;

	LoopValidClients(i)
	{
		if (g_iStatus != Round_Active)
		{
			if (!IsPlayerAlive(i))
			{
				CreateTimer(0.0, Timer_RespawnPlayer, i);
			} 
			else 
			{
				for (int offset = 0; offset < 128; offset += 4)
				{
					int weapon = GetEntDataEnt2(i, FindSendPropInfo("CBasePlayer", "m_hMyWeapons") + offset);

					if (IsValidEntity(weapon))
					{
						char sClass[32];
						GetEntityClassname(weapon, sClass, sizeof(sClass));

						if (StrContains(sClass, "weapon_", false) != -1)
						{
							SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 2.0);
							SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 2.0);
						}
					}
				}
			}
		}

		int team = GetClientTeam(i);

		if (team == TEAM_BUILDERS)
		{
			if (g_iStatus == Round_Active && !IsPlayerAlive(i))
			{
				CS_SwitchTeam(i, TEAM_ZOMBIES);

				CreateTimer(0.0, Timer_RespawnPlayer, i);
			}
			else
			{
				iBuildersAlive++;
			}
		}
		else if (team == TEAM_ZOMBIES)
		{
			if (g_iStatus == Round_Active && !IsPlayerAlive(i))
			{
				CreateTimer(0.0, Timer_RespawnPlayer, i);
			}
			else
			{
				iZombiesAlive++;
			}
		}
		else
		{
			CS_SwitchTeam(i, TEAM_ZOMBIES);

			if (!IsPlayerAlive(i))
			{
				CreateTimer(0.0, Timer_RespawnPlayer, i);
			}
		}
	}

	if (g_iStatus == Round_Active)
	{
		if (g_iRoundTime-- <= 0)
		{
			CS_TerminateRound(7.0, CSRoundEnd_CTWin);
		} 
		else if(iBuildersAlive == 0)
		{
			CS_TerminateRound(7.0, CSRoundEnd_TerroristWin);
		}
	}
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	BB_ClearTimer(g_hCountdownTimer);

	g_iStatus = Round_Inactive;

	int iWinner = reason == CSRoundEnd_CTWin ? TEAM_BUILDERS : TEAM_ZOMBIES;

	// TODO: Make sound which team won.

	Call_StartForward(g_fwOnRoundEnd);
	Call_PushCell(iWinner);
	Call_Finish();

	// TODO: Announce new round?

	char sQuery[128];
	Format(sQuery, sizeof(sQuery), "UPDATE bb_rounds SET End = UNIX_TIMESTAMP() WHERE ID = %d", g_iRoundID);
	BB_Query("SQL_UpdateRoundEndTime", sQuery);

	g_iRoundID = -1;
	return Plugin_Changed;
}

public void OnClientPutInServer(int client)
{
	if (!BB_IsClientValid(client))
	{
		return;
	}

	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);

	g_iPlayer[client].iIcon = -1;
	g_iPlayer[client].iLocks = 0;
	g_iPlayer[client].iRespawn = 0;
	g_iPlayer[client].iInPartyWith = -1;
	g_iPlayer[client].iPlayerNewEntity = -1;
	g_iPlayer[client].iPlayerPrevButtons = -1;
	g_iPlayer[client].iPlayerSelectedBlock = -1;

	g_iPlayer[client].bIsOnIce = false;
	g_iPlayer[client].bIsInParty = false;
	g_iPlayer[client].bFlashlight = true;
	g_iPlayer[client].bPartyOwner = false;
	g_iPlayer[client].bOnceStopped = false;
	g_iPlayer[client].bTouchingBlock = false;
	g_iPlayer[client].bTakenWithNoOwner = false;
	g_iPlayer[client].bWasAlreadyInServer = false;
	g_iPlayer[client].bWasBuilderThisRound = false;

	char sCommunityID[64];
	GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID));

	char sQuery[256];
	Format(sQuery, sizeof(sQuery), "SELECT Color, Points, Level FROM bb WHERE CommunityID = \"%s\"", sCommunityID);
	g_dDatabase.Query(SQL_OnClientPutInServer, sQuery, GetClientUserId(client));
}

public void OnClientDisconnect(int client)
{
	if (!BB_IsClientValid(client))
	{
		return;
	}

	UpdatePlayer(client);

	RemoveBlocks(client, "disconnect");

	if (g_iPlayer[client].bIsInParty)
	{
		int target = g_iPlayer[client].iInPartyWith;

		g_iPlayer[client].bIsInParty = false;
		g_iPlayer[target].bIsInParty = false;

		g_iPlayer[client].iInPartyWith = -1;
		g_iPlayer[target].iInPartyWith = -1;

		CPrintToChat(target, "%s %T", g_sPluginTag, "Party: Team member left", target);
	}
}

public Action Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	// TODO: Round start
}

public Action Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	// TODO: Round end
}

public Action Event_OnPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	// TODO: Team change
}

public Action Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	// TODO: Player spawn
}

public Action Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	// TODO: Player death
}

public Action Event_OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	// TODO: Player hurt
}

public Action SoundHook(int c[MAXPLAYERS], int &nc, char sample[PLATFORM_MAX_PATH], int &e, int &ch, float &v, int &le, int &p, int &f, char se[PLATFORM_MAX_PATH], int &s)
{
	if (StrContains(sample, "player/land", false) != -1 || StrContains(sample, "player/damage", false) != -1 || StrContains(sample, "player/kevlar", false) != -1 || StrContains(sample, "player/bhit_helmet", false) != -1 || StrContains(sample, "player/footsteps", false) != -1)
	{
		v = 0.01;
		return Plugin_Changed;
	}

	v = 0.75;
	return Plugin_Changed;
}

public int OnEndTouch(int client, int iEnt)
{
	g_iPlayer[client].bIsOnIce = false;

	char sName[64];
	GetEntityClassname(iEnt, sName, sizeof(sName));

	if (StrEqual(sName, "prop_dynamic"))
	{
		g_iPlayer[client].bTouchingBlock = false;

		SetEntityGravity(client, 1.0);
	}
}

public int OnStartTouch(int client, int iEnt)
{
	if (!IsValidEntity(iEnt))
	{
		return;
	}

	if (GetClientTeam(client) == TEAM_ZOMBIES)
	{
		return;
	}

	if (g_iPlayer[client].bTouchingBlock)
	{
		g_iPlayer[client].bIsOnIce = true;

		SetEntityGravity(client, 10.0);	
	}

	char sName[64];
	GetEntityClassname(iEnt, sName, sizeof(sName));

	if (!StrEqual(sName, "prop_dynamic"))
	{
		return;
	}

	// TODO: Check block owner and party member
}

public Action Command_Points(int client, int args)
{
	if (!BB_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	CPrintToChat(client, "%s \x07===================================", g_sPluginTag);
	CPrintToChat(client, "%s %T", g_sPluginTag, "Main: Current points", client, g_iPlayer[client].iPoints);
	CPrintToChat(client, "%s \x07===================================", g_sPluginTag);
	return Plugin_Handled;
}

public Action Command_Level(int client, int args)
{
	if (!BB_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	CPrintToChat(client, "%s \x07===================================", g_sPluginTag);
	CPrintToChat(client, "%s %T", g_sPluginTag, "Main: Current level", client, g_iPlayer[client].iLevel);
	CPrintToChat(client, "%s %T", g_sPluginTag, "Main: Next level in", client, RoundToCeil(((g_iPlayer[client].iLevel + 1) * 0.4) * ((g_iPlayer[client].iLevel + 1) * 35)) - g_iPlayer[client].iPoints);	
	CPrintToChat(client, "%s \x07===================================", g_sPluginTag);
	return Plugin_Handled;
}

public Action Command_LastMover(int client, int args)
{
	if (!BB_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	// TODO: Last mover

	return Plugin_Handled;
}

public Action Command_Respawn(int client, int args)
{
	if (!BB_IsClientValid(client))
	{
	return Plugin_Handled;
	}

	if (g_iStatus == Round_Active)
	{
		if (GetClientTeam(client) == TEAM_ZOMBIES && g_cRespawnZombie.IntValue > 0)
		{
			if (g_iPlayer[client].iRespawn++ < g_cRespawnZombie.IntValue)
			{
				ForcePlayerSuicide(client);
				return Plugin_Handled;
			}

			CPrintToChat(client, "%s %T", g_sPluginTag, "Main: Command limited usage", client, g_cRespawnZombie.IntValue);
			return Plugin_Handled;
		}

		CPrintToChat(client, "%s %T", g_sPluginTag, "Main: Cannot use in active round", client);
		return Plugin_Handled;
	}

	CreateTimer(0.0, Timer_RespawnPlayer, client);
	return Plugin_Handled;
}

public Action Command_Colors(int client, int args)
{
	if (!BB_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	// TODO: Colors

	return Plugin_Handled;
}

public Action Command_Party(int client, int args)
{
	// TODO: Party
}

public Action Command_PartyAccept(int client, int args)
{
	// TODO: Party accept
}

public Action Command_PartyRemove(int client, int args)
{
	// TODO: Party accept
}

public Action Command_Flashlight(int client, int args)
{
	if (!BB_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	g_iPlayer[client].bFlashlight = !g_iPlayer[client].bFlashlight;

	char sTranslate[32];
	Format(sTranslate, sizeof(sTranslate), "Main: Flashlight %s", g_iPlayer[client].bFlashlight ? "enabled" : "disabled");

	CPrintToChat(client, "%s %T", g_sPluginTag, sTranslate, client);
	return Plugin_Handled;
}

public Action Command_AdminMenu(int client, int args)
{
	if (!BB_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	// TODO: Check access and add main stuff

	return Plugin_Handled;
}

public Action Timer_RespawnPlayer(Handle timer, any client)
{
	if (!BB_IsClientValid(client) || g_iStatus == Round_Inactive)
	{
		return;
	}

	int iRandom = GetRandomInt(0, g_iSpawns - 1);

	if (GetClientTeam(client) == TEAM_BUILDERS)
	{
		if (g_iStatus == Round_Active)
		{
			CS_SwitchTeam(client, TEAM_ZOMBIES);
			CS_RespawnPlayer(client);
			TeleportEntity(client, g_fSpawnLocation[iRandom], g_fSpawnAngles[iRandom], NULL_VECTOR);
		}
		else
		{
			CS_RespawnPlayer(client);
		}
	} 
	else
	{
		if (g_iStatus == Round_Active)
		{
			if (IsPlayerAlive(client))
			{
				return;
			}

			CS_RespawnPlayer(client);
			TeleportEntity(client, g_fSpawnLocation[iRandom], g_fSpawnAngles[iRandom], NULL_VECTOR);
		}
		else
		{
			CS_RespawnPlayer(client);
		}
	}
}

public void OnEntityCreated(int entity, const char[] name)
{
	for (int i = 0; i < sizeof(g_sRemoveEntityList); i++)
	{
		if (!StrEqual(name, g_sRemoveEntityList[i]))
		{
			continue;
		}

		if (StrEqual("func_bombtarget", g_sRemoveEntityList[i], false))
		{
			AcceptEntityInput(entity, "kill");
		}
		else if (StrEqual("func_buyzone", g_sRemoveEntityList[i], false))
		{
			AcceptEntityInput(entity, "kill");
		}
		else if (StrEqual("hostage_entity", g_sRemoveEntityList[i], false) || StrEqual("func_hostage_rescue", g_sRemoveEntityList[i], false) || StrEqual("info_hostage_spawn", g_sRemoveEntityList[i], false))
		{
			AcceptEntityInput(entity, "kill");
		}
	}
}

public Action Command_RadioCMDs(int client, const char[] command, int args)
{
	return Plugin_Handled;
}

public Action Command_LAW(int client, const char[] command, int args)
{
	if (!BB_IsClientValid(client) || !g_iPlayer[client].bFlashlight)
	{
		return Plugin_Handled;
	}

	EmitSoundToAllAny("items/flashlight1.wav", client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.05);
	SetEntProp(client, Prop_Send, "m_fEffects", GetEntProp(client, Prop_Send, "m_fEffects") ^ 4);
	return Plugin_Handled;
}

public Action Command_Kill(int client, const char[] command, int args)
{
	if (IsPlayerAlive(client)) {
		CPrintToChat(client, "%s %T", g_sPluginTag, "Main: Suicide disabled", client);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action Command_TeamChange(int client, const char[] command, int args)
{
	CPrintToChat(client, "%s %T", g_sPluginTag, "Main: Team change disabled", client);
	return Plugin_Handled;
}

public Action Command_LockBlock(int client, const char[] command, int args)
{
	// TODO: Lock blocks
}

public Action OnTakeDamage(int iVictim, int &iAttacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (g_iStatus != Round_Active || damagetype & DMG_FALL)
	{
		return Plugin_Handled;
	}

	if (!BB_IsClientValid(iVictim) || !BB_IsClientValid(iAttacker))
	{
		return Plugin_Continue;
	}

	if (GetClientTeam(iVictim) == GetClientTeam(iAttacker))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action OnWeaponCanUse(int client, int iWeapon)
{
	if (GetClientTeam(client) == TEAM_BUILDERS)
	{
		return Plugin_Continue;
	}

	char sName[32];
	GetEdictClassname(iWeapon, sName, sizeof(sName));

	return StrEqual(sName, "weapon_knife") || StrEqual(sName, "weapon_bayonet") ? Plugin_Continue : Plugin_Handled;
}

stock void UpdatePlayer(int client)
{
	char sCommunityID[64];
	GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID));

	char sQuery[1024];
	Format(sQuery, sizeof(sQuery), "INSERT INTO bb (CommunityID, Color, Points, Level) VALUES (\"%s\", %i, 0, 1) ON DUPLICATE KEY UPDATE Color = %d, Points = %d, Level = %d", sCommunityID, g_iPlayer[client].iColor, g_iPlayer[client].iColor, g_iPlayer[client].iPoints, g_iPlayer[client].iLevel);
	BB_Query("SQL_UpdatePlayer", sQuery);
}

stock int GetTargetBlock(int client)
{
	float fLoc[3], fAng[3];
	GetClientEyePosition(client, fLoc);
	GetClientEyeAngles(client, fAng);

	Handle tr = TR_TraceRayFilterEx(fLoc, fAng, MASK_VISIBLE, RayType_Infinite, TR_DontHitSelf, client);

	if (TR_DidHit(tr))
	{
		int iEntity = TR_GetEntityIndex(tr);

		if (iEntity == 0)
		{
			iEntity = GetClientAimTarget(client, false);
		}

		if (IsValidEntity(iEntity))
		{
			char sName[32];
			GetEdictClassname(iEntity, sName, sizeof(sName));

			if (StrContains(sName, "prop_dynamic") != -1)
			{
				return iEntity;
			}
		}

		delete tr;
		return -1;
	}

	delete tr;
	return -1;
}

public bool TR_DontHitSelf(int entity, int mask, int client)
{
	return !BB_IsClientValid(entity);
}

stock int GetBlockOwner(int entity)
{
	if (!IsValidEntity(entity))
	{
		return 0;
	}

	char sName[MAX_NAME_LENGTH];
	GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

	return StringToInt(sName);
}

stock void SetBlockOwner(int entity, int owner)
{
	if (!IsValidEntity(entity))
	{
		return 0;
	}

	char sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "%i", owner);

	DispatchKeyValue(entity, "targetname", sBuffer);
}

stock int GetLastMover(int entity)
{
	char sName[MAX_NAME_LENGTH];
	GetEntPropString(entity, Prop_Data, "m_iGlobalname", sName, sizeof(sName));

	return StringToInt(sName);
}

stock void SetLastMover(int entity, int owner)
{
	char sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "%i", owner);

	DispatchKeyValue(entity, "globalname", sBuffer);
}

stock void AddInFrontOf(float vecOrigin[3], float vecAngle[3], float units, float output[3])
{
	float fVec[3];
	fVec = vecAngle;

	GetAngleVectors(fVec, fVec, NULL_VECTOR, NULL_VECTOR);

	for (int i; i < 3; i++)
	{
		output[i] = vecOrigin[i] + (fVec[i] * units);
	}
}

stock int GetAimOrigin(int client, float hOrigin[3]) 
{
	float vAngles[3];
	float fOrigin[3];
	GetClientEyePosition(client,fOrigin);
	GetClientEyeAngles(client, vAngles);

	Handle trace = TR_TraceRayFilterEx(fOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);

	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(hOrigin, trace);
		CloseHandle(trace);
		return 1;
	}

	CloseHandle(trace);
	return 0;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask) 
{
	return entity > MaxClients;
}

stock void RotateBlock(int client, int entity)
{
	if (BB_IsClientValid(client))
	{
		entity = GetTargetBlock(client);
	}

	if (IsValidEntity(entity))
	{
		if (BB_IsClientValid(client) || GetBlockOwner(entity) == 0)
		{
			float fAng[3];
			GetEntPropVector(entity, Prop_Send, "m_angRotation", fAng);

			fAng[0] += 0.0;
			fAng[1] += 45.0;
			fAng[2] += 0.0;

			TeleportEntity(entity, NULL_VECTOR, fAng, NULL_VECTOR);
		}	
	}
}

stock void ColorBlock(int client, int entity, bool reset)
{
	if (BB_IsClientValid(client) && IsValidEntity(entity))
	{
		SetEntityRenderMode(entity, RENDER_TRANSCOLOR);

		if (reset)
		{
			BB_SetRenderColor(entity, 255, 255, 255, 255);
		}
		else
		{
			int color = GetPartyColor(client);

			BB_SetRenderColor(entity, g_iColorRed[color], g_iColorGreen[color], g_iColorBlue[color], 255);
		}
	}
}

stock int GetPartyOwner(int client)
{
	return g_iPlayer[client].bIsInParty ? (g_iPlayer[client].bPartyOwner ? client : g_iPlayer[client].iInPartyWith) : client;
}

stock int GetPartyColor(int client)
{
	if (g_iPlayer[client].bIsInParty && !g_iPlayer[client].bPartyOwner)
	{
		int target = g_iPlayer[client].iInPartyWith;

		if (!BB_IsClientValid(target))
		{
			return g_iPlayer[client].iColor;
		}

		return g_iPlayer[target].iColor;
	}
	else
	{
		return g_iPlayer[client].iColor;
	}
}

stock void RemoveBlocks(int client, char[] type)
{
	int iEnt = INVALID_ENT_REFERENCE;

	if (StrEqual(type, "disconnect"))
	{
		while ((iEnt = FindEntityByClassname(iEnt, "prop_dynamic")) != INVALID_ENT_REFERENCE)
		{
			if (IsValidEntity(iEnt))
			{
				char sName[32];
				GetEntPropString(iEnt, Prop_Data, "m_iName", sName, sizeof(sName));

				char sGlobalName[32];
				GetEntPropString(iEnt, Prop_Data, "m_iGlobalname", sGlobalName, sizeof(sGlobalName));

				if (StringToInt(sName) == client || StringToInt(sGlobalName) == client)
				{
					AcceptEntityInput(iEnt, "Kill");
				}
			}
		}
	} 
	else
	{
		if (g_cRemoveNotUsedBlocks.BoolValue && StrEqual(type, "prep"))
		{
			while ((iEnt = FindEntityByClassname(iEnt, "prop_dynamic")) != INVALID_ENT_REFERENCE)
			{
				if (IsValidEntity(iEnt) && IsValidEdict(iEnt))
				{
					char sName[32];
					GetEntPropString(iEnt, Prop_Data, "m_iName", sName, sizeof(sName));

					char sGlobalName[32];
					GetEntPropString(iEnt, Prop_Data, "m_iGlobalname", sGlobalName, sizeof(sGlobalName));

					if(StrEqual(sName, "") && StrEqual(sGlobalName, ""))
					{
						AcceptEntityInput(iEnt, "Kill");
					}
				}
			}
		}

		if (g_cRemoveBlockAfterDeath.BoolValue && StrEqual(type, "death") && g_iStatus == Round_Active)
		{
			while ((iEnt = FindEntityByClassname(iEnt, "prop_dynamic")) != INVALID_ENT_REFERENCE)
			{
				if (IsValidEntity(iEnt))
				{
					char sName[32];
					GetEntPropString(iEnt, Prop_Data, "m_iName", sName, sizeof(sName));

					char sGlobalName[32];
					GetEntPropString(iEnt, Prop_Data, "m_iGlobalname", sGlobalName, sizeof(sGlobalName));

					if (StringToInt(sName) == client || StringToInt(sGlobalName) == client)
					{
						AcceptEntityInput(iEnt, "Kill");
					}
				}
			}
		}
	}
}