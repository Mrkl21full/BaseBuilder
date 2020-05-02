#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <clientprefs>
#include <basebuilder>
#include <basebuilder_sql>
#include <basebuilder_shop>

#define PLUGIN_NAME BB_PLUGIN_NAME ... " - Shop"

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = BB_PLUGIN_AUTHOR,
    description = BB_PLUGIN_DESCRIPTION,
    version = BB_PLUGIN_VERSION,
    url = BB_PLUGIN_URL
};

Database g_dDatabase = null;

ArrayList g_aShopItems = null;

ConVar g_cSortItems = null;
ConVar g_cBuilderKill = null;
ConVar g_cZombieKill = null;
ConVar g_cBuilderWin = null;
ConVar g_cZombieWin = null;
ConVar g_cShowEarnCreditsMessage = null;
ConVar g_cShowLoseCreditsMessage = null;
ConVar g_cCreditsType = null;
ConVar g_cStartCredits = null;
ConVar g_cMessageTypCredits = null;
ConVar g_cResetCreditsEachRound = null;
ConVar g_cReopenMenu = null;
ConVar g_cCredits = null;
ConVar g_cBuyCmd = null;
ConVar g_cShowCmd = null;
ConVar g_cMoneyCredits = null;
ConVar g_cShopCMDs = null;
ConVar g_cItemsMenu = null;
ConVar g_cShopMenuTime = null;
ConVar g_cTestingMode = null;
ConVar g_cShowItems = null;
ConVar g_cGiveItem = null;
ConVar g_cSetCredits = null;
ConVar g_cResetItems = null;
ConVar g_cListItems = null;
ConVar g_cReloadDiscount = null;
ConVar g_cReloadFlag = null;

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

GlobalForward g_fwOnItemPurchasePost = null;
GlobalForward g_fwOnItemPurchasePre = null;
GlobalForward g_fwOnCreditsGiven_Pre = null;
GlobalForward g_fwOnCreditsGiven = null;
GlobalForward g_fwOnShopReady = null;
GlobalForward g_fwRegisterShopItemPost = null;
GlobalForward g_fwOnStartCredits = null;

Cookie g_coReopen = null;

char g_sDiscountFile[PLATFORM_MAX_PATH + 1];
char g_sFlagsFile[PLATFORM_MAX_PATH + 1];

int g_iCommands = -1;
char g_sCommandList[6][32];

StringMap g_smDiscountPercent = null;
StringMap g_smDiscountFlag = null;
StringMap g_smAccessFlag = null;
StringMap g_smPurchases = null;

enum struct Item
{
    char Long[64];
    char Short[16];
    int Price;
    int Role;
    int Sort;
    int MaxUsages;
    int Limit;

    Handle Plugin;
    Function Callback;
}

enum struct PlayerData 
{
    int Credits;

    float Holder;

    bool Reopen;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];
StringMap g_smUsages[MAXPLAYERS + 1] = { null, ...};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_fwOnItemPurchasePost = new GlobalForward("BB_OnItemPurchasePost", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_String);
    g_fwOnItemPurchasePre = new GlobalForward("BB_OnItemPurchasePre", ET_Event, Param_Cell, Param_CellByRef, Param_CellByRef, Param_String);
    g_fwOnCreditsGiven_Pre = new GlobalForward("BB_OnCreditsChanged_Pre", ET_Event, Param_Cell, Param_Cell, Param_CellByRef);
    g_fwOnCreditsGiven = new GlobalForward("BB_OnCreditsChanged", ET_Ignore, Param_Cell, Param_Cell);
    g_fwOnShopReady = new GlobalForward("BB_OnShopReady", ET_Ignore);
    g_fwRegisterShopItemPost = new GlobalForward("BB_OnRegisterShopItemPost", ET_Ignore, Param_String, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_fwOnStartCredits = new GlobalForward("BB_OnStartCredits", ET_Event, Param_Cell, Param_CellByRef);

    CreateNative("BB_RegisterShopItem", Native_RegisterShopItem);
    CreateNative("BB_GetItemPrice", Native_GetItemPrice);
    CreateNative("BB_GetItemRole", Native_GetItemRole);
    CreateNative("BB_UpdateShopItem", Native_UpdateShopItem);
    CreateNative("BB_RemoveShopItem", Native_RemoveShopItem);
    CreateNative("BB_GetItemName", Native_GetItemName);
    CreateNative("BB_ShopItemExist", Native_ShopItemExist);
    CreateNative("BB_GetItemMaxUsages", Native_GetItemMaxUsages);
    CreateNative("BB_GetItemLimit", Native_GetItemLimit);

    CreateNative("BB_GetClientCredits", Native_GetClientCredits);
    CreateNative("BB_SetClientCredits", Native_SetClientCredits);
    CreateNative("BB_AddClientCredits", Native_AddClientCredits);
    CreateNative("BB_GiveClientItem", Native_GiveClientItem);
    CreateNative("BB_GetItemUsages", Native_GetItemUsages);
    CreateNative("BB_AddItemUsage", Native_AddItemUsage);
    CreateNative("BB_RemoveItemUsage", Native_RemoveItemUsage);
    CreateNative("BB_SetItemUsage", Native_SetItemUsage);

    CreateNative("BB_GetItemDiscount", Native_GetItemDiscount);
    CreateNative("BB_CheckItemAccess", Native_CheckItemAccess);

    RegPluginLibrary("basebuilder_shop");

    return APLRes_Success;
}

