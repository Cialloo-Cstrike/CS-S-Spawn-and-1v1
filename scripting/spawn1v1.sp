//This script has been Licenced by Master(D) under http://creativecommons.org/licenses/by-nc-nd/3.0/
//All Rights of this script is the owner of Master(D).

//Includes:
#include <sourcemod>
#include <sdktools>
#include <events>
#include <cstrike>
//初始化堆栈内存大小
#pragma dynamic 131072

//Misc:
static  MaxSpawns = 64;

//数据
int geter;
int PlayerNum;
int Survial;
int Tsur;
int CTsur;
int Attack;
int Died;
int KillEarn;
int Dieddown;
char Buffer[64];
int PMVP;
int CTPLAYER[12];
int TPLAYER[12];

int COUNT_T;
int COUNT_CT;

//Spawns:
static Float:SpawnPoints[MAXPLAYERS + 1][2][3];
static bool:ValidSpawn[MAXPLAYERS + 1][2];

//Definitions:
#define MAINVERSION		"1.00.24"

//Database Sql:
static Handle:hDataBase = INVALID_HANDLE;

//Plugin Info:
public Plugin:myinfo =
{
	name = "SQL Spawn System",
	author = "Master(D)(Fix by Cialloo & Sparkle)",
	description = "respawns players with MySQL Saving",
	version = MAINVERSION,
	url = ""
};

//Initation:
public OnPluginStart()
{
	//Print Server If Plugin Start:
	PrintToServer("SQL Spawn System Successfully Loaded (v%s)!", MAINVERSION);

	//Commands:
	RegAdminCmd("sm_createspawn", CommandCreateSpawn, ADMFLAG_ROOT, "<id> <Type> - Type = 0:Team 2, Type = 1:Team 3 Creates a spawn point");

	RegAdminCmd("sm_removespawn", CommandRemoveSpawn, ADMFLAG_ROOT, "<id> <Type> - Type = 0:Team 2, Type = 1:Team 3 Removes a spawn point");

	RegAdminCmd("sm_mapspawnlist", CommandMapSpawnList, ADMFLAG_SLAY, " <Map String> Lists all the Spawns in the database");

	RegAdminCmd("sm_spawnlist", CommandListSpawns, ADMFLAG_SLAY, " <No Args> Lists all the Spawns in the database");

	RegAdminCmd("sm_spawnlistall", CommandListSpawnsAll, ADMFLAG_SLAY, " <No Args> Lists all the Spawns in the database");

	//Setup Sql Connection:
	initSQL();

	//Reset Spawns:
	ResetSpawns();

	//Initulize:
	MaxSpawns = MaxClients;

	//初始化数组值
    for(int i = 0; i < 12; i++)
	{
       TPLAYER[i] = i;
	   CTPLAYER[i] = i;
	}
	//Timer:
	CreateTimer(0.1, CreateSQLdbSpawnPoints);

	//Event:
    HookEvent("round_start", round_start);

    HookEvent("player_death", round_tie);
}


//Initation:
public OnMapStart()
{

	//SQL Load:
	CreateTimer(0.4, LoadSpawnPoints);
}

//Initation:
public OnEndStart()
{

	//Reset Spawns:
	ResetSpawns();
}

public ResetSpawns()
{

	//Loop:
	for(new Z = 0; Z < MaxSpawns + 1; Z++)
	{

		//Initulize:
		ValidSpawn[Z][0] = false;

		ValidSpawn[Z][1] = false;

		//Loop:
		for(new B = 0; B < 2; B++) for(new i = 0; i < 3; i++)
		{

			//Initulize:
			SpawnPoints[Z][B][i] = 69.0;
		}
	}
}

//开始时设置标识

//回合结束减去这人获得的MVP

