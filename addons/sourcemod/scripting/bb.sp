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

	// Rotate
	RegConsoleCmd("sm_rotate", Command_Rotate);

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

	PrecacheSoundAny("BaseBuilder/Time_1min.mp3", true);
	PrecacheSoundAny("BaseBuilder/Time_2min.mp3", true);
	PrecacheSoundAny("BaseBuilder/Time_5sec.mp3", true);
	PrecacheSoundAny("BaseBuilder/Time_10sec.mp3", true);
	PrecacheSoundAny("BaseBuilder/Time_30sec.mp3", true);
	PrecacheSoundAny("BaseBuilder/Block_Drop.mp3", true);
	PrecacheSoundAny("BaseBuilder/Block_Grab.mp3", true); 
	PrecacheSoundAny("BaseBuilder/Player_Hit.mp3", true);
	PrecacheSoundAny("BaseBuilder/Phase_Build.mp3", true);
	PrecacheSoundAny("BaseBuilder/Phase_Prep.mp3", true);
	PrecacheSoundAny("BaseBuilder/Round_Start1.mp3", true);
	PrecacheSoundAny("BaseBuilder/Round_Start2.mp3", true);
	PrecacheSoundAny("BaseBuilder/Win_Builders.mp3", true);
	PrecacheSoundAny("BaseBuilder/Win_Zombies.mp3", true);
	PrecacheSoundAny("BaseBuilder/Zombie_Kill.mp3", true);
	PrecacheSoundAny("BaseBuilder/Special/LevelUp.mp3", true);
	PrecacheSoundAny("BaseBuilder/Special/Teleportation.mp3", true);
	PrecacheSoundAny("items/flashlight1.wav", true);

	AddFileToDownloadsTable("sound/BaseBuilder/Time_1min.mp3");
	AddFileToDownloadsTable("sound/BaseBuilder/Time_2min.mp3"); 
	AddFileToDownloadsTable("sound/BaseBuilder/Time_5sec.mp3"); 
	AddFileToDownloadsTable("sound/BaseBuilder/Time_10sec.mp3"); 
	AddFileToDownloadsTable("sound/BaseBuilder/Time_30sec.mp3"); 
	AddFileToDownloadsTable("sound/BaseBuilder/Block_Drop.mp3"); 
	AddFileToDownloadsTable("sound/BaseBuilder/Block_Grab.mp3"); 
	AddFileToDownloadsTable("sound/BaseBuilder/Player_Hit.mp3"); 
	AddFileToDownloadsTable("sound/BaseBuilder/Phase_Build.mp3"); 
	AddFileToDownloadsTable("sound/BaseBuilder/Phase_Prep.mp3"); 
	AddFileToDownloadsTable("sound/BaseBuilder/Round_Start1.mp3"); 
	AddFileToDownloadsTable("sound/BaseBuilder/Round_Start2.mp3"); 
	AddFileToDownloadsTable("sound/BaseBuilder/Win_Builders.mp3"); 
	AddFileToDownloadsTable("sound/BaseBuilder/Win_Zombies.mp3"); 
	AddFileToDownloadsTable("sound/BaseBuilder/Zombie_Kill.mp3");
	AddFileToDownloadsTable("sound/BaseBuilder/Special/LevelUp.mp3");
	AddFileToDownloadsTable("sound/BaseBuilder/Special/Teleportation.mp3");

	if (g_cLoadConvars.BoolValue)
	{
		ServerCommand("exec basebuilder/extra/game_convars.cfg");
	}
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

	if (iWinner == TEAM_ZOMBIES)
	{
		EmitSoundToAllAny("BaseBuilder/Win_Zombies.mp3");
	}
	else
	{
		EmitSoundToAllAny("BaseBuilder/Win_Builders.mp3");
	}

	Call_StartForward(g_fwOnRoundEnd);
	Call_PushCell(iWinner);
	Call_Finish();

	LoopValidClients(i)
	{
		CPrintToChat(i, "%s %T", g_sPluginTag, "Main: Next round in", i, delay);
	}

	char sQuery[128];
	Format(sQuery, sizeof(sQuery), "UPDATE bb_rounds SET End = UNIX_TIMESTAMP() WHERE ID = %d", g_iRoundID);
	BB_Query("SQL_UpdateRoundEndTime", sQuery);

	g_iRoundID = -1;
	return Plugin_Changed;
}

