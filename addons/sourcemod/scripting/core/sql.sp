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

    // TODO: Set level / insert player to db.
}