//玩家重生事件，判断是否为人机 并且传送
public Action:round_start(Event event, const char[] name, bool dontBroadcast) 
{

	COUNT_T = GetTeamClientCount(2);
	COUNT_CT =  GetTeamClientCount(3);

    for (int i = 1; i <= 25; i++)
    {
		if(IsClientConnected(i) && !IsFakeClient(i) && IsClientInGame(i))
		{
	 		InitSpawnPos(i, COUNT_T, COUNT_CT);
	 		PrintToConsole(i,"传送成功");
			if(GetClientTeam(i) == 2)
			{
				COUNT_T--;
			}
			else
			{
				COUNT_CT--;
			}
        }
	}
}

//回合结束的事件，双方平局
public Action:round_tie(Event event, const char[] name, bool dontBroadcast)
{
	PlayerNum = (GetTeamClientCount(2) + GetTeamClientCount(3))
    CTsur = GetTeamEntity(3);
	Tsur = GetTeamEntity(2);
    Died = GetClientOfUserId(GetEventInt(event, "userid"));
    Attack = GetClientOfUserId(GetEventInt(event, "attacker"));
	Survial = (GetTeamEntity(2) + GetTeamEntity(3));

    if(Died == 0 || Attack == 0)
	{
		return Plugin_Continue;
	}

	if(Died == Attack)
	{
		PrintToChat(Died, "你自杀了");
	}
    if(Died != Attack)
	{
		ForcePlayerSuicide(Attack);
		PrintToChat(Attack, "你赢了，但是你还是得死，去看别人吧");
	}

    //结束回合
	if((PlayerNum % 2) == 0 && PlayerNum > 0)
	{
	    if((2 * Survial) == PlayerNum)
		CS_TerminateRound(3.0, CSRoundEnd_Draw, false)
	}
	else if((PlayerNum % 2) == 1 && PlayerNum > 0)
	{
        if((4 * (CTsur + 1)) == PlayerNum || (4 * (Tsur + 1)) == PlayerNum)
        CS_TerminateRound(3.0, CSRoundEnd_Draw, false)
	}
}
//重生函数
public InitSpawnPos(Client, COUNT_T, COUNT_CT)
{
	//Get Job Type:
	new Type;

	//检查队伍
	if(GetClientTeam(Client) == 2)
	{

		//宣告:
		Type = 1;
		OneByOneSpawn(Client, Type, COUNT_T);
		

	}
	else
	{

		//宣告:
		Type = 0;
		OneByOneSpawn(Client, Type, COUNT_CT);
		COUNT_T--;
	}


}

//传送:
public Action:OneByOneSpawn(Client, SpawnType, COUNT)
{   
	TeleportEntity(Client, SpawnPoints[COUNT][SpawnType], NULL_VECTOR, NULL_VECTOR);
	//设置标签
	Format(Buffer, 64, "| %d 竞技场|", COUNT);
    CS_SetClientClanTag(Client, Buffer);
}

/*
————————————————————这下面所有代码请不要修改——————————————————————
*/
//Setup Sql Connection:
initSQL()
{
	SQL_TConnect(DBConnect, "Spawns");

}

public DBConnect(Handle:owner, Handle:hndl, const String:error[], any:data)
{

	//Is Valid Handle:
	if(hndl == INVALID_HANDLE)
	{
#if defined DEBUG
		//Log Message:
		LogError("|DataBase| : %s", error);
#endif
		//Return:
		return false;
	}

	//Override:
	else
	{

		//Copy Handle:
		hDataBase = hndl;

		//Declare:
		decl String:SQLDriver[32];

		new bool:iSqlite = true;

		//Read SQL Driver
		SQL_ReadDriver(hndl, SQLDriver, sizeof(SQLDriver));

		//MYSQL
		if(strcmp(SQLDriver, "mysql", false)==0)
		{

			//Thread Query:
			SQL_TQuery(hDataBase, SQLErrorCheckCallback, "SET NAMES \"UTF8\"");

			//Initulize:
			iSqlite = false;
		}

		//Is Sqlite:
		if(iSqlite)
		{

			//Print:
			PrintToServer("|DataBase| Connected to SQLite Database. Version %s", MAINVERSION);
		}

		//Override:
		else
		{

			//Print:
			PrintToServer("|DataBase| Connected to MySQL Database I.e External Config. Version %s.", MAINVERSION);
		}
	}

	//Return:
	return true;
}

public SQLErrorCheckCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{

	//Is Error:
	if(hndl == INVALID_HANDLE)
	{
#if defined DEBUG
		//Log Message:
		LogError("[Spawns] SQLErrorCheckCallback: Query failed! %s", error);
#endif
	}
}

//Create Database:
public Handle:GetGlobalSQL()
{

	//Return:
	return hDataBase;
}

//Create Database:
public Action:CreateSQLdbSpawnPoints(Handle:Timer)
{

	//Declare:
	new len = 0;
	decl String:query[512];

	//Sql String:
	len += Format(query[len], sizeof(query)-len, "CREATE TABLE IF NOT EXISTS `SpawnPoints`");

	len += Format(query[len], sizeof(query)-len, " (`Map` varchar(32) NOT NULL, `Type` int(12) NULL,");

	len += Format(query[len], sizeof(query)-len, " `SpawnId` int(12) NULL, `Position` varchar(32) NOT NULL);");

	//Thread query:
	SQL_TQuery(GetGlobalSQL(), SQLErrorCheckCallback, query);
}

//Create Database:
public Action:LoadSpawnPoints(Handle:Timer)
{

	//Declare:
	decl String:query[512];

	//Format:
	Format(query, sizeof(query), "SELECT * FROM SpawnPoints WHERE Map = '%s';", ServerMap());

	//Not Created Tables:
	SQL_TQuery(GetGlobalSQL(), T_DBLoadSpawnPoints, query);
}

public T_DBLoadSpawnPoints(Handle:owner, Handle:hndl, const String:error[], any:data)
{

	//Invalid Query:
	if (hndl == INVALID_HANDLE)
	{

		//Logging:
		LogError("[Spawns] T_DBLoadSpawnPoints: Query failed! %s", error);
	}

	//Override:
	else 
	{

		//Not Player:
		if(!SQL_GetRowCount(hndl))
		{

			//Print:
			PrintToServer("[SM] - No Spawns Found in DB!");

			//Return:
			return;
		}

		//Declare:
		new Type, SpawnId; decl String:Buffer[64];

		//Override
		while(SQL_FetchRow(hndl))
		{

			//Database Field Loading String:
			SQL_FetchString(hndl, 3, Buffer, 64);

			//Database Field Loading Intiger:
			SpawnId = SQL_FetchInt(hndl, 2);

			//Database Field Loading Intiger:
			Type = SQL_FetchInt(hndl, 1);

			//Declare:
			decl String:Dump[3][64]; new Float:Position[3];

			//Database Field Loading String:
			SQL_FetchString(hndl, 3, Buffer, 64);

			//Convert:
			ExplodeString(Buffer, "^", Dump, 3, 64);

			//Loop:
			for(new X = 0; X <= 2; X++)
			{

				//Initulize:
				Position[X] = StringToFloat(Dump[X]);
			}

			//Initulize:
			SpawnPoints[SpawnId][Type] = Position;

			ValidSpawn[SpawnId][Type] = true;
		}

		//Print:
		PrintToServer("[SM] - Spawns Loaded!");
	}
}

