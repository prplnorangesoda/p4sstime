#include <tf2_stocks>
#include <sdkhooks>
//#include <dhooks>
#include <clientprefs>

#pragma semicolon 1	   // required for logs.tf
#pragma newdecls required

#define VERSION "2.2.0"

enum struct enubPlyJackSettings
{
	bool bPlyCoundownCaptionSetting;
	bool bPlyHudTextSetting;
	bool bPlyChatPrintSetting;
	bool bPlySoundSetting;
	bool bPlySimpleChatPrintSetting;
	bool bPlyToggleChatPrintSetting;
}

enum struct enuiPlyRoundStats
{
	int iPlyScores;
	int iPlyAssists;
	int iPlySaves;
	int iPlyIntercepts;
	int iPlySteals;
	int iPlyPanaceas;
	int iPlyWinStrats;
	int iPlyDeathbombs;
	int iPlyHandoffs;
	int iPlyFirstGrabs;
	int iPlyCatapults;
	int iPlyBlocks;
	int iPlySteal2Saves;
}

enubPlyJackSettings arrbJackAcqSettings[MAXPLAYERS + 1];
enuiPlyRoundStats	arriPlyRoundPassStats[MAXPLAYERS + 1];

float			fBluGoalPos[3], fRedGoalPos[3], fTopSpawnPos[3], fFreeBallPos[3];

ConVar			bEquipStockWeapons, bSwitchDuringRespawn, bStealBlurryOverlay, bDroppedItemsCollision, bPrintStats, /*trikzEnable, trikzProjCollide, trikzProjDev*/bPracticeMode;

int				iPlyWhoGotJack;
// int			plyDirecter;
int				ibFirstGrabCheck;
int  			eiJack;
int  			eiPassTarget;
int 			ibBallSpawnedLower;
int 			iRoundResetTick;
int 			iWinStratDistance = 450;
int 			eiDeathBomber;
//int  			trikzProjCollideCurVal;
//int  			trikzProjCollideSave = 2;
Menu			mPassMenu;
bool 			bHalloweenMode;
bool			arrbPlyIsDead[MAXPLAYERS + 1];
bool			arrbBlastJumpStatus[MAXPLAYERS + 1]; // true if blast jumping, false if has landed
bool			arrbPanaceaCheck[MAXPLAYERS + 1];
bool			arrbWinStratCheck[MAXPLAYERS + 1];
bool 			arrbDeathbombCheck[MAXPLAYERS + 1];
// bool			plyTakenDirectHit[MAXPLAYERS + 1];
Cookie  		cookieCountdownCaption, cookieJACKPickupHud, cookieJACKPickupChat, cookieJACKPickupSound, cookieSimpleChatPrint, cookieToggleChatPrint;

// log variables
int user1;
char user1steamid[16];
char user1team[12];
float user1position[3];
int user2;
char user2steamid[16];
char user2team[12];
float user2position[3];

// stats menu variables
char moreurl[128];

public Plugin myinfo =
{
	name		= "4v4 PASS Time Extension",
	author		= "blake++",
	description = "The main plugin for 4v4 Competitive PASS Time.",
	version		= VERSION,
	url			= "https://github.com/blakeplusplus/p4sstime"
};

