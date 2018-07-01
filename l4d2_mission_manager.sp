#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d2_mission_manager>

public Plugin myinfo = {
	name = "L4D2 Mission Manager",
	author = "Rikka0w0",
	description = "Mission manager for L4D2, provide information about map orders for other plugins",
	version = "v0.9.0",
	url = "http://forums.alliedmods.net/showthread.php?t=308725"
}

public void OnPluginStart(){
	char game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead", false) && !StrEqual(game_name, "left4dead2", false)) {
		SetFailState("Use this in Left 4 Dead or Left 4 Dead 2 only.");
	}

	CacheMissions();
	LMM_InitLists();
	ParseMissions();
	FireEvent_OnLMMUpdateList();
		
	RegConsoleCmd("sm_lmm_list", Command_List, "Usage: sm_lmm_list [<coop|versus|scavenge|survival|invalid>]");
}

public void OnPluginEnd() {
	LMM_FreeLists();
}

public Action Command_List(int iClient, int args) {
	if (args < 1) {
		for (int i=0; i<4; i++) {
			LMM_GAMEMODE gamemode = view_as<LMM_GAMEMODE>(1<<i);
			DumpMissionInfo(iClient, gamemode);
		}
	} else {
		char gamemodeName[LEN_GAMEMODE_NAME];
		GetCmdArg(1, gamemodeName, sizeof(gamemodeName));
		
		if (StrEqual("invalid", gamemodeName, false)) {
			int missionCount = LMM_GetNumberOfInvalidMissions();
			ReplyToCommand(iClient, "Invalid missions (count:%d):\n", missionCount);
			for (int iMission=0; iMission<missionCount; iMission++) {
				char missionName[LEN_MISSION_NAME];
				LMM_GetInvalidMissionName(iMission, missionName, sizeof(missionName));
				ReplyToCommand(iClient, ", %s\n", missionName);
			}
		} else {
			LMM_GAMEMODE gamemode = StringToGamemode(gamemodeName);
			DumpMissionInfo(iClient, gamemode);
		}
	}
	return Plugin_Handled;
}

void DumpMissionInfo(int client, LMM_GAMEMODE gamemode) {
	char gamemodeName[LEN_GAMEMODE_NAME];
	GamemodeToString(gamemode, gamemodeName, sizeof(gamemodeName));

	int missionCount = LMM_GetNumberOfMissions(gamemode);
	char missionName[LEN_MISSION_NAME];
	char mapName[LEN_MAP_FILENAME];
	
	ReplyToCommand(client, "Gamemode = %s (%d missions)\n", gamemodeName, missionCount);

	for (int iMission=0; iMission<missionCount; iMission++) {
		LMM_GetMissionName(gamemode, iMission, missionName, sizeof(missionName));
		int mapCount = LMM_GetNumberOfMaps(gamemode, iMission);
		ReplyToCommand(client, "%d. %s (%d maps)\n", iMission+1, missionName, mapCount);
				
		for (int iMap=0; iMap<mapCount; iMap++) {
			LMM_GetMapName(gamemode, iMission, iMap, mapName, sizeof(mapName));
			ReplyToCommand(client, ", %s", mapName);
		}
	}
	ReplyToCommand(client, "-------------------\n");
}

LMM_GAMEMODE StringToGamemode(const char[] name) {
	if(StrEqual("coop", name, false)) {
		return LMM_GAMEMODE_COOP;
	} else if (StrEqual("versus", name, false)) {
		return LMM_GAMEMODE_VERSUS;
	} else if(StrEqual("scavenge", name, false)) {
		return LMM_GAMEMODE_SCAVENGE;
	} else if (StrEqual("survival", name, false)) {
		return LMM_GAMEMODE_SURVIVAL;
	}
	
	return LMM_GAMEMODE_UNKNOWN;
}

int GamemodeToString(LMM_GAMEMODE gamemode, char[] name, int length) {
	switch (gamemode) {
		case LMM_GAMEMODE_COOP: {
			return strcopy(name, length, "coop");
		}
		case LMM_GAMEMODE_VERSUS: {
			return strcopy(name, length, "versus");
		}
		case LMM_GAMEMODE_SCAVENGE: {
			return strcopy(name, length, "scavenge");
		}
		case LMM_GAMEMODE_SURVIVAL: {
			return strcopy(name, length, "survival");
		}
	}
	
	return strcopy(name, length, "unknown");
}

