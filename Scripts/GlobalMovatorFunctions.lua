-----------------------------------------------------------------------------------------
-- Global Setup
-----------------------------------------------------------------------------------------
--Make all the global movator variables once when the game starts
if not GlobalMovatorVariablesMade then
	MovatorPowerValues = {};

	MovatorNodeTable = {};
	MovatorPathTable = {};
	CombinedMovatorArea = {};
	MovatorCheckWrapping = false;
	MovatorAllNodesGenerated = false;
	MovatorDefaultNodeSize = 48;
	GlobalMovatorVariablesMade = true;
	print ("Global Movator Variables Made");
end

--------------------------------
--Team Based Movator Functions--
--------------------------------
--Function for resetting all the movator variables for a team except power
function ResetMovatorVariables(team)
	MovatorNodeTable[team+3] = {length = 0};
	CombinedMovatorArea[team+3] = Area();
	MovatorPathTable[team+3] = {};
	print ("Global Movator Variables Reset For Team "..tostring(team));
end
--Function to completely empty and refill a team's movator table, costly since it has to do everything over again
function RecheckAllMovators(team)
	--Clear the table
	MovatorNodeTable[team+3] = {length = 0};
	--Iterate through all particles to find the node and add it
	for node in MovableMan.Particles do
		node = ToMOSRotating(node);
		if node.PresetName == "Movator Zone Node" and node.Team == team then
			node:SetNumberValue("shouldReaddNode", 1);
		end
	end
end
--Function to reset the team's global movator area then add all their boxes to it as long as the activity is actually running, returns true if it works, false otherwise
function AddAllBoxes(team)
	CombinedMovatorArea[team+3] = Area();
	local mytable = MovatorNodeTable[team+3];
	
	--Now add all boxes and lines
	for k, v in pairs(mytable) do
		if (type(k) ~= "string") then
			--First add the movator's actual boxes to the movator area
			if v.box ~= nil then
				CombinedMovatorArea[team+3]:AddBox(v.box)
			else
				print("Box Error: "..tostring(k.Pos).."  "..tostring(v.box));
			end
			
			--Now add those boxes in between areas
			--If we have a node above, find the in between box and add it
			local nbox, nbox2 = nil;
			local size = v[2];
			if v.a[1] ~= nil then
				--Check for wrapping so we can deal with it properly
				if SceneMan.SceneWrapsY and v.a[1].Pos.Y > k.Pos.Y then
					--Split this box into two and add it so we can cross the scenewrap point
					nbox = Box(Vector(k.Pos.X - size*0.5, 0), Vector(k.Pos.X + size*0.5, k.Pos.Y - size*0.5)); --Box starts at top of map and goes to this movator
					nbox2 = Box(Vector(k.Pos.X - size*0.5, v.a[1].Pos.Y + size*0.5), Vector(k.Pos.X + size*0.5, SceneMan.SceneHeight)); --Box starts at target and goes to bottom of map
				else
					nbox = Box(Vector(k.Pos.X - size*0.5, v.a[1].Pos.Y + size*0.5) , Vector(k.Pos.X + size*0.5, k.Pos.Y - size*0.5));
				end
				v.area.above:AddBox(nbox);
				CombinedMovatorArea[team+3]:AddBox(nbox);
				if nbox2 ~= nil then
					v.area.above:AddBox(nbox2);
					CombinedMovatorArea[team+3]:AddBox(nbox2);
					if MovatorDrawConnectingLines == true then
						AddConnectionLines(team, k.Pos, v.a[1].Pos, size*0.5, mytable[v.a[1]][2]*0.5, 0, true);
					end
				else
					if MovatorDrawConnectingLines == true then
						AddConnectionLines(team, k.Pos, v.a[1].Pos, size*0.5, mytable[v.a[1]][2]*0.5, 0, false);
					end
				end
			end
			--If we have a node to the left, find the in between box and add it
			if v.l[1] ~= nil then
				--Check for wrapping so we can deal with it properly
				if SceneMan.SceneWrapsX and v.l[1].Pos.X > k.Pos.X then
					--Split this box into two and add it so we can cross the scenewrap point
					nbox = Box(Vector(0, k.Pos.Y - size*0.5), Vector(k.Pos.X - size*0.5, k.Pos.Y + size*0.5)); --Box starts at the left of map and goes to this movator
					nbox2 = Box(Vector(v.l[1].Pos.X + size*0.5, k.Pos.Y - size*0.5), Vector(SceneMan.SceneWidth , k.Pos.Y + size*0.5)); --Box starts at target and goes to right of map
				else
					nbox = Box(Vector(v.l[1].Pos.X + size*0.5, k.Pos.Y - size*0.5) , Vector(k.Pos.X - size*0.5, k.Pos.Y + size*0.5));
				end
				v.area.left:AddBox(nbox);
				CombinedMovatorArea[team+3]:AddBox(nbox);
				if nbox2 ~= nil then
					v.area.left:AddBox(nbox2);
					CombinedMovatorArea[team+3]:AddBox(nbox2);
					if MovatorDrawConnectingLines == true then
						AddConnectionLines(team, k.Pos, v.l[1].Pos, size*0.5, mytable[v.l[1]][2]*0.5,  1, true);
					end
				else
					if MovatorDrawConnectingLines == true then
						AddConnectionLines(team, k.Pos, v.l[1].Pos, size*0.5, mytable[v.l[1]][2]*0.5,  1, false);
					end
				end
			end
		end
	end
	return true;
