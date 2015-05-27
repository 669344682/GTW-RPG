--[[ 
********************************************************************************
	Project owner:		GTWGames												
	Project name: 		GTW-RPG	
	Developers:   		GTWCode
	
	Source code:		https://github.com/GTWCode/GTW-RPG/
	Bugtracker: 		http://forum.gtw-games.org/bug-reports/
	Suggestions:		http://forum.gtw-games.org/mta-servers-development/
	
	Version:    		Open source
	License:    		GPL v.3 or later
	Status:     		Stable release
********************************************************************************
]]--

-- Temporary storage of weapons
timers			= { }
weapon_list 	= {{ }}
ammo_list 		= {{ }}

-- List of available hospitals
hs_table = {
	[1]={ 1177, -1320, 13, 270 },
	[2]={ -2666, 630, 13.5, 180 },
	[3]={ 1607.1225585938, 1817.8732910156, 9.8203125, 0 },
	[4]={ 2040, -1420, 16.2, 90 },
	[5]={ -2200, -2308, 29.6, -45 },
	[6]={ 208.095703125, -65.3193359375, 0.5, 175.78668212891 },
	[7]={ 1245.779296875, 336.87890625, 18.5, 341.87503051758 },
	[8]={ -317.4208984375, 1056.3779296875, 18.7, 356.13000488281 },
	[9]={ -1514.7568359375, 2527.89453125, 54.7, 1.7880554199219 },
}

-- Cost of the healthcare
hs_charge 					= 500
hs_respawn_time 			= 10
hs_spawn_protection_time 	= 20

--[[ Load all the hospitals from the table ]]--
function load_hospitals()
	for i=1, #hs_table do
		createBlip(hs_table[i][1], hs_table[i][2], hs_table[i][3], 22, 1, 0, 0, 0, 255, 2, 180)
		local h_marker = createMarker(hs_table[i][1], hs_table[i][2], hs_table[i][3], "cylinder", 2, 0, 200, 0, 30)
		addEventHandler("onMarkerHit", h_marker, hs_start_heal) 
		addEventHandler("onMarkerLeave", h_marker, hs_stop_heal)
	end
end
addEventHandler("onResourceStart", resourceRoot, load_hospitals)

--[[ Return the nearest hospital depending on a players location ]]--
function get_nearest_hospital(plr)
	if not plr or not isElement(plr) or getElementType(plr) ~= "player" then return end
	local n_loc,min = nil,9999
	for k,v in ipairs(hs_table) do
		-- Get the distance for each point
		local px,py,pz=getElementPosition(plr)
        local dist = getDistanceBetweenPoints2D(px,py,v[1],v[2])
		
		-- Update coordinates if distance is smaller
		if dist < min then
			n_loc = v
			min = dist
		end
	        
		-- 2015-03-01 Dead in interior? respawn at LS hospital
		if getElementInterior(plr) > 0 then break end
	end
	
	-- Check if jailed or not and return either hospital or jail
	local isJailed = exports.GTWjail:isJailed(thePlayer)
	if not isJailed then
		return n_loc[1]+math.random(-2,2),n_loc[2]+math.random(-2,2),n_loc[3]+2,n_loc[4]
	else
		return -2965+math.random(-2,2),2305+math.random(-2,2),8,180
	end
end

--[[ Toggle controls for a player ]]--
function toggle_controls(plr, n_state)
	if not plr or not isElement(plr) or getElementType(plr) ~= "player" then return end
	toggleControl(plr, "jump", n_state)
	toggleControl(plr, "sprint", n_state)
    toggleControl(plr, "crouch", n_state)
    toggleControl(plr, "fire", n_state)
    toggleControl(plr, "aim_weapon", n_state)
    toggleControl(plr, "enter_exit", n_state)
    toggleControl(plr, "enter_passenger", n_state)
    toggleControl(plr, "forwards", n_state)
	toggleControl(plr, "walk", n_state)
 	toggleControl(plr, "backwards", n_state)
  	toggleControl(plr, "left", n_state)
  	toggleControl(plr, "right", n_state)
  	toggleControl(plr, "vehicle_fire", n_state)
end

