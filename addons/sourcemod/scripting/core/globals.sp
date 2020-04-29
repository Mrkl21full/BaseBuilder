char g_sPluginTag[64];

Database g_dDatabase;

GlobalForward g_fwOnBuildStart = null;
GlobalForward g_fwOnPrepStart = null;
GlobalForward g_fwOnRoundStart = null;
GlobalForward g_fwOnRoundEnd = null;

GlobalForward g_fwOnBlockMove = null;
GlobalForward g_fwOnBlockStop = null;

Handle g_hCountdownTimer = null;

int g_iCountdownTime;
int g_iRoundTime;

char g_sRadioCMDs[][] =  {
    "coverme",
    "takepoint",
    "holdpos",
    "regroup",
    "followme",
    "takingfire",
    "go",
    "fallback",
    "sticktog",
    "getinpos",
    "stormfront",
    "report",
    "roger",
    "enemyspot",
    "needbackup",
    "sectorclear",
    "inposition",
    "reportingin",
    "getout",
    "negative",
    "enemydown",
    "compliment",
    "thanks",
    "cheer"
};

char g_sRemoveEntityList[][] =  {
    "func_bomb_target",
    "func_buyzone",
    "hostage_entity",
    "func_hostage_rescue",
    "info_hostage_spawn"
};

int g_iSpawns;
int g_iCollisionOffset = -1;
int g_iColorRed[17] = { 128, 243, 232, 155, 102, 62, 32, 2, 0, 0, 75, 138, 204, 254, 254, 254, 120 };
int g_iColorGreen[17] = { 128, 66, 29, 38, 57, 80, 149, 168, 187, 149, 174, 194, 234, 192, 151, 86, 84 };
int g_iColorBlue[17] = { 128, 53, 98, 175, 182, 180, 242, 243, 211, 135, 79, 73, 58, 6, 0, 33, 71 };

// TODO: Make then in english?
char g_sColorName[][] = { "Domyślny", "Jasny czerwony", "Różowy", "Fioletowy", "Ciemny fioletowy", "Fioletowo-Niebieski", "Niebieski", "Jasny niebieski", "Morski", "Niebiesko-Zielony", "Jasny zielony", "Limonkowy", "Żółty", "Żółto-Pomarańczowy", "Pomarańczowy", "Ciemny pomarańczowy", "Brazowy" };

float g_fSpawnLocation[32][3];
float g_fSpawnAngles[32][3];

int g_iRoundID = -1;

bool g_bIsBuildTime = false;
bool g_bIsPrepTime = false;

ConVar g_cPluginTag = null;
ConVar g_cPrepTime = null;
ConVar g_cBuildTime = null;
ConVar g_cRoundTime = null;
ConVar g_cInviteTime = null;
ConVar g_cRespawnZombie = null;
ConVar g_cMaxLocks = null;
ConVar g_cRemoveNotUsedBlocks = null;
ConVar g_cRemoveBlockAfterDeath = null;
ConVar g_cPushPlayersOfBlocks = null;

RoundStatus g_iStatus = Round_Inactive;

enum struct PlayerData 
{
    int iPoints;
    int iLevel;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];