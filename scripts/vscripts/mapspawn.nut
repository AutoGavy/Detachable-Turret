mapName <- GetMapName();
challengeName <- Convars.GetStr("rd_challenge");
if (mapName != "dm_desert" && mapName != "dm_deima" && mapName != "dm_residential" && mapName != "dm_testlab" && mapName != "dm_lavarena" &&
challengeName != "gandalfs_revenge" && challengeName.find("backfire", 0) == null && challengeName.find("4fun", 0) == null)
	IncludeScript("script_detachable_turrets.nut");
