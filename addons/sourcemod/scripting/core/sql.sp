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
        g_iPlayer[client].iColor = results.FetchInt(0);
        g_iPlayer[client].iPoints = results.FetchInt(1);
        g_iPlayer[client].iLevel = results.FetchInt(2);
    }
    else
    {
        g_iPlayer[client].iColor = GetRandomInt(0, sizeof(g_iColorRed) - 1);
        g_iPlayer[client].iPoints = 0;
        g_iPlayer[client].iLevel = 1;

        UpdatePlayer(client);
    }
}
