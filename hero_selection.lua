function UpdateLaneAssignments()
	if ( GetTeam() == TEAM_RADIANT ) then 
		return {
			[1] = LANE_BOT,
			[2] = LANE_MID,
			[3] = LANE_TOP,
			[4] = LANE_TOP,
			[5] = LANE_BOT
		};
	elseif ( GetTeam() == TEAM_DIRE ) then
		return {
			[1] = LANE_TOP,
			[2] = LANE_MID,
			[3] = LANE_BOT,
			[4] = LANE_BOT,
			[5] = LANE_TOP
		};
	end
end
		
function Think()
	if ( GetTeam() == TEAM_RADIANT ) then
		SelectHero( 0, "npc_dota_hero_medusa" );
		SelectHero( 1, "npc_dota_hero_lina" );
		SelectHero( 2, "npc_dota_hero_abyssal_underlord" );
		SelectHero( 3, "npc_dota_hero_ogre_magi" );
		SelectHero( 4, "npc_dota_hero_lich" );
		SelectHero( 5, "npc_dota_hero_gyrocopter" );
		SelectHero( 6, "npc_dota_hero_nevermore" );
		SelectHero( 7, "npc_dota_hero_tidehunter" );
		SelectHero( 8, "npc_dota_hero_disruptor" );
		SelectHero( 9, "npc_dota_hero_witch_doctor" );
	elseif ( GetTeam() == TEAM_DIRE ) then
		SelectHero( 0, "npc_dota_hero_medusa" );
		SelectHero( 1, "npc_dota_hero_lina" );
		SelectHero( 2, "npc_dota_hero_abyssal_underlord" );
		SelectHero( 3, "npc_dota_hero_ogre_magi" );
		SelectHero( 4, "npc_dota_hero_lich" );
		SelectHero( 5, "npc_dota_hero_gyrocopter" );
		SelectHero( 6, "npc_dota_hero_nevermore" );
		SelectHero( 7, "npc_dota_hero_tidehunter" );
		SelectHero( 8, "npc_dota_hero_disruptor" );
		SelectHero( 9, "npc_dota_hero_witch_doctor" );
	end
end