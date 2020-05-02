#if defined _basebuilder_spectate_included
    #endinput
#endif
#define _basebuilder_spectate_included

/**
 * Check if zombie is spectating builder bases.
 *
 * @param client            Client index.
 *
 * @return                  True if spectating, false otherwise.
 */
native bool BB_IsZombieSpectating(int client);

/**
 * Change player spectating status.
 *
 * @param client            Client index.
 * @param value             True if spectating, false otherwise.
 */
native void BB_SetZombieSpectating(int client, bool value);