/* ========== Register Native APIs ========== */
Handle g_hForward_OnLMMUpdateList;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
   CreateNative("LMM_GetCurrentGameMode", Native_GetCurrentGameMode);
   CreateNative("LMM_GetNumberOfMissions", Native_GetNumberOfMissions);
   CreateNative("LMM_FindMissionIndexByName", Native_FindMissionIndexByName);
   CreateNative("LMM_GetMissionName", Native_GetMissionName);
   CreateNative("LMM_GetNumberOfMaps", Native_GetNumberOfMaps);
   CreateNative("LMM_GetMapName", Native_GetMapName);
   CreateNative("LMM_GetNumberOfInvalidMissions", Native_GetNumberOfInvalidMissions);
   CreateNative("LMM_GetInvalidMissionName", Native_GetInvalidMissionName);
   g_hForward_OnLMMUpdateList = CreateGlobalForward("OnLMMUpdateList", ET_Ignore);
   RegPluginLibrary("l4d2_mission_manager");
   return APLRes_Success;
}

void FireEvent_OnLMMUpdateList() {
	Call_StartForward(g_hForward_OnLMMUpdateList);
	Call_Finish();
}

public int Native_GetCurrentGameMode(Handle plugin, int numParams) {
	LMM_GAMEMODE gamemode;
	//Get the gamemode string from the game
	char strGameMode[20];
	FindConVar("mp_gamemode").GetString(strGameMode, sizeof(strGameMode));
	
	//Set the global gamemode int for this plugin
	if(StrEqual(strGameMode, "coop", false))
		gamemode = LMM_GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "realism", false))
		gamemode = LMM_GAMEMODE_COOP;
	else if(StrEqual(strGameMode,"versus", false))
		gamemode = LMM_GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "teamversus", false))
		gamemode = LMM_GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "scavenge", false))
		gamemode = LMM_GAMEMODE_SCAVENGE;
	else if(StrEqual(strGameMode, "teamscavenge", false))
		gamemode = LMM_GAMEMODE_SCAVENGE;
	else if(StrEqual(strGameMode, "survival", false))
		gamemode = LMM_GAMEMODE_SURVIVAL;
	else if(StrEqual(strGameMode, "mutation1", false))		//Last Man On Earth
		gamemode = LMM_GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation2", false))		//Headshot!
		gamemode = LMM_GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation3", false))		//Bleed Out
		gamemode = LMM_GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation4", false))		//Hard Eight
		gamemode = LMM_GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation5", false))		//Four Swordsmen
		gamemode = LMM_GAMEMODE_COOP;
	//else if(StrEqual(strGameMode, "mutation6", false))	//Nothing here
	//	gamemode = LMM_GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation7", false))		//Chainsaw Massacre
		gamemode = LMM_GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation8", false))		//Ironman
		gamemode = LMM_GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation9", false))		//Last Gnome On Earth
		gamemode = LMM_GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation10", false))	//Room For One
		gamemode = LMM_GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation11", false))	//Healthpackalypse!
		gamemode = LMM_GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "mutation12", false))	//Realism Versus
		gamemode = LMM_GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "mutation13", false))	//Follow the Liter
		gamemode = LMM_GAMEMODE_SCAVENGE;
	else if(StrEqual(strGameMode, "mutation14", false))	//Gib Fest
		gamemode = LMM_GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation15", false))	//Versus Survival
		gamemode = LMM_GAMEMODE_SURVIVAL;
	else if(StrEqual(strGameMode, "mutation16", false))	//Hunting Party
		gamemode = LMM_GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation17", false))	//Lone Gunman
		gamemode = LMM_GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation18", false))	//Bleed Out Versus
		gamemode = LMM_GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "mutation19", false))	//Taaannnkk!
		gamemode = LMM_GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "mutation20", false))	//Healing Gnome
		gamemode = LMM_GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "community1", false))	//Special Delivery
		gamemode = LMM_GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "community2", false))	//Flu Season
		gamemode = LMM_GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "community3", false))	//Riding My Survivor
		gamemode = LMM_GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "community4", false))	//Nightmare
		gamemode = LMM_GAMEMODE_SURVIVAL;
	else if(StrEqual(strGameMode, "community5", false))	//Death's Door
		gamemode = LMM_GAMEMODE_COOP;
	else
		gamemode = LMM_GAMEMODE_UNKNOWN;
		
	return view_as<int>gamemode;
}