public void OnPluginStart()
{
	/*GameData gamedata = new GameData("p4sstime");
	if (gamedata)
	{
		DHooks_Initialize(gamedata);
		delete gamedata;
	}*/

	cookieCountdownCaption = RegClientCookie("p4ssClientCountdownCaption", "p4sstime's client setting (1/0) for captions for JACK spawn timer", CookieAccess_Public);
	cookieJACKPickupHud = RegClientCookie("p4ssClientJACKPickupHudText", "p4sstime's client setting (1/0) for HUD text when picking up JACK", CookieAccess_Public);
	cookieJACKPickupChat = RegClientCookie("p4ssClientJACKPickupChatMsg", "p4sstime's client setting (1/0) for chat msg when picking up JACK", CookieAccess_Public);
	cookieJACKPickupSound = RegClientCookie("p4ssClientJACKPickupSound", "p4sstime's client setting (1/0) for sound when picking up JACK", CookieAccess_Public);
	cookieSimpleChatPrint = RegClientCookie("p4ssClientSimpleChatPrint", "p4sstime's client setting (1/0) for simple EoR chat prints", CookieAccess_Public);
	cookieToggleChatPrint = RegClientCookie("p4ssClientToggleChatPrint",  "p4sstime's client setting (1/0) for toggling EoR chat prints", CookieAccess_Public);

	RegConsoleCmd("sm_pt_menu", Command_PassMenu);
	RegConsoleCmd("sm_pt_suicide", Command_PasstimeSuicide);
	RegConsoleCmd("sm_pt_countdowncaption", Command_PasstimeCoundownCaption);
	RegConsoleCmd("sm_pt_jackpickup_hud", Command_PasstimeJackPickupHud);
	RegConsoleCmd("sm_pt_jackpickup_chat", Command_PasstimeJackPickupChat);
	RegConsoleCmd("sm_pt_jackpickup_sound", Command_PasstimeJackPickupSound);
	RegConsoleCmd("sm_pt_simplechatprint", Command_PasstimeSimpleChatPrint);
	RegConsoleCmd("sm_pt_togglechatprint", Command_PasstimeToggleChatPrint);

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("post_inventory_application", Event_PlayerResup);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("pass_get", Event_PassGet);
	HookEvent("pass_free", Event_PassFree);
	HookEvent("pass_ball_stolen", Event_PassStolen);
	HookEvent("pass_score", Event_PassScore);
	HookEvent("pass_pass_caught", Event_PassCaught);
	HookEvent("pass_ball_blocked", Event_PassBallBlocked);
	HookEvent("rocket_jump", Event_RJ);
	HookEvent("rocket_jump_landed", Event_RJLand);
	HookEvent("sticky_jump", Event_SJ);
	HookEvent("sticky_jump_landed", Event_SJLand);
	HookEvent("teamplay_pre_round_time_left", Event_PregameCountdown);
	HookEvent("teamplay_broadcast_audio", Event_MidgameCountdown);
	HookEvent("teamplay_round_win", Event_TeamWin);
	HookEvent("stats_resetround", Event_RoundReset);
	HookEntityOutput("trigger_catapult", "OnCatapulted", Hook_OnCatapult);
	HookEntityOutput("info_passtime_ball_spawn", "OnSpawnBall", Hook_OnSpawnBall);
	AddCommandListener(OnChangeClass, "joinclass");

	bEquipStockWeapons		= CreateConVar("sm_pt_stock_blocklist", "0", "If 1, disable ability to equip shotgun, stickies, and needles; this is needed as allowlists can't normally block stock weapons.", FCVAR_NOTIFY);
	bSwitchDuringRespawn	= CreateConVar("sm_pt_block_instant_respawn", "0", "If 1, disable class switch ability while dead to instantly respawn.", FCVAR_NOTIFY);
	bStealBlurryOverlay		= CreateConVar("sm_pt_disable_intercept_blur", "1", "If 1, disable blurry screen overlay after intercepting or stealing.", FCVAR_NOTIFY);
	bDroppedItemsCollision 	= CreateConVar("sm_pt_disable_jack_drop_item_collision", "1", "If 1, disables the jack colliding with dropped ammo packs or weapons.", FCVAR_NOTIFY);
	bPrintStats		 		= CreateConVar("sm_pt_print_events", "0", "If 1, enables printing of passtime events to chat both during and after games. Does not affect logging.", FCVAR_NOTIFY);
	bPracticeMode	 		= CreateConVar("sm_pt_practice", "0", "If 1, enables practice mode. When the round timer reaches 5 minutes, add 5 minutes to the timer.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	//trikzEnable	 = CreateConVar("sm_pt_trikz", "0", "Set 'trikz' mode. 1 adds friendly knockback for airshots, 2 adds friendly knockback for splash damage, 3 adds friendly knockback for everywhere", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	//trikzProjCollide = CreateConVar("sm_pt_trikz_projcollide", "2", "Manually set team projectile collision behavior when trikz is on. 2 always collides, 1 will cause your projectiles to phase through if you are too close (default game behavior), 0 will cause them to never collide.", 0, true, 0.0, true, 2.0);
	//trikzProjDev = CreateConVar("sm_pt_trikz_projcollide_dev", "0", "DONOTUSE; This command is used solely by the plugin to change values. Changing this manually may cause issues.", FCVAR_HIDDEN, true, 0.0, true, 2.0);

	//HookConVarChange(trikzEnable, Hook_OnTrikzChange);
	//HookConVarChange(trikzProjCollide, Hook_OnProjCollideChange);
	//HookConVarChange(trikzProjDev, Hook_OnProjCollideDev);
	HookConVarChange(bPracticeMode, Hook_OnPracticeModeChange);

	/*for (int client = 1; client <= MaxClients; client++)
		if (IsClientInGame(client))
			OnClientPutInServer(client);*/
	for (int i = MaxClients; i > 0; --i)
	{
		if (!AreClientCookiesCached(i))
		{
			continue;
		}
		OnClientCookiesCached(i);
	}
}

//#include <p4sstime/trikz.sp>
#include "p4sstime/logs.sp"
#include "p4sstime/pass_menu.sp"
#include "p4sstime/practice.sp"
#include "p4sstime/anticheat.sp"
#include "p4sstime/convars.sp"
#include "p4sstime/stats_print.sp"
#include "p4sstime/f2stocks.sp"

public void OnMapInit(const char[] mapName)
{
	// this requires a changelevel!
	if(StrContains(mapName, "stadium") != -1) // stadium has much lower top spawner so do this to avoid false positive win strats
		iWinStratDistance = 200;
}

public void OnMapStart() // getgoallocations
{
	int goal1 = FindEntityByClassname(-1, "func_passtime_goal");
	int goal2 = FindEntityByClassname(goal1, "func_passtime_goal");
	int team1 = GetEntProp(goal1, Prop_Send, "m_iTeamNum");
	if (team1 == 2)
	{
		GetEntPropVector(goal1, Prop_Send, "m_vecOrigin", fBluGoalPos);
		GetEntPropVector(goal2, Prop_Send, "m_vecOrigin", fRedGoalPos);
	}
	else 
	{
		GetEntPropVector(goal2, Prop_Send, "m_vecOrigin", fBluGoalPos);
		GetEntPropVector(goal1, Prop_Send, "m_vecOrigin", fRedGoalPos);
	}
}

Action Event_RoundReset(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i < MaxClients + 1; i++)
		ClearLocalStats(i);
	if(GetConVarInt(bPracticeMode) == 1)
	{
		SetConVarInt(bPracticeMode, 0);
		PrintToChatAll("\x0700ffff[PASS] Game started; practice mode disabled.");
	}
	bHalloweenMode = false;
	iRoundResetTick = GetGameTickCount();
	return Plugin_Handled;
}

