local dummyTarget = Entities.CreateByClassname("info_target");
dummyTarget.PrecacheSoundScript("ASW_Sentry.Fire");
dummyTarget.PrecacheModel("models/swarm/sentrygun/remoteturret.mdl");
dummyTarget.Destroy();

MarineManager <- [];

class cMarine
{
	constructor(hMarine = null)
	{
		if (hMarine != null)
		{
			m_hMarine = hMarine;
			m_strName = hMarine.GetMarineName();
		}
	}
	
	m_hMarine = null;
	m_strName = null;
	m_hProp = null;
}

function OnGameplayStart()
{
	Startup();
	local hMarine = null;
	while ((hMarine = Entities.FindByClassname(hMarine, "asw_marine")) != null)
	{
		local hWeapon_Check = null;
		local TableInv_Check = hMarine.GetInvTable();
		if ("slot0" in TableInv_Check && TableInv_Check["slot0"] != null)
		{
			hWeapon_Check = TableInv_Check["slot0"];
			if (hWeapon_Check == null || hWeapon_Check.GetClassname() != "asw_weapon_railgun")
				continue;
		}
		hMarine.GiveWeapon("asw_weapon_autogun", 0);
		local hWeapon = null;
		local TableInv = hMarine.GetInvTable();
		if ("slot0" in TableInv && TableInv["slot0"] != null)
		{
			hWeapon = TableInv["slot0"];
			if (hWeapon != null)
			{
				local cTarget = MarineManager[GetMarineIndex(hMarine)];
				hWeapon.SetName("gs_" + cTarget.m_strName);
				hWeapon.SetClips(3);
				hWeapon.__KeyValueFromInt("renderamt", 0);
				hWeapon.__KeyValueFromInt("rendermode", 1);
				hWeapon.__KeyValueFromString("disableshadows", "1");
				hWeapon.__KeyValueFromString("disablereceiveshadows", "1");
				
				cTarget.m_hProp = Entities.CreateByClassname("prop_dynamic");
				cTarget.m_hProp.__KeyValueFromString("model", "models/swarm/sentrygun/remoteturret.mdl");
				cTarget.m_hProp.__KeyValueFromString("solid", "0");
				cTarget.m_hProp.__KeyValueFromInt("rendermode", 1);
				cTarget.m_hProp.SetOrigin(hMarine.GetOrigin());
				cTarget.m_hProp.SetOwner(hWeapon);
				cTarget.m_hProp.Spawn();
				
				cTarget.m_hProp.ValidateScriptScope();
				cTarget.m_hProp.GetScriptScope().MarineManager<-MarineManager;
				cTarget.m_hProp.GetScriptScope().GetMarineIndex<-GetMarineIndex;
				cTarget.m_hProp.GetScriptScope().RotateTurret<-RotateTurret;
				cTarget.m_hProp.GetScriptScope().SetTurretThinkFunc<-SetTurretThinkFunc;
				AddThinkToEnt(cTarget.m_hProp, "SetTurretThinkFunc");
			}
		}
	}
}

function OnTakeDamage_Alive_Any(hVictim, inflictor, hAttacker, hWeapon, flDamage, damageType, ammoName) 
{
	if (hWeapon != null && hAttacker && hAttacker.GetClassname() == "asw_marine")
	{
		if (hWeapon.GetKeyValue("rendermode").tointeger())
		{
			if (hAttacker.GetMarineName() == "Wolfe" || hAttacker.GetMarineName() == "Wildcat")
				flDamage -= 5;
			flDamage *= 3.7;
		}
	}
	return flDamage;
}

function OnGameEvent_weapon_fire(params)
{
	local hWeapon = EntIndexToHScript(params["weapon"]);
	if (hWeapon != null && hWeapon.GetKeyValue("rendermode").tointeger())
		hWeapon.EmitSound("ASW_Sentry.Fire");
}

function OnGameEvent_entity_killed(params)
{
	local hVictim = null;
	if ("entindex_killed" in params)
		hVictim = EntIndexToHScript(params["entindex_killed"]);
	if (hVictim && hVictim.GetClassname() == "asw_marine")
		CheckTurret(hVictim);
}


