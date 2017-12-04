-----------------------------------------------------------------------------------------
-- Create
-----------------------------------------------------------------------------------------
function Create(self)
	--Ensure there's a power value for this movator
	if MovatorPowerValues[self.Team+3] == nil then
		MovatorPowerValues[self.Team+3] = 0;
	end

	self.CheckNodesTimer = Timer();
	self.CheckNodesInterval = 500*math.random(1,4);
	self.MyInfoGenerated = AddMovatorNode(self);
	
	self:RemoveNumberValue("shouldReaddNode");
end
-----------------------------------------------------------------------------------------
-- Update
-----------------------------------------------------------------------------------------
function Update(self)
	--Change the look of the node depending on nearby nodes
	if UInputMan:KeyPressed(3) then
		--self:ReloadScripts();
	end
	
	--Check if we should readd this node
	if (self:GetNumberValue("shouldReaddNode") > 0) then
		self.MyInfoGenerated = AddMovatorNode(self);
		self:RemoveNumberValue("shouldReaddNode");
	end
	
	--Do visual effects so movator nodes look different depending on what sides they have other movators on
	if MovatorPowerValues[self.Team+3] <= 0 then
		self.Frame = 0;
	elseif self.MyInfoGenerated == true and self.CheckNodesTimer:IsPastSimMS(self.CheckNodesInterval) and MovatorNodeTable[self.Team+3][self] ~= nil and MovatorPowerValues[self.Team+3] > 0 then
		local ta = MovatorNodeTable[self.Team+3][self].a[1];
		local tb = MovatorNodeTable[self.Team+3][self].b[1];
		local tl = MovatorNodeTable[self.Team+3][self].l[1];
		local tr = MovatorNodeTable[self.Team+3][self].r[1];
		if ta ~= nil and tb == nil and tl == nil and tr == nil then
			self.Frame = 1;
		elseif ta == nil and tb ~= nil and tl == nil and tr == nil then
			self.Frame = 2;
		elseif ta == nil and tb == nil and tl ~= nil and tr == nil then
			self.Frame = 3;
		elseif ta == nil and tb == nil and tl == nil and tr ~= nil then
			self.Frame = 4;
		elseif ta ~= nil and tb ~= nil and tl == nil and tr == nil then
			self.Frame = 5;
		elseif ta ~= nil and tb == nil and tl ~= nil and tr == nil then
			self.Frame = 6;
		elseif ta ~= nil and tb == nil and tl == nil and tr ~= nil then
			self.Frame = 7;
		elseif ta == nil and tb ~= nil and tl ~= nil and tr == nil then
			self.Frame = 8;
		elseif ta == nil and tb ~= nil and tl == nil and tr ~= nil then
			self.Frame = 9;
		elseif ta == nil and tb == nil and tl ~= nil and tr ~= nil then
			self.Frame = 10;
		elseif ta ~= nil and tb ~= nil and tl ~= nil and tr == nil then
			self.Frame = 11;
		elseif ta ~= nil and tb ~= nil and tl == nil and tr ~= nil then
			self.Frame = 12;
		elseif ta ~= nil and tb == nil and tl ~= nil and tr ~= nil then
			self.Frame = 13;
		elseif ta == nil and tb ~= nil and tl ~= nil and tr ~= nil then
			self.Frame = 14;
		elseif ta ~= nil and tb ~= nil and tl ~= nil and tr ~= nil then
			self.Frame = 15;
		elseif ta == nil and tb == nil and tl == nil and tr == nil then
			self.Frame = 16;
		end
		self.CheckNodesTimer:Reset();
		self.CheckNodesInterval = 500*math.random(1,4);
	end
end
-----------------------------------------------------------------------------------------
-- Destroy
-----------------------------------------------------------------------------------------
function Destroy(self)
	ActivityMan:GetActivity():SetTeamFunds(ActivityMan:GetActivity():GetTeamFunds(self.Team) + self:GetGoldValue(0,0), self.Team);
	RemoveMovatorNode(self);
end