public void OnPluginStart()
{
    BB_IsGameCSGO();
    BB_LoadTranslations();

    RegConsoleCmd("sm_reopenshop", Command_ReopenShop);
    RegConsoleCmd("sm_roshop", Command_ReopenShop);
    RegConsoleCmd("sm_reshop", Command_ReopenShop);
    RegConsoleCmd("sm_rshop", Command_ReopenShop);
    RegConsoleCmd("sm_giveitem", Command_GiveItem);
    RegConsoleCmd("sm_setcredits", Command_SetCredits);
    RegConsoleCmd("sm_resetitems", Command_ResetItems);
    RegConsoleCmd("sm_listitems", Command_ListItems);
    RegConsoleCmd("sm_reload_discount", Command_ReloadDiscount);
    RegConsoleCmd("sm_reload_flags", Command_ReloadFlag);

    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say_team");

    HookEvent("player_spawn", Event_OnPlayerSpawn);
    HookEvent("player_death", Event_OnPlayerDeath);

    BB_StartConfig("shop");
    CreateConVar("bb_shop_version", BB_PLUGIN_VERSION, BB_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cSortItems = AutoExecConfig_CreateConVar("bb_sort_items", "1", "Sort shop items? 0 = Disabled. 1 = Enabled (default).", _, true, 0.0, true, 1.0);
    g_cBuilderKill = AutoExecConfig_CreateConVar("bb_credits_killer_builder", "2", "The amount of credits an builder will gain on zombie kill.");
    g_cZombieKill = AutoExecConfig_CreateConVar("bb_credits_killer_zombie", "5", "The amount of credits an zombie will gain on builder kill.");

    g_cBuilderWin = AutoExecConfig_CreateConVar("bb_credits_roundend_builder", "8", "The amount of credits an builder will recieve for winning the round if they survived.");
    g_cZombieWin = AutoExecConfig_CreateConVar("bb_credits_roundend_zombie", "5", "The amount of credits an zombie will recieve for winning the round.");
    
    g_cShowEarnCreditsMessage = AutoExecConfig_CreateConVar("bb_show_message_earn_credits", "1", "Display a message showing how many credits you earned. 1 = Enabled, 0 = Disabled", _, true, 0.0, true, 1.0);
    g_cShowLoseCreditsMessage = AutoExecConfig_CreateConVar("bb_show_message_lose_credits", "1", "Display a message showing how many credits you lost. 1 = Enabled, 0 = Disabled", _, true, 0.0, true, 1.0);

    g_cCreditsType = AutoExecConfig_CreateConVar("bb_credits_type", "1", "Should credits be stored in database? 1 = Enabled (default), 0 Disabled (0 means that credits will reset on everymap change).");
    g_cStartCredits = AutoExecConfig_CreateConVar("bb_start_credits", "0", "The amount of credits players will recieve when they join for the first time.");
    g_cMessageTypCredits = AutoExecConfig_CreateConVar("bb_message_typ_credits", "1", "The credit message type. 1 = Hint Text, 2 = Chat Message", _, true, 1.0, true, 2.0);
    g_cResetCreditsEachRound = AutoExecConfig_CreateConVar("bb_credits_reset_each_round", "0", "Reset credits for all players each round?. 0 = Disabled (default). 1 = Enabled.", _, true, 0.0, true, 1.0);
    
    g_cReopenMenu = AutoExecConfig_CreateConVar("bb_menu_reopen", "1", "Reopen the shop menu, after buying something.", _, true, 0.0, true, 1.0);
    g_cCredits = AutoExecConfig_CreateConVar("bb_credits_command", "credits", "The command to show the credits");
    g_cBuyCmd = AutoExecConfig_CreateConVar("bb_shop_buy_command", "buyitem", "The command to buy a shop item instantly (by shortname)");
    g_cShowCmd = AutoExecConfig_CreateConVar("bb_shop_show_command", "showitems", "The command to show the shortname of the shopitems (to use for the buycommand)");
    g_cMoneyCredits = AutoExecConfig_CreateConVar("bb_shop_show_credits_as_money", "1", "Show player credits as csgo money? (limit 65535)", _, true, 0.0, true, 1.0);
    g_cShopCMDs = AutoExecConfig_CreateConVar("bb_shop_commands", "shop", "Commands for bb shop (up to 6 commands)");
    g_cItemsMenu = AutoExecConfig_CreateConVar("bb_hide_disable_items_menu", "1", "How should unavailable (not enough credits or max usages reached) items be handled? (0 - Enabled with text message, 1 - Disable item in menu (default), 2 - Hide item in menu", _, true, 0.0, true, 2.0);
    g_cShopMenuTime = AutoExecConfig_CreateConVar("bb_shop_menu_time", "15", "How long shop menu should be displayed.");
    g_cTestingMode = AutoExecConfig_CreateConVar("bb_enable_testing_mode", "0", "Enable testing mode for shop? All items will be free without any limits!", _, true, 0.0, true, 1.0);

    g_cShowItems = AutoExecConfig_CreateConVar("bb_show_items", "z", "Admin flags to show items");
    g_cGiveItem = AutoExecConfig_CreateConVar("bb_give_item", "z", "Admin flags to give item");
    g_cSetCredits = AutoExecConfig_CreateConVar("bb_set_credits", "z", "Admin flags to set client credits");
    g_cResetItems = AutoExecConfig_CreateConVar("bb_reset_items", "z", "Admin flags to reset array with items");
    g_cListItems = AutoExecConfig_CreateConVar("bb_list_items", "z", "Admin flags to list items");
    g_cReloadDiscount = AutoExecConfig_CreateConVar("bb_reload_discount", "z", "Admin flags to reload discount file");
    g_cReloadFlag = AutoExecConfig_CreateConVar("bb_reload_flag", "z", "Admin flags to reload flags file");
    BB_EndConfig();

    LoadTranslations("common.phrases");

    BuildPath(Path_SM, g_sDiscountFile, sizeof(g_sDiscountFile), "configs/basebuilder/shop_discounts.ini");
    BuildPath(Path_SM, g_sFlagsFile, sizeof(g_sFlagsFile), "configs/basebuilder/shop_flags.ini");

    g_coReopen = new Cookie("bb_reopen_shop", "Cookie to reopen shop menu", CookieAccess_Private);

    ResetItemsArray("OnPluginStart", true);
}

public void OnConfigsExecuted()
{
    g_cPluginTag = FindConVar("bb_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    
    char sBuffer[32];
    g_cCredits.GetString(sBuffer, sizeof(sBuffer));
    Format(sBuffer, sizeof(sBuffer), "sm_%s", sBuffer);
    
    if (!CommandExists(sBuffer))
    {
        RegConsoleCmd(sBuffer, Command_Credits);
    }

    g_cBuyCmd.GetString(sBuffer, sizeof(sBuffer));
    Format(sBuffer, sizeof(sBuffer), "sm_%s", sBuffer);
    
    if (!CommandExists(sBuffer)) 
    {
        RegConsoleCmd(sBuffer, Command_Buy);
    }

    g_cShowCmd.GetString(sBuffer, sizeof(sBuffer));
    Format(sBuffer, sizeof(sBuffer), "sm_%s", sBuffer);
    
    if (!CommandExists(sBuffer))
    {
        RegConsoleCmd(sBuffer, Command_ShowItems);
    }

    char sCVarCMD[64];
    g_cShopCMDs.GetString(sCVarCMD, sizeof(sCVarCMD));

    g_iCommands = ExplodeString(sCVarCMD, ";", g_sCommandList, sizeof(g_sCommandList), sizeof(g_sCommandList[]));

    for (int i = 0; i < g_iCommands; i++)
    {
        char sCommand[32];
        Format(sCommand, sizeof(sCommand), "sm_%s", g_sCommandList[i]);
        RegConsoleCmd(sCommand, Command_Shop);
    }

    LoadShopFile(g_sDiscountFile);
    LoadShopFile(g_sFlagsFile);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public void BB_OnSQLConnect(Database db) 
{
    g_dDatabase = db;

    if (g_cCreditsType.BoolValue && !g_cResetCreditsEachRound.BoolValue)
    {
        BB_Query("SQL_AlterCreditsColumn", "ALTER TABLE `bb` ADD COLUMN `Credits` INT(11) NOT NULL DEFAULT 0 AFTER `Level`");
    }
}

void UpdatePlayer(int client, bool save = false)
{
    if (IsFakeClient(client) || IsClientSourceTV(client))
    {
        return;
    }

    if (g_cMoneyCredits.BoolValue)
    {
        SetEntProp(client, Prop_Send, "m_iAccount", g_iPlayer[client].Credits);
    }

    if (save && g_cCreditsType.BoolValue)
    {
        char sQuery[256], sCommunityID[64];
        GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID));
        Format(sQuery, sizeof(sQuery), "UPDATE `bb` SET `Credits` = %d WHERE CommunityID = \"%s\"", g_iPlayer[client].Credits, sCommunityID);
        BB_Query("SQL_UpdateShopPlayer", sQuery);
    }   
}

public void OnClientCookiesCached(int client)
{
    if (AreClientCookiesCached(client))
    {
        char sBuffer[4];
        g_coReopen.Get(client, sBuffer, sizeof(sBuffer));
        g_iPlayer[client].Reopen = view_as<bool>(StringToInt(sBuffer));
    } 
    else
    {
        char sBuffer[4];
        IntToString(view_as<int>(true), sBuffer, sizeof(sBuffer));
        g_coReopen.Set(client, sBuffer);
    }
}

public Action Command_Buy(int client, int args)
{
    if (!BB_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (args < 1)
    {
        char sBuffer[32];
        g_cBuyCmd.GetString(sBuffer, sizeof(sBuffer));
        CReplyToCommand(client, "%s Usage: %s <item_short_name>", g_sPluginTag, g_cBuyCmd);
        return Plugin_Handled;
    }

    if (!IsPlayerAlive(client))
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Not alive", client);
        return Plugin_Handled;
    }

    char sItem[16];
    GetCmdArg(1, sItem, sizeof(sItem));

    if (strlen(sItem) > 0)
    {
        ClientBuyItem(client, sItem, false);
    }

    return Plugin_Handled;
}

public Action Command_ShowItems(int client, int args)
{
    if (!BB_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!BB_CheckCommandAccess(client, "bb_shop_show_items", g_cShowItems, true))
    {
        return Plugin_Handled;
    }

    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);

        if (strlen(item.Short) > 1)
        {
            PrintToConsole(client, "Name: %s (%s) - Roles: %d - Price: %i - Max Usages: %d, Limit: %d", item.Long, item.Short, item.Role, item.Price, item.MaxUsages, item.Limit);
        }
    }

    return Plugin_Handled;
}

