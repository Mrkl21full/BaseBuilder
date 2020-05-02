#if defined _basebuilder_playerhud_included
    #endinput
#endif
#define _basebuilder_playerhud_included

/**
 * Check if player hud is active.
 *
 * @param client            Client index.
 *
 * @return                  True if active, false otherwise.
 */
native bool BB_IsPlayerHudActive(int client);

/**
 * Set player visibility on hud for other players.
 *
 * @param client            Client index.
 * @param visile            True if visible, false otherwise.
 *
 * @return                  Return visibility status.
 */
native bool BB_SetPlayerVisibilityOnHud(int client, bool visile);