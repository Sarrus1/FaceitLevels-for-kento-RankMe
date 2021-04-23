#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <lvl_ranks>
#include <rankme>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
	{
		name = "Faceit Levels For Kento RankMe and Level Ranks",
		author = "Sarrus",
		description = "A plugin that gives players faceit levels based on their RankMe or Level Ranks points.",
		version = "1.1",
		url = "https://github.com/Sarrus1/"};

enum struct Player
{
	int iPoints;
	int iFaceitLevel;
}

Player g_Players[MAXPLAYERS + 1];

int m_nPersonaDataPublicLevel,
	g_iFaceitLevelsMins[10] = {0};

ConVar g_FaceitLevelRank1,
	g_FaceitLevelRank2,
	g_FaceitLevelRank3,
	g_FaceitLevelRank4,
	g_FaceitLevelRank5,
	g_FaceitLevelRank6,
	g_FaceitLevelRank7,
	g_FaceitLevelRank8,
	g_FaceitLevelRank9,
	g_FaceitLevelRank10,
	g_FaceitLevelRoundReload,
	g_FaceitLevelFFAMode;

bool g_bRankMe = true,
		 g_bLevelRank = false;

public void OnPluginStart()
{
	HookEvent("round_end", OnRoundEnd, EventHookMode_Post);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);

	g_FaceitLevelRank1 = CreateConVar("sm_faceit_level_rank_1", "0", "Minimum amounts of points for a player to be level 1.", 0, true, 0.0);
	g_FaceitLevelRank2 = CreateConVar("sm_faceit_level_rank_2", "1200", "Minimum amounts of points for a player to be level 2.", 0, true, 0.0);
	g_FaceitLevelRank3 = CreateConVar("sm_faceit_level_rank_3", "1300", "Minimum amounts of points for a player to be level 3.", 0, true, 0.0);
	g_FaceitLevelRank4 = CreateConVar("sm_faceit_level_rank_4", "1400", "Minimum amounts of points for a player to be level 4.", 0, true, 0.0);
	g_FaceitLevelRank5 = CreateConVar("sm_faceit_level_rank_5", "1500", "Minimum amounts of points for a player to be level 5.", 0, true, 0.0);
	g_FaceitLevelRank6 = CreateConVar("sm_faceit_level_rank_6", "1600", "Minimum amounts of points for a player to be level 6.", 0, true, 0.0);
	g_FaceitLevelRank7 = CreateConVar("sm_faceit_level_rank_7", "1700", "Minimum amounts of points for a player to be level 7.", 0, true, 0.0);
	g_FaceitLevelRank8 = CreateConVar("sm_faceit_level_rank_8", "1800", "Minimum amounts of points for a player to be level 8.", 0, true, 0.0);
	g_FaceitLevelRank9 = CreateConVar("sm_faceit_level_rank_9", "1900", "Minimum amounts of points for a player to be level 9.", 0, true, 0.0);
	g_FaceitLevelRank10 = CreateConVar("sm_faceit_level_rank_10", "2000", "Minimum amounts of points for a player to be level 10.", 0, true, 0.0);
	g_FaceitLevelRoundReload = CreateConVar("sm_faceit_level_round_reload", "1", "1 to reload the ranks every round, 0 to only reload them on map start", 0, true, 0.0, true, 1.0);
	g_FaceitLevelFFAMode = CreateConVar("sm_faceit_level_ffa_mode", "0", "1 to enable ffa mode, player rank is reloaded every death, 0 to reload everyround.", 0, true, 0.0, true, 1.0);

	HookConVarChange(g_FaceitLevelRank1, ReloadSkillLevelsMins_ConvarChange);
	HookConVarChange(g_FaceitLevelRank2, ReloadSkillLevelsMins_ConvarChange);
	HookConVarChange(g_FaceitLevelRank3, ReloadSkillLevelsMins_ConvarChange);
	HookConVarChange(g_FaceitLevelRank4, ReloadSkillLevelsMins_ConvarChange);
	HookConVarChange(g_FaceitLevelRank5, ReloadSkillLevelsMins_ConvarChange);
	HookConVarChange(g_FaceitLevelRank6, ReloadSkillLevelsMins_ConvarChange);
	HookConVarChange(g_FaceitLevelRank7, ReloadSkillLevelsMins_ConvarChange);
	HookConVarChange(g_FaceitLevelRank8, ReloadSkillLevelsMins_ConvarChange);
	HookConVarChange(g_FaceitLevelRank9, ReloadSkillLevelsMins_ConvarChange);
	HookConVarChange(g_FaceitLevelRank10, ReloadSkillLevelsMins_ConvarChange);

	AutoExecConfig(true, "FaceitLevels-kento-rankme");

	m_nPersonaDataPublicLevel = FindSendPropInfo("CCSPlayerResource", "m_nPersonaDataPublicLevel");

	ReloadSkillLevelsMins();
	for(int i = 1; i < MAXPLAYERS + 1; i++)
	{
		RefreshSkillLevels(i);
	}
}

