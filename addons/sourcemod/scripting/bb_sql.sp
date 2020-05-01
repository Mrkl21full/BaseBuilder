#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <basebuilder>
#include <basebuilder_sql>

#define PLUGIN_NAME BB_PLUGIN_NAME ... " - SQL Manager"

Database g_dDatabase = null;

ConVar g_cEntry = null;
ConVar g_cRetries = null;

char g_sType[18];
int g_iRetries = -1;

GlobalForward g_fwOnConnect = null;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("BB_Query", Native_Query);
    CreateNative("BB_GetSQLConnection", Native_GetSQLConnection);

    g_fwOnConnect = new GlobalForward("BB_OnSQLConnect", ET_Ignore, Param_Cell);

    RegPluginLibrary("basebuilder_sql");

    return APLRes_Success;
}

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = BB_PLUGIN_AUTHOR,
    description = BB_PLUGIN_DESCRIPTION,
    version = BB_PLUGIN_VERSION,
    url = BB_PLUGIN_URL
};

public void OnPluginStart()
{
    BB_IsGameCSGO();

    BB_StartConfig("sql");
    CreateConVar("bb_sql_version", BB_PLUGIN_VERSION, BB_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cRetries = AutoExecConfig_CreateConVar("sql_max_retries", "3", "The amount of retries after first failed connection");
    g_cEntry = AutoExecConfig_CreateConVar("sql_database_entry_name", "basebuilder", "The name of the entry in your databases.cfg");
    BB_EndConfig();

    g_iRetries = 0;
}

public void OnConfigsExecuted()
{
    SQL_Start();
}

void SQL_Start()
{
    char sEntry[32];
    g_cEntry.GetString(sEntry, sizeof(sEntry));
    
    if (g_dDatabase != null)
    {
        LogMessage("(SQL_Start) %s is already connected! (Handle: %d)", sEntry, g_dDatabase);
        Call_OnSQLConnect();
        return;
    }

    if (g_iRetries > g_cRetries.IntValue)
    {
        LogError("(SQL_Start) Can't connect to a database after %d retries!", g_iRetries-1);
        return;
    }

    if (g_iRetries >= 1 && g_iRetries <= g_cRetries.IntValue)
    {
        LogMessage("(SQL_Start) We try again to connect to a database (Retry #%d)!", g_iRetries);
    }

    if (!SQL_CheckConfig(sEntry) && g_iRetries < g_cRetries.IntValue)
    {
        LogError("(SQL_Start) Couldn't find an \"%s\"-entry in your databases.cfg...", sEntry);

        delete g_dDatabase;

        char sError[255];
        g_dDatabase = SQL_Connect(sEntry, true, sError, sizeof(sError));

        if (strlen(sError) > 1)
        {
            delete g_dDatabase;
            LogError("(SQL_Start) Error: %s", sError);
        }

        if (g_dDatabase == null)
        {
            LogError("(SQL_Start) Database failure: Couldn't connect to \"%s\"!", sEntry);
            CreateTimer(5.0, Timer_Retry);
            return;
        }
        else
        {
            LogMessage("(SQL_Start) We have a connection!");
            DBDriver iDriver = g_dDatabase.Driver;
            iDriver.GetIdentifier(g_sType, sizeof(g_sType));
            CheckAndCreateTables();
            return;
        }
    }
    else
    {
        Database.Connect(OnConnect, sEntry);
    }
}

public void OnConnect(Database db, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        LogMessage("(OnConnect) Connection to database failed: %s", error);
        CreateTimer(5.0, Timer_Retry);
        return;
    }

    DBDriver iDriver = db.Driver;
    iDriver.GetIdentifier(g_sType, sizeof(g_sType));

    if (!StrEqual(g_sType, "mysql", false))
    {
        SetFailState("(OnConnect) We found an unsupported database driver (%s). We only support mysql.", g_sType);
        return;
    }

    delete g_dDatabase;
    
    if (db != null)
    {
        g_dDatabase = db;
    }

    CheckAndCreateTables();
}

public Action Timer_Retry(Handle timer)
{
    g_iRetries++;

    SQL_Start();
}

void Call_OnSQLConnect()
{
    Call_StartForward(g_fwOnConnect);
    Call_PushCell(g_dDatabase);
    Call_Finish();
}

void CheckAndCreateTables()
{
    BB_Query("SQL_CreateMainBaseBuilderTable", "CREATE TABLE IF NOT EXISTS `bb` ( `ID` INT NOT NULL AUTO_INCREMENT , `CommunityID` VARCHAR(64) NOT NULL , `Color` INT NOT NULL DEFAULT 0, `Points` INT NOT NULL DEFAULT 0, `Level` INT NOT NULL DEFAULT 1, PRIMARY KEY (`ID`), UNIQUE (`CommunityID`)) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;");
    BB_Query("SQL_CreateBaseBuilderRoundTable", "CREATE TABLE IF NOT EXISTS `bb_rounds` ( `ID` INT NOT NULL AUTO_INCREMENT , `Start` INT NOT NULL DEFAULT 0 , `End` INT NOT NULL DEFAULT 0, PRIMARY KEY (`id`)) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;");

    SetCharsetAndCollate();
}

void SetCharsetAndCollate()
{
    g_dDatabase.SetCharset("utf8mb4");
    BB_Query("SQL_ConvertToUTF8MB4", "ALTER TABLE bb CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;");
    Call_OnSQLConnect();
}

public int Native_Query(Handle plugin, int numParams)
{
    char sDebug[128];
    char sQuery[2048];
    GetNativeString(1, sDebug, sizeof(sDebug));
    GetNativeString(2, sQuery, sizeof(sQuery));

    DataPack pack = new DataPack();
    pack.WriteString(sDebug);
    g_dDatabase.Query(SQL_QueryCB, sQuery, pack);

    return 0;
}

public void SQL_QueryCB(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    if (db == null || strlen(error) > 0)
    {
        pack.Reset();
        char sBuffer[128];
        pack.ReadString(sBuffer, sizeof(sBuffer));

        LogError("[SQL] (%s) Query failed: %s", sBuffer, error);
    }
    
    delete pack;
}

public int Native_GetSQLConnection(Handle plugin, int numParams)
{
    return view_as<int>(g_dDatabase);
}