public void OnClientPutInServer(int client)
{
	if (!BB_IsClientValid(client) || IsFakeClient(client))
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

	g_iPlayer[client].fRotate = 45.0;

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
	Format(sQuery, sizeof(sQuery), "SELECT Rotate, Color, Points, Level FROM bb WHERE CommunityID = \"%s\"", sCommunityID);
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
	if (BB_IsWarmUp())
	{
		return;
	}

	BB_ClearTimer(g_hCountdownTimer);

	EmitSoundToAllAny("BaseBuilder/Phase_Build.mp3");

	LoopValidClients(i)
	{
		g_iPlayer[i].iLocks = 0;
		g_iPlayer[i].iRespawn = 0;
		g_iPlayer[i].iInPartyWith = -1;
		g_iPlayer[i].bIsInParty = false;
		g_iPlayer[i].bPartyOwner = false;
		g_iPlayer[i].bWasBuilderThisRound = GetClientTeam(i) == TEAM_BUILDERS;

		CS_SetMVPCount(i, g_iPlayer[i].iLevel);
	}

	g_iStatus = Round_Building;
	g_iCountdownTime = g_cBuildTime.IntValue;
	g_hCountdownTimer = CreateTimer(1.0, Timer_Build, _, TIMER_REPEAT);

	GameRules_SetProp("m_iRoundTime", g_cBuildTime.IntValue + g_cPrepTime.IntValue + g_cRoundTime.IntValue, 4, 0, true);

	Call_StartForward(g_fwOnBuildStart);
	Call_Finish();
}

public Action Timer_Build(Handle timer)
{
	char sBuffer[1024];

	LoopValidClients(i)
	{
		Format(sBuffer, sizeof(sBuffer), "<pre><font size='22' color='#FFA500'>%T<br>%T</font><br><font size='18' color='#309FFF'>%T</font></pre>", "Main: Build time", i, "Main: Seconds", i, g_iCountdownTime, "Main: Hud footer", i);
		PrintCenterText2(i, "BaseBuilder", sBuffer);
	}

	switch(g_iCountdownTime--)
	{
		case 120: { EmitSoundToAllAny("BaseBuilder/Time_2min.mp3"); }
		case 60: { EmitSoundToAllAny("BaseBuilder/Time_1min.mp3"); }
		case 30: { EmitSoundToAllAny("BaseBuilder/Time_30sec.mp3"); }
		case 10: { EmitSoundToAllAny("BaseBuilder/Time_10sec.mp3"); }
		case 5: { EmitSoundToAllAny("BaseBuilder/Time_5sec.mp3"); }
		case 0: {
			BB_ClearTimer(g_hCountdownTimer);

			LoopValidClients(i)
			{
				if (GetClientTeam(i) == TEAM_BUILDERS)
				{
					StoppedMovingBlock(i);
					CS_RespawnPlayer(i);
				}
			}

			RemoveBlocks(1, "prep");	

			g_iStatus = Round_Preparation;
			g_iCountdownTime = g_cPrepTime.IntValue;
			g_hCountdownTimer = CreateTimer(1.0, Timer_PrepTime, _, TIMER_REPEAT);

			EmitSoundToAllAny("BaseBuilder/Phase_Prep.mp3");

			Call_StartForward(g_fwOnPrepStart);
			Call_Finish();
		}
	}
}

public Action Timer_PrepTime(Handle timer)
{
	char sBuffer[1024];
	
	LoopValidClients(i)
	{
		Format(sBuffer, sizeof(sBuffer), "<pre><font size='22' color='#FFA500'>%T<br>%T</font><br><font size='18' color='#309FFF'>%T</font></pre>", "Main: Preparation time", i, "Main: Seconds", i, g_iCountdownTime, "Main: Hud footer", i);
		PrintCenterText2(i, "BaseBuilder", sBuffer);
	}

	if(g_iCountdownTime-- <= 0)
	{
		BB_ClearTimer(g_hCountdownTimer);

		LoopValidClients(i)
		{
			Format(sBuffer, sizeof(sBuffer), "<pre><font size='22' color='#44FF22'>%T</font><br><br><font size='18' color='#309FFF'>%T</font></pre>", "Main: Start", i, "Main: Hud footer", i);
			PrintCenterText2(i, "BaseBuilder", sBuffer);
		}

		if (GetRandomInt(1, 2) == 1)
		{
			EmitSoundToAllAny("BaseBuilder/Round_Start1.mp3");
		}
		else
		{
			EmitSoundToAllAny("BaseBuilder/Round_Start2.mp3");
		}

		char sQuery[256];
		Format(sQuery, sizeof(sQuery), "INSERT INTO bb_rounds (Start) VALUES (UNIX_TIMESTAMP())");
		g_dDatabase.Query(SQL_InsertRound, sQuery);
	}
}

