#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma semicolon 1
#pragma newdecls required

#define MAX_PLAYERS 65
#define PLUGIN_VERSION "1.1.0"

// Global variables for tracking damage
int g_DamageGiven[MAX_PLAYERS][MAX_PLAYERS];
int g_HitsGiven[MAX_PLAYERS][MAX_PLAYERS];

// ConVars
ConVar g_cvEnabled;

public Plugin myinfo =
{
    name = "Round End Damage Report",
    author = "RATING3PRO",
    description = "Displays damage statistics at the end of each round.",
    version = PLUGIN_VERSION
};

public void OnPluginStart()
{
    // Register ConVars
    g_cvEnabled = CreateConVar("sm_dmgreport_enabled", "1", "Enable damage report plugin");
    
    // Auto generate config file
    AutoExecConfig(true, "plugin.round_damage_report");

    // Hook events
    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_hurt", Event_PlayerHurt);
    HookEvent("round_end", Event_RoundEnd);
}

public void OnClientDisconnect(int client)
{
    ClearClientData(client);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    ClearAllData();
    return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnabled.BoolValue)
    {
        return Plugin_Continue;
    }

    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int damage = event.GetInt("dmg_health");

    // Check validity and ensure we don't track self-damage or world damage for this report
    if (IsValidClient(victim) && IsValidClient(attacker) && victim != attacker)
    {
        g_DamageGiven[attacker][victim] += damage;
        g_HitsGiven[attacker][victim]++;
    }
    
    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnabled.BoolValue)
    {
        return Plugin_Continue;
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            ShowDamageReport(i);
        }
    }
    return Plugin_Continue;
}

void ShowDamageReport(int client)
{
    int clientTeam = GetClientTeam(client);
    
    // Only show for T or CT (Spectators don't need this report usually)
    if (clientTeam != CS_TEAM_T && clientTeam != CS_TEAM_CT)
    {
        return;
    }

    bool headerPrinted = false;

    for (int i = 1; i <= MaxClients; i++)
    {
        // Skip self and invalid clients
        if (i == client || !IsClientInGame(i))
        {
            continue;
        }

        int otherTeam = GetClientTeam(i);
        
        // Only show enemies (Opposite team)
        if (otherTeam == clientTeam || (otherTeam != CS_TEAM_T && otherTeam != CS_TEAM_CT))
        {
            continue;
        }

        int dmgGiven = g_DamageGiven[client][i];
        int hitsGiven = g_HitsGiven[client][i];
        int dmgTaken = g_DamageGiven[i][client];
        int hitsTaken = g_HitsGiven[i][client];

        if (!headerPrinted)
        {
            PrintToChat(client, " \x04[回合伤害统计] \x01----------------------------");
            headerPrinted = true;
        }
        
        char enemyName[MAX_NAME_LENGTH];
        GetClientName(i, enemyName, sizeof(enemyName));

        // Determine Health Status
        char healthStatus[32];
        if (IsPlayerAlive(i))
        {
            // Alive: Show HP in Green
            Format(healthStatus, sizeof(healthStatus), "\x04%d HP", GetClientHealth(i));
        }
        else
        {
            // Dead: Show DEAD in Red
            Format(healthStatus, sizeof(healthStatus), "\x02DEAD");
        }

        // Format: 
        // Name (TeamColor) [Health] :: Hits: X (Y dmg) (Green) :: Taken: A (B dmg) (Red)
        // Using \x08 (Grey) for separators
        
        char buffer[256];
        Format(buffer, sizeof(buffer), " \x03%s \x01[%s\x01] \x08:: \x06攻: %d \x01(\x06%d hp\x01) \x08:: \x02受: %d \x01(\x02%d hp\x01)", 
            enemyName, healthStatus, hitsGiven, dmgGiven, hitsTaken, dmgTaken);
        
        PrintToChat(client, buffer);
    }
    
    if (headerPrinted)
    {
        PrintToChat(client, " \x01-----------------------------------------------");
    }
}

void ClearAllData()
{
    for (int i = 0; i < MAX_PLAYERS; i++)
    {
        for (int j = 0; j < MAX_PLAYERS; j++)
        {
            g_DamageGiven[i][j] = 0;
            g_HitsGiven[i][j] = 0;
        }
    }
}

void ClearClientData(int client)
{
    if (client > 0 && client < MAX_PLAYERS)
    {
        for (int i = 0; i < MAX_PLAYERS; i++)
        {
            g_DamageGiven[client][i] = 0;
            g_HitsGiven[client][i] = 0;
            g_DamageGiven[i][client] = 0; 
            g_HitsGiven[i][client] = 0;
        }
    }
}

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}