Action Event_PregameCountdown(Event event, const char[] name, bool dontBroadcast)
{
	int time = event.GetInt("time");
	for (int x = 1; x < MaxClients + 1; x++)
	{
		if (!IsValidClient(x) || !arrbJackAcqSettings[x].bPlyCoundownCaptionSetting) continue;

		if(time == 10)
			PrintToChat(x, "\x0700ffff[PASS] \x07ff000010 seconds...");
		else if(time == 5)
			PrintToChat(x, "\x0700ffff[PASS] \x07ffff005");
		else if(time == 4)
			PrintToChat(x, "\x0700ffff[PASS] \x07ffff004");
		else if(time == 3)
			PrintToChat(x, "\x0700ffff[PASS] \x07ffff003");
		else if(time == 2)
			PrintToChat(x, "\x0700ffff[PASS] \x0700ff002");
		else if(time == 1)
			PrintToChat(x, "\x0700ffff[PASS] \x0700ff001");
	}
	return Plugin_Handled;
}

Action Event_MidgameCountdown(Event event, const char[] name, bool dontBroadcast)
{
	// if it is halloween, announcer always says 10 seconds, but merasmus says 5-1
	// for pregame, announcer ALWAYS says start

	char sound[128];
	event.GetString("sound", sound, sizeof(sound));
	if(StrEqual(sound, "Passtime.Merasmus.Laugh")) // if this occurs (which it does during halloween right after ball spawn), assume halloween
		bHalloweenMode = true;
	for (int x = 1; x < MaxClients + 1; x++)
	{
		if (!IsValidClient(x) || !arrbJackAcqSettings[x].bPlyCoundownCaptionSetting) continue;

		if(StrEqual(sound, "Announcer.RoundBegins10seconds"))
			PrintToChat(x, "\x0700ffff[PASS] \x07ff000010 seconds...");
		else if(StrEqual(sound, "Passtime.BallSpawn"))
			PrintToChat(x, "\x0700ffff[PASS] \x0700ff00Ball has spawned!");
		if(bHalloweenMode)
		{
			if(StrEqual(sound, "Merasmus.RoundBegins5seconds"))
				PrintToChat(x, "\x0700ffff[PASS] \x07ffff005");
			else if(StrEqual(sound, "Merasmus.RoundBegins4seconds"))
				PrintToChat(x, "\x0700ffff[PASS] \x07ffff004");
			else if(StrEqual(sound, "Merasmus.RoundBegins3seconds"))
				PrintToChat(x, "\x0700ffff[PASS] \x0700ff003");
			else if(StrEqual(sound, "Merasmus.RoundBegins2seconds"))
				PrintToChat(x, "\x0700ffff[PASS] \x0700ff002");
			else if(StrEqual(sound, "Merasmus.RoundBegins1seconds"))
				PrintToChat(x, "\x0700ffff[PASS] \x0700ff001");
		}
		else
		{
			if(StrEqual(sound, "Announcer.RoundBegins5seconds"))
				PrintToChat(x, "\x0700ffff[PASS] \x07ffff005");
			else if(StrEqual(sound, "Announcer.RoundBegins4seconds"))
				PrintToChat(x, "\x0700ffff[PASS] \x07ffff004");
			else if(StrEqual(sound, "Announcer.RoundBegins3seconds"))
				PrintToChat(x, "\x0700ffff[PASS] \x0700ff003");
			else if(StrEqual(sound, "Announcer.RoundBegins2seconds"))
				PrintToChat(x, "\x0700ffff[PASS] \x0700ff002");
			else if(StrEqual(sound, "Announcer.RoundBegins1seconds"))
				PrintToChat(x, "\x0700ffff[PASS] \x0700ff001");
		}
	}
	return Plugin_Handled;
}

