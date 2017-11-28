--NOTE ABOUT CRASH:
--Only happens when rechecking nodes. Look for something in there. Not sure if in zones or controller
-----------------------------------------------------------------------------------------
-- Create
-----------------------------------------------------------------------------------------
function Create(self)

	--Set the area this movator encompasses
	self.Box = Box(Vector(self.Pos.X - 24 , self.Pos.Y - 24) , Vector(self.Pos.X + 24 , self.Pos.Y + 24));
	--The smaller area for the movator. Used for turning corners
	self.InnerBox = Box(Vector(self.Pos.X - 10 , self.Pos.Y - 10) , Vector(self.Pos.X + 10 , self.Pos.Y + 10));
	--The two boxes in between movators. Only two directions are needed because the other movator will supply directions for the in between boxes.
	self.ABox = Box(Vector(0 , 0) , Vector(0 , 0));
	self.LBox = Box(Vector(0 , 0) , Vector(0 , 0));	--Unneeded?

	--Variables for whether a node is directly above to self in each direction
	self.NodeAbove = false;
	self.NodeBelow = false;
	self.NodeLeft = false;
	self.NodeRight = false;
	--Save the various nodes in all directions. Used for picking direction tables for actors
	self.ANode = nil;
	self.BNode = nil;
	self.LNode = nil;
	self.RNode = nil;
	--Booleans for whether to draw boxes for above and to the left
	self.ABoxNode = false;
	self.LBoxNode = false;
	
	self.MyNum = nil; --The globabl table value for this movator, testing to see if it'll work
	
	--Global Table for all movators
	--Arguments: 1 - the number of movators
	--[i][1] - reference to each movator
	--[i][2] - the length of that string, i.e. the total number of connections
	--[i][3 - 6] - reference to each of the closest movators. Above = 3, Below = 4, Left = 5, Right = 6
	if not MovatorNodeTable then
		MovatorNodeTable = {}
	end
	self.MyNum = #MovatorNodeTable+1;
	self.Sharpness = self.MyNum; --Set the sharpness to the table num for reference from the controller. Sigh, had to resort to this :(
	--Note: nil values unnecessary and do nothing, just placeholders for me
	MovatorNodeTable[self.MyNum] = {self, 0, nil, nil, nil, nil};
	--MovatorNodeTable[#MovatorNodeTable + 1] = {self, 0, nil, nil, nil, nil};
	
	--Global Variable for checking when a node has been placed
	if not MovatorNodePlacedCheck == true then
		MovatorNodePlacedCheck = true;
	end
	
	--Area shared by all movators, add this movator's box to it
	if not CombinedMovatorArea then
		CombinedMovatorArea = Area();
	end
	CombinedMovatorArea:AddBox(self.Box);

	--TODO: Make movators pick just one controller box. I.e. all new movators 
	--Use mass changes, i.e. for particles do if controller.mass == normal + 5 then use it, else none in use so use what we find
	
	self.NodeRechecked = false; --A variable for checking when called to from controller
	self.ConnectionsSaved = false;
	self.CheckTimer = Timer();
	self.CheckInterval = 10;
	self.CheckTimer:Reset();
	self.EffectsTimer = Timer();
	self.EffectsTimer:Reset();
	self.CleanTimer = Timer();
	self.CleanTimer:Reset();
end
-----------------------------------------------------------------------------------------
-- Update
-----------------------------------------------------------------------------------------
function Update(self)
	if UInputMan:KeyPressed(3) then
		self:ReloadScripts();
		print ("zone scripts reloaded");
	end

	--If we have power then
	if MovatorNodesPowered == true then
		--Check for nearest node and to see if there's a node in each direction.
		DoNodeChecks(self);
	else
		--Set the movator to be mostly invisible if it's not powered
		self.Frame = 0;
		self.NodeRechecked = false;
	end
	--Add this node's box and table to the CombinedMovatorArea and global MovatorNodeTable if flag set
	if CheckAllMovators == true then
		if self.NodeRechecked == false then
			if MovatorNodeTable[self.MyNum][1] then
				if MovatorNodeTable[self.MyNum][1] == self then
					table.remove(MovatorNodeTable, self.MyNum);
				end
			end
			CombinedMovatorArea:AddBox(self.Box);
			self.MyNum = #MovatorNodeTable + 1;
			self.Sharpness = self.MyNum;
			MovatorNodeTable[self.MyNum] = {self, 0, nil, nil, nil, nil};
			self.NodeRechecked = true
		end
	end
			
end
-----------------------------------------------------------------------------------------
-- Check The Nodes
-----------------------------------------------------------------------------------------
function DoNodeChecks(self)
	--Flag the global variable as false so movators recheck. Put a short delay so it works properly
	--Uneeded? (The Delay)
	if self.CheckTimer ~= nil then
		if self.CheckTimer:IsPastSimMS(self.CheckInterval) then
			MovatorNodePlacedCheck = false;
			self.CheckTimer = nil;
			self.CheckInterval = nil;
		end
	end

	--When told to recheck nodes, find nodes in all directions and pick the closest to connect to, if it exists
	if MovatorNodePlacedCheck == true then

		--Set up tables for each direction for picking the closest node, essentially table finds node that can connect to self
		--Divided into directions to reduce intensity. This is probably actually less efficient. TODO: Think on this
		local anodes = {}
		local bnodes = {}
		local lnodes = {}
		local rnodes = {}
		if #MovatorNodeTable > 1 then
			for i = 1 , #MovatorNodeTable do
				if (MovatorNodeTable[i][1].Pos.Y <= self.Pos.Y - 48) and (MovatorNodeTable[i][1].Pos.X == self.Pos.X) then
					anodes[#anodes + 1] = MovatorNodeTable[i][1];
				end
				if (MovatorNodeTable[i][1].Pos.Y >= self.Pos.Y + 48) and (MovatorNodeTable[i][1].Pos.X == self.Pos.X) then
					bnodes[#bnodes + 1] = MovatorNodeTable[i][1];
				end
				if (MovatorNodeTable[i][1].Pos.X <= self.Pos.X - 48) and (MovatorNodeTable[i][1].Pos.Y == self.Pos.Y) then
					lnodes[#lnodes + 1] = MovatorNodeTable[i][1];
				end
				if (MovatorNodeTable[i][1].Pos.X >= self.Pos.X + 48) and (MovatorNodeTable[i][1].Pos.Y == self.Pos.Y) then
					rnodes[#rnodes + 1] = MovatorNodeTable[i][1];
				end
			end
		end

		--Find the closest node in each table and set it to be the closest in each direction.
		--Then, for left and above, add the box formed to the combined area for movement and for glowy effects

		--Attached Above
		--Reset flags if no nodes in this direction
		if #anodes <= 0 then
			self.NodeAbove = false;
			self.ANode = nil;
			self.ABoxNode = false;
		elseif #anodes > 0 then
			--Find the closest node in this direction
			local adist = 0;
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
				--Finally check for visibility and attachment between this and closest node
				local aray = SceneMan:CastStrengthRay(self.Pos, (atarget.Pos - self.Pos), 15, Vector(), 4, 0, true);
				if aray == false then
					self.NodeAbove = true;
					self.ANode = atarget;
					if (atarget.Pos.Y < self.Pos.Y - 48) then
						self.ABoxNode = true;
					end
				else
					self.NodeAbove = false;
					self.ANode = nil;
					self.ABoxNode = false;
				end
			end
		end
		--If the nextdoor node is not directly attached, add the box to the combined area
		if self.ABoxNode == true then
			self.ABox = Box(Vector(self.Pos.X - 24 , self.ANode.Pos.Y + 24) , Vector(self.Pos.X + 24 , self.Pos.Y - 24));
			CombinedMovatorArea:AddBox(self.ABox);
		elseif self.ABoxNode == false then
			self.ABox = Box(Vector(0,0) , Vector(0,0));
		end

		--Attached Below
		--Reset flags if no nodes in this direction
		if #bnodes <= 0 then
			self.NodeBelow = false;
			self.BNode = nil;
		elseif #bnodes > 0 then
			--Find the closest node in this direction
			local bdist = 0;
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
				--Finally check for visibility between this and closest node
				local bray = SceneMan:CastStrengthRay(self.Pos, (btarget.Pos - self.Pos), 15, Vector(), 4, 0, true);
				if bray == false then
					self.NodeBelow = true;
					self.BNode = btarget;
				else
					self.NodeBelow = false;
					self.BNode = nil;
				end
			end
		end

		--Attached Left
		--Reset flags if no nodes in this direction
		if #lnodes <= 0 then
			self.NodeLeft = false;
			self.LNode = nil;
			self.LBoxNode = false;
		elseif #lnodes > 0 then
			--Find the closest node in this direction
			local ldist = 0;
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
				--Finally check for visibility and direct attachment between this and closest node
				local lray = SceneMan:CastStrengthRay(self.Pos, (ltarget.Pos - self.Pos), 15, Vector(), 4, 0, true);
				if lray == false then
					self.NodeLeft = true;
					self.LNode = ltarget;
					if (ltarget.Pos.X < self.Pos.X - 48) then
						self.LBoxNode = true;
					end
				else
					self.NodeLeft = false;
					self.LNode = nil;
					self.LBoxNode = false;
				end
			end
		end
		--If the nextdoor node is not directly attached, add the box to the combined area
		if self.LBoxNode == true then
			self.LBox = Box(Vector(self.LNode.Pos.X + 24 , self.Pos.Y - 24) , Vector(self.Pos.X - 24 , self.Pos.Y + 24));
			CombinedMovatorArea:AddBox(self.LBox);
		elseif self.LBoxNode == false then
			self.LBox = Box(Vector(0,0) , Vector(0,0));
		end

		--Attached Right
		--Reset flags if no nodes in this direction
		if #rnodes <= 0 then
			self.NodeRight = false;
			self.RNode = nil;
		elseif #rnodes > 0 then
			--Find the closest node in this direction
			local rdist = 0;
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
				--Finally check for visibility between this and closest node
				local rray = SceneMan:CastStrengthRay(self.Pos, (rtarget.Pos - self.Pos), 15, Vector(), 4, 0, true);
				if rray == false then
					self.NodeRight = true;
					self.RNode = rtarget;
				else
					self.NodeRight = false;
					self.RNode = nil;
				end
			end
		end

		--Change the look of the hub depending on nearby nodes
		--TODO: Make a glow that changes look instead to remove weird collision problems
		if self.NodeAbove == true and self.NodeBelow ~= true and self.NodeLeft ~= true and self.NodeRight ~= true then
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
			self.Frame = 16;
		end
		
		--Flag it so we check through connections for controller reading
		self.ConnectionsSaved = false;
	end
	
	--Make it clear to the movator controller what node connections this node has and which nodes they are.
	--Also figure out the total for ease later
	if self.ConnectionsSaved == false then
		local i = self.MyNum;
		MovatorNodeTable[i][2] = 0;
		if self == MovatorNodeTable[i][1] then
			if self.NodeAbove == true then
				MovatorNodeTable[i][2] = MovatorNodeTable[i][2] + 1;
				MovatorNodeTable[i][3] = self.ANode;
			end
			if self.NodeBelow == true then
				MovatorNodeTable[i][2] = MovatorNodeTable[i][2] + 1;
				MovatorNodeTable[i][4] = self.BNode;
			end
			if self.NodeLeft == true then
				MovatorNodeTable[i][2] = MovatorNodeTable[i][2] + 1;
					MovatorNodeTable[i][5] = self.LNode;
			end
			if self.NodeRight == true then
				MovatorNodeTable[i][2] = MovatorNodeTable[i][2] + 1;
				MovatorNodeTable[i][6] = self.RNode;
			end
			self.ConnectionsSaved = true;
		end
	end
	
	
	
		--[[for i = 1, #MovatorNodeTable do
			if MovatorNodeTable[i][1] then
				if self == MovatorNodeTable[i][1] then
					if self.NodeAbove == true then
						MovatorNodeTable[i][2] = MovatorNodeTable[i][2] + 1;
						MovatorNodeTable[i][3] = self.ANode;
					end
					if self.NodeBelow == true then
						MovatorNodeTable[i][2] = MovatorNodeTable[i][2] + 1;
						MovatorNodeTable[i][4] = self.BNode;
					end
					if self.NodeLeft == true then
						MovatorNodeTable[i][2] = MovatorNodeTable[i][2] + 1;
						MovatorNodeTable[i][5] = self.LNode;
					end
					if self.NodeRight == true then
						MovatorNodeTable[i][2] = MovatorNodeTable[i][2] + 1;
						MovatorNodeTable[i][6] = self.RNode;
					end
					print (MovatorNodeTable[i][2]);
					self.ConnectionsSaved = true;
					break;
				end
			end
		end
		--self.ConnectionsSaved = true;
	end--]]
	
	--TODO Change these shitty effects to something simpler and less laggy
	if self.EffectsTimer:IsPastSimMS(150) then
		if self.ABoxNode == true then
			local aline = CreateMOPixel("Movator Line" , "Movator.rte");
			aline.Pos = Vector(self.Pos.X , self.Pos.Y - 24);
			aline.RotAngle = math.rad(90);
			aline.Vel = Vector(0 , -8);
			aline.Lifetime = math.abs(self.ABox.Height*50/aline.Vel.Y);
			MovableMan:AddParticle(aline);
		end
		if self.LBoxNode == true then
			local lline = CreateMOPixel("Movator Line" , "Movator.rte");
			lline.Pos = Vector(self.Pos.X - 24 , self.Pos.Y);
			lline.RotAngle = math.rad(180);
			lline.Vel = Vector(-8 , 0);
			lline.Lifetime = math.abs(self.LBox.Width*50/lline.Vel.X);
			MovableMan:AddParticle(lline);
		end
		self.EffectsTimer:Reset();
	elseif self.LBoxNode == false and self.ABoxNode == false then
		self.EffectsTimer:Reset();
	end
end
-----------------------------------------------------------------------------------------
-- Destroy
-----------------------------------------------------------------------------------------
function Destroy(self)
	if CombinedMovatorArea then
		self.Box = Box(Vector(0,0) , Vector(0,0));
	end
	if MovatorNodeTable then
		for i = 1, #MovatorNodeTable do
			if MovatorNodeTable[i][1] == self then
				table.remove(MovatorNodeTable, i)
			end
		end
	end
end