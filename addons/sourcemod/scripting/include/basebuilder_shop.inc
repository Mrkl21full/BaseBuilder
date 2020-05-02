#if defined _bb_shop_included
    #endinput
#endif
#define _bb_shop_included

#define SHOP_ITEM_4ALL 1
#define SHOP_ITEM_NAME_LONG 64
#define SHOP_ITEM_NAME_SHORT 16

typedef BB_ItemPurchaseCallback = function Action (int client, const char[] itemshort, int count, int price);

/*
 * Called after an item is purchased in the menu.
 *
 * @param client            The client who purchased the item.
 * @param price             The price that the item has cost. (0 = Free)
 * @param count             Usages of this item. (0 - No usage left, 1+ - Usages per Round)
                            Check for yourself if you've round based items without usage limit
 * @param itemshort         The short-tag for the item's name.
 */
forward void BB_OnItemPurchasePost(int client, int price, int count, const char[] itemshort);

/*
 * Called before the purchase process has begun.
 *
 * @param client            The client who will purchase this item
 * @param price             Price of the item
 * @param count             Usages of this item. (0 - No usage left, 1+ - Usages per Round)
                            Check for yourself if you've round based items without usage limit
 * @param itemshort         Short name of the item
 */
forward Action BB_OnItemPurchasePre(int client, int &price, int &count, const char[] itemshort);

/*
 * Called when items array was initialized. This was added to avoid "empty items list".
 *
 */
forward void BB_OnShopReady();

/*
 * Called after a players credits are modified.
 *
 * @param client            Client index.
 * @param credits           The new amount of credits.
 */
forward void BB_OnCreditsChanged(int client, int &credits);

/*
 * Called before a players credits are modified.
 *
 * @param client            Client index.
 * @param oldcredits        The old amount of credits.
 * @param newcredits        The new amount of credits.
 */
forward Action BB_OnCreditsChanged_Pre(int client, int oldcredits, int &newcredits);

/*
 * Called after registers a custom item in the menu/shop.
 *
 * @param itemshort         The short-tag identifier of the item (must be unique).
 * @param itemlong          The long fancy name for the item.
 * @param price             The price of the item.
 * @param role              The optional role to restrict the item to. (Default: 0 - for all)
 * @param sort              The priority in Sorting. Buy menu is sorted from high to low. (Default: 0)
 * @param maxUsages         Max usages per user and round. (Default: 0)
 * @param limit             Global max usages per round. (Default: 0)
 */
forward void BB_OnRegisterShopItemPost(const char[] itemshort, const char[] itemlong, int price, int role, int sort, int maxUsages, int limit);

/*
 * Called before start credits (on player_spawn) will be given.
 * By changing credits and return Plugin_Changed, you can modify credits amount.
 *
 * @param client            Client index.
 * @param credits           The amount of credits.
 */
forward void BB_OnStartCredits(int client, int &credits);

/*
 * Registers a item in the menu/shop.
 *
 * @param itemshort                 The short-tag identifier of the item (must be unique).
 * @param itemlong                  The long fancy name for the item.
 * @param price                     The price of the item.
 * @param role                      The optional role to restrict the item to. (Default: 0 - for all)
 * @param sort                      The priority in Sorting. Buy menu is sorted from high to low. (Default: 0)
 * @param maxUsages                 Max usages per user and round. (Default: 0)
 * @param limit                     Global max usages per round. (Default: 0)
 * @param BB_ItemPurchaseCallback   Function which will do some action after buying this item.
 *
 * @return                          True if success, false otherwise.
 */
native bool BB_RegisterShopItem(const char[] itemshort, const char[] itemlong, int price, int role = 0, int sort = 0, int maxUsages, int limit, BB_ItemPurchaseCallback callback);

/*
 * Update shop item.
 *
 * @param itemshort         The short-tag identifier to find the item.
 * @param price             The price of the item.
 * @param sort              The priority in Sorting. Buy menu is sorted from high to low.
 * @param maxUsages         Max usages per user and round. (Default: 0)
 * @param limit             Global max usages per round. (Default: 0)
 *
 * @return                  True if success, false otherwise.
 */
