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

function OnMissionStart()
{
	Convars.SetValue("asw_marine_death_cam_slowdown", 0);
	Convars.SetValue("rd_override_allow_rotate_camera", 1);
	Convars.SetValue("achievement_disable", 1);
	Convars.SetValue("rd_leaderboard_enabled", 0);
	Convars.SetValue("rd_extinguisher_dmg_amount", 1);
	
	local dummyTarget = Entities.CreateByClassname("info_target");
	dummyTarget.PrecacheSoundScript("ASW_Sentry.Fire");
	dummyTarget.PrecacheSoundScript("ASW_Sentry.CannonFire");
	dummyTarget.PrecacheSoundScript("ASWGrenade.Explode");
	dummyTarget.PrecacheModel("models/sentry_gun/flame_top.mdl");
	dummyTarget.PrecacheModel("models/sentry_gun/freeze_top.mdl");
	dummyTarget.PrecacheModel("models/sentry_gun/grenade_top.mdl");
	dummyTarget.PrecacheModel("models/swarm/sentrygun/remoteturret.mdl");
	dummyTarget.Destroy();
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
			if (hWeapon_Check != null)
				GiveTurretWeapon(hMarine, hWeapon_Check.GetClassname())
		}
	}
}

function OnTakeDamage_Alive_Any(hVictim, hInflictor, hAttacker, hWeapon, flDamage, damageType, ammoName) 
{
	if (hInflictor != null && hInflictor.GetClassname() == "asw_extinguisher_projectile")
		flDamage = 0;
	if (hAttacker && hAttacker.GetClassname() == "asw_marine")
	{
		if (hWeapon != null)
		{
			if (CheckWeaponName(hWeapon, "gs_tvan"))
			{
				if (hAttacker.GetMarineName() == "Wolfe" || hAttacker.GetMarineName() == "Wildcat")
					flDamage -= 5;
				flDamage *= 3.7;
			}
		}
		else if (hInflictor != null && hInflictor.GetClassname() == "asw_extinguisher_projectile")
		{
			local hIceWeapon = NetProps.GetPropEntity(hAttacker, "m_hActiveWeapon");
			if (hIceWeapon != null && hIceWeapon.GetName().len() > 6)
			{
				switch (hIceWeapon.GetName().slice(0, 7))
				{
					case "gs_tice":
						if (hVictim && hVictim.IsAlien())
							hVictim.Freeze(0.4);
						flDamage = 1;
						break;
				}
			}
		}
	}
	return flDamage;
}
	
function OnGameEvent_weapon_reload_finish(params)
{
	local hMarine = EntIndexToHScript(params["marine"]);
	local hWeapon = NetProps.GetPropEntity(hMarine, "m_hActiveWeapon");
	if (hWeapon.GetName().len() > 6)
	{
		switch (hWeapon.GetName().slice(0, 7))
		{
			case "gs_tflm":
				hWeapon.SetClip1(150);
				break;
			case "gs_tice":
				hWeapon.SetClip1(250);
				break;
			case "gs_tcan":
				hWeapon.SetClip1(15);
				break;
		}
	}
}

