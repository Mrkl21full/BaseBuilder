public void SQL_InsertRound(Database db, DBResultSet results, const char[] error, int userid)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(SQL_InsertRound) Query failed: %s", error);
        return;
    }

    g_iRoundID = results.InsertId;
    g_iRoundTime = g_cRoundTime.IntValue;
    g_iStatus = Round_Active;

    int iTeam, iRandom, iBuilders = 0, iZombies = 0;

    LoopValidClients(i)
    {
        iTeam = GetClientTeam(i);

        if (iTeam == CS_TEAM_SPECTATOR)
        {
            CS_SwitchTeam(i, TEAM_ZOMBIES);
        }

        if (!IsPlayerAlive(i))
        {
            CreateTimer(0.0, Timer_RespawnPlayer, i);
        }
        
        SetEntProp(i, Prop_Send, "m_fEffects", 0);
        
        CS_SetMVPCount(i, g_iPlayer[i].iLevel);

        for (int offset = 0; offset < 128; offset += 4)
        {
            int weapon = GetEntDataEnt2(i, FindSendPropInfo("CBasePlayer", "m_hMyWeapons") + offset);

            if (IsValidEntity(weapon))
            {
                char sClass[32];
                GetEntityClassname(weapon, sClass, sizeof(sClass));

                if (StrContains(sClass, "weapon_", false) != -1)
                {
                    SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() - 0.1);
                    SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() - 0.1);
                }
            }
        }

        if (iTeam == TEAM_ZOMBIES)
        {
            iZombies++;

            iRandom = GetRandomInt(0, g_iSpawns - 1);

            TeleportEntity(i, g_fSpawnLocation[iRandom], g_fSpawnAngles[iRandom], NULL_VECTOR);
        } 
        else if (iTeam == TEAM_BUILDERS)
        {
            iBuilders++;

            if (g_iPlayer[i].bIsInParty)
            {
                g_iPlayer[i].iIcon = -1;
            }
        }

        CPrintToChat(i, "%s %T", g_sPluginTag, "Main: Round begun", i, g_iRoundID);
    }

    Call_StartForward(g_fwOnRoundStart);
    Call_PushCell(g_iRoundID);
    Call_PushCell(iZombies);
    Call_PushCell(iBuilders);
    Call_Finish();
}

public void SQL_OnClientPutInServer(Database db, DBResultSet results, const char[] error, int userid)
{
    int client = GetClientOfUserId(userid);

    if (!BB_IsClientValid(client) || IsFakeClient(client))
    {
        return;
    }

    if (db == null || strlen(error) > 0)
    {
        SetFailState("(SQL_OnClientPutInServer) Query failed: %s", error);
        return;
    }

    if (results.RowCount > 0 && results.FetchRow())
    {
        g_iPlayer[client].fRotate = results.FetchFloat(0);
        g_iPlayer[client].iColor = results.FetchInt(1);
        g_iPlayer[client].iPoints = results.FetchInt(2);
        g_iPlayer[client].iLevel = results.FetchInt(3);
    }
    else
    {
        g_iPlayer[client].fRotate = 45.0;
        g_iPlayer[client].iColor = GetRandomInt(0, sizeof(g_iColorRed) - 1);
        g_iPlayer[client].iPoints = 0;
        g_iPlayer[client].iLevel = 1;

        UpdatePlayer(client);
    }
}
