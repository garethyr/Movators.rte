--The global movator controller and power source
--[[
TODO:
Power, etc. A long time in the future
--]]

--Include and run all the global movator stuff
dofile("Movator.rte/Scripts/GlobalMovatorFunctions.lua");
dofile("Movator.rte/Scripts/GlobalUIFunctions.lua");

-----------------------------------------------------------------------------------------
-- Pie Menu
-----------------------------------------------------------------------------------------
function CommandDisplayMovatorInfo(self)
	if self:GetNumberValue("displayingInfo") == 0 then
		self:SetNumberValue("displayingInfo", 1);
	else
		self:RemoveNumberValue("displayingInfo");
	end
end
function CommandModifyMovatorSpeed(self)
	self:RemoveNumberValue("modifyMassLimit");
	if self:GetNumberValue("modifySpeed") == 0 then
		self:SetNumberValue("modifySpeed", 1);
	else
		self:RemoveNumberValue("modifySpeed");
	end
end
function CommandModifyMovatorMassLimit(self)
	self:RemoveNumberValue("modifySpeed");
	if self:GetNumberValue("modifyMassLimit") == 0 then
		self:SetNumberValue("modifyMassLimit", 1);
	else
		self:RemoveNumberValue("modifyMassLimit");
	end
end
function CommandSwapMovatorTeamActorAcceptance(self)
	self:SetNumberValue("swapTeamActorAcceptance", 1);
end
function CommandSwapMovatorCraftAcceptance(self)
	self:SetNumberValue("swapCraftAcceptance", 1);
end
function CommandModifyMovatorEffectsType(self)
	self:SetNumberValue("modifyMovatorEffectsType", 1);
end
function CommandModifyMovatorEffectsSize(self)
	self:SetNumberValue("modifyMovatorEffectsSize", 1);
end