function OnGameEvent_weapon_fire(params)
{
	local hWeapon = EntIndexToHScript(params["weapon"]);
	if (hWeapon.GetName().len() > 6)
	{
		switch (hWeapon.GetName().slice(0, 7))
		{
			case "gs_tvan":
				hWeapon.EmitSound("ASW_Sentry.Fire");
				break;
			case "gs_tice":
				local hIceFX = Entities.CreateByClassname("info_particle_system");
				hIceFX.__KeyValueFromString("effect_name", "asw_freezer_spray");
				hIceFX.__KeyValueFromString("start_active", "1");
				DoEntFire("!self", "SetParent", "!activator", 0, hWeapon, hIceFX);
				DoEntFire("!self", "SetParentAttachment", "muzzleo", 0, null, hIceFX);
				DoEntFire("!self", "Kill", "", 0.1, null, hIceFX);
				hIceFX.Spawn();
				hIceFX.Activate();
				break;
			case "gs_tcan":
				hWeapon.EmitSound("ASW_Sentry.CannonFire");
				local hMarine = EntIndexToHScript(params["marine"]);
				
				local hMuzzlePoint = Entities.CreateByClassname("info_particle_system");
				DoEntFire("!self", "SetParent", "!activator", 0, hWeapon, hMuzzlePoint);
				DoEntFire("!self", "SetParentAttachment", "eject1", 0, null, hMuzzlePoint);
				
				local hGrenade = Entities.CreateByClassname("asw_rifle_grenade");
				hGrenade.SetOwner(hMarine);
				hGrenade.Spawn();
				hGrenade.Activate();	

				local hGrenadeFX = Entities.CreateByClassname("info_particle_system");
				hGrenadeFX.__KeyValueFromString("effect_name", "rifle_grenade_fx");
				hGrenadeFX.__KeyValueFromString("start_active", "1");
				DoEntFire("!self", "SetParent", "!activator", 0, hGrenade, hGrenadeFX);
				DoEntFire("!self", "SetParentAttachment", "fuse", 0, null, hGrenadeFX);
				hGrenadeFX.Spawn();
				hGrenadeFX.Activate();				
				
				hGrenade.ValidateScriptScope()
				local grenadeScope = hGrenade.GetScriptScope();
				grenadeScope.hMarine <- hMarine;
				grenadeScope.hMuzzlePoint <- hMuzzlePoint;
				grenadeScope.GrenadeMoveForward <- GrenadeMoveForward;
				grenadeScope.Fire <- function()
				{
					self.SetOrigin(hMuzzlePoint.GetOrigin());
					self.SetAnglesVector(hMarine.GetAngles());
					self.SetVelocity(hMarine.GetForwardVector() * 850 + Vector(0, 0, 3));
					
					iCount <- 0;
					AddThinkToEnt(self, "GrenadeMoveForward");
					
					DoEntFire("!self", "Kill", "", 0, null, hMuzzlePoint);
					self.DisconnectOutput("OnUser1", "Fire");
				}
				hGrenade.ConnectOutput("OnUser1", "Fire");
				EntFireByHandle(hGrenade, "Start", "", 0, hGrenade, hGrenade);
				EntFireByHandle(hGrenade, "FireUser1", "", 0, hGrenade, hGrenade);
				DoEntFire("!self", "Kill", "", 1.0, null, hGrenadeFX);
				break;
		}
	}
}

function OnGameEvent_entity_killed(params)
{
	local hVictim = EntIndexToHScript(params["entindex_killed"]);
	if (!hVictim)
		return;
	
	if (hVictim.GetClassname() == "asw_marine")
		CheckTurret(hVictim);
	else if (hVictim.GetClassname() == "asw_grenade_cluster" && hVictim.GetOwner() != null)
	{
		local hMarine = hVictim.GetOwner();
		if (hMarine.GetClassname() == "asw_marine")
		{
			local hWeapon = NetProps.GetPropEntity(hMarine, "m_hActiveWeapon");
			if (hWeapon && hWeapon.GetName().slice(0, 7) == "gs_tcan")
				hVictim.Destroy();
		}
	}
}

function OnGameEvent_item_pickup(params)
{
	local hMarine = NetProps.GetPropEntity(GetPlayerFromUserID(params["userid"]), "m_hMarine")
	if (hMarine)
	{
		local TableInv = hMarine.GetInvTable();
		if (!("slot0" in TableInv) || TableInv["slot0"] == null)
			CheckTurret(hMarine);
	}
}

function OnGameEvent_player_dropped_weapon(params)
{
	local hMarine = NetProps.GetPropEntity(GetPlayerFromUserID(params["userid"]), "m_hMarine")
	if (hMarine)
	{
		local TableInv = hMarine.GetInvTable();
		if (!("slot0" in TableInv) || TableInv["slot0"] == null)
			CheckTurret(hMarine);
	}
}

function Startup()
{
	local hMarine = null;
	while ((hMarine = Entities.FindByClassname(hMarine, "asw_marine")) != null)
		MarineManager.push(cMarine(hMarine));
}

function Startup()
{
	local hMarine = null;
	while ((hMarine = Entities.FindByClassname(hMarine, "asw_marine")) != null)
		MarineManager.push(cMarine(hMarine));
}