/* ========== Mission Parser Outputs ========== */
ArrayList g_hStr_InvalidMissionNames;
ArrayList g_hStr_CoopMissionNames;	// g_hStr_CoopMissionNames.Length = Number of Coop Missions
ArrayList g_hInt_CoopEntries;		// g_hInt_CoopEntries.Length = Number of Coop Missions + 1
ArrayList g_hStr_CoopMaps;			// The value of nth element in g_hInt_CoopEntries is the offset of nth mission's first map 
ArrayList g_hStr_VersusMissionNames;
ArrayList g_hInt_VersusEntries;
ArrayList g_hStr_VersusMaps;
ArrayList g_hStr_ScavengeMissionNames;
ArrayList g_hInt_ScavengeEntries;
ArrayList g_hStr_ScavengeMaps;
ArrayList g_hStr_SurvicalMissionNames;
ArrayList g_hInt_SurvivalEntries;
ArrayList g_hStr_SurvivalMaps;

void LMM_InitLists() {
	g_hStr_InvalidMissionNames = new ArrayList(LEN_MISSION_NAME);

	g_hStr_CoopMissionNames = new ArrayList(LEN_MISSION_NAME);
	g_hInt_CoopEntries = new ArrayList(1);
	g_hInt_CoopEntries.Push(0);
	g_hStr_CoopMaps = new ArrayList(LEN_MAP_FILENAME);
	
	g_hStr_VersusMissionNames = new ArrayList(LEN_MISSION_NAME);
	g_hInt_VersusEntries = new ArrayList(1);
	g_hInt_VersusEntries.Push(0);
	g_hStr_VersusMaps = new ArrayList(LEN_MAP_FILENAME);
	
	g_hStr_ScavengeMissionNames = new ArrayList(LEN_MISSION_NAME);
	g_hInt_ScavengeEntries = new ArrayList(1);
	g_hInt_ScavengeEntries.Push(0);
	g_hStr_ScavengeMaps = new ArrayList(LEN_MAP_FILENAME);
	
	g_hStr_SurvicalMissionNames = new ArrayList(LEN_MISSION_NAME);
	g_hInt_SurvivalEntries = new ArrayList(1);
	g_hInt_SurvivalEntries.Push(0);
	g_hStr_SurvivalMaps = new ArrayList(LEN_MAP_FILENAME);
}

void LMM_FreeLists() {
	delete g_hStr_InvalidMissionNames;

	delete g_hStr_CoopMissionNames;
	delete g_hInt_CoopEntries;
	delete g_hStr_CoopMaps;
	delete g_hStr_VersusMissionNames;
	delete g_hInt_VersusEntries;
	delete g_hStr_VersusMaps;
	delete g_hStr_ScavengeMissionNames;
	delete g_hInt_ScavengeEntries;
	delete g_hStr_ScavengeMaps;
	delete g_hStr_SurvicalMissionNames;
	delete g_hInt_SurvivalEntries;
	delete g_hStr_SurvivalMaps;
}

ArrayList LMM_GetMissionNameList(LMM_GAMEMODE gamemode) {
	switch (gamemode) {
		case LMM_GAMEMODE_COOP: {
			return g_hStr_CoopMissionNames;
		}
		case LMM_GAMEMODE_VERSUS: {
			return g_hStr_VersusMissionNames;
		}
		case LMM_GAMEMODE_SCAVENGE: {
			return g_hStr_ScavengeMissionNames;
		}
		case LMM_GAMEMODE_SURVIVAL: {
			return g_hStr_SurvicalMissionNames;
		}
	}
	
	return null;
}