public Action Command_Shop(int client, int args)
{
    if (!BB_IsClientValid(client) || g_iPlayer[client].Holder > GetGameTime())
    {
        return Plugin_Handled;
    }

    g_iPlayer[client].Holder = GetGameTime() + 0.5;

    if (BB_GetRoundStatus() == Round_Inactive)
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Buy in active round", client);
        return Plugin_Handled;
    }

    if (!IsPlayerAlive(client))
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Not alive", client);
        return Plugin_Handled;
    }

    int team = GetClientTeam(client);

    if (team == CS_TEAM_SPECTATOR)
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Not spectator", client);
        return Plugin_Handled;
    }
    
    Menu menu = new Menu(Menu_ShopHandler);
    menu.SetTitle("%T", "Shop: Title", client, g_iPlayer[client].Credits);

    char sDisplay[128];
    int iCount = 0;
    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);

        if (strlen(item.Short) > 1)
        {
            if ((item.Role == 1) || (item.Role == team))
            {
                int iPrice = item.Price;

                bool bAvailable = true;

                if (!BB_CheckItemAccess(client, item.Short))
                {
                    bAvailable = false;
                }
                
                bool bDiscount = false;
                int iPercents = BB_GetItemDiscount(client, item.Short);

                if (iPercents > 0)
                {
                    float fPercentage = iPercents / 100.0;
                    int iDiscount = RoundToCeil(iPrice * fPercentage);
                    iPrice = item.Price - iDiscount;
                    bDiscount = true;
                }

                if (iPrice > g_iPlayer[client].Credits)
                {
                    bAvailable = false;
                }

                if (g_smPurchases == null)
                {
                    g_smPurchases = new StringMap();
                }

                int iPurchases = -1;
                g_smPurchases.GetValue(item.Short, iPurchases);

                if (item.Limit > 0 && iPurchases >= item.Limit)
                {
                    bAvailable = false;
                }

                if (g_smUsages[client] == null)
                {
                    g_smUsages[client] = new StringMap();
                    g_smUsages[client].SetValue(item.Short, 0);
                }

                if (bAvailable)
                {
                    int iUsages;
                    g_smUsages[client].GetValue(item.Short, iUsages);

                    if (iUsages >= item.MaxUsages)
                    {
                        bAvailable = false;
                    }
                }

                if (g_cItemsMenu.IntValue == 2 && !bAvailable)
                {
                    continue;
                }
                
                if (bDiscount)
                {
                    Format(sDisplay, sizeof(sDisplay), "%s - %d$ (-%d%)", item.Long, iPrice, iPercents);
                } 
                else 
                {
                    Format(sDisplay, sizeof(sDisplay), "%s - %d$", item.Long, iPrice);
                }

                if (g_cItemsMenu.IntValue == 1 && !bAvailable)
                {
                    menu.AddItem(item.Short, sDisplay, ITEMDRAW_DISABLED);
                } 
                else
                {
                    menu.AddItem(item.Short, sDisplay);
                }

                iCount++;
            }
        }
    }

    menu.ExitButton = true;

    if (iCount > 0)
    {
        menu.Display(client, g_cShopMenuTime.IntValue);
    } 
    else
    {
        delete menu;
    }

    return Plugin_Handled;

}

