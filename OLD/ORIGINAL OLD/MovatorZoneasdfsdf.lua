-----------------------------------------------------------------------------------------
-- Create
-----------------------------------------------------------------------------------------
function Create(self)

	--Set the speed that the actors move at and the speed above which to slow down actors that are using the movator
	self.Speed = 4;

	--Set the area this movator encompasses
	self.Box = Box(Vector(self.Pos.X - 24 , self.Pos.Y - 24) , Vector(self.Pos.X + 24 , self.Pos.Y + 24));
	--The smaller area for the movator. Used for turning corners
	self.InnerBox = Box(Vector(self.Pos.X - 10 , self.Pos.Y - 10) , Vector(self.Pos.X + 10 , self.Pos.Y + 10));
	--The two boxes in between movators. Only two directions are needed because the other movator will supply directions for the in between boxes.
	self.ABox = Box(Vector(0 , 0) , Vector(0 , 0));
	self.LBox = Box(Vector(0 , 0) , Vector(0 , 0));

	--The targets for each node, used for checking closest target
	self.ATarget = nil;
	self.BTarget = nil;
	self.LTarget = nil;
	self.RTarget = nil;
	--Variables for whether a node is directly attached to self in each direction
	self.NodeAbove = false;
	self.NodeBelow = false;
	self.NodeLeft = false;
	self.NodeRight = false;
	--Save each node that counts as being above or left
	self.ANode = nil;
	self.LNode = nil;

	--Table for actors who are inside the movator's field of effect
	self.Move = {}

	--Global Variable for checking when a node has been placed
	if not MovatorNodePlacedCheck == true then
		MovatorNodePlacedCheck = true;
	end
	--Global timer for rechecking node placement in case the node gets blocked or removed
	if not MovatorNodeRecheckTimer then
		MovatorNodeRecheckTimer = Timer();
		MovatorNodeRecheckInterval = 5000;
	end
	--Area shared by all movators
	if not CombinedMovatorArea then
		CombinedMovatorArea = Area();
	end
	CombinedMovatorArea:AddBox(self.Box);

	self.CheckTimer = Timer();
	self.CheckInterval = 10;
	self.CheckTimer:Reset();
	self.BumpTimer = Timer();
	self.BumpTimer:Reset();
	self.PartTimer = Timer();
	self.PartTimer:Reset();
	self.CleanTimer = Timer();
	self.CleanTimer:Reset();