Action Event_TeamWin(Event event, const char[] name, bool dontBroadcast)
{
	if (!bPrintStats.BoolValue) return Plugin_Handled;
	CreateTimer(0.5, Timer_DisplayStats);
	iPlyWhoGotJack = 0; // reset this because it's a good idea. doesn't actually fix anything but this shouldn't carry over between rounds
	return Plugin_Handled;
}

int STVTickCount()
{
	int tick;
	tick = GetGameTickCount() - iRoundResetTick;
	return tick;
}

bool IsValidClient(int client, bool blockbots = true)
{
	if (client > 4096) client = EntRefToEntIndex(client);
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (blockbots && IsFakeClient(client)) return false;
	if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	return true;
}

/*-------------------------------------------------- Player Events --------------------------------------------------*/

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if(StrEqual(sArgs, "/more", false) || StrEqual(sArgs, ".more", false))
	{
		CreateTimer(0.1, Timer_ShowMoreTF, client, TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Handled;
	}
	else if(StrEqual(sArgs, "/pass", false) || StrEqual(sArgs, "/p4ss", false) || StrEqual(sArgs, ".pass", false) || StrEqual(sArgs, ".p4ss", false))
	{
		ShowPassMenu(client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

bool TraceEntityFilterPlayer(int entity, int contentsMask) // taken from mgemod; just going to use this instead of isvalidclient for the below function
{
	return entity > MaxClients || !entity;
}

float DistanceAboveGround(int victim) // taken from mgemod
{
	float vStart[3];
	float vEnd[3];
	float vAngles[3] =  { 90.0, 0.0, 0.0 };
	GetClientAbsOrigin(victim, vStart);
	Handle trace = TR_TraceRayFilterEx(vStart, vAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer);

	float distance = -1.0;
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(vEnd, trace);
		distance = GetVectorDistance(vStart, vEnd, false);
	} 
	else 
		LogError("trace error. victim %N(%d)", victim, victim);

	delete trace;
	return distance;
}

Action Event_RJ(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	arrbBlastJumpStatus[client] = true;
	return Plugin_Handled;
}

Action Event_RJLand(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	arrbBlastJumpStatus[client] = false;
	return Plugin_Handled;
}

Action Event_SJ(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	arrbBlastJumpStatus[client] = true;
	return Plugin_Handled;
}

Action Event_SJLand(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	arrbBlastJumpStatus[client] = false;
	return Plugin_Handled;
}

// the below function is dr underscore's fix. thanks!
public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if (condition == TFCond_Ubercharged)
		TF2_RemoveCondition(client, TFCond_UberchargeFading);
}

Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	arrbPlyIsDead[client] = true;
	if(client == eiPassTarget)
	{
		eiDeathBomber = client;
		arrbDeathbombCheck[eiDeathBomber] = true;
	}
	return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
	ClearLocalStats(client);
}

/*-------------------------------------------------- PASS Events --------------------------------------------------*/
void Hook_OnSpawnBall(const char[] name, int caller, int activator, float delay)
{
	char spawnName[24];
	eiJack = FindEntityByClassname(-1, "passtime_ball");
	ibBallSpawnedLower = 0;
	if (bDroppedItemsCollision.BoolValue) SetEntityCollisionGroup(eiJack, 4);
	GetEntPropString(caller, Prop_Data, "m_iName", spawnName, sizeof(spawnName));
	if(StrEqual(spawnName, "passtime_ball_spawn1"))
	{
		LogToGame("passtime_ball spawned from the upper spawnpoint.");
		PrintToSTV("[PASS-TV] passtime_ball spawned from the upper spawnpoint.");
		GetEntPropVector(caller, Prop_Send, "m_vecOrigin", fTopSpawnPos);
	}
	else if(StrEqual(spawnName, "passtime_ball_spawn2"))
	{
		LogToGame("passtime_ball spawned from the lower spawnpoint."); 
		PrintToSTV("[PASS-TV] passtime_ball spawned from the lower spawnpoint.");
		ibBallSpawnedLower = 1;
	}
	else if(StrEqual(spawnName, "passtime_ball_spawn3"))
	{
		LogToGame("passtime_ball spawned from the right spawnpoint.");
		PrintToSTV("[PASS-TV] passtime_ball spawned from the right spawnpoint.");
	}
	else if(StrEqual(spawnName, "passtime_ball_spawn4"))
	{
		LogToGame("passtime_ball spawned from the left spawnpoint.");
		PrintToSTV("[PASS-TV] passtime_ball spawned from the left spawnpoint.");
	}
	ibFirstGrabCheck = true;
}