public Action Command_ReopenShop(int client, int args)
{
    if (!BB_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    char sTranslation[32];
    Format(sTranslation, sizeof(sTranslation), "Shop: Reopen");

    if (g_iPlayer[client].Reopen)
    {
        g_iPlayer[client].Reopen = false;

        Format(sTranslation, sizeof(sTranslation), "%s disabled", sTranslation);

        char sBuffer[4];
        IntToString(view_as<int>(g_iPlayer[client].Reopen), sBuffer, sizeof(sBuffer));
        g_coReopen.Set(client, sBuffer);
    }
    else
    {
        g_iPlayer[client].Reopen = true;

        Format(sTranslation, sizeof(sTranslation), "%s enabled", sTranslation);

        char sBuffer[4];
        IntToString(view_as<int>(g_iPlayer[client].Reopen), sBuffer, sizeof(sBuffer));
        g_coReopen.Set(client, sBuffer);
    }

    CPrintToChat(client, "%s %T", g_sPluginTag, sTranslation, client);

    return Plugin_Continue;
}

public int Menu_ShopHandler(Menu menu, MenuAction action, int client, int itemNum)
{
    if (action == MenuAction_Select)
    {
        if (!IsPlayerAlive(client))
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Not alive", client);
            return;
        }

        char info[32];
        menu.GetItem(itemNum, info, sizeof(info));

        ClientBuyItem(client, info, true);
    } 
    else if(action == MenuAction_End)
    {
        delete menu;
    }
}

bool ClientBuyItem(int client, char[] sItem, bool menu, bool free = false)
{
    if (menu && BB_GetRoundStatus() != Round_Active)
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Buy in active round", client);
        return false;
    }

    if (g_cTestingMode.BoolValue)
    {
        free = true;
    }

    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);

        if ((strlen(item.Short) > 0) && (strcmp(sItem, item.Short) == 0) && ((item.Role == 1) || (GetClientTeam(client) == item.Role)))
        {
            int iPrice = 0;

            if (!free)
            {
                iPrice = item.Price;
            }

            if (!g_cTestingMode.BoolValue && item.MaxUsages == 0)
            {
                CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Item disabled", client, item.Long);
                return false;
            }

            int iPurchases = -1;
            g_smPurchases.GetValue(item.Short, iPurchases);

            if (item.Limit > 0 && iPurchases >= item.Limit)
            {
                CPrintToChat(client, "%s %T!", g_sPluginTag, "Shop: Item global limit", client, item.Long, item.Limit);
                return false;
            }

            if (g_smUsages[client] == null)
            {
                g_smUsages[client] = new StringMap();
                g_smUsages[client].SetValue(item.Short, 0);
            }

            int iUsages = 0;

            if (!g_cTestingMode.BoolValue)
            {
                g_smUsages[client].GetValue(item.Short, iUsages);

                if (iUsages >= item.MaxUsages)
                {
                    CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Item max limit", client, item.Long, item.MaxUsages);
                    return false;
                }
            }

            int count = 1;

            Action result = Plugin_Continue;

            Call_StartForward(g_fwOnItemPurchasePre);
            Call_PushCell(client);
            Call_PushCellRef(iPrice);
            Call_PushCellRef(count);
            Call_PushString(item.Short);
            Call_Finish(result);

            if (result == Plugin_Stop || result == Plugin_Handled)
            {
                return false;
            }

            if ((!free && g_iPlayer[client].Credits >= iPrice) || (free && iPrice == 0))
            {
                Action res = Plugin_Continue;

                Call_StartFunction(item.Plugin, item.Callback);
                Call_PushCell(client);
                Call_PushString(item.Short);
                Call_PushCell(count);
                Call_PushCell(iPrice);
                Call_Finish(res);

                if (res < Plugin_Stop)
                {
                    subtractCredits(client, iPrice);
                    
                    if (!free)
                    {
                        CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Bought item", client, item.Long, iPrice);                    
                        CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Current credits", client, g_iPlayer[client].Credits);
                    }

                    Call_StartForward(g_fwOnItemPurchasePost);
                    Call_PushCell(client);
                    Call_PushCell(iPrice);
                    Call_PushCell(count);
                    Call_PushString(item.Short);
                    Call_Finish();

                    g_smUsages[client].SetValue(item.Short, ++iUsages);

                    if (g_smPurchases == null)
                    {
                        g_smPurchases = new StringMap();
                    }

                    int iValue = -1;
                    g_smPurchases.GetValue(item.Short, iValue);
                    g_smPurchases.SetValue(item.Short, (iValue == -1) ? 1 : ++iValue);
                    
                    return true;
                }
            } 
            else
            {
                CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Not enough credits", client);
                return false;
            }

            if (menu && g_cReopenMenu.BoolValue && g_iPlayer[client].Reopen)
            {
                Command_Shop(client, 0);
            }
        }
    }

    return false;
}