ArrayList LMM_GetEntryList(LMM_GAMEMODE gamemode) {
	switch (gamemode) {
		case LMM_GAMEMODE_COOP: {
			return g_hInt_CoopEntries;
		}
		case LMM_GAMEMODE_VERSUS: {
			return g_hInt_VersusEntries;
		}
		case LMM_GAMEMODE_SCAVENGE: {
			return g_hInt_ScavengeEntries;
		}
		case LMM_GAMEMODE_SURVIVAL: {
			return g_hInt_SurvivalEntries;
		}
	}
	
	return null;
}

ArrayList LMM_GetMapList(LMM_GAMEMODE gamemode) {
	switch (gamemode) {
		case LMM_GAMEMODE_COOP: {
			return g_hStr_CoopMaps;
		}
		case LMM_GAMEMODE_VERSUS: {
			return g_hStr_VersusMaps;
		}
		case LMM_GAMEMODE_SCAVENGE: {
			return g_hStr_ScavengeMaps;
		}
		case LMM_GAMEMODE_SURVIVAL: {
			return g_hStr_SurvivalMaps;
		}
	}
	
	return null;
}

public int Native_GetNumberOfMissions(Handle plugin, int numParams) {
	if (numParams < 1)
		return -1;
	
	LMM_GAMEMODE gamemode = view_as<LMM_GAMEMODE>GetNativeCell(1);
	switch (gamemode) {
		case LMM_GAMEMODE_COOP: {
			return g_hStr_CoopMissionNames.Length;
		}
		case LMM_GAMEMODE_VERSUS: {
			return g_hStr_VersusMissionNames.Length;
		}
		case LMM_GAMEMODE_SCAVENGE: {
			return g_hStr_ScavengeMissionNames.Length;
		}
		case LMM_GAMEMODE_SURVIVAL: {
			return g_hStr_SurvicalMissionNames.Length;
		}
	}
	
	return -1;	
}

public int Native_FindMissionIndexByName(Handle plugin, int numParams) {
	if (numParams < 1)
		return -1;
	
	// Get parameters
	LMM_GAMEMODE gamemode = view_as<LMM_GAMEMODE>GetNativeCell(1);
	int length;
	GetNativeStringLength(2, length);
	char[] missionName = new char[length+1];
	GetNativeString(2, missionName, length+1);
	
	ArrayList missionNameList = LMM_GetMissionNameList(gamemode);
	if (missionNameList == null)
		return -1;
	
	return missionNameList.FindString(missionName);
}

public int Native_GetMissionName(Handle plugin, int numParams) {
	if (numParams < 4)
		return -1;
	
	// Get parameters
	LMM_GAMEMODE gamemode = view_as<LMM_GAMEMODE>GetNativeCell(1);
	int missionIndex = GetNativeCell(2);
	int length = GetNativeCell(4);
	
	ArrayList missionNameList = LMM_GetMissionNameList(gamemode);
	if (missionNameList == null)
		return -1;
	
	
	char missionName[LEN_MISSION_NAME];
	missionNameList.GetString(missionIndex, missionName, sizeof(missionName));
	
	if (SetNativeString(3, missionName, length, false) != SP_ERROR_NONE)
		return -1;
		
	return 0;
}

public int Native_GetNumberOfMaps(Handle plugin, int numParams) {
	if (numParams < 2)
		return -1;
	
	// Get parameters
	LMM_GAMEMODE gamemode = view_as<LMM_GAMEMODE>GetNativeCell(1);
	int missionIndex = GetNativeCell(2);
	
	ArrayList entryList = LMM_GetEntryList(gamemode);
	if (entryList == null)
		return -1;
		
	if (missionIndex > entryList.Length - 1)
		return -1;
		
	int startMapIndex = entryList.Get(missionIndex);
	int endMapIndex = entryList.Get(missionIndex + 1);
		
	return endMapIndex - startMapIndex;
}

public int Native_GetMapName(Handle plugin, int numParams) {
	if (numParams < 5)
		return -1;
	
	// Get parameters
	LMM_GAMEMODE gamemode = view_as<LMM_GAMEMODE>GetNativeCell(1);
	int missionIndex = GetNativeCell(2);
	int mapIndex = GetNativeCell(3);
	int length = GetNativeCell(5);
	
	ArrayList entryList = LMM_GetEntryList(gamemode);
	if (entryList == null)
		return -1;
		
	if (missionIndex > entryList.Length - 1)
		return -1;
		
	int mapIndexOffset = entryList.Get(missionIndex);
	ArrayList mapList = LMM_GetMapList(gamemode);
	
	char mapName[LEN_MAP_FILENAME];
	mapList.GetString(mapIndexOffset+mapIndex, mapName, sizeof(mapName));
	
	if (SetNativeString(4, mapName, length, false) != SP_ERROR_NONE)
		return -1;
		
	return 0;
}

