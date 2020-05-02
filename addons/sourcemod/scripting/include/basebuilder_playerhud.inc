#if defined _basebuilder_playerhud_included
    #endinput
#endif
#define _basebuilder_playerhud_included

/**
 * Check if player hud is active.
 *
 * @param client            Client index.
 *
 */
native bool BB_IsPlayerHudActive(int client);

/**
 * IDK.
 *
 * @param client            Client index.
 * @param visile            IDK what is that.
 *
 */
native bool BB_SetPlayerVisibilityOnHud(int client, bool visile);