end
-----------------------------------------------------------------------------------------
-- Update
-----------------------------------------------------------------------------------------
function Update(self)

	--For some reason the functions weren't calling in this and the vertical node. Movement was being run as was actor slowing but ai directions wouldn't change and nothing would print. I renamed them (added Re at the front) and they started working fine but I really don't understand why. Note that this didn't happen with the horizontal nodes. I would love to know why this is.
	AReDoNodeChecks(self);

	--Check for actors in the Movators and add them to the table
	if self.BumpTimer:IsPastSimMS(10) then
		--[[for actor in MovableMan.Actors do
			if CombinedMovatorArea:IsInside(actor.Pos) and (actor.PinStrength == 0) and actor.ClassName ~= "ACRocket" and actor.ClassName ~= "ADropship" then

				--Pick the right direction to move in for players and ai
				AReGetDirections(self , actor);

				--Do the actual movements
				AReDoMovements(self , actor);
			elseif not CombinedMovatorArea:IsInside(actor.Pos) and actor.Lifetime >= 999999 then
				actor.Lifetime = 0;
			end
		end--]]



		--Table stuff, because it only iterates once it doesn't work. If someone can figure out a way to fix this I'd appreciate it cause it'd greatly reduce lag I'm sure.

		for actor in MovableMan.Actors do
			if CombinedMovatorArea:IsInside(actor.Pos) and (actor.PinStrength == 0) and actor.ClassName ~= "ACRocket" and actor.ClassName ~= "ADropship" and actor.Lifetime < 999999 then
				self.Move[#self.Move + 1] = actor;
				actor.Lifetime = 999999;
			end
		end

		--Do everything for the actors in the movators

		--Sets actors' lifetime back to zero if they're not in the Movator Area
		if #self.Move > 0 then
			for i = 1 , #self.Move do
				if not CombinedMovatorArea:IsInside(self.Move[i].Pos) then
					self.Move[i].Lifetime = 0;
					table.remove(self.Move , i);
				--Performs all the actions
				--[[elseif CombinedMovatorArea:IsInside(self.Move[i].Pos) then
					--Pick the right direction to move in for players and ai
					GetDirections(self , self.Move[i]);
	
					--Do the actual movements
					DoMovements(self , self.Move[i]);--]]
				end
			end
			AReGetDirections(self);
			AReDoMovements(self);

			self.BumpTimer:Reset();
		end
		print (table.getn(self.Move));
	end
end
-----------------------------------------------------------------------------------------
-- Check The Nodes
-----------------------------------------------------------------------------------------
function AReDoNodeChecks(self)
	if self.CheckTimer ~= nil then
		if self.CheckTimer:IsPastSimMS(self.CheckInterval) then
			MovatorNodePlacedCheck = false;
			self.CheckTimer = nil;
			self.CheckInterval = nil;
		end
	end
	if MovatorNodeRecheckTimer:IsPastSimMS(MovatorNodeRecheckInterval - 10) then
		MovatorNodePlacedCheck = true;
	elseif MovatorNodeRecheckTimer:IsPastSimMS(MovatorNodeRecheckInterval) then
		MovatorNodePlacedCheck = false;
		MovatorNodeRecheckTimer:Reset();
	end

	local nodes = {}
	if MovatorNodePlacedCheck == true then

		for node in MovableMan.Particles do
			if (node.PresetName == "Movator Zone Node" or node.PresetName == "Movator Test Node") and not (node.Pos.X == self.Pos.X and node.Pos.Y == self.Pos.Y) then
				nodes[#nodes + 1] = node;
			end
		end

		local anodes = {}
		local bnodes = {}
		local lnodes = {}
		local rnodes = {}
		--Everything for nodes
		if #nodes > 0 then
			for i = 1 , #nodes do
				--Set up tables for each direction for picking the closest node, essentially table finds node that can connect to self
				if (nodes[i].Pos.Y <= self.Pos.Y - 48) and (nodes[i].Pos.X == self.Pos.X) then
					anodes[#anodes + 1] = nodes[i]
				end
				if (nodes[i].Pos.Y >= self.Pos.Y + 48) and (nodes[i].Pos.X == self.Pos.X) then
					bnodes[#bnodes + 1] = nodes[i]
				end
				if (nodes[i].Pos.X <= self.Pos.X - 48) and (nodes[i].Pos.Y == self.Pos.Y) then
					lnodes[#lnodes + 1] = nodes[i]
				end
				if (nodes[i].Pos.X >= self.Pos.X + 48) and (nodes[i].Pos.Y == self.Pos.Y) then
					rnodes[#rnodes + 1] = nodes[i]
				end
			end
		end

		--Find the closest node in each table and set it to be the node above then, for left and above, add the box formed to the combined area for movement and for glowy effects

		--Attached Above
		if #anodes <= 0 then
			self.NodeAbove = false;
		elseif #anodes > 0 then
			local adist = 0
			local atarget;
			for i = 1 , #anodes do
				if i == 1 then
					atarget = anodes[i];
					adist = SceneMan:ShortestDistance(self.Pos,atarget.Pos,SceneMan.SceneWrapsX).Magnitude;
				else
					local dist = SceneMan:ShortestDistance(self.Pos,anodes[i].Pos,SceneMan.SceneWrapsX).Magnitude;
					if dist < adist then
						atarget = anodes[i];
						adist = dist;
					end
				end
				local aray = SceneMan:CastStrengthRay(self.Pos, (atarget.Pos - self.Pos), 15, Vector(), 4, 0, true);
				if aray == false then
					if (atarget.Pos.Y == self.Pos.Y - 48) then
						self.NodeAbove = true;
					elseif (atarget.Pos.Y < self.Pos.Y - 48) then
						self.ANode = atarget;
						self.NodeAbove = true;
					end
				else
					self.NodeAbove = false;
				end
			end
		end
		if self.NodeAbove == true and self.ANode ~= nil then
			self.ABox = Box(Vector(self.Pos.X - 24 , self.ANode.Pos.Y + 24) , Vector(self.Pos.X + 24 , self.Pos.Y - 24));
			CombinedMovatorArea:AddBox(self.ABox);
		elseif self.NodeAbove ~= true then
			self.ABox = Box(Vector(0,0) , Vector(0,0));
			self.ANode = nil;
		end

		--Attached Below
		if #bnodes <= 0 then
			self.NodeBelow = false;
		elseif #bnodes > 0 then
			local bdist = 0
			local btarget;
			for i = 1 , #bnodes do
				if i == 1 then
					btarget = bnodes[i];
					bdist = SceneMan:ShortestDistance(self.Pos,btarget.Pos,SceneMan.SceneWrapsX).Magnitude;
				else
					local dist = SceneMan:ShortestDistance(self.Pos,bnodes[i].Pos,SceneMan.SceneWrapsX).Magnitude;
					if dist < bdist then
						btarget = bnodes[i];
						bdist = dist;
					end
				end
				local bray = SceneMan:CastStrengthRay(self.Pos, (btarget.Pos - self.Pos), 15, Vector(), 4, 0, true);
				if bray == false then
					self.NodeBelow = true;
				else
					self.NodeBelow = false;
				end
			end
		end

		--Attached Left
		if #lnodes <= 0 then
			self.NodeLeft = false;
		elseif #lnodes > 0 then
			local ldist = 0
			local ltarget;
			for i = 1 , #lnodes do
				if i == 1 then
					ltarget = lnodes[i];
					ldist = SceneMan:ShortestDistance(self.Pos,ltarget.Pos,SceneMan.SceneWrapsX).Magnitude;
				else
					local dist = SceneMan:ShortestDistance(self.Pos,lnodes[i].Pos,SceneMan.SceneWrapsX).Magnitude;
					if dist < ldist then
						ltarget = lnodes[i];
						ldist = dist;
					end
				end
				local lray = SceneMan:CastStrengthRay(self.Pos, (ltarget.Pos - self.Pos), 15, Vector(), 4, 0, true);
				if lray == false then
					if (ltarget.Pos.X == self.Pos.X - 48) then
						self.NodeLeft = true;
					elseif (ltarget.Pos.X < self.Pos.X - 48) then
						self.LNode = ltarget;
						self.NodeLeft = true;
					end
				else
					self.NodeLeft = false;
				end
			end
		end
		if self.NodeLeft == true and self.LNode ~= nil then
			self.LBox = Box(Vector(self.LNode.Pos.X + 24 , self.Pos.Y - 24) , Vector(self.Pos.X - 24 , self.Pos.Y + 24));
			CombinedMovatorArea:AddBox(self.LBox);
		elseif self.NodeLeft ~= true then
			self.LBox = Box(Vector(0,0) , Vector(0,0));
			self.LNode = nil;
		end

		--Attached Right
		if #rnodes <= 0 then
			self.NodeRight = false;
		elseif #rnodes > 0 then
			local rdist = 0
			local rtarget;
			for i = 1 , #rnodes do
				if i == 1 then
					rtarget = rnodes[i];
					rdist = SceneMan:ShortestDistance(self.Pos,rtarget.Pos,SceneMan.SceneWrapsX).Magnitude;
				else
					local dist = SceneMan:ShortestDistance(self.Pos,rnodes[i].Pos,SceneMan.SceneWrapsX).Magnitude;
					if dist < rdist then
						rtarget = rnodes[i];
						rdist = dist;
					end
				end
				local rray = SceneMan:CastStrengthRay(self.Pos, (rtarget.Pos - self.Pos), 15, Vector(), 4, 0, true);
				if rray == false then
					self.NodeRight = true;
				else
					self.NodeRight = false;
				end
			end
		end

		--Change the look of the hub depending on nearby nodes
		--[[if self.NodeAbove == true and self.NodeBelow ~= true and self.NodeLeft ~= true and self.NodeRight ~= true then
			self.Frame = 1;
		elseif self.NodeAbove ~= true and self.NodeBelow == true and self.NodeLeft ~= true and self.NodeRight ~= true then
			self.Frame = 2;
		elseif self.NodeAbove ~= true and self.NodeBelow ~= true and self.NodeLeft == true and self.NodeRight ~= true then
			self.Frame = 3;
		elseif self.NodeAbove ~= true and self.NodeBelow ~= true and self.NodeLeft ~= true and self.NodeRight == true then
			self.Frame = 4;
		elseif self.NodeAbove == true and self.NodeBelow == true and self.NodeLeft ~= true and self.NodeRight ~= true then
			self.Frame = 5;
		elseif self.NodeAbove == true and self.NodeBelow ~= true and self.NodeLeft == true and self.NodeRight ~= true then
			self.Frame = 6;
		elseif self.NodeAbove == true and self.NodeBelow ~= true and self.NodeLeft ~= true and self.NodeRight == true then
			self.Frame = 7;
		elseif self.NodeAbove ~= true and self.NodeBelow == true and self.NodeLeft == true and self.NodeRight ~= true then
			self.Frame = 8;
		elseif self.NodeAbove ~= true and self.NodeBelow == true and self.NodeLeft ~= true and self.NodeRight == true then
			self.Frame = 9;
		elseif self.NodeAbove ~= true and self.NodeBelow ~= true and self.NodeLeft == true and self.NodeRight == true then
			self.Frame = 10;
		elseif self.NodeAbove == true and self.NodeBelow == true and self.NodeLeft == true and self.NodeRight ~= true then
			self.Frame = 11;
		elseif self.NodeAbove == true and self.NodeBelow == true and self.NodeLeft ~= true and self.NodeRight == true then
			self.Frame = 12;
		elseif self.NodeAbove == true and self.NodeBelow ~= true and self.NodeLeft == true and self.NodeRight == true then
			self.Frame = 13;
		elseif self.NodeAbove ~= true and self.NodeBelow == true and self.NodeLeft == true and self.NodeRight == true then
			self.Frame = 14;
		elseif self.NodeAbove == true and self.NodeBelow == true and self.NodeLeft == true and self.NodeRight == true then
			self.Frame = 15;
		elseif self.NodeAbove ~= true and self.NodeBelow ~= true and self.NodeLeft ~= true and self.NodeRight ~= true then
			self.Frame = 0;
		end--]]
	end
	if self.PartTimer:IsPastSimMS(150) then
		if self.LNode ~= nil then
			local lline = CreateMOPixel("Movator Line" , "Movator.rte");
			lline.Pos = Vector(self.Pos.X - 24 , self.Pos.Y);
			lline.RotAngle = math.rad(180);
			lline.Vel = Vector(-8 , 0);
			lline.Lifetime = math.abs(self.LBox.Width*50/lline.Vel.X);
			MovableMan:AddParticle(lline);
		end
		if self.ANode ~= nil then
			local aline = CreateMOPixel("Movator Line" , "Movator.rte");
			aline.Pos = Vector(self.Pos.X , self.Pos.Y - 24);
			aline.RotAngle = math.rad(90);
			aline.Vel = Vector(0 , -8);
			aline.Lifetime = math.abs(self.ABox.Height*50/aline.Vel.Y);
			MovableMan:AddParticle(aline);
		end
		self.PartTimer:Reset();
	elseif self.LNode == nil and self.ANode == nil then
		self.PartTimer:Reset();
	end
end
-----------------------------------------------------------------------------------------
-- Get The Actor's Directions
-----------------------------------------------------------------------------------------
function AReGetDirections(self)

	for i = 1, #self.Move + 100 do
	if self.Move[i] ~= nil then

	--Stuff for player controlled Actors here
	if self.Move[i]:IsPlayerControlled() and CombinedMovatorArea:IsInside(self.Move[i].Pos) then

		--Change self.Move[i]'s lifetime to the necessary one based on what they pressed
		if self.Move[i]:GetController():IsState(Controller.PRESS_UP) or self.Move[i]:GetController():IsState(Controller.HOLD_UP) and not self.Move[i]:GetController():IsState(Controller.PIE_MENU_ACTIVE) then
			self.Move[i].Lifetime = 1000000;
		elseif self.Move[i]:GetController():IsState(Controller.PRESS_DOWN) or self.Move[i]:GetController():IsState(Controller.HOLD_DOWN) and not self.Move[i]:GetController():IsState(Controller.PIE_MENU_ACTIVE) then
			self.Move[i].Lifetime = 1000001;
		elseif self.Move[i]:GetController():IsState(Controller.PRESS_LEFT) or self.Move[i]:GetController():IsState(Controller.HOLD_LEFT) and not self.Move[i]:GetController():IsState(Controller.PIE_MENU_ACTIVE) then
			self.Move[i].Lifetime = 1000002;
		elseif self.Move[i]:GetController():IsState(Controller.PRESS_RIGHT) or self.Move[i]:GetController():IsState(Controller.HOLD_RIGHT) and not self.Move[i]:GetController():IsState(Controller.PIE_MENU_ACTIVE) then
			self.Move[i].Lifetime = 1000003;
		elseif self.Move[i]:GetController():IsState(Controller.PIE_MENU_ACTIVE) and (self.Move[i]:GetController():IsState(Controller.PRESS_UP) or self.Move[i]:GetController():IsState(Controller.HOLD_UP)) then
			self.Move[i].Lifetime = 1000004;
		elseif self.Move[i]:GetController():IsState(Controller.PIE_MENU_ACTIVE) and (self.Move[i]:GetController():IsState(Controller.PRESS_DOWN) or self.Move[i]:GetController():IsState(Controller.HOLD_DOWN)) then
			self.Move[i].Lifetime = 0;
		end

	--Stuff for ai controlled Actors here
	elseif not self.Move[i]:IsPlayerControlled() and CombinedMovatorArea:IsInside(self.Move[i].Pos) and self.Move[i].AIMode == Actor.AIMODE_GOTO or self.Move[i].AIMode == Actor.AIMODE_BRAINHUNT then
		local point = self.Move[i]:GetLastAIWaypoint()
		if self.Box:WithinBox(self.Move[i].Pos) then

			--If there's a movator above then move the self.Move[i] up if its waypoint is above. If it's near its waypoint move it in the correct x direction
			if self.NodeAbove == true then
				if point.Y < self.Move[i].Pos.Y - 5 then
					if self.Move[i].Lifetime ~= 1000002 and self.Move[i].Lifetime ~= 1000003 then
						self.Move[i].Lifetime = 1000000;
					elseif self.Move[i].Lifetime == 1000002 or self.Move[i].Lifetime == 1000003 then
						if self.InnerBox:WithinBox(self.Move[i].Pos) then
							self.Move[i].Lifetime = 1000000;
						end
					end
				elseif point.Y > self.Move[i].Pos.Y + 5 and (point.X >= self.Move[i].Pos.X - 5) and (point.X <= self.Move[i].Pos.X + 5) and self.NodeBelow ~= true then
					self.Move[i].Lifetime = 1000001;
				elseif (point.Y >= self.Move[i].Pos.Y - 5) and (point.Y <= self.Move[i].Pos.Y + 5) then
					if point.X < self.Move[i].Pos.X - 5 and self.NodeLeft ~= true then
						self.Move[i].Lifetime = 1000002;
					elseif point.X > self.Move[i].Pos.X + 5 and self.NodeRight ~= true then
						self.Move[i].Lifetime = 1000003;
					elseif (point.X >= self.Move[i].Pos.X - 5) and (point.X <= self.Move[i].Pos.X + 5) then
						self.Move[i].Lifetime = 0;
					end
				end
			end

			--If there's a movator below then move the Actor down if its waypoint is below. If it's near its waypoint move it in the correct x direction
			if self.NodeBelow == true then
				if point.Y > self.Move[i].Pos.Y + 5 then
					if self.Move[i].Lifetime ~= 1000002 and self.Move[i].Lifetime ~= 1000003 then
						self.Move[i].Lifetime = 1000001;
					elseif self.Move[i].Lifetime == 1000002 or self.Move[i].Lifetime == 1000003 then
						if self.InnerBox:WithinBox(self.Move[i].Pos) then
							self.Move[i].Lifetime = 1000001;
						end
					end
				elseif point.Y < self.Move[i].Pos.Y - 5 and (point.X >= self.Move[i].Pos.X - 5) and (point.X <= self.Move[i].Pos.X + 5) and self.NodeAbove ~= true  then
					self.Move[i].Lifetime = 1000000;
				elseif (point.Y >= self.Move[i].Pos.Y - 5) and (point.Y <= self.Move[i].Pos.Y + 5) then
					if point.X < self.Move[i].Pos.X - 5 and self.NodeLeft ~= true then
						self.Move[i].Lifetime = 1000002;
					elseif point.X > self.Move[i].Pos.X + 5 and self.NodeRight ~= true then
						self.Move[i].Lifetime = 1000003;
					elseif (point.X >= self.Move[i].Pos.X - 5) and (point.X <= self.Move[i].Pos.X + 5) then
						self.Move[i].Lifetime = 0;
					end
				end
			end

			--If there's a movator on either side then if there's not one in the y direction of the waypoint move it in the correct x direction and if there are none also move it in the correct x direction
			if self.NodeLeft == true or self.NodeRight == true then
				if self.NodeAbove ~= true and self.NodeBelow == true then
					if point.Y < self.Move[i].Pos.Y then
						if (point.X < self.Move[i].Pos.X - 5) or (point.X > self.Move[i].Pos.X + 5) then
							if self.Move[i].Lifetime ~= 1000000 then
								if point.X < self.Move[i].Pos.X - 5 then
									self.Move[i].Lifetime = 1000002;
								elseif point.X > self.Move[i].Pos.X + 5 then
									self.Move[i].Lifetime = 1000003;
								end
							elseif self.Move[i].Lifetime == 1000000 then
								if self.InnerBox:WithinBox(self.Move[i].Pos) then
									if point.X < self.Move[i].Pos.X - 5 then
										self.Move[i].Lifetime = 1000002;
									elseif point.X > self.Move[i].Pos.X + 5 then
										self.Move[i].Lifetime = 1000003;
									end
								end
							end
						elseif (point.X >= self.Move[i].Pos.X - 5) and (point.X <= self.Move[i].Pos.X + 5) and self.Move[i].Lifetime ~= 0 then
							self.Move[i].Lifetime = 1000000;
						end
					end
				elseif self.NodeBelow ~= true and self.NodeAbove == true then
					if point.Y > self.Move[i].Pos.Y then
						if (point.X < self.Move[i].Pos.X - 5) or (point.X > self.Move[i].Pos.X + 5) then
							if self.Move[i].Lifetime ~= 1000001 then
								if point.X < self.Move[i].Pos.X - 5 then
									self.Move[i].Lifetime = 1000002;
								elseif point.X > self.Move[i].Pos.X + 5 then
									self.Move[i].Lifetime = 1000003;
								end
							elseif self.Move[i].Lifetime == 1000001 then
								if self.InnerBox:WithinBox(self.Move[i].Pos) then
									if point.X < self.Move[i].Pos.X - 5 then
										self.Move[i].Lifetime = 1000002;
									elseif point.X > self.Move[i].Pos.X + 5 then
										self.Move[i].Lifetime = 1000003;
									end
								end
							end
						elseif (point.X >= self.Move[i].Pos.X - 5) and (point.X <= self.Move[i].Pos.X + 5) and self.Move[i].Lifetime ~= 0 then
							self.Move[i].Lifetime = 1000001;
						end
					end
				elseif self.NodeBelow ~= true and self.NodeAbove ~= true then
					if (point.X >= self.Move[i].Pos.X - 5) and (point.X <= self.Move[i].Pos.X + 5) then
						if point.Y < self.Move[i].Pos.Y - 5 then
							self.Move[i].Lifetime = 1000000;
						elseif point.Y > self.Move[i].Pos.Y + 5 then
							self.Move[i].Lifetime = 1000001;
						end
					elseif (point.Y >= self.Move[i].Pos.Y - 5) and (point.Y <= self.Move[i].Pos.Y + 5) then
						if point.X < self.Move[i].Pos.X - 5 then
							self.Move[i].Lifetime = 1000002;
						elseif point.X > self.Move[i].Pos.X + 5 then
							self.Move[i].Lifetime = 1000003;
						end
					end
				end
			end
		elseif not self.Box:WithinBox(self.Move[i].Pos) then
			if (point.X >= self.Move[i].Pos.X - 5) and (point.X <= self.Move[i].Pos.X + 5) then
				if point.Y < self.Move[i].Pos.Y - 5 then
					self.Move[i].Lifetime = 1000000;
				elseif point.Y > self.Move[i].Pos.Y + 5 then
					self.Move[i].Lifetime = 1000001;
				end
			elseif (point.Y >= self.Move[i].Pos.Y - 5) and (point.Y <= self.Move[i].Pos.Y + 5) then
				if point.X < self.Move[i].Pos.X - 5 then
					self.Move[i].Lifetime = 1000002;
				elseif point.X > self.Move[i].Pos.X + 5 then
					self.Move[i].Lifetime = 1000003;
				end
			end
		end
	end
	end
	end
end
-----------------------------------------------------------------------------------------
-- Do The Movements
-----------------------------------------------------------------------------------------
function AReDoMovements(self)

	for i = 1, #self.Move + 100 do
	if self.Move[i] ~= nil then

	if self.Move[i].Vel.X <= self.Speed and self.Move[i].Vel.X >= -self.Speed and (self.Box:WithinBox(self.Move[i].Pos) or self.ABox:WithinBox(self.Move[i].Pos) or self.LBox:WithinBox(self.Move[i].Pos))  and self.Move[i].Lifetime >= 999999 then

		--Slow down spinning
		if self.Move[i].AngularVel > self.Speed then
			self.Move[i].AngularVel = self.Move[i].AngularVel - self.Speed/4;
		elseif self.Move[i].AngularVel < -self.Speed then
			self.Move[i].AngularVel = self.Move[i].AngularVel + self.Speed/4;
		end

		--Centre the Actor
		local centre;
		if self.Move[i].ClassName == "ACrab" then
			centre = 13;
		elseif self.Move[i].ClassName ~= "ACrab" then
			if self.Move[i]:IsPlayerControlled() ~= true then
				centre = 9;
				self.Move[i]:GetController():SetState(Controller.BODY_CROUCH , true);
			elseif self.Move[i]:IsPlayerControlled() == true then
				centre = 2;
			end
		end

		if self.Move[i].Lifetime == 1000000 or self.Move[i].Lifetime == 1000001 then
			self.Move[i]:GetController():SetState(Controller.BODY_CROUCH , false);
			if self.Move[i].Pos.X > self.Pos.X then
				self.Move[i].Vel.X = -self.Speed/4;
			elseif self.Move[i].Pos.X < self.Pos.X then
				self.Move[i].Vel.X = self.Speed/4;
			elseif self.Move[i].Pos.X == self.Pos.X then
				self.Move[i].Vel.X = 0;
			end
		elseif self.Move[i].Lifetime == 1000002 or self.Move[i].Lifetime == 1000003 then
			if self.Move[i].Pos.Y > self.Pos.Y + centre then
				self.Move[i].Vel.Y = -self.Speed/4;
			elseif self.Move[i].Pos.Y < self.Pos.Y + centre then
				self.Move[i].Vel.Y = self.Speed/4;
			elseif self.Move[i].Pos.Y == self.Pos.Y + centre then
				self.Move[i].Vel.Y = 0;
			end
		end

		if not self.Move[i]:IsPlayerControlled() and self.Move[i].Lifetime ~= 1000004 then

			--Turn Actor fully upright.
			if self.Move[i].AngularVel <= self.Speed and self.Move[i].AngularVel >= -self.Speed then
				if self.Move[i].RotAngle > .5 then
					self.Move[i].AngularVel = -1;
				elseif self.Move[i].RotAngle < -.5 then
					self.Move[i].AngularVel = 1;
				end
			end
			--Stop the Actor from moving freely
			self.Move[i]:GetController():SetState(Controller.MOVE_LEFT , false);
			self.Move[i]:GetController():SetState(Controller.MOVE_RIGHT , false);
			self.Move[i]:GetController():SetState(Controller.MOVE_UP , false);
			self.Move[i]:GetController():SetState(Controller.MOVE_DOWN , false);
			self.Move[i]:GetController():SetState(Controller.BODY_JUMP , false);
			self.Move[i]:GetController():SetState(Controller.BODY_JUMPSTART , false);
		end

		--If the Actor's Y velocity is to fast then slow it down, otherwise...
		if self.Move[i].Vel.Y > self.Speed or self.Move[i].Vel.Y < -self.Speed then
			self.Move[i].Vel.Y = self.Move[i].Vel.Y/1.5
		elseif self.Move[i].Vel.Y <= self.Speed and self.Move[i].Vel.Y >= -self.Speed then

		--Read the Actor's lifetime and move it accordingly to it
			if self.Move[i].Lifetime == 1000000 then
				self.Move[i].Vel.Y = -self.Speed;
			elseif self.Move[i].Lifetime == 1000001 then
				self.Move[i].Vel.Y = self.Speed;
			elseif self.Move[i].Lifetime == 1000002 then
				self.Move[i].Vel.X = -self.Speed;
			elseif self.Move[i].Lifetime == 1000003 then
				self.Move[i].Vel.X = self.Speed;
			elseif self.Move[i].Lifetime == 1000004 then
				self.Move[i].Vel.X = 0;
				self.Move[i].Vel.Y = 0 - SceneMan.GlobalAcc.Magnitude*TimerMan.DeltaTimeSecs;
			end
		end
	elseif self.Move[i].Vel.X > self.Speed or self.Move[i].Vel.X < -self.Speed then
		self.Move[i].Vel.X = self.Move[i].Vel.X/1.2
	end
	end
	end
end

	--Move Actors out of terrain if they get stuck in anything. Doesn't work well, velocity not helping and both functions are ineffective.
	--[[if self.Move[i].Lifetime ~= 100004 and self.Move[i].Lifetime ~= 0 then
		if not self.Move[i]:IsPlayerControlled() then
			if self.Move[i].Vel.Magnitude < self.Speed/4 then
				self.Move[i]:ForceDeepCheck(true);
				--self.Move[i]:MoveOutOfTerrain(0)
				print ("moveout");
			end
		end
	end
end--]]
-----------------------------------------------------------------------------------------
-- Destroy
-----------------------------------------------------------------------------------------
function Destroy(self)
	if self.Lifetime == 0 then
		if CombinedMovatorArea then
			CombinedMovatorArea = nil;
		end
		if MovatorNodePlacedCheck then
			MovatorNodePlacedCheck = nil;
		end
		if MovatorNodeRecheckTimer then
			MovatorNodeRecheckTimer = nil;
			MovatorNodeRecehckInterval = nil;
		end
	elseif self.Lifetime >= 0 then
		if CombinedMovatorArea then
			self.Box = Box(Vector(0,0) , Vector(0,0));
		end
	end
end