public int Native_GetNumberOfInvalidMissions(Handle plugin, int numParams) {
	return g_hStr_InvalidMissionNames.Length;
}

public int Native_GetInvalidMissionName(Handle plugin, int numParams) {
	if (numParams < 2)
		return -1;
	
	int missionIndex = GetNativeCell(1);
	int length = GetNativeCell(3);
	
	char missionName[LEN_MISSION_NAME];
	g_hStr_InvalidMissionNames.GetString(missionIndex, missionName, sizeof(missionName));
	
	if (SetNativeString(2, missionName, length, false) != SP_ERROR_NONE)
		return -1;
		
	return 0;
}

/* ========== Mission Parser ========== */
// MissionParser state variables
int g_MissionParser_UnknownCurLayer;
int g_MissionParser_UnknownPreState;
int g_MissionParser_State;
#define MPS_UNKNOWN -1
#define MPS_ROOT 0
#define MPS_MISSION 1
#define MPS_MODES 2
#define MPS_GAMEMODE 3
#define MPS_MAP 4

LMM_GAMEMODE g_MissionParser_CurGameMode;
char g_MissionParser_MissionName[LEN_MISSION_NAME];
int g_MissionParser_CurMapID;
ArrayList g_hIntMap_Index;
ArrayList g_hStrMap_FileName;

public SMCResult MissionParser_NewSection(SMCParser smc, const char[] name, bool opt_quotes) {
	switch (g_MissionParser_State) {
		case MPS_ROOT: {
			if(strcmp("mission", name, false)==0) {
				g_MissionParser_State = MPS_MISSION;
			} else {
				g_MissionParser_UnknownPreState = g_MissionParser_State;
				g_MissionParser_UnknownCurLayer = 1;
				g_MissionParser_State = MPS_UNKNOWN;
				// PrintToServer("MissionParser_NewSection found an unknown structure: %s\n",name);
			}
		}
		case MPS_MISSION: {
			if(StrEqual("modes", name, false)) {
				g_MissionParser_State = MPS_MODES;
				// PrintToServer("Entering modes section\n");
			} else {
				g_MissionParser_UnknownPreState = g_MissionParser_State;
				g_MissionParser_UnknownCurLayer = 1;
				g_MissionParser_State = MPS_UNKNOWN;
				// PrintToServer("MissionParser_NewSection found an unknown structure: %s\n",name);
			}
		}
		case MPS_MODES: {
			g_MissionParser_CurGameMode = StringToGamemode(name);
			if (g_MissionParser_CurGameMode == LMM_GAMEMODE_UNKNOWN) {
				g_MissionParser_UnknownPreState = g_MissionParser_State;
				g_MissionParser_UnknownCurLayer = 1;
				g_MissionParser_State = MPS_UNKNOWN;
				// PrintToServer("MissionParser_NewSection found an unknown structure: %s\n",name);
			} else {
				g_hIntMap_Index.Clear();
				g_hStrMap_FileName.Clear();
				g_MissionParser_State = MPS_GAMEMODE;
			}
			
			// PrintToServer("Enter gamemode: %d (%s)\n", g_MissionParser_CurGameMode, name);
		}
		case MPS_GAMEMODE: {
			int mapID = StringToInt(name);
			if (mapID > 0) {	// Valid map section
				g_MissionParser_State = MPS_MAP;
				g_MissionParser_CurMapID = mapID;
			} else {
				// Skip invalid sections
				g_MissionParser_UnknownPreState = g_MissionParser_State;
				g_MissionParser_UnknownCurLayer = 1;
				g_MissionParser_State = MPS_UNKNOWN;
				//PrintToServer("MissionParser_NewSection found an unknown structure: %s\n",name);
			}
		}
		case MPS_MAP: {
			// Do not traverse further
			g_MissionParser_UnknownPreState = g_MissionParser_State;
			g_MissionParser_UnknownCurLayer = 1;
			g_MissionParser_State = MPS_UNKNOWN;
			//PrintToServer("MissionParser_NewSection found an unknown structure: %s\n",name);
		}
		
		case MPS_UNKNOWN: { // Traverse through unknown structures
			g_MissionParser_UnknownCurLayer++;
		}
	}
	
	return SMCParse_Continue;
}