Action Event_PassFree(Event event, const char[] name, bool dontBroadcast)
{
	int owner = event.GetInt("owner");

	arrbDeathbombCheck[eiDeathBomber] = false; // if anyone at all throws the ball, the deathbomb is automatically false
	
	if (arrbJackAcqSettings[owner].bPlyHudTextSetting)
	{
		SetHudTextParams(-1.0, 0.22, 3.0, 240, 0, 240, 255);
		ShowHudText(owner, 1, "");
	}
	GetEntPropVector(eiJack, Prop_Data, "m_vecAbsOrigin", fFreeBallPos);
	eiPassTarget = EntRefToEntIndex(GetEntPropEnt(owner, Prop_Send, "m_hPasstimePassTarget"));
	if (!(arrbBlastJumpStatus[owner]))
	{
		arrbPanaceaCheck[owner] = false;
		arrbWinStratCheck[owner] = false;
	}	
	SetLogInfo(owner);
	LogToGame("\"%N<%i><%s><%s>\" triggered \"pass_free\" (position \"%.0f %.0f %.0f\")",
		user1, GetClientUserId(user1), user1steamid, user1team,
		user1position[0], user1position[1], user1position[2]);
	return Plugin_Handled;
}

Action Event_PassBallBlocked(Event event, const char[] name, bool dontBroadcast) // When an enemy player blocks a thrown ball without picking it up, via uber or rocket/sticky jumpers
{
	int blocker = event.GetInt("blocker");
	int thrower = event.GetInt("owner");
	arriPlyRoundPassStats[blocker].iPlyBlocks++;
	SetLogInfo(blocker, thrower);
	LogToGame("\"%N<%i><%s><%s>\" triggered \"pass_ball_blocked\" against \"%N<%i><%s><%s>\" (thrower_position \"%.0f %.0f %.0f\") (blocker_position \"%.0f %.0f %.0f\")",
		user1, GetClientUserId(user1), user1steamid, user1team,
		user2, GetClientUserId(user2), user2steamid, user2team,
		user1position[0], user1position[1], user1position[2], 
		user2position[0], user2position[1], user2position[2]);
	user2 = 0;
	return Plugin_Handled;
}

Action Event_PassGet(Event event, const char[] name, bool dontBroadcast)
{
	iPlyWhoGotJack = event.GetInt("owner");
	float position[3];

	SetLogInfo(iPlyWhoGotJack);
	LogToGame("\"%N<%i><%s><%s>\" triggered \"pass_get\" (firstcontact \"%i\") (position \"%.0f %.0f %.0f\")",
		user1, GetClientUserId(user1), user1steamid, user1team, ibFirstGrabCheck,
		user1position[0], user1position[1], user1position[2]);
	if (ibFirstGrabCheck && arrbBlastJumpStatus[iPlyWhoGotJack])
	{
		arriPlyRoundPassStats[iPlyWhoGotJack].iPlyFirstGrabs++;
		arrbPanaceaCheck[iPlyWhoGotJack] = true;
		GetClientAbsOrigin(iPlyWhoGotJack, position);
		float distanceFromTopSpawner = GetVectorDistance(position, fTopSpawnPos, false);
		LogToGame("Panacea check - Distance from top spawner: %.0f, Cutoff distance for winstrat: %i", distanceFromTopSpawner, iWinStratDistance);
		if(distanceFromTopSpawner < iWinStratDistance) // may need to be changed
			{
				arrbPanaceaCheck[iPlyWhoGotJack] = false;
				arrbWinStratCheck[iPlyWhoGotJack] = true;
				// KILL winstratter
				SDKHooks_TakeDamage(iPlyWhoGotJack, iPlyWhoGotJack, iPlyWhoGotJack, 500.0);
				char winstratterName[MAX_NAME_LENGTH];
				GetClientName(iPlyWhoGotJack, winstratterName, sizeof(winstratterName));
				for (int x = 1; x < MaxClients + 1; x++)
				{
					if(!IsValidClient(x) || IsClientSourceTV(x)) continue;
					PrintToChat(x, "\x0700ffff[PASS] \x0700ffff%s\x073BC43B tried to \x078aed8awin strat.", winstratterName);
				}
			}
	}
	else
	{
		arrbPanaceaCheck[iPlyWhoGotJack] = false;
		arrbWinStratCheck[iPlyWhoGotJack] = false;
	}
	ibFirstGrabCheck = false;

	if (arrbJackAcqSettings[iPlyWhoGotJack].bPlyHudTextSetting)
	{
		SetHudTextParams(-1.0, 0.22, 3.0, 240, 0, 240, 255);
		ShowHudText(iPlyWhoGotJack, 1, "YOU HAVE THE JACK");
	}

	if (arrbJackAcqSettings[iPlyWhoGotJack].bPlyChatPrintSetting)
		PrintToChat(iPlyWhoGotJack, "\x07ffff00[PASS]\x0700ff00 YOU HAVE THE JACK!!!");

	if (arrbJackAcqSettings[iPlyWhoGotJack].bPlySoundSetting)
		ClientCommand(iPlyWhoGotJack, "playgamesound Passtime.BallSmack");

	return Plugin_Handled;
}