-----------------------------------------------------------------------------------------
-- Create
-----------------------------------------------------------------------------------------
function Create(self)
	--Before we do anything else, check for any other movator controllers on this team and if they exist, delete them and refund the player their cost
	for a in MovableMan.Actors do
		if a.PresetName == "Movator Controller" and a.Team == self.Team and a.ID ~= self.ID then
			ActivityMan:GetActivity():SetTeamFunds(ActivityMan:GetActivity():GetTeamFunds(self.Team) + a:GetGoldValue(0,0), self.Team);
			a.ToDelete = true;
		end
	end

	--Set the movator variables for this team so there are no possible issues if this is added before any movators
	ResetMovatorVariables(self.Team)
	--Global variable for reading if nodes have power TODO make this an actual power system
	MovatorPowerValues[self.Team+3] = 100;
	
	--Make sure this handles movators already added before it
	RecheckAllMovators(self.Team)
	
	--Coroutines for 1. Creating the path table for this team, 2. Checking for obstructions between movators for this team
	self.PathRoutine = coroutine.create(AddAllPaths);
	self.ObstructionRoutine = coroutine.create(CheckAllObstructions);
	
	--HashTable for actors affected by the movators along with a length value
	--["act"] - the actor, ["dir] - their movement direction, ["prevdir"] - their previous movement direction, ["cnode"] - the node they should centre to, changed on direction change
	--["stage"] - their movement stage, ["s"] - their start node, ["n"] - their next node in path, ["d"] - their destination node in path,
	--["t"] - [1] - their closest waypoint, [2] -nil if it's scene or the actor if it's MO, [3]- a table of their remaining waypoints to be added back later or nil if they have an MO waypoint
	self.MovatorAffectedActors = {};
	self.MovatorAffectedActors.length = 0;
	
	--Boolean for whether or not this controller should be displaying its UI
	self.DisplayingUI = false;
	--Table for handling movator effects
	self.EffectsTable = {
		directionsToUse = {"a", "l"},
		displayTypes = {
			line = {
				generalData = {
					displayType = "line",
					nodeArrowDistanceFromEdge = 5,
					halfLineCapWidth = 3,
				},
				sizes = {
					{
						lineCapObject = CreateMOSParticle("Movator LineCap", "Movator.rte"),
						lineInfoTable = {{offset = 0.5, colour = 179}, {offset = 1.5, colour = 253}, {offset = 2.5, colour = 179}}
					},
					{
						lineCapObject = CreateMOSParticle("Movator LineCap", "Movator.rte"),
						lineInfoTable = {{offset = 0.5, colour = 179}, {offset = 1.5, colour = 179}, {offset = 2.5, colour = 253}, {offset = 3.5, colour = 179}}
					},
					{
						lineCapObject = CreateMOSParticle("Movator LineCap", "Movator.rte"),
						lineInfoTable = {{offset = 0.5, colour = 179, lengthModifier = 1}, {offset = 1.5, colour = 179}, {offset = 2.5, colour = 179, lengthModifier = -1}, {offset = 3.5, colour = 253}, {offset = 4.5,  colour = 179}}
					}
				}
			},
			chevron = {
				generalData = {
					displayType = "object",
					minimumNumberOfSpacesNeededForDrawingObjectEffects = 3,
					speedTimer = Timer()
				},
				sizes = {
					{
						object = CreateMOSParticle("Movator Chevron Small", "Movator.rte"),
						objectSize = 16,
						speed = 30,
						coolDownInterval = 1000,
						minFrame = 0,
						maxFrame = 7,
						previousObjectTriggerFrame = 1,
						nodeEntries = {}
					},
					{
						object = CreateMOSParticle("Movator Chevron Medium", "Movator.rte"),
						objectSize = 32,
						speed = 60,
						coolDownInterval = 2000,
						minFrame = 0,
						maxFrame = 7,
						previousObjectTriggerFrame = 1,
						nodeEntries = {}
					},
					{
						object = CreateMOSParticle("Movator Chevron Large", "Movator.rte"),
						objectSize = 48,
						speed = 80,
						coolDownInterval = 3000,
						minFrame = 0,
						maxFrame = 7,
						previousObjectTriggerFrame = 1,
						nodeEntries = {}
					}
				}
			},
			chevron_narrow = {
				generalData = {
					displayType = "object",
					minimumNumberOfSpacesNeededForDrawingObjectEffects = 3,
					speedTimer = Timer()
				},
				sizes = {
					{
						object = CreateMOSParticle("Movator Chevron Small", "Movator.rte"),
						objectSize = 5.33,
						speed = 5,
						coolDownInterval = 1000,
						minFrame = 0,
						maxFrame = 7,
						previousObjectTriggerFrame = 1,
						nodeEntries = {}
					},
					{
						object = CreateMOSParticle("Movator Chevron Medium", "Movator.rte"),
						objectSize = 10.67,
						speed = 30,
						coolDownInterval = 2000,
						minFrame = 0,
						maxFrame = 7,
						previousObjectTriggerFrame = 1,
						nodeEntries = {}
					},
					{
						object = CreateMOSParticle("Movator Chevron Large", "Movator.rte"),
						objectSize = 16,
						speed = 55,
						coolDownInterval = 3000,
						minFrame = 0,
						maxFrame = 7,
						previousObjectTriggerFrame = 1,
						nodeEntries = {}
					}
				}
			}
		},
		selectedType = "chevron",
		selectedSize = 1
	}
	
	--Boolean for whether or not this controller will move actors of any team or only its own
	self.AcceptAllActors = false;
	
	--Boolean for whether or not this controller will move crafts as well as normal actors
	self.AcceptCrafts = false;
	
	--The range of distance to look for actors when trying to find an actor target for a movator passenger - greater range means it's easier for the player to get working if the target is moving quickly, but actors follow less closely
	self.ActorTargetRange = 48;
	
	--Set the speed that the actors move at and the speed above which to slow down actors that are using the movator
	self.Speed = 8;
	self.MaxSpeed = 16;
	self.MinSpeed = 4;
	
	--Set the mass limit this controller will accept, i.e. no actors heavier than this will work
	self.MassLimit = 300;
	self.MaxMassLimit = 1000;
	self.MinMassLimit = 100;
	
	--Set the Y offset this controller will centre actors by, i.e. actor.Pos.Y = cnode.Pos.Y + actor.Height/self.CentreOffset
	self.CentreOffset = 20;
	
	--Variables for the lifetimes used for actors, cur gets incremented each time a new actor appears
	self.BaseLifetime = 1000000000;
	self.CurLifetime = self.BaseLifetime;
	
	--Variable for if this team's movator boxes have been added
	self.AllBoxesAdded = false;
	--Variable for if this team's shortest paths have been added
	self.AllPathsAdded = false;
	
	--Node specific timers and timer related variables
	self.MovatorCheckTimer = Timer();
	self.MovatorCheckInterval = 5000 + math.random(0, 2500);
	self.MovatorChecksNeeded = false; --Track whether or not we need to recheck all the movator boxes and paths due to obstructions
	self.NodeGenerationSafetyTimer = Timer();
	self.NodeGenerationSafetyInterval = 1500;
	
	self.MovatorCheckTimer:Reset();
	self.NodeGenerationSafetyTimer:Reset();

	--Actor specific timers
	self.ActorCheckLagTimer = Timer();
	self.ActorMovementLagTimer = Timer();
	
	self.ActorCheckLagTimer:Reset();
	self.ActorMovementLagTimer:Reset();
	
	
	--debuggy stuff
	self.displayall = false;
	self.FullyReset = false;
	self.MyShowPathTimer = Timer();
	self.MyShowPath = false;
	self.MyShowPathRoutine = coroutine.create(ShowMyPath);
	self.MyShowPathObjectives = {};
	self.Mouse = self.Pos;
	self.Click1 = nil; self.Click2 = nil;
	self.ShowMouse = false;
end
-----------------------------------------------------------------------------------------
-- Update
-----------------------------------------------------------------------------------------
function Update(self)
	HandlePieButtons(self);
	
	--Input based testing
	if true then
	--Reset
	if UInputMan:KeyPressed(3) then
		ToGameActivity(ActivityMan:GetActivity()):ClearObjectivePoints();
		self.FullyReset = false;
		
		self.MovatorCheckInterval = 5000 + math.random(0, 2500);
		self.ObstructionRoutine = coroutine.create(CheckAllObstructions);
		
		self.CurLifetime = self.BaseLifetime;
		for k, v in pairs(self.MovatorAffectedActors) do 
			if type (k) ~= "string" then
				v.act.Lifetime = 0;
			end
		end
		self.MovatorAffectedActors = {};
		
		PresetMan:ReloadAllScripts();
		print ("All scripts reloaded");
		self:ReloadScripts();
		print ("Controller scripts reloaded");
	end
	if UInputMan:KeyPressed(26) then
		if self.FullyReset == false then
			ResetMovatorVariables(self.Team);
			RecheckAllMovators(self.Team)
			print("Part 1: All movators readded for Team "..tostring(self.Team));
			self.FullyReset = true;
		elseif self.FullyReset == true then
			AddAllBoxes(self.Team);
			self.AllPathsAdded = false;
			self.PathRoutine = coroutine.create(AddAllPaths);
			print("Part 2: All boxes readded for Team "..tostring(self.Team));
			self.FullyReset = false;
		end
	end
	--Display
	if UInputMan:KeyPressed(22) then
		local count = 0;
		for k, v in pairs(MovatorNodeTable[self.Team+3]) do
			if (type(k) ~= "string") then
				print("Tot - "..tostring(v[1]).."  Size - "..tostring(v[2]).."  A - "..tostring(v.a[2]).."  B - "..tostring(v.b[2]).."  L - "..tostring(v.l[2]).."  R - "..tostring(v.r[2]).." Boxes - "..type(v.box):sub(1, 3)..type(v.sbox):sub(1, 3).." Areas - "..type(v.area.above):sub(1, 3)..type(v.area.left):sub(1, 3).." Pos - "..tostring(k.Pos));
				count = count+1;
			end
		end
		print ("Number of nodes in node table: "..tostring(count));
	end
	if UInputMan:KeyPressed(2) then
		for k, v in pairs(self.MovatorAffectedActors) do
			if type (k) ~= "string" then
				print("LifeT: "..tostring(k).."  Act: "..tostring(v.act).."  Dir: "..tostring(v.dir).."  PDir: "..tostring(v.prevdir).."  Stage: "..tostring(v.stage).."  Start: "..tostring(v.s~=nil).."  Next: "..tostring(v.n~=nil).."  Dest: "..tostring(v.d~=nil).."Target: "..tostring(v.t[1]));
				if MovableMan:IsActor(v.act) then
					print(v.act.Pos);
				end
			end
		end
	end
	if UInputMan:KeyPressed(14) then
		local n = 0;
		for k, v in pairs(MovatorPathTable[self.Team+3]) do
			n = n+1;
			local z = 0;
			local str = ""
			for m, n in pairs(v) do
				str = str.."{"..tostring(n[1])..","..tostring(n[2])..","..tostring(n[3]):sub(1, 1).."}, ";
				z = z+1;
			end
			print(tostring(z).." Nodes: "..tostring(str));
		end
		print("Number of nodes in shortest path table: "..tostring(n));
	end
	--Functional
	if UInputMan:KeyPressed(24) then
		self.displayall = not self.displayall;
		ToGameActivity(ActivityMan:GetActivity()):ClearObjectivePoints();
		local bool = coroutine.resume(self.PathRoutine, self.Team);
		while bool == true do
			bool = coroutine.resume(self.PathRoutine, self.Team);
		end
		print ("Display Movator path additions == "..tostring(self.displayall));
	end
	if self.displayall == true then
		ToGameActivity(ActivityMan:GetActivity()):ClearObjectivePoints();
		for k, v in pairs(MovatorNodeTable[self.Team+3]) do
			if (type(k) ~= "string") then
				ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint(tostring(k.Pos), Vector(k.Pos.X, k.Pos.Y), self.Team, GameActivity.ARROWDOWN);
			end
		end
	end
	--Mouse based
	if UInputMan:KeyPressed(13) then
		self.ShowMouse = not self.ShowMouse;
	end
	if self.ShowMouse == true then
		ShowMouse(self);
	end
	if type(self.MyShowPath) ~= "boolean" then
		local bool = not self.MyShowPathTimer:IsPastSimMS(100);
		if self.MyShowPathTimer:IsPastSimMS(100) then
			bool, self.MyShowPathObjectives = coroutine.resume(self.MyShowPathRoutine, self.Team, self.MyShowPath);
			self.MyShowPathTimer:Reset();
		end
		--Reset it and recreate the coroutine if the it's done
		if type(self.MyShowPathObjectives) == "string" then
			self.MyShowPath = false;
			self.MyShowPathObjectives = {};
			self.MyShowPathRoutine = coroutine.create(ShowMyPath);
		end
		--Show the objective points
		if type(self.MyShowPathObjectives) ~= "string" then
			for k, v in ipairs(self.MyShowPathObjectives) do
				ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint(v[1], v[2], v[3], v[4]);
			end
		end
	end
	end

	--Reset the node generation safety timer if all nodes haven't been safely generated
	if MovatorAllNodesGenerated == false and type(self.NodeGenerationSafetyTimer) ~= "nil" then
		self.NodeGenerationSafetyTimer:Reset();
	end
	
	--If we're running the activity, do various checks
	if ActivityMan:GetActivity().ActivityState == Activity.RUNNING then
		--Make sure all nodes are fully generated before doing any of these complex checks so there are no screwups in making their boxes
		if self.NodeGenerationSafetyTimer ~= nil and self.NodeGenerationSafetyTimer:IsPastSimMS(self.NodeGenerationSafetyInterval) then
			self.NodeGenerationSafetyInterval = 50;
			--Add all movator boxes and areas for this team if they haven't already been added
			if self.AllBoxesAdded == false then
				self.AllBoxesAdded = AddAllBoxes(self.Team);
			end
			--Add all movator paths for this team if they haven't already been added
			if self.AllPathsAdded == false then
				self.AllPathsAdded = not coroutine.resume(self.PathRoutine, self.Team);
			--Kill the timer once all paths have been added
			else
				self.NodeGenerationSafetyTimer = nil;
				self.NodeGenerationSafetyInterval = nil;
			end
		end
		
		--Check for any obstructions between movator nodes and act accordingly
		if self.MovatorCheckTimer:IsPastSimMS(self.MovatorCheckInterval) then
			local bool, changesneeded = coroutine.resume(self.ObstructionRoutine, self.Team, changesneeded); --TODO changesneeded probably not needed here
			if type(changesneeded) == "boolean" then
				self.MovatorChecksNeeded = changesneeded;
			end
			self.MovatorCheckInterval = 50;
			self.MovatorCheckTimer:Reset();
			if bool == false then
				self.MovatorCheckInterval = 5000 + math.random(0, 2500);
				self.ObstructionRoutine = coroutine.create(CheckAllObstructions);
				
				--If we've found obstructions, set variables cause we have to readd all boxes and paths unfortunately
				if self.MovatorChecksNeeded == true then
					print("Set flags to reset all boxes and paths for team "..self.Team);
					self.NodeGenerationSafetyTimer = Timer();
					self.NodeGenerationSafetyInterval = 1;
					self.AllBoxesAdded = false;
					self.AllPathsAdded = false;
					self.PathRoutine = coroutine.create(AddAllPaths);
				end
			end
		end
	
		--Check for actors in the Movators that aren't already in the table and add them to it
		if self.ActorCheckLagTimer:IsPastSimMS(100) then
			for actor in MovableMan.Actors do
				if MovableMan:IsActor(actor) then
					if CombinedMovatorArea[self.Team+3]:IsInside(actor.Pos) and actor.Lifetime < self.BaseLifetime  and (actor.Team == self.Team or self.AcceptAllActors) and actor.PinStrength == 0 and actor.Mass < self.MassLimit and (actor.ClassName == "AHuman" or actor.ClassName == "ACrab" or (self.AcceptCrafts and actor.ClassName == "ACraft" or actor.ClassName == "ACRocket" or actor.ClassName == "ACDropShip")) then
						actor.Lifetime = self.CurLifetime;
						self.CurLifetime = self.CurLifetime + 1;
						self.MovatorAffectedActors[actor.Lifetime] = {act = actor, dir = -1, prevdir = -2, cnode = 0, stage = 0, s = 0, n = 0, e = 0, t = {nil, nil, {}}};
						self.MovatorAffectedActors.length = self.MovatorAffectedActors.length + 1;
					end
				end
			end
			self.ActorCheckLagTimer:Reset();
		end
		
		if self.ActorMovementLagTimer:IsPastSimMS(15) then
			for k, v in pairs(self.MovatorAffectedActors) do
				if type (k) ~= "string" then
					--Remove the actor if it's dead and don't try to do anything with it
					if not MovableMan:IsActor(v.act) then
						self.MovatorAffectedActors[k] = nil;
					else
						--Removes the actors from the table if they're not in the Movator Area
						if not CombinedMovatorArea[self.Team+3]:IsInside(v.act.Pos) then
							v.act.Lifetime = 0;
							self.MovatorAffectedActors[k] = nil;
							self.MovatorAffectedActors.length = self.MovatorAffectedActors.length - 1;
						--Performs all the actions
						else
							--Pick the right direction to move in for players and ai
							GetDirections(self, v.act, v.dir, v.stage, v.s, v.n, v.d, v.t);
							--Do the actual movements
							DoMovements(self , v.act, v.dir, v.prevdir, v.cnode);
						end
					end
				end
			end
			self.ActorMovementLagTimer:Reset();
		end
		DoEffects(self);
	end
	
	--Now that everything else is done, handle UI
	if (self.DisplayingUI) then
		self.Frame = 1;
		DoUI(self);
	else
		self.Frame = 0;
	end
end

-----------------------------------------------------------------------------------------
-- Look for values set by Pie Button presses and handle them accordingly
-----------------------------------------------------------------------------------------
function HandlePieButtons(self)
	if self:GetNumberValue("displayingInfo") > 0 then
		self.DisplayingUI = true;
	else
		self.DisplayingUI = false;
	end
	
	if self:GetNumberValue("modifySpeed") > 0 then
		if self:GetController():IsMouseControlled() == true then
			if self:GetController():IsState(Controller.SCROLL_UP) then
				self.Speed = math.min(self.Speed + 1, self.MaxSpeed);
			elseif self:GetController():IsState(Controller.SCROLL_DOWN) then
				self.Speed = math.max(self.Speed - 1, self.MinSpeed);
			end
		else
			if self:GetController():IsState(Controller.HOLD_UP) then
				self.Speed = math.min(self.Speed + 1, self.MaxSpeed);
			elseif self:GetController():IsState(Controller.HOLD_DOWN) then
				self.Speed = math.max(self.Speed - 1, self.MinSpeed);
			end
		end
	end
	if self:GetNumberValue("modifyMassLimit") > 0 then
		if self:GetController():IsMouseControlled() == true then
			if self:GetController():IsState(Controller.SCROLL_UP) then
				self.MassLimit = math.min(self.MassLimit + 25, self.MaxMassLimit);
			elseif self:GetController():IsState(Controller.SCROLL_DOWN) then
				self.MassLimit = math.max(self.MassLimit - 25, self.MinMassLimit);
			end
		else
			if self:GetController():IsState(Controller.HOLD_UP) then
				self.MassLimit = math.min(self.MassLimit + 25, self.MaxMassLimit);
			elseif self:GetController():IsState(Controller.HOLD_DOWN) then
				self.MassLimit = math.max(self.MassLimit - 25, self.MinMassLimit);
			end
		end
	end
	
	if self:GetNumberValue("swapTeamActorAcceptance") > 0 then
		self.AcceptAllActors = not self.AcceptAllActors;
		self:RemoveNumberValue("swapTeamActorAcceptance");
	end
	if self:GetNumberValue("swapCraftAcceptance") > 0 then
		self.AcceptCrafts = not self.AcceptCrafts;
		self:RemoveNumberValue("swapCraftAcceptance");
	end
	
	if self:GetNumberValue("modifyMovatorEffectsType") > 0 then
		CleanupCurrentMovatorObjectEffectsTableIfPossible(self);
		local displayTypes = {""};
		for k, _ in pairs(self.EffectsTable.displayTypes) do
			displayTypes[#displayTypes+1] = k;
		end
		
		for i, v in ipairs(displayTypes) do
			if (v == self.EffectsTable.selectedType) then
				self.EffectsTable.selectedType = displayTypes[((i % #displayTypes) + 1)];
				break;
			end
		end
		self:RemoveNumberValue("modifyMovatorEffectsType");
	end
	if self:GetNumberValue("modifyMovatorEffectsSize") > 0 then
		CleanupCurrentMovatorObjectEffectsTableIfPossible(self);
		local maxSize = 3;
		self.EffectsTable.selectedSize = (self.EffectsTable.selectedSize % maxSize) + 1;
		self:RemoveNumberValue("modifyMovatorEffectsSize");
	end
end

-----------------------------------------------------------------------------------------
-- UI for players to let them manage movator options
-----------------------------------------------------------------------------------------
function DoUI(self)
	local formattedEffectsNameTable = {
		displayTypes = {[""] = "None", line = "Line", chevron = "Pulse", chevron_narrow = "Tight Pulse"},
		sizes = {"Small", "Medium", "Large"}
	}
	local textDataTable = {
		"Controlled Movators: "..tostring(MovatorNodeTable[self.Team+3].length),
		"Number of Affected Actors: "..tostring(self.MovatorAffectedActors.length),
		"Movator Accepts All Teams: "..tostring(self.AcceptAllActors),
		"Movator Accepts Crafts: "..tostring(self.AcceptCrafts),
		"Movator Speed: "..tostring(self.Speed),
		"Movator Mass Limit: "..tostring(self.MassLimit),
		"Selected Effects Type: "..formattedEffectsNameTable.displayTypes[self.EffectsTable.selectedType]
	}
	if (self.EffectsTable.selectedType ~= "") then
		textDataTable[#textDataTable + 1] = "Selected Effects Size: "..formattedEffectsNameTable.sizes[self.EffectsTable.selectedSize];
	end
	
	if (self:GetNumberValue("modifySpeed") > 0) then
		table.insert(textDataTable, 1, "-----------------------");
		table.insert(textDataTable, 1, "--MODIFYING MOVATOR SPEED--");
		table.insert(textDataTable, 1, "-----------------------");
	elseif (self:GetNumberValue("modifyMassLimit") > 0) then
		table.insert(textDataTable, 1, "--------------------------");
		table.insert(textDataTable, 1, "--MODIFYING MOVATOR MASS LIMIT--");
		table.insert(textDataTable, 1, "--------------------------");
	end
	local maxSizeBox = Vector(self.Pos.X, self.Pos.Y);--Box(Vector(self.Pos.X - 120, self.Pos.Y - 72), Vector(self.Pos.X + 120, self.Pos.Y + 72));
	local config = {useSmallText = false, boxBGColour = 179, boxOutlineWidth = 1, boxOutlineColour = 254};
	
	DrawTextBox(textDataTable, maxSizeBox, config);
end

-----------------------------------------------------------------------------------------
-- Effects for connections between movator nodes
-----------------------------------------------------------------------------------------
function DoEffects(self)
	if (self.EffectsTable.selectedType == "") then
		return;
	end
	
	local selectedSizeTableEntry = self.EffectsTable.displayTypes[self.EffectsTable.selectedType].sizes[self.EffectsTable.selectedSize];
	local generalDataTable = self.EffectsTable.displayTypes[self.EffectsTable.selectedType].generalData;
	if (generalDataTable.displayType == "line") then
		DrawMovatorConnectionLineEffects(self, selectedSizeTableEntry, generalDataTable);
	else
		DrawMovatorConnectionObjectEffects(self, selectedSizeTableEntry, generalDataTable);
	end
end

-----------------------------------------------------------------------------------------
-- Return whether or not effects should be drawn between the two movator nodes
-----------------------------------------------------------------------------------------
function ShouldDrawEffects(self, startNodeData, endNodeData, direction, selectedSizeTableEntry, generalDataTable)
	local nodeInDirection = startNodeData[direction][1];
	if (type(nodeInDirection) ~= "nil") then
		local minDistanceToShowEffects = startNodeData[2] + endNodeData[2];
		if (generalDataTable.displayType == "object") then
			minDistanceToShowEffects = minDistanceToShowEffects + selectedSizeTableEntry.objectSize * generalDataTable.minimumNumberOfSpacesNeededForDrawingObjectEffects;
		end
		if (startNodeData[direction][2] >= minDistanceToShowEffects) then
			return true;
		end
	end
	return false;
end

-----------------------------------------------------------------------------------------
-- Determine positions for and draw movator object effects based on what's selected
-----------------------------------------------------------------------------------------
function DrawMovatorConnectionObjectEffects(self, selectedSizeTableEntry, generalDataTable)
	if (generalDataTable.speedTimer:IsPastSimMS(selectedSizeTableEntry.speed)) then
		for startNode, startNodeData in pairs(MovatorNodeTable[self.Team+3]) do
			if (type(startNode) ~= "string") then
				for _, direction in ipairs(self.EffectsTable.directionsToUse) do
					local endNode = startNodeData[direction][1];
					local endNodeData = MovatorNodeTable[self.Team+3][endNode];
					if (ShouldDrawEffects(self, startNodeData, endNodeData, direction, selectedSizeTableEntry, generalDataTable)) then
						DoMovatorConnectionObjectEffectsSetup(selectedSizeTableEntry, startNode, startNodeData, endNode, endNodeData, direction);
						DoMovatorConnectionObjectEffectsActions(selectedSizeTableEntry, generalDataTable, startNode, direction);
					end
				end
			end
		end
		generalDataTable.speedTimer:Reset();
	end
	DisplayMovatorConnectionObjectEffects(self, selectedSizeTableEntry);
end

-----------------------------------------------------------------------------------------
-- Setup movator object effects based on what's selected
-----------------------------------------------------------------------------------------
function DoMovatorConnectionObjectEffectsSetup(selectedSizeTableEntry, startNode, startNodeData, endNode, endNodeData, direction)
	if (type(selectedSizeTableEntry.nodeEntries[startNode]) == "nil") then
		selectedSizeTableEntry.nodeEntries[startNode] = {};
	end
	--Set or reset the object values for this node and direction
	local selectedNodeEntry = selectedSizeTableEntry.nodeEntries[startNode];
	if (type(selectedNodeEntry[direction]) == "nil" or selectedNodeEntry[direction].endNode ~= endNode) then
		selectedNodeEntry[direction] = {
			coolDownTimer = Timer(),
			isGoingBackwards = false,
			endNode = endNode,
			objectLocations = {}
		};
		
		local maxObjects, halfRemainderDistance = math.modf(startNodeData[direction][2]/selectedSizeTableEntry.objectSize);
		halfRemainderDistance = halfRemainderDistance * selectedSizeTableEntry.objectSize * 0.5;
		
		local startOffset = {a = Vector(0, -(selectedSizeTableEntry.objectSize * 0.5 + startNodeData[2] * 0.5 + halfRemainderDistance)), l = Vector(-(selectedSizeTableEntry.objectSize * 0.5 + startNodeData[2] * 0.5 + halfRemainderDistance), 0)};
		local generalOffset = {a = Vector(0, -selectedSizeTableEntry.objectSize), l = Vector(-selectedSizeTableEntry.objectSize, 0)};
		local endOffset = {a = Vector(0, selectedSizeTableEntry.objectSize * 0.5 + endNodeData[2] * 0.5 + halfRemainderDistance), l = Vector(selectedSizeTableEntry.objectSize * 0.5 + endNodeData[2] * 0.5 + halfRemainderDistance, 0)};
		
		for i = 1, maxObjects do
			local position = Vector(0,0);
			if (i == 1) then
				position = startNode.Pos + startOffset[direction];
			else
				position = selectedNodeEntry[direction].objectLocations[i-1].position + generalOffset[direction];
			end
			if (MovatorCheckWrapping) then
				if (position.X < 0) then
					position.X = position.X + SceneMan.Scene.Width;
				end
				if (position.Y < 0) then
					position.Y = position.Y + SceneMan.Scene.Height;
				end
			end
			local accountForSeneWrapping = (startNode.Pos.X <= endNode.Pos.X and startNode.Pos.Y <= endNode.Pos.Y) and Vector(SceneMan.Scene.Width, SceneMan.Scene.Height) or Vector(0, 0);
			if (direction == "a" and (position.Y + accountForSeneWrapping.Y) < (endNode.Pos.Y + endOffset[direction].Y) or (position.X + accountForSeneWrapping.X) < (endNode.Pos.X + endOffset[direction].X)) then
				break;
			end
			selectedNodeEntry[direction].objectLocations[i] = {position = position, frame = selectedSizeTableEntry.minFrame - 1};
		end
	end
end

-----------------------------------------------------------------------------------------
-- Update frames and positions for movator object effects based on what's selected
-----------------------------------------------------------------------------------------
function DoMovatorConnectionObjectEffectsActions(selectedSizeTableEntry, generalDataTable, startNode, direction)
	local selectedNodeAndDirectionEntry = selectedSizeTableEntry.nodeEntries[startNode][direction];
	if (selectedNodeAndDirectionEntry.coolDownTimer:IsPastSimMS(selectedSizeTableEntry.coolDownInterval)) then
		local indices = {1, #selectedNodeAndDirectionEntry.objectLocations};
		local startIndex = selectedNodeAndDirectionEntry.isGoingBackwards and indices[2] or indices[1];
		local endIndex = selectedNodeAndDirectionEntry.isGoingBackwards and indices[1] or indices[2];
		local i = startIndex;
		repeat
			local currentObjectLocation = selectedNodeAndDirectionEntry.objectLocations[i];
			if ((i == startIndex or currentObjectLocation.frame >= selectedSizeTableEntry.minFrame) and currentObjectLocation.frame <= selectedSizeTableEntry.maxFrame) then
				if (i ~= startIndex and i ~= endIndex and currentObjectLocation.frame == selectedSizeTableEntry.maxFrame) then
					currentObjectLocation.frame = selectedSizeTableEntry.minFrame - 1;
				else
					currentObjectLocation.frame = currentObjectLocation.frame + 1;
				end
			elseif (i ~= startIndex and currentObjectLocation.frame < selectedSizeTableEntry.minFrame) then
				local previousIndex = selectedNodeAndDirectionEntry.isGoingBackwards and i+1 or i-1;
				local previousObjectLocation = selectedNodeAndDirectionEntry.objectLocations[previousIndex];
				if (previousObjectLocation.frame == selectedSizeTableEntry.previousObjectTriggerFrame) then
					currentObjectLocation.frame = selectedSizeTableEntry.minFrame;
				end
			end
			i = i + (selectedNodeAndDirectionEntry.isGoingBackwards and -1 or 1);
		until (i == endIndex + (selectedNodeAndDirectionEntry.isGoingBackwards and -1 or 1)); --Need to have +/- 1 here because it ends as soon as the condition is satisfied
		
		if (selectedNodeAndDirectionEntry.objectLocations[endIndex].frame > selectedSizeTableEntry.maxFrame) then
			selectedNodeAndDirectionEntry.isGoingBackwards = not selectedNodeAndDirectionEntry.isGoingBackwards;
			selectedNodeAndDirectionEntry.objectLocations[startIndex].frame = selectedSizeTableEntry.minFrame - 1;
			selectedNodeAndDirectionEntry.objectLocations[endIndex].frame = selectedSizeTableEntry.minFrame - 1;
			selectedNodeAndDirectionEntry.coolDownTimer:Reset();
			return;
		end
	end
end

-----------------------------------------------------------------------------------------
-- Draw movator object connection effects based on what's selected
-----------------------------------------------------------------------------------------
function DisplayMovatorConnectionObjectEffects(self, selectedSizeTableEntry)
	for startNode, startNodeData in pairs(MovatorNodeTable[self.Team+3]) do
		if (type(startNode) ~= "string" and type(selectedSizeTableEntry.nodeEntries[startNode]) ~= "nil") then
			for _, direction in ipairs(self.EffectsTable.directionsToUse) do
				local selectedNodeAndDirectionEntry = selectedSizeTableEntry.nodeEntries[startNode][direction];
				if (type(selectedNodeAndDirectionEntry) ~= "nil") then
					local rotAngles = {a = {[true] = math.rad(270), [false] = math.rad(90)}, l = {[true] = 0, [false] = math.rad(180)}};
					for _, objectLocation in ipairs(selectedNodeAndDirectionEntry.objectLocations) do
						if (selectedSizeTableEntry.minFrame <= objectLocation.frame and objectLocation.frame <= selectedSizeTableEntry.maxFrame) then
							FrameMan:DrawBitmapPrimitive(objectLocation.position, selectedSizeTableEntry.object, rotAngles[direction][selectedNodeAndDirectionEntry.isGoingBackwards], objectLocation.frame);
						end
					end
				end
			end
		end
	end
end

-----------------------------------------------------------------------------------------
-- Determine positions for and draw movator line effects based on what's selected
-----------------------------------------------------------------------------------------
function DrawMovatorConnectionLineEffects(self, selectedSizeTableEntry, generalDataTable)
	for startNode, startNodeData in pairs(MovatorNodeTable[self.Team+3]) do
		if (type(startNode) ~= "string") then
			for _, direction in ipairs(self.EffectsTable.directionsToUse) do
				local endNode = startNodeData[direction][1];
				local endNodeData = MovatorNodeTable[self.Team+3][endNode];
				if (ShouldDrawEffects(self, startNodeData, endNodeData, direction, selectedSizeTableEntry, generalDataTable)) then
					local lineStartAndEndPoints = {
						a = {
							startPoint = Vector(startNode.Pos.X, startNode.Pos.Y - startNodeData[2] * 0.5 + generalDataTable.nodeArrowDistanceFromEdge - generalDataTable.halfLineCapWidth),
							endPoint = Vector(endNode.Pos.X, endNode.Pos.Y + endNodeData[2] * 0.5 - generalDataTable.nodeArrowDistanceFromEdge + generalDataTable.halfLineCapWidth)
						},
						l = {
							startPoint = Vector(startNode.Pos.X - startNodeData[2] * 0.5 + generalDataTable.nodeArrowDistanceFromEdge - generalDataTable.halfLineCapWidth, startNode.Pos.Y),
							endPoint = Vector(endNode.Pos.X + endNodeData[2] * 0.5 - generalDataTable.nodeArrowDistanceFromEdge + generalDataTable.halfLineCapWidth, endNode.Pos.Y)
						}
					}
					for _, lineInfo in ipairs(selectedSizeTableEntry.lineInfoTable) do
						for i = -1, 1, 2 do
							local lengthModifier = lineInfo.lengthModifier;
							if (type(lengthModifier) == "nil") then
								lengthModifier = 0;
							end
							local lengthModifiers = {a = Vector(0, -lengthModifier), l = Vector(-lengthModifier, 0)};
							local startOffset = direction == "a" and Vector(lineInfo.offset * i, -(generalDataTable.halfLineCapWidth - 1)) or Vector(-(generalDataTable.halfLineCapWidth - 1), lineInfo.offset * i);
							local endOffset = direction == "a" and Vector(lineInfo.offset * i, (generalDataTable.halfLineCapWidth - 1)) or Vector((generalDataTable.halfLineCapWidth - 1), lineInfo.offset * i);
							
							local startPos = lineStartAndEndPoints[direction].startPoint + startOffset;
							local endPos = lineStartAndEndPoints[direction].endPoint + endOffset + lengthModifiers[direction]
							
							--Check for scene wrapping
							if (endPos.X > startPos.X or endPos.Y > startPos.Y) then
								local drawToVectors = direction == "a" and {startTarget = Vector(startPos.X, 0), endTarget = Vector(startPos.X, SceneMan.Scene.Height)} or {startTarget = Vector(0, startPos.Y), endTarget = Vector(SceneMan.Scene.Width, startPos.Y)}; 
								FrameMan:DrawLinePrimitive(startPos, drawToVectors.startTarget, lineInfo.colour);
								FrameMan:DrawLinePrimitive(drawToVectors.endTarget, endPos, lineInfo.colour);
							else
								FrameMan:DrawLinePrimitive(startPos, endPos, lineInfo.colour);
							end
						end
					end
					local rotAngles = {a = {startPoint = math.rad(270), endPoint = math.rad(90)}, l = {startPoint = math.rad(0), endPoint = math.rad(180)}};
					for k, point in pairs(lineStartAndEndPoints[direction]) do
						FrameMan:DrawBitmapPrimitive(point, selectedSizeTableEntry.lineCapObject, rotAngles[direction][k], 0);
					end
				end
			end
		end
	end
end

-----------------------------------------------------------------------------------------
-- Clean up data tables for current object effects if possible, needs to be called when switching size or type
-----------------------------------------------------------------------------------------
function CleanupCurrentMovatorObjectEffectsTableIfPossible(self)
	if (self.EffectsTable.selectedType ~= "") then
		local selectedSizeTableEntry = self.EffectsTable.displayTypes[self.EffectsTable.selectedType].sizes[self.EffectsTable.selectedSize];
		local generalDataTable = self.EffectsTable.displayTypes[self.EffectsTable.selectedType].generalData;
		
		if (generalDataTable.displayType == "object") then
			selectedSizeTableEntry.nodeEntries = {};
		end
	end
end

-----------------------------------------------------------------------------------------
-- Find Nearest Visible Movator (returns a reference to that movator)
-----------------------------------------------------------------------------------------
function NearestMovator(self, pos, checksight, pathchecker, inarea)
	local closest = nil;
	local dist1 = math.huge;
	local mytable = MovatorNodeTable[self.Team+3];
	local mypaths = MovatorPathTable[self.Team+3];
	for k, v in pairs(mytable) do
		if (type(k) ~= "string" and MovableMan:IsParticle(k)) then
			--Just check for distance if there's no node to check paths for, otherwise only check its distance if there's a path to it from pathchecker
			if pathchecker == nil or (pathchecker ~= nil and mypaths[pathchecker] ~= nil and mypaths[pathchecker][k] ~= nil) then
				--Find the shortest distance accounting for both x and y wrapping
				local signeddist2 = SceneMan:ShortestDistance(k.Pos, pos, MovatorCheckWrapping)
				local dist2 = signeddist2.Magnitude;
				--Check if this distance is closer than the previous closest
				if dist2 < dist1 then
					--Check if this closer node is visible and if it is, set it as the new closest node
					local seeray = false;
					if checksight == true then
						seeray = SceneMan:CastStrengthRay(pos, (k.Pos - pos), 15, Vector(), 4, 0, true);
					end
					if seeray == false then
						--Check the point size/2 away from the node in the direction of the point is in the movator area and if it is, set it as the new closest node
						local isvalid = true;
						if inarea == true then
							local str = tostring(k.Pos).."\n\t";
							local str2 = "\n\t";
							local num = v[2]/2 + 1;
							local valtable = {signeddist2.Y + v[2]/2 < 0, signeddist2.Y - v[2]/2 > 0, signeddist2.X + v[2]/2 < 0, signeddist2.X - v[2]/2 > 0};
							local checktable = {v.a[1] ~= nil and v.area.above:IsInside(pos), v.b[1] ~= nil and mytable[v.b[1]].area.above:IsInside(pos), v.l[1] ~= nil and v.area.left:IsInside(pos), v.r[1] ~= nil and mytable[v.r[1]].area.left:IsInside(pos)}
							--Run through each direction, if the first condition is true then the second must be true for us to use this point, if not break
							for i = 1, 4 do
								str = str..tostring(valtable[i]).."  "..tostring(checktable[i]).."    ";
								if valtable[i] == true and checktable[i] == false then
									if v.area.left ~= nil then
										str2 = "\n\t"..tostring(v.l[1]~=nil).."  "..tostring(v.area.left:IsInside(pos)).."\n\t";
									end
									isvalid = false;
									break;
								end
							end
							str = str..str2;
							str = str..tostring(k.Pos).." validity: "..tostring(isvalid);
							--print(str);
						end
						--Set this point as closest
						if isvalid == true then
							closest = k;
							dist1 = dist2;
						end
					end
				end
			end
		end
	end
	if closest ~= nil then
	--print ("winner is "..tostring(closest.Pos));
	end
	return closest;
end
-----------------------------------------------------------------------------------------
-- Get The Actor's Directions
-----------------------------------------------------------------------------------------
function GetDirections(self, actor, dir, mstage, start, nnode, dest, target)
	-------------------
	--Manual Movement--
	-------------------
	if MovableMan:IsActor(actor) and actor:IsPlayerControlled() or (not actor:IsPlayerControlled() and (target[1] == nil and SceneMan:ShortestDistance(actor:GetLastAIWaypoint(), actor.Pos, false).Magnitude <= 10)) then

		--Change actor's table value to the necessary one based on what they pressed
		local dirchanged = true;
		--Up
		if (actor:GetController():IsState(Controller.PRESS_UP) or actor:GetController():IsState(Controller.HOLD_UP)) and not actor:GetController():IsState(Controller.PIE_MENU_ACTIVE) then
			dir = 0;
		--Down
		elseif (actor:GetController():IsState(Controller.PRESS_DOWN) or actor:GetController():IsState(Controller.HOLD_DOWN)) and not actor:GetController():IsState(Controller.PIE_MENU_ACTIVE) then
			dir = 1;
		--Left
		elseif (actor:GetController():IsState(Controller.PRESS_LEFT) or actor:GetController():IsState(Controller.HOLD_LEFT)) and not actor:GetController():IsState(Controller.PIE_MENU_ACTIVE) then
			dir = 2;
		--Right
		elseif (actor:GetController():IsState(Controller.PRESS_RIGHT) or actor:GetController():IsState(Controller.HOLD_RIGHT)) and not actor:GetController():IsState(Controller.PIE_MENU_ACTIVE) then
			dir = 3;
		--Freeze
		elseif actor:GetController():IsState(Controller.PIE_MENU_ACTIVE) and (actor:GetController():IsState(Controller.PRESS_UP) or actor:GetController():IsState(Controller.HOLD_UP)) then
			dir = 4;
		--Leave the table
		elseif actor:GetController():IsState(Controller.PIE_MENU_ACTIVE) and (actor:GetController():IsState(Controller.PRESS_DOWN) or actor:GetController():IsState(Controller.HOLD_DOWN)) then
			dir = 5;
		else
			dirchanged = false;
		end
		
		--Reset the actor's target if the player takes control and does something
		if dirchanged == true then
			target[1] = nil;
			target[2] = nil;
			target[3] = {};
			actor:ClearAIWaypoints();
			if mstage == 6 then
				mstage = 0;
			end
		end
		
	---------------
	--AI Movement-- TODO somewhere in actor following, the actor is moving directly causing it to mess up corners (specifically turning from horizontal to downwards), instead of moving to the movator. Find and solve this issue.
	--------------- Works fine for non actor movement, probably caused by waypoint reset making improper movement
	elseif MovableMan:IsActor(actor) and not actor:IsPlayerControlled() and mstage < 7 and ((SceneMan:ShortestDistance(actor:GetLastAIWaypoint(), actor.Pos, MovatorCheckWrapping).Magnitude > 10) or target[1] ~= nil) then
		local mytable = MovatorNodeTable[self.Team+3];
		local mypaths = MovatorPathTable[self.Team+3];
	
		------------
		--Starting--
		------------
		--Set our target if we don't have one already and the actor should actually be going somewhere, not being an engine buggy little shit
		if target[1] == nil and target[2] == nil and (actor.AIMode == Actor.AIMODE_GOTO or actor.AIMode == Actor.AIMODE_BRAINHUNT or actor.AIMode == Actor.AIMODE_SQUAD) then

			print (tostring(target[1]).."  "..tostring(actor:GetLastAIWaypoint()).."  "..tostring(actor:GetLastAIWaypoint()).."  "..tostring(actor.Pos).." No waypoint or waypoint changed!");
			--Get the first actor waypoint and, if it's MO, the target actor
			local ept = nil
			for pt in actor.MovePath do
				ept = pt;
			end
			target[1] = ept;
			target[2] = nil;
			if (type(actor.MOMoveTarget) ~= "nil") then
				target[2] = {MO = actor.MOMoveTarget, mode = actor.AIMode};
			end
			--Get the list of remaining waypoints if we don't have an MO waypoint and our waypoint isn't in the movator area and we have more than one waypoint
			if target[2] == nil and target[1] ~= nil and CombinedMovatorArea[self.Team+3]:IsInside(target[1]) == false and target[1] ~= actor:GetLastAIWaypoint() then
				local ept = nil;
				--While we still have more waypoints to add
				while actor.MovePathSize > 0 and ept ~= actor:GetLastAIWaypoint() do
					--Get the last point in the movepath
					for pt in actor.MovePath do
						ept = pt;
					end
					--If we're getting the actor position as our last point, we're done, break out
					if ept == actor.Pos then
						break;
					--Otherwise add the point to our table and set up for the next one
					else
						table.insert(target[3], ept);
						actor:ClearMovePath();
						actor:UpdateMovePath();
					end
				end
			end
			--Now that we have our target and all waypoints are saved, clean up
			actor.AIMode = Actor.AIMODE_SENTRY;
			actor:ClearAIWaypoints();
			--Reset variables
			dir = 4;
			start = 0;
			mstage = 0;
			nnode = 0;
			dest = 0;
		--If the actor is being an engine buggy little shit, clear his waypoints
		else
			actor:ClearAIWaypoints();
		end
		if target[1] ~= nil then
			if type(target[2]) == "nil" then
				ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("HERE",target[1], self.Team, GameActivity.ARROWDOWN);
			end
			if type(start) ~= "number" then
				ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("START",start.Pos, self.Team, GameActivity.ARROWDOWN);
			end
		end
		

		--If we're in the early stages of our movement path and we've not been told not to start
		if mstage < 2 and MovableMan:IsActor(actor) then
			------------------
			--Early Movements--
			------------------
			if mstage == 0 and target[1] ~= nil then
				--Get the start and end movators if we don't have them already then move to the starting node, as long as the actor has a target point
				if type(start) == "number" then
					start = NearestMovator(self, actor.Pos, true, nil, true);
					--The destination has to account for visibility to the point, make sure we only look for movators connected to start, and pick the best route if our dest is inside the global moator area
					dest = NearestMovator(self, target[1], true, start, CombinedMovatorArea[self.Team+3]:IsInside(target[1]));
					
					--If we can't find a movator with direct visibility to the endpoint, just find the closest one
					--TODO figure out a method of outside movator area target analysis for this and mstage 3, either a. look at right angles to find points i.e. cast a ray to the point's x/y if it's visible cast a ray from there to the target if it's visible then we're in the clear - expensive! Or, make a dummy actor, use goto and see if it generates a path, also expensive!
					if dest == nil or type(dest) == "number" then
						print (tostring(dest).." "..tostring(target[1]).." No node has visibility to target, destination set to "..tostring(NearestMovator(self, target[1], false)));
						dest = NearestMovator(self, target[1], false, start, false); --By definition, this target isn't inside the movator area
					end
						
					--Check if we should change the starting node to the next one in the path
					local testdir = mypaths[start][dest][2];
					--If the closest node to our destination is actually our start, don't check, just move on
					if testdir < 4 and MovableMan:IsActor(actor) then
						--Set up variables and get distance to current start
						local n = {"a", "b", "l", "r"};
						local mynext = mytable[start][n[testdir+1]][1];
						local dist = SceneMan:ShortestDistance(actor.Pos,start.Pos,MovatorCheckWrapping);
						--If we're not very close to our starting node, do the check
						if dist.Magnitude >= 10 then
							--Get the direction to the start node
							local sdir;
							--Pick the farther direction
							if (math.abs(dist.Y) >= math.abs(dist.X)) then
								if dist.Y < -5 then
									sdir = 0;
								elseif dist.Y > 5 then
									sdir = 1;
								end
							else
								if dist.X < -5 then
									sdir = 2;
								elseif dist.X > 5 then
									sdir = 3;
								end
							end
							--Get the opposite of direction to the next node from the start node
							local ndir = mypaths[start][dest][2];
							local dirtab = {1, 0, 3, 2};
							--If our direction to the original start is opposite the direction we need to go, set start to be the next node so we don't go backwards
							if sdir == dirtab[ndir+1] then
								start = mynext;
								print ("Next node better, go there!");
								--If the new start is actually our end node, skip to mstage 3 (not 4 since there could be a corner to worry about)
								if mypaths[start][dest][2] == 4 then
									mstage = 3;
									nnode = start;
									print("Stage 0: New start is dest, Skip to "..tostring(mstage));
								end
							end
						end
					--If our original start is our destination, skip to stage 3 if we have a corner, 4 if it's a straight movement
					else
						mstage = 3;
						--Make sure we don't go backwards when our point is in the opposite direction from the start node
						local startdist = SceneMan:ShortestDistance(actor.Pos, start.Pos, MovatorCheckWrapping); --Extra vector to avoid division by zero issues
						local targetdist = SceneMan:ShortestDistance(actor.Pos, target[1], MovatorCheckWrapping); --Extra vector to avoid division by zero issues
						print (tostring(startdist).."  "..tostring(targetdist));
						if math.abs(startdist.Y) <= actor.Height/self.CentreOffset then
							print (tostring(actor.Height/self.CentreOffset).."  startdist.Y set to 0");
							startdist.Y = 0;
						end
						local absdists = {math.abs(startdist.X), math.abs(targetdist.X), math.abs(startdist.Y), math.abs(targetdist.Y)};
						local dists = {startdist.X/absdists[1], targetdist.X/absdists[2], startdist.Y/absdists[3], targetdist.Y/absdists[4]};
						print(tostring(dists[1]).."  "..tostring(dists[2]).."  "..tostring(dists[3]).."  "..tostring(dists[4]))
						--XOR only one startdist == -targetdist at a time will bump up the movement stage
						if not(dists[1] == -dists[2]) == (dists[3] == -dists[4]) then
							mstage = 4;
						end
						nnode = start;
						print("Stage 0: Original start is dest, Leap to "..tostring(mstage));
					end
				end
			
				--Do the movements if we haven't already skipped ahead
				if mstage < 4 and MovableMan:IsActor(actor) then
					local dist = SceneMan:ShortestDistance(actor.Pos, start.Pos, MovatorCheckWrapping);
					local sizex, sizey = math.abs(dist.X), math.abs(dist.Y);
					
					--Pick the farther direction for this
					--Vertical
					if sizey > sizex then
						--If we're more than 5 below our destination go up
						if dist.Y < -5 then
							dir = 0;
						--If we're more than 5 above our destination go down
						elseif dist.Y > 5 then
							dir = 1;
						end
					--Horizontal
					else
						--If we're more than 5 to the right of our destination go left
						if dist.X < -5 then
							dir = 2;
						--If we're more than 5 to the left of our destination go right
						elseif dist.X > 5 then
							dir = 3;
						end
					end
					--If we're close, move to the next stage, aka waiting
					if mytable[start].sbox:WithinBox(actor.Pos) then
						dir = 4; --Wait if there
						mstage = 1;
					end
				end
				
			--Now that actor is at his start point, find his path
			elseif mstage == 1 then
				dir = mypaths[start][dest][2];
				--If we're at our destination node right from the get-go, skip to mstage 4
				if dir == 4 then
					mstage = 4;
					print ("Stage 1: Start is dest, Skip to "..tostring(mstage));
				--Otherwise get the next node and do the relevant movements
				else
					local n = {"a", "b", "l", "r"};
					nnode = mytable[start][n[dir+1]][1];
					mstage = 2;
					
					--If the next node is our destination, jump ahead to mstage 3
					if Vector(nnode.Pos.X, nnode.Pos.Y) == Vector(dest.Pos.X, dest.Pos.Y) then
						mstage = 3;
						print ("Stage 1: Next node is dest, Fasttrack to "..tostring(mstage));
					end
				end
			end
		--------------------
		--Middle Movements--
		--------------------
		--Now we've got a path and have gotten moving, follow the path
		elseif mstage >= 2 and MovableMan:IsActor(actor) then
			--If we're not at our destination move to our next node
			if mstage == 2 or mstage == 3 then
				--If we're in stage 3, we have to be careful we don't overshoot our target and double back, so check all the time instead of just at nodes
				if mstage == 3 then
					local dist = SceneMan:ShortestDistance(actor.Pos,target[1],MovatorCheckWrapping);
					local sizex, sizey = math.abs(dist.X), math.abs(dist.Y);
					--Set up a variable for how close we have to get to our end waypoint, it's farther if the target is an actor so they don't all sit on top of each other
					local close = self.ActorTargetRange;
					if type(target[2]) == "nil" then
						close = close*0.5;
					end
					--If we're close to our target, move to the next stage and make the actor stay
					if sizex <= close and sizey <= close then
						print ("Stay at target in stage 3: "..tostring(sizex).."  "..tostring(sizey));
						mstage = 4;
						dir = 4;
						print ("Stage 3: At our end waypoint, move to "..tostring(mstage));
					end
				end
				--If we haven't already jumped ahead, when we're within our current next node's box, figure out what to do next
				if mstage < 4 and MovableMan:IsActor(actor) then
					if mytable[nnode].sbox:WithinBox(actor.Pos) then
						--If it's not the destination find the next path direction
						dir = mypaths[nnode][dest][2];
						if dir < 4 then
							local n = {"a", "b", "l", "r"};
							nnode = mytable[nnode][n[dir+1]][1];
							--If our new next node is next to the destination and we're not already in stage 3, advance the stage
							if mypaths[nnode][dest][2] == 4 and mstage == 2 then
								mstage = 3;
								print ("Stage 2: New next node is dest, hurry to to "..tostring(mstage));
							end
						--If it's the destination, advance the stage
						else
							print (mypaths[nnode][dest][2]);
							local printval = mstage
							mstage = 4;
							dest = nil;
							print ("Stage "..tostring(printval)..": Next node is dest, move to "..tostring(mstage)..", no destination node now");
						end
					end
				end
			----------------
			--End Movement--
			----------------
			--Now that we're at our final movator destination, we have to figure out what to do with the actor
			elseif mstage == 4 and MovableMan:IsActor(actor) then
				local dist = SceneMan:ShortestDistance(actor.Pos,target[1],MovatorCheckWrapping);
				local sizex, sizey = math.abs(dist.X), math.abs(dist.Y);
				--Set up a variable for how close we have to get to our end waypoint, it's farther if the target is an actor so they don't all sit on top of each other
				local close = self.ActorTargetRange;
				if type(target[2]) == "nil" then
					close = close*0.5;
				end
				
				--If we've got a waypoint inside the movator area, figure out which way to send the actor
				if target[1] ~= nil and CombinedMovatorArea[self.Team+3]:IsInside(target[1]) then
					--Pick the farther direction for this
					--Vertical
					if sizey > sizex then
						--If we're more than the determined distance below our destination go up
						if dist.Y < -close then
							dir = 0;
						--If we're more than the determined distance above our destination go down
						elseif dist.Y > close then
							dir = 1;
						end
					--Horizontal
					else
						--If we're more than the determined distance to the right of our destination go left
						if dist.X < -close then
							dir = 2;
						--If we're more than the determined distance to the left of our destination go right
						elseif dist.X > close then
							dir = 3;
						end
					end
					--If we're close, move to the next stage, aka waiting
					if sizex <= close and sizey <= close then
						print ("stage 4 -> 5, halt then retarget if needed");
						mstage = 5;
					end
				--Otherwise figure out which way to kick him out
				else
					if MovableMan:IsActor(actor) then
						dir = 5; --Default value, just drop the actor out of the table and let him figure it out from here
						--Pick the farther direction for this
						--Vertical
						if sizey > sizex then
							if dist.Y < 0 then
								if SceneMan:CastStrengthRay(actor.Pos, Vector(0, -50), 15, Vector(), 4, 0, true) == false then
									dir = 0;
								end
							elseif dist.Y > 0 then
								if SceneMan:CastStrengthRay(actor.Pos, Vector(0, 50), 15, Vector(), 4, 0, true) == false then
									dir = 1;
								end
							else
								dir = 5;
							end
						--Horizontal
						else --TODO A possible way to make sure we move in the right direction is check that there's no movator in that direction. If there is we're going the wrong way maybe?
							if dist.X < 0 then
								if SceneMan:CastStrengthRay(actor.Pos, Vector(-50, 0), 15, Vector(), 4, 0, true) == false then
									dir = 2;
								end
							elseif dist.X > 0 then
								if SceneMan:CastStrengthRay(actor.Pos, Vector(50, 0), 15, Vector(), 4, 0, true) == false then
									dir = 3;
								end
							else
								dir = 5;
							end
						end
						print ("Stage 4 -> 6 dump out "..tostring(dir));
						mstage = 6;
					end
				end
			--Destination inside movator area - reset the actor unless he shouldn't reset, make him stay able to goto or squad again, if he's got an actor waypoint, goto it
			elseif mstage == 5 and MovableMan:IsActor(actor) then
				--Halt the actor
				dir = 4;
				--If it's an MO target
				local retarget = 0;
				if type(target[2]) ~= "nil" then
					local dist = SceneMan:ShortestDistance(actor.Pos,target[2].MO.Pos,MovatorCheckWrapping);
					--Set a flag for if the actor's far enough away to retarget
					if math.max(math.abs(dist.X), math.abs(dist.Y)) > self.ActorTargetRange then
						retarget = 2;
					else
						--For close targets, go into squad mode so you the squad can shoot together
						if (actor.AIMode ~= Actor.AIMODE_SQUAD) then
							actor.MOMoveTarget = target[2].MO;
							actor.AIMode = Actor.AIMODE_SQUAD;
						end
						retarget = 1;
					end
					--ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint(tostring(retarget).." target dist "..tostring(math.max(sizex, sizey)), Vector(actor.Pos.X, actor.Pos.Y + 20), self.Team, GameActivity.ARROWUP);
				end
				--If it's an MO waypoint, check if we should get moving again
				if retarget > 0 then
					--If we  should get moving, add the target MO as our target and reset the variables so we start over
					if retarget == 2 then
						actor:AddAIMOWaypoint(target[2].MO);
						actor.AIMode = target[2].mode;
						actor:UpdateMovePath();
						target = {nil, nil, {}};
						print("Stage 5 time to move, readd actor waypoint");
					end
				--Otherwise if it's a scene waypoint, reset so we can get moving again but won't move until we're asked to
				elseif retarget == 0 then
					target = {nil, nil, {}};
					actor:ClearAIWaypoints();
					mstage = 0;
				end
			--Destination outside of movator area - set his ai back to goto or squad and give him back his waypoint, reset variables and advance stage out of bounds so it works properly
			elseif mstage == 6 and MovableMan:IsActor(actor) then
				print ("Out of area, give him his waypoint and leave him alone");
				if type(target[2]) == "nil" then
					actor:AddAISceneWaypoint(target[1]);
					--Readd all the actor's scene waypoints
					for i = 1, #target[3] do
						actor:AddAISceneWaypoint(target[3][i]);
					end
					actor.AIMode = Actor.AIMODE_GOTO;
				else
					actor:AddAIMOWaypoint(target[2].MO);
					actor.AIMode = target[2].mode;
				end
				--Update movepath to avoid issues
				actor:UpdateMovePath();
				--Reset variables and behaviour
				target = {nil, nil, {}};
				mstage = 7;
			end
		end
	end
	if MovableMan:IsActor(actor) and not actor:IsPlayerControlled() then
		ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("Life: "..tostring(actor.Lifetime).."  Dir: "..tostring(dir).." Stage: "..tostring(mstage).." S: "..tostring(start~=nil).." N: "..tostring(nnode~=nil).." D: "..tostring(dest~=nil).." T1: "..tostring(target[1]).." T2: "..tostring(target[2]), Vector(actor.Pos.X, actor.Pos.Y - 20), self.Team, GameActivity.ARROWDOWN);
	end

	self.MovatorAffectedActors[actor.Lifetime].dir = dir;
	self.MovatorAffectedActors[actor.Lifetime].stage = mstage;
	self.MovatorAffectedActors[actor.Lifetime].s = start;
	self.MovatorAffectedActors[actor.Lifetime].n = nnode;
	self.MovatorAffectedActors[actor.Lifetime].d = dest;
	self.MovatorAffectedActors[actor.Lifetime].t[1] = target[1];
	self.MovatorAffectedActors[actor.Lifetime].t[2] = target[2];
	self.MovatorAffectedActors[actor.Lifetime].t[3] = target[3];
end
-----------------------------------------------------------------------------------------
-- Do The Movements
-----------------------------------------------------------------------------------------
function DoMovements(self, actor, dir, prevdir, cnode)

	--If the actor is slow enough, exists and is not set to be dropping
	if math.abs(actor.Vel.X) <= self.Speed and math.abs(actor.Vel.Y) <= self.Speed and dir < 5 and MovableMan:IsActor(actor) then

		------------------
		--Centring stuff--
		------------------
		--Find the centre for the actor, based on their height
		local centre = actor.Height/self.CentreOffset;

		--Do actor centring, rotation checks and other miscellaneous behaviour
		--Only happens when rechecking closest node
		local iscentred = true;
		--Treat the actor as centred if he's set to stay or fall
		if dir >= 4 then
			prevdir = dir;
		end
		--If he's changed direction, treat him as uncentred and find the node to centre him to
		if prevdir ~= dir then
			--Find the node to center to, checking if the node has this actor in its in between area
			cnode = NearestMovator(self, actor.Pos, true, nil, true);
			--If no node was found somehow, default to the closest one
			if cnode == nil then
				print ("Centring error, no node found, defaulting to simple closest");
				cnode = NearestMovator(self, actor.Pos, true, nil, nil);
			end
			--If we still can't find a node, make the actor flash white and drop it out of the movator network
			if (cnode == nil) then
				actor:FlashWhite(300);
				actor:MoveOutOfTerrain(0);
				print("Could not find a node for actor "..actor.PresetName.." to center on. Trying to move it out of terrain and dropping it out of the movator network");
				self.MovatorAffectedActors[actor.Lifetime].dir = 5;
				return;
			end
			iscentred = false;
		end
		--If the actor is not centred, centre him
		if iscentred == false then
			--Up and down actions
			if dir == 0 or dir == 1 then
				--Do horizontal centring
				if actor.Pos.X > cnode.Pos.X + self.Speed*0.5 then
					actor.Vel.X = -self.Speed*0.5;
				elseif actor.Pos.X < cnode.Pos.X - self.Speed*0.5 then
					actor.Vel.X = self.Speed*0.5;
				elseif actor.Pos.X >= cnode.Pos.X - self.Speed*0.5 and actor.Pos.X <= cnode.Pos.X + self.Speed*0.5 then
					actor.Vel.X = 0;
					actor.Pos.X = cnode.Pos.X;
					--Flag actor as centred
					iscentred = true;
				end
			--Left and right actions
			elseif dir == 2 or dir == 3 then
				--Do vertical centring
				if actor.Pos.Y > cnode.Pos.Y + centre + self.Speed*0.5 then
					actor.Vel.Y = -self.Speed*0.5;
				elseif actor.Pos.Y < cnode.Pos.Y + centre - self.Speed*0.5 then
					actor.Vel.Y = self.Speed*0.5;
				elseif actor.Pos.Y >= cnode.Pos.Y + centre - self.Speed*0.5 and actor.Pos.Y <= cnode.Pos.Y + centre + self.Speed*0.5 then
					actor.Vel.Y = 0 - SceneMan.GlobalAcc.Magnitude*TimerMan.DeltaTimeSecs;
					actor.Pos.Y = cnode.Pos.Y + centre;
					--Flag actor as centred
					iscentred = true;
				end
			end
		end
		--Otherwise if the actor is centred, set prevdir to dir
		if iscentred == true then
			prevdir = dir;
		end
		
		-------------------------------------------------
		--Actual movement stuff, plus crouching changes--
		-------------------------------------------------
		--if MovableMan:IsActor(actor) then
		--Up
		if dir == 0 then
			actor.Vel.Y = -self.Speed - SceneMan.GlobalAcc.Magnitude*TimerMan.DeltaTimeSecs;
			--Uncrouch actor
			actor:GetController():SetState(Controller.BODY_CROUCH, false);
		--Down
		elseif dir == 1 then
			actor.Vel.Y = self.Speed;
			--Uncrouch actor
			actor:GetController():SetState(Controller.BODY_CROUCH, false);
		--Left
		elseif dir == 2 then
			actor.Vel.X = -self.Speed;
			if iscentred == true then
				actor.Vel.Y = 0 - SceneMan.GlobalAcc.Magnitude*TimerMan.DeltaTimeSecs;
			end
			--Crouch actor
			actor:GetController():SetState(Controller.BODY_CROUCH, true);
		--Right
		elseif dir == 3 then
			actor.Vel.X = self.Speed;
			if iscentred == true then
				actor.Vel.Y = 0 - SceneMan.GlobalAcc.Magnitude*TimerMan.DeltaTimeSecs;
			end
			--Crouch actor
			actor:GetController():SetState(Controller.BODY_CROUCH, true);
		--Stay
		elseif dir == 4 then
			actor.Vel.X = 0;
			actor.Vel.Y = 0 - SceneMan.GlobalAcc.Magnitude*TimerMan.DeltaTimeSecs;
			actor:GetController():SetState(Controller.BODY_CROUCH, actor:GetController():IsState(Controller.BODY_CROUCH)); --Keep crouching if they were already
		end
		
		-----------------------
		--Extra general stuff--
		-----------------------
		--Slow down spinning
		if actor.AngularVel > self.Speed then
			actor.AngularVel = actor.AngularVel - self.Speed/4;
		elseif actor.AngularVel < -self.Speed then
			actor.AngularVel = actor.AngularVel + self.Speed/4;
		end
		
		--Turn Actor fully upright if it's not rotating too quickly
		if math.abs(actor.AngularVel) <= self.Speed then
			if actor.RotAngle > math.rad(5) then
				actor.AngularVel = -1; --Rotate right if too far left
			elseif actor.RotAngle < math.rad(-5) then
				actor.AngularVel = 1; --Rotate left if too far right
			end
		end
		
		--Stop the Actor from moving freely
		actor:GetController():SetState(Controller.MOVE_LEFT , false);
		actor:GetController():SetState(Controller.MOVE_RIGHT , false);
		actor:GetController():SetState(Controller.MOVE_UP , false);
		actor:GetController():SetState(Controller.MOVE_DOWN , false);
		actor:GetController():SetState(Controller.BODY_JUMP , false);
		actor:GetController():SetState(Controller.BODY_JUMPSTART , false);
		
		--Set the actor's table variables so they're updated
		self.MovatorAffectedActors[actor.Lifetime].dir = dir;
		self.MovatorAffectedActors[actor.Lifetime].prevdir = prevdir;
		self.MovatorAffectedActors[actor.Lifetime].cnode = cnode;
	
	--Slow down actors in the area that are moving too fast
	elseif math.abs(actor.Vel.X) > self.Speed or math.abs(actor.Vel.Y) > self.Speed then
		if dir ~= 5 then
			actor.Vel.Y = actor.Vel.Y/1.5
			actor.Vel.X = actor.Vel.X/1.2
		end
	end
end
-----------------------------------------------------------------------------------------
-- Destroy
-----------------------------------------------------------------------------------------
function Destroy(self)
	--Fix actor lifetimes (TODO this lifetime business should be replaced by number values on actors by the way)
	for k, v in pairs(self.MovatorAffectedActors) do 
		if type (k) ~= "string" then
			v.act.Lifetime = 0;
		end
	end
	
	--Only reset movator variables and power values if there's no replacement movator
	for a in MovableMan.Actors do
		if a.PresetName == "Movator Controller" and a.Team == self.Team and a.ID ~= self.ID then
			return;
		end
	end
	ResetMovatorVariables(self.Team);
	MovatorPowerValues[self.Team+3] = 0;
end

--Mouse stuff
function ShowMouse(self)
	DrawMouseCursor(self.Mouse);
	--Try to deal with scenewrapping
	if self.Mouse.X < SceneMan.SceneWidth - FrameMan.PlayerScreenWidth and self.Mouse.X > 0 + FrameMan.PlayerScreenWidth then
		SceneMan:SetScrollTarget(self.Mouse, 1, false, 0);
	else
		SceneMan:SetScrollTarget(self.Mouse, 1, true, 0);
	end

	-- Read the mouse's input
	self.Mouse = self.Mouse + UInputMan:GetMouseMovement(0);
	--Deal with wrapping
	if self.Mouse.X <= 2 and UInputMan:GetMouseMovement(0).X < 0 then
		self.Mouse.X = SceneMan.SceneWidth;
	elseif self.Mouse.X >= SceneMan.SceneWidth-2 and UInputMan:GetMouseMovement(0).X > 0 then
		self.Mouse.X = 0;
	end
	if self.Mouse.Y < 0 then
		self.Mouse.Y = 0;
	elseif self.Mouse.Y > SceneMan.SceneHeight then
		self.Mouse.Y = SceneMan.SceneHeight;
	end
	
	--Right click option, show path creation for a specific node
	if UInputMan:MouseButtonPressed(2) then
		self.MyShowPath = NearestMovator(self, self.Mouse, false, nil, false);
	end
	--Left click option, show path between clicked nodes
	if self.Click1 == nil or self.Click2 == nil then
		if UInputMan:MouseButtonPressed(0) then
			if self.Click1 == nil then
				self.Click1 = self.Mouse;
				print (self.Mouse)
			else
				self.Click2 = self.Mouse;
				print (self.Mouse)
			end
		end
	elseif self.Click1 ~= nil and self.Click2 ~= nil then
		DoDir(self);
	end
end
function DrawMouseCursor(m)
	local pix = CreateMOPixel("Cursor");
	pix.Pos = m + Vector(6 , 6);
	MovableMan:AddParticle(pix);
end
function DoDir(self)
	local mytable = MovatorNodeTable[self.Team+3];
	local mypaths = MovatorPathTable[self.Team+3];
	local start = NearestMovator(self, self.Click1, false, nil, false);
	local dest = NearestMovator(self, self.Click2, false, start, false);
	local dist, dir, mid = nil, nil, nil;
	dist = mypaths[start][dest][1];
	dir = mypaths[start][dest][2];
	local n = {"a", "b", "l", "r"}; --convert numbers to directions
	mid = mytable[start][n[dir+1]][1]; --The middle node is found by looking for the node in the relevant direction from the start (or the previous mid node)
	ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("Start: "..tostring(start.Pos), Vector(start.Pos.X, start.Pos.Y - 20), self.Team, GameActivity.ARROWDOWN);
	ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("Intermediate: dist: "..tostring(dist).." dir: "..tostring(dir), Vector(mid.Pos.X, mid.Pos.Y - 20), self.Team, GameActivity.ARROWDOWN);
	ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("End: "..tostring(dest.Pos), Vector(dest.Pos.X, dest.Pos.Y - 40), self.Team, GameActivity.ARROWDOWN);
	if UInputMan:MouseButtonPressed(0) then
		print (SceneMan:ShortestDistance(self.Click1, self.Mouse, SceneMan.SceneWrapsX));
		self.Click1, self.Click2 = nil, nil;
	end
end