public SMCResult MissionParser_KeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes) {
	switch (g_MissionParser_State) {
		case MPS_MISSION: {
			if (strcmp("Name", key, false)==0) {
				strcopy(g_MissionParser_MissionName, LEN_MISSION_NAME, value);
			}
		}
		case MPS_MAP: {
			if (StrEqual("Map", key, false)) {
				g_hIntMap_Index.Push(g_MissionParser_CurMapID);
				g_hStrMap_FileName.PushString(value);
				// PrintToServer("Map %d: %s\n", g_MissionParser_CurMapID, value);
			}
		}
	}
	
	return SMCParse_Continue;
}

public SMCResult MissionParser_EndSection(SMCParser smc) {
	switch (g_MissionParser_State) {
		case MPS_MISSION: {
			g_MissionParser_State = MPS_ROOT;
		}
		
		case MPS_MODES: {
			// PrintToServer("Leaving modes section\n");
			g_MissionParser_State = MPS_MISSION;
		}
		
		case MPS_GAMEMODE: {
			// PrintToServer("Leaving gamemode: %d", g_MissionParser_CurGameMode);
			g_MissionParser_State = MPS_MODES;
			
			int numOfValidMaps = 0;
			char mapFile[LEN_MAP_FILENAME];
			// Make sure that all map indexes are consecutive and start from 1
			// And validate maps
			for (int iMap=1; iMap<=g_hIntMap_Index.Length; iMap++) {
				int index = g_hIntMap_Index.FindValue(iMap);
				if (index < 0) {
					char gamemodeName[LEN_GAMEMODE_NAME];
					GamemodeToString(g_MissionParser_CurGameMode, gamemodeName, sizeof(gamemodeName));
					if (g_hStr_InvalidMissionNames.FindString(g_MissionParser_MissionName) < 0) {
						g_hStr_InvalidMissionNames.PushString(g_MissionParser_MissionName);
					}
					LogError("Mission %s contains invalid \"%s\" section", g_MissionParser_MissionName, gamemodeName);
					return SMCParse_HaltFail;
				}
				
				g_hStrMap_FileName.GetString(index, mapFile, sizeof(mapFile));
				if (!IsMapValid(mapFile)) {
					char gamemodeName[LEN_GAMEMODE_NAME];
					GamemodeToString(g_MissionParser_CurGameMode, gamemodeName, sizeof(gamemodeName));
					if (g_hStr_InvalidMissionNames.FindString(g_MissionParser_MissionName) < 0) {
						g_hStr_InvalidMissionNames.PushString(g_MissionParser_MissionName);
					}
					LogError("Mission %s contains invalid map: \"%s\", gamemode: \"%s\"", g_MissionParser_MissionName, mapFile, gamemodeName);
					return SMCParse_HaltFail;
				}
				numOfValidMaps++;
			}
			
			if (numOfValidMaps < 1) {
				char gamemodeName[LEN_GAMEMODE_NAME];
				GamemodeToString(g_MissionParser_CurGameMode, gamemodeName, sizeof(gamemodeName));
				LogError("Mission %s does not contain any valid map in gamemode: \"%s\"", g_MissionParser_MissionName, gamemodeName);
				return SMCParse_Continue;
			}
			
			// Add them to corresponding map lists
			ArrayList mapList = LMM_GetMapList(g_MissionParser_CurGameMode);
			
			for (int iMap=1; iMap<=g_hIntMap_Index.Length; iMap++) {
				int index = g_hIntMap_Index.FindValue(iMap);
				
				g_hStrMap_FileName.GetString(index, mapFile, sizeof(mapFile));
				mapList.PushString(mapFile);
			}
			
			// Add a new entry
			ArrayList entryList = LMM_GetEntryList(g_MissionParser_CurGameMode);
			int lastOffset = entryList.Get(entryList.Length-1);
			entryList.Push(lastOffset+g_hIntMap_Index.Length);
			
			// Add to mission name list
			ArrayList missionName = LMM_GetMissionNameList(g_MissionParser_CurGameMode);
			missionName.PushString(g_MissionParser_MissionName);
		}
		
		case MPS_MAP: {
			g_MissionParser_State = MPS_GAMEMODE;
		}
		
		case MPS_UNKNOWN: { // Traverse through unknown structures
			g_MissionParser_UnknownCurLayer--;
			if (g_MissionParser_UnknownCurLayer == 0) {
				g_MissionParser_State = g_MissionParser_UnknownPreState;
			}
		}
	}
	
	return SMCParse_Continue;
}