Action Event_PassCaught(Handle event, const char[] name, bool dontBroadcast)
{
	int	thrower	= GetEventInt(event, "passer");
	int	catcher	= GetEventInt(event, "catcher");
	float dist = GetEventFloat(event, "dist");
	float duration = GetEventFloat(event, "duration");
	int intercept = false;
	int bSave = false;
	int ibHandoffCheck = false;
	iPlyWhoGotJack = catcher;

	char throwerName[MAX_NAME_LENGTH], catcherName[MAX_NAME_LENGTH];
	GetClientName(thrower, throwerName, sizeof(throwerName));
	GetClientName(catcher, catcherName, sizeof(catcherName));

	if (TF2_GetClientTeam(thrower) == TFTeam_Spectator || TF2_GetClientTeam(catcher) == TFTeam_Spectator) return Plugin_Handled;

	if (GetClientTeam(thrower) != GetClientTeam(catcher))
	{
		intercept = true;
		if(InGoalieZone(catcher))
		{
			bSave = true;
			arriPlyRoundPassStats[catcher].iPlySaves++;
			if(bPrintStats.BoolValue)
			{
				for (int x = 1; x < MaxClients + 1; x++)
				{
					if(!IsValidClient(x) || IsClientSourceTV(x)) continue;
					PrintToChat(x, "\x0700ffff[PASS] %s \x07ffff00blocked \x0700ffff%s from scoring!", catcherName, throwerName);
				}
			}
			PrintToSTV("[PASS-TV] %s blocked %s from scoring. Tick: %d", catcherName, throwerName, STVTickCount());
		}
		else
		{
			arriPlyRoundPassStats[catcher].iPlyIntercepts++;
			if(bPrintStats.BoolValue)
			{
				for (int x = 1; x < MaxClients + 1; x++)
				{
					if(!IsValidClient(x) || IsClientSourceTV(x)) continue;
					PrintToChat(x, "\x0700ffff[PASS] %s \x07ff00ffintercepted \x0700ffff%s!", catcherName, throwerName);
				}
			}
			PrintToSTV("[PASS-TV] %s intercepted %s. Tick: %d", catcherName, throwerName, STVTickCount());
		}
	}

	if (TF2_GetClientTeam(thrower) == TF2_GetClientTeam(catcher) && eiPassTarget != catcher && !(GetEntityFlags(catcher) & FL_ONGROUND) && DistanceAboveGround(catcher) > 200) // if on same team and catcher is not locked onto for a pass, also 200 units above ground at least (to ignore just normal non-lock passes)
	{
		if (bPrintStats.BoolValue)
		{
			for (int x = 1; x < MaxClients + 1; x++)
				{
					if(!IsValidClient(x) || IsClientSourceTV(x)) continue;
					PrintToChat(x, "\x0700ffff[PASS] %s \x07ffff00handed off \x0700ffffto %s!", throwerName, catcherName);
				}
		}
		PrintToSTV("[PASS-TV] %s handed off to %s. Tick: %d", throwerName, catcherName, STVTickCount());
		ibHandoffCheck = true;
		arriPlyRoundPassStats[thrower].iPlyHandoffs++;
		eiPassTarget = 0;
	}
	SetLogInfo(catcher, thrower);
	LogToGame("\"%N<%i><%s><%s>\" triggered \"pass_pass_caught\" against \"%N<%i><%s><%s>\" (interception \"%i\") (save \"%i\") (handoff \"%i\") (dist \"%.3f\") (duration \"%.3f\") (thrower_position \"%.0f %.0f %.0f\") (catcher_position \"%.0f %.0f %.0f\")",
		user1, GetClientUserId(user1), user1steamid, user1team,
		user2, GetClientUserId(user2), user2steamid, user2team,
		intercept, bSave, ibHandoffCheck, dist, duration,
		user1position[0], user1position[1], user1position[2], 
		user2position[0], user2position[1], user2position[2]);
	user2 = 0;
	arrbPanaceaCheck[thrower] = false;
	arrbPanaceaCheck[catcher] = false;
	arrbWinStratCheck[thrower] = false;
	arrbWinStratCheck[catcher] = false;

	return Plugin_Handled;
}

