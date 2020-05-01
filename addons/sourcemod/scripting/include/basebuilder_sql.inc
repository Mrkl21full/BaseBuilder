#if defined _basebuilder_sql_included
    #endinput
#endif
#define _basebuilder_sql_included

native void BB_Query(const char[] debugname, const char[] query);

native Database BB_GetSQLConnection();

forward void BB_OnSQLConnect(Database db);