//Create NPC:
public Action:CommandCreateSpawn(Client, Args)
{

	//Is Colsole:
	if(Client == 0)
	{

		//Print:
		PrintToServer("[SM] - This command can only be used ingame.");

		//Return:
		return Plugin_Handled;
	}

	//No Valid Charictors:
	if(Args < 2)
	{

		//Print:
		PrintToChat(Client, "[SM] - Usage: sm_createspawn <id> <type>");

		//Return:
		return Plugin_Handled;
	}

	//Declare:
	decl String:SpawnId[32], String:sType[32];

	//Initialize:
	GetCmdArg(1, SpawnId, sizeof(SpawnId));

	GetCmdArg(2, sType, sizeof(sType));

	//Declare:
	new Spawn = StringToInt(SpawnId);

	//No Valid Charictors:
	if(Spawn < 1 && Spawn > MaxSpawns)
	{

		//Print:
		PrintToChat(Client, "[SM] - Usage: sm_createspawn <1-%i> <type>", MaxSpawns);

		//Return:
		return Plugin_Handled;
	}

	//Declare:
	new Type = StringToInt(sType);

	//No Valid Charictors:
	if(Type != 1 && Type != 0)
	{

		//Print:
		PrintToChat(Client, "[SM] - Usage: sm_createspawn <1-%i> <1 = Team 2, 0 = Team 3>", MaxSpawns);

		//Return:
		return Plugin_Handled;
	}

	//Declare:
	new Float:ClientOrigin[3]; decl String:query[512], String:Position[32];

	//Initialize:
	GetClientAbsOrigin(Client, ClientOrigin);

	//Sql String:
	Format(Position, sizeof(Position), "%f^%f^%f", ClientOrigin[0], ClientOrigin[1], ClientOrigin[2]);

	//Spawn Already Created:
	if(ValidSpawn[Spawn][Type] == true)
	{

		//Format:
		Format(query, sizeof(query), "UPDATE SpawnPoints SET Position = '%s' WHERE Map = '%s' AND Type = %i AND SpawnId = %i;", Position, ServerMap(), Type, Spawn);
	}

	//Override:
	else
	{

		//Format:
		Format(query, sizeof(query), "INSERT INTO SpawnPoints (`Map`,`Type`,`SpawnId`,`Position`) VALUES ('%s',%i,%i,'%s');", ServerMap(), Type, Spawn, Position);
	}

	//Initulize:
	SpawnPoints[Spawn][Type] = ClientOrigin;

	ValidSpawn[Spawn][Type] = true;

	//Not Created Tables:
	SQL_TQuery(GetGlobalSQL(), SQLErrorCheckCallback, query);

	//Print:
	PrintToChat(Client, "[SM] - Created spawn #%s <%f, %f, %f>", SpawnId, ClientOrigin[0], ClientOrigin[1], ClientOrigin[2]);

	//Return:
	return Plugin_Handled;
}

//Remove Spawn:
public Action:CommandRemoveSpawn(Client, Args)
{

	//No Valid Charictors:
	if(Args < 2)
	{

		//Print:
		PrintToChat(Client, "[SM] - Usage: sm_removespawn <id> <Type>");

		//Return:
		return Plugin_Handled;
	}

	//Declare:
	decl String:SpawnId[32], String:sType[32];

	//Initialize:
	GetCmdArg(1, SpawnId, sizeof(SpawnId));

	GetCmdArg(2, sType, sizeof(sType));

	//Declare:
	new Spawn = StringToInt(SpawnId);

	//No Valid Charictors:
	if(Spawn < 1 && Spawn > MaxSpawns)
	{

		//Print:
		PrintToChat(Client, "[SM] - Usage: sm_removespawn <1-%i> <type>", MaxSpawns);

		//Return:
		return Plugin_Handled;
	}

	//Declare:
	new Type = StringToInt(sType);

	//No Valid Charictors:
	if(Type != 1 && Type != 0)
	{

		//Print:
		PrintToChat(Client, "[SM] - Usage: sm_removespawn <1-%i> <1-%i> <1 = Team 2, 0 = Team 3>", MaxSpawns);

		//Return:
		return Plugin_Handled;
	}

	//No Spawn:
	if(ValidSpawn[Spawn][Type] == true)
	{

		//Print:
		PrintToChat(Client, "[SM] - There is no spawnpoint found in the db. (ID #%s TYPE #%s)", SpawnId, Type);

		//Return:
		return Plugin_Handled;
	}

	//Loop:
	for(new i = 0; i < 3; i++)
	{

		//Initulize:
		SpawnPoints[Spawn][Type][i] = 69.0;

		ValidSpawn[Spawn][Type] = false;
	}

	//Declare:
	decl String:query[512];

	//Sql String:
	Format(query, sizeof(query), "DELETE FROM SpawnPoints WHERE SpawnId = %i AND Type = %i AND Map = '%s';", Spawn, Type, ServerMap());

	//Not Created Tables:
	SQL_TQuery(GetGlobalSQL(), SQLErrorCheckCallback, query);

	//Print:
	PrintToChat(Client, "[SM] - Removed Spawn (ID #%s TYPE #%s)", SpawnId, Type);

	//Return:
	return Plugin_Handled;
}

