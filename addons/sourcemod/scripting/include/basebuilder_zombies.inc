#if defined _basebuilder_zombies_included
    #endinput
#endif
#define _basebuilder_zombies_included

/**
 * Get client speed.
 *
 * @param client            Client index.
 *
 * @return                  Client speed.
 */
native float BB_GetClientSpeed(int client);

/**
 * Add value to client speed.
 *
 * @param client            Client index.
 * @param speed             Speed to add.
 *
 * @return                  Client speed.
 */
native float BB_AddClientSpeed(int client, float speed = 0.1);

/**
 * Set client speed.
 *
 * @param client            Client index.
 * @param speed             Speed.
 *
 * @return                  Client speed.
 */
native float BB_SetClientSpeed(int client, float speed = 1.0);

/**
 * Get client gravity.
 *
 * @param client            Client index.
 *
 * @return                  Client gravity.
 */
native float BB_GetClientGravity(int client);

/**
 * Add value to client gravity.
 *
 * @param client            Client index.
 * @param gravity           Gravity to add.
 *
 * @return                  Client gravity.
 */
native float BB_AddClientGravity(int client, float gravity = 0.1);

/**
 * Substract value from client gravity.
 *
 * @param client            Client index.
 * @param gravity           Gravity to substract.
 *
 * @return                  Client gravity.
 */
native float BB_SubClientGravity(int client, float gravity = 0.1);

/**
 * Set client gravity.
 *
 * @param client            Client index.
 * @param gravity           Gravity.
 *
 * @return                  Client gravity.
 */
native float BB_SetClientGravity(int client, float gravity = 1.0);