Action Event_PassStolen(Event event, const char[] name, bool dontBroadcast)
{
	int thief  = event.GetInt("attacker");
	int victim = event.GetInt("victim");
	bool steal2save = false;
	iPlyWhoGotJack = thief;
	if(InGoalieZone(thief))
		{
			arriPlyRoundPassStats[thief].iPlySteal2Saves++;
			steal2save = true;
		}

	SetLogInfo(thief, victim);
	LogToGame("\"%N<%i><%s><%s>\" triggered \"pass_ball_stolen\" against \"%N<%i><%s><%s>\" (steal defense \"%d\") (thief_position \"%.0f %.0f %.0f\") (victim_position \"%.0f %.0f %.0f\")",
		user1, GetClientUserId(user1), user1steamid, user1team,
		user2, GetClientUserId(user2), user2steamid, user2team,
		steal2save,
		user1position[0], user1position[1], user1position[2], 
		user2position[0], user2position[1], user2position[2]);
	user2 = 0;
	arrbPanaceaCheck[thief] = false;
	arrbPanaceaCheck[victim] = false;
	arrbWinStratCheck[thief] = false;
	arrbWinStratCheck[victim] = false;

	if (arrbJackAcqSettings[victim].bPlyHudTextSetting)
	{
		SetHudTextParams(-1.0, 0.22, 3.0, 240, 0, 240, 255);
		ShowHudText(victim, 1, "");
	}
	if (bPrintStats.BoolValue)
	{
		char thiefName[MAX_NAME_LENGTH], victimName[MAX_NAME_LENGTH];
		GetClientName(thief, thiefName, sizeof(thiefName));
		GetClientName(victim, victimName, sizeof(victimName));
		if(InGoalieZone(thief))
		{
			for (int x = 1; x < MaxClients + 1; x++)
				{
					if(!IsValidClient(x) || IsClientSourceTV(x)) continue;
					PrintToChat(x, "\x0700ffff[PASS] %s\x07ff8000 defensively stole from\x0700ffff %s!", thiefName, victimName);
				}
			PrintToSTV("[PASS-TV] %s defensively stole from %s. Tick: %d", thiefName, victimName, STVTickCount());
		}
		else
		{
			for (int x = 1; x < MaxClients + 1; x++)
				{
					if(!IsValidClient(x) || IsClientSourceTV(x)) continue;
					PrintToChat(x, "\x0700ffff[PASS] %s\x07ff8000 stole from\x0700ffff %s!", thiefName, victimName);
				}
			PrintToSTV("[PASS-TV] %s stole from %s. Tick: %d", thiefName, victimName, STVTickCount());
		}
	}
	arriPlyRoundPassStats[thief].iPlySteals++;
	return Plugin_Handled;
}