//List Spawns:
public Action:CommandMapSpawnList(Client, Args)
{

	//No Valid Charictors:
	if(Args < 2)
	{

		//Print:
		PrintToChat(Client, "[SM] - Usage: sm_removespawn <id> <Type>");

		//Return:
		return Plugin_Handled;
	}

	//Declare:
	decl String:Map[64];

	//Initialize:
	GetCmdArg(1, Map, sizeof(Map));

	//Declare:
	new conuserid = 0;

	//Print:
	if(Client > 0)
	{

		//Print:
		PrintToChat(Client, "[SM] - press essape for more infomation");

		//Initulize:
		conuserid = GetClientUserId(Client);

		//Print:
		PrintToConsole(Client, "[SM] - Team 3 Spawns:");
	}

	//Override:
	else
	{

		//Print:
		PrintToServer("[SM] - Team 3 Spawns:");
	}

	//Declare:
	decl String:query[512];

	//Loop:
	for(new X = 0; X <= MaxSpawns + 1; X++)
	{

		//Format:
		Format(query, sizeof(query), "SELECT * FROM SpawnPoints WHERE Map = '%s' AND SpawnId = %i;", Map, X);

		//Not Created Tables:
		SQL_TQuery(GetGlobalSQL(), T_DBPrintSpawnList, query, conuserid);
	}

	//Return:
	return Plugin_Handled;
}

//List Spawns:
public Action:CommandListSpawns(Client, Args)
{

	//Declare:
	new conuserid = 0;

	//Print:
	if(Client > 0)
	{

		//Print:
		PrintToChat(Client, "[SM] - press essape for more infomation");

		//Initulize:
		conuserid = GetClientUserId(Client);

		//Print:
		PrintToConsole(Client, "[SM] - Team 3 Spawns:");
	}

	//Override:
	else
	{

		//Print:
		PrintToServer("[SM] - Team 3 Spawns:");
	}

	//Declare:
	decl String:query[512];

	//Loop:
	for(new X = 0; X <= MaxSpawns + 1; X++)
	{

		//Format:
		Format(query, sizeof(query), "SELECT * FROM SpawnPoints WHERE Type = 0 AND Map = '%s' AND SpawnId = %i;", ServerMap(), X);

		//Not Created Tables:
		SQL_TQuery(GetGlobalSQL(), T_DBPrintSpawnList, query, conuserid);
	}

	//Timer:
	CreateTimer(1.5, List, Client);

	//Return:
	return Plugin_Handled;
}

//Load Spawn:
public Action:List(Handle:Timer, any:Client)
{

	//Declare:
	new conuserid = 0;

	//Print:
	if(Client > 0)
	{

		//Initulize:
		conuserid = GetClientUserId(Client);

		//Print:
		PrintToConsole(Client, "[SM] - Team 2 Spawns:");
	}

	//Override:
	else
	{

		//Print:
		PrintToServer("[SM] - Team 2 Spawns:");
	}

	//Declare:
	decl String:query[512];

	//Loop:
	for(new X = 0; X < MaxSpawns + 1; X++)
	{

		//Format:
		Format(query, sizeof(query), "SELECT * FROM SpawnPoints WHERE Type = 1 AND Map = '%s' AND SpawnId = %i;", ServerMap(), X);

		//Not Created Tables:
		SQL_TQuery(GetGlobalSQL(), T_DBPrintSpawnList, query, conuserid);
	}
}