void CopyFile(const char[] src, const char[] target) {
	File fileSrc;
	fileSrc = OpenFile(src, "rb", true, NULL_STRING);
	if (fileSrc != null) {
		File fileTarget;
		fileTarget = OpenFile(target, "wb", true, NULL_STRING);
		if (fileTarget != null) {
			int buffer[256]; // 256Bytes each time
			int numOfElementRead;
			while (!fileSrc.EndOfFile()){
				numOfElementRead = fileSrc.Read(buffer, 256, 1);
				fileTarget.Write(buffer, numOfElementRead, 1);
			}
			FlushFile(fileTarget);
			fileTarget.Close();
		}
		fileSrc.Close();
	}
}

void CacheMissions() {
	DirectoryListing dirList;
	dirList = OpenDirectory("missions", true, NULL_STRING);

	if (dirList == null) {
        LogError("[SM] Plugin is not running! Could not locate mission folder");
        SetFailState("Could not locate mission folder");
	} else {	
		if (!DirExists("missions.cache")) {
			CreateDirectory("missions.cache", 777);
		}
		
		char missionFileName[PLATFORM_MAX_PATH];
		FileType fileType;
		while(dirList.GetNext(missionFileName, PLATFORM_MAX_PATH, fileType)) {
			if (fileType == FileType_File &&
			strcmp("credits.txt", missionFileName, false) != 0
			) {
				char missionSrc[PLATFORM_MAX_PATH];
				char missionCache[PLATFORM_MAX_PATH];
				missionSrc = "missions/";

				Format(missionSrc, PLATFORM_MAX_PATH, "missions/%s", missionFileName);
				Format(missionCache, PLATFORM_MAX_PATH, "missions.cache/%s", missionFileName);
				// PrintToServer("Cached mission file %s\n", missionFileName);
				
				if (!FileExists(missionCache, true, NULL_STRING)) {
					CopyFile(missionSrc, missionCache);
				}
			}
			
		}
		
		delete dirList;
	}
}

void ParseMissions() {
	DirectoryListing dirList;
	dirList = OpenDirectory("missions.cache", true, NULL_STRING);
	
	if (dirList == null) {
		LogError("The \"missions.cache\" folder was not found!\n");
	} else {
		// Create the parser
		SMCParser parser = SMC_CreateParser();
		parser.OnEnterSection = MissionParser_NewSection;
		parser.OnLeaveSection = MissionParser_EndSection;
		parser.OnKeyValue = MissionParser_KeyValue;
		
		g_hIntMap_Index = new ArrayList(1);
		g_hStrMap_FileName = new ArrayList(LEN_MAP_FILENAME);
	
		char missionCache[PLATFORM_MAX_PATH];
		char missionFileName[PLATFORM_MAX_PATH];
		FileType fileType;
		while(dirList.GetNext(missionFileName, PLATFORM_MAX_PATH, fileType)) {
			if (fileType == FileType_File) {
				Format(missionCache, PLATFORM_MAX_PATH, "missions.cache/%s", missionFileName);
				
				// Process the mission file				
				g_MissionParser_State = MPS_ROOT;
				SMCError err = parser.ParseFile(missionCache);
				if (err != SMCError_Okay) {
					LogError("An error occured while parsing %s, code:%d\n", missionCache, err);
				}
			}
		}
		
		delete g_hIntMap_Index;
		delete g_hStrMap_FileName;
		delete dirList;	
	}
}