function GiveTurretWeapon(hMarine, strWeaponName)
{
	switch(strWeaponName)
	{
		case "asw_weapon_sentry":
			GiveVanillaTurret(hMarine);
			break;
		case "asw_weapon_sentry_flamer":
			GiveFlameTurret(hMarine);
			break;
		case "asw_weapon_sentry_freeze":
			GiveIceTurret(hMarine);
			break;
		case "asw_weapon_sentry_cannon":
			GiveCannonTurret(hMarine);
			break;
	}
}

function GiveVanillaTurret(hMarine)
{
	hMarine.GiveWeapon("asw_weapon_autogun", 0);
	local hWeapon = null;
	local TableInv = hMarine.GetInvTable();
	if ("slot0" in TableInv && TableInv["slot0"] != null)
	{
		hWeapon = TableInv["slot0"];
		if (hWeapon != null)
		{
			local cTarget = MarineManager[GetMarineIndex(hMarine)];
			hWeapon.SetName("gs_tvan" + cTarget.m_strName);
			hWeapon.SetClips(2);
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
			cTarget.m_hProp.GetScriptScope().MarineManager <- MarineManager;
			cTarget.m_hProp.GetScriptScope().GetMarineIndex <- GetMarineIndex;
			cTarget.m_hProp.GetScriptScope().RotateTurret <- RotateTurret;
			cTarget.m_hProp.GetScriptScope().CheckWeaponName <- CheckWeaponName;
			cTarget.m_hProp.GetScriptScope().SetVanTurretThinkFunc <- SetVanTurretThinkFunc;
			AddThinkToEnt(cTarget.m_hProp, "SetVanTurretThinkFunc");
		}
	}
}

function GiveFlameTurret(hMarine)
{
	hMarine.GiveWeapon("asw_weapon_flamer", 0);
	local hWeapon = null;
	local TableInv = hMarine.GetInvTable();
	if ("slot0" in TableInv && TableInv["slot0"] != null)
	{
		hWeapon = TableInv["slot0"];
		if (hWeapon != null)
		{
			local cTarget = MarineManager[GetMarineIndex(hMarine)];
			hWeapon.SetName("gs_tflm" + cTarget.m_strName);
			hWeapon.SetClip1(150);
			hWeapon.__KeyValueFromInt("renderamt", 0);
			hWeapon.__KeyValueFromInt("rendermode", 1);
			hWeapon.__KeyValueFromString("disableshadows", "1");
			hWeapon.__KeyValueFromString("disablereceiveshadows", "1");
			
			cTarget.m_hProp = Entities.CreateByClassname("prop_dynamic");
			cTarget.m_hProp.__KeyValueFromString("model", "models/sentry_gun/flame_top.mdl");
			cTarget.m_hProp.__KeyValueFromString("solid", "0");
			cTarget.m_hProp.__KeyValueFromInt("rendermode", 1);
			cTarget.m_hProp.SetOrigin(hMarine.GetOrigin());
			cTarget.m_hProp.SetOwner(hWeapon);
			cTarget.m_hProp.Spawn();
			
			cTarget.m_hProp.ValidateScriptScope();
			cTarget.m_hProp.GetScriptScope().MarineManager <- MarineManager;
			cTarget.m_hProp.GetScriptScope().GetMarineIndex <- GetMarineIndex;
			cTarget.m_hProp.GetScriptScope().RotateTurret <- RotateTurret;
			cTarget.m_hProp.GetScriptScope().CheckWeaponName <- CheckWeaponName;
			cTarget.m_hProp.GetScriptScope().SetFlameTurretThinkFunc <- SetFlameTurretThinkFunc;
			AddThinkToEnt(cTarget.m_hProp, "SetFlameTurretThinkFunc");
		}
	}
}