//List Spawns:
public Action:CommandListSpawnsAll(Client, Args)
{

	//Declare:
	new conuserid = 0;

	//Print:
	if(Client > 0)
	{

		//Print:
		PrintToChat(Client, "[SM] - press essape for more infomation");

		//Initulize:
		conuserid = GetClientUserId(Client);

		//Print:
		PrintToConsole(Client, "[SM] - Team 3 Spawns:");
	}

	//Override:
	else
	{

		//Print:
		PrintToServer("[SM] - Team 3 Spawns:");
	}

	//Declare:
	decl String:query[512];

	//Loop:
	for(new X = 0; X <= MaxSpawns + 1; X++)
	{

		//Format:
		Format(query, sizeof(query), "SELECT * FROM SpawnPoints WHERE Type = 0 AND SpawnId = %i;", X);

		//Not Created Tables:
		SQL_TQuery(GetGlobalSQL(), T_DBPrintSpawnList, query, conuserid);
	}

	//Timer:
	CreateTimer(2.5, ListAll, Client);
		
	//Return:
	return Plugin_Handled;
}

//Load Spawn:
public Action:ListAll(Handle:Timer, any:Client)
{

	//Declare:
	new conuserid = 0;

	//Print:
	if(Client > 0)
	{

		//Initulize:
		conuserid = GetClientUserId(Client);

		//Print:
		PrintToConsole(Client, "[SM] - Team 2 Spawns:");
	}

	//Override:
	else
	{

		//Print:
		PrintToServer("[SM] - Team 2 Spawns:");
	}

	//Declare:
	decl String:query[512];

	//Loop:
	for(new X = 0; X < MaxSpawns + 1; X++)
	{

		//Format:
		Format(query, sizeof(query), "SELECT * FROM SpawnPoints WHERE Type = 1 AND SpawnId = %i", X);

		//Not Created Tables:
		SQL_TQuery(GetGlobalSQL(), T_DBPrintSpawnList, query, conuserid);
	}
}

public T_DBPrintSpawnList(Handle:owner, Handle:hndl, const String:error[], any:data)
{

	//Declare:
	new Client;

	//Is Client:
	if(data != 0 && (Client = GetClientOfUserId(data)) == 0)
	{

		//Return:
		return;
	}

	//Invalid Query:
	if (hndl == INVALID_HANDLE)
	{

		//Logging:
		LogError("[Spawns] T_DBPrintSpawnList: Query failed! %s", error);
	}

	//Override:
	else 
	{

		//Not Player:
		if(!SQL_GetRowCount(hndl))
		{

			//Print:
			if(Client > 0)
			{

				//Print:
				PrintToChat(Client, "[SM] - Invalid Map");
			}

			//Override:
			else
			{

				//Print:
				PrintToServer("Invalid Map");
			}

			//Return:
			return;
		}

		//Declare:
		new SpawnId, String:Buffer[64], String:Map[64];

		//Database Row Loading INTEGER:
		while(SQL_FetchRow(hndl))
		{

			//Database Field Loading String:
			SQL_FetchString(hndl, 0, Map, 64);

			//Database Field Loading Intiger:
			SpawnId = SQL_FetchInt(hndl, 2);

			//Database Field Loading String:
			SQL_FetchString(hndl, 3, Buffer, 64);

			//Print:
			if(Client > 0)
			{

				//Print:
				PrintToConsole(Client, "%s: %i <%s>", Map, SpawnId, Buffer);
			}

			//Override:
			else
			{

				//Print:
				PrintToServer("%s %i <%s>", Map, SpawnId, Buffer);
			}
		}
	}
}

String:ServerMap()
{

	//Declare:
	decl String:Map[64];

	//Initialize:
	GetCurrentMap(Map, sizeof(Map));

	//Return
	return Map;
}