public Action BB_OnItemPurchasePre(int client, int &price, int &count, const char[] itemshort)
{
    char sFlag[16];
    g_smDiscountFlag.GetString(itemshort, sFlag, sizeof(sFlag));

    if (strlen(sFlag) > 0 && !HasFlag(client, sFlag, g_sDiscountFile))
    {
        return Plugin_Continue;
    }

    int iPercent = 0;

    if (g_smDiscountPercent.GetValue(itemshort, iPercent))
    {
        float fPercentage = iPercent / 100.0;
        int iDiscount = RoundToCeil(price * fPercentage);
        int iOld = price;
        price = iOld - iDiscount;
        return Plugin_Changed;
    }

    return Plugin_Continue;
}

public Action Command_Say(int client, const char[] command, int argc)
{
    if (!BB_IsClientValid(client) || !IsPlayerAlive(client))
    {
        return Plugin_Continue;
    }

    char sText[MAX_MESSAGE_LENGTH];
    GetCmdArgString(sText, sizeof(sText));

    StripQuotes(sText);

    if (sText[0] == '@')
    {
        return Plugin_Continue;
    }

    for (int i = 0; i < g_iCommands; i++)
    {
        char sCommand[32];
        Format(sCommand, sizeof(sCommand), "sm_%s", g_sCommandList[i]);

        if (StrEqual(sText, sCommand, false))
        {
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

public int Native_RegisterShopItem(Handle plugin, int numParams)
{
    if (numParams < 4)
    {
        return false;
    }

    char sShort[16];
    char temp_long[64];
    GetNativeString(1, sShort, sizeof(sShort));
    GetNativeString(2, temp_long, sizeof(temp_long));

    int temp_price = GetNativeCell(3);
    int temp_role = GetNativeCell(4);
    int temp_sort = GetNativeCell(5);
    int temp_maxUsages = GetNativeCell(6);
    int temp_limit = GetNativeCell(7);
    
    Function temp_callback = GetNativeFunction(8);

    if ((strlen(sShort) < 1) || (strlen(temp_long) < 1) || (temp_price <= 0))
    {
        return false;
    }

    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);

        if (StrEqual(item.Short, sShort, false))
        {
            return false;
        }
    }

    Format(item.Short, sizeof(sShort), "%s", sShort);
    Format(item.Long, sizeof(temp_long), "%s", temp_long);
    item.Price = temp_price;
    item.Role = temp_role;
    item.Sort = temp_sort;
    item.MaxUsages = temp_maxUsages;
    item.Limit = temp_limit;
    item.Plugin = plugin;
    item.Callback = temp_callback;
    g_aShopItems.PushArray(item);

    Call_StartForward(g_fwRegisterShopItemPost);
    Call_PushString(item.Short);
    Call_PushString(item.Long);
    Call_PushCell(item.Price);
    Call_PushCell(item.Price);
    Call_PushCell(item.Sort);
    Call_PushCell(item.MaxUsages);
    Call_PushCell(item.Limit);
    Call_Finish();

    if (g_cSortItems.IntValue)
    {
        SortADTArrayCustom(g_aShopItems, Sorting);
    }

    return true;
}

public int Native_UpdateShopItem(Handle plugin, int numParams)
{
    Item item;
    char sShort[16];
    GetNativeString(1, sShort, sizeof(sShort));
    
    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);

        if (StrEqual(item.Short, sShort, false))
        {            
            item.Price = GetNativeCell(2);
            item.Sort = GetNativeCell(3);
            item.MaxUsages = GetNativeCell(4);
            item.Limit = GetNativeCell(5);
            
            g_aShopItems.SetArray(i, item);
            
            return true;
        }
    }
    
    return false;
}

public int Native_RemoveShopItem(Handle plugin, int numParams)
{
    Item item;
    char sShort[16];
    GetNativeString(1, sShort, sizeof(sShort));
    
    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);

        if (StrEqual(item.Short, sShort, false))
        {
            g_aShopItems.Erase(i);
            return true;
        }
    }
    
    return false;
}

public int Native_GetItemName(Handle plugin, int numParams)
{
    char sName[16];
    int iSize = GetNativeCell(3);
    GetNativeString(1, sName, sizeof(sName));
    
    char[] sBuffer = new char[iSize];
    if (GetItemLong(sName, sBuffer, iSize) && SetNativeString(2, sBuffer, iSize) == SP_ERROR_NONE)
    {
        return true;
    }
    
    return false;
}

public int Native_ShopItemExist(Handle plugin, int numParams)
{
    char sName[16];
    GetNativeString(1, sName, sizeof(sName));
    
    bool bExist = false;
    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);

        if (StrEqual(item.Short, sName))
        {
            bExist = true;
            break;
        }    
    }
    
    return bExist;
}

public int Sorting(int i, int j, Handle array, Handle hndl)
{
    Item item1;
    Item item2;

    g_aShopItems.GetArray(i, item1);
    g_aShopItems.GetArray(j, item2);

    if (item1.Sort < item2.Sort)
    {
        return -1;
    } 
    else if (item1.Sort > item2.Sort)
    {
        return 1;
    }

    return 0;
}

public int Native_GetItemPrice(Handle plugin, int numParams)
{
    char sShort[32];
    GetNativeString(1, sShort, sizeof(sShort));

    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);

        if (strcmp(sShort, item.Short, false) == 0)
        {
            return item.Price;
        }
    }

    return 0;
}

public int Native_GetItemRole(Handle plugin, int numParams)
{
    char sShort[32];
    GetNativeString(1, sShort, sizeof(sShort));

    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);

        if (strcmp(sShort, item.Short, false) == 0)
        {
            return item.Role;
        }
    }

    return 0;
}

public int Native_GetItemMaxUsages(Handle plugin, int numParams)
{
    char sShort[32];
    GetNativeString(1, sShort, sizeof(sShort));

    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);

        if (strcmp(sShort, item.Short, false) == 0)
        {
            return item.MaxUsages;
        }
    }

    return -1;
}

public int Native_GetItemLimit(Handle plugin, int numParams)
{
    char sShort[32];
    GetNativeString(1, sShort, sizeof(sShort));

    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);

        if (strcmp(sShort, item.Short, false) == 0)
        {
            return item.Limit;
        }
    }

    return -1;
}

public void BB_OnBuildStart()
{
    delete g_smPurchases;
    g_smPurchases = new StringMap();
}

