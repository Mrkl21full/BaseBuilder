void SetupConfig()
{
	CreateConVar("bb_version", BB_PLUGIN_VERSION, BB_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cPluginTag = AutoExecConfig_CreateConVar("bb_plugin_tag", "{blue}[BaseBuilder]{default}", "The prefix used in all plugin messages.");
	g_cWarmupTime = AutoExecConfig_CreateConVar("bb_warmup_time", "20", "Time for warmup. (0 to disable warmup)", _, true, 5.0);
	g_cPrepTime = AutoExecConfig_CreateConVar("bb_prep_time", "30", "Time for builders to enter thier base.", _, true, 5.0);
	g_cBuildTime = AutoExecConfig_CreateConVar("bb_build_time", "150", "Time for builders to build thier base.", _, true, 60.0);
	g_cRoundTime = AutoExecConfig_CreateConVar("bb_round_time", "210", "Max round time in seconds.", _, true, 60.0);
	g_cInviteTime = AutoExecConfig_CreateConVar("bb_invite_time", "15", "Time in seconds for invite to reset.", _, true, 10.0);
	g_cRespawnZombie = AutoExecConfig_CreateConVar("bb_respawn_zombie", "2", "How much times zombie can commit suicide during active round? (0 to disable)", _, true, 0.0);
	g_cMaxLocks = AutoExecConfig_CreateConVar("bb_max_locks", "10", "How much blocks can player lock.", _, true, 5.0);
	g_cScrambleTeams = AutoExecConfig_CreateConVar("bb_scramble_teams_warmup", "1", "Scramble teams after warmup ends?", _, true, 0.0, true, 1.0);
	g_cRemoveNotUsedBlocks = AutoExecConfig_CreateConVar("bb_remove_not_used_blocks", "1", "Removes unused blocks when preparation time starts.", _, true, 0.0, true, 1.0);
	g_cRemoveBlockAfterDeath = AutoExecConfig_CreateConVar("bb_remove_block_after_death", "1", "Removes blocks when player dies (or disconnect).", _, true, 0.0, true, 1.0);
	g_cPushPlayersOfBlocks = AutoExecConfig_CreateConVar("bb_push_players_of_blocks", "1", "Push player away from base if this base is not thiers.", _, true, 0.0, true, 1.0);

	g_cPluginTag.AddChangeHook(OnConVarChanged);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cPluginTag)
	{
		Format(g_sPluginTag, sizeof(g_sPluginTag), newValue);
	}
}
