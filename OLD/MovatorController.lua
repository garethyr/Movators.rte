--The global movator controller and power source
--[[NOTES:
For AI need to
CHECK	1.	Find the nearest movator to actor, keep him still until he has a path.
			Move him to the nearest one if necessary.
				Maybe compare the nearest and the direction we want to go in so we don't go backwards.

		2.	Plot path: check directions nearest movator can move actor in, pick the right/only one, save it and move on.
				Repeat til we have a valid path.
				For paths, we could send a particle and measure the length of time each valid path takes to pick the shortest.
		3.	Once we have a valid path, copy the saved movements to the actor's direction instructions and move him.
		4.	For each movator he passes over, read the next direction and make him go in it, then remove that instruction.
		5.	Once he's at the movator nearest his destination, spit him out and remove him from the table.

		
		NOTE: For actual movement - open affectedactor table to movators. Make it so they check if the
				actor has a table2 value and if so, take the first of those for its direction to move in
				(maybe wait to change move direction til actor is in center so it doesn't drag on corners)
				Then set the actor's lifetime to that value and remove it from the table.
				
				TODO: Also, make movator hold actor and glow if an actor is in there with no direction table.

Oh God this is gonna be hard!




Other TODO:
Make nodes on the end of a route glowy?
Power, etc. A long time in the future
]]--

-----------------------------------------------------------------------------------------
-- Create
-----------------------------------------------------------------------------------------
function Create(self)
	--Global area shared by all movators
	CombinedMovatorArea = Area();
	
	--Global Table for all movators
	--Arguments: 1 - the number of movators
	--[i][1] - reference to this movator
	--[i][2] - the number of connections for this movator
	--[i][3 - 6] - reference to each of the closest movators. Above = 3, Below = 4, Left = 5, Right = 6
	MovatorNodeTable = {}
	
	--Check through all movators
	CheckAllMovators = true;
	
	--Global timer for rechecking node placement in case the node gets blocked or removed
	MovatorNodeRecheckTimer = Timer();
	MovatorNodeRecheckInterval = 1500;
	
	--Global variable for reading if nodes have power
	--TODO change this into area based, etc.
	MovatorNodesPowered = true;
	
	--Table for actors affected by the movators
	--[i][1] is the actor
	--[i][2] is the actor's direction table
	self.MovatorAffectedActors = {};
	
	--The table for direction choices in pathfinding.
	--1 - Each actor using it.
	--2 - Each run for that actor, total number of runs based on self.DirectionTotal
	--[i][i][1] - Path table (i.e. 0,0,1,2 etc. using last digit of move directions) TODO: Currently string, use table or string?
	--[i][i][2] Distance calculation
	--[i][i][3] Validity check, boolean true/false
	self.PDTable = {};
	
	--Timers and other self variables
	
	--Set the speed that the actors move at and the speed above which to slow down actors that are using the movator
	self.Speed = 4;
	--self.DirectionTotal = 0; --The total number of possible directions an actor can go in. For path calculation.
	
	self.ActorCheckLagTimer = Timer();
	self.AllMovatorCheckTimer = Timer();
	self.MovementLagTimer = Timer();
	self.DirectionLagTimer = Timer();

	--TODO: Figure out a better way for when to check the closest movator. Probably based on direction changes
	--Possibly set up a table that mirrors the actor table (or is argument 2 of the actor table) that stores the closest, and is only changed on direction change
	self.ActorClosestCheckTimer = Timer();
	self.ActorClosestCheckTimer:Reset();
	
	self.ActorCheckLagTimer:Reset();
	self.AllMovatorCheckTimer:Reset();
	self.MovementLagTimer:Reset();
	self.DirectionLagTimer:Reset();
end
-----------------------------------------------------------------------------------------
-- Update
-----------------------------------------------------------------------------------------
function Update(self)
	if UInputMan:KeyPressed(3) then
		self.MovatorAffectedActors = {};
		for actor in MovableMan.Actors do actor.Lifetime = 0 end;
		MovatorNodeTable = {}
		PresetMan:ReloadAllScripts();
		print ("all scripts reloaded");
		self:ReloadScripts();
		print ("controller scripts reloaded");
	end
	
	--Stop checking through all movators if we still are
	if self.AllMovatorCheckTimer ~= nil then
		if self.AllMovatorCheckTimer:IsPastSimMS(500) then
			CheckAllMovators = false;
			self.AllMovatorCheckTimer = nil;
		end
	end
	if UInputMan:KeyPressed(2) then
		print ("Number Movator Node Table: "..tostring(#MovatorNodeTable));
		print ("Number of paths: "..tostring(PathNumberCalc(self)));
	end
	--TODO Make a real power system. Hahaha so far in the future it's not even funny
	--Make sure the movators stay flagged as powered
	MovatorNodesPowered = true;

	--Redo the movator closeness checks approximately every 3000 MS to make sure nothing is blocked
	if ActivityMan:GetActivity():Running() then --currently does nothing
		if MovatorNodeRecheckTimer:IsPastSimMS(MovatorNodeRecheckInterval - 51) and not MovatorNodeRecheckTimer:IsPastSimMS(MovatorNodeRecheckInterval - 1) then
			MovatorNodePlacedCheck = true;
		elseif MovatorNodeRecheckTimer:IsPastSimMS(MovatorNodeRecheckInterval) then
			MovatorNodePlacedCheck = false;
			MovatorNodeRecheckTimer:Reset();
		end
	end
	
		for actor in MovableMan.Actors do
			if not actor:IsPlayerControlled() then
				actor:GetController():SetState(Controller.BODY_JUMP, false);
				actor:GetController():SetState(Controller.BODY_JUMPSTART, false);
				actor:GetController():SetState(Controller.MOVE_LEFT, false);
				actor:GetController():SetState(Controller.MOVE_RIGHT, false);
			end
		end

	--Check for actors in the Movators and add them to the table
	if self.ActorCheckLagTimer:IsPastSimMS(100) then
		for actor in MovableMan.Actors do
			if CombinedMovatorArea:IsInside(actor.Pos) and actor.PinStrength == 0 and actor.Mass < 300 and actor.ClassName ~= "ACRocket" and actor.ClassName ~= "ADropship" and actor.Lifetime < 999999 then
				--Make the table have another dimension
				self.MovatorAffectedActors[#self.MovatorAffectedActors+1] = {};
				--The first part of the table is a reference to the actor
				self.MovatorAffectedActors[#self.MovatorAffectedActors][1] = actor;
				--The second part is a table which will be used to fill its movement directions
				self.MovatorAffectedActors[#self.MovatorAffectedActors][2] = {};
				actor.Lifetime = 999999;
			end
		end
		self.ActorCheckLagTimer:Reset();
	end
	--Sets actors' lifetime back to zero if they're not in the Movator Area
	if #self.MovatorAffectedActors > 0 then --Use the second because it sets to 0 when it's empty while the original table is at 1
		for i = 1 , #self.MovatorAffectedActors do
			if not CombinedMovatorArea:IsInside(self.MovatorAffectedActors[i][1].Pos) then
				self.MovatorAffectedActors[i][1].Lifetime = 0;
				self.MovatorAffectedActors[i][2] = {};
				table.remove(self.MovatorAffectedActors , i);
					
			--Performs all the actions
			elseif CombinedMovatorArea:IsInside(self.MovatorAffectedActors[i][1].Pos) then
		
				--Pick the right direction to move in for players and ai
				if self.DirectionLagTimer:IsPastSimMS(25) then
					GetDirections(self , self.MovatorAffectedActors[i][1] , self.MovatorAffectedActors[i][2]);
					self.DirectionLagTimer:Reset();
				end
				
				--Do the actual movements
				if self.MovementLagTimer:IsPastSimMS(15) then
					DoMovements(self , self.MovatorAffectedActors[i][1]);
					self.MovementLagTimer:Reset();
				end
			end
		end
	end
end
-----------------------------------------------------------------------------------------
-- Find Nearest Visible Movator (returns a reference to that movator)
-----------------------------------------------------------------------------------------
function NearestMovator(self, actor)
	local dist1 = 0
	local closest;
	for i = 1 , #MovatorNodeTable do
		if i == 1 then
			closest = MovatorNodeTable[i][1];
			dist1 = SceneMan:ShortestDistance(actor.Pos,closest.Pos,SceneMan.SceneWrapsX).Magnitude;
		else
			local dist2 = SceneMan:ShortestDistance(actor.Pos,MovatorNodeTable[i][1].Pos,SceneMan.SceneWrapsX).Magnitude;
			if dist2 < dist1 then
				local seeray = SceneMan:CastStrengthRay(actor.Pos, (MovatorNodeTable[i][1].Pos - actor.Pos), 15, Vector(), 4, 0, true);
				if seeray == false then
					closest = MovatorNodeTable[i][1];
					dist = dist;
				end
			end
		end
	end
	return closest;
end
-----------------------------------------------------------------------------------------
-- Find The Number of Possible Directions (returns the number of possible directions)
-----------------------------------------------------------------------------------------
function PathNumberCalc(self)
	local dnum = 0;
	--If we have movators then
	if #MovatorNodeTable > 1 then
		--If we only have two make sure it's clear there's one connection
		if #MovatorNodeTable == 2 then
			dnum = 1;
		--Otherwise the rest will be handled by this
		elseif #MovatorNodeTable > 2 then
			for i = 1, #MovatorNodeTable do
				if MovatorNodeTable[i][2] > 1 then
					dnum = dnum + MovatorNodeTable[i][2];
				end
			end
		end
	end
	return dnum;
end	
-----------------------------------------------------------------------------------------
-- Find Valid Movement Path (returns the shortest correct move path to the actor's table2
-----------------------------------------------------------------------------------------
function FindPath(self, actor, dtable, start)
	--Note: dtable is the actor's individual direction table, filled in at the end.
	--Note2: This function is run once for each actor. Treat it as such.
	--May be run again if actor is in trouble (TODO: make diagnostic).

	--Find the ending movator
	--starting point defined already
	local target = actor:GetLastAIWaypoint()
	
	--Calculate number of possibilities, 
	--Pick first empty pdtable main.
	--Run number, starts at 1, etc.
	--1 of the third becomes path table (i.e. 0,0,1,2 etc. using last digit of move directions)
	--1		Use a string or a table? Will using a table fuck it up and require another level of complexity?
	--2 of the third becomes distance calc
	--3 of the third becomes validity check, boolean true/false
	--After all possibilities return the shortest one that works
	
	--The number of possible paths the actor can take.
	local totpaths = PathNumberCalc(self);
	--Pick the table to use for this direction finding
	self.PDTable[#self.PDTable+1] = {};
	local PDT1Val = #self.PDTable;
								--ConsoleMan:SaveAllText("Text.txt");
	--Iterate through the total number of path choices to get our number of runs
	if totpaths > 1 then
		for i = 1, totpaths do
			--For each choice, we make a new run and open its table
			self.PDTable[PDT1Val][i] = {};
			self.PDTable[PDT1Val][i][1] = "";
			self.PDTable[PDT1Val][i][2] = 0;
			--Set a flag for which node to find in the MovatorNodeTable, which node was checked before and the final node checked
			local ncheck, pncheck, fncheck = start, start, start;
			--Set boolean flags for if the movator is going backwards, so we know when we're at the end (i.e. if all 4 are true)
			local noup, nodown, noleft, noright = true, true, true, true;
			--The string of instructions for all runs after the first
			local instructionstring = "";
			
			--Now we begin the hard work
			--Iterate through the movatornodetable for each run, determining direction each time.
			for j = 1 , #MovatorNodeTable do
				print ("I: "..tostring(i).."     J: "..tostring(j));
			--for j, v in ipairs(MovatorNodeTable) do
				--We want to check from a specific node (originally the start).
				if MovatorNodeTable[j][1].Sharpness == ncheck.Sharpness then
					--If we haven't been given instructions because this is the first run
					if instructionstring == nil then
						--If we can go in more direction or we are at the start, i.e. not a dead end
						if MovatorNodeTable[j][2] > 1 or (MovatorNodeTable[j][2] == 1 and ncheck.Sharpness == start.Sharpness) then
							--If we can go up (i.e. we have a node above us)
							if MovatorNodeTable[j][3] ~= nil then
								--If the node above isn't the one we came from
								if MovatorNodeTable[j][3].Sharpness ~= pncheck.Sharpness then
									--If we've hit our destination, flag that as true
									if ncheck.Sharpness == target.Sharpness then
										self.PDTable[PDT1Val][i][3] = true;
										print ("At destination from a hub");
									else
										--Find the shortest distance to this node, to get the most efficient final route
										local dist = SceneMan:ShortestDistance(ncheck.Pos,MovatorNodeTable[j][3].Pos,SceneMan.SceneWrapsX).Magnitude;
										--Add to the table[1] the direction to move in to go to this node
										self.PDTable[PDT1Val][i][1] = self.PDTable[PDT1Val][i][1].."0";
										--Save this run in the instructionstring for the next run
										instructionstring = self.PDTable[PDT1Val][i][1];
										--Add to the table[2] the distance between these nodes
										self.PDTable[PDT1Val][i][2] = self.PDTable[PDT1Val][i][2]+dist;
										--Set the node we started this from as pncheck and node we moved to as ncheck
										pncheck = ncheck;
										ncheck = MovatorNodeTable[j][3];
										print ("All set to go up!");
									end
								end
								
							--We can't go up so:
							--If we can go down (i.e. we have a node below us)
							elseif MovatorNodeTable[j][4] ~= nil then
								--If the node below isn't the one we came from
								if MovatorNodeTable[j][4].Sharpness ~= pncheck.Sharpness then
									--If we've hit our destination, flag that as true
									if ncheck.Sharpness == target.Sharpness then
										self.PDTable[PDT1Val][i][3] = true;
										print ("At destination from a hub");
									else
										--Find the shortest distance to this node, to get the most efficient final route
										local dist = SceneMan:ShortestDistance(ncheck.Pos,MovatorNodeTable[j][4].Pos,SceneMan.SceneWrapsX).Magnitude;
										--Add to the table[1] the direction to move in to go to this node
										self.PDTable[PDT1Val][i][1] = self.PDTable[PDT1Val][i][1].."1";
										--Save this run in the instructionstring for the next run
										instructionstring = self.PDTable[PDT1Val][i][1];
										--Add to the table[2] the distance between these nodes
										self.PDTable[PDT1Val][i][2] = self.PDTable[PDT1Val][i][2]+dist;
										--Set the node we started this from as pncheck and node we moved to as ncheck
										pncheck = ncheck;
										ncheck = MovatorNodeTable[j][4];
										print ("All set to go down!");
									end
								end
							
							--We can't go down so:
							--If we can go left (i.e. we gave a node to the left of us)
							elseif MovatorNodeTable[j][5] ~= nil then
								 --If the node to the left isn't the one we came from
								if MovatorNodeTable[j][5].Sharpness ~= pncheck.Sharpness then
									--If we've hit our destination, flag that as true
									if ncheck.Sharpness == target.Sharpness then
										self.PDTable[PDT1Val][i][3] = true;
										print ("At destination from a hub");
									else
										--Find the shortest distance to this node, to get the most efficient final route
										local dist = SceneMan:ShortestDistance(ncheck.Pos,MovatorNodeTable[j][5].Pos,SceneMan.SceneWrapsX).Magnitude;
										--Add to the table[1] the direction to move in to go to this node
										self.PDTable[PDT1Val][i][1] = self.PDTable[PDT1Val][i][1].."2";
										--Save this run in the instructionstring for the next run
										instructionstring = self.PDTable[PDT1Val][i][1];
										--Add to the table[2] the distance between these nodes
										self.PDTable[PDT1Val][i][2] = self.PDTable[PDT1Val][i][2]+dist;
										--Set the node we started this from as pncheck and node we moved to as ncheck
										pncheck = ncheck;
										ncheck = MovatorNodeTable[j][5];
										print ("All set to go left!");
									end
								end
								
							--We can't go left so we're on the final choice now:
							--If we can go right (i.e. we have a node to the right of us)
							elseif MovatorNodeTable[j][6] ~= nil then
								--If the node to the right isn't the one we came from
								if MovatorNodeTable[j][6].Sharpness ~= pncheck.Sharpness then
									--If we've hit our destination, flag that as true
									if ncheck.Sharpness == target.Sharpness then
										self.PDTable[PDT1Val][i][3] = true;
										print ("At destination from a hub");
									else
										--Find the shortest distance to this node, to get the most efficient final route
										local dist = SceneMan:ShortestDistance(ncheck.Pos,MovatorNodeTable[j][6].Pos,SceneMan.SceneWrapsX).Magnitude;
										--Add to the table[1] the direction to move in to go to this node
										self.PDTable[PDT1Val][i][1] = self.PDTable[PDT1Val][i][1].."3";
										--Save this run in the instructionstring for the next run
										instructionstring = self.PDTable[PDT1Val][i][1];
										--Add to the table[2] the distance between these nodes
										self.PDTable[PDT1Val][i][2] = self.PDTable[PDT1Val][i][2]+dist;
										--Set the node we started this from as pncheck and node we moved to as ncheck
										pncheck = ncheck;
										ncheck = MovatorNodeTable[j][6];
										print ("All set to go right!");
									end
								end
							end
						--If we've reached a dead end and it's not just the starting node
						elseif MovatorNodeTable[j][2] == 1 and ncheck.Sharpness ~= start.Sharpness then
							--If we've reached the target, flag this run as a success. Huzzah!
							if ncheck.Sharpness == target.Sharpness then
								self.PDTable[PDT1Val][i][3] = true;
								print ("At destination from an end");
								break;
							end
							--Save this run in the instructionstring for the next run
							instructionstring = self.PDTable[PDT1Val][i][1];
							print ("Dead end, not there yet. New run!");
							break;
						end
					--------------------------------------------------------------------------	
					--Otherwise if we have instructions, read them then repeat the procedure--
					elseif instructionstring ~= nil then
						--Set the PDTable instruction string to be the current instruction string we have
						self.PDTable[self.PDT1Val][i][1] = instructionstring;
						local lastdir = string.sub(instructionstring, string.len(instructionstring));
						--if lastdir == "1" then
							--if 
							--if MovatorNodeTable[j][2] < 1 then
							
						
						--If we can go in more direction or we are at the start, i.e. not a dead end
						if MovatorNodeTable[j][2] > 1 or (MovatorNodeTable[j][2] == 1 and ncheck.Sharpness == start.Sharpness) then
							--If we can go up (i.e. we have a node above us)
							if MovatorNodeTable[j][3] ~= nil then
								--If the node above isn't the one we came from
								if MovatorNodeTable[j][3].Sharpness ~= pncheck.Sharpness then
									--If we've hit our destination, flag that as true
									if ncheck.Sharpness == target.Sharpness then
										self.PDTable[PDT1Val][i][3] = true;
										print ("At destination from a hub");
									else
										--Find the shortest distance to this node, to get the most efficient final route
										local dist = SceneMan:ShortestDistance(ncheck.Pos,MovatorNodeTable[j][3].Pos,SceneMan.SceneWrapsX).Magnitude;
										--Add to the table[1] the direction to move in to go to this node
										self.PDTable[PDT1Val][i][1] = self.PDTable[PDT1Val][i][1].."0";
										--Save this run in the instructionstring for the next run
										instructionstring = self.PDTable[PDT1Val][i][1];
										--Add to the table[2] the distance between these nodes
										self.PDTable[PDT1Val][i][2] = self.PDTable[PDT1Val][i][2]+dist;
										--Set the node we started this from as pncheck and node we moved to as ncheck
										pncheck = ncheck;
										ncheck = MovatorNodeTable[j][3];
										print ("All set to go up!");
									end
								end
								
							--We can't go up so:
							--If we can go down (i.e. we have a node below us)
							elseif MovatorNodeTable[j][4] ~= nil then
								--If the node below isn't the one we came from
								if MovatorNodeTable[j][4].Sharpness ~= pncheck.Sharpness then
									--If we've hit our destination, flag that as true
									if ncheck.Sharpness == target.Sharpness then
										self.PDTable[PDT1Val][i][3] = true;
										print ("At destination from a hub");
									else
										--Find the shortest distance to this node, to get the most efficient final route
										local dist = SceneMan:ShortestDistance(ncheck.Pos,MovatorNodeTable[j][4].Pos,SceneMan.SceneWrapsX).Magnitude;
										--Add to the table[1] the direction to move in to go to this node
										self.PDTable[PDT1Val][i][1] = self.PDTable[PDT1Val][i][1].."1";
										--Save this run in the instructionstring for the next run
										instructionstring = self.PDTable[PDT1Val][i][1];
										--Add to the table[2] the distance between these nodes
										self.PDTable[PDT1Val][i][2] = self.PDTable[PDT1Val][i][2]+dist;
										--Set the node we started this from as pncheck and node we moved to as ncheck
										pncheck = ncheck;
										ncheck = MovatorNodeTable[j][4];
										print ("All set to go down!");
									end
								end
							
							--We can't go down so:
							--If we can go left (i.e. we gave a node to the left of us)
							elseif MovatorNodeTable[j][5] ~= nil then
								 --If the node to the left isn't the one we came from
								if MovatorNodeTable[j][5].Sharpness ~= pncheck.Sharpness then
									--If we've hit our destination, flag that as true
									if ncheck.Sharpness == target.Sharpness then
										self.PDTable[PDT1Val][i][3] = true;
										print ("At destination from a hub");
									else
										--Find the shortest distance to this node, to get the most efficient final route
										local dist = SceneMan:ShortestDistance(ncheck.Pos,MovatorNodeTable[j][5].Pos,SceneMan.SceneWrapsX).Magnitude;
										--Add to the table[1] the direction to move in to go to this node
										self.PDTable[PDT1Val][i][1] = self.PDTable[PDT1Val][i][1].."2";
										--Save this run in the instructionstring for the next run
										instructionstring = self.PDTable[PDT1Val][i][1];
										--Add to the table[2] the distance between these nodes
										self.PDTable[PDT1Val][i][2] = self.PDTable[PDT1Val][i][2]+dist;
										--Set the node we started this from as pncheck and node we moved to as ncheck
										pncheck = ncheck;
										ncheck = MovatorNodeTable[j][5];
										print ("All set to go left!");
									end
								end
								
							--We can't go left so we're on the final choice now:
							--If we can go right (i.e. we have a node to the right of us)
							elseif MovatorNodeTable[j][6] ~= nil then
								--If the node to the right isn't the one we came from
								if MovatorNodeTable[j][6].Sharpness ~= pncheck.Sharpness then
									--If we've hit our destination, flag that as true
									if ncheck.Sharpness == target.Sharpness then
										self.PDTable[PDT1Val][i][3] = true;
										print ("At destination from a hub");
									else
										--Find the shortest distance to this node, to get the most efficient final route
										local dist = SceneMan:ShortestDistance(ncheck.Pos,MovatorNodeTable[j][6].Pos,SceneMan.SceneWrapsX).Magnitude;
										--Add to the table[1] the direction to move in to go to this node
										self.PDTable[PDT1Val][i][1] = self.PDTable[PDT1Val][i][1].."3";
										--Save this run in the instructionstring for the next run
										instructionstring = self.PDTable[PDT1Val][i][1];
										--Add to the table[2] the distance between these nodes
										self.PDTable[PDT1Val][i][2] = self.PDTable[PDT1Val][i][2]+dist;
										--Set the node we started this from as pncheck and node we moved to as ncheck
										pncheck = ncheck;
										ncheck = MovatorNodeTable[j][6];
										print ("All set to go right!");
									end
								end
							end
						--If we've reached a dead end and it's not just the starting node
						elseif MovatorNodeTable[j][2] == 1 and ncheck.Sharpness ~= start.Sharpness then
							--If we've reached the target, flag this run as a success. Huzzah!
							if ncheck.Sharpness == target.Sharpness then
								self.PDTable[PDT1Val][i][3] = true;
								print ("At destination from an end");
								break;
							end
							--Save this run in the instructionstring for the next run
							instructionstring = self.PDTable[PDT1Val][i][1];
							print ("Dead end, not there yet. New run!");
							break;
						end
						
					end
				end
			end
		end
		--Now do the run sorting stuff
		local failz = true;
		for i = 1, totpaths do
			print (self.PDTable[PDT1Val][i][1])
			if self.PDTable[PDT1Val][i][3] == true then
				failz = false;
				print ("OMG")
				print (self.PDTable[PDT1Val][i][1]);
			end
		end
		if failz == true then
			print ("FAILZ");
		end
	end
						
				--Runs will prefer up, then down, then left then right so:
				--If we can only go in one direction and that is backwards and we're not at our target:
				--end this run (break), copy it up to the first right (or second last if no rights) into a new string
				--Change that string so the last one (i.e. the one to change is changed so:
				--	up --> down, down --> left, left --> right, right --> remove one and repeat
				--Paste that changed string in as new directions and follow them
	
	return {"HI", "Hey"};
	--return self.PDTable[PDT1Val][i][1];
end
-----------------------------------------------------------------------------------------
-- Get The Actor's Directions
-----------------------------------------------------------------------------------------
function GetDirections(self, actor, directiontable)
	--Note, run for each actor, directiontable is the actor's individual table
	--Stuff for player controlled Actors here
	if actor:IsPlayerControlled() and CombinedMovatorArea:IsInside(actor.Pos) then

		--Change actor's lifetime to the necessary one based on what they pressed
		if (actor:GetController():IsState(Controller.PRESS_UP) or actor:GetController():IsState(Controller.HOLD_UP)) and not actor:GetController():IsState(Controller.PIE_MENU_ACTIVE) then
			actor.Lifetime = 1000000;
		elseif (actor:GetController():IsState(Controller.PRESS_DOWN) or actor:GetController():IsState(Controller.HOLD_DOWN)) and not actor:GetController():IsState(Controller.PIE_MENU_ACTIVE) then
			actor.Lifetime = 1000001;
		elseif (actor:GetController():IsState(Controller.PRESS_LEFT) or actor:GetController():IsState(Controller.HOLD_LEFT)) and not actor:GetController():IsState(Controller.PIE_MENU_ACTIVE) then
			actor.Lifetime = 1000002;
		elseif (actor:GetController():IsState(Controller.PRESS_RIGHT) or actor:GetController():IsState(Controller.HOLD_RIGHT)) and not actor:GetController():IsState(Controller.PIE_MENU_ACTIVE) then
			actor.Lifetime = 1000003;
		elseif actor:GetController():IsState(Controller.PIE_MENU_ACTIVE) and (actor:GetController():IsState(Controller.PRESS_UP) or actor:GetController():IsState(Controller.HOLD_UP)) then
			actor.Lifetime = 1000004;
		elseif actor:GetController():IsState(Controller.PIE_MENU_ACTIVE) and (actor:GetController():IsState(Controller.PRESS_DOWN) or actor:GetController():IsState(Controller.HOLD_DOWN)) then
			actor.Lifetime = 1000005;
		end
		--Reset the waypoint path and stuff to ensure there's no trouble. TODO: Playtest to make sure this is a good idea
		directiontable[1] = 0;

	--Stuff for ai controlled Actors here
	elseif not actor:IsPlayerControlled() and CombinedMovatorArea:IsInside(actor.Pos) and actor.AIMode == Actor.AIMODE_GOTO or actor.AIMode == Actor.AIMODE_BRAINHUNT then

		--Move the actor to the starting movator
		--We use variable 1 of the direction table as an indicator of whether to do this. Thus the first variable in that table is just a useless buffer, NONE.
		if directiontable[1] == 0 then
			--Find the nearest as the start
			local start = NearestMovator(self, actor);
			--Do the movements
			if actor.Pos.Y > start.Pos.Y + 5 then
				actor.Lifetime = 1000000; --Move up if below
			elseif actor.Pos.Y < start.Pos.Y - 5 then
				actor.Lifetime = 1000001; --Move down if above
			elseif actor.Pos.X > start.Pos.X + 5 then
				actor.Lifetime = 1000002; --Move left if right
			elseif actor.Pos.X < start.Pos.X - 5 then
				actor.Lifetime = 1000003; --Move right if left
			elseif actor.Pos.Y >= start.Pos.Y - 5 and actor.Pos.Y <= start.Pos.Y + 5 and actor.Pos.X >= start.Pos.X - 5 and actor.Pos.X <= start.Pos.X + 5 then
				actor.Lifetime = 1000004; --Hover if there
				directiontable[1] = -1; --Fill space
			end
			
		--Now that actor is at his start point, find his path
		elseif directiontable[1] == -1 then
			--Find the nearest as the start
			local start = NearestMovator(self, actor);
			--Find his directions
			directiontable[2] = FindPath(self, actor, directiontable, start);
			directiontable[1] = 1;
			actor.Age = 100;
			
		--Now that we have a path for the actor, control his movements and stuff
		--[[elseif directiontable[1] == 1 then
			if actor.Age > 100 then
				local near = NearestMovator(self, actor);
				--If the actor's close, center him before moving in the next direction
				if actor.Pos.Y >= near.Pos.Y - 5 and actor.Pos.Y <= near.Pos.Y + 5 and actor.Pos.X >= near.Pos.X - 5 and actor.Pos.X <= near.Pos.X + 5 then
					if actor.Pos.Y > near.Pos.Y + 1 then
						actor.Lifetime = 1000000; --Move up if below
					elseif actor.Pos.Y < near.Pos.Y - 1 then
						actor.Lifetime = 1000001; --Move down if above
					elseif actor.Pos.X > near.Pos.X + 1 then
						actor.Lifetime = 1000002; --Move left if right
					elseif actor.Pos.X < near.Pos.X - 1 then
						actor.Lifetime = 1000003; --Move right if left
					--If he's more or less centred
					elseif (actor.Pos - near.Pos).Magnitude <= 1 then
						--Set him to move in the right direction
						actor.Lifetime = tonumber(directiontable[2]:sub(1,1));
						--Edit his direction string
						directiontable[2] = directiontable[2]:sub(2);
						--Reset his age
						actor.Age = 0;
					end
				end
			end--]]
		end
	end
end
-----------------------------------------------------------------------------------------
-- Do The Movements
-----------------------------------------------------------------------------------------
function DoMovements(self, actor)

	--If the actor is slow enough, within our area and flagged to be movator affected then
	if actor.Vel.X <= self.Speed and actor.Vel.X >= -self.Speed and actor.Vel.Y <= self.Speed and actor.Vel.Y >= -self.Speed and CombinedMovatorArea:IsInside(actor.Pos) and actor.Lifetime >= 999999 and actor.Lifetime < 1000005 then
		--Slow down spinning
		if actor.AngularVel > self.Speed then
			actor.AngularVel = actor.AngularVel - self.Speed/4;
		elseif actor.AngularVel < -self.Speed then
			actor.AngularVel = actor.AngularVel + self.Speed/4;
		end

		--Find the centre for the actor
		--TODO: Make this based on the actor's height, etc.
		local centre;
		if actor.ClassName == "ACrab" then
			centre = 13;
		elseif actor.ClassName ~= "ACrab" then
			if actor:IsPlayerControlled() ~= true then
				centre = 9;
			elseif actor:IsPlayerControlled() == true then
				centre = 2;
			end
		end

		--Do actor centreing, rotation checks and other miscellanious behaviour
		--Only happens when rechecking closest node
		if self.ActorClosestCheckTimer:IsPastSimMS(100) then
			local cnode = NearestMovator(self , actor);
			
			--If the actor's not player controlled and not set to stay or fall
			if not actor:IsPlayerControlled() and actor.Lifetime ~= 1000004 and actor.Lifetime ~= 1000005 then

				--Turn Actor fully upright.
				if actor.AngularVel <= self.Speed and actor.AngularVel >= -self.Speed then
					if actor.RotAngle > .5 then
						actor.AngularVel = -1;
					elseif actor.RotAngle < -.5 then
						actor.AngularVel = 1;
					end
				end
				--Stop the Actor from moving freely
				actor:GetController():SetState(Controller.MOVE_LEFT , false);
				actor:GetController():SetState(Controller.MOVE_RIGHT , false);
				actor:GetController():SetState(Controller.MOVE_UP , false);
				actor:GetController():SetState(Controller.MOVE_DOWN , false);
				actor:GetController():SetState(Controller.BODY_JUMP , false);
				actor:GetController():SetState(Controller.BODY_JUMPSTART , false);
			end
			
			if actor.Lifetime == 1000000 or actor.Lifetime == 1000001 then
				--Set crouch state as false
				actor:GetController():SetState(Controller.BODY_CROUCH , false);
				--Do centreing
				if actor.Pos.X > cnode.Pos.X then
					actor.Vel.X = -self.Speed/4;
				elseif actor.Pos.X < cnode.Pos.X then
					actor.Vel.X = self.Speed/4;
				elseif actor.Pos.X >= cnode.Pos.X - 1 and actor.Pos.X <= cnodePos.X + 1 then
					actor.Vel.X = 0;
				end
			elseif actor.Lifetime == 1000002 or actor.Lifetime == 1000003 then
				--Set crouch state as true
				if actor.ClassName == "AHuman" then
					actor:GetController():SetState(Controller.BODY_CROUCH , true);
				end
				--Do centreing
				if actor.Pos.Y > cnode.Pos.Y + centre then
					actor.Vel.Y = -self.Speed/4;
				elseif actor.Pos.Y < cnode.Pos.Y + centre then
					actor.Vel.Y = self.Speed/4;
				elseif actor.Pos.Y >= cnode.Pos.Y + centre - 1 and actor.Pos.Y <= cnode.Pos.Y + centre + 1 then
					actor.Vel.Y = 0;
				end
			end
			self.ActorClosestCheckTimer:Reset();
		end

		--Read the Actor's lifetime and move it accordingly
		--In order, UP, DOWN, LEFT, RIGHT, STAY
		if actor.Lifetime == 1000000 then
			actor.Vel.Y = -self.Speed;
		elseif actor.Lifetime == 1000001 then
			actor.Vel.Y = self.Speed;
		elseif actor.Lifetime == 1000002 then
			actor.Vel.X = -self.Speed;
		elseif actor.Lifetime == 1000003 then
			actor.Vel.X = self.Speed;
		elseif actor.Lifetime == 1000004 then
			actor.Vel.X = 0;
			actor.Vel.Y = 0 - SceneMan.GlobalAcc.Magnitude*TimerMan.DeltaTimeSecs;
		end
		
	--Slow down actors in the area that are moving too fast
	elseif actor.Vel.X > self.Speed or actor.Vel.X < -self.Speed or actor.Vel.Y > self.Speed or actor.Vel.Y < -self.Speed and CombinedMovatorArea:IsInside(actor.Pos) and actor.Lifetime >= 999999 then
		if actor.Lifetime ~= 1000005 then
			actor.Vel.Y = actor.Vel.Y/1.5
			actor.Vel.X = actor.Vel.X/1.2
		end
	end

	--TODO: Make a stuck check. If stuck, cast rays to see where obstacle is, move in opposite direction
end
-----------------------------------------------------------------------------------------
-- Destroy
-----------------------------------------------------------------------------------------
function Destroy(self)
	CombinedMovatorArea = nil;
	MovatorNodeTable = nil;
	MovatorNodeRecheckTimer = nil;
	MovatorNodesPowered = false;
	CheckAllMovators = false;
end