public void BB_OnRoundStart(int roundid, int zombies, int builders)
{
    LoopValidClients(i)
    {
        if (g_smUsages[i] != null)
        {
            delete g_smUsages[i];
        }

        g_smUsages[i] = new StringMap();
    }
}

public Action Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (BB_IsClientValid(client))
    {        
        if (g_cResetCreditsEachRound.BoolValue)
        {
            int iCredits = g_cStartCredits.IntValue;
            
            Action res = Plugin_Continue;
            Call_StartForward(g_fwOnStartCredits);
            Call_PushCell(client);
            Call_PushCellRef(iCredits);
            Call_Finish(res);

            if (res != Plugin_Changed)
            {
                g_iPlayer[client].Credits = g_cStartCredits.IntValue;
            } 
            else
            {
                g_iPlayer[client].Credits = iCredits;
            }
        }

        UpdatePlayer(client);

        if (BB_GetRoundStatus() == Round_Active)
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Current credits", client, g_iPlayer[client].Credits);
        }
    }

    return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
    if (g_cCreditsType.BoolValue && !g_cResetCreditsEachRound.BoolValue)
    {
        char sQuery[256], sCommunityID[64];
        GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID));
        Format(sQuery, sizeof(sQuery), "SELECT `Credits` FROM `bb` WHERE `CommunityID`= \"%s\";", sCommunityID);
        g_dDatabase.Query(SQL_OnClientPutInServer, sQuery, GetClientUserId(client));
    }
    else
    {
        g_iPlayer[client].Credits = g_cStartCredits.IntValue;
    }
}

public void SQL_OnClientPutInServer(Database db, DBResultSet results, const char[] error, int userid)
{
    int client = GetClientOfUserId(userid);

    if (!client || !BB_IsClientValid(client) || IsFakeClient(client))
    {
        return;
    }

    if (db == null || strlen(error) > 0)
    {
        LogError("(SQL_OnClientPutInServer) Query failed: %s", error);
        return;
    }
    else
    {
        if (results.RowCount > 0 && results.FetchRow())
        {
            g_iPlayer[client].Credits = results.FetchInt(0);

            if (g_cMoneyCredits.BoolValue)
            {
                SetEntProp(client, Prop_Send, "m_iAccount", g_iPlayer[client].Credits);
            }
        }
        else
        {
            g_iPlayer[client].Credits = g_cStartCredits.IntValue;

            UpdatePlayer(client, true);
        }
    }
}

public void OnClientDisconnect(int client)
{
    UpdatePlayer(client, true);

    delete g_smUsages[client];
}

public Action Command_Credits(int client, int args)
{
    if (!BB_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Current credits", client, g_iPlayer[client].Credits);
    return Plugin_Handled;
}

public Action Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!BB_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (!BB_IsClientValid(attacker) || attacker == client)
    {
        return Plugin_Handled;
    }

    if (GetClientTeam(attacker) == TEAM_BUILDERS)
    {
        addCredits(attacker, g_cBuilderKill.IntValue, true);
    } 
    else if (GetClientTeam(attacker) == TEAM_ZOMBIES)
    {
        addCredits(attacker, g_cZombieKill.IntValue, true);
    }

    UpdatePlayer(attacker);
    return Plugin_Handled;
}

public void BB_OnRoundEnd(int winner)
{
    if (BB_IsWarmUp())
    {
        return;
    }

    LoopValidClients(i)
    {
        if(winner == TEAM_BUILDERS)
        {
            if (GetClientTeam(i) == TEAM_BUILDERS && IsPlayerAlive(i))
            {
                addCredits(i, g_cBuilderWin.IntValue);
            }
        }
        else
        {
            if (GetClientTeam(i) == TEAM_ZOMBIES)
            {
                addCredits(i, g_cZombieWin.IntValue);
            }
        }
    }
}

void addCredits(int client, int credits, bool message = false)
{
    int newcredits = g_iPlayer[client].Credits + credits;

    Action res = Plugin_Continue;
    Call_StartForward(g_fwOnCreditsGiven_Pre);
    Call_PushCell(client);
    Call_PushCell(g_iPlayer[client].Credits);
    Call_PushCellRef(newcredits);
    Call_Finish(res);

    if (res > Plugin_Changed)
    {
        return;
    }

    g_iPlayer[client].Credits = newcredits;

    if (g_cShowEarnCreditsMessage.BoolValue && message)
    {
        if (g_cMessageTypCredits.IntValue == 1)
        {
            char sBuffer[MAX_MESSAGE_LENGTH];
            Format(sBuffer, sizeof(sBuffer), "<pre><font size='22' color='#13E800'>%T<br>%T</font><br><font size='18' color='#309FFF'>BaseBuilder</font></pre>", "Shop: Credits earned", client, credits, "Shop: Current credits", client, g_iPlayer[client].Credits);
            PrintCenterText2(client, "BaseBuilder", sBuffer);
        } 
        else 
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Credits earned", client, credits);
            CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Current credits", client, g_iPlayer[client].Credits);
        }
    }

    UpdatePlayer(client);

    Call_StartForward(g_fwOnCreditsGiven);
    Call_PushCell(client);
    Call_PushCell(g_iPlayer[client].Credits);
    Call_Finish();
}

void subtractCredits(int client, int credits, bool message = false)
{
    int newcredits = g_iPlayer[client].Credits - credits;

    Action res = Plugin_Continue;
    Call_StartForward(g_fwOnCreditsGiven_Pre);
    Call_PushCell(client);
    Call_PushCell(g_iPlayer[client].Credits);
    Call_PushCellRef(newcredits);
    Call_Finish(res);

    if (res > Plugin_Changed)
    {
        return;
    }

    g_iPlayer[client].Credits = newcredits;

    if (g_iPlayer[client].Credits < 0)
    {
        g_iPlayer[client].Credits = 0;
    }

    if (g_cShowLoseCreditsMessage.BoolValue && message)
    {
        if (g_cMessageTypCredits.IntValue == 1)
        {
            char sBuffer[MAX_MESSAGE_LENGTH];
            Format(sBuffer, sizeof(sBuffer), "<pre><font size='22' color='#13E800'>%T<br>%T</font><br><font size='18' color='#309FFF'>BaseBuilder</font></pre>", "Shop: Credits lost", client, credits, "Shop: Current credits", client, g_iPlayer[client].Credits);
            PrintCenterText2(client, "BaseBuilder", sBuffer);
        } 
        else 
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Credits lost", client, credits);
            CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Current credits", client, g_iPlayer[client].Credits);
        }
    }

    UpdatePlayer(client);

    Call_StartForward(g_fwOnCreditsGiven);
    Call_PushCell(client);
    Call_PushCell(g_iPlayer[client].Credits);
    Call_Finish();
}