function GiveIceTurret(hMarine)
{
	hMarine.GiveWeapon("asw_weapon_fire_extinguisher", 0);
	local hWeapon = null;
	local TableInv = hMarine.GetInvTable();
	if ("slot0" in TableInv && TableInv["slot0"] != null)
	{
		hWeapon = TableInv["slot0"];
		if (hWeapon != null)
		{
			local cTarget = MarineManager[GetMarineIndex(hMarine)];
			hWeapon.SetName("gs_tice" + cTarget.m_strName);
			hWeapon.SetClip1(250);
			hWeapon.SetClips(3);
			hWeapon.__KeyValueFromInt("renderamt", 0);
			hWeapon.__KeyValueFromInt("rendermode", 1);
			hWeapon.__KeyValueFromString("disableshadows", "1");
			hWeapon.__KeyValueFromString("disablereceiveshadows", "1");
			
			cTarget.m_hProp = Entities.CreateByClassname("prop_dynamic");
			cTarget.m_hProp.__KeyValueFromString("model", "models/sentry_gun/freeze_top.mdl");
			cTarget.m_hProp.__KeyValueFromString("solid", "0");
			cTarget.m_hProp.__KeyValueFromInt("rendermode", 1);
			cTarget.m_hProp.SetOrigin(hMarine.GetOrigin());
			cTarget.m_hProp.SetOwner(hWeapon);
			cTarget.m_hProp.Spawn();
			
			cTarget.m_hProp.ValidateScriptScope();
			cTarget.m_hProp.GetScriptScope().MarineManager <- MarineManager;
			cTarget.m_hProp.GetScriptScope().GetMarineIndex <- GetMarineIndex;
			cTarget.m_hProp.GetScriptScope().RotateTurret <- RotateTurret;
			cTarget.m_hProp.GetScriptScope().CheckWeaponName <- CheckWeaponName;
			cTarget.m_hProp.GetScriptScope().SetIceTurretThinkFunc <- SetIceTurretThinkFunc;
			AddThinkToEnt(cTarget.m_hProp, "SetIceTurretThinkFunc");
		}
	}
}

function GiveCannonTurret(hMarine)
{
	hMarine.GiveWeapon("asw_weapon_grenade_launcher", 0);
	local hWeapon = null;
	local TableInv = hMarine.GetInvTable();
	if ("slot0" in TableInv && TableInv["slot0"] != null)
	{
		hWeapon = TableInv["slot0"];
		if (hWeapon != null)
		{
			local cTarget = MarineManager[GetMarineIndex(hMarine)];
			hWeapon.SetName("gs_tcan" + cTarget.m_strName);
			hWeapon.SetClip1(20);
			hWeapon.__KeyValueFromInt("renderamt", 0);
			hWeapon.__KeyValueFromInt("rendermode", 1);
			hWeapon.__KeyValueFromString("disableshadows", "1");
			hWeapon.__KeyValueFromString("disablereceiveshadows", "1");
			
			cTarget.m_hProp = Entities.CreateByClassname("prop_dynamic");
			cTarget.m_hProp.__KeyValueFromString("model", "models/sentry_gun/grenade_top.mdl");
			cTarget.m_hProp.__KeyValueFromString("solid", "0");
			cTarget.m_hProp.__KeyValueFromInt("rendermode", 1);
			cTarget.m_hProp.SetOrigin(hMarine.GetOrigin());
			cTarget.m_hProp.SetOwner(hWeapon);
			cTarget.m_hProp.Spawn();
			
			cTarget.m_hProp.ValidateScriptScope();
			cTarget.m_hProp.GetScriptScope().MarineManager <- MarineManager;
			cTarget.m_hProp.GetScriptScope().GetMarineIndex <- GetMarineIndex;
			cTarget.m_hProp.GetScriptScope().RotateTurret <- RotateTurret;
			cTarget.m_hProp.GetScriptScope().CheckWeaponName <- CheckWeaponName;
			cTarget.m_hProp.GetScriptScope().SetCannonTurretThinkFunc <- SetCannonTurretThinkFunc;
			AddThinkToEnt(cTarget.m_hProp, "SetCannonTurretThinkFunc");
		}
	}
}