--[[ Respawn after death "onPlayerSpawn" ]]--
function player_Spawn(x,y,z, r, team_name, skin_id, int,dim)
	-- Play the spawn sound
	playSoundFrontEnd(source, 16)
	
	-- Restore weapons
	if weapon[source] and ammo[source] then
		for k,wep in ipairs(weapon[source]) do
			if weapon[source][k] and ammo[source][k] then
				-- Return ammo to the player
				giveWeapon(source, weapon[source][k], ammo[source][k], false)
				
				-- Clean up used space
				weapon[source][k] = nil
				ammo[source][k] = nil
			end
		end
	end
	
	-- Check if jailed
	local isJailed = exports.GTWjail:isJailed(source)
	if isJailed then return end
	
	-- Fade in the camera and set it's target	
	fadeCamera(source, true, 6,255,255,255)
	setCameraTarget(source, source)
	
	-- Make sure the player is not frozen
	setElementFrozen(source, false)
	
	-- Set health to 30
	setElementHealth(source, 30)
	
	-- Enable controls
	toggle_controls(source, true)
	
	-- Enable spawn protection
	triggerClientEvent(source, "GTWhospital.setSpawnProtection", source, hs_spawn_protection_time)
	  
	-- Infom the player about his respawn	  
	exports.GTWtopbar:dm("Hospital: You have been healed at "..getZoneName(x,y,z)..", for a cost of $"..hs_charge, source, 255, 100, 0)
end
addEventHandler("onPlayerSpawn", root, player_Spawn)

--[[ On player wasted, fade out and send to hospital ]]--
function on_death(ammo, attacker, weapon, bodypart)
	-- Save all weapons currently hold by a player
	weapon[source] 	= { 0,0,0,0,0,0,0,0,0,0,0,0 }
	ammo[source] 	= { 0,0,0,0,0,0,0,0,0,0,0,0 }
	
	-- Check all weapon slots and save their ammo
	for k,v in ipairs(weapon[source]) do
		weapon[source][k] = getPedWeapon(source, k)
		setPedWeaponSlot(source, k)
		ammo[source][k] = getPedTotalAmmo(source, k)
	end
	
	-- Check if jailed or not
	local isJailed = exports.GTWjail:isJailed(source)
	if isJailed then return end
	
	-- Make sure warp to hospital is possible
	if getPedOccupiedVehicle(source) then removePedFromVehicle(source) end	
	
	-- Take some of the money
	takePlayerMoney(plr, hs_charge)
	fadeCamera(source, false, 6, 0, 0, 0)
	
	-- Respawn player after "hs_respawn_time" seconds
	local x,y,z, r = get_nearest_hospital(plr)
	setTimer(spawnPlayer, hs_respawn_time*1000, 1, plr, x,y,z+1, r, getElementModel(plr), 0,0, getPlayerTeam(plr))
	
	-- Notify player about his death
	exports.GTWtopbar:dm("Hospital: You are dead! an ambulance will pick you up soon", source, 255, 100, 0)
end
addEventHandler("onPlayerWasted", root, on_death)

--[[ Dump weapons into users database on quit ]]--
function dump_weapons()
	-- Get player account
    local acc = getPlayerAccount(source)
    
    -- Check if there is any weapons in memory
    if not weapon_list[source] then return end
    
    -- Save the weapons and ammo stored in memory
    for k,w in ipairs(weapons) do
	    if weapon_list[source][k] and ammo_list[source][k] then
	   		setAccountData(acc, "acorp.weapon."..tostring(k), weapon_list[source][k])
	   		setAccountData(acc, "acorp.ammo."..tostring(k), ammo_list[source][k])
	   	end
	end
end
addEventHandler("onPlayerQuit", root, dump_weapons)
 
--[[ Heal player once in a health marker ]]--
function hospital_heal(plr)
	if not plr or not isElement(plr) or getElementType(plr) ~= "player" then return end
	local health = getElementHealth(plr)
	local charge = math.floor(hs_charge/10)
    if health < 90 and getPlayerMoney(plr) >= charge then
    	setElementHealth(plr, health+10)
    	takePlayerMoney(plr, charge)
    elseif getPlayerMoney(plr) >= charge then
    	setElementHealth(plr, 100)
    	takePlayerMoney(plr, charge)
    	exports.GTWtopbar:dm("Hospital: Go away, you're fine!", plr, 255, 100, 0)
    	if isTimer(timers[plr]) then
			killTimer(timers[plr])
		end
    elseif getPlayerMoney(plr) < charge then
    	exports.GTWtopbar:dm("Hospital: You can't afford the healthcare!", plr, 255, 0, 0)
    end
end

--[[ Start an healing timer, increasing the health of a player ]]--
function hs_start_heal(hitElement, matchingDimension) 
	if isTimer(timers[hitElement]) then killTimer(timers[hitElement]) end
	if getElementHealth(hitElement) < 90 then
		exports.GTWtopbar:dm("Stay in the marker to get healed!", hitElement, 255, 100, 0)
    	timers[hitElement] = setTimer(hospital_heal, 1400, 0, hitElement)
    end
end

--[[ Stop and kill the heal timers ]]--
function hs_stop_heal(plr, matchingDimension)
	if isTimer(timers[plr]) then killTimer(timers[plr]) end
end