void setCredits(int client, int credits)
{
    g_iPlayer[client].Credits = credits;

    if (g_iPlayer[client].Credits < 0)
    {
        g_iPlayer[client].Credits = 0;
    }

    UpdatePlayer(client);

    Call_StartForward(g_fwOnCreditsGiven);
    Call_PushCell(client);
    Call_PushCell(g_iPlayer[client].Credits);
    Call_Finish();
}

public Action Command_GiveItem(int client, int args)
{
    if (!BB_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!BB_CheckCommandAccess(client, "bb_shop_give_item", g_cGiveItem, true))
    {
        return Plugin_Handled;
    }

    if (args != 2)
    {
        CReplyToCommand(client, "%s Usage: sm_giveitem <#userid|name> <item>", g_sPluginTag);
        return Plugin_Handled;
    }

    char sArg1[12];
    GetCmdArg(1, sArg1, sizeof(sArg1));

    char sItem[16];
    GetCmdArg(2, sItem, sizeof(sItem));

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS];
    int target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(sArg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (int i = 0; i < target_count; i++)
    {
        int target = target_list[i];

        if (!BB_IsClientValid(target))
        {
            return Plugin_Handled;
        }

        if (!GiveClientItem(target, sItem))
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Item not found", client, sItem);
        }
    }

    return Plugin_Continue;
}

public Action Command_SetCredits(int client, int args)
{
    if (!BB_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!BB_CheckCommandAccess(client, "bb_shop_set_credits", g_cSetCredits, true))
    {
        return Plugin_Handled;
    }

    if (args != 2)
    {
        CReplyToCommand(client, "%s Usage: sm_setcredits <#userid|name> <credits>", g_sPluginTag);
        return Plugin_Handled;
    }

    char arg1[32];
    GetCmdArg(1, arg1, sizeof(arg1));

    char arg2[32];
    GetCmdArg(2, arg2, sizeof(arg2));

    int credits = StringToInt(arg2);

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS];
    int target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (int i = 0; i < target_count; i++)
    {
        int target = target_list[i];

        if (!BB_IsClientValid(target))
        {
            return Plugin_Handled;
        }

        setCredits(target, credits);

        CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Set credits", client, target, credits);
    }

    return Plugin_Continue;
}

public Action Command_ResetItems(int client, int args)
{
    if (!BB_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!BB_CheckCommandAccess(client, "bb_shop_reset_items", g_cResetItems, true))
    {
        return Plugin_Handled;
    }

    ResetItemsArray("Command_ResetItems", true);
    return Plugin_Continue;
}

public Action Command_ListItems(int client, int args)
{
    if (!BB_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!BB_CheckCommandAccess(client, "bb_shop_list_items", g_cListItems, true))
    {
        return Plugin_Handled;
    }

    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);

        if (strlen(item.Short) > 1)
        {
            PrintToConsole(client, "Name: %s \t Short Name: %s \t Price (without discount): %d \t  Max Usages: %d \t  Limit: %d", item.Long, item.Short, item.Price, item.MaxUsages, item.Limit);
        }
    }

    return Plugin_Handled;
}

public Action Command_ReloadDiscount(int client, int args)
{
    if (!BB_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!BB_CheckCommandAccess(client, "bb_shop_reload_discount", g_cReloadDiscount, true))
    {
        return Plugin_Handled;
    }

    ReplyToCommand(client, "%s Shop Discount file reloaded!", g_sPluginTag);

    LoadShopFile(g_sDiscountFile);
    return Plugin_Continue;
}

public Action Command_ReloadFlag(int client, int args)
{
    if (!BB_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!BB_CheckCommandAccess(client, "bb_shop_reload_flag", g_cReloadFlag, true))
    {
        return Plugin_Handled;
    }

    CReplyToCommand(client, "%s Shop Flags file reloaded!", g_sPluginTag);

    LoadShopFile(g_sFlagsFile);
    return Plugin_Continue;
}

public int Native_GetClientCredits(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (BB_IsClientValid(client))
    {
        return g_iPlayer[client].Credits;
    }
    
    return 0;
}

public int Native_SetClientCredits(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int credits = GetNativeCell(2);

    if (BB_IsClientValid(client))
    {
        setCredits(client, credits);
        return g_iPlayer[client].Credits;
    }

    return 0;
}

public int Native_AddClientCredits(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int credits = GetNativeCell(2);

    if (BB_IsClientValid(client))
    {
        setCredits(client, g_iPlayer[client].Credits+credits);
        return g_iPlayer[client].Credits;
    }

    return 0;
}

public int Native_GiveClientItem(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    char sItem[16];
    GetNativeString(2, sItem, sizeof(sItem));

    if (BB_IsClientValid(client))
    {
        return GiveClientItem(client, sItem);
    }

    return false;
}

public int Native_GetItemUsages(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char sShort[16];
    GetNativeString(2, sShort, sizeof(sShort));
    
    int iUsages = -1;
    
    if (g_smUsages[client].GetValue(sShort, iUsages))
    {
        return iUsages;
    }

    return -1;
}

public int Native_AddItemUsage(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char sShort[16];
    GetNativeString(2, sShort, sizeof(sShort));

    int iUsage = GetNativeCell(3);

    int iOldUsage;
    g_smUsages[client].GetValue(sShort, iOldUsage);

    int iItemMaxUsages;

    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);

        if (strlen(item.Short) > 1 && StrEqual(item.Short, sShort, false))
        {
            iItemMaxUsages = item.MaxUsages;
        }
    }

    int iNewUsage = iOldUsage + iUsage;

    if (iNewUsage > iItemMaxUsages)
    {
        iNewUsage = iItemMaxUsages;
    }

    g_smUsages[client].SetValue(sShort, iNewUsage);
    return iNewUsage;
}