function SetVanTurretThinkFunc()
{
	if (self.tostring().slice(0, 2) != "(i")
	{
		if (!self || !self.IsValid())
			self.Destroy();
	}
	else
		return 5000;
	
	local hMarine = null;
	while ((hMarine = Entities.FindByClassname(hMarine, "asw_marine")) != null)
	{
		local cTarget = MarineManager[GetMarineIndex(hMarine)];
		local hWeapon = NetProps.GetPropEntity(hMarine, "m_hActiveWeapon");
		
		if (hWeapon != null && CheckWeaponName(hWeapon, "gs_tvan"))
		{
			if (cTarget.m_hProp && cTarget.m_hProp.GetKeyValue("rendermode").tointeger())
			{
				DoEntFire("!self", "SetParent", "!activator", 0, hMarine, cTarget.m_hProp);
				DoEntFire("!self", "SetParentAttachment", "RHand", 0, null, cTarget.m_hProp);
				RotateTurret(cTarget.m_hProp, 0);
				cTarget.m_hProp.GetOwner().__KeyValueFromInt("renderamt", 0);
				cTarget.m_hProp.__KeyValueFromInt("renderamt", 255);
				cTarget.m_hProp.__KeyValueFromInt("rendermode", 0);
			}
		}
		else
		{
			local hWeaponSlot1 = null;
			local TableInv = hMarine.GetInvTable();
			if ("slot0" in TableInv && TableInv["slot0"] != null)
				hWeaponSlot1 = TableInv["slot0"];
			
			if (hWeaponSlot1 != null && CheckWeaponName(hWeaponSlot1, "gs_tvan"))
			{
				cTarget.m_hProp.GetOwner().__KeyValueFromInt("renderamt", 255);
				cTarget.m_hProp.__KeyValueFromInt("renderamt", 0);
				cTarget.m_hProp.__KeyValueFromInt("rendermode", 1);
			}
		}
	}
	return 0.05;
}

function SetFlameTurretThinkFunc()
{
	if (self.tostring().slice(0, 2) != "(i")
	{
		if (!self || !self.IsValid())
			self.Destroy();
	}
	else
		return 5000;
	
	local hMarine = null;
	while ((hMarine = Entities.FindByClassname(hMarine, "asw_marine")) != null)
	{
		local cTarget = MarineManager[GetMarineIndex(hMarine)];
		local hWeapon = NetProps.GetPropEntity(hMarine, "m_hActiveWeapon");
		
		if (hWeapon != null && CheckWeaponName(hWeapon, "gs_tflm"))
		{
			if (cTarget.m_hProp && cTarget.m_hProp.GetKeyValue("rendermode").tointeger())
			{
				DoEntFire("!self", "SetParent", "!activator", 0, hMarine, cTarget.m_hProp);
				DoEntFire("!self", "SetParentAttachment", "RHand", 0, null, cTarget.m_hProp);
				RotateTurret(cTarget.m_hProp, 1);
				cTarget.m_hProp.GetOwner().__KeyValueFromInt("renderamt", 0);
				cTarget.m_hProp.__KeyValueFromInt("renderamt", 255);
				cTarget.m_hProp.__KeyValueFromInt("rendermode", 0);
			}
		}
		else
		{
			local hWeaponSlot1 = null;
			local TableInv = hMarine.GetInvTable();
			if ("slot0" in TableInv && TableInv["slot0"] != null)
				hWeaponSlot1 = TableInv["slot0"];
			
			if (hWeaponSlot1 != null && CheckWeaponName(hWeaponSlot1, "gs_tflm"))
			{
				cTarget.m_hProp.GetOwner().__KeyValueFromInt("renderamt", 255);
				cTarget.m_hProp.__KeyValueFromInt("renderamt", 0);
				cTarget.m_hProp.__KeyValueFromInt("rendermode", 1);
			}
		}
	}
	return 0.05;
}

function SetIceTurretThinkFunc()
{
	if (self.tostring().slice(0, 2) != "(i")
	{
		if (!self || !self.IsValid())
			self.Destroy();
	}
	else
		return 5000;
	
	local hMarine = null;
	while ((hMarine = Entities.FindByClassname(hMarine, "asw_marine")) != null)
	{
		local cTarget = MarineManager[GetMarineIndex(hMarine)];
		local hWeapon = NetProps.GetPropEntity(hMarine, "m_hActiveWeapon");
		
		if (hWeapon != null && CheckWeaponName(hWeapon, "gs_tice"))
		{
			if (cTarget.m_hProp && cTarget.m_hProp.GetKeyValue("rendermode").tointeger())
			{
				DoEntFire("!self", "SetParent", "!activator", 0, hMarine, cTarget.m_hProp);
				DoEntFire("!self", "SetParentAttachment", "RHand", 0, null, cTarget.m_hProp);
				RotateTurret(cTarget.m_hProp, 2);
				cTarget.m_hProp.GetOwner().__KeyValueFromInt("renderamt", 0);
				cTarget.m_hProp.__KeyValueFromInt("renderamt", 255);
				cTarget.m_hProp.__KeyValueFromInt("rendermode", 0);
			}
		}
		else
		{
			local hWeaponSlot1 = null;
			local TableInv = hMarine.GetInvTable();
			if ("slot0" in TableInv && TableInv["slot0"] != null)
				hWeaponSlot1 = TableInv["slot0"];
			
			if (hWeaponSlot1 != null && CheckWeaponName(hWeaponSlot1, "gs_tice"))
			{
				cTarget.m_hProp.GetOwner().__KeyValueFromInt("renderamt", 255);
				cTarget.m_hProp.__KeyValueFromInt("renderamt", 0);
				cTarget.m_hProp.__KeyValueFromInt("rendermode", 1);
			}
		}
	}
	return 0.05;
}