public void OnAllPluginsLoaded()
{
	g_bLevelRank = LibraryExists("levelsranks");
	g_bRankMe = LibraryExists("rankme");
}

public void OnLibraryAdded(const char[] name)
{
	RefreshLibraryStatus(name, true);
}

public void OnLibraryRemoved(const char[] name)
{
	RefreshLibraryStatus(name, false);
}

stock void RefreshLibraryStatus(const char[] name, bool IsAdded)
{
	if(StrEqual(name, "levelsranks"))
	{
		g_bLevelRank = IsAdded;
		return;
	}

	if(StrEqual(name, "rankme"))
	{
		g_bRankMe = IsAdded;
		return;
	}
}

public Action OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int iVictim = GetClientOfUserId(GetEventInt(event, "userid"));
	int iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(GetConVarBool(g_FaceitLevelFFAMode))
	{
		if(IsValidClient(iVictim))
			RefreshSkillLevels(iVictim);
		if(IsValidClient(iAttacker))
			RefreshSkillLevels(iAttacker);
	}
	return Plugin_Continue;
}


public void ReloadSkillLevelsMins_ConvarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ReloadSkillLevelsMins();
}


public void ReloadSkillLevelsMins()
{
	g_iFaceitLevelsMins[0] = GetConVarInt(g_FaceitLevelRank1);
	g_iFaceitLevelsMins[1] = GetConVarInt(g_FaceitLevelRank2);
	g_iFaceitLevelsMins[2] = GetConVarInt(g_FaceitLevelRank3);
	g_iFaceitLevelsMins[3] = GetConVarInt(g_FaceitLevelRank4);
	g_iFaceitLevelsMins[4] = GetConVarInt(g_FaceitLevelRank5);
	g_iFaceitLevelsMins[5] = GetConVarInt(g_FaceitLevelRank6);
	g_iFaceitLevelsMins[6] = GetConVarInt(g_FaceitLevelRank7);
	g_iFaceitLevelsMins[7] = GetConVarInt(g_FaceitLevelRank8);
	g_iFaceitLevelsMins[8] = GetConVarInt(g_FaceitLevelRank9);
	g_iFaceitLevelsMins[9] = GetConVarInt(g_FaceitLevelRank10);
	PrintToServer("Faceit ranks minimums have been reloaded.");
}


public Action OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	if(GetConVarBool(g_FaceitLevelRoundReload))
	{
		for(int i = 0; i < MaxClients; i++)
		{
			RefreshSkillLevels(i);
		}
	}
	return Plugin_Continue;
}

public void OnMapStart()
{
	char sBuf[PLATFORM_MAX_PATH];

	for(int i = 0; i < 10; i++)
	{
		FormatEx(sBuf, sizeof sBuf, "materials/panorama/images/icons/xp/level%i.png", 5001 + i);

		AddFileToDownloadsTable(sBuf);
	}

	SDKHook(GetPlayerResourceEntity(), SDKHook_ThinkPost, Hook_OnThinkPost);
}

public Action RankMe_OnPlayerLoaded(int iClient)
{
	RequestFrame(RefreshSkillLevels, iClient);
}


public void RefreshSkillLevels(int iClient)
{
	if(!IsValidClient(iClient))
		return;
	int iPoints = 0;
	if(g_bRankMe)
	{
		if(RankMe_IsPlayerLoaded(iClient))
			iPoints = RankMe_GetPoints(iClient);
	}
	else if(g_bLevelRank)
	{
		if(LR_GetClientStatus(iClient))
		{
			iPoints = LR_GetClientInfo(iClient, ST_EXP);
			PrintToConsole(iClient, "Your score is %d", iPoints);
		}
	}

	g_Players[iClient].iPoints = iPoints;

	for(int i = 9; i >= 0; i--)
	{
		if(g_Players[iClient].iPoints >= g_iFaceitLevelsMins[i])
		{
			g_Players[iClient].iFaceitLevel = i + 1;
			return;
		}
	}
	g_Players[iClient].iFaceitLevel = 1;
}


public void Hook_OnThinkPost(int iEnt)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			SetEntData(iEnt, m_nPersonaDataPublicLevel + i * 4, g_Players[i].iFaceitLevel + 5000);
		}
	}
}


public bool IsValidClient(int client)
{
	return (client > 0 && client < MaxClients && IsClientConnected(client) && IsClientAuthorized(client) && IsClientInGame(client) && !IsFakeClient(client));
}