public Action Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (BB_IsWarmUp())
	{
		return;
	}

	// TODO: Round end, remove parties
}

public Action Event_OnPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!BB_IsClientValid(client) || g_iPlayer[client].bWasAlreadyInServer)
	{
		return Plugin_Handled;
	}
	
	g_iPlayer[client].bWasAlreadyInServer = true;
	
	int team = event.GetInt("team");

	if (g_iStatus == Round_Active && team == TEAM_BUILDERS)
	{
		CS_SwitchTeam(client, TEAM_ZOMBIES);
		g_iPlayer[client].bWasBuilderThisRound = true;
		CreateTimer(0.0, Timer_RespawnPlayer, client);
	}
	
	return Plugin_Handled;
}

public Action Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!BB_IsClientValid(client))
	{
		return;
	}

	if (GetClientTeam(client) == TEAM_BUILDERS)
	{
		g_iPlayer[client].bWasBuilderThisRound = true;

		if (g_cPushPlayersOfBlocks.BoolValue)
		{
			SDKHook(client, SDKHook_StartTouch, OnStartTouch);
			SDKHook(client, SDKHook_EndTouch, OnEndTouch);
		}
	} else {
		SDKUnhook(client, SDKHook_StartTouch, OnStartTouch);
		SDKUnhook(client, SDKHook_EndTouch, OnEndTouch);
	}

	CS_SetMVPCount(client, g_iPlayer[client].iLevel);

	SetEntData(client, g_iCollisionOffset, 2, 1, true);

	g_iPlayer[client].iPlayerNewEntity = -1;
	g_iPlayer[client].iPlayerSelectedBlock = -1;
}

public Action Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	// TODO: Player death
}

public Action Event_OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (!BB_IsClientValid(client) || !BB_IsClientValid(attacker) || client == attacker)
	{
		return Plugin_Handled;
	}
	
	SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 4);
	
	if (GetClientTeam(attacker) == TEAM_ZOMBIES && g_iStatus == Round_Active)
	{
		EmitSoundToAllAny("BaseBuilder/Player_Hit.mp3", attacker);
	}

	return Plugin_Handled;
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

		SetEntityGravity(client, g_iPlayer[client].fGravity);
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

	int owner = GetBlockOwner(iEnt);

	if (!BB_IsClientValid(owner))
	{
		return;
	}

	int target = g_iPlayer[client].iInPartyWith;

	if (target == -1)
	{
		target = client;
	}

	if (owner != client && owner != target)
	{
		g_iPlayer[client].bIsOnIce = true;
		g_iPlayer[client].bTouchingBlock = true;
		g_iPlayer[client].fGravity = GetEntityGravity(client);

		SetEntityGravity(client, 10.0);	
		SlapPlayer(client, 0, false);
	}
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

	int entity = GetTargetBlock(client);

	if (IsValidEntity(entity))
	{
		int target = GetLastMover(entity);

		if (BB_IsClientValid(target))
		{
			CPrintToChat(client, "%s %T!", g_sPluginTag, "Main: Block moved by", client, target);
		}
		else
		{
			CPrintToChat(client, "%s %T", g_sPluginTag, "Main: Block not moved", client);
		}
	}

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