function OnGameEvent_player_dropped_weapon(params)
{
	if (!("userid" in params))
		return;
	local hMarine = NetProps.GetPropEntity(GetPlayerFromUserID(params["userid"]), "m_hMarine")
	if (hMarine)
		CheckTurret(hMarine);
}

function SetTurretThinkFunc()
{
	if (!self || !self.IsValid())
		self.Destroy();
	
	local hMarine = null;
	while ((hMarine = Entities.FindByClassname(hMarine, "asw_marine")) != null)
	{
		local cTarget = MarineManager[GetMarineIndex(hMarine)];
		local hWeapon = NetProps.GetPropEntity(hMarine, "m_hActiveWeapon");
		
		if (hWeapon != null && hWeapon.GetKeyValue("rendermode").tointeger() && cTarget.m_hProp)
		{
			if (cTarget.m_hProp.GetKeyValue("rendermode").tointeger())
			{
				DoEntFire("!self", "SetParent", "!activator", 0, hMarine, cTarget.m_hProp);
				DoEntFire("!self", "SetParentAttachment", "RHand", 0, null, cTarget.m_hProp);
				RotateTurret(cTarget.m_hProp);
				cTarget.m_hProp.GetOwner().__KeyValueFromInt("renderamt", 0);
				cTarget.m_hProp.__KeyValueFromInt("renderamt", 255);
				cTarget.m_hProp.__KeyValueFromInt("rendermode", 0);
			}
		}
		else if (cTarget.m_hProp && !cTarget.m_hProp.GetKeyValue("rendermode").tointeger())
		{
			cTarget.m_hProp.GetOwner().__KeyValueFromInt("renderamt", 255);
			cTarget.m_hProp.__KeyValueFromInt("renderamt", 0);
			cTarget.m_hProp.__KeyValueFromInt("rendermode", 1);
		}
	}
	return 0.05;
}

function Startup()
{
	local hMarine = null;
	while ((hMarine = Entities.FindByClassname(hMarine, "asw_marine")) != null)
		MarineManager.push(cMarine(hMarine));
}

function CheckTurret(hMarine)
{
	local cTarget = MarineManager[GetMarineIndex(hMarine)];
	if (cTarget.m_hProp)
	{
		cTarget.m_hProp.Destroy();
		cTarget.m_hProp = null;
	}
	else
		return;
		
	local hTurret = null;
	while ((hTurret = Entities.FindByClassname(hTurret, "asw_weapon_autogun")) != null)
	{
		if (hTurret.GetKeyValue("rendermode").tointeger() && hTurret.GetName() == "gs_" + cTarget.m_strName)
		{
			local vecTurretPos = hTurret.GetOrigin();
			local flTurretAngleY = hTurret.GetAngles().y + 90;
			hTurret.Destroy();
			local hRealTurret = Entities.CreateByClassname("asw_sentry_top_machinegun");
			hRealTurret.SetOrigin(vecTurretPos + Vector(0, 0, -50));
			hRealTurret.SetAnglesVector(Vector(0, flTurretAngleY, 0));
			hRealTurret.Spawn();
		}
	}
}

function RotateTurret(hTurret)
{
	local hTimer = Entities.CreateByClassname("logic_timer");
	hTimer.__KeyValueFromFloat("RefireTime", 0.1);
	DoEntFire("!self", "Disable", "", 0, null, hTimer);
	hTimer.ValidateScriptScope();
	
	hTimer.GetScriptScope().hTurret <- hTurret;
	hTimer.GetScriptScope().TimerFunc <- function()
	{
		if (hTurret != null && hTurret.IsValid())
		{
			hTurret.SetLocalOrigin(Vector(3, 0, 6));
			hTurret.SetLocalAngles(10, 0, -180);
		}
		
		self.DisconnectOutput("OnTimer", "TimerFunc");
		self.Destroy();	
	}
	hTimer.ConnectOutput("OnTimer", "TimerFunc");
	DoEntFire("!self", "Enable", "", 0, null, hTimer);
}

function GetMarineIndex(hMarine)
{
	local strName = hMarine.GetMarineName();
	foreach (index, val in MarineManager)
	{
		if (strName == val.m_strName)
			return index;
	}
	return 0;
}