native bool BB_UpdateShopItem(const char[] itemshort, int price, int sort = 0, int maxUsages, int limit);

/*
 * Remove shop item.
 *
 * @param itemshort         The short-tag identifier to find the item.
 *
 * @return                  True it was removed, otherwise shop item not found.
 */
native bool BB_RemoveShopItem(const char[] itemshort);

/*
 * Retrieve a item's price.
 *
 * @param item              The short-tag identifier of the item.
 *
 * @return                  Item price.
 */
native int BB_GetItemPrice(const char[] item);

/*
 * Retrieve a item's role restriction.
 *
 * @param item              The short-tag identifier of the item.
 *
 * @return                  Team index which can use this item.
 */
native int BB_GetItemRole(const char[] item);

/*
 * Gets the display name of the item.
 *
 * @param itemshort         Unique name of item.
 * @param buffer            Buffer to store display name.
 * @param size              Size of buffer.
 *
 * @return                  Returns true on success. Will return false if the item is no longer registered in shop or native failed to write to buffer.
 */
native bool BB_GetItemName(const char[] itemshort, char[] buffer, int size);

/*
 * Checks whether or not item exists.
 *
 * @param itemshort         Unique name of item.
 *
 * @return                  Returns true if item exists, otherwise false.
 */
native bool BB_ShopItemExist(const char[] itemshort);

/*
 * Retrieve the max usages of a item.
 *
 * @param item              The short-tag identifier of the item.
 *
 * @return                  Item max usages.
 */
native int BB_GetItemMaxUsages(const char[] item);

/*
 * Retrieve a client's credits.
 *
 * @param client            Client index.
 *
 * @return                  Client credits amount.
 */
native int BB_GetClientCredits(int client);

/*
 * Set a client's credits.
 *
 * @param client            Client index.
 *
 * @return                  New client credits amount.
 */
native int BB_SetClientCredits(int client, int credits);

/*
 * Add a client's credits (currentCredits+credits).
 *
 * @param client            Client index.
 *
 * @return                  New client credits amount.
 */
native int BB_AddClientCredits(int client, int credits);

/*
 * Add item to client (without any costs)
 *
 * @param client            Client Index
 * @param item              Short Item name
 *
 * @return                  True item found/valid, false item not found
 */
native bool BB_GiveClientItem(int client, const char[] item);

/*
 * Get's the amount of usages for this item
 * Attention: This will be reset on player spawn and client disconnect
 *
 * @param client            Client index.
 * @param short             Short item name
 * 
 * @return                  Usages for this item, -1 = Item not found
 */
native int BB_GetItemUsages(int client, const char[] short);

/*
 * Add the client usages for the specific item
 * Can't be higher as the max usages
 * Attention: This will be reset on player spawn and client disconnect
 *
 * @param client            Client index.
 * @param short             Short item name
 * @param usage             Usages to add
 * 
 * @return                  Usages for this item
 */
native int BB_AddItemUsage(int client, const char[] short, int usages = 1);

/*
 * Remove the client usages for the specific item
 * Can't be lower as 0
 * Attention: This will be reset on player spawn and client disconnect
 *
 * @param client            Client index.
 * @param short             Short item name
 * @param usage             Usages to remove
 * 
 * @return                  Usages for this item
 */
native int BB_RemoveItemUsage(int client, const char[] short, int usages = 1);

/*
 * Set the client usages for the specific item
 * Can't be higher as the max usages
 * Can't be lower as 0
 * Attention: This will be reset on player spawn and client disconnect
 *
 * @param client            Client index.
 * @param short             Short item name
 * @param usage             Usages to set
 * 
 * @return                  Usages for this item
 */
native int BB_SetItemUsage(int client, const char[] short, int usages);

/*
 * Get discount in percent for the specific item (from 0 - 100)
 *
 * @param client              Client Index
 * @param item                Short Item name
 *
 * @return                    Percent of discount
 */
native int BB_GetItemDiscount(int client, const char[] shortName);

/*
 * Check if client has access to the specific item
 *
 * @param client              Client Index
 * @param item                Short Item name
 *
 * @return                    True if has access, false otherwise
 */
native bool BB_CheckItemAccess(int client, const char[] shortName);