Action Event_PassScore(Event event, const char[] name, bool dontBroadcast)
{
	int	scorer = event.GetInt("scorer");
	int	points = event.GetInt("points");
	int assistant = event.GetInt("assister");
	char playerName[MAX_NAME_LENGTH], assistantName[MAX_NAME_LENGTH];
	GetClientName(scorer, playerName, sizeof(playerName));

	if(ibBallSpawnedLower)
		arrbPanaceaCheck[scorer] = false;

	float fScoredBallPos[3];
	GetEntPropVector(eiJack, Prop_Send, "m_vecOrigin", fScoredBallPos);
	float dist = GetVectorDistance(fFreeBallPos, fScoredBallPos, false);

	if(arrbDeathbombCheck[eiDeathBomber])
	{
		SetLogInfo(eiDeathBomber);
		LogToGame("\"%N<%i><%s><%s>\" triggered \"pass_score\" (points \"%i\") (panacea \"%d\") (win strat \"%d\") (deathbomb \"%d\") (dist \"%.0f\") (position \"%.0f %.0f %.0f\")", 
			user1, GetClientUserId(user1), user1steamid, user1team,
			points, arrbPanaceaCheck[scorer], arrbWinStratCheck[scorer], arrbDeathbombCheck[eiDeathBomber], dist,
			user1position[0], user1position[1], user1position[2]);
		arriPlyRoundPassStats[eiDeathBomber].iPlyScores++;
		arriPlyRoundPassStats[eiDeathBomber].iPlyDeathbombs++;

		GetClientName(scorer, assistantName, sizeof(assistantName));
		SetLogInfo(scorer);
		LogToGame("\"%N<%i><%s><%s>\" triggered \"pass_score_assist\" (position \"%.0f %.0f %.0f\")", 
			user1, GetClientUserId(user1), user1steamid, user1team,
			user1position[0], user1position[1], user1position[2]);
		arriPlyRoundPassStats[scorer].iPlyAssists++;
	}
	else
	{
		SetLogInfo(scorer);
		LogToGame("\"%N<%i><%s><%s>\" triggered \"pass_score\" (points \"%i\") (panacea \"%d\") (win strat \"%d\") (deathbomb \"%d\") (dist \"%.0f\") (position \"%.0f %.0f %.0f\")", 
			user1, GetClientUserId(user1), user1steamid, user1team,
			points, arrbPanaceaCheck[scorer], arrbWinStratCheck[scorer], arrbDeathbombCheck[eiDeathBomber], dist,
			user1position[0], user1position[1], user1position[2]);
		arriPlyRoundPassStats[scorer].iPlyScores++;
		
		if (assistant > 0)
		{
			GetClientName(assistant, assistantName, sizeof(assistantName));
			SetLogInfo(assistant);
			LogToGame("\"%N<%i><%s><%s>\" triggered \"pass_score_assist\" (position \"%.0f %.0f %.0f\")", 
				user1, GetClientUserId(user1), user1steamid, user1team,
				user1position[0], user1position[1], user1position[2]);
			arriPlyRoundPassStats[assistant].iPlyAssists++;
		}
	}

	if(arrbPanaceaCheck[scorer] && TF2_GetPlayerClass(scorer) != TFClass_Medic)
		arriPlyRoundPassStats[scorer].iPlyPanaceas++;
	else if(arrbWinStratCheck[scorer])
		arriPlyRoundPassStats[scorer].iPlyWinStrats++;
	
	if(bPrintStats.BoolValue)
	{
		if(arrbPanaceaCheck[scorer] && TF2_GetPlayerClass(scorer) != TFClass_Medic)
		{
			for (int x = 1; x < MaxClients + 1; x++)
				{
					if(!IsValidClient(x) || IsClientSourceTV(x)) continue;
					PrintToChat(x, "\x0700ffff[PASS] %s\x073BC43B scored a \x074df74dPanacea!", playerName);
				}
			PrintToSTV("[PASS-TV] %s scored a Panacea. Tick: %d", playerName, STVTickCount());
		}
		else if(arrbWinStratCheck[scorer])
		{
			for (int x = 1; x < MaxClients + 1; x++)
				{
					if(!IsValidClient(x) || IsClientSourceTV(x)) continue;
					PrintToChat(x, "\x0700ffff[PASS] %s\x073BC43B scored a \x078aed8awin strat!", playerName);
				}
			PrintToSTV("[PASS-TV] %s scored a win strat. Tick: %d", playerName, STVTickCount());
		}
		else if(arrbDeathbombCheck[eiDeathBomber])
		{
			GetClientName(eiDeathBomber, playerName, sizeof(playerName));
			for (int x = 1; x < MaxClients + 1; x++)
				{
					if(!IsValidClient(x) || IsClientSourceTV(x)) continue;
					PrintToChat(x, "\x0700ffff[PASS] %s\x073BC43B scored a \x0797e043deathbomb!", playerName);
				}
			PrintToSTV("[PASS-TV] %s scored a deathbomb. Tick: %d", playerName, STVTickCount());
		}
		else if(dist > 1600)
		{
			for (int x = 1; x < MaxClients + 1; x++)
				{
					if(!IsValidClient(x) || IsClientSourceTV(x)) continue;
					PrintToChat(x, "\x0700ffff[PASS] %s\x073BC43B scored a goal from a distance of %.0fhu!", playerName, dist);
				}
			PrintToSTV("[PASS-TV] %s scored a goal from distance of %.0fhu. Tick: %d", playerName, dist, STVTickCount());
		}
		else if(assistant > 0)
		{
			for (int x = 1; x < MaxClients + 1; x++)
				{
					if(!IsValidClient(x) || IsClientSourceTV(x)) continue;
					PrintToChat(x, "\x0700ffff[PASS] %s\x073BC43B scored a goal \x0700ffffassisted by %s!", playerName, assistantName);
				}
			PrintToSTV("[PASS-TV] %s scored a goal assisted by %s. Tick: %d", playerName, assistantName, STVTickCount());
		}
		else
		{
			for (int x = 1; x < MaxClients + 1; x++)
				{
					if(!IsValidClient(x) || IsClientSourceTV(x)) continue;
					PrintToChat(x, "\x0700ffff[PASS] %s\x073BC43B scored a goal!", playerName);
				}
			PrintToSTV("[PASS-TV] %s scored a goal. Tick: %d", playerName, STVTickCount());
		}
	}
	arrbPanaceaCheck[scorer] = false;
	arrbWinStratCheck[scorer] = false; // reset these cuz its good idea

	return Plugin_Handled;
}

bool InGoalieZone(int client)
{
	int	team = GetClientTeam(client);
	float position[3];
	GetClientAbsOrigin(client, position);

	if (team == view_as<int>(TFTeam_Blue))
	{
		float distance = GetVectorDistance(position, fBluGoalPos, false);
		if (distance < 200) return true;
	}

	if (team == view_as<int>(TFTeam_Red))
	{
		float distance = GetVectorDistance(position, fRedGoalPos, false);
		if (distance < 200) return true;
	}
	return false;
}

void Hook_OnCatapult(const char[] output, int caller, int activator, float delay)
{
	char catapultName[15];
	GetEntPropString(caller, Prop_Data, "m_iName", catapultName, sizeof(catapultName));
	if(activator == eiJack && iPlyWhoGotJack != 0)
	{
		if(StrEqual(catapultName, "red_catapult1") || StrEqual(catapultName, "red_catapult2") || StrEqual(catapultName, "blu_catapult1") || StrEqual(catapultName, "blu_catapult2") && IsClientConnected(iPlyWhoGotJack))
		{
			SetLogInfo(iPlyWhoGotJack);
			LogToGame("\"%N<%i><%s><%s>\" triggered \"%s\" with the jack (position \"%.0f %.0f %.0f\")", 
				user1, GetClientUserId(user1), user1steamid, user1team,
				catapultName, user1position[0], user1position[1], user1position[2]);
			arriPlyRoundPassStats[iPlyWhoGotJack].iPlyCatapults++;
			PrintToSTV("[PASS-TV] %N triggered \"%s\" with the jack. Tick: %d", user1, catapultName, STVTickCount());
		}
	}
}