public int Native_RemoveItemUsage(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char sShort[16];
    GetNativeString(2, sShort, sizeof(sShort));

    int iUsage = GetNativeCell(3);

    int iOldUsage;
    g_smUsages[client].GetValue(sShort, iOldUsage);

    int iNewUsage = iOldUsage - iUsage;

    if (iNewUsage < 0)
    {
        iNewUsage = 0;
    }

    g_smUsages[client].SetValue(sShort, iNewUsage);
    return iNewUsage;
}

public int Native_SetItemUsage(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char sShort[16];
    GetNativeString(2, sShort, sizeof(sShort));

    int iUsage = GetNativeCell(3);

    int iItemMaxUsages;

    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);

        if (strlen(item.Short) > 1 && StrEqual(item.Short, sShort, false))
        {
            iItemMaxUsages = item.MaxUsages;
        }
    }

    if (iUsage > iItemMaxUsages)
    {
        iUsage = iItemMaxUsages;
    }

    if (iUsage < 0)
    {
        iUsage = 0;
    }

    g_smUsages[client].SetValue(sShort, iUsage);
    return iUsage;
}

public int Native_GetItemDiscount(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char sItem[16];
    GetNativeString(2, sItem, sizeof(sItem));

    if (BB_IsClientValid(client))
    {
        char sFlag[16];
        g_smDiscountFlag.GetString(sItem, sFlag, sizeof(sFlag));

        int iPercent = 0;

        if (!HasFlag(client, sFlag, g_sDiscountFile))
        {
            return iPercent;
        }

        if (g_smDiscountPercent.GetValue(sItem, iPercent))
        {
            return iPercent;
        }

        return iPercent;
    }

    return -1;
}

public int Native_CheckItemAccess(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char sItem[16];
    GetNativeString(2, sItem, sizeof(sItem));

    if (BB_IsClientValid(client))
    {
        char sFlag[16];
        bool success = g_smAccessFlag.GetString(sItem, sFlag, sizeof(sFlag));

        if (!success || strlen(sFlag) == 0)
        {
            return true;
        }

        return HasFlag(client, sFlag, g_sFlagsFile);
    }

    return true;
}

void ResetItemsArray(const char[] sFunction, bool initArray = false)
{
    delete g_aShopItems;

    PrintToServer("Function: %s - Init: %d", sFunction, initArray);
    
    if (initArray)
    {
        g_aShopItems = new ArrayList(sizeof(Item));
        RequestFrame(Frame_ShopReady, g_aShopItems);
    }
}

public void Frame_ShopReady(ArrayList aItems)
{
    if (aItems != null && g_aShopItems != null && aItems == g_aShopItems)
    {
        Call_StartForward(g_fwOnShopReady);
        Call_Finish();
    }
}

int GiveClientItem(int client, char[] sItem)
{
    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);

        if (strlen(item.Short) > 1 && StrEqual(item.Short, sItem, false))
        {
            ClientBuyItem(client, sItem, false, true);
            return true;
        }
    }

    return false;
}

bool GetItemLong(const char[] itemshort, char[] buffer, int size)
{
    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);

        if (!StrEqual(itemshort, item.Short))
        {
            continue;
        }

        strcopy(buffer, size, item.Long);
        return true;
    }
    
    return false;
}

bool HasFlag(int client, const char[] flags, char[] file)
{
    int iFlag = ReadFlagString(flags);

    if (StrEqual(file, g_sDiscountFile))
    {
        return CheckCommandAccess(client, "bb_shop_discount", iFlag, true);
    }

    if (StrEqual(file, g_sFlagsFile))
    {
        return CheckCommandAccess(client, "bb_shop_flags", iFlag, true);
    }

    return false;
}

void LoadShopFile(const char[] sFile)
{
    Handle hFile = OpenFile(sFile, "rt");

    if (hFile == null)
    {
        SetFailState("[Shop] Can't open File: %s", sFile);
    }

    KeyValues kvValues;

    if (StrEqual(sFile, g_sDiscountFile))
    {
        kvValues = new KeyValues("Shop-Discount");
    }
    else if (StrEqual(sFile, g_sFlagsFile))
    {
        kvValues = new KeyValues("Shop-Flags");
    }
    else
    {
        delete kvValues;
        delete hFile;
        return;
    }

    if (!kvValues.ImportFromFile(sFile))
    {
        SetFailState("Can't read %s correctly! (ImportFromFile)", sFile);
        delete kvValues;
        delete hFile;
        return;
    }

    if (!kvValues.GotoFirstSubKey())
    {
        SetFailState("Can't read %s correctly! (GotoFirstSubKey)", sFile);
        delete kvValues;
        delete hFile;
        return;
    }

    delete g_smDiscountPercent;
    delete g_smDiscountFlag;
    delete g_smAccessFlag;

    g_smDiscountPercent = new StringMap();
    g_smDiscountFlag = new StringMap();
    g_smAccessFlag = new StringMap();

    if (StrEqual(sFile, g_sDiscountFile))
    {
        do
        {
            char sShort[16];
            int iPercent;
            char sFlag[16];

            kvValues.GetSectionName(sShort, sizeof(sShort));
            iPercent = kvValues.GetNum("percentage");
            kvValues.GetString("flag", sFlag, sizeof(sFlag));

            if (strlen(sShort) > 1 && iPercent >= 1 && iPercent <= 100)
            {
                g_smDiscountPercent.SetValue(sShort, iPercent, true);
                g_smDiscountFlag.SetString(sShort, sFlag, true);
            }
        }
        while (kvValues.GotoNextKey());
    }
    else if (StrEqual(sFile, g_sFlagsFile))
    {
        do
        {
            char sShort[16];
            char sFlag[16];

            kvValues.GetSectionName(sShort, sizeof(sShort));
            kvValues.GetString("flag", sFlag, sizeof(sFlag));

            if (strlen(sShort) > 1)
            {
                g_smAccessFlag.SetString(sShort, sFlag, true);
            }
        }
        while (kvValues.GotoNextKey());
    }

    delete kvValues;
    delete hFile;
}