end
--Function to generate a table of the shortest path between every possible combination of nodes
function AddAllPaths(team)
	local mypaths = MovatorPathTable[team+3];
	local mytable = MovatorNodeTable[team+3];
	--Iterate through the node table since we need a set of paths for each node
	local confirmed, tentative = {}, {}; --Format - [node] = {distance, direction for next hop}
	local nnode = nil; notents = false; dist1 = nil; dist2 = nil; count = 0; my = nil;
	local acount = 0;
	for k, v in pairs(mytable) do
		if (type(k) ~= "string") then
			confirmed, tentative = {}, {};
			--Reset all our lovely locals
			nnode = nil; notents = false; dist1 = nil; dist2 = nil; count = 0; my = nil;
			
			--Add the source node to the confirmed table
			confirmed[k] = {0, 4};
			
			--Add source's neighbours to tentative nodes: {distance to node from start, next hop from start}
			my = mytable[k];
			if my.a[1] ~= nil and confirmed[my.a[1]] == nil then
				tentative[my.a[1]] = {my.a[2]+confirmed[k][1], 0};
			end
			if my.b[1] ~= nil and confirmed[my.b[1]] == nil then
				tentative[my.b[1]] = {my.b[2]+confirmed[k][1], 1};
			end
			if my.l[1] ~= nil and confirmed[my.l[1]] == nil then
				tentative[my.l[1]] = {my.l[2]+confirmed[k][1], 2};
			end
			if my.r[1] ~= nil and confirmed[my.r[1]] == nil then
				tentative[my.r[1]] = {my.r[2]+confirmed[k][1], 3};
			end
			
			--Start the loop to keep going while we have tentative nodes
			while notents == false do
				----------------------------------
				--Confirm closest tentative node--
				----------------------------------
				--Iterate through the tentative nodes to find the one we should add next
				dist1 = nil; dist2 = nil;
				for m, n in pairs(tentative) do
					--Set the first node we find's distance as dist1
					if dist1 == nil then
						dist1 = n[1];
						nnode = m;
					--The other nodes use dist2, which is then compared against dist1
					else
						dist2 = n[1];
						if dist2 < dist1 then
							--Set nnode as the closest one and change dist1
							nnode = m;
							dist1 = dist2;
						end
					end
				end
				--If this node doesn't actually have neighbours, break out and move on to the next node
				if dist1 == nil and dist2 == nil then
					break
				end
				--Add the new node to the confirmed list and remove it from the tentative list
				confirmed[nnode] = {dist1, tentative[nnode][2]};
				tentative[nnode] = nil;
				
				------------------------------------------------------
				--Add confirmed nodes' neighbours to tentative nodes--
				------------------------------------------------------
				my = mytable[nnode];
				--Add each direction to the tentative table, if it's not confirmed and it's not in the tentative table with a shorter distance already
				if my.a[1] ~= nil and confirmed[my.a[1]] == nil then
					if (tentative[my.a[1]] ~= nil and tentative[my.a[1]][1] > (my.a[2]+confirmed[nnode][1])) or tentative[my.a[1]] == nil then
						tentative[my.a[1]] = {my.a[2]+confirmed[nnode][1], confirmed[nnode][2]};
					end
				end
				if my.b[1] ~= nil and confirmed[my.b[1]] == nil then
					if (tentative[my.b[1]] ~= nil and tentative[my.b[1]][1] > (my.b[2]+confirmed[nnode][1])) or tentative[my.b[1]] == nil then
						tentative[my.b[1]] = {my.b[2]+confirmed[nnode][1], confirmed[nnode][2]};
					end
				end
				if my.l[1] ~= nil and confirmed[my.l[1]] == nil then
					if (tentative[my.l[1]] ~= nil and tentative[my.l[1]][1] > (my.l[2]+confirmed[nnode][1])) or tentative[my.l[1]] == nil then
						tentative[my.l[1]] = {my.l[2]+confirmed[nnode][1], confirmed[nnode][2]};
					end
				end
				if my.r[1] ~= nil and confirmed[my.r[1]] == nil then
					if (tentative[my.r[1]] ~= nil and tentative[my.r[1]][1] > (my.r[2]+confirmed[nnode][1])) or tentative[my.r[1]] == nil then
						tentative[my.r[1]] = {my.r[2]+confirmed[nnode][1], confirmed[nnode][2]};
					end
				end
				
				-------------------------------
				--Checking for loop finishing--
				-------------------------------
				--Iterate through the tentative nodes to see if there's anything left in there, if there isn't we're done, otherwise we loop again
				notents = true;
				for m, n in pairs(tentative) do
					notents = false;
					break;
				end
				--A count to yield the coroutine every few runs
				count = count+1;
				if count%10 == 0 then
					coroutine.yield();
				end
			end
		end
		--Add the confirmed table to this node's dijkstra table
		mypaths[k] = confirmed;
		--Take a break
		coroutine.yield();
	end
	return true;