public Action Command_Rotate(int client, int args)
{
	if (!BB_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	Menu menu = new Menu(Menu_BlockRotate);

	menu.SetTitle("%T", "Main: Rotate title", client);

	char sCMD[64], sDegreesList[6][32];
	g_cBlockRotation.GetString(sCMD, sizeof(sCMD));

	int iDegrees = ExplodeString(sCMD, ";", sDegreesList, sizeof(sDegreesList), sizeof(sDegreesList[]));

	for (int i = 0; i < iDegrees; i++)
	{
		char sFormat[32];
		Format(sFormat, sizeof(sFormat), "%T", "Main: Rotate degrees", client, sDegreesList[i]);
		menu.AddItem(sDegreesList[i], sFormat, g_iPlayer[client].fRotate == StringToFloat(sDegreesList[i]) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int Menu_BlockRotate(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char sInfo[32];
		GetMenuItem(menu, item, sInfo, sizeof(sInfo));

		g_iPlayer[client].fRotate = StringToFloat(sInfo);

		Command_Rotate(client, 0);
	}
}

public Action Command_Colors(int client, int args)
{
	if (!BB_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	Menu menu = new Menu(PlayerColors);
		
	menu.SetTitle("%T", "Color: Player colors title", client);

	char sBuffer[MAX_NAME_LENGTH];
	Format(sBuffer, sizeof(sBuffer), "%T", "Color: Change color", client);

	menu.AddItem("change", sBuffer);
	menu.AddItem("", "", ITEMDRAW_SPACER);

	LoopValidClients(i)
	{
		Format(sBuffer, sizeof(sBuffer), "%N - %s", i, g_sColorName[g_iPlayer[i].iColor]);
		menu.AddItem("", sBuffer);
	}
	
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int PlayerColors(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char sInfo[32];
		GetMenuItem(menu, item, sInfo, sizeof(sInfo));

		if (StrEqual(sInfo, "change"))
		{
			Menu colors = new Menu(PlayerColors_Change);
		
			colors.SetTitle("%T", "Color: Change block color title", client);

			char sBuffer[8];
			for (int i = 0; i < sizeof(g_sColorName); i++)
			{
				Format(sBuffer, sizeof(sBuffer), "%i", i);
				colors.AddItem(sBuffer, g_sColorName[i]);
			}
			
			colors.Display(client, MENU_TIME_FOREVER);
		}
	}
}

public int PlayerColors_Change(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char sInfo[32];
		GetMenuItem(menu, item, sInfo, sizeof(sInfo));

		g_iPlayer[client].iColor = StringToInt(sInfo);

		if (g_iPlayer[client].iLocks > 0)
		{
			ColorBlockByClient(client);
		}
	}
}

public Action Command_Party(int client, int args)
{
	if(!BB_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	if (GetClientTeam(client) != TEAM_BUILDERS)
	{
		CPrintToChat(client, "%s %T", g_sPluginTag, "Party: Builders only", client);
		return Plugin_Handled;
	}

	if (g_iPlayer[client].bIsInParty)
	{
		CPrintToChat(client, "%s %T!", g_sPluginTag, "Party: Already in team", client);
		return Plugin_Handled;
	}

	Menu menu = new Menu(PartyMenu);

	menu.SetTitle("%T", "Party: Choose teammate title", client);

	char sUID[8], sNick[MAX_NAME_LENGTH];
	LoopValidClients(i)
	{
		if (g_iPlayer[i].bIsInParty || GetClientTeam(i) != TEAM_BUILDERS || client == i)
		{
			continue;
		}

		Format(sUID, sizeof(sUID), "%i", i);
		Format(sNick, sizeof(sNick), "%N", i);

		menu.AddItem(sUID, sNick);
	}

	if (strlen(sUID) <= 0)
	{
		Format(sNick, sizeof(sNick), "%T", "Party: Empty list", client);
		menu.AddItem("empty", sNick);
	}

	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int PartyMenu(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char sInfo[32];
		GetMenuItem(menu, item, sInfo, sizeof(sInfo));

		if (!StrEqual(sInfo, "empty")) {
			int target = StringToInt(sInfo);

			if (!BB_IsClientValid(target))
			{
				CPrintToChat(client, "%s %T", g_sPluginTag, "Party: Team member left", client);
				return;
			}

			g_iPlayer[client].iInPartyWith = target;
			g_iPlayer[target].iInPartyWith = client;

			g_iPlayer[client].bPartyOwner = true;

			CPrintToChat(client, "%s %T", g_sPluginTag, "Party: Invite sended", client, target);
			CPrintToChat(client, "%s %T", g_sPluginTag, "Party: Target accept in", client, g_cInviteTime.IntValue);

			CPrintToChat(target, "%s %T", g_sPluginTag, "Party: Invite from", target, client);
			CPrintToChat(target, "%s %T", g_sPluginTag, "Party: To accept it", target);
			CPrintToChat(target, "%s %T", g_sPluginTag, "Party: To decline it", target, g_cInviteTime.IntValue);

			Menu invite = new Menu(PartyMenu_Invite);

			invite.SetTitle("%T", "Party: Invite from title", target, client);

			char sBuffer[64];
			Format(sBuffer, sizeof(sBuffer), "%T", "Party: Accept title", target);
			invite.AddItem("yes", sBuffer);

			Format(sBuffer, sizeof(sBuffer), "%T", "Party: Decline title", target);
			invite.AddItem("no", sBuffer);

			invite.Display(target, g_cInviteTime.IntValue);

			g_iPlayer[client].hInvite = CreateTimer(g_cInviteTime.FloatValue, Timer_ResetInvite, client);
			g_iPlayer[client].hInvite = CreateTimer(g_cInviteTime.FloatValue, Timer_ResetInvite, target);
		}
	}
}

public int PartyMenu_Invite(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char sInfo[32];
		GetMenuItem(menu, item, sInfo, sizeof(sInfo));

		if (StrEqual(sInfo, "no"))
		{
			int target = g_iPlayer[client].iInPartyWith;

			BB_ClearTimer(g_iPlayer[client].hInvite);
			BB_ClearTimer(g_iPlayer[target].hInvite);

			g_iPlayer[client].iInPartyWith = -1;
			g_iPlayer[client].bPartyOwner = false;

			g_iPlayer[target].iInPartyWith = -1;
			g_iPlayer[target].bPartyOwner = false;

			CPrintToChat(client, "%s %T", g_sPluginTag, "Party: Player declined it", client, target);
			CPrintToChat(target, "%s %T", g_sPluginTag, "Party: Player declined it other", target, client);
		}
		else
		{
			int target = g_iPlayer[client].iInPartyWith;

			if (g_iPlayer[client].bIsInParty)
			{
				CPrintToChat(client, "%s %T", g_sPluginTag, "Party: Already in team", client);
				return;
			}

			if (g_iPlayer[target].bIsInParty)
			{
				BB_ClearTimer(g_iPlayer[client].hInvite);

				g_iPlayer[client].iInPartyWith = -1;
				g_iPlayer[client].bPartyOwner = false;

				CPrintToChat(client, "%s %T", g_sPluginTag, "Party: Player already in team", client, target);
				return;
			}
			
			AcceptInvite(client, target);
		}
	}
}

public Action Timer_ResetInvite(Handle timer, any client)
{
	if (!BB_IsClientValid(client) || g_iPlayer[client].bIsInParty)
	{
		return;
	}

	BB_ClearTimer(g_iPlayer[client].hInvite);

	g_iPlayer[client].iInPartyWith = -1;
	g_iPlayer[client].bPartyOwner = false;
}

public Action Command_PartyAccept(int client, int args)
{
	if (!BB_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	int target = g_iPlayer[client].iInPartyWith;

	if (!BB_IsClientValid(target))
	{
		CPrintToChat(client, "%s %T", g_sPluginTag, "Party: Not active invites", client);
		return Plugin_Handled;
	}

	if (g_iPlayer[client].bPartyOwner)
	{
		CPrintToChat(client, "%s %T", g_sPluginTag, "Party: You shouldnt", client);
		return Plugin_Handled;
	}

	if (GetClientTeam(client) != TEAM_BUILDERS || GetClientTeam(target) != TEAM_BUILDERS)
	{
		CPrintToChat(client, "%s %T!", g_sPluginTag, "Party: Not the same teams", client);
		return Plugin_Handled;
	}

	if (g_iPlayer[client].bIsInParty)
	{
		CPrintToChat(client, "%s %T", g_sPluginTag, "Party: Already in team", client);
		return Plugin_Handled;
	}

	if (g_iPlayer[target].bIsInParty)
	{
		CPrintToChat(client, "%s %T", g_sPluginTag, "Party: Player already in team", client, target);
		return Plugin_Handled;
	}

	AcceptInvite(client, target);
	return Plugin_Handled;
}

public Action Command_PartyRemove(int client, int args)
{
	if (!BB_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	if (!g_iPlayer[client].bIsInParty)
	{
		CPrintToChat(client, "%s %T", g_sPluginTag, "Party: Not in team", client);
		return Plugin_Handled;
	}

	int target = g_iPlayer[client].iInPartyWith;

	g_iPlayer[client].bIsInParty = false;
	g_iPlayer[target].bIsInParty = false;

	g_iPlayer[client].iInPartyWith = -1;
	g_iPlayer[target].iInPartyWith = -1;

	// RemoveDecalAbovePlayer(client);
	// RemoveDecalAbovePlayer(target);

	CPrintToChat(client, "%s %T", g_sPluginTag, "Party: No longer with", client, target);
	CPrintToChat(target, "%s %T", g_sPluginTag, "Party: No longer with", target, client);
	return Plugin_Handled;
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

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon) 
{
	if (!BB_IsClientValid(client) || !IsPlayerAlive(client) || GetClientTeam(client) == CS_TEAM_SPECTATOR)
	{
		return Plugin_Continue;
	}

	if ((GetClientTeam(client) == TEAM_BUILDERS && g_iStatus == Round_Building) || BB_CheckCommandAccess(client, "bb_move_blocks", g_cMoveBlocks, true))
	{
		if (!(g_iPlayer[client].iPlayerPrevButtons & IN_USE) && iButtons & IN_USE)
		{
			FirstTimePress(client);
		} 
		else if (iButtons & IN_USE)
		{
			StillPressingButton(client, iButtons);
		}
		else if (g_iPlayer[client].bOnceStopped)
		{
			StoppedMovingBlock(client);
		}

		if (iButtons & IN_RELOAD && !(g_iPlayer[client].iPlayerPrevButtons & IN_RELOAD))
		{
			if (g_iPlayer[client].bOnceStopped)
			{
				RotateBlock(client, g_iPlayer[client].iPlayerNewEntity);
			}
			else if (g_iStatus == Round_Building)
			{
				RotateBlock(client);
			}
		}

		g_iPlayer[client].iPlayerPrevButtons = iButtons;
	}

	return Plugin_Continue;
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
	LockBlock(client, 0);
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
	Format(sQuery, sizeof(sQuery), "INSERT INTO bb (CommunityID, Rotate, Color, Points, Level) VALUES (\"%s\", 45.0, %i, 0, 1) ON DUPLICATE KEY UPDATE Rotate = '%.1f', Color = %d, Points = %d, Level = %d", sCommunityID, g_iPlayer[client].iColor, g_iPlayer[client].fRotate, g_iPlayer[client].iColor, g_iPlayer[client].iPoints, g_iPlayer[client].iLevel);
	BB_Query("SQL_UpdatePlayer", sQuery);
}

stock void CheckClientLevel(int client)
{
	if (g_iPlayer[client].iPoints >= RoundToCeil(((g_iPlayer[client].iLevel + 1) * 0.4) * ((g_iPlayer[client].iLevel + 1) * 35)))
	{
		g_iPlayer[client].iPoints = 0;
		g_iPlayer[client].iLevel++;
		
		UpdatePlayer(client);

		CS_SetMVPCount(client, g_iPlayer[client].iLevel);

		LoopValidClients(i)
		{
			CPrintToChat(i, "%s %T", g_sPluginTag, "Main: New level", i, client, g_iPlayer[client].iLevel);
		}

		EmitSoundToAllAny("BaseBuilder/Special/LevelUp.mp3", client);
	}
}

stock void AcceptInvite(int client, int target)
{
	g_iPlayer[client].bIsInParty = true;
	g_iPlayer[target].bIsInParty = true;

	g_iPlayer[client].iInPartyWith = target;
	g_iPlayer[target].iInPartyWith = client;

	// g_iPlayer[client].iIcon = SpawnDecalAbovePlayer(client);
	// g_iPlayer[target].iIcon = SpawnDecalAbovePlayer(target);

	char sBuffer[8];
	IntToString(g_iPlayer[client].iInPartyWith, sBuffer, sizeof(sBuffer));
	DispatchKeyValue(g_iPlayer[client].iIcon, "globalname", sBuffer);

	IntToString(g_iPlayer[target].iInPartyWith, sBuffer, sizeof(sBuffer));
	DispatchKeyValue(g_iPlayer[target].iIcon, "globalname", sBuffer);

	// SDKHook(g_iPlayer[client].iIcon, SDKHook_SetTransmit, ShowFriendOverlay);
	// SDKHook(g_iPlayer[target].iIcon, SDKHook_SetTransmit, ShowFriendOverlay);

	CPrintToChat(client, "%s %T", g_sPluginTag, "Party: Team with", client, target);
	CPrintToChat(target, "%s %T", g_sPluginTag, "Party: Team with", target, client);

	if (g_iPlayer[client].iLocks > 0 || g_iPlayer[target].iLocks > 0)
	{
		if (g_iPlayer[client].bPartyOwner)
		{
			ColorBlockByClient(client, target);
		}
		else
		{
			ColorBlockByClient(target, client);
		}
	}
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
		return;
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

stock void RotateBlock(int client, int entity = INVALID_ENT_REFERENCE)
{
	if (entity == INVALID_ENT_REFERENCE)
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
			fAng[1] += g_iPlayer[client].fRotate;
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

stock void ColorBlockByClient(int client, int target = -1)
{
	int iEnt;

	while ((iEnt = FindEntityByClassname(iEnt, "prop_dynamic")) != INVALID_ENT_REFERENCE)
	{
		if (IsValidEntity(iEnt))
		{
			char sName[64];
			GetEntPropString(iEnt, Prop_Data, "m_iName", sName, sizeof(sName));

			char sGlobalName[64];
			GetEntPropString(iEnt, Prop_Data, "m_iGlobalname", sGlobalName, sizeof(sGlobalName));

			if (target != INVALID_ENT_REFERENCE)
			{
				if (StringToInt(sName) == client || StringToInt(sName) == target || StringToInt(sGlobalName) == client || StringToInt(sGlobalName) == target)
				{
					ColorBlock(client, iEnt, false);
				}
			}
			else
			{
				if (StringToInt(sName) == client || StringToInt(sGlobalName) == client)
				{
					ColorBlock(client, iEnt, false);
				}
			}
		}
	}
}

stock void FirstTimePress(int client)
{
	g_iPlayer[client].iPlayerSelectedBlock = GetTargetBlock(client);

	if (IsValidEntity(g_iPlayer[client].iPlayerSelectedBlock))
	{
		char sName[128];
		GetEntityClassname(g_iPlayer[client].iPlayerSelectedBlock, sName, sizeof(sName));

		if (!StrEqual(sName, "weaponworldmodel"))
		{
			int iOwner = GetBlockOwner(g_iPlayer[client].iPlayerSelectedBlock);
			int target = g_iPlayer[client].bIsInParty ? g_iPlayer[client].iInPartyWith : -1;

			if (iOwner == 0 || iOwner == client || iOwner == target)
			{
				g_iPlayer[client].bTakenWithNoOwner = iOwner == 0;
				g_iPlayer[client].bOnceStopped = true;

				if (!IsValidEntity(g_iPlayer[client].iPlayerNewEntity) || g_iPlayer[client].iPlayerNewEntity <= 0)
				{
					g_iPlayer[client].iPlayerNewEntity = CreateEntityByName("prop_dynamic");
				}

				float fTelVec[3];
				GetAimOrigin(client, fTelVec);
				TeleportEntity(g_iPlayer[client].iPlayerNewEntity, fTelVec, NULL_VECTOR, NULL_VECTOR);

				SetVariantString("!activator");
				AcceptEntityInput(g_iPlayer[client].iPlayerSelectedBlock, "SetParent", g_iPlayer[client].iPlayerNewEntity, g_iPlayer[client].iPlayerSelectedBlock, 0);

				float fPos[3], fPlayerPos[3];
				GetClientEyePosition(client, fPlayerPos);
				GetEntPropVector(g_iPlayer[client].iPlayerNewEntity, Prop_Send, "m_vecOrigin", fPos);

				g_iPlayer[client].fPlayerSelectedBlockDistance = GetVectorDistance(fPlayerPos, fPos);

				if (g_iPlayer[client].fPlayerSelectedBlockDistance > 250.0)
				{
					g_iPlayer[client].fPlayerSelectedBlockDistance = 250.0;
				}

				ColorBlock(client, g_iPlayer[client].iPlayerSelectedBlock, false);

				EmitSoundToClientAny(client, "BaseBuilder/Block_Grab.mp3");

				SetBlockOwner(g_iPlayer[client].iPlayerSelectedBlock, client);
				SetLastMover(g_iPlayer[client].iPlayerSelectedBlock, client);

				Call_StartForward(g_fwOnBlockMove);
				Call_PushCell(client);
				Call_PushCell(g_iPlayer[client].iPlayerSelectedBlock);
				Call_Finish();
			}
		}
	}
	
}

stock void StillPressingButton(int client, int &iButtons)
{
	if (iButtons & IN_ATTACK)
	{
		g_iPlayer[client].fPlayerSelectedBlockDistance += 1.0;		
	}
	else if (iButtons & IN_ATTACK2)
	{
		g_iPlayer[client].fPlayerSelectedBlockDistance -= 1.0;
	}

	MoveBlock(client);
}

stock void MoveBlock(int client)
{
	if (!IsValidEntity(g_iPlayer[client].iPlayerSelectedBlock) || !IsValidEntity(g_iPlayer[client].iPlayerNewEntity))
	{
		return;
	}

	float fPlayerPos[3], fPlayerAngle[3], fFinal[3];
	GetClientEyePosition(client, fPlayerPos);
	GetClientEyeAngles(client, fPlayerAngle);

	AddInFrontOf(fPlayerPos, fPlayerAngle, g_iPlayer[client].fPlayerSelectedBlockDistance, fFinal);

	TeleportEntity(g_iPlayer[client].iPlayerNewEntity, fFinal, NULL_VECTOR, NULL_VECTOR);
}

stock void StoppedMovingBlock(int client)
{
	if (IsValidEntity(g_iPlayer[client].iPlayerSelectedBlock))
	{
		ColorBlock(client, g_iPlayer[client].iPlayerSelectedBlock, g_iPlayer[client].bTakenWithNoOwner);

		EmitSoundToClientAny(client, "BaseBuilder/Block_Drop.mp3");

		SetVariantString("!activator");
		AcceptEntityInput(g_iPlayer[client].iPlayerSelectedBlock, "SetParent", g_iPlayer[client].iPlayerSelectedBlock, g_iPlayer[client].iPlayerSelectedBlock, 0);

		Call_StartForward(g_fwOnBlockStop);
		Call_PushCell(client);
		Call_PushCell(g_iPlayer[client].iPlayerSelectedBlock);
		Call_Finish();
	}
	
	g_iPlayer[client].bOnceStopped = false;

	if (g_iPlayer[client].bTakenWithNoOwner)
	{
		SetBlockOwner(g_iPlayer[client].iPlayerSelectedBlock, 0);
		LockBlock(client, g_iPlayer[client].iPlayerSelectedBlock);
	}
}

stock void LockBlock(int client, int entities = 0)
{
	if ((IsPlayerAlive(client) && GetClientTeam(client) == TEAM_BUILDERS && g_iStatus == Round_Building) || BB_CheckCommandAccess(client, "bb_lock_blocks", g_cLockBlocks, true)) {
		int entity = (entities == 0) ? GetTargetBlock(client) : entities;
			
		if (entity == -1)
		{
			return;
		}

		int owner = GetBlockOwner(entity);

		if (owner <= 0)
		{
			if(g_iPlayer[client].iLocks >= g_cMaxLocks.IntValue) {
				CPrintToChat(client, "%s %T", g_sPluginTag, "Main: Block lock limit", client, g_cMaxLocks.IntValue);
				return;
			}

			ColorBlock(client, entity, false);
			SetBlockOwner(entity, client);
			
			g_iPlayer[client].iLocks++;
		}
		else
		{
			if (client != owner && BB_CheckCommandAccess(client, "bb_lock_blocks", g_cLockBlocks, true))
			{
				CPrintToChat(client, "%s %T", g_sPluginTag, "Main: Block blocked by", client, owner);
			}
			else if (!g_iPlayer[client].bOnceStopped)
			{
				ColorBlock(client, entity, true);
				SetBlockOwner(entity, 0);

				g_iPlayer[client].iLocks--;
			}
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