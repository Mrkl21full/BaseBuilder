#if defined _basebuilder_spectate_included
    #endinput
#endif
#define _basebuilder_spectate_included

/**
 * Check if zombie is testing CT's bases.
 *
 * @param client            Client index.
 *
 */
native bool BB_IsZombieSpectating(int client);

/**
 * Starts or stops zombie base testing.
 *
 * @param client            Client index.
 * @param value             1 - Set to testing, 0 - Stop testing
 *
 */
native void BB_SetZombieSpectating(int client, int value);