end
--Show a single node's path as it is created
function ShowMyPath(team, node)
	local mypaths = MovatorPathTable[team+3];
	local mytable = MovatorNodeTable[team+3];
	--Iterate through the node table since we need a set of paths for each node
	local confirmed, tentative = {}, {}; --Format - [node] = {distance, direction for next hop}
	local nnode = nil; notents = false; dist1 = nil; dist2 = nil; count = 0; my = nil;
	local acount = 0;
	local objpoints = {};
	confirmed, tentative = {}, {};
	--Reset all our lovely locals
	nnode = nil; notents = false; dist1 = nil; dist2 = nil; count = 0; my = nil;
	
	--Add the source node to the confirmed table
	confirmed[node] = {0, 4};
	
	--Add source's neighbours to tentative nodes: {distance to node from start, next hop from start}
	my = mytable[node];
	if my.a[1] ~= nil and confirmed[my.a[1]] == nil then
		tentative[my.a[1]] = {my.a[2]+confirmed[node][1], 0};
	end
	if my.b[1] ~= nil and confirmed[my.b[1]] == nil then
		tentative[my.b[1]] = {my.b[2]+confirmed[node][1], 1};
	end
	if my.l[1] ~= nil and confirmed[my.l[1]] == nil then
		tentative[my.l[1]] = {my.l[2]+confirmed[node][1], 2};
	end
	if my.r[1] ~= nil and confirmed[my.r[1]] == nil then
		tentative[my.r[1]] = {my.r[2]+confirmed[node][1], 3};
	end
	
	--Start the loop to keep going while we have tentative nodes
	while notents == false and not UInputMan:KeyPressed(1) do
		objpoints = {};
		for m, n in pairs(confirmed) do
			--ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("Confirmed, dist: "..tostring(n[1]).." dir: "..tostring(n[2]), Vector(m.Pos.X, m.Pos.Y), team, GameActivity.ARROWDOWN);
			objpoints[#objpoints+1] = {"Confirmed, dist: "..tostring(n[1]).." dir: "..tostring(n[2]), Vector(m.Pos.X, m.Pos.Y), team, GameActivity.ARROWDOWN};
			print("Confirmed: "..tostring(m.Pos).."  "..tostring(n[1]).."  "..tostring(n[2]));
		end
		print("");
		for m, n in pairs(tentative) do
			--ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("Tentative, dist: "..tostring(n[1]).." dir: "..tostring(n[2]), Vector(m.Pos.X, m.Pos.Y), team, GameActivity.ARROWDOWN);
			objpoints[#objpoints+1] = {"Tentative, dist: "..tostring(n[1]).." dir: "..tostring(n[2]), Vector(m.Pos.X, m.Pos.Y), team, GameActivity.ARROWUP};
			print("Tentative: "..tostring(m.Pos).."  "..tostring(n[1]).."  "..tostring(n[2]));
		end
		print("");
		print("");
		----------------------------------
		--Confirm closest tentative node--
		----------------------------------
		--Iterate through the tentative nodes to find the one we should add next
		dist1 = nil; dist2 = nil;
		for m, n in pairs(tentative) do
			--Set the first node we find's distance as dist1
			if dist1 == nil then
				dist1 = n[1];
				nnode = m;
			--The other nodes use dist2, which is then compared against dist1
			else
				dist2 = n[1];
				if dist2 < dist1 then
					--Set nnode as the closest one and change dist1
					nnode = m;
					dist1 = dist2;
				end
			end
		end
		--If this node doesn't actually have neighbours, break out and move on to the next node
		if dist1 == nil and dist2 == nil then
			break
		end
		--Add the new node to the confirmed list and remove it from the tentative list
		confirmed[nnode] = {dist1, tentative[nnode][2]};
		tentative[nnode] = nil;
		
		------------------------------------------------------
		--Add confirmed nodes' neighbours to tentative nodes--
		------------------------------------------------------
		my = mytable[nnode];
		--Add each direction to the tentative table, if it's not confirmed and it's not in the tentative table with a shorter distance already
		if my.a[1] ~= nil and confirmed[my.a[1]] == nil then
			if (tentative[my.a[1]] ~= nil and tentative[my.a[1]][1] > (my.a[2]+confirmed[nnode][1])) or tentative[my.a[1]] == nil then
				tentative[my.a[1]] = {my.a[2]+confirmed[nnode][1], confirmed[nnode][2]};
			end
		end
		if my.b[1] ~= nil and confirmed[my.b[1]] == nil then
			if (tentative[my.b[1]] ~= nil and tentative[my.b[1]][1] > (my.b[2]+confirmed[nnode][1])) or tentative[my.b[1]] == nil then
				tentative[my.b[1]] = {my.b[2]+confirmed[nnode][1], confirmed[nnode][2]};
			end
		end
		if my.l[1] ~= nil and confirmed[my.l[1]] == nil then
			if (tentative[my.l[1]] ~= nil and tentative[my.l[1]][1] > (my.l[2]+confirmed[nnode][1])) or tentative[my.l[1]] == nil then
				tentative[my.l[1]] = {my.l[2]+confirmed[nnode][1], confirmed[nnode][2]};
			end
		end
		if my.r[1] ~= nil and confirmed[my.r[1]] == nil then
			if (tentative[my.r[1]] ~= nil and tentative[my.r[1]][1] > (my.r[2]+confirmed[nnode][1])) or tentative[my.r[1]] == nil then
				tentative[my.r[1]] = {my.r[2]+confirmed[nnode][1], confirmed[nnode][2]};
			end
		end
		
		-------------------------------
		--Checking for loop finishing--
		-------------------------------
		--Iterate through the tentative nodes to see if there's anything left in there, if there isn't we're done, otherwise we loop again
		notents = true;
		for m, n in pairs(tentative) do
			notents = false;
			break;
		end
		coroutine.yield(objpoints);
	end
	objpoints = {};
	for m, n in pairs(confirmed) do
		--ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("Confirmed, dist: "..tostring(n[1]).." dir: "..tostring(n[2]), Vector(m.Pos.X, m.Pos.Y), team, GameActivity.ARROWDOWN);	
		objpoints[#objpoints+1] = {"Confirmed, dist: "..tostring(n[1]).." dir: "..tostring(n[2]), Vector(m.Pos.X, m.Pos.Y), team, GameActivity.ARROWDOWN}
		print("Confirmed: "..tostring(m.Pos).."  "..tostring(n[1]).."  "..tostring(n[2]));
	end
	print("");
	for m, n in pairs(tentative) do
		--ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("Tentative, dist: "..tostring(n[1]).." dir: "..tostring(n[2]), Vector(m.Pos.X, m.Pos.Y), team, GameActivity.ARROWDOWN);
		objpoints[#objpoints+1] = {"Tentative, dist: "..tostring(n[1]).." dir: "..tostring(n[2]), Vector(m.Pos.X, m.Pos.Y), team, GameActivity.ARROWUP}
		print("Tentative: "..tostring(m.Pos).."  "..tostring(n[1]).."  "..tostring(n[2]));
	end
	local count = 0;
	for k, v in pairs(confirmed) do
		count = count+1;
	end
	print("Total confirmed nodes: "..tostring(count));
	ConsoleMan:SaveAllText("Movator Show Path Log.txt");
	--Add the confirmed table to this node's dijkstra table
	mypaths[node] = confirmed;
	return objpoints;
end

--Function to check for any obstructions in the movator's path
function CheckAllObstructions(team)
	local mytable = MovatorNodeTable[team+3];
	local changesneeded = false;
	local count = 0;
	local dirtable = {"a", "b", "l", "r"};
	local revdirtable = {a = "b", b = "a", l = "r", r = "l"};
	local connectionsnum = 0;
	
	--A bit hacky, clear each node's connections and its connections' connections, recheck them, if the number of connections the node has has changed from before, set flag
	for k, v in pairs(mytable) do
		if (type(k) ~= "string") then
			--Clear this node's connections and save then clear its number of connections
			for i = 1, 4 do
				v[dirtable[i]] = {nil, 0};
			end
			connectionsnum = v[1];
			v[1] = 0;
			
			--Fully check this node's connections
			local vals = CheckConnections(k);
			--If this movator has affected any others, refind all connections for them
			if vals ~= nil then
				for m, n in pairs(vals) do
					mytable[n][1] = mytable[n][1] - 1;
					mytable[n][revdirtable[m]] = {nil, 0};
					CheckConnections(n);
				end
			end
			
			--Set the flag for if we need to make changes
			if connectionsnum ~= v[1] then
				changesneeded = true;
			end
			--Increase the count and yield if it's a multiple of 5
			count = count + 1;
			if count%5 == 0 then
				coroutine.yield(changesneeded);
			end
		end
	end
	coroutine.yield(changesneeded);
end

--------------------------------
--Individual Movator Functions--
--------------------------------
--Function for adding movators to the relevant movator node table
function AddMovatorNode(node)
	--Make the global movator variables for this team if they don't exist
	if not MovatorNodeTable[node.Team+3] then
		ResetMovatorVariables(node.Team);
	end
	--If we're adding movators, the scene is running, so set the global constant for checking wrapping
	MovatorCheckWrapping = SceneMan.SceneWrapsX or SceneMan.SceneWrapsY;
	--Add the inputted movator node to the table if it's not there already
	--[1] - number of connected nodes, [2] - size, ["ablr"] - the movator in each direction and its distance, ["box"] - movator's box, ["sbox"] - movator's inside box, for ai direction changes, ["areas"] - the area between this movator and the one above and left of it
	if MovatorNodeTable[node.Team+3][node] == nil then
		for teamKey, teamNodeTable in pairs(MovatorNodeTable) do
			for nodeKey, nodeInfo in pairs(teamNodeTable) do
				if (type(nodeKey) ~= "string") then
					if nodeInfo.box ~= false then
						local size = node.Sharpness <= 1 and MovatorDefaultNodeSize or node.Sharpness;
						local nodeBox = Box(Vector(node.Pos.X - size*0.5 + 0.5, node.Pos.Y - size*0.5) , Vector(node.Pos.X + size*0.5, node.Pos.Y + size*0.5));
						if BoxesIntersect(nodeInfo.box, nodeBox) then
							node.ToDelete = true;
							return false;
						end
					end
				end
			end
		end
		MovatorNodeTable[node.Team+3][node] = {0, 0, a = {nil, 0}, b = {nil, 0}, l = {nil, 0}, r = {nil, 0}, box = false, sbox = false, area = {above = nil, left = nil}};
		--Fill in the inputted movator node's information then return true so the zone knows it's good
		if GenerateNodeInfo(node) then
			MovatorNodeTable[node.Team+3].length = MovatorNodeTable[node.Team+3].length + 1;
			return true;
		end
	end
	return false;
end
--Function for adding all neighbour information for a node to the node table
function GenerateNodeInfo(node)
	MovatorAllNodesGenerated = false;
	--Set the area this movator encompasses
	local mytable = MovatorNodeTable[node.Team+3][node];
	local size = node.Sharpness <= 1 and MovatorDefaultNodeSize or node.Sharpness;
	mytable[2] = size;
	mytable.box = Box(Vector(node.Pos.X - size*0.5, node.Pos.Y - size*0.5) , Vector(node.Pos.X + size*0.5, node.Pos.Y + size*0.5));
	mytable.sbox = Box(Vector(node.Pos.X - size*0.25, node.Pos.Y - size*0.25) , Vector(node.Pos.X + size*0.25, node.Pos.Y + size*0.25));
	
	--Find all connected movators for this one and get any movators it has affected
	local vals = CheckConnections(node);
	--If this movator has affected any others, refind all connections for them
	if vals ~= nil then
		local nodetable = MovatorNodeTable[node.Team+3];
		for k, v in pairs(vals) do
			CheckConnections(v);
		end
	end
	MovatorAllNodesGenerated = true;
	return true;
end
--Function for rechecking all connections of a specific node, used on removal and possibly addition of a node
function CheckConnections(node)
	local mytable = MovatorNodeTable[node.Team+3];
	local mynodes = {a={}, b={}, l={}, r={}};
	local myreturns = {};
	------------------------------------
	--Find all nodes in each direction--
	------------------------------------
	--Add any nodes that have the same one pos the same but are half this' size plus half the other's size or more away in the other pos (i.e. same x, different y or vice-versa)
	for k, v in pairs(mytable) do
		if (type(k) ~= "string" and MovableMan:IsParticle(k)) then --Make sure the movator node exists for safety
			local short = SceneMan:ShortestDistance(node.Pos, k.Pos, MovatorCheckWrapping);
			local xdist = short.X;
			local ydist = short.Y;
			local size = mytable[node][2]*0.5 + v[2]*0.5;
			--Nodes above, below, left and right
			if ydist <= -size and xdist == 0 then
				table.insert(mynodes.a, k);
			elseif ydist >= size and xdist == 0 then
				table.insert(mynodes.b, k);
			elseif xdist <= -size and ydist == 0 then
				table.insert(mynodes.l, k);
			elseif xdist >= size and ydist == 0 then
				table.insert(mynodes.r, k);
			end
		end
	end
	
	-------------------------------------------
	--Find the closest node in each direction--
	-------------------------------------------
	--Check through the nodes in each direction to find the closest one
	for k, v in pairs(mynodes) do
		if #v > 0 and MovableMan:IsParticle(v[1]) then --Make sure we've got movators in this list and at least the first one exists for safety
			local mywraps = MovatorCheckWrapping;
			--Set up default values for closest node
			local target = v[1];
			local rdist = SceneMan:ShortestDistance(node.Pos,target.Pos,mywraps);
			local dist = rdist.Magnitude;
			--Find the actual closest node
			if #v > 1 then
				for i = 2, #v do
					if MovableMan:IsParticle(v[i]) then --Make sure the movator node exists for safety
						local ndist = SceneMan:ShortestDistance(node.Pos,v[i].Pos,mywraps).Magnitude;
						if ndist < dist then
							target = v[i];
							dist = ndist;
						end
					end
				end
			end
			---------------------------------------------
			--Ensure the node found is actually visible--
			---------------------------------------------
			--Check for visibility and direct attachment between this and closest node
			local rayvec = SceneMan:ShortestDistance(node.Pos,target.Pos,mywraps);
			local rayOffsets = {
				(k == "a" or k == "b") and Vector(-mytable[node][2]*0.25, 0) or Vector(0, -mytable[node][2]*0.25);
				Vector(0, 0),
				(k == "a" or k == "b") and Vector(mytable[node][2]*0.25, 0) or Vector(0, mytable[node][2]*0.25);
			}
			local ray = false;
			for _, rayOffset in ipairs(rayOffsets) do
				ray = SceneMan:CastStrengthRay(node.Pos + rayOffset, rayvec, 15, Vector(), 4, 0, true);
				if (ray == true) then
					break;
				end
			end
			--If we've got a clear los to the nearest node, add the values to the global table and the global movator area if needed and set the target's closest to be this
			if ray == false and MovableMan:IsParticle(target) then --Make sure the movator node exists for safety
				
				--If this isn't replacing a more distant node for the target, increase the target's node count
				if mytable[node][k][1] == nil then
					mytable[node][1] = mytable[node][1] + 1;
				end
				
				--Set the target as this node's closest in the relevant direction
				mytable[node][k] = {target, dist};
				
				--Add the area between this and the next node in up or left directions as long as we don't already have an area there (i.e. we're not rechecking)
				local myareas = {a = {Area(), "above"}, l = {Area(), "left"}};
				if myareas[k] ~= nil and mytable[node].area[myareas[k][2]] == nil then
					mytable[node].area[myareas[k][2]] = myareas[k][1];
				end
				
				--Add the target to the return number
				myreturns[k] = target;
			end
		end
	end
	return myreturns;
end
--Function for removing a node from the table safely
function RemoveMovatorNode(node)
	local mytable = MovatorNodeTable[node.Team+3];
	--Put together a temporary table of the nodes whose connections we need to recheck
	local t = mytable[node];
	if type(t) ~= "nil" then
		local size = mytable[node][2];
		local tocheck = {t.a[1], t.b[1], t.l[1], t.r[1]};
		--Clear this value from the global table
		mytable[node] = nil;
		--Check all the necessary nodes' connections
		for k, v in pairs(tocheck) do
			if v ~= nil then
				--Completely reset the movator's table value, not done manually to avoid maintaining two similar functions
				mytable[v] = nil;
				v:SetNumberValue("shouldReaddNode", 1);
			end
		end
		MovatorNodeTable[node.Team+3].length = MovatorNodeTable[node.Team+3].length - 1;
	end
end

-----------------------------
--General Utility Functions--
-----------------------------
--Function for checking if two boxes intersect
function BoxesIntersect(box1, box2)
	local box1Area = Area();
	box1Area:AddBox(box1);
	local correctedBox2 = Box(box2.Corner + Vector(0.1, 0.1), Vector(box2.Corner.X + box2.Width - 0.1, box2.Corner.Y + box2.Height - 0.1));
	local points = {correctedBox2.Corner, Vector(correctedBox2.Corner.X + correctedBox2.Width, correctedBox2.Corner.Y), Vector(correctedBox2.Corner.X, correctedBox2.Corner.Y + correctedBox2.Height), Vector(correctedBox2.Corner.X + correctedBox2.Width, correctedBox2.Corner.Y + correctedBox2.Height)}
	for _, point in ipairs(points) do
		if box1Area:IsInside(point) then
			return true;
		end
	end
	return false;
end

--DEBUG
function DebugMovators(num, team)
	if num == 1 then
		ResetMovatorVariables(team);
		RecheckAllMovators(team)
		print("Part 1: All movators readded for Team "..tostring(team));
	elseif num == 2 then
		AddAllBoxes(team);
		print("Part 2: All boxes readded for Team "..tostring(team));
	end
end