function SetCannonTurretThinkFunc()
{
	if (self.tostring().slice(0, 2) != "(i")
	{
		if (!self || !self.IsValid())
			self.Destroy();
	}
	else
		return 5000;
	
	local hMarine = null;
	while ((hMarine = Entities.FindByClassname(hMarine, "asw_marine")) != null)
	{
		local cTarget = MarineManager[GetMarineIndex(hMarine)];
		local hWeapon = NetProps.GetPropEntity(hMarine, "m_hActiveWeapon");
		
		if (hWeapon != null && CheckWeaponName(hWeapon, "gs_tcan"))
		{
			if (cTarget.m_hProp && cTarget.m_hProp.GetKeyValue("rendermode").tointeger())
			{
				DoEntFire("!self", "SetParent", "!activator", 0, hMarine, cTarget.m_hProp);
				DoEntFire("!self", "SetParentAttachment", "RHand", 0, null, cTarget.m_hProp);
				RotateTurret(cTarget.m_hProp, 3);
				cTarget.m_hProp.GetOwner().__KeyValueFromInt("renderamt", 0);
				cTarget.m_hProp.__KeyValueFromInt("renderamt", 255);
				cTarget.m_hProp.__KeyValueFromInt("rendermode", 0);
			}
		}
		else
		{
			local hWeaponSlot1 = null;
			local TableInv = hMarine.GetInvTable();
			if ("slot0" in TableInv && TableInv["slot0"] != null)
				hWeaponSlot1 = TableInv["slot0"];
			
			if (hWeaponSlot1 != null && CheckWeaponName(hWeaponSlot1, "gs_tcan"))
			{
				cTarget.m_hProp.GetOwner().__KeyValueFromInt("renderamt", 255);
				cTarget.m_hProp.__KeyValueFromInt("renderamt", 0);
				cTarget.m_hProp.__KeyValueFromInt("rendermode", 1);
			}
		}
	}
	return 0.05;
}

function GrenadeMoveForward()
{
	if (iCount > 0.9)
	{
		local hExplosion = Entities.CreateByClassname("env_explosion");
		hExplosion.__KeyValueFromInt("iMagnitude", 100);
		hExplosion.__KeyValueFromInt("iRadiusOverride", 128);
		hExplosion.__KeyValueFromInt("spawnflags", 1618);
		hExplosion.SetOrigin(self.GetOrigin());
		local hExplosionFX = Entities.CreateByClassname("info_particle_system");
		hExplosionFX.__KeyValueFromString("effect_name", "explosion_grenade");
		hExplosionFX.__KeyValueFromString("start_active", "1");
		hExplosionFX.SetOrigin(self.GetOrigin());
		hExplosionFX.Spawn();
		hExplosionFX.Activate();
		DoEntFire("!self", "Explode", "", 0, null, hExplosion);
		self.EmitSound("ASWGrenade.Explode");
		self.Destroy();
	}
	iCount += 0.1;
	return 0.1;
}

function CheckWeaponName(hWeapon, strName)
{
	if (hWeapon.GetName().len() > 7)
	{
		if (hWeapon.GetName().slice(0, 7) == strName)
			return true;
	}
	return false;
}

