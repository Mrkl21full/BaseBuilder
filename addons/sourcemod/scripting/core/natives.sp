void InitForwards()
{
    g_fwOnWarmupEnd = new GlobalForward("BB_OnWarmupEnd", ET_Ignore);
    g_fwOnBuildStart = new GlobalForward("BB_OnBuildStart", ET_Ignore);
    g_fwOnPrepStart = new GlobalForward("BB_OnPrepStart", ET_Ignore);
    g_fwOnRoundStart = new GlobalForward("BB_OnRoundStart", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_fwOnRoundEnd = new GlobalForward("BB_OnRoundEnd", ET_Ignore, Param_Cell);

    g_fwOnBlockMove = new GlobalForward("BB_OnBlockMove", ET_Ignore, Param_Cell, Param_Cell);
    g_fwOnBlockStop = new GlobalForward("BB_OnBlockStop", ET_Ignore, Param_Cell, Param_Cell);
}

void InitNatives()
{
    CreateNative("BB_GetRoundID", Native_GetRoundID);
    CreateNative("BB_IsBuildTime", Native_IsBuildTime);
    CreateNative("BB_IsPrepTime", Native_IsPrepTime);
    CreateNative("BB_ForceZombie", Native_ForceZombie);
    CreateNative("BB_ForceBuilder", Native_ForceBuilder);
    CreateNative("BB_TeleportToBuilders", Native_TeleportToBuilders);
    CreateNative("BB_TeleportToZombies", Native_TeleportToZombies);

    CreateNative("BB_IsClientInParty", Native_IsClientInParty);
    CreateNative("BB_GetClientPartyPerson", Native_GetClientPartyPerson);

    CreateNative("BB_GetClientLevel", Native_GetClientLevel);
    CreateNative("BB_GetClientPoints", Native_GetClientPoints);

    CreateNative("BB_GetRoundStatus", Native_GetRoundStatus);

    CreateNative("BB_CheckCommandAccess", Native_CheckCommandAccess);
}

public int Native_GetRoundID(Handle plugin, int numParams)
{
    return g_iRoundID;
}

public int Native_IsBuildTime(Handle plugin, int numParams)
{
    return g_bIsBuildTime;
}

public int Native_IsPrepTime(Handle plugin, int numParams)
{
    return g_bIsPrepTime;
}

public int Native_ForceZombie(Handle plugin, int numParams)
{
    // TODO: Force zombie
}

public int Native_ForceBuilder(Handle plugin, int numParams)
{
    // TODO: Force builder
}

public int Native_TeleportToBuilders(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (BB_IsClientValid(client))
    {
        if (!IsPlayerAlive(client))
        {
            CS_RespawnPlayer(client);
        }

        int iRandom = GetRandomInt(0, g_iSpawns - 1);

        TeleportEntity(client, g_fSpawnLocation[iRandom], g_fSpawnAngles[iRandom], NULL_VECTOR);
    }
}

public int Native_TeleportToZombies(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (BB_IsClientValid(client))
    {
        if (!IsPlayerAlive(client))
        {
            CS_RespawnPlayer(client);
        }

        float fLocation[3];
        GetEntPropVector(FindEntityByClassname(-1, "info_player_terrorist"), Prop_Data, "m_vecOrigin", fLocation);

        TeleportEntity(client, fLocation, NULL_VECTOR, NULL_VECTOR);
    }
}

public int Native_IsClientInParty(Handle plugin, int numParams)
{
    return g_iPlayer[GetNativeCell(1)].bIsInParty;
}

public int Native_GetClientPartyPerson(Handle plugin, int numParams)
{
    return g_iPlayer[GetNativeCell(1)].bIsInParty ? g_iPlayer[GetNativeCell(1)].iInPartyWith : -1;
}

public int Native_GetClientLevel(Handle plugin, int numParams)
{
    return g_iPlayer[GetNativeCell(1)].iLevel;
}

public int Native_GetClientPoints(Handle plugin, int numParams)
{
    return g_iPlayer[GetNativeCell(1)].iPoints;
}

public int Native_GetRoundStatus(Handle plugin, int numParams)
{
    return view_as<int>(g_iStatus);
}

public int Native_CheckCommandAccess(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char sCommand[32];
    GetNativeString(2, sCommand, sizeof(sCommand));

    ConVar cvar = view_as<ConVar>(GetNativeCell(3));

    bool override_only = view_as<bool>(GetNativeCell(4));

    char sFlags[24];
    cvar.GetString(sFlags, sizeof(sFlags));

    if (strlen(sFlags) < 1)
    {
        return false;
    }
    
    int iFlags = ReadFlagString(sFlags);
    
    if (CheckCommandAccess(client, sCommand, iFlags, override_only))
    {
        return true;
    }

    return false;
}