function CheckTurret(hMarine)
{
	local cTarget = MarineManager[GetMarineIndex(hMarine)];
	if (cTarget.m_hProp)
	{
		if (cTarget.m_hProp.tostring().len() > 2 && cTarget.m_hProp.tostring().slice(0, 2) != "(i")
		{
			cTarget.m_hProp.Destroy();
			cTarget.m_hProp = null;
		}
	}
	else
		return;
		
	local hVanTurret = null;
	while ((hVanTurret = Entities.FindByClassname(hVanTurret, "asw_weapon_autogun")) != null)
	{
		if (hVanTurret.GetName() == "gs_tvan" + cTarget.m_strName)
		{
			local vecTurretPos = hVanTurret.GetOrigin();
			local flTurretAngleY = hVanTurret.GetAngles().y + 90;
			hVanTurret.Destroy();
			local hRealTurret = Entities.CreateByClassname("asw_sentry_top_machinegun");
			hRealTurret.SetOrigin(vecTurretPos + Vector(0, 0, -50));
			hRealTurret.SetAnglesVector(Vector(0, flTurretAngleY, 0));
			hRealTurret.Spawn();
		}
	}
	
	local hFlameTurret = null;
	while ((hFlameTurret = Entities.FindByClassname(hFlameTurret, "asw_weapon_flamer")) != null)
	{
		if (hFlameTurret.GetName() == "gs_tflm" + cTarget.m_strName)
		{
			local vecTurretPos = hFlameTurret.GetOrigin();
			local flTurretAngleY = hFlameTurret.GetAngles().y + 90;
			hFlameTurret.Destroy();
			local hRealTurret = Entities.CreateByClassname("asw_sentry_top_flamer");
			hRealTurret.SetOrigin(vecTurretPos + Vector(0, 0, -60));
			hRealTurret.SetAnglesVector(Vector(0, flTurretAngleY, 0));
			hRealTurret.Spawn();
		}
	}
	
	local hIceTurret = null;
	while ((hIceTurret = Entities.FindByClassname(hIceTurret, "asw_weapon_fire_extinguisher")) != null)
	{
		if (hIceTurret.GetName() == "gs_tice" + cTarget.m_strName)
		{
			local vecTurretPos = hIceTurret.GetOrigin();
			local flTurretAngleY = hIceTurret.GetAngles().y + 180;
			hIceTurret.Destroy();
			local hRealTurret = Entities.CreateByClassname("asw_sentry_top_icer");
			hRealTurret.SetOrigin(vecTurretPos + Vector(0, 0, -60));
			hRealTurret.SetAnglesVector(Vector(0, flTurretAngleY, 0));
			hRealTurret.Spawn();
		}
	}
	
	local hCannonTurret = null;
	while ((hCannonTurret = Entities.FindByClassname(hCannonTurret, "asw_weapon_grenade_launcher")) != null)
	{
		if (hCannonTurret.GetName() == "gs_tcan" + cTarget.m_strName)
		{
			local vecTurretPos = hCannonTurret.GetOrigin();
			local flTurretAngleY = hCannonTurret.GetAngles().y + 90;
			hCannonTurret.Destroy();
			local hRealTurret = Entities.CreateByClassname("asw_sentry_top_cannon");
			hRealTurret.SetOrigin(vecTurretPos + Vector(0, 0, -60));
			hRealTurret.SetAnglesVector(Vector(0, flTurretAngleY, 0));
			hRealTurret.Spawn();
		}
	}
}

function RotateTurret(hTurret, iType)
{
	local hTimer = Entities.CreateByClassname("logic_timer");
	hTimer.__KeyValueFromFloat("RefireTime", 0.01);
	DoEntFire("!self", "Disable", "", 0, null, hTimer);
	hTimer.ValidateScriptScope();
	
	hTimer.GetScriptScope().hTurret <- hTurret;
	hTimer.GetScriptScope().iType <- iType;
	hTimer.GetScriptScope().TimerFunc <- function()
	{
		if (hTurret != null && hTurret.IsValid())
		{
			switch (iType)
			{
				case 0:
					hTurret.SetLocalOrigin(Vector(3, 0, 6));
					hTurret.SetLocalAngles(10, 0, -180);
					break;
				case 1:
					hTurret.SetLocalOrigin(Vector(-19, -46, -2));
					hTurret.SetLocalAngles(-2, -4, -90);
					break;
				case 2:
					hTurret.SetLocalOrigin(Vector(-10, -44, -7));
					hTurret.SetLocalAngles(12, -12, -87);
					break;
				case 3:
					hTurret.SetLocalOrigin(Vector(-13, -49, -4));
					hTurret.SetLocalAngles(10, 0, -90);